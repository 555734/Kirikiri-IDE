import 'package:flutter/material.dart';
import 'package:kirikiri/l10n/app_localizations.dart';
import 'package:provider/provider.dart';

import '../../core/screenshot_mode.dart';
import '../../core/secure_storage_service.dart';
import '../../theme/app_theme.dart';
import '../../features/auth/google_auth_service.dart';
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
  int _handledPendingVersion = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (context.read<GoogleAuthService>().isSignedIn) {
        context.read<CloudShellService>().startAndConnect();
      }
    });
  }

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
        return Scaffold(
          backgroundColor: AppColors.background,
          body: auth.isSignedIn
              ? Consumer<CloudShellService>(
                  builder: (context, service, _) {
                    if (service.isLoading ||
                        service.state == CloudShellState.starting) {
                      return _buildLoadingView(service);
                    }
                    if (service.state == CloudShellState.error) {
                      return _buildErrorView(service);
                    }
                    if (service.isRunning) {
                      if (service.pendingRepoName != null &&
                          service.pendingVersion > _handledPendingVersion) {
                        _handledPendingVersion = service.pendingVersion;
                        WidgetsBinding.instance.addPostFrameCallback(
                            (_) => _openTerminal(context, service));
                      }
                      return _buildRunningView(context, service);
                    }
                    return _buildIdleView(context, service);
                  },
                )
              : _buildLoginView(context, auth),
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
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Icon(Icons.terminal_rounded,
                  color: Colors.white, size: 40),
            ),
            const SizedBox(height: 24),
            Text(
              l.cloudShellTitle,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 20,
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
                  padding: const EdgeInsets.symmetric(vertical: 16),
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

  // ── 接続中ビュー ────────────────────────────────────────

  Widget _buildLoadingView(CloudShellService service) {
    final l = AppLocalizations.of(context)!;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(color: AppColors.primary),
          const SizedBox(height: 24),
          Text(
            service.pendingRepoName != null
                ? l.preparingRepo(service.pendingRepoName!)
                : l.cloudShellStarting,
            style:
                const TextStyle(color: AppColors.textPrimary, fontSize: 16),
          ),
          const SizedBox(height: 8),
          Text(
            l.cloudShellFirstLaunchNote,
            style: const TextStyle(color: AppColors.textSecondary),
          ),
        ],
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

  Widget _buildRunningView(BuildContext context, CloudShellService service) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.success.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle_rounded,
                  color: AppColors.success, size: 40),
            ),
            const SizedBox(height: 24),
            Text(
              AppLocalizations.of(context)!.cloudShellRunning,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              service.sshHost ?? '',
              style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                  fontFamily: 'monospace'),
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _openTerminal(context, service),
                icon: const Icon(Icons.terminal_rounded),
                label: Text(AppLocalizations.of(context)!.openTerminal),
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

  Widget _buildErrorView(CloudShellService service) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded,
                color: AppColors.error, size: 48),
            const SizedBox(height: 16),
            Text(AppLocalizations.of(context)!.cloudShellError,
                style: const TextStyle(
                    color: AppColors.errorLight,
                    fontSize: 18,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            Text(
              service.error ?? '',
              textAlign: TextAlign.center,
              style:
                  const TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 28),
            ElevatedButton.icon(
              onPressed: () =>
                  context.read<CloudShellService>().startAndConnect(),
              icon: const Icon(Icons.refresh_rounded),
              label: Text(AppLocalizations.of(context)!.retry),
              style:
                  ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIdleView(BuildContext context, CloudShellService service) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_outlined,
              color: AppColors.textMuted, size: 64),
          const SizedBox(height: 16),
          Text(AppLocalizations.of(context)!.cloudShellStopped,
              style: const TextStyle(color: AppColors.textSecondary)),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => service.startAndConnect(),
            icon: const Icon(Icons.play_arrow_rounded),
            label: Text(AppLocalizations.of(context)!.cloudShellStartButton),
            style:
                ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
          ),
        ],
      ),
    );
  }

  void _openTerminal(BuildContext context, CloudShellService service) async {
    final privateKey = await SecureStorageService.instance.getSshPrivateKey();
    final repoCommand = service.consumePendingShellCommand();
    if (!context.mounted) return;
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ChangeNotifierProvider(
        create: (_) => TerminalController(
          workspaceId: service.pendingRepoName ?? 'cloudshell',
          sshHost: service.sshHost ?? '',
          ownerToken: null,
          sshPrivateKeyPem: privateKey,
          sshUsername: service.sshUsername ?? 'user',
          sshPort: service.sshPort,
          initialCommand: _buildInitialCommand(repoCommand),
          webHost: service.webHost,
        ),
        child: const TerminalScreen(),
      ),
    )).then((_) {
      if (mounted) setState(() {});
    });
  }

  String _buildInitialCommand(String? repoCommand) {
    const s = 'k';
    if (repoCommand == null) {
      return 'tmux new-session -A -s $s';
    }
    final escaped = repoCommand.replaceAll("'", r"'\''");
    return "tmux new-session -d -s $s 2>/dev/null || true; "
        "tmux send-keys -t $s '$escaped' Enter; "
        "tmux attach-session -t $s";
  }

}
