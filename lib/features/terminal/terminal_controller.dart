import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dartssh2/dartssh2.dart' show SSHClient;
import 'package:flutter/foundation.dart';
import 'package:xterm/xterm.dart' show Terminal;
import 'package:xterm/xterm.dart' as xterm_pkg show TerminalController;

import '../../core/known_hosts_service.dart';
import '../../core/notification_service.dart';
import '../../core/ssh_foreground_service.dart';
import '../preview/ssh_tunnel_service.dart';
import 'reconnect_policy.dart';
import 'remote_notification_parser.dart';
import 'ssh_service.dart';

/// UI 層から供給される表示文言。サービス層はロケールを知らないため、
/// ターミナルに書き出す文言はここを通して受け取る。
class TerminalMessages {
  const TerminalMessages({
    required this.describeFailure,
    required this.reconnecting,
  });

  final String Function(SshFailure failure) describeFailure;
  final String Function() reconnecting;
}

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
    _watchConnectivity();
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
  SshFailure? _failure;
  bool _isDisposed = false;

  SshConnectionState get connectionState => _connectionState;
  /// 直近の接続失敗。表示文言は UI 層が [messages] で決める。
  SshFailure? get failure => _failure;
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
          _reconnectPolicy.onConnected();
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
      _checkForNotifications(data);
    }));

    _subs.add(_ssh.errorStream.listen((failure) {
      if (_isDisposed) return;
      _failure = failure;
      _reconnectPolicy.onFailure(failure.kind);
      terminal.write(
          '\r\n\x1B[31m[kirikiri] ${_describe(failure)}\x1B[0m\r\n');
      notifyListeners();
    }));
  }

  /// 未知・変更されたホスト鍵をユーザーに確認するためのコールバック。
  /// 接続前に UI 層が設定する。未設定なら該当する鍵は拒否される。
  set onHostkeyPrompt(HostkeyPromptHandler? handler) =>
      _ssh.onHostkeyPrompt = handler;

  /// ターミナルに表示する文言。UI 層が接続前に設定する。
  /// 未設定の場合は技術的な詳細のみを表示する。
  TerminalMessages? messages;

  String _describe(SshFailure failure) =>
      messages?.describeFailure(failure) ??
      failure.detail ??
      failure.kind.name;

  // ── 自動再接続 ──────────────────────────────────────────
  //
  // モバイルでは通信の切り替わりやアプリの再開で接続が切れる。切断を防ぐ
  // ことはできないため、復帰を検知して自動で繋ぎ直す。リモート側の作業は
  // tmux が保持しているので、繋ぎ直せば元の画面に戻れる。

  final ReconnectPolicy _reconnectPolicy = ReconnectPolicy();
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  Timer? _reconnectDebounce;

  void _watchConnectivity() {
    _connectivitySub = Connectivity().onConnectivityChanged.listen((results) {
      final online =
          results.any((r) => r != ConnectivityResult.none);
      if (online) _scheduleReconnect();
    });
  }

  /// アプリが前面に戻ったときに UI 層から呼ぶ。
  /// iOS はバックグラウンドでソケットを維持できないため、復帰時はほぼ確実に
  /// 切れている。
  void onAppResumed() {
    _appInForeground = true;
    _scheduleReconnect();
  }

  /// アプリが背面へ回ったときに UI 層から呼ぶ。
  void onAppPaused() => _appInForeground = false;

  /// 通信の復帰イベントは短時間に連続して届くため、まとめて1回だけ試す。
  void _scheduleReconnect() {
    if (_isDisposed) return;
    if (!_reconnectPolicy.isAllowed) return;
    if (_connectionState == SshConnectionState.connected ||
        _connectionState == SshConnectionState.connecting) {
      return;
    }

    _reconnectDebounce?.cancel();
    _reconnectDebounce = Timer(const Duration(seconds: 1), () {
      if (_isDisposed || !_reconnectPolicy.isAllowed) return;
      if (_connectionState == SshConnectionState.connected ||
          _connectionState == SshConnectionState.connecting) {
        return;
      }
      _reconnectPolicy.onAttempt();
      unawaited(reconnect(
        notice: messages?.reconnecting(),
        userInitiated: false,
      ));
    });
  }

  // ── リモートからの通知 ──────────────────────────────────
  //
  // 長時間かかる処理を投げてアプリを離れたとき、終わったことを知る手段が
  // 必要になる。リモート側が送った通知シーケンスを拾って端末通知に変える。

  final RemoteNotificationParser _notificationParser =
      RemoteNotificationParser();

  /// アプリが前面にあるか。前面で見ているときに通知を出しても邪魔なので、
  /// 背面にいる間だけ通知する。
  bool _appInForeground = true;

  void _checkForNotifications(String data) {
    for (final notification in _notificationParser.feed(data)) {
      if (_appInForeground) continue;
      unawaited(NotificationService.instance.show(
        title: notification.title,
        body: notification.body,
      ));
    }
  }

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

  /// 利用者の操作による接続。自動再接続の試行回数をリセットする。
  Future<void> connect() async {
    _reconnectPolicy.onUserConnect();
    await _connect();
  }

  Future<void> _connect() async {
    _failure = null;
    notifyListeners();
    await _ssh.connect(
      cols: terminal.viewWidth > 0 ? terminal.viewWidth : 80,
      rows: terminal.viewHeight > 0 ? terminal.viewHeight : 24,
    );
  }

  Future<void> disconnect() async {
    // 利用者による切断。以後は自動で繋ぎ直さない。
    _reconnectPolicy.onUserDisconnect();
    await _ssh.disconnect();
    await SshForegroundService.stop();
  }

  /// JSランタイムがターミナル出力を購読するために公開
  Stream<String> get sshOutputStream => _ssh.outputStream;

  /// SftpServiceがSFTP操作に使用するSSHクライアント
  SshService get sshService => _ssh;

  /// 再接続する。[notice] が渡された場合はターミナルに表示する
  /// （文言は UI 層がロケールに応じて決める）。
  ///
  /// [userInitiated] が false のときは自動再接続なので、試行回数を
  /// リセットしない（リセットすると上限が効かず延々と再試行してしまう）。
  Future<void> reconnect({String? notice, bool userInitiated = true}) async {
    if (userInitiated) _reconnectPolicy.onUserConnect();
    if (notice != null) {
      terminal.write('\r\n\x1B[33m[kirikiri] $notice\x1B[0m\r\n');
    }
    _notificationParser.reset();
    await _ssh.disconnect();
    await Future.delayed(const Duration(milliseconds: 500));
    await _connect();
  }

  /// Detects ports with listening servers on the remote host.
  Future<List<int>> detectRunningPorts() =>
      _tunnelService?.detectRunningPorts() ?? Future.value([]);

  @override
  void dispose() {
    _isDisposed = true;
    _reconnectDebounce?.cancel();
    _connectivitySub?.cancel();
    for (final s in _subs) {
      s.cancel();
    }
    _ssh.dispose();
    SshForegroundService.stop();
    super.dispose();
  }
}
