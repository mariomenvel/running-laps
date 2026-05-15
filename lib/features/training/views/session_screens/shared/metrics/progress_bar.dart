import 'package:flutter/material.dart';

class SessionProgressBar extends StatelessWidget {
  final double progress;     // 0.0 a 1.0
  final Color color;
  final double height;
  final bool showPercentage;

  const SessionProgressBar({
    super.key,
    required this.progress,
    required this.color,
    this.height = 8,
    this.showPercentage = false,
  });

  @override
  Widget build(BuildContext context) {
    final p = progress.clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(height / 2),
          child: LinearProgressIndicator(
            value: p,
            minHeight: height,
            backgroundColor: color.withValues(alpha: 0.15),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
        if (showPercentage) ...[
          const SizedBox(height: 4),
          Text(
            '${(p * 100).toInt()}%',
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }
}
