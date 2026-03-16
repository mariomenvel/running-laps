import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:running_laps/features/analytics/data/series_pattern.dart';
import 'package:running_laps/features/analytics/widgets/pattern_carousel.dart';
import 'package:running_laps/config/app_theme.dart';

class SeriesPatternCarouselView extends StatelessWidget {
  final List<SeriesPattern> patterns;
  final int initialIndex;

  const SeriesPatternCarouselView({
    super.key,
    required this.patterns,
    this.initialIndex = 0,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Patrones de Series'),
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Tema.brandPurple),
          onPressed: () => Navigator.pop(context),
        ),
        titleTextStyle: TextStyle(
          color: Theme.of(context).colorScheme.onSurface,
          fontSize: 17,
          fontWeight: FontWeight.w600,
        ),
      ),
      body: PatternCarousel<SeriesPattern>(
        items: patterns,
        initialPage: initialIndex,
        itemBuilder: (context, pattern, index) {
          return _SeriesPatternContent(pattern: pattern);
        },
      ),
    );
  }
}

class _SeriesPatternContent extends StatelessWidget {
  final SeriesPattern pattern;

  const _SeriesPatternContent({required this.pattern});

  @override
  Widget build(BuildContext context) {
    final sortedInstances = List<SerieInstance>.from(pattern.instances)
      ..sort((a, b) => a.fecha.compareTo(b.fecha));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Pattern title
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Tema.brandPurple.withOpacity(0.1), Colors.transparent],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              children: [
                Text(
                  pattern.distanceFormatted,
                  style: TextStyle(
                    fontSize: 40,
                    fontWeight: FontWeight.bold,
                    foreground: Paint()
                      ..shader = LinearGradient(
                        colors: [Tema.brandPurple, Colors.blue.shade600],
                      ).createShader(const Rect.fromLTWH(0, 0, 200, 70)),
                    letterSpacing: -1,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${pattern.count} series en ${pattern.uniqueWorkoutsCount} entrenamientos',
                  style: TextStyle(
                    fontSize: 14,
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // KPI Header
          Row(
            children: [
              Expanded(
                child: _buildKpiCard(
                  context,
                  "Mejor Ritmo",
                  pattern.bestPaceFormatted,
                  Icons.emoji_events,
                  Colors.amber,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildKpiCard(
                  context,
                  "Ritmo Medio",
                  pattern.averagePaceFormatted,
                  Icons.speed,
                  Colors.blue,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildKpiCard(
                  context,
                  "Total Veces",
                  "${pattern.count}",
                  Icons.repeat,
                  Colors.purple,
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Chart Section
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Theme.of(context).colorScheme.outline.withOpacity(0.15)),
              boxShadow: [
                BoxShadow(
                  color: Tema.brandPurple.withOpacity(0.08),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                  spreadRadius: -4,
                ),
                BoxShadow(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.transparent
                      : Colors.black.withOpacity(0.04),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Progresión del Ritmo",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
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
            child: Text(
              "Historial",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
              ),
            ),
          ),
          const SizedBox(height: 12),

          ListView.separated(
            physics: const NeverScrollableScrollPhysics(),
            shrinkWrap: true,
            itemCount: sortedInstances.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final instance =
                  sortedInstances[sortedInstances.length - 1 - index];
              return _buildHistoryItem(context, instance);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildKpiCard(BuildContext context, String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.2), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.15),
            blurRadius: 15,
            offset: const Offset(0, 6),
            spreadRadius: -3,
          ),
          BoxShadow(
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.transparent
                : Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [color.withOpacity(0.8), color],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.4),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(icon, color: Colors.white, size: 24),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
              fontSize: 11,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.3,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryItem(BuildContext context, SerieInstance instance) {
    final m = instance.paceSecKm ~/ 60;
    final s = (instance.paceSecKm % 60).toInt();
    final pace = '$m:${s.toString().padLeft(2, '0')}';

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Theme.of(context).colorScheme.outline.withOpacity(0.15)),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.transparent
                : Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "${instance.fecha.day}/${instance.fecha.month}/${instance.fecha.year}",
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                "Serie #${instance.serieIndex + 1}",
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Tema.brandPurple.withOpacity(0.15),
                  Tema.brandPurple.withOpacity(0.08),
                ],
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Tema.brandPurple.withOpacity(0.3)),
            ),
            child: Text(
              "$pace /km",
              style: const TextStyle(
                color: Tema.brandPurple,
                fontWeight: FontWeight.bold,
                fontSize: 14,
                letterSpacing: -0.3,
              ),
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

    final maxY = spots.map((e) => e.y).reduce((a, b) => a > b ? a : b);
    final minY = spots.map((e) => e.y).reduce((a, b) => a < b ? a : b);
    final targetMinY = (minY * 0.9).floorToDouble();

    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (_) => FlLine(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.06)),
        ),
        titlesData: FlTitlesData(show: false),
        borderData: FlBorderData(show: false),
        minY: targetMinY,
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: Tema.brandPurple,
            barWidth: 3,
            dotData: const FlDotData(show: true),
            belowBarData: BarAreaData(
              show: true,
              color: Tema.brandPurple.withOpacity(0.1),
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
                  const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                );
              }).toList();
            },
          ),
        ),
      ),
    );
  }
}

