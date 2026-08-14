import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:pointycastle/export.dart';

import '../../core/constants.dart';
import '../../core/secure_storage_service.dart';

/// Cloud Shell の状態
enum CloudShellState { unknown, starting, running, stopped, error }

/// Cloud Shell 起動の各フェーズ
enum StartupStep { idle, preparingKey, checkingState, starting, waitingRunning, registeringKey }

/// Google Cloud Shell API サービス
/// Cloud Shell の起動に失敗した理由。表示文言は UI 層が決める。
enum CloudShellFailureKind {
  /// アクセストークンが無い（未ログイン）
  notSignedIn,

  /// アクセストークンの期限切れ
  authExpired,

  /// 起動待ちがタイムアウトした
  startTimeout,

  /// 想定外のエラー（[CloudShellFailure.detail] に詳細）
  unknown,
}

class CloudShellFailure {
  const CloudShellFailure(this.kind, {this.detail});

  final CloudShellFailureKind kind;
  final String? detail;
}

/// サービス内部で送出する型付き例外。
class CloudShellException implements Exception {
  const CloudShellException(this.kind);

  final CloudShellFailureKind kind;

  @override
  String toString() => 'CloudShellException(${kind.name})';
}

class CloudShellService extends ChangeNotifier {
  final _storage = SecureStorageService.instance;

  CloudShellState _state = CloudShellState.unknown;
  StartupStep _startupStep = StartupStep.idle;
  int _pollAttempt = 0;
  String? _sshHost;
  String? _sshUsername;
  int _sshPort = AppConstants.sshPort;
  String? _webHost;
  CloudShellFailure? _error;
  bool _isLoading = false;
  List<String> _remotePublicKeys = [];

  // リポジトリから起動する場合に設定される
  String? _pendingRepoName;
  String? _pendingShellCommand;
  int _pendingVersion = 0;

  CloudShellState get state => _state;
  StartupStep get startupStep => _startupStep;
  int get pollAttempt => _pollAttempt;
  String? get sshHost => _sshHost;
  String? get sshUsername => _sshUsername;
  int get sshPort => _sshPort;
  String? get webHost => _webHost;
  /// 直近の失敗。表示文言は UI 層（ロケール）が決める。
  CloudShellFailure? get error => _error;
  bool get isLoading => _isLoading;
  bool get isRunning => _state == CloudShellState.running;

  String? get pendingRepoName => _pendingRepoName;
  int get pendingVersion => _pendingVersion;
  String? consumePendingShellCommand() {
    final cmd = _pendingShellCommand;
    _pendingShellCommand = null;
    return cmd;
  }

  // ログアウト後に状態をリセットする
  void reset() {
    _storage.clearCache();
    unawaited(_storage.clearCloudShellCredentials());
    _state = CloudShellState.unknown;
    _startupStep = StartupStep.idle;
    _pollAttempt = 0;
    _sshHost = null;
    _sshUsername = null;
    _sshPort = AppConstants.sshPort;
    _webHost = null;
    _error = null;
    _isLoading = false;
    _pendingRepoName = null;
    _pendingShellCommand = null;
    notifyListeners();
  }

  // リポジトリ付きで Cloud Shell を起動する
  void setPendingRepo(String repoName, String shellCommand) {
    _pendingRepoName = repoName;
    _pendingShellCommand = shellCommand;
    _pendingVersion++;
    if (_state != CloudShellState.running) {
      startAndConnect();
    }
    notifyListeners();
  }

  // ── 環境の状態取得 & 起動 ────────────────────────────

