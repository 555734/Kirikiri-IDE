import 'package:flutter/material.dart';
import 'package:kirikiri/l10n/app_localizations.dart';
import 'package:provider/provider.dart';

import 'core/feature_flag_service.dart';
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
  late TabController _tabController;
  GoogleAuthService? _authRef;
  FeatureFlagService? _flagsRef;

  bool get _hasSshTab => _flagsRef?.sshTab ?? false;
  int get _tabCount => _hasSshTab ? 4 : 3;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabCount, vsync: this);
    _tabController.addListener(() => setState(() {}));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<GitHubService>().init();
      context.read<SshConnectionService>().load();
      context.read<PluginService>().loadAll();
      _authRef = context.read<GoogleAuthService>();
      _authRef!.addListener(_onAuthChanged);
      if (_authRef!.isSignedIn) {
        context.read<CloudShellService>().startAndConnect();
      }
      _flagsRef = context.read<FeatureFlagService>();
      _flagsRef!.addListener(_onFlagsChanged);
    });
  }

  void _onAuthChanged() {
    if (!mounted) return;
    if (_authRef?.isSignedIn == true) {
      context.read<CloudShellService>().startAndConnect();
    }
  }

  void _onFlagsChanged() {
    if (!mounted) return;
    final newCount = _tabCount;
    if (newCount == _tabController.length) return;
    final current = _tabController.index.clamp(0, newCount - 1);
    _tabController.dispose();
    _tabController = TabController(length: newCount, vsync: this, initialIndex: current);
    _tabController.addListener(() => setState(() {}));
    setState(() {});
  }

  @override
  void dispose() {
    _authRef?.removeListener(_onAuthChanged);
    _flagsRef?.removeListener(_onFlagsChanged);
    _tabController.dispose();
    super.dispose();
  }

  void _switchToShellTab() {
    _tabController.animateTo(0);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final flags = context.watch<FeatureFlagService>();
    final hasSsh = flags.sshTab;

    final tabTitles = [l.tabCloudShell, l.tabRepository, if (hasSsh) l.tabSsh, l.tabAccount];
    final tabChildren = [
      const CloudShellScreen(),
      RepoListScreen(onSwitchToShell: _switchToShellTab),
      if (hasSsh) const SshServersScreen(),
      const AccountScreen(),
    ];

    final isCloudShellTab = _tabController.index == 0;
    return Scaffold(
          backgroundColor: AppColors.background,
          appBar: isCloudShellTab ? null : AppBar(
            backgroundColor: AppColors.surface,
            title: Text(tabTitles[_tabController.index]),
            actions: [
              if (flags.plugins)
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
            children: tabChildren,
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
                Tab(icon: const Icon(Icons.cloud_rounded), text: l.tabCloudShell,
                    iconMargin: const EdgeInsets.only(bottom: 2)),
                Tab(icon: const Icon(Icons.source_rounded), text: l.tabRepository,
                    iconMargin: const EdgeInsets.only(bottom: 2)),
                if (hasSsh)
                  Tab(icon: const Icon(Icons.dns_rounded), text: l.tabSsh,
                      iconMargin: const EdgeInsets.only(bottom: 2)),
                Tab(icon: const Icon(Icons.person_rounded), text: l.tabAccount,
                    iconMargin: const EdgeInsets.only(bottom: 2)),
              ],
            ),
          ),
        );
  }
}
