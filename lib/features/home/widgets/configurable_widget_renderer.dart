import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:running_laps/features/home/data/home_layout_config.dart';
import 'package:running_laps/features/training/data/entrenamiento.dart';
import 'package:running_laps/config/app_theme.dart';
import 'package:running_laps/core/theme/app_colors.dart';
import 'package:running_laps/core/widgets/kpi_card_with_delta.dart';

/// Renderiza un widget configurable según su tipo y configuración
class ConfigurableWidgetRenderer extends StatelessWidget {
  final HomeWidget config;
  final List<Entrenamiento> data;

  const ConfigurableWidgetRenderer({
    super.key,
    required this.config,
    required this.data,
  });

  @override
  Widget build(BuildContext context) {
    if (!config.visible) return const SizedBox.shrink();

    final title = config.config['title'] as String? ?? 'Widget';
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.transparent : Colors.black.withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 200,
            child: _buildChartContent(context),
          ),
        ],
      ),
    );
  }

  Widget _buildChartContent(BuildContext context) {
    if (data.isEmpty) {
      return const Center(child: Text("Sin datos suficientes"));
    }

    switch (config.type) {
      case WidgetType.lineChart:
        return _buildLineChart();
      case WidgetType.barChart:
        return _buildBarChart();
      case WidgetType.donutChart:
        return _buildDonutChart();
      case WidgetType.heatmap:
        return const Center(child: Text("Heatmap (Próximamente)"));
        // TODO: Implement Github-style heatmap in Phase 6
      case WidgetType.carousel:
         return _buildCarousel();
      case WidgetType.kpiCard:
        return _buildKpiCardPlaceholder(context);
      default:
        return const Center(child: Text("Widget no implementado"));
    }
  }

  Widget _buildLineChart() {
    // Example: Pace progression over time
    // Metric can be 'pace', 'rpe', etc. from config['metric']
    final metric = config.config['metric'] as String? ?? 'pace';
    final points = <FlSpot>[];
    
    // Sort by date ascending
    final sortedData = List<Entrenamiento>.from(data)
      ..sort((a, b) => a.fecha.compareTo(b.fecha));

    for (int i = 0; i < sortedData.length; i++) {
        final e = sortedData[i];
        double yVal = 0;
        if (metric == 'pace') {
            yVal = (e.ritmoMedioSecPorKm() ?? 0).toDouble();
        } else if (metric == 'rpe') {
            yVal = e.rpePromedio();
        }
        points.add(FlSpot(i.toDouble(), yVal));
    }

    if (points.isEmpty) return const Center(child: Text("No hay datos"));

    // Normalize for chart if needed, or just plot
    return LineChart(
      LineChartData(
        gridData: const FlGridData(show: false),
        titlesData: FlTitlesData(
            leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (value, meta) {
                        return const Text(''); // Simplify for now
                    }
                ),
            ),
        ),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: points,
            isCurved: true,
            color: AppColors.brand,
            barWidth: 3,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              color: AppColors.brand.withValues(alpha: 0.1),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBarChart() {
     // Example: Weekly Distance
     final metric = config.config['metric'] as String? ?? 'distance';
     
     // Simple aggregation: Just show last 7 workouts for now as bars
     final displayData = data.take(7).toList().reversed.toList();
     
     return BarChart(
        BarChartData(
          gridData: const FlGridData(show: false),
          titlesData: const FlTitlesData(show: false),
          borderData: FlBorderData(show: false),
          barGroups: displayData.asMap().entries.map((e) {
             final index = e.key;
             final workout = e.value;
             double yVal = 0;
             if (metric == 'distance') {
                 yVal = workout.distanciaTotalM() / 1000.0;
             }
             return BarChartGroupData(
                 x: index,
                 barRods: [
                    BarChartRodData(
                        toY: yVal,
                        color: AppColors.rest,
                        borderRadius: BorderRadius.circular(4),
                        width: 16,
                    )
                 ]
             );
          }).toList(),
        )
     );
  }
  
  Widget _buildDonutChart() {
      // Example: Tag distribution
      final Map<String, double> distribution = {};
      for (var e in data) {
          if (e.tags != null) {
              for (var tag in e.tags!) {
                  distribution[tag] = (distribution[tag] ?? 0) + (e.distanciaTotalM() / 1000.0);
              }
          } else {
             distribution['Sin etiqueta'] = (distribution['Sin etiqueta'] ?? 0) + (e.distanciaTotalM() / 1000.0);
          }
      }
      
      if (distribution.isEmpty) return const Center(child: Text("Sin etiquetas"));
      
      final sections = distribution.entries.toList().asMap().entries.map((e) {
          final index = e.key;
          final entry = e.value;
          final color = Colors.primaries[index % Colors.primaries.length];
          
          return PieChartSectionData(
              color: color,
              value: entry.value,
              title: '', // entry.key.substring(0, 1).toUpperCase(),
              radius: 20,
          );
      }).toList();
      
      return Row(
         children: [
            Expanded(
                child: PieChart(
                    PieChartData(
                        sections: sections,
                        centerSpaceRadius: 40,
                        sectionsSpace: 2,
                    )
                )
            ),
            // Simple Legend
            Column(
               mainAxisAlignment: MainAxisAlignment.center,
               crossAxisAlignment: CrossAxisAlignment.start,
               children: distribution.entries.take(4).map((e) => 
                   Padding(
                       padding: const EdgeInsets.symmetric(vertical: 2),
                       child: Text("${e.key}: ${e.value.toStringAsFixed(1)}km", style: const TextStyle(fontSize: 12)),
                   )
               ).toList(),
            )
         ]
      );
  }

  Widget _buildCarousel() {
      // Basic list of recent workouts cards
      return ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: data.length > 5 ? 5 : data.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
            final e = data[index];
            return Container(
                width: 140,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                   color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.06),
                   borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                   crossAxisAlignment: CrossAxisAlignment.start,
                   children: [
                       Text(
                           "${e.fecha.day}/${e.fecha.month}",
                           style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6), fontSize: 12),
                       ),
                       const SizedBox(height: 8),
                       Text(
                           "${(e.distanciaTotalM() / 1000).toStringAsFixed(1)} km",
                           style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                       ),
                       Text(
                           e.ritmoMedioTexto(),
                           style: TextStyle(color: Theme.of(context).brightness == Brightness.dark ? AppColors.brandLight : AppColors.brand, fontWeight: FontWeight.w600),
                       ),
                   ],
                ),
            );
        },
      );
  }

  Widget _buildKpiCardPlaceholder(BuildContext context) {
    // KPI cards are rendered directly in HomeView with full metric computation.
    // This placeholder is shown if a kpiCard widget appears outside the home grid.
    return KpiCardWithDelta(
      title: config.config['title'] as String? ?? 'KPI',
      value: '-',
      primaryColor: AppColors.brand,
      icon: Icons.bar_chart_rounded,
      compact: true,
    );
  }
}

