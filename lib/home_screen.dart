import 'package:flutter/material.dart';
import 'package:kirikiri/l10n/app_localizations.dart';
import 'package:provider/provider.dart';

import 'features/account/account_screen.dart';
import 'features/auth/google_auth_service.dart';
import 'features/cloudshell/cloud_shell_screen.dart';
import 'features/cloudshell/cloud_shell_service.dart';
import 'features/github/github_service.dart';
import 'features/github/repo_list_screen.dart';
import 'features/plugins/plugin_manager_screen.dart';
import 'features/plugins/plugin_service.dart';
import 'features/ssh/ssh_connection_service.dart';
import 'features/ssh/ssh_servers_screen.dart';
import 'theme/app_theme.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() => setState(() {}));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<GitHubService>().init();
      context.read<SshConnectionService>().load();
      context.read<PluginService>().loadAll();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _switchToShellTab() {
    _tabController.animateTo(0);
  }

  void _confirmLogout(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(l.logoutConfirmTitle),
        content: Text(l.logoutConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l.cancel),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await context.read<GoogleAuthService>().signOut();
              if (context.mounted) {
                context.read<CloudShellService>().reset();
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: Text(l.logout),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            backgroundColor: AppColors.surface,
            title: _tabController.index == 0
                ? Consumer<CloudShellService>(
                    builder: (_, service, __) => Text(
                      service.pendingRepoName ?? l.tabCloudShell,
                    ),
                  )
                : Text([l.tabCloudShell, l.tabRepository, l.tabSsh, l.tabAccount][_tabController.index]),
            actions: [
              if (_tabController.index == 0)
                Consumer<GoogleAuthService>(
                  builder: (context, auth, _) => auth.isSignedIn
                      ? IconButton(
                          icon: const Icon(Icons.logout_rounded),
                          tooltip: l.logoutTooltip,
                          onPressed: () => _confirmLogout(context),
                        )
                      : const SizedBox.shrink(),
                ),
              Consumer<PluginService>(
                builder: (context, pluginService, _) => Stack(
                  alignment: Alignment.center,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.extension_rounded),
                      tooltip: l.pluginsTitle,
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ChangeNotifierProvider.value(
                            value: pluginService,
                            child: const PluginManagerScreen(),
                          ),
                        ),
                      ),
                    ),
                    if (pluginService.plugins.isNotEmpty)
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          body: TabBarView(
            controller: _tabController,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              const CloudShellScreen(),
              RepoListScreen(onSwitchToShell: _switchToShellTab),
              const SshServersScreen(),
              const AccountScreen(),
            ],
          ),
          bottomNavigationBar: Container(
            decoration: const BoxDecoration(
              border: Border(
                top: BorderSide(
                    color: AppColors.surfaceHighlight, width: 1),
              ),
            ),
            child: TabBar(
              controller: _tabController,
              indicatorColor: AppColors.primary,
              indicatorWeight: 2,
              labelColor: AppColors.primary,
              unselectedLabelColor: AppColors.textMuted,
              tabs: [
                Tab(
                  icon: const Icon(Icons.cloud_rounded),
                  text: l.tabCloudShell,
                  iconMargin: const EdgeInsets.only(bottom: 2),
                ),
                Tab(
                  icon: const Icon(Icons.source_rounded),
                  text: l.tabRepository,
                  iconMargin: const EdgeInsets.only(bottom: 2),
                ),
                Tab(
                  icon: const Icon(Icons.dns_rounded),
                  text: l.tabSsh,
                  iconMargin: const EdgeInsets.only(bottom: 2),
                ),
                Tab(
                  icon: const Icon(Icons.person_rounded),
                  text: l.tabAccount,
                  iconMargin: const EdgeInsets.only(bottom: 2),
                ),
              ],
            ),
          ),
        );
  }
}
