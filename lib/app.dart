import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:kirikiri/l10n/app_localizations.dart';
import 'package:provider/provider.dart';

import 'core/feature_flag_service.dart';
import 'core/theme_service.dart';
import 'features/auth/google_auth_service.dart';
import 'features/cloudshell/cloud_shell_service.dart';
import 'features/github/github_service.dart';
import 'features/onboarding/onboarding_screen.dart';
import 'features/plugins/plugin_service.dart';
import 'features/ssh/ssh_connection_service.dart';
import 'home_screen.dart';
import 'theme/app_theme.dart';

class KirikiriApp extends StatefulWidget {
  const KirikiriApp({
    super.key,
    required this.isAuthenticated,
    this.showOnboarding = false,
  });
  final bool isAuthenticated;
  final bool showOnboarding;

  @override
  State<KirikiriApp> createState() => _KirikiriAppState();
}

class _KirikiriAppState extends State<KirikiriApp> {
  late final GoogleAuthService _authService;
  late final CloudShellService _cloudShellService;
  late final GitHubService _gitHubService;
  late final SshConnectionService _sshConnectionService;
  late final PluginService _pluginService;
  late final ThemeService _themeService;
  late final FeatureFlagService _featureFlagService;

  @override
  void initState() {
    super.initState();
    _authService = GoogleAuthService(initiallyAuthenticated: widget.isAuthenticated);
    _cloudShellService = CloudShellService();
    _gitHubService = GitHubService();
    _sshConnectionService = SshConnectionService();
    _pluginService = PluginService();
    _themeService = ThemeService();
    _featureFlagService = FeatureFlagService();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _themeService.load();
      _featureFlagService.load();
    });
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: _themeService),
        ChangeNotifierProvider.value(value: _authService),
        ChangeNotifierProvider.value(value: _cloudShellService),
        ChangeNotifierProvider.value(value: _gitHubService),
        ChangeNotifierProvider.value(value: _sshConnectionService),
        ChangeNotifierProvider.value(value: _pluginService),
        ChangeNotifierProvider.value(value: _featureFlagService),
      ],
      child: Consumer<ThemeService>(
        builder: (_, themeService, __) => MaterialApp(
          title: 'kirikiri',
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: themeService.themeMode,
          debugShowCheckedModeBanner: false,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [
            Locale('ja'),
            Locale('en'),
          ],
          home: widget.showOnboarding
              ? const OnboardingScreen()
              : const HomeScreen(),
        ),
      ),
    );
  }
}
