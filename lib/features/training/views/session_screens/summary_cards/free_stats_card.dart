import 'package:flutter/material.dart';
import 'package:running_laps/core/theme/app_colors.dart';
import 'package:running_laps/features/training/data/summary_stats_calculator.dart';

class FreeStatsCard extends StatelessWidget {
  final FreeStats stats;
  final Color accentColor;

  const FreeStatsCard({super.key, required this.stats, required this.accentColor});

  String _formatPace(double sec) {
    final m = sec ~/ 60;
    final s = (sec % 60).round();
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  String _formatDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    if (h > 0) return '${h}h ${m}min';
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('RESUMEN',
              style: TextStyle(fontSize: 11, letterSpacing: 2.0, fontWeight: FontWeight.w600, color: accentColor)),
          const SizedBox(height: 16),
          _row(context, Icons.straighten_rounded, 'Distancia',
              '${stats.distanceKm.toStringAsFixed(2)} km', highlight: true),
          const SizedBox(height: 12),
          _row(context, Icons.timer_outlined, 'Tiempo',
              _formatDuration(stats.duration)),
          if (stats.avgPaceSecPerKm != null) ...[
            const SizedBox(height: 12),
            _row(context, Icons.speed_rounded, 'Pace medio',
                '${_formatPace(stats.avgPaceSecPerKm!)} /km'),
          ],
          if (stats.avgFc != null) ...[
            const SizedBox(height: 12),
            _row(context, Icons.favorite_outline_rounded, 'FC media',
                '${stats.avgFc!.toStringAsFixed(0)} bpm'),
          ],
        ],
      ),
    );
  }

  Widget _row(BuildContext context, IconData icon, String label, String value,
      {bool highlight = false}) {
    return Row(children: [
      Icon(icon, size: 18, color: AppColors.textSecondary(context)),
      const SizedBox(width: 10),
      Expanded(child: Text(label,
          style: TextStyle(fontSize: 13, color: AppColors.textSecondary(context)))),
      Text(value,
          style: TextStyle(
              fontSize: highlight ? 18 : 14,
              fontWeight: highlight ? FontWeight.w800 : FontWeight.w600,
              color: AppColors.textPrimary(context))),
    ]);
  }
}
