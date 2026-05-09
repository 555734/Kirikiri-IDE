import 'package:flutter/material.dart';
import 'package:kirikiri/l10n/app_localizations.dart';
import 'package:provider/provider.dart';

import '../../core/constants.dart';
import '../../core/screenshot_mode.dart';
import '../../core/secure_storage_service.dart';
import '../../theme/app_theme.dart';
import '../../features/auth/google_auth_service.dart';
import '../../features/preview/port_tunnel_config_service.dart';
import '../../features/preview/ssh_tunnel_service.dart';
import '../../features/terminal/demo_terminal_screen.dart';
import '../../features/terminal/terminal_controller.dart';
import '../../features/terminal/terminal_screen.dart';
import 'cloud_shell_service.dart';

/// Google Cloud Shell メイン画面
class CloudShellScreen extends StatefulWidget {
  const CloudShellScreen({super.key});

  @override
  State<CloudShellScreen> createState() => _CloudShellScreenState();
}

class _CloudShellScreenState extends State<CloudShellScreen> {
  @override
  Widget build(BuildContext context) {
    if (kDemoMode) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: _buildDemoRunningView(context),
      );
    }
    return Consumer<GoogleAuthService>(
      builder: (context, auth, _) {
        if (!auth.isSignedIn) {
          return Scaffold(
            backgroundColor: AppColors.background,
            body: _buildLoginView(context, auth),
          );
        }
        // サインイン済み → 即座にターミナルフレームを表示（起動オーバーレイ付き）
        return const Scaffold(
          backgroundColor: AppColors.terminalBackground,
          body: _EagerTerminalView(),
        );
      },
    );
  }

  // ── ログインビュー ─────────────────────────────────────

  Widget _buildLoginView(BuildContext context, GoogleAuthService auth) {
    final l = AppLocalizations.of(context)!;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFFEF4444), Color(0xFFB91C1C)],
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.30),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: const Icon(Icons.terminal_rounded,
                  color: Colors.white, size: 46),
            ),
            const SizedBox(height: 24),
            Text(
              l.cloudShellTitle,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 24,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              l.cloudShellSignInPrompt,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
            ),
            if (auth.error != null) ...[
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.error.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                  border:
                      Border.all(color: AppColors.error.withOpacity(0.4)),
                ),
                child: Text(
                  auth.error!,
                  style: const TextStyle(color: AppColors.errorLight),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: auth.isLoading
                    ? null
                    : () => auth.signIn(
                          onSuccess: () {
                            if (context.mounted) {
                              context
                                  .read<CloudShellService>()
                                  .startAndConnect();
                            }
                          },
                        ),
                icon: auth.isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.login_rounded),
                label: Text(auth.isLoading ? l.loggingIn : l.loginWithGoogle),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(
                      vertical: 16, horizontal: 24),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  textStyle: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              l.googleAccountOnly,
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            TextButton(
              onPressed: () {
                enableRuntimeDemoMode();
                setState(() {});
              },
              child: Text(
                l.tryDemo,
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 13),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDemoRunningView(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppColors.success.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle_rounded,
                  color: AppColors.success, size: 36),
            ),
            const SizedBox(height: 16),
            Text(
              l.cloudShellRunning,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'cloudshell.googleusercontent.com',
              style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 11,
                  fontFamily: 'monospace'),
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => const DemoTerminalScreen(title: 'Cloud Shell'),
                )),
                icon: const Icon(Icons.terminal_rounded),
                label: Text(l.openTerminal),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  textStyle: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── 即時ターミナルビュー（Cloud Shell 起動と並行してターミナルフレームを表示） ──

class _EagerTerminalView extends StatefulWidget {
  const _EagerTerminalView();

  @override
  State<_EagerTerminalView> createState() => _EagerTerminalViewState();
}

class _EagerTerminalViewState extends State<_EagerTerminalView> {
  CloudShellService? _serviceRef;
  PortTunnelConfigService? _tunnelConfig;
  SshTunnelService? _tunnelService;
  TerminalController? _ctrl;
  String? _privateKey;
  int _handledPendingVersion = 0;
  String? _overrideInitialCommand;

  // キャッシュ済み Cloud Shell 認証情報（optimistic SSH 接続用）
  String? _cachedSshHost;
  String? _cachedSshUsername;
  int _cachedSshPort = AppConstants.sshPort;
  String? _cachedWebHost;
  String? _ctrlHost; // コントローラ生成時に使用したホスト

  @override
  void initState() {
    super.initState();
    // 秘密鍵とキャッシュ済み認証情報を並列でロード
    SecureStorageService.instance.getSshPrivateKey().then((key) {
      if (!mounted) return;
      setState(() => _privateKey = key);
      _maybeInitController();
    });
    SecureStorageService.instance.getCloudShellCredentials().then((creds) {
      if (!mounted || creds == null) return;
      setState(() {
        _cachedSshHost = creds['host'] as String?;
        _cachedSshUsername = creds['username'] as String?;
        _cachedSshPort = (creds['port'] as int?) ?? AppConstants.sshPort;
        _cachedWebHost = creds['webHost'] as String?;
      });
      _maybeInitController();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _serviceRef = context.read<CloudShellService>();
      _serviceRef!.addListener(_onServiceChanged);
      _onServiceChanged();
    });
  }

