import 'package:flutter/material.dart';
import 'secure_storage_service.dart';

class ThemeService extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.light;
  double _terminalFontSize = 13.0;

  ThemeMode get themeMode => _themeMode;
  bool get isDark => _themeMode == ThemeMode.dark;
  double get terminalFontSize => _terminalFontSize;

  Future<void> load() async {
    final stored = await SecureStorageService.instance.getThemeMode();
    _themeMode = stored == 'dark' ? ThemeMode.dark : ThemeMode.light;
    final fsRaw = await SecureStorageService.instance.getTerminalFontSize();
    if (fsRaw != null) _terminalFontSize = double.tryParse(fsRaw) ?? 13.0;
    notifyListeners();
  }

  Future<void> setDark(bool dark) async {
    _themeMode = dark ? ThemeMode.dark : ThemeMode.light;
    await SecureStorageService.instance.saveThemeMode(dark ? 'dark' : 'light');
    notifyListeners();
  }

  Future<void> setTerminalFontSize(double size) async {
    _terminalFontSize = size;
    await SecureStorageService.instance.saveTerminalFontSize(size.toString());
    notifyListeners();
  }
}
