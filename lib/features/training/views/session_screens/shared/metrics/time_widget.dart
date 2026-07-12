import 'package:flutter/material.dart';
import 'package:running_laps/core/theme/app_colors.dart';

class TimeWidget extends StatelessWidget {
  final Duration elapsed;
  final Duration? target;
  final double fontSize;
  final bool hero;
  final bool showCentiseconds;

  const TimeWidget({
    super.key,
    required this.elapsed,
    this.target,
    this.fontSize = 32,
    this.hero = false,
    this.showCentiseconds = false,
  });

  String _format(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    if (showCentiseconds) {
      final cs = (d.inMilliseconds.remainder(1000) / 10).floor();
      return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}.${cs.toString().padLeft(2, '0')}';
    }
    if (h > 0) {
      return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final timeText = Text(
      _format(elapsed),
      style: TextStyle(
        fontSize: hero ? 88 : fontSize,
        fontWeight: hero ? FontWeight.w800 : FontWeight.w600,
        color: AppColors.textPrimary(context),
        height: 1.0,
        letterSpacing: -1.0,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        hero
            ? FittedBox(
                fit: BoxFit.scaleDown,
                child: timeText,
              )
            : timeText,
        if (target != null) ...[
          const SizedBox(height: 4),
          Text(
            'de ${_format(target!)} objetivo',
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
