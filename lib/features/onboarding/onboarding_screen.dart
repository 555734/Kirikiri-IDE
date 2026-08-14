import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kirikiri/l10n/app_localizations.dart';
import 'package:provider/provider.dart';

import '../../core/secure_storage_service.dart';
import '../../home_screen.dart';
import '../../theme/app_theme.dart';
import '../../core/failure_messages.dart';
import '../auth/google_auth_service.dart';

// ── データ ────────────────────────────────────────────────────

class _PageData {
  const _PageData({
    required this.illustrationBg,
    required this.iconBg,
    required this.iconData,
    this.badge,
    required this.title,
    required this.body,
  });
  final Color illustrationBg;
  final Color iconBg;
  final IconData iconData;
  final String? badge;
  final String title;
  final String body;
}


// ページ数 = _pages.length + 1（最終ログインページ）
const _totalPages = 5;

// 最終ページ以外のページ背景色
const _pageBgColors = [
  Color(0xFFFFF5F5),
  Color(0xFFF0F4FF),
  Color(0xFFF0FDF4),
  Color(0xFFFFFBEB),
  Color(0xFFFFF5F5), // ログインページ
];

// ── メイン画面 ────────────────────────────────────────────────

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pageCtrl = PageController();
  int _currentPage = 0;

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  void _next() {
    if (_currentPage < _totalPages - 1) {
      _pageCtrl.nextPage(
        duration: const Duration(milliseconds: 380),
        curve: Curves.easeInOutCubic,
      );
    }
  }

  void _skip() {
    _pageCtrl.animateToPage(
      _totalPages - 1,
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeInOutCubic,
    );
  }

  Future<void> _finish() async {
    await SecureStorageService.instance.setOnboardingDone();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, animation, __) => const HomeScreen(),
        transitionsBuilder: (_, animation, __, child) => FadeTransition(
          opacity: animation,
          child: child,
        ),
        transitionDuration: const Duration(milliseconds: 400),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final pages = [
      _PageData(
        illustrationBg: const Color(0xFFFFF5F5),
        iconBg: AppColors.primary,
        iconData: Icons.terminal_rounded,
        title: l.onboardingWelcomeTitle,
        body: l.onboardingWelcomeBody,
      ),
      _PageData(
        illustrationBg: const Color(0xFFF0F4FF),
        iconBg: const Color(0xFF2563EB),
        iconData: Icons.cloud_done_rounded,
        badge: 'Cloud Shell',
        title: l.onboardingTerminalTitle,
        body: l.onboardingTerminalBody,
      ),
      _PageData(
        illustrationBg: const Color(0xFFF0FDF4),
        iconBg: const Color(0xFF16A34A),
        iconData: Icons.source_rounded,
        badge: l.tabRepository,
        title: l.onboardingGithubTitle,
        body: l.onboardingGithubBody,
      ),
      _PageData(
        illustrationBg: const Color(0xFFFFFBEB),
        iconBg: const Color(0xFFD97706),
        iconData: Icons.widgets_rounded,
        badge: l.buttonsEdit,
        title: l.onboardingCommandsTitle,
        body: l.onboardingCommandsBody,
      ),
    ];

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
        color: _pageBgColors[_currentPage],
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: Column(
            children: [
              Expanded(
                child: PageView(
                  controller: _pageCtrl,
                  onPageChanged: (i) => setState(() => _currentPage = i),
                  children: [
                    ...pages.map(
                      (data) => _FeaturePage(data: data, onSkip: _skip),
                    ),
                    _LoginPage(onFinish: _finish),
                  ],
                ),
              ),
              _BottomNav(
                currentPage: _currentPage,
                totalPages: _totalPages,
                onNext: _next,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── 機能紹介ページ ────────────────────────────────────────────

class _FeaturePage extends StatelessWidget {
  const _FeaturePage({required this.data, required this.onSkip});
  final _PageData data;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // スキップボタン
          Align(
            alignment: Alignment.topRight,
            child: Padding(
              padding: const EdgeInsets.only(right: 8),
              child: TextButton(
                onPressed: onSkip,
                child: Text(
                  l.skip,
                  style: const TextStyle(
                      color: AppColors.textMuted,
                      fontWeight: FontWeight.w500),
                ),
              ),
            ),
          ),
          // イラストエリア
          Expanded(
            flex: 52,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: _IllustrationCard(data: data),
            ),
          ),
          // テキストエリア
          Expanded(
            flex: 48,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(32, 28, 32, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    data.title,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    data.body,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 15,
                      height: 1.75,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _IllustrationCard extends StatelessWidget {
  const _IllustrationCard({required this.data});
  final _PageData data;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: data.illustrationBg,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: data.iconBg.withOpacity(0.12),
          width: 1.5,
        ),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // メインアイコン
            Container(
              width: 104,
              height: 104,
              decoration: BoxDecoration(
                color: data.iconBg,
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                    color: data.iconBg.withOpacity(0.40),
                    blurRadius: 28,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Icon(data.iconData, color: Colors.white, size: 54),
            ),
            if (data.badge != null) ...[
              const SizedBox(height: 22),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
                decoration: BoxDecoration(
                  color: data.iconBg.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: data.iconBg.withOpacity(0.25),
                  ),
                ),
                child: Text(
                  data.badge!,
                  style: TextStyle(
                    color: data.iconBg,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── ログインページ（最終） ─────────────────────────────────────

class _LoginPage extends StatelessWidget {
  const _LoginPage({required this.onFinish});
  final Future<void> Function() onFinish;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Consumer<GoogleAuthService>(
      builder: (context, auth, _) {
        return SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // あとでボタン
              Align(
                alignment: Alignment.topRight,
                child: Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: TextButton(
                    onPressed: onFinish,
                    child: Text(
                      l.later,
                      style: const TextStyle(
                          color: AppColors.textMuted,
                          fontWeight: FontWeight.w500),
                    ),
                  ),
                ),
              ),
              // イラストエリア
              Expanded(
                flex: 52,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF5F5),
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(
                        color: AppColors.primary.withOpacity(0.12),
                        width: 1.5,
                      ),
                    ),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 104,
                            height: 104,
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              borderRadius: BorderRadius.circular(30),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.primary.withOpacity(0.40),
                                  blurRadius: 28,
                                  offset: const Offset(0, 10),
                                ),
                              ],
                            ),
                            child: const Icon(Icons.rocket_launch_rounded,
                                color: Colors.white, size: 54),
                          ),
                          const SizedBox(height: 22),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 7),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: AppColors.primary.withOpacity(0.25),
                              ),
                            ),
                            child: Text(
                              l.letsGo,
                              style: const TextStyle(
                                color: AppColors.primary,
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              // テキスト + ログインボタン
              Expanded(
                flex: 48,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(32, 28, 32, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l.onboardingSignInTitle,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          height: 1.3,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        l.onboardingSignInBody,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 15,
                          height: 1.75,
                        ),
                      ),
                      if (auth.error != null) ...[
                        const SizedBox(height: 14),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.error.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                                color: AppColors.error.withOpacity(0.3)),
                          ),
                          child: Text(
                            authFailureMessage(
                                AppLocalizations.of(context)!,
                                auth.error!),
                            style: const TextStyle(
                                color: AppColors.errorLight, fontSize: 13),
                          ),
                        ),
                      ],
                      const Spacer(),
                      // ログインボタン
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: auth.isLoading
                              ? null
                              : () => auth.signIn(onSuccess: onFinish),
                          icon: auth.isLoading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.white),
                                )
                              : const Icon(Icons.login_rounded),
                          label: Text(auth.isLoading
                              ? l.loggingIn
                              : l.loginWithGoogle),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            textStyle: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Center(
                        child: TextButton(
                          onPressed: onFinish,
                          child: Text(
                            l.loginWithoutAccount,
                            style: const TextStyle(
                                color: AppColors.textMuted, fontSize: 13),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ── ボトムナビゲーション（ドット + 次へボタン） ────────────────

class _BottomNav extends StatelessWidget {
  const _BottomNav({
    required this.currentPage,
    required this.totalPages,
    required this.onNext,
  });
  final int currentPage;
  final int totalPages;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final isLastPage = currentPage == totalPages - 1;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(28, 8, 28, 20),
        child: Row(
          children: [
            // ページインジケーター
            Row(
              children: List.generate(totalPages, (i) {
                final active = i == currentPage;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 280),
                  curve: Curves.easeInOut,
                  margin: const EdgeInsets.only(right: 7),
                  width: active ? 28 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: active
                        ? AppColors.primary
                        : AppColors.primary.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                );
              }),
            ),
            const Spacer(),
            // 次へボタン（最終ページでは非表示）
            if (!isLastPage)
              GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  onNext();
                },
                child: Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withOpacity(0.38),
                        blurRadius: 16,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.arrow_forward_rounded,
                      color: Colors.white, size: 26),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
