import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'secure_storage_service.dart';

class FeatureFlagService extends ChangeNotifier {
  bool _sshTab = false;
  bool _apiKeys = false;
  bool _cicd = false;
  bool _plugins = false;

  bool get sshTab => _sshTab;
  bool get apiKeys => _apiKeys;
  bool get cicd => _cicd;
  bool get plugins => _plugins;

  Future<void> load() async {
    final raw = await SecureStorageService.instance.getFeatureFlags();
    if (raw != null) {
      try {
        final map = jsonDecode(raw) as Map<String, dynamic>;
        _sshTab = map['ssh_tab'] as bool? ?? false;
        _apiKeys = map['api_keys'] as bool? ?? false;
        _cicd = map['cicd'] as bool? ?? false;
        _plugins = map['plugins'] as bool? ?? false;
      } catch (_) {}
    }
    notifyListeners();
  }

  Future<void> _save() async {
    await SecureStorageService.instance.saveFeatureFlags(jsonEncode({
      'ssh_tab': _sshTab,
      'api_keys': _apiKeys,
      'cicd': _cicd,
      'plugins': _plugins,
    }));
  }

  Future<void> setSshTab(bool v) async {
    _sshTab = v;
    notifyListeners();
    await _save();
  }

  Future<void> setApiKeys(bool v) async {
    _apiKeys = v;
    notifyListeners();
    await _save();
  }

  Future<void> setCicd(bool v) async {
    _cicd = v;
    notifyListeners();
    await _save();
  }

  Future<void> setPlugins(bool v) async {
    _plugins = v;
    notifyListeners();
    await _save();
  }
}
