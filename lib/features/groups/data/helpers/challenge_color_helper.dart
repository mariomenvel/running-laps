import 'package:flutter/material.dart';
import 'package:running_laps/config/app_theme.dart';
import '../models/enums.dart';

/// Shared color utilities for challenge UI.
/// Used by ChallengeDetailScreen and GlobalChallengeCard so both surfaces
/// render consistent metric-based gradients.
class ChallengeColorHelper {
  /// Returns the accent (right-side) color that represents a given metric.
  static Color accentForMetric(ChallengeMetric metric) {
    switch (metric) {
      case ChallengeMetric.distance:
        return const Color(0xFF10B981); // emerald green
      case ChallengeMetric.time:
        return const Color(0xFFF59E0B); // amber
      case ChallengeMetric.sessions:
        return const Color(0xFF3B82F6); // blue
      case ChallengeMetric.bestPace:
      case ChallengeMetric.avgPace:
        return const Color(0xFFEF4444); // coral red
    }
  }

  /// Returns a LinearGradient: brandPurple (left) → metric accent (right).
  static LinearGradient gradientForMetric(ChallengeMetric metric) {
    return LinearGradient(
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
      colors: [Tema.brandPurple, accentForMetric(metric)],
    );
  }
}
