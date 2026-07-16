import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'app_colors.dart';

// iOS usa San Francisco (sistema nativo); Android/Web usa GeneralSans.
String? get _platformFontFamily {
  if (kIsWeb) return 'GeneralSans';
  if (defaultTargetPlatform == TargetPlatform.iOS) return null;
  return 'GeneralSans';
}

/// ThemeData de Running Laps — dark mode por defecto.
/// No hay light mode implementado.
class AppTheme {
  AppTheme._();

  static ThemeData light() => ThemeData(
    fontFamily: _platformFontFamily,
    brightness: Brightness.light,
    scaffoldBackgroundColor: AppColors.lightBackground,
    colorScheme: const ColorScheme.light(
      primary: AppColors.brand,
      secondary: AppColors.effort,
      surface: AppColors.lightSurface,
      onSurface: AppColors.lightTextPrimary,
      outline: AppColors.lightBorder,
    ),
    cardColor: AppColors.lightSurface,
    primaryColor: AppColors.brand,
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.lightSurface,
      foregroundColor: AppColors.lightTextPrimary,
      elevation: 0,
      centerTitle: true,
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: AppColors.lightSurface,
      selectedItemColor: AppColors.brand,
      unselectedItemColor: AppColors.lightIconMuted,
    ),
    visualDensity: VisualDensity.adaptivePlatformDensity,
  );

  static ThemeData dark() => ThemeData(
    fontFamily: _platformFontFamily,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: const Color(0xFF111111),
    colorScheme: const ColorScheme.dark(
      primary: AppColors.brand,
      secondary: AppColors.effort,
      surface: AppColors.surface,
      onPrimary: Colors.white,
      onSurface: Colors.white,
      outline: AppColors.border,
    ),
    cardColor: AppColors.surface,
    primaryColor: AppColors.brand,
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFF111111),
      foregroundColor: Colors.white,
      elevation: 0,
      centerTitle: true,
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: Color(0xFF111111),
      selectedItemColor: AppColors.brand,
      unselectedItemColor: AppColors.iconMuted,
    ),
    visualDensity: VisualDensity.adaptivePlatformDensity,
  );
}

/// Escala tipográfica de la app.
class AppTypography {
  AppTypography._();

  static const display = TextStyle(fontSize: 56, fontWeight: FontWeight.w400, letterSpacing: -0.5, height: 1.0);
  static const h1 = TextStyle(fontSize: 32, fontWeight: FontWeight.w600, letterSpacing: -0.5, height: 1.15);
  static const h2 = TextStyle(fontSize: 24, fontWeight: FontWeight.w500, letterSpacing: -0.5, height: 1.15);
  static const h3 = TextStyle(fontSize: 20, fontWeight: FontWeight.w500, letterSpacing: -0.5, height: 1.15);
  static const body = TextStyle(fontSize: 14, fontWeight: FontWeight.w400, letterSpacing: -0.1, height: 1.5);
  static const small = TextStyle(fontSize: 12, fontWeight: FontWeight.w400, letterSpacing: -0.1, height: 1.5);
  static const label = TextStyle(fontSize: 10, fontWeight: FontWeight.w600, letterSpacing: 1.2, height: 1.2);
  static const caption = TextStyle(fontSize: 11, fontWeight: FontWeight.w400, letterSpacing: -0.1, height: 1.5);
}

/// Sistema oficial de animación de Running Laps.
class AppMotion {
  AppMotion._();

  // Duraciones
  static const fast = Duration(milliseconds: 120);
  static const base = Duration(milliseconds: 200);
  static const medium = Duration(milliseconds: 250); // hover, press de cards, transiciones intermedias
  static const slow = Duration(milliseconds: 320);
  static const enter = Duration(milliseconds: 400);

  // Curvas
  static const snap = Cubic(0.2, 0, 0, 1);         // press, toggles, feedback táctil
  static const easeEnter = Cubic(0.33, 1, 0.68, 1); // entradas de pantalla, cards, modales
  static const easeExit = Cubic(0.32, 0, 0.67, 0);  // salidas, fades out
}

/// Espaciado semántico — usar en padding, gap, margin.
class AppSpacing {
  AppSpacing._();

  static const double xs     = 4;
  static const double s      = 8;
  static const double m      = 12;
  static const double l      = 16;
  static const double gutter = 20; // gutter móvil — regla principal (manual pág. 32)
  static const double xl     = 24;
  static const double xxl    = 32;
  static const double xxxl   = 48;
  static const double xxxxl  = 64;
}

/// Dimensiones de componentes reutilizables.
class AppDimens {
  AppDimens._();

  static const double radiusSm        = 8;
  static const double cardRadius      = 12;
  static const double cardRadiusLarge = 16;
  static const double radiusLg        = 20;
  static const double radiusPill      = 999;
  static const double cardPadding     = 16;

  static const double buttonRadius    = 12;
  static const double buttonPadding   = 16;
  static const double buttonFontSize  = 14;

  static const double iconSize        = 24;
  static const double iconSizeSmall   = 20;
  static const double navIconSize     = 24;
}
