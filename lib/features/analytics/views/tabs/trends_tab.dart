import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:running_laps/features/analytics/viewmodels/analytics_hub_controller.dart';
import 'package:running_laps/config/app_theme.dart';
import 'package:running_laps/features/training/data/entrenamiento.dart';

/// Tab de Progreso - Muestra mejores marcas y evolución
/// Diseño super premium iOS-style
class TrendsTab extends StatelessWidget {
  final AnalyticsHubController controller;

  const TrendsTab({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: controller.isLoading,
      builder: (context, isLoading, _) {
        if (isLoading) {
          return const Center(child: CircularProgressIndicator(color: AppColors.brand));
        }
        return ValueListenableBuilder(
          valueListenable: controller.filteredData,
          builder: (context, data, _) {
            if (data.isEmpty) {
          return const Center(child: Text("No hay datos para el periodo seleccionado"));
        }

        return SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildBestPerformancesSection(context, data),
                  const SizedBox(height: 32),
                  _buildWeeklyProgressSection(context, data),
                  const SizedBox(height: 32),
                  _buildPaceEvolutionSection(context, data),
                  const SizedBox(height: 40),
                ],
              ),
            );
          },
        );
      },
    );
  }

  /// Sección de mejores marcas - Estilo premium
  Widget _buildBestPerformancesSection(BuildContext context, List<Entrenamiento> data) {
    final best400m = _findBestPaceForDistance(data, 400);
    final best1km = _findBestPaceForDistance(data, 1000);
    final best5km = _findBestPaceForDistance(data, 5000);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Mejores Marcas',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onSurface,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildBestMarkCard(
                context,
                '400m',
                best400m,
                Icons.bolt,
                AppColors.rpeMid,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildBestMarkCard(
                context,
                '1km',
                best1km,
                Icons.speed,
                AppColors.rest,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildBestMarkCard(
                context,
                '5km',
                best5km,
                Icons.emoji_events,
                AppColors.brand,
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// Card de mejor marca - Super premium
  Widget _buildBestMarkCard(BuildContext context, String distance, String? pace, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: color.withValues(alpha: 0.3),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.2),
            blurRadius: 20,
            offset: const Offset(0, 10),
            spreadRadius: -5,
          ),
          BoxShadow(
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.transparent
                : Colors.black.withValues(alpha: 0.05),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.5),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Icon(icon, color: Colors.white, size: 28),
          ),
          const SizedBox(height: 16),
          Text(
            distance,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            pace ?? '-',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
              letterSpacing: -0.5,
            ),
          ),
        ],
      ),
    );
  }

  /// Sección de progreso semanal
  Widget _buildWeeklyProgressSection(BuildContext context, List<Entrenamiento> data) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Volumen Semanal',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onSurface,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.15)),
            boxShadow: [
              BoxShadow(
                color: AppColors.rest.withValues(alpha: 0.1),
                blurRadius: 20,
                offset: const Offset(0, 10),
                spreadRadius: -5,
              ),
              BoxShadow(
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.transparent
                    : Colors.black.withValues(alpha: 0.05),
                blurRadius: 15,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: SizedBox(
            height: 200,
            child: _WeeklyVolumeChart(workouts: data),
          ),
        ),
      ],
    );
  }

  /// Sección de evolución de ritmo
  Widget _buildPaceEvolutionSection(BuildContext context, List<Entrenamiento> data) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Evolución de Ritmo',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onSurface,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.15)),
            boxShadow: [
              BoxShadow(
                color: AppColors.brand.withValues(alpha: 0.1),
                blurRadius: 20,
                offset: const Offset(0, 10),
                spreadRadius: -5,
              ),
              BoxShadow(
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.transparent
                    : Colors.black.withValues(alpha: 0.05),
                blurRadius: 15,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: SizedBox(
            height: 200,
            child: _PaceEvolutionChart(workouts: data),
          ),
        ),
      ],
    );
  }

  /// Encuentra mejor ritmo para una distancia específica
  String? _findBestPaceForDistance(List<Entrenamiento> data, int targetDistance) {
    double? bestPace;
    final tolerance = targetDistance < 1000 ? 0.20 : targetDistance < 3000 ? 0.10 : 0.15;
    final minDist = targetDistance * (1 - tolerance);
    final maxDist = targetDistance * (1 + tolerance);

    for (var workout in data) {
      for (var serie in workout.series) {
        if (serie.distanciaM >= minDist && serie.distanciaM <= maxDist) {
          final paceSec = serie.ritmoSecPorKm();
          if (paceSec != null) {
            final pace = paceSec.toDouble();
            if (pace > 0 && (bestPace == null || pace < bestPace)) {
              bestPace = pace;
            }
          }
        }
      }
    }

    if (bestPace == null) return null;
    final m = bestPace ~/ 60;
    final s = (bestPace % 60).toInt();
    return '$m:${s.toString().padLeft(2, '0')}';
  }
}