  Future<void> startAndConnect() async {
    if (_isLoading) return; // 再入防止
    _isLoading = true;
    _error = null;
    _state = CloudShellState.starting;
    _startupStep = StartupStep.preparingKey;
    _pollAttempt = 0;
    notifyListeners();

    try {
      // トークンと公開鍵を並列で読み出す
      final results = await Future.wait([
        _storage.getAccessToken(),
        _storage.getSshPublicKey(),
      ]);
      final token = results[0];
      if (token == null || token.isEmpty) {
        throw const CloudShellException(CloudShellFailureKind.notSignedIn);
      }

      // SSH鍵ペアを準備（初回 or コメント付き旧形式の場合は再生成）
      final existingPub = results[1];
      if (existingPub == null || existingPub.trim().split(' ').length > 2) {
        await _generateAndStoreSshKeyPair();
      }

      // まず現在の状態を確認（既に RUNNING なら start + poll をスキップ）
      _startupStep = StartupStep.checkingState;
      notifyListeners();
      final alreadyRunning = await _checkCurrentState(token);
      if (!alreadyRunning) {
        _startupStep = StartupStep.starting;
        notifyListeners();
        await _startEnvironment(token);

        _startupStep = StartupStep.waitingRunning;
        notifyListeners();
        await _pollUntilRunning(token);
      }

      // この時点で _state == running & SSH 認証情報が揃っている → UI を即解放
      _isLoading = false;
      notifyListeners();

      // 公開鍵の登録はバックグラウンドで実施（非ブロッキング）
      unawaited(_registerKeyNonBlocking(token));
    } catch (e) {
      _state = CloudShellState.error;
      _error = e is CloudShellException
          ? CloudShellFailure(e.kind)
          : CloudShellFailure(CloudShellFailureKind.unknown,
              detail: e.toString());
    } finally {
      _startupStep = StartupStep.idle;
      if (_isLoading) _isLoading = false; // エラーパスのみここで false
      notifyListeners();
    }
  }

  Future<void> _registerKeyNonBlocking(String token) async {
    _startupStep = StartupStep.registeringKey;
    notifyListeners();
    try {
      final publicKey = await _storage.getSshPublicKey();
      if (publicKey != null) {
        final trimmed = publicKey.trim();
        if (_remotePublicKeys.contains(trimmed)) {
          debugPrint('公開鍵は既に環境に登録済み。スキップします。');
        } else {
          await _registerPublicKey(token, trimmed);
        }
      }
    } catch (e) {
      debugPrint('公開鍵登録に失敗しました（非致命的）: $e');
    } finally {
      _startupStep = StartupStep.idle;
      notifyListeners();
    }
  }

  // ── 現在の状態を確認（RUNNING なら即完了） ───────────

