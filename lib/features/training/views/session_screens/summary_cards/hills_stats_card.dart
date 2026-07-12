import 'package:flutter/material.dart';
import 'package:running_laps/core/theme/app_colors.dart';
import 'package:running_laps/features/training/data/summary_stats_calculator.dart';

class HillsStatsCard extends StatelessWidget {
  final HillsStats stats;
  final Color accentColor;

  const HillsStatsCard({super.key, required this.stats, required this.accentColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accentColor.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('CUESTAS CONQUISTADAS',
              style: TextStyle(fontSize: 11, letterSpacing: 2.0, fontWeight: FontWeight.w600, color: accentColor)),
          const SizedBox(height: 16),
          _row(context, Icons.terrain_rounded, 'Cuestas completadas',
              '${stats.totalClimbs}', highlight: true),
          const SizedBox(height: 12),
          _row(context, Icons.timer_outlined, 'Tiempo total subiendo',
              _formatDuration(stats.totalClimbingTime)),
          if (stats.avgFcClimbs != null) ...[
            const SizedBox(height: 12),
            _row(context, Icons.favorite_outline_rounded, 'FC media en subidas',
                '${stats.avgFcClimbs!.toStringAsFixed(0)} bpm'),
          ],
          if (stats.peakFc != null) ...[
            const SizedBox(height: 12),
            _row(context, Icons.trending_up_rounded, 'FC pico',
                '${stats.peakFc} bpm', valueColor: AppColors.rpeMax),
          ],
        ],
      ),
    );
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds.remainder(60);
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  Widget _row(BuildContext context, IconData icon, String label, String value,
      {bool highlight = false, Color? valueColor}) {
    return Row(children: [
      Icon(icon, size: 18, color: AppColors.textSecondary(context)),
      const SizedBox(width: 10),
      Expanded(child: Text(label,
          style: TextStyle(fontSize: 13, color: AppColors.textSecondary(context)))),
      Text(value,
          style: TextStyle(
              fontSize: highlight ? 18 : 14,
              fontWeight: highlight ? FontWeight.w800 : FontWeight.w600,
              color: valueColor ?? AppColors.textPrimary(context))),
    ]);
  }
}
