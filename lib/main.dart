import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'core/screenshot_mode.dart';
import 'core/secure_storage_service.dart';
import 'core/ssh_foreground_service.dart';
import 'app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SshForegroundService.init();

  if (kDemoMode) {
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
    );
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);
    runApp(const KirikiriApp(isAuthenticated: true, showOnboarding: false));
    return;
  }

  // 起動時にサイレントサインインで最新トークンを取得（期限切れトークンを自動更新）
  bool isAuthenticated = false;
  try {
    final googleSignIn = GoogleSignIn(scopes: [
      'email',
      'https://www.googleapis.com/auth/cloud-platform',
    ]);
    final account = await googleSignIn.signInSilently();
    if (account != null) {
      final auth = await account.authentication;
      if (auth.accessToken != null) {
        await SecureStorageService.instance.saveAccessToken(auth.accessToken!);
        isAuthenticated = true;
      }
    }
  } catch (_) {}
  if (!isAuthenticated) {
    final token = await SecureStorageService.instance.getAccessToken();
    isAuthenticated = token != null && token.isNotEmpty;
  }

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
    ),
  );

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  final onboardingDone =
      await SecureStorageService.instance.isOnboardingDone();

  runApp(KirikiriApp(
    isAuthenticated: isAuthenticated,
    showOnboarding: !onboardingDone,
  ));
}
