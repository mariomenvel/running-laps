import 'package:flutter/material.dart';

/// Semantic color tokens for Running Laps.
///
/// Every UI color in the app should come from here or from
/// [Theme.of(context).colorScheme]. Never hardcode Color(0xFF...) in screen files.
///
/// Naming convention:
///   <role><Light|Dark>
///   e.g. surfaceLight, surfaceDark
class AppColors {
  AppColors._();

  // ── Brand ─────────────────────────────────────────────────────────
  /// Main brand accent — light mode primary.
  static const Color brandPurple = Color(0xFF8E24AA);

  /// Softer variant for dark mode primary (better contrast on dark surfaces).
  static const Color brandPurpleLight = Color(0xFFAB47BC);

  // ── Backgrounds (Scaffold / page fill) ───────────────────────────
  static const Color backgroundLight = Color(0xFFF4F6F8);
  static const Color backgroundDark  = Color(0xFF1C1C1E); // iOS-style dark

  // ── Surface (cards, containers, modals, bottom sheets) ───────────
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color surfaceDark  = Color(0xFF2C2C2E); // iOS card dark

  // ── Surface Variant (slightly elevated / alternate cards) ────────
  static const Color surfaceVariantLight = Color(0xFFF9FAFB);
  static const Color surfaceVariantDark  = Color(0xFF3A3A3C);

  // ── Text ──────────────────────────────────────────────────────────
  /// Primary body & title text.
  static const Color textPrimaryLight   = Color(0xFF1C1C1E);
  static const Color textPrimaryDark    = Color(0xFFFFFFFF);

  /// Secondary / supporting text (replaces grey.shade500–600).
  static const Color textSecondaryLight = Color(0xFF6B7280);
  static const Color textSecondaryDark  = Color(0xFF8E8E93);

  /// Tertiary / caption text (replaces grey.shade400).
  static const Color textTertiaryLight  = Color(0xFF9CA3AF);
  static const Color textTertiaryDark   = Color(0xFF636366);

  // ── Borders & Dividers ────────────────────────────────────────────
  static const Color borderLight = Color(0xFFE5E7EB);
  static const Color borderDark  = Color(0xFF38383A);

  // ── Shadows ───────────────────────────────────────────────────────
  /// Use as BoxShadow.color. Invisible in dark mode to avoid the
  /// "floating" look that shadows produce on dark backgrounds.
  static const Color shadowLight = Color(0x0A000000); // black ~4%
  static const Color shadowDark  = Color(0x00000000); // fully transparent

  // ── Semantic / Performance (same in both modes) ───────────────────
  /// Pace / RPE alert colors — intentionally invariant between modes.
  static const Color paceFast   = Color(0xFF22C55E); // green
  static const Color paceMedium = Color(0xFFF59E0B); // amber
  static const Color paceSlow   = Color(0xFFEF4444); // red

  // ── Skeleton Shimmer ──────────────────────────────────────────────
  static const Color skeletonBaseLight  = Color(0xFFE5E7EB);
  static const Color skeletonBaseDark   = Color(0xFF3A3A3C);
  static const Color skeletonShineLight = Color(0xFFF3F4F6);
  static const Color skeletonShineDark  = Color(0xFF48484A);
}
