import 'package:flutter/material.dart';
import 'package:running_laps/core/theme/app_colors.dart';

class PaceWidget extends StatelessWidget {
  final String paceString;       // "4:35" o "--:--"
  final int? targetMinSec;       // opcional, segundos por km
  final int? targetMaxSec;       // opcional, máximo del rango
  final double fontSize;
  final bool showLabel;

  const PaceWidget({
    super.key,
    required this.paceString,
    this.targetMinSec,
    this.targetMaxSec,
    this.fontSize = 32,
    this.showLabel = true,
  });

  Color _colorForPace(BuildContext context) {
    if (targetMinSec == null) return AppColors.textPrimary(context);

    final currentSec = _parsePaceSec(paceString);
    if (currentSec == null) return AppColors.textPrimary(context);

    final max = targetMaxSec ?? targetMinSec! + 15;
    if (currentSec >= targetMinSec! - 5 && currentSec <= max + 5) {
      return AppColors.rpeLow;  // verde — dentro
    }
    if ((currentSec - max).abs() <= 20 || (currentSec - targetMinSec!).abs() <= 20) {
      return AppColors.rpeMid;  // naranja — cerca
    }
    return AppColors.rpeMax;    // rojo — lejos
  }

  static int? _parsePaceSec(String pace) {
    final parts = pace.split(':');
    if (parts.length != 2) return null;
    final m = int.tryParse(parts[0]);
    final s = int.tryParse(parts[1]);
    if (m == null || s == null) return null;
    return m * 60 + s;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          paceString,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.w700,
            color: _colorForPace(context),
            height: 1.0,
          ),
        ),
        if (showLabel) ...[
          const SizedBox(height: 4),
          Text(
            'min/km',
            style: TextStyle(
              fontSize: fontSize * 0.25,
              color: AppColors.textSecondary(context),
              letterSpacing: 1.5,
            ),
          ),
        ],
      ],
    );
  }
}
