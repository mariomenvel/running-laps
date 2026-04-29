import 'package:running_laps/core/theme/app_colors.dart';
import 'package:flutter/material.dart';

class InfoTooltip extends StatelessWidget {
  final String content;
  final Color iconColor;
  final double iconSize;

  const InfoTooltip({
    super.key,
    required this.content,
    this.iconColor = AppColors.iconMuted,
    this.iconSize = 16.0,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: content,
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: AppColors.iconMuted.withOpacity(0.95),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      textStyle: const TextStyle(
        color: Colors.white,
        fontSize: 13,
        fontWeight: FontWeight.w400,
      ),
      preferBelow: false,
      verticalOffset: 15,
      triggerMode: TooltipTriggerMode.tap, // Se activa al tocar y se cierra al tocar fuera
      child: Padding(
        padding: const EdgeInsets.all(4.0),
        child: Icon(
          Icons.help_outline_rounded,
          size: iconSize,
          color: iconColor.withOpacity(0.6),
        ),
      ),
    );
  }
}

