import 'package:flutter/material.dart';
import 'package:running_laps/core/theme/app_colors.dart';

class DistanceWidget extends StatelessWidget {
  final double meters;
  final double? targetMeters;
  final double fontSize;
  final bool hero;

  const DistanceWidget({
    super.key,
    required this.meters,
    this.targetMeters,
    this.fontSize = 32,
    this.hero = false,
  });

  String _format(double m) {
    if (m >= 1000) return (m / 1000).toStringAsFixed(2);
    return m.toInt().toString();
  }

  String _unit() => meters >= 1000 ? 'km' : 'm';

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        RichText(
          textAlign: TextAlign.center,
          text: TextSpan(
            children: [
              TextSpan(
                text: _format(meters),
                style: TextStyle(
                  fontSize: hero ? 96 : fontSize,
                  fontWeight: hero ? FontWeight.w800 : FontWeight.w600,
                  color: AppColors.textPrimary(context),
                  height: 1.0,
                ),
              ),
              TextSpan(
                text: ' ${_unit()}',
                style: TextStyle(
                  fontSize: (hero ? 96 : fontSize) * 0.35,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textSecondary(context),
                ),
              ),
            ],
          ),
        ),
        if (targetMeters != null) ...[
          const SizedBox(height: 4),
          Text(
            'de ${_format(targetMeters!)} ${_unit()} objetivo',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary(context),
            ),
          ),
        ],
      ],
    );
  }
}
