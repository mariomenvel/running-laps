import 'package:flutter/material.dart';
import 'package:running_laps/core/theme/app_colors.dart';
import 'package:running_laps/features/training/data/summary_stats_calculator.dart';

class IntervalStatsCard extends StatelessWidget {
  final IntervalStats stats;
  final Color accentColor;

  const IntervalStatsCard({
    super.key,
    required this.stats,
    required this.accentColor,
  });

  String _formatPace(double secPerKm) {
    final m = secPerKm ~/ 60;
    final s = (secPerKm % 60).round();
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
        border: Border.all(
          color: accentColor.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'DETALLE DE SERIES',
            style: TextStyle(
              fontSize: 11,
              letterSpacing: 2.0,
              fontWeight: FontWeight.w600,
              color: accentColor,
            ),
          ),
          const SizedBox(height: 16),

          // Total series
          _row(
            context,
            icon: Icons.format_list_numbered_rounded,
            label: 'Series completadas',
            value: '${stats.totalSeries}',
          ),

          // Mejor serie
          if (stats.bestSerieIndex != null && stats.bestSeriePace != null) ...[
            const SizedBox(height: 12),
            _row(
              context,
              icon: Icons.emoji_events_outlined,
              label: 'Mejor serie',
              value: 'Serie ${stats.bestSerieIndex! + 1} · ${_formatPace(stats.bestSeriePace!)} /km',
              highlight: true,
            ),
          ],

          // Consistencia
          if (stats.consistencyPctVariation != null) ...[
            const SizedBox(height: 12),
            _row(
              context,
              icon: Icons.timeline_rounded,
              label: 'Consistencia',
              value: '${stats.consistencyPctVariation!.toStringAsFixed(1)}% variación',
              valueColor: stats.consistencyPctVariation! < 3
                  ? AppColors.rpeLow
                  : stats.consistencyPctVariation! < 7
                      ? AppColors.rpeMid
                      : AppColors.rpeMax,
            ),
          ],

          // % en objetivo
          if (stats.percentInTarget != null) ...[
            const SizedBox(height: 12),
            _row(
              context,
              icon: Icons.center_focus_strong_rounded,
              label: 'Series en objetivo',
              value: '${stats.percentInTarget!.toStringAsFixed(0)}%',
              valueColor: stats.percentInTarget! >= 80
                  ? AppColors.rpeLow
                  : stats.percentInTarget! >= 50
                      ? AppColors.rpeMid
                      : AppColors.rpeMax,
            ),
          ],
        ],
      ),
    );
  }

  Widget _row(BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
    bool highlight = false,
    Color? valueColor,
  }) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.textSecondary(context)),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary(context),
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: highlight ? FontWeight.w600 : FontWeight.w600,
            color: valueColor ?? AppColors.textPrimary(context),
          ),
        ),
      ],
    );
  }
}
