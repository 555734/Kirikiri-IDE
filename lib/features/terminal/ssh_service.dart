import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:dartssh2/dartssh2.dart';

import '../../core/constants.dart';
import '../../core/known_hosts_service.dart';

enum SshConnectionState { disconnected, connecting, connected, error }

/// dartssh2 を使って SSH 接続するサービス
/// パスワード認証とSSH鍵認証の両方に対応
class SshService {
  SshService({
    required this.workspaceId,
    required this.sshHost,
    this.ownerToken,
    this.sshPrivateKeyPem,
    this.sshUsername,
    this.sshPort,
  });

  final String workspaceId;
  final String sshHost;
  final String? ownerToken;       // パスワード認証用 (旧GitPod)
  final String? sshPrivateKeyPem; // SSH鍵認証用 (Cloud Shell)
  final String? sshUsername;
  final int? sshPort;

  /// 未知・変更されたホスト鍵をユーザーに確認するためのコールバック。
  ///
  /// UI 層（TerminalScreen）が接続前に設定する。未設定の場合、保存済みの
  /// 指紋と一致しないホスト鍵はすべて拒否される（フェイルセーフ）。
  HostkeyPromptHandler? onHostkeyPrompt;

  SSHClient? _client;
  SSHSession? _session;

  /// ホスト鍵検証で接続を拒否した理由。connect() のエラー整形に使う。
  String? _hostkeyRejection;

  final _stateController = StreamController<SshConnectionState>.broadcast();
  final _outputController = StreamController<String>.broadcast();
  final _errorMessageController = StreamController<String>.broadcast();

  Stream<SshConnectionState> get stateStream => _stateController.stream;
  Stream<String> get outputStream => _outputController.stream;
  Stream<String> get errorStream => _errorMessageController.stream;

  SshConnectionState _state = SshConnectionState.disconnected;
  SshConnectionState get state => _state;

  // アプリ内ログ（デバッグプリント不要でUIに表示可能）
  final List<String> _log = [];
  List<String> get log => List.unmodifiable(_log);

  void _addLog(String msg) {
    final ts = DateTime.now().toIso8601String().substring(11, 23);
    _log.add('[$ts] $msg');
  }

  int _termCols = AppConstants.terminalInitialCols;
  int _termRows = AppConstants.terminalInitialRows;

  int _resolvedPort = AppConstants.sshPort;

  /// サーバーのホスト鍵を known_hosts と照合する。
  ///
  /// dartssh2 は onVerifyHostKey を渡さないとホスト鍵を無検証で受け入れるため、
  /// このハンドラを必ず指定すること。
  Future<bool> _verifyHostkey(String keyType, Uint8List digest) async {
    final fingerprint = KnownHostsService.formatFingerprint(digest);
    final knownHosts = KnownHostsService.instance;
    final verdict = await knownHosts.verify(
      sshHost,
      _resolvedPort,
      keyType,
      fingerprint,
    );

    if (verdict == HostkeyVerdict.trusted) {
      _addLog('ホスト鍵: 既知の鍵と一致 ($keyType $fingerprint)');
      return true;
    }

    final prompt = onHostkeyPrompt;
    if (prompt == null) {
      // 確認手段がないまま未知の鍵を受け入れると中間者攻撃を検出できない
      _addLog('ホスト鍵: 未確認のため拒否 ($keyType $fingerprint)');
      _hostkeyRejection = 'サーバーのホスト鍵を確認できなかったため接続を中止しました。';
      return false;
    }

    final known = verdict == HostkeyVerdict.changed
        ? await knownHosts.fingerprintOf(sshHost, _resolvedPort, keyType)
        : null;
    _addLog(
      'ホスト鍵: ${verdict == HostkeyVerdict.changed ? "変更を検出" : "未登録"} '
      '($keyType $fingerprint)',
    );

    final accepted = await prompt(HostkeyRequest(
      host: sshHost,
      port: _resolvedPort,
      keyType: keyType,
      fingerprint: fingerprint,
      verdict: verdict,
      knownFingerprint: known,
    ));

    if (!accepted) {
      _addLog('ホスト鍵: ユーザーが拒否');
      _hostkeyRejection = verdict == HostkeyVerdict.changed
          ? 'サーバーのホスト鍵が変更されています。中間者攻撃の可能性があるため接続を中止しました。'
          : 'ホスト鍵が承認されなかったため接続を中止しました。';
      return false;
    }

    await knownHosts.trust(sshHost, _resolvedPort, keyType, fingerprint);
    _addLog('ホスト鍵: ユーザーが承認し保存しました');
    return true;
  }

