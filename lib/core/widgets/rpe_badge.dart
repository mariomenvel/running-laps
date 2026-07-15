import 'package:flutter/material.dart';
import 'package:running_laps/core/theme/app_colors.dart';

/// Tamaño visual del badge de RPE.
enum RpeBadgeSize { text, chip, stat }

/// Muestra un valor de RPE con el color semántico
/// correcto (AppColors.effortColor) de forma consistente
/// en toda la app. Sustituye implementaciones ad-hoc
/// que calculaban el color por separado o usaban un
/// color fijo incorrecto.
class RpeBadge extends StatelessWidget {
  final double rpe;
  final RpeBadgeSize size;
  final String? label; // override del label, ej. 'RPE med.'
  final bool showIcon;

  const RpeBadge({
    super.key,
    required this.rpe,
    this.size = RpeBadgeSize.chip,
    this.label,
    this.showIcon = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = AppColors.effortColor(rpe);
    final text = label ?? 'RPE ${rpe.toStringAsFixed(1)}';

    switch (size) {
      case RpeBadgeSize.text:
        return Text(
          text,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w400,
            color: color,
          ),
        );

      case RpeBadgeSize.chip:
        return Container(
          padding: const EdgeInsets.symmetric(
              horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (showIcon) ...[
                Icon(Icons.bolt_rounded, size: 13, color: color),
                const SizedBox(width: 3),
              ],
              Text(
                text,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: _darken(color),
                ),
              ),
            ],
          ),
        );

      case RpeBadgeSize.stat:
        return Text(
          rpe.toStringAsFixed(1),
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w500,
            color: color,
          ),
        );
    }
  }

  Color _darken(Color c) {
    final hsl = HSLColor.fromColor(c);
    return hsl
        .withLightness((hsl.lightness - 0.18).clamp(0.0, 1.0))
        .toColor();
  }
}
