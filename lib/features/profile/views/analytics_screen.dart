import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:running_laps/app/tema.dart';
import 'package:running_laps/core/utils/tag_utils.dart'; // Import
import 'package:running_laps/features/profile/viewmodels/analytics_view_model.dart';

class AnalyticsScreen extends StatelessWidget {
  final AnalyticsViewModel viewModel;

  const AnalyticsScreen({Key? key, required this.viewModel}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Si no hay datos, mostrar mensaje
    if (viewModel.trainings.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Estadísticas')),
        body: const Center(child: Text('No hay entrenamientos para analizar')),
      );
    }
    
    final pieData = viewModel.trainingsByTag;
    final totalKm = viewModel.totalKm;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F8),
      appBar: AppBar(
        title: const Text(
          'Estadísticas', 
          style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // KPI CARDS
            Row(
              children: [
                Expanded(
                  child: _buildKpiCard(
                    'Total Km', 
                    totalKm.toStringAsFixed(1), 
                    Icons.map_rounded, 
                    Colors.blue.shade400
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildKpiCard(
                    'Tag Top', 
                    viewModel.mostFrequentTag.split('(').first.trim().replaceAll('#', ''), 
                    Icons.local_offer_rounded, 
                    Colors.orange.shade400
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 24),
            
            // PIE CHART TITLE
            const Text(
              'Distribución por Etiquetas',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            
            // PIE CHART
            Container(
              height: 300,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                 boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    offset: const Offset(0, 4),
                    blurRadius: 16,
                  ),
                ],
              ),
              child: pieData.isEmpty 
                  ? const Center(child: Text("Sin etiquetas")) 
                  : PieChart(
                      PieChartData(
                        sectionsSpace: 2,
                        centerSpaceRadius: 40,
                        sections: _buildPieSections(pieData),
                      ),
                    ),
            ),
            
             const SizedBox(height: 24),
             
             // BAR CHART (Distancia por Tag)
             const Text(
              'Distancia por Etiqueta (km)',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
             ),
             const SizedBox(height: 16),
             
             Container(
              height: 300,
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                 boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    offset: const Offset(0, 4),
                    blurRadius: 16,
                  ),
                ],
              ),
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: _getMaxY(viewModel.distanceByTag),
                  barTouchData: BarTouchData(
                    enabled: true,
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipColor: (_) => Colors.blueGrey,
                      getTooltipItem: (group, groupIndex, rod, rodIndex) {
                        final tagName = viewModel.distanceByTag.keys.elementAt(group.x.toInt());
                        return BarTooltipItem(
                          '$tagName\n',
                          const TextStyle(
                            color: Colors.white, 
                            fontWeight: FontWeight.bold, 
                            fontSize: 14,
                          ),
                          children: [
                            TextSpan(
                              text: '${rod.toY.toStringAsFixed(1)} km',
                              style: const TextStyle(
                                color: Colors.yellow,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                  titlesData: FlTitlesData(
                     show: true,
                     bottomTitles: AxisTitles(
                       sideTitles: SideTitles(
                         showTitles: true,
                         getTitlesWidget: (value, meta) {
                           final keys = viewModel.distanceByTag.keys.toList();
                           if (value.toInt() >= keys.length) return const Text('');
                           // Mostrar solo 3 letras del tag para no saturar
                           final tag = keys[value.toInt()];
                           return Padding(
                             padding: const EdgeInsets.only(top: 8.0),
                             child: Text(
                               tag.length > 4 ? tag.substring(0, 4) + '.' : tag,
                               style: const TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.bold),
                             ),
                           );
                         },
                         reservedSize: 30,
                       ),
                     ),
                     leftTitles: AxisTitles(
                       sideTitles: SideTitles(showTitles: false), // Ocultar eje Y para limpieza
                     ),
                     topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                     rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  gridData: FlGridData(show: false),
                  borderData: FlBorderData(show: false),
                  barGroups: _buildBarGroups(viewModel.distanceByTag),
                ),
              ),
             ),
             
             const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildKpiCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 10),
              Text(title, style: TextStyle(color: Colors.grey.shade600, fontSize: 12, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value, 
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.black87),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  List<PieChartSectionData> _buildPieSections(Map<String, int> data) {
    int index = 0;
    return data.entries.map((entry) {
      final color = viewModel.colorProvider(entry.key); // Dynamic Color
      index++;
      final isTouched = false;
      final double fontSize = isTouched ? 20 : 12;
      final double radius = isTouched ? 110 : 100;

      return PieChartSectionData(
        color: color,
        value: entry.value.toDouble(),
        title: '${entry.key}\n${entry.value}',
        radius: radius,
        titleStyle: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.bold,
          color: Colors.white,
          shadows: const [Shadow(color: Colors.black26, blurRadius: 2)],
        ),
      );
    }).toList();
  }

  List<BarChartGroupData> _buildBarGroups(Map<String, double> data) {
     int index = 0;
     return data.entries.map((entry) {
       final color = viewModel.colorProvider(entry.key); // Dynamic Color
       final x = index++;
       return BarChartGroupData(
         x: x,
         barRods: [
           BarChartRodData(
             toY: entry.value,
             color: color,
             width: 16,
             borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
             backDrawRodData: BackgroundBarChartRodData(
               show: true,
               toY: _getMaxY(data),
               color: Colors.grey.withOpacity(0.1),
             ),
           ),
         ],
       );
     }).toList();
  }

  double _getMaxY(Map<String, double> data) {
    if (data.isEmpty) return 10;
    final max = data.values.reduce((curr, next) => curr > next ? curr : next);
    return max * 1.2; // +20% breathing room
  }
}
