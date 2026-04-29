import 'package:flutter/material.dart';
import 'app_colors.dart';

/// ThemeData de Running Laps — dark mode por defecto.
/// No hay light mode implementado.
class AppTheme {
  AppTheme._();

  static const _pageTransitions = PageTransitionsTheme(
    builders: {
      TargetPlatform.android: CupertinoPageTransitionsBuilder(),
      TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
    },
  );

  static ThemeData light() => dark(); // no light mode — alias para compatibilidad

  static ThemeData dark() => ThemeData(
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
    pageTransitionsTheme: _pageTransitions,
  );
}

/// Escala tipográfica de la app.
class AppTypography {
  AppTypography._();

  static const h1 = TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white);
  static const h2 = TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white);
  static const h3 = TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: Colors.white);
  static const body = TextStyle(fontSize: 14, fontWeight: FontWeight.normal, color: Colors.white);
  static const small = TextStyle(fontSize: 12, fontWeight: FontWeight.normal, color: Color(0xFFCCCCCC));
}

/// Espaciado semántico — usar en padding, gap, margin.
class AppSpacing {
  AppSpacing._();

  static const double xs  = 4;
  static const double s   = 8;
  static const double m   = 12;
  static const double l   = 16;
  static const double xl  = 24;
  static const double xxl = 32;
}

/// Dimensiones de componentes reutilizables.
class AppDimens {
  AppDimens._();

  static const double cardRadius      = 12;
  static const double cardRadiusLarge = 16;
  static const double cardPadding     = 16;
  static final BoxShadow cardShadow   = BoxShadow(
    color: Colors.black.withOpacity(0.3),
    blurRadius: 12,
    offset: const Offset(0, 4),
  );

  static const double buttonRadius    = 12;
  static const double buttonPadding   = 16;
  static const double buttonFontSize  = 14;

  static const double iconSize        = 24;
  static const double iconSizeSmall   = 20;
  static const double navIconSize     = 24;
}