/// Gráfica de volumen semanal - Premium
class _WeeklyVolumeChart extends StatelessWidget {
  final List<Entrenamiento> workouts;
  const _WeeklyVolumeChart({required this.workouts});

  @override
  Widget build(BuildContext context) {
    final sorted = List<Entrenamiento>.from(workouts)
      ..sort((a, b) => a.fecha.compareTo(b.fecha));

    final displayData = sorted.length > 12 ? sorted.sublist(sorted.length - 12) : sorted;

    final barGroups = displayData.asMap().entries.map((e) {
      final km = e.value.distanciaTotalM() / 1000.0;
      return BarChartGroupData(
        x: e.key,
        barRods: [
          BarChartRodData(
            toY: km,
            gradient: LinearGradient(
              colors: [AppColors.rest, AppColors.rest],
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
            ),
            width: 20,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
          ),
        ],
      );
    }).toList();

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (_) => AppColors.iconMuted,
            tooltipBorderRadius: BorderRadius.circular(8),
            tooltipPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              final workout = displayData[groupIndex];
              final date = "${workout.fecha.day}/${workout.fecha.month}";
              return BarTooltipItem(
                "$date\n",
                const TextStyle(
                  color: Colors.white70,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
                children: [
                  TextSpan(
                    text: "${rod.toY.toStringAsFixed(1)} km",
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (value) => FlLine(
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1),
            strokeWidth: 1,
          ),
        ),
        titlesData: const FlTitlesData(show: false),
        borderData: FlBorderData(show: false),
        barGroups: barGroups,
      ),
    );
  }
}

/// Gráfica de evolución de ritmo - Premium
class _PaceEvolutionChart extends StatelessWidget {
  final List<Entrenamiento> workouts;
  const _PaceEvolutionChart({required this.workouts});

  @override
  Widget build(BuildContext context) {
    final sorted = List<Entrenamiento>.from(workouts)
      ..sort((a, b) => a.fecha.compareTo(b.fecha));

    final displayData = sorted.length > 20 ? sorted.sublist(sorted.length - 20) : sorted;

    final spots = displayData.asMap().entries.map((e) {
      final pace = (e.value.ritmoMedioSecPorKm() ?? 0).toDouble();
      return FlSpot(e.key.toDouble(), pace);
    }).toList();

    if (spots.isEmpty) return const Center(child: Text('Sin datos'));

    final maxY = spots.map((e) => e.y).reduce((a, b) => a > b ? a : b);
    final minY = spots.map((e) => e.y).reduce((a, b) => a < b ? a : b);
    final targetMinY = (minY * 0.95).floorToDouble();

    return LineChart(
      LineChartData(
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => AppColors.iconMuted,
            tooltipBorderRadius: BorderRadius.circular(8),
            tooltipPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            getTooltipItems: (touchedSpots) {
              return touchedSpots.map((spot) {
                final workout = displayData[spot.x.toInt()];
                final date = "${workout.fecha.day}/${workout.fecha.month}";
                final totalSeconds = spot.y.toInt();
                final m = totalSeconds ~/ 60;
                final s = (totalSeconds % 60).toString().padLeft(2, '0');

                return LineTooltipItem(
                  "$date\n",
                  const TextStyle(
                    color: Colors.white70,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                  children: [
                    TextSpan(
                      text: "$m:$s /km",
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                );
              }).toList();
            },
          ),
        ),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (value) => FlLine(
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1),
            strokeWidth: 1,
          ),
        ),
        titlesData: const FlTitlesData(show: false),
        borderData: FlBorderData(show: false),
        minY: targetMinY > 0 ? targetMinY : 0,
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            curveSmoothness: 0.4,
            gradient: LinearGradient(
              colors: [AppColors.brand, AppColors.brand],
            ),
            barWidth: 4,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                colors: [
                  AppColors.brand.withValues(alpha: 0.3),
                  AppColors.brand.withValues(alpha: 0.0),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

