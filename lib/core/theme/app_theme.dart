import 'package:flutter/material.dart';
import 'app_colors.dart';

/// Light and dark [ThemeData] for Running Laps.
///
/// Usage in MaterialApp:
///   theme: AppTheme.light(),
///   darkTheme: AppTheme.dark(),
///   themeMode: ThemeService.themeMode.value,
class AppTheme {
  AppTheme._();

  static const _pageTransitions = PageTransitionsTheme(
    builders: {
      TargetPlatform.android: CupertinoPageTransitionsBuilder(),
      TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
    },
  );

  static ThemeData light() => ThemeData(
    brightness: Brightness.light,
    colorScheme: const ColorScheme.light(
      primary: AppColors.brandPurple,
      surface: AppColors.surfaceLight,
      onPrimary: Colors.white,
      onSurface: AppColors.textPrimaryLight,
      outline: AppColors.borderLight,
    ),
    scaffoldBackgroundColor: AppColors.backgroundLight,
    cardColor: AppColors.surfaceLight,
    primaryColor: AppColors.brandPurple,
    visualDensity: VisualDensity.adaptivePlatformDensity,
    pageTransitionsTheme: _pageTransitions,
  );

  static ThemeData dark() => ThemeData(
    brightness: Brightness.dark,
    colorScheme: const ColorScheme.dark(
      primary: AppColors.brandPurpleLight,
      surface: AppColors.surfaceDark,
      onPrimary: Colors.white,
      onSurface: AppColors.textPrimaryDark,
      outline: AppColors.borderDark,
    ),
    scaffoldBackgroundColor: AppColors.backgroundDark,
    cardColor: AppColors.surfaceDark,
    primaryColor: AppColors.brandPurpleLight,
    visualDensity: VisualDensity.adaptivePlatformDensity,
    pageTransitionsTheme: _pageTransitions,
  );
}
