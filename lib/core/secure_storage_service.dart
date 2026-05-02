import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'constants.dart';

/// 認証トークンとSSH鍵をデバイスのセキュアストレージに保存するサービス
class SecureStorageService {
  SecureStorageService._();
  static final SecureStorageService instance = SecureStorageService._();

  static const FlutterSecureStorage _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );

  // ── Google アクセストークン ──────────────────────────
  Future<void> saveAccessToken(String token) async {
    await _storage.write(key: AppConstants.storageKeyAccessToken, value: token);
  }

  Future<String?> getAccessToken() async {
    return _storage.read(key: AppConstants.storageKeyAccessToken);
  }

  // ── Google リフレッシュトークン ──────────────────────
  Future<void> saveRefreshToken(String token) async {
    await _storage.write(key: AppConstants.storageKeyRefreshToken, value: token);
  }

  Future<String?> getRefreshToken() async {
    return _storage.read(key: AppConstants.storageKeyRefreshToken);
  }

  // ── SSH 鍵ペア ────────────────────────────────────────
  Future<void> saveSshKeyPair(String privateKey, String publicKey) async {
    await _storage.write(key: AppConstants.storageKeySshPrivateKey, value: privateKey);
    await _storage.write(key: AppConstants.storageKeySshPublicKey, value: publicKey);
  }

  Future<String?> getSshPrivateKey() async {
    return _storage.read(key: AppConstants.storageKeySshPrivateKey);
  }

  Future<String?> getSshPublicKey() async {
    return _storage.read(key: AppConstants.storageKeySshPublicKey);
  }

  Future<bool> hasSshKeyPair() async {
    final key = await getSshPrivateKey();
    return key != null && key.isNotEmpty;
  }

  // ── GitHub PAT ───────────────────────────────────────────
  Future<void> saveGitHubPat(String pat) async {
    await _storage.write(key: AppConstants.storageKeyGitHubPat, value: pat);
  }

  Future<String?> getGitHubPat() async {
    return _storage.read(key: AppConstants.storageKeyGitHubPat);
  }

  Future<void> deleteGitHubPat() async {
    await _storage.delete(key: AppConstants.storageKeyGitHubPat);
  }

  // ── プラグインシステム ────────────────────────────────
  Future<String?> getPluginList() async {
    return _storage.read(key: 'installed_plugins_v1');
  }

  Future<void> savePluginList(String json) async {
    await _storage.write(key: 'installed_plugins_v1', value: json);
  }

  Future<String?> getPluginValue(String pluginId, String key) async {
    return _storage.read(key: 'plugin_${pluginId}_$key');
  }

  Future<void> setPluginValue(String pluginId, String key, String value) async {
    await _storage.write(key: 'plugin_${pluginId}_$key', value: value);
  }

  Future<void> deletePluginValues(String pluginId) async {
    final all = await _storage.readAll();
    final prefix = 'plugin_${pluginId}_';
    for (final k in all.keys.where((k) => k.startsWith(prefix))) {
      await _storage.delete(key: k);
    }
  }

  // ── ターミナルお気に入りコマンド ─────────────────────
  Future<String?> getTerminalFavorites() async {
    return _storage.read(key: 'terminal_favorites');
  }

  Future<void> saveTerminalFavorites(String json) async {
    await _storage.write(key: 'terminal_favorites', value: json);
  }

  // ── テーマ設定 ──────────────────────────────────────────
  Future<String?> getThemeMode() async {
    return _storage.read(key: 'theme_mode');
  }

  Future<void> saveThemeMode(String mode) async {
    await _storage.write(key: 'theme_mode', value: mode);
  }

  // ── APIキー ──────────────────────────────────────────────
  Future<String?> getApiKeys() async {
    return _storage.read(key: 'api_keys_v1');
  }

  Future<void> saveApiKeys(String json) async {
    await _storage.write(key: 'api_keys_v1', value: json);
  }

  // ── コマンドスニペット ────────────────────────────────────
  Future<String?> getCommandSnippets() async {
    return _storage.read(key: 'command_snippets_v1');
  }

  Future<void> saveCommandSnippets(String json) async {
    await _storage.write(key: 'command_snippets_v1', value: json);
  }

  // ── フローティングコマンドボタン ─────────────────────────────
  Future<String?> getFloatingCommands() async {
    return _storage.read(key: 'floating_commands_v1');
  }

  Future<void> saveFloatingCommands(String json) async {
    await _storage.write(key: 'floating_commands_v1', value: json);
  }

  // ── 右アクションパネル位置 ────────────────────────────────────
  Future<String?> getRightPanelPosition() async {
    return _storage.read(key: 'right_panel_position_v1');
  }

  Future<void> saveRightPanelPosition(String json) async {
    await _storage.write(key: 'right_panel_position_v1', value: json);
  }

  // ── オンボーディング完了フラグ ────────────────────────────────
  Future<bool> isOnboardingDone() async {
    final val = await _storage.read(key: 'onboarding_v1');
    return val == 'done';
  }

  Future<void> setOnboardingDone() async {
    await _storage.write(key: 'onboarding_v1', value: 'done');
  }

  // ── Google認証のみクリア（GitHub PAT・設定は保持） ────────
  Future<void> clearGoogleAuth() async {
    await _storage.delete(key: AppConstants.storageKeyAccessToken);
    await _storage.delete(key: AppConstants.storageKeyRefreshToken);
    await _storage.delete(key: AppConstants.storageKeySshPrivateKey);
    await _storage.delete(key: AppConstants.storageKeySshPublicKey);
  }

  // ── 全データ削除 (ログアウト) ─────────────────────────
  Future<void> clearAll() async {
    await _storage.deleteAll();
  }
}
