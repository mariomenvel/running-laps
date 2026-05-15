import 'package:flutter/material.dart';
import 'package:running_laps/core/theme/app_colors.dart';

class TargetComparison extends StatelessWidget {
  final String label;        // "RITMO", "FC", "ZONA"
  final String currentValue; // "4:35"
  final String targetValue;  // "4:30 - 5:00"
  final Color valueColor;    // verde/naranja/rojo según proximidad
  final IconData? icon;

  const TargetComparison({
    super.key,
    required this.label,
    required this.currentValue,
    required this.targetValue,
    required this.valueColor,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.borderOf(context).withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 14, color: AppColors.textSecondary(context)),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  letterSpacing: 1.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary(context),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'ACTUAL',
                    style: TextStyle(
                      fontSize: 9,
                      color: AppColors.textSecondary(context),
                    ),
                  ),
                  Text(
                    currentValue,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: valueColor,
                    ),
                  ),
                ],
              ),
              Icon(
                Icons.arrow_forward_rounded,
                color: AppColors.textSecondary(context),
                size: 20,
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'OBJETIVO',
                    style: TextStyle(
                      fontSize: 9,
                      color: AppColors.textSecondary(context),
                    ),
                  ),
                  Text(
                    targetValue,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary(context),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
