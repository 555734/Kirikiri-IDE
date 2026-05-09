import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:dartssh2/dartssh2.dart';

import '../../core/constants.dart';

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

  SSHClient? _client;
  SSHSession? _session;

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

  Future<void> connect({int cols = 80, int rows = 24}) async {
    if (_state == SshConnectionState.connecting ||
        _state == SshConnectionState.connected) return;

    _log.clear();
    _termCols = cols;
    _termRows = rows;
    _setState(SshConnectionState.connecting);

    try {
      final port = sshPort ?? AppConstants.sshPort;
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
        );
      } else {
        // パスワード認証
        _addLog('パスワード認証を試みます (トークン長: ${ownerToken?.length ?? 0})');
        _client = SSHClient(
          socket,
          username: username,
          onPasswordRequest: () => ownerToken ?? '',
          keepAliveInterval: AppConstants.sshKeepalive,
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
    } on SSHAuthAbortError catch (e) {
      _addLog('認証エラー(Abort): $e');
      _handleError('SSH認証に失敗しました: $e');
    } on SSHAuthFailError catch (e) {
      _addLog('認証エラー(Fail): $e');
      _handleError('SSH認証が拒否されました: $e');
    } catch (e) {
      _addLog('例外: $e');
      _handleError('接続エラー: $e');
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

    session.stderr?.listen(
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
