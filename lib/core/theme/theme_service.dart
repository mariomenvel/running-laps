import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persists and exposes [ThemeMode] across app restarts.
///
/// Call [ThemeService.init()] before [runApp].
/// Bind [ThemeService.themeMode] to [MaterialApp.themeMode] via
/// [ValueListenableBuilder].
class ThemeService {
  ThemeService._();

  static const _key = 'app_theme_mode';

  /// Current [ThemeMode]. Mutate via [setTheme] — never directly.
  static final ValueNotifier<ThemeMode> themeMode =
      ValueNotifier(ThemeMode.system);

  /// Load persisted preference. Must be called once before [runApp].
  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    themeMode.value = _fromString(prefs.getString(_key));
  }

  /// Persist and immediately apply [mode].
  static Future<void> setTheme(ThemeMode mode) async {
    themeMode.value = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, _toString(mode));
  }

  static ThemeMode _fromString(String? s) {
    switch (s) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  static String _toString(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return 'light';
      case ThemeMode.dark:
        return 'dark';
      default:
        return 'system';
    }
  }
}
