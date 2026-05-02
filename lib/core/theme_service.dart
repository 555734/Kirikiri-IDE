import 'package:flutter/material.dart';
import 'secure_storage_service.dart';

class ThemeService extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.light;

  ThemeMode get themeMode => _themeMode;
  bool get isDark => _themeMode == ThemeMode.dark;

  Future<void> load() async {
    final stored = await SecureStorageService.instance.getThemeMode();
    _themeMode = stored == 'dark' ? ThemeMode.dark : ThemeMode.light;
    notifyListeners();
  }

  Future<void> setDark(bool dark) async {
    _themeMode = dark ? ThemeMode.dark : ThemeMode.light;
    await SecureStorageService.instance.saveThemeMode(dark ? 'dark' : 'light');
    notifyListeners();
  }
}
