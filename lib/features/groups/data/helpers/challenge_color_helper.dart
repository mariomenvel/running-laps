import 'package:flutter/material.dart';
import 'package:running_laps/core/theme/app_colors.dart';
import '../models/enums.dart';

/// Shared color utilities for challenge UI.
/// Uses AppColors tokens for consistent metric-based colors.
class ChallengeColorHelper {
  /// Returns the accent color that represents a given metric.
  static Color accentForMetric(ChallengeMetric metric) {
    switch (metric) {
      case ChallengeMetric.distance:
        return AppColors.rest;      // azul distancia
      case ChallengeMetric.time:
        return AppColors.rpeMid;    // ámbar tiempo
      case ChallengeMetric.sessions:
        return AppColors.brand;     // morado sesiones
      case ChallengeMetric.bestPace:
      case ChallengeMetric.avgPace:
        return AppColors.effort;    // coral ritmo
    }
  }

  /// Returns the surface background color for a metric badge/card.
  static Color surfaceForMetric(ChallengeMetric metric) {
    switch (metric) {
      case ChallengeMetric.distance:
        return AppColors.restSurface;
      case ChallengeMetric.time:
        return AppColors.brandSurface;
      case ChallengeMetric.sessions:
        return AppColors.brandSurface;
      case ChallengeMetric.bestPace:
      case ChallengeMetric.avgPace:
        return AppColors.effortSurfaceConst;
    }
  }

}
