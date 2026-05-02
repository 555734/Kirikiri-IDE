/// アプリ全体の定数定義
class AppConstants {
  AppConstants._();

  // ── アプリ情報 ──────────────────────────────────────────
  static const String appName = 'kirikiri';
  static const String appVersion = '1.0.0';

  // google_sign_in パッケージが認証を担当するため OAuth 定数は不要

  // ── Google Cloud Shell API ─────────────────────────────
  static const String cloudShellApiBase =
      'https://cloudshell.googleapis.com/v1';

  // ── SecureStorage キー ─────────────────────────────────
  static const String storageKeyAccessToken = 'google_access_token';
  static const String storageKeyRefreshToken = 'google_refresh_token';
  static const String storageKeySshPrivateKey = 'ssh_private_key';
  static const String storageKeySshPublicKey = 'ssh_public_key';
  static const String storageKeyGitHubPat = 'github_pat';

  // ── GitHub API ─────────────────────────────────────────
  static const String gitHubApiBase = 'https://api.github.com';

  // ── SSH ────────────────────────────────────────────────
  static const int sshPort = 6000; // Cloud Shell SSH ポート
  static const int sshConnectTimeoutSeconds = 20;
  static const Duration sshKeepalive = Duration(seconds: 30);

  static const int terminalInitialCols = 80;
  static const int terminalInitialRows = 24;
}