  Future<bool> _checkCurrentState(String token) async {
    try {
      final response = await http
          .get(
            Uri.parse(
                '${AppConstants.cloudShellApiBase}/users/me/environments/default'),
            headers: {'Authorization': 'Bearer $token'},
          )
          .timeout(AppConstants.httpTimeout);
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        if (json['state'] == 'RUNNING') {
          _parseRunningState(json);
          debugPrint('Cloud Shell は既に起動中。ポーリングをスキップします。');
          return true;
        }
      }
    } catch (_) {}
    return false;
  }

  void _parseRunningState(Map<String, dynamic> json) {
    _sshHost = json['sshHost'] as String?;
    _sshUsername = json['sshUsername'] as String?;
    _sshPort = (json['sshPort'] as int?) ?? AppConstants.sshPort;
    _webHost = json['webHost'] as String?;
    _remotePublicKeys = (json['publicKeys'] as List<dynamic>?)
            ?.map((e) => e.toString().trim())
            .toList() ??
        [];
    debugPrint('登録済み公開鍵数: ${_remotePublicKeys.length}');
    _state = CloudShellState.running;
    notifyListeners();
    // 次回起動時の optimistic SSH 接続に使うため認証情報をキャッシュ
    if (_sshHost != null) {
      unawaited(_storage.saveCloudShellCredentials(
        host: _sshHost!,
        username: _sshUsername ?? 'user',
        port: _sshPort,
        webHost: _webHost,
      ));
    }
  }

  // ── Cloud Shell API: 起動 ─────────────────────────────

  Future<void> _startEnvironment(String token) async {
    final response = await http
        .post(
          Uri.parse(
              '${AppConstants.cloudShellApiBase}/users/me/environments/default:start'),
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
          body: '{}',
        )
        .timeout(AppConstants.httpTimeout);
    if (response.statusCode != 200 && response.statusCode != 204) {
      if (!response.body.contains('already')) {
        debugPrint('Start: HTTP ${response.statusCode}');
      }
    }
  }

  // ── Cloud Shell API: 状態ポーリング ──────────────────

  Future<void> _pollUntilRunning(String token) async {
    for (var i = 0; i < 40; i++) {
      // 初回は遅延なし、2回目以降は2秒待機
      if (i > 0) await Future.delayed(const Duration(seconds: 2));

      try {
        final response = await http
            .get(
              Uri.parse(
                  '${AppConstants.cloudShellApiBase}/users/me/environments/default'),
              headers: {'Authorization': 'Bearer $token'},
            )
            .timeout(AppConstants.httpTimeout);

        if (response.statusCode == 401) {
          throw const CloudShellException(CloudShellFailureKind.authExpired);
        }
        if (response.statusCode != 200) continue;

        final json = jsonDecode(response.body) as Map<String, dynamic>;
        final stateStr = json['state'] as String? ?? '';
        debugPrint('Cloud Shell state: $stateStr');

        if (stateStr == 'RUNNING') {
          _parseRunningState(json);
          return;
        }

        _pollAttempt = i;
        _state = CloudShellState.starting;
        notifyListeners();
      } on CloudShellException {
        // 認証エラーはリトライしても回復しないため即座に伝播させる
        rethrow;
      } catch (_) {
        // ネットワーク一時エラーは無視して継続
      }
    }

    throw const CloudShellException(CloudShellFailureKind.startTimeout);
  }

  // ── Cloud Shell API: SSH公開鍵を登録（リトライ付き） ──

  Future<void> _registerPublicKey(String token, String publicKey) async {
    // 最大3回試みる。500 の場合は新しい鍵ペアを生成して再試行
    String keyToRegister = publicKey.trim();

    for (var attempt = 1; attempt <= 3; attempt++) {
      debugPrint('addPublicKey 試行 $attempt/3');

      final response = await http
          .post(
            Uri.parse(
                '${AppConstants.cloudShellApiBase}/users/me/environments/default:addPublicKey'),
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({'key': keyToRegister}),
          )
          .timeout(AppConstants.httpTimeout);

      debugPrint('addPublicKey: HTTP ${response.statusCode}');

      // 成功
      if (response.statusCode == 200 || response.statusCode == 201) {
        // Long-running Operation の完了を待つ
        try {
          final op = jsonDecode(response.body) as Map<String, dynamic>;
          final opName = op['name'] as String?;
          if (opName != null) {
            await _pollOperation(token, opName);
          }
        } catch (_) {
          // Operationが取得できない場合は固定待機
          await Future.delayed(const Duration(seconds: 5));
        }
        return;
      }

      // 既に登録済みならOK
      if (response.body.contains('already') ||
          response.body.contains('ALREADY_EXISTS')) {
        debugPrint('公開鍵は既に登録済みです。スキップします。');
        return;
      }

      // 最終試行失敗 → throw せず警告のみ（前回セッションの鍵が有効な可能性あり）
      if (attempt == 3) {
        debugPrint('公開鍵登録に失敗しましたが、SSH接続を試みます（前回登録鍵が有効な可能性あり）');
        return;
      }

      // リトライ前に新しい鍵を生成
      final waitSec = attempt * 5;
      debugPrint('エラー (${response.statusCode})。新しい鍵ペアを生成して${waitSec}秒後に再試行...');
      await Future.delayed(Duration(seconds: waitSec));
      await _generateAndStoreSshKeyPair();
      keyToRegister = ((await _storage.getSshPublicKey()) ?? '').trim();
    }
  }

  // ── Long-running Operation のポーリング ──────────────

  Future<void> _pollOperation(String token, String operationName) async {
    final url = '${AppConstants.cloudShellApiBase}/$operationName';

    for (var i = 0; i < 30; i++) {
      // 初回は遅延なし、2回目以降は2秒待機
      if (i > 0) await Future.delayed(const Duration(seconds: 2));

      try {
        final response = await http
            .get(
              Uri.parse(url),
              headers: {'Authorization': 'Bearer $token'},
            )
            .timeout(AppConstants.httpTimeout);
        if (response.statusCode == 200) {
          final op = jsonDecode(response.body) as Map<String, dynamic>;
          if (op['done'] == true) {
            debugPrint('Operation 完了: $operationName');
            return;
          }
        }
      } catch (_) {}
    }
    // タイムアウトしても SSH 接続を試みる（楽観的継続）
    debugPrint('Operation タイムアウト。SSH接続を試みます: $operationName');
  }

  // ── SSH 鍵ペア生成 (RSA 2048) ────────────────────────

  Future<void> _generateAndStoreSshKeyPair() async {
    final secureRandom = FortunaRandom();
    final seedSource = Random.secure();
    final seeds = List<int>.generate(32, (_) => seedSource.nextInt(256));
    secureRandom.seed(KeyParameter(Uint8List.fromList(seeds)));

    final keyGen = RSAKeyGenerator()
      ..init(ParametersWithRandom(
        RSAKeyGeneratorParameters(BigInt.parse('65537'), 2048, 64),
        secureRandom,
      ));

    final pair = keyGen.generateKeyPair();
    final public = pair.publicKey;
    final private = pair.privateKey;

    final privatePem = _encodeRsaPrivatePem(private);
    final publicSsh = _encodeRsaPublicSsh(public);

    debugPrint('新しい公開鍵を生成しました: ${publicSsh.substring(0, 40)}...');
    await _storage.saveSshKeyPair(privatePem, publicSsh);
  }

  // ── RSA PEM/SSH エンコード ────────────────────────────

  String _encodeRsaPrivatePem(RSAPrivateKey key) {
    List<int> encodeLen(int len) {
      if (len < 0x80) return [len];
      if (len < 0x100) return [0x81, len];
      return [0x82, len >> 8, len & 0xff];
    }

    List<int> encodeInt(BigInt n) {
      var bytes = _bigIntToBytes(n);
      if (bytes[0] >= 0x80) bytes = [0x00, ...bytes];
      return [0x02, ...encodeLen(bytes.length), ...bytes];
    }

    final content = [
      ...encodeInt(BigInt.zero), // version
      ...encodeInt(key.n!),
      ...encodeInt(key.publicExponent!),
      ...encodeInt(key.privateExponent!),
      ...encodeInt(key.p!),
      ...encodeInt(key.q!),
      ...encodeInt(key.privateExponent! % (key.p! - BigInt.one)),
      ...encodeInt(key.privateExponent! % (key.q! - BigInt.one)),
      ...encodeInt(key.q!.modInverse(key.p!)),
    ];

    final der = Uint8List.fromList(
        [0x30, ...encodeLen(content.length), ...content]);
    final b64 = base64.encode(der);
    final lines =
        RegExp(r'.{1,64}').allMatches(b64).map((m) => m.group(0)!);
    return '-----BEGIN RSA PRIVATE KEY-----\n${lines.join('\n')}\n-----END RSA PRIVATE KEY-----';
  }

  String _encodeRsaPublicSsh(RSAPublicKey key) {
    final algoBytes = utf8.encode('ssh-rsa');
    final exponent = _bigIntToBytes(key.publicExponent!);
    // SSH wire format: exponent first, then modulus (both with sign byte if needed)
    final expWithSign =
        exponent[0] >= 0x80 ? [0x00, ...exponent] : exponent;
    final modulus = _bigIntToBytes(key.modulus!);
    final modWithSign =
        modulus[0] >= 0x80 ? [0x00, ...modulus] : modulus;

    final buf = BytesBuilder();
    void writeBytes(List<int> data) {
      final lenBytes = ByteData(4)..setUint32(0, data.length);
      buf.add(lenBytes.buffer.asUint8List());
      buf.add(data);
    }

    writeBytes(algoBytes);
    writeBytes(expWithSign);
    writeBytes(modWithSign);

    final b64 = base64.encode(buf.toBytes());
    // Cloud Shell API は "<format> <content>" の2フィールドのみ受け付ける
    return 'ssh-rsa $b64';
  }

  List<int> _bigIntToBytes(BigInt n) {
    var hex = n.toRadixString(16);
    if (hex.length % 2 != 0) hex = '0$hex';
    return List.generate(
        hex.length ~/ 2,
        (i) => int.parse(hex.substring(i * 2, i * 2 + 2), radix: 16));
  }
}
