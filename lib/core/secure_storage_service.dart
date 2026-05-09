import 'dart:convert';

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

  // in-memory キャッシュ（起動後の再読み出しを高速化）
  String? _cachedToken;
  String? _cachedPrivateKey;
  String? _cachedPublicKey;

  void clearCache() {
    _cachedToken = null;
    _cachedPrivateKey = null;
    _cachedPublicKey = null;
  }

  // ── Google アクセストークン ──────────────────────────
  Future<void> saveAccessToken(String token) async {
    _cachedToken = token;
    await _storage.write(key: AppConstants.storageKeyAccessToken, value: token);
  }

  Future<String?> getAccessToken() async {
    return _cachedToken ??= await _storage.read(key: AppConstants.storageKeyAccessToken);
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
    _cachedPrivateKey = privateKey;
    _cachedPublicKey = publicKey;
    await _storage.write(key: AppConstants.storageKeySshPrivateKey, value: privateKey);
    await _storage.write(key: AppConstants.storageKeySshPublicKey, value: publicKey);
  }

  Future<String?> getSshPrivateKey() async {
    return _cachedPrivateKey ??= await _storage.read(key: AppConstants.storageKeySshPrivateKey);
  }

  Future<String?> getSshPublicKey() async {
    return _cachedPublicKey ??= await _storage.read(key: AppConstants.storageKeySshPublicKey);
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

  Future<String?> getTerminalFontSize() async {
    return _storage.read(key: 'terminal_font_size_v1');
  }

  Future<void> saveTerminalFontSize(String value) async {
    await _storage.write(key: 'terminal_font_size_v1', value: value);
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

  // ── コマンドランチャー ────────────────────────────────────────
  Future<String?> getCommandLauncher() async {
    return _storage.read(key: 'command_launcher_v1');
  }

  Future<void> saveCommandLauncher(String json) async {
    await _storage.write(key: 'command_launcher_v1', value: json);
  }

  // ── ポートトンネル設定 ─────────────────────────────────────────
  Future<String?> getPortTunnels(String connectionId) async {
    return _storage.read(key: 'port_tunnels_v1_$connectionId');
  }

  Future<void> savePortTunnels(String connectionId, String json) async {
    await _storage.write(key: 'port_tunnels_v1_$connectionId', value: json);
  }

  // ── 右アクションパネル位置 ────────────────────────────────────
  Future<String?> getRightPanelPosition() async {
    return _storage.read(key: 'right_panel_position_v1');
  }

  Future<void> saveRightPanelPosition(String json) async {
    await _storage.write(key: 'right_panel_position_v1', value: json);
  }

  // ── Cloud Shell 認証情報キャッシュ ───────────────────────────
  Future<Map<String, dynamic>?> getCloudShellCredentials() async {
    final raw = await _storage.read(key: 'cloudshell_credentials_v1');
    if (raw == null) return null;
    try {
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  Future<void> saveCloudShellCredentials({
    required String host,
    required String username,
    required int port,
    String? webHost,
  }) async {
    await _storage.write(
      key: 'cloudshell_credentials_v1',
      value: jsonEncode({
        'host': host,
        'username': username,
        'port': port,
        if (webHost != null) 'webHost': webHost,
      }),
    );
  }

  Future<void> clearCloudShellCredentials() async {
    await _storage.delete(key: 'cloudshell_credentials_v1');
  }

  // ── 機能フラグ ──────────────────────────────────────────────
  Future<String?> getFeatureFlags() async {
    return _storage.read(key: 'feature_flags_v1');
  }

  Future<void> saveFeatureFlags(String json) async {
    await _storage.write(key: 'feature_flags_v1', value: json);
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
    clearCache();
    await _storage.delete(key: AppConstants.storageKeyAccessToken);
    await _storage.delete(key: AppConstants.storageKeyRefreshToken);
    await _storage.delete(key: AppConstants.storageKeySshPrivateKey);
    await _storage.delete(key: AppConstants.storageKeySshPublicKey);
    await _storage.delete(key: 'cloudshell_credentials_v1');
  }

  // ── 全データ削除 (ログアウト) ─────────────────────────
  Future<void> clearAll() async {
    await _storage.deleteAll();
  }
}
