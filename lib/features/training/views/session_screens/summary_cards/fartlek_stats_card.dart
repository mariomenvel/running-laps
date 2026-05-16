import 'package:flutter/material.dart';
import 'package:running_laps/core/theme/app_colors.dart';
import 'package:running_laps/features/training/data/summary_stats_calculator.dart';

class FartlekStatsCard extends StatelessWidget {
  final FartlekStats stats;
  final Color accentColor;

  const FartlekStatsCard({super.key, required this.stats, required this.accentColor});

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
          Text('TRAMOS DEL FARTLEK',
              style: TextStyle(fontSize: 11, letterSpacing: 2.0, fontWeight: FontWeight.w700, color: accentColor)),
          const SizedBox(height: 16),

          // Rápidos
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFE76F51).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(children: [
              const Icon(Icons.local_fire_department_rounded, color: Color(0xFFE76F51), size: 20),
              const SizedBox(width: 10),
              const Expanded(child: Text('Tramos rápidos',
                  style: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFFE76F51)))),
              Text('${stats.fastSegmentsCount}',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFFE76F51))),
            ]),
          ),
          if (stats.avgFcFast != null) ...[
            const SizedBox(height: 8),
            Text('  FC media: ${stats.avgFcFast!.toStringAsFixed(0)} bpm',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary(context))),
          ],

          const SizedBox(height: 16),

          // Suaves
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF4A90A4).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(children: [
              const Icon(Icons.ac_unit_rounded, color: Color(0xFF4A90A4), size: 20),
              const SizedBox(width: 10),
              const Expanded(child: Text('Tramos suaves',
                  style: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF4A90A4)))),
              Text('${stats.slowSegmentsCount}',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF4A90A4))),
            ]),
          ),
          if (stats.avgFcSlow != null) ...[
            const SizedBox(height: 8),
            Text('  FC media: ${stats.avgFcSlow!.toStringAsFixed(0)} bpm',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary(context))),
          ],

          // Diferencia de recuperación
          if (stats.avgFcFast != null && stats.avgFcSlow != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.rpeLow.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(children: [
                Icon(Icons.trending_down, color: AppColors.rpeLow, size: 16),
                const SizedBox(width: 8),
                Text('Recuperación media: -${(stats.avgFcFast! - stats.avgFcSlow!).toStringAsFixed(0)} bpm',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.rpeLow)),
              ]),
            ),
          ],
        ],
      ),
    );
  }
}
