import 'package:flutter/material.dart';
import 'package:running_laps/core/theme/app_colors.dart';

class FcWidget extends StatelessWidget {
  final int? bpm;          // null = sin sensor / sin datos
  final int? currentZone;  // 1-5
  final int? targetZone;   // opcional
  final double fontSize;
  final bool showLabel;

  const FcWidget({
    super.key,
    this.bpm,
    this.currentZone,
    this.targetZone,
    this.fontSize = 24,
    this.showLabel = true,
  });

  Color _zoneColor() {
    if (currentZone == null) return Colors.grey;
    switch (currentZone) {
      case 1: return AppColors.rest;  // azul Z1 (guía: recuperación)
      case 2: return const Color(0xFF7FB069);  // verde Z2
      case 3: return const Color(0xFFE9C46A);  // amarillo Z3
      case 4: return const Color(0xFFE76F51);  // naranja Z4
      case 5: return const Color(0xFFD62828);  // rojo Z5
      default: return Colors.grey;
    }
  }

  Widget? _statusIndicator() {
    if (targetZone == null || currentZone == null) return null;
    final diff = (currentZone! - targetZone!).abs();
    if (diff == 0) {
      return const Icon(Icons.check_circle, color: Color(0xFF7FB069), size: 16);
    }
    if (diff == 1) {
      return const Icon(Icons.warning_amber_rounded, color: Color(0xFFE9C46A), size: 16);
    }
    return const Icon(Icons.error_outline, color: Color(0xFFD62828), size: 16);
  }

  @override
  Widget build(BuildContext context) {
    if (bpm == null) {
      return Text(
        'Sin sensor',
        style: TextStyle(
          fontSize: fontSize * 0.6,
          color: AppColors.textSecondary(context),
        ),
      );
    }

    final indicator = _statusIndicator();

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.favorite, color: _zoneColor(), size: fontSize),
        const SizedBox(width: 6),
        Text(
          '$bpm',
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary(context),
          ),
        ),
        if (showLabel) ...[
          const SizedBox(width: 4),
          Text(
            'bpm',
            style: TextStyle(
              fontSize: fontSize * 0.5,
              color: AppColors.textSecondary(context),
            ),
          ),
        ],
        if (currentZone != null) ...[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: _zoneColor().withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              'Z$currentZone',
              style: TextStyle(
                fontSize: fontSize * 0.5,
                fontWeight: FontWeight.w600,
                color: _zoneColor(),
              ),
            ),
          ),
        ],
        if (indicator != null) ...[
          const SizedBox(width: 4),
          indicator,
        ],
      ],
    );
  }
}
