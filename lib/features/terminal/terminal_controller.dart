import 'dart:async';
import 'package:dartssh2/dartssh2.dart' show SSHClient;
import 'package:flutter/foundation.dart';
import 'package:xterm/xterm.dart' show Terminal;
import 'package:xterm/xterm.dart' as xterm_pkg show TerminalController;

import '../../core/known_hosts_service.dart';
import '../../core/ssh_foreground_service.dart';
import '../preview/ssh_tunnel_service.dart';
import 'ssh_service.dart';

/// xterm の Terminal と SshService を橋渡しするコントローラー
class TerminalController extends ChangeNotifier {
  TerminalController({
    required this.workspaceId,
    required String sshHost,
    String? ownerToken,
    String? sshPrivateKeyPem,
    String? sshUsername,
    int? sshPort,
    this.initialCommand,
    this.webHost,
    this.onBeforeInitialCommand,
    SshTunnelService? tunnelService,
  }) : _ssh = SshService(
          workspaceId: workspaceId,
          sshHost: sshHost,
          ownerToken: ownerToken,
          sshPrivateKeyPem: sshPrivateKeyPem,
          sshUsername: sshUsername,
          sshPort: sshPort,
        ),
        _tunnelService = tunnelService {
    _initTerminal();
    _subscribeToSsh();
  }

  final String workspaceId;
  final String? initialCommand;
  final String? webHost;

  /// 接続確立後、[initialCommand] を送信する前に実行されるフック。
  /// ターミナルに出したくない準備処理（資格情報の登録など）に使う。
  final Future<void> Function(SSHClient client)? onBeforeInitialCommand;
  final SshService _ssh;
  final SshTunnelService? _tunnelService;

  late final Terminal terminal;
  late final xterm_pkg.TerminalController xtermController;

  SshConnectionState _connectionState = SshConnectionState.disconnected;
  String? _errorMessage;
  bool _isDisposed = false;

  SshConnectionState get connectionState => _connectionState;
  String? get errorMessage => _errorMessage;
  bool get isConnected => _connectionState == SshConnectionState.connected;
  List<String> get sshLog => _ssh.log;

  /// Exposes the tunnel service for use by the terminal screen UI.
  SshTunnelService? get tunnels => _tunnelService;

  final List<StreamSubscription> _subs = [];

  void _initTerminal() {
    terminal = Terminal(maxLines: 20000);
    xtermController = xterm_pkg.TerminalController();
    terminal.onOutput = (data) => _ssh.write(data);
    terminal.onResize = (cols, rows, _, __) => _ssh.resize(cols, rows);
  }

  void _subscribeToSsh() {
    _subs.add(_ssh.stateStream.listen((state) {
      if (_isDisposed) return;
      _connectionState = state;

      switch (state) {
        case SshConnectionState.connected:
          // バックグラウンド維持のためフォアグラウンドサービスを開始
          SshForegroundService.start(
            label: workspaceId,
            hostInfo: '${_ssh.sshUsername ?? ''}@${_ssh.sshHost}',
          );
          // ポートトンネルを有効化
          if (_ssh.sshClient != null) {
            _tunnelService?.onSshConnected(_ssh.sshClient!);
          }
          // 初期コマンドを一度だけ送信
          if (initialCommand != null) {
            unawaited(_runInitialCommand());
          }
        case SshConnectionState.disconnected:
        case SshConnectionState.error:
          _tunnelService?.onSshDisconnected();
          SshForegroundService.stop();
        case SshConnectionState.connecting:
          break;
      }

      notifyListeners();
    }));

    _subs.add(_ssh.outputStream.listen((data) {
      if (_isDisposed) return;
      terminal.write(data);
    }));

    _subs.add(_ssh.errorStream.listen((msg) {
      if (_isDisposed) return;
      _errorMessage = msg;
      terminal.write('\r\n\x1B[31m[kirikiri] $msg\x1B[0m\r\n');
      notifyListeners();
    }));
  }

  /// 未知・変更されたホスト鍵をユーザーに確認するためのコールバック。
  /// 接続前に UI 層が設定する。未設定なら該当する鍵は拒否される。
  set onHostkeyPrompt(HostkeyPromptHandler? handler) =>
      _ssh.onHostkeyPrompt = handler;

  /// 準備フックを実行してから初期コマンドを送信する。
  Future<void> _runInitialCommand() async {
    final hook = onBeforeInitialCommand;
    final client = _ssh.sshClient;
    if (hook != null && client != null) {
      try {
        await hook(client);
      } catch (e) {
        // 準備に失敗しても接続自体は維持し、警告のみ表示する
        if (!_isDisposed) {
          terminal.write('\r\n\x1B[33m[kirikiri] $e\x1B[0m\r\n');
        }
      }
    }

    await Future.delayed(const Duration(milliseconds: 800));
    if (_isDisposed || _connectionState != SshConnectionState.connected) return;
    _ssh.write('$initialCommand\n');
  }

  Future<void> connect() async {
    _errorMessage = null;
    notifyListeners();
    await _ssh.connect(
      cols: terminal.viewWidth > 0 ? terminal.viewWidth : 80,
      rows: terminal.viewHeight > 0 ? terminal.viewHeight : 24,
    );
  }

  Future<void> disconnect() async {
    await _ssh.disconnect();
    await SshForegroundService.stop();
  }

  /// JSランタイムがターミナル出力を購読するために公開
  Stream<String> get sshOutputStream => _ssh.outputStream;

  /// SftpServiceがSFTP操作に使用するSSHクライアント
  SshService get sshService => _ssh;

  Future<void> reconnect() async {
    terminal.write('\r\n\x1B[33m[kirikiri] 再接続中...\x1B[0m\r\n');
    await _ssh.disconnect();
    await Future.delayed(const Duration(milliseconds: 500));
    await connect();
  }

  /// Detects ports with listening servers on the remote host.
  Future<List<int>> detectRunningPorts() =>
      _tunnelService?.detectRunningPorts() ?? Future.value([]);

  @override
  void dispose() {
    _isDisposed = true;
    for (final s in _subs) {
      s.cancel();
    }
    _ssh.dispose();
    SshForegroundService.stop();
    super.dispose();
  }
}
