import 'package:flutter/material.dart';
import 'package:running_laps/core/theme/app_colors.dart';

class TrainingTags {
  static const List<String> predefined = [
    'rodaje',
    'series',
    'tempo',
    'largo',
    'fartlek',
    'competición',
    'recuperación',
  ];

  static bool isPredefined(String tag) =>
      predefined.contains(tag.trim().toLowerCase());

  static ({Color background, Color text, Border? border}) styleForTag(
      String tag, BuildContext context) {
    if (isPredefined(tag)) {
      return (
        background: AppColors.brand.withValues(alpha: 0.1),
        text: AppColors.brandOf(context),
        border: null,
      );
    }
    return (
      background: AppColors.surface2Of(context),
      text: AppColors.textSecondary(context),
      border: Border.all(color: AppColors.borderOf(context), width: 0.5),
    );
  }
}