  Future<void> connect({int cols = 80, int rows = 24}) async {
    if (_state == SshConnectionState.connecting ||
        _state == SshConnectionState.connected) return;

    _log.clear();
    _hostkeyRejection = null;
    _termCols = cols;
    _termRows = rows;
    _setState(SshConnectionState.connecting);

    try {
      final port = sshPort ?? AppConstants.sshPort;
      _resolvedPort = port;
      final username = sshUsername ?? workspaceId;

      _addLog('接続先: $sshHost:$port');
      _addLog('ユーザー名: $username');
      _addLog('認証方式: ${sshPrivateKeyPem != null ? "SSH鍵" : "パスワード"}');

      final socket = await SSHSocket.connect(
        sshHost,
        port,
        timeout: Duration(seconds: AppConstants.sshConnectTimeoutSeconds),
      );
      _addLog('TCP接続: 成功');

      // SSH鍵認証かパスワード認証かを選択
      if (sshPrivateKeyPem != null && sshPrivateKeyPem!.isNotEmpty) {
        // SSH鍵認証 (Cloud Shell)
        _addLog('SSH鍵を解析中...');
        final keyPairs = SSHKeyPair.fromPem(sshPrivateKeyPem!);
        _addLog('鍵ペア数: ${keyPairs.length}');
        _client = SSHClient(
          socket,
          username: username,
          identities: keyPairs,
          keepAliveInterval: AppConstants.sshKeepalive,
          onVerifyHostKey: _verifyHostkey,
        );
      } else {
        // パスワード認証
        _addLog('パスワード認証を試みます (トークン長: ${ownerToken?.length ?? 0})');
        _client = SSHClient(
          socket,
          username: username,
          onPasswordRequest: () => ownerToken ?? '',
          keepAliveInterval: AppConstants.sshKeepalive,
          onVerifyHostKey: _verifyHostkey,
        );
      }

      _addLog('SSH認証を待機中...');
      await _client!.authenticated;
      _addLog('SSH認証: 成功');

      _session = await _client!.shell(
        pty: SSHPtyConfig(
          type: 'xterm-256color',
          width: _termCols,
          height: _termRows,
        ),
      );
      _addLog('シェルセッション: 開始');

      _setState(SshConnectionState.connected);
      _listenToSession();
    } on SSHHostkeyError catch (e) {
      _addLog('ホスト鍵エラー: $e');
      _handleError(_hostkeyRejection ?? 'ホスト鍵の検証に失敗しました: $e');
    } on SSHAuthAbortError catch (e) {
      _addLog('認証エラー(Abort): $e');
      // ホスト鍵を拒否すると接続が閉じられ、認証中断として観測されることがある
      _handleError(_hostkeyRejection ?? 'SSH認証に失敗しました: $e');
    } on SSHAuthFailError catch (e) {
      _addLog('認証エラー(Fail): $e');
      _handleError(_hostkeyRejection ?? 'SSH認証が拒否されました: $e');
    } catch (e) {
      _addLog('例外: $e');
      _handleError(_hostkeyRejection ?? '接続エラー: $e');
    }
  }

  void _listenToSession() {
    final session = _session;
    if (session == null) return;

    session.stdout.listen(
      (data) => _outputController.add(utf8.decode(data, allowMalformed: true)),
      onError: (_) {},
      onDone: _onSessionDone,
      cancelOnError: false,
    );

    session.stderr.listen(
      (data) => _outputController.add(utf8.decode(data, allowMalformed: true)),
      onError: (_) {},
      cancelOnError: false,
    );

    session.done.then((_) => _onSessionDone());
  }

  void _onSessionDone() {
    if (_state != SshConnectionState.error) {
      _setState(SshConnectionState.disconnected);
    }
  }

  void write(String data) {
    if (_session == null || _state != SshConnectionState.connected) return;
    _session!.stdin.add(utf8.encode(data));
  }

  void writeBytes(List<int> bytes) {
    if (_session == null || _state != SshConnectionState.connected) return;
    _session!.stdin.add(Uint8List.fromList(bytes));
  }

  void resize(int cols, int rows) {
    if (_state != SshConnectionState.connected) return;
    if (cols == _termCols && rows == _termRows) return;
    _termCols = cols;
    _termRows = rows;
    _session?.resizeTerminal(cols, rows);
  }

  /// Exposes the underlying SSH client for port-forwarding use.
  SSHClient? get sshClient => _client;

  Future<void> disconnect() async {
    _session?.close();
    _client?.close();
    _session = null;
    _client = null;
    _setState(SshConnectionState.disconnected);
  }

  void _setState(SshConnectionState newState) {
    _state = newState;
    if (!_stateController.isClosed) _stateController.add(newState);
  }

  void _handleError(String message) {
    _state = SshConnectionState.error;
    if (!_stateController.isClosed) {
      _stateController.add(SshConnectionState.error);
    }
    if (!_errorMessageController.isClosed) {
      _errorMessageController.add(message);
    }
  }

  Future<void> dispose() async {
    await disconnect();
    await _stateController.close();
    await _outputController.close();
    await _errorMessageController.close();
  }

  /// SFTPクライアント取得用（SftpServiceのみ使用）
  SSHClient? get rawClient => _client;
}
