import 'package:flutter/material.dart';
import 'package:running_laps/core/theme/app_colors.dart';
import 'package:running_laps/features/training/data/summary_stats_calculator.dart';

class CompetitionStatsCard extends StatelessWidget {
  final CompetitionStats stats;
  final Color accentColor;

  const CompetitionStatsCard({super.key, required this.stats, required this.accentColor});

  String _formatPace(double sec) {
    final m = sec ~/ 60;
    final s = (sec % 60).round();
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  String _formatDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    if (h > 0) {
      return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      // Tiempo final destacado
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [accentColor.withValues(alpha: 0.20), accentColor.withValues(alpha: 0.05)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: accentColor, width: 2),
        ),
        child: Column(children: [
          Text('TIEMPO FINAL',
              style: TextStyle(fontSize: 11, letterSpacing: 3.0, fontWeight: FontWeight.w800, color: accentColor)),
          const SizedBox(height: 8),
          Text(_formatDuration(stats.finishTime),
              style: TextStyle(fontSize: 48, fontWeight: FontWeight.w900, color: accentColor, letterSpacing: -1)),
          const SizedBox(height: 4),
          Text('${stats.totalDistanceKm.toStringAsFixed(2)} km',
              style: TextStyle(fontSize: 14, color: AppColors.textSecondary(context))),
          if (stats.avgPaceSecPerKm != null) ...[
            const SizedBox(height: 4),
            Text('Pace medio: ${_formatPace(stats.avgPaceSecPerKm!)} /km',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary(context))),
          ],
        ]),
      ),

      // Parciales por km (si hay)
      if (stats.kmSplits.isNotEmpty) ...[
        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('PARCIALES',
                  style: TextStyle(fontSize: 11, letterSpacing: 2.0, fontWeight: FontWeight.w600, color: accentColor)),
              const SizedBox(height: 12),
              ...stats.kmSplits.map((split) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(children: [
                  Text('Km ${split.kmNumber}',
                      style: TextStyle(fontSize: 13, color: AppColors.textSecondary(context))),
                  const Spacer(),
                  Text('${_formatPace(split.paceSecPerKm)} /km',
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                ]),
              )),
            ],
          ),
        ),
      ],

      // Marca personal si aplica
      if (stats.isNewPersonalBest == true) ...[
        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFC9A227).withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFC9A227), width: 1.5),
          ),
          child: const Row(children: [
            Icon(Icons.emoji_events_rounded, color: Color(0xFFC9A227), size: 28),
            SizedBox(width: 12),
            Text('¡NUEVA MARCA PERSONAL!',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800,
                    color: Color(0xFFC9A227), letterSpacing: 1.0)),
          ]),
        ),
      ],
    ]);
  }
}
