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
  ///
  /// MVP: forzado a [ThemeMode.light]. AppTheme.dark() no está pulido para
  /// el morado de marca (se ve mal sobre negro) — queda para una fase
  /// futura. El selector de tema está oculto en Perfil/Ajustes; no leer ni
  /// persistir preferencia mientras tanto.
  static final ValueNotifier<ThemeMode> themeMode =
      ValueNotifier(ThemeMode.light);

  /// MVP: no-op — el tema queda fijo en light hasta que se pula dark mode.
  static Future<void> init() async {}

  /// Persist and immediately apply [mode].
  static Future<void> setTheme(ThemeMode mode) async {
    themeMode.value = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, _toString(mode));
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
