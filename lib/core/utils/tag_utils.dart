import 'package:running_laps/core/theme/app_colors.dart';
import 'package:flutter/material.dart';

class TagUtils {
  static const List<Color> _palette = [
    AppColors.rpeMax,
    AppColors.brand,
    AppColors.brand,
    Colors.deepPurple,
    Colors.indigo,
    AppColors.rest,
    Colors.lightBlue,
    Colors.cyan,
    AppColors.brand,
    AppColors.rpeLow,
    Colors.lightGreen,
    Colors.lime,
    AppColors.rpeMid, // Skip yellow as it's hard to read? Maybe darker shade.
    Colors.deepOrange,
    Colors.brown,
    AppColors.iconMuted,
  ];

  static Color getColor(String? tag) {
    if (tag == null || tag.trim().isEmpty) {
      return AppColors.iconMuted; // Gris clarito para sin etiqueta
    }
    
    // Deterministic color based on string content
    final int hash = tag.trim().toLowerCase().hashCode;
    final int index = hash.abs() % _palette.length;
    return _palette[index];
  }
}

