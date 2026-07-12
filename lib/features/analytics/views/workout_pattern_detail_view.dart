import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:running_laps/features/analytics/data/workout_pattern.dart';
import 'package:running_laps/config/app_theme.dart';
import 'package:running_laps/core/theme/app_colors.dart';

class WorkoutPatternDetailView extends StatelessWidget {
  final WorkoutPattern pattern;

  const WorkoutPatternDetailView({super.key, required this.pattern});

  @override
  Widget build(BuildContext context) {
    // Sort instances chronologically
    final sortedInstances = List<WorkoutInstance>.from(pattern.instances)
      ..sort((a, b) => a.fecha.compareTo(b.fecha));

    // Determine title: Use key or a generated structure string
    final title = pattern.patternKey;

    return Scaffold(
      appBar: AppBar(
        title: Text(title, overflow: TextOverflow.ellipsis),
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
                Expanded(child: _buildKpiCard(context, "Ritmo Medio", pattern.averagePaceFormatted, Icons.speed, AppColors.rest)),
                const SizedBox(width: 12),
                Expanded(child: _buildKpiCard(context, "Tiempo Medio", pattern.averageTotalTimeFormatted, Icons.timer, AppColors.rpeLow)),
                const SizedBox(width: 12),
                Expanded(child: _buildKpiCard(context, "Sesiones", "${pattern.count}", Icons.calendar_today, AppColors.rpeMid)),
              ],
            ),
            
            const SizedBox(height: 24),
            
            // Stats Chart
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                   const Text("Evolución del Rendimiento", style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                   const SizedBox(height: 24),
                   SizedBox(
                     height: 200,
                     child: _PerformanceChart(instances: sortedInstances),
                   ),
                ],
              ),
            ),
            
            const SizedBox(height: 24),

            // History List
            Align(
              alignment: Alignment.centerLeft,
              child: Text("Sesiones Realizadas", style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5))),
            ),
            const SizedBox(height: 12),
            
            ListView.separated(
              physics: const NeverScrollableScrollPhysics(),
              shrinkWrap: true,
              itemCount: sortedInstances.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final instance = sortedInstances[sortedInstances.length - 1 - index];
                return _buildHistoryItem(context, instance);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKpiCard(BuildContext context, String title, String value, IconData icon, Color color) {
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
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
          const SizedBox(height: 4),
          Text(title, style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5), fontSize: 11), textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _buildHistoryItem(BuildContext context, WorkoutInstance instance) {
    // Format pace
    final paceSec = instance.averagePace.round();
    final m = paceSec ~/ 60;
    final s = (paceSec % 60).toInt();
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
           Row(
             children: [
               Container(
                 padding: const EdgeInsets.all(8),
                 decoration: BoxDecoration(
                   color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.08),
                   shape: BoxShape.circle,
                 ),
                 child: Icon(Icons.fitness_center, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6), size: 16),
               ),
               const SizedBox(width: 12),
               Column(
                 crossAxisAlignment: CrossAxisAlignment.start,
                 children: [
                   Text(
                     "${instance.fecha.day}/${instance.fecha.month}/${instance.fecha.year}",
                     style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                   ),
                   const SizedBox(height: 4),
                   Text(
                     "Consistencia: ${(instance.consistency * 100).toInt()}%",
                     style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6), fontSize: 12),
                   ),
                 ],
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
                    WorkoutPattern.formatDuration(instance.entrenamiento.tiempoTotalSec()),
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

class _PerformanceChart extends StatelessWidget {
  final List<WorkoutInstance> instances;
  const _PerformanceChart({required this.instances});

  @override
  Widget build(BuildContext context) {
    final spots = instances.asMap().entries.map((e) {
      return FlSpot(e.key.toDouble(), e.value.averagePace.toDouble());
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
            isCurved: true, // Smooth curve for average performance
            color: AppColors.rest,
            barWidth: 3,
            dotData: const FlDotData(show: true),
            belowBarData: BarAreaData(
              show: true,
              color: AppColors.rest.withValues(alpha: 0.1),
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

