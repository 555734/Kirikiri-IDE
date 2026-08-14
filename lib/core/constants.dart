/// アプリ全体の定数定義
class AppConstants {
  AppConstants._();

  // ── アプリ情報 ──────────────────────────────────────────
  static const String appName = 'kirikiri';
  static const String appVersion = '1.0.0';

  // ── 公開ドキュメント（docs/ を GitHub Pages で公開したもの） ──
  static const String termsOfUseUrl =
      'https://555734.github.io/kirikiri-web/terms.html';
  static const String privacyPolicyUrl =
      'https://555734.github.io/kirikiri-web/privacy.html';

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

  // ── HTTP ───────────────────────────────────────────────
  /// 通常の API 呼び出しのタイムアウト。
  /// モバイル回線では接続が黙って切れることがあるため必ず指定する。
  static const Duration httpTimeout = Duration(seconds: 30);

  /// プラグイン ZIP のような大きなレスポンス向けのタイムアウト。
  static const Duration httpDownloadTimeout = Duration(minutes: 2);

  // ── SSH ────────────────────────────────────────────────
  static const int sshPort = 6000; // Cloud Shell SSH ポート
  static const int sshConnectTimeoutSeconds = 20;
  static const Duration sshKeepalive = Duration(seconds: 30);

  static const int terminalInitialCols = 80;
  static const int terminalInitialRows = 24;
}