  @override
  void dispose() {
    _serviceRef?.removeListener(_onServiceChanged);
    _ctrl?.disconnect().ignore();
    _ctrl?.dispose();
    _tunnelService?.dispose();
    _tunnelConfig?.dispose();
    super.dispose();
  }

  void _onServiceChanged() {
    if (!mounted) return;
    _maybeInitController();
    _maybeSendPendingCommand();
  }

  void _maybeInitController() {
    final service = _serviceRef ?? context.read<CloudShellService>();
    if (_privateKey == null) return;

    // ライブ認証情報を優先、なければキャッシュ済みで optimistic 接続
    final host = (service.isRunning ? service.sshHost : null) ?? _cachedSshHost;
    if (host == null || host.isEmpty) return;

    if (_ctrl != null) {
      // ホストが変わった場合（Cloud Shell 再起動後）はコントローラを再生成
      if (_ctrlHost == host) return;
      _ctrl!.disconnect().ignore();
      _ctrl!.dispose();
      _tunnelService?.dispose();
      _tunnelConfig?.dispose();
      _ctrlHost = null;
      setState(() { _ctrl = null; _tunnelService = null; _tunnelConfig = null; });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _maybeInitController();
      });
      return;
    }

    final username = (service.isRunning ? service.sshUsername : null) ?? _cachedSshUsername ?? 'user';
    final port = service.isRunning ? service.sshPort : _cachedSshPort;
    final webHost = (service.isRunning ? service.webHost : null) ?? _cachedWebHost;

    final repoCommand = _overrideInitialCommand
        ?? _buildInitialCommand(service.consumePendingShellCommand());
    _overrideInitialCommand = null;
    _handledPendingVersion = service.pendingVersion;
    _ctrlHost = host;

    final config = PortTunnelConfigService();
    final tunnel = SshTunnelService(connectionId: 'cloudshell', configService: config);
    final ctrl = TerminalController(
      workspaceId: service.pendingRepoName ?? 'cloudshell',
      sshHost: host,
      ownerToken: null,
      sshPrivateKeyPem: _privateKey,
      sshUsername: username,
      sshPort: port,
      initialCommand: repoCommand,
      webHost: webHost,
      tunnelService: tunnel,
    );

    setState(() {
      _tunnelConfig = config;
      _tunnelService = tunnel;
      _ctrl = ctrl;
    });
  }

  void _maybeSendPendingCommand() {
    final service = _serviceRef;
    if (service == null) return;
    if (service.pendingRepoName == null) return;
    if (service.pendingVersion <= _handledPendingVersion) return;
    _handledPendingVersion = service.pendingVersion;

    if (_ctrl != null) {
      // 既存コントローラを破棄し、新コマンドで再生成
      final rawCmd = service.consumePendingShellCommand();
      _overrideInitialCommand = _buildInitialCommand(rawCmd);
      _ctrl?.disconnect().ignore();
      _ctrl?.dispose();
      _tunnelService?.dispose();
      _tunnelConfig?.dispose();
      setState(() {
        _ctrl = null;
        _tunnelService = null;
        _tunnelConfig = null;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _maybeInitController();
      });
    }
    // ctrl == null の場合は _maybeInitController が起動時にコマンドを拾う
  }

  @override
  Widget build(BuildContext context) {
    final service = context.watch<CloudShellService>();

    return Stack(
      children: [
        if (_ctrl != null)
          MultiProvider(
            providers: [
              ChangeNotifierProvider<PortTunnelConfigService>.value(
                  value: _tunnelConfig!),
              ChangeNotifierProvider<SshTunnelService>.value(
                  value: _tunnelService!),
              ChangeNotifierProvider<TerminalController>.value(value: _ctrl!),
            ],
            child: const TerminalScreen(embedded: true),
          )
        else
          const SizedBox.expand(),

        if (service.state == CloudShellState.error)
          _buildErrorOverlay(context, service),
      ],
    );
  }

  Widget _buildErrorOverlay(BuildContext context, CloudShellService service) {
    final l = AppLocalizations.of(context)!;
    return Container(
      color: AppColors.terminalBackground,
      child: Center(
        child: Container(
          margin: const EdgeInsets.all(32),
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.error.withOpacity(0.20)),
            boxShadow: [
              BoxShadow(
                color: AppColors.error.withOpacity(0.08),
                blurRadius: 24,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded,
                  color: AppColors.error, size: 48),
              const SizedBox(height: 16),
              Text(l.cloudShellError,
                  style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              Text(
                service.error ?? '',
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 28),
              ElevatedButton.icon(
                onPressed: () =>
                    context.read<CloudShellService>().startAndConnect(),
                icon: const Icon(Icons.refresh_rounded),
                label: Text(l.retry),
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _buildInitialCommand(String? repoCommand) {
    const s = 'k';
    if (repoCommand == null) return 'tmux new-session -A -s $s';
    final escaped = repoCommand.replaceAll("'", r"'\''");
    return "tmux new-session -d -s $s 2>/dev/null || true; "
        "tmux send-keys -t $s '$escaped' Enter; "
        "tmux attach-session -t $s";
  }
}

