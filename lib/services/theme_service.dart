import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeService {
  ThemeService._();

  static final ThemeService instance = ThemeService._();
  static const _themeKey = 'theme_mode';

  final ValueNotifier<ThemeMode> themeMode = ValueNotifier(ThemeMode.light);

  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    final savedMode = prefs.getString(_themeKey);

    switch (savedMode) {
      case 'dark':
        themeMode.value = ThemeMode.dark;
        break;
      case 'light':
      default:
        themeMode.value = ThemeMode.light;
        break;
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    if (themeMode.value == mode) return;

    themeMode.value = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeKey, mode == ThemeMode.dark ? 'dark' : 'light');
  }

  bool get isDarkMode => themeMode.value == ThemeMode.dark;
}
