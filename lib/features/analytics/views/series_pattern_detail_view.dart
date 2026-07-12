import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:running_laps/features/analytics/data/series_pattern.dart';
import 'package:running_laps/config/app_theme.dart';
import 'package:running_laps/core/theme/app_colors.dart';

class SeriesPatternDetailView extends StatelessWidget {
  final SeriesPattern pattern;

  const SeriesPatternDetailView({super.key, required this.pattern});

  @override
  Widget build(BuildContext context) {
    // Sort instances chronologically for the chart
    final sortedInstances = List<SerieInstance>.from(pattern.instances)
      ..sort((a, b) => a.fecha.compareTo(b.fecha));

    return Scaffold(
      appBar: AppBar(
        title: Text('${pattern.distanceFormatted} Series'),
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: Theme.of(context).brightness == Brightness.dark ? AppColors.brandLight : AppColors.brand),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // KPI Header
            Row(
              children: [
                Expanded(child: _buildKpiCard(context, "Mejor Tiempo", pattern.bestTimeFormatted, Icons.emoji_events, AppColors.rpeMid, subValue: pattern.bestPaceFormatted)),
                const SizedBox(width: 12),
                Expanded(child: _buildKpiCard(context, "Tiempo Medio", pattern.averageTimeFormatted, Icons.speed, AppColors.rest, subValue: pattern.averagePaceFormatted)),
                const SizedBox(width: 12),
                Expanded(child: _buildKpiCard(context, "Total Veces", "${pattern.count}", Icons.repeat, AppColors.brand)),
              ],
            ),
            
            const SizedBox(height: 24),
            
            // Chart Section
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Progresión del Ritmo", style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                  const SizedBox(height: 24),
                  SizedBox(
                    height: 200,
                    child: _PaceProgressionChart(instances: sortedInstances),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 24),

            // History List
            Align(
              alignment: Alignment.centerLeft,
              child: Text("Historial", style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5))),
            ),
            const SizedBox(height: 12),
            
            ListView.separated(
              physics: const NeverScrollableScrollPhysics(),
              shrinkWrap: true,
              itemCount: sortedInstances.length, // Show all or limit?
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                // Show newest first in list
                final instance = sortedInstances[sortedInstances.length - 1 - index];
                return _buildHistoryItem(context, instance);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKpiCard(BuildContext context, String title, String value, IconData icon, Color color, {String? subValue}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.transparent
                : Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          FittedBox(fit: BoxFit.scaleDown, child: Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16))),
          if (subValue != null) ...[
            Text(subValue, style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.35), fontSize: 10)),
          ],
          const SizedBox(height: 4),
          Text(title, style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5), fontSize: 11), textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _buildHistoryItem(BuildContext context, SerieInstance instance) {
    // Calculate formatted pace for this instance
    final m = instance.paceSecKm ~/ 60;
    final s = (instance.paceSecKm % 60).toInt();
    final pace = '$m:${s.toString().padLeft(2, '0')}';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "${instance.fecha.day}/${instance.fecha.month}/${instance.fecha.year}",
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              ),
              const SizedBox(height: 4),
              Text(
                "Serie #${instance.serieIndex + 1}",
                style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5), fontSize: 12),
              ),
            ],
          ),
          Container(
             padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
             decoration: BoxDecoration(
               color: AppColors.brand.withValues(alpha: 0.1),
               borderRadius: BorderRadius.circular(20),
             ),
             child: Column(
               mainAxisAlignment: MainAxisAlignment.center,
               crossAxisAlignment: CrossAxisAlignment.end,
               children: [
                 Text(
                   SeriesPattern.formatDuration(instance.serie.tiempoSec),
                   style: TextStyle(color: Theme.of(context).brightness == Brightness.dark ? AppColors.brandLight : AppColors.brand, fontWeight: FontWeight.w600, fontSize: 16),
                 ),
                 Text(
                   "$pace /km",
                   style: TextStyle(color: (Theme.of(context).brightness == Brightness.dark ? AppColors.brandLight : AppColors.brand).withValues(alpha: 0.6), fontSize: 11, fontWeight: FontWeight.w500),
                 ),
               ],
             ),
          ),
        ],
      ),
    );
  }
}

class _PaceProgressionChart extends StatelessWidget {
  final List<SerieInstance> instances;
  const _PaceProgressionChart({required this.instances});

  @override
  Widget build(BuildContext context) {
    final spots = instances.asMap().entries.map((e) {
      return FlSpot(e.key.toDouble(), e.value.paceSecKm.toDouble());
    }).toList();

    if (spots.isEmpty) return const SizedBox.shrink();

    final minY = spots.map((e) => e.y).reduce((a, b) => a < b ? a : b);
    final targetMinY = (minY * 0.9).floorToDouble();

    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true, 
          drawVerticalLine: false,
          getDrawingHorizontalLine: (_) => FlLine(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.06)),
        ),
        titlesData: FlTitlesData(show: false),
        borderData: FlBorderData(show: false),
        minY: targetMinY,
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: AppColors.brand,
            barWidth: 3,
            dotData: const FlDotData(show: true),
            belowBarData: BarAreaData(
              show: true,
              color: AppColors.brand.withValues(alpha: 0.1),
            ),
          ),
        ],
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
             getTooltipItems: (touchedSpots) {
                 return touchedSpots.map((spot) {
                    final val = spot.y;
                    final m = val ~/ 60;
                    final s = (val % 60).toInt();
                    return LineTooltipItem(
                       '$m:${s.toString().padLeft(2, '0')}', 
                       const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                    );
                 }).toList();
             }
          ),
        ),
      ),
    );
  }
}

