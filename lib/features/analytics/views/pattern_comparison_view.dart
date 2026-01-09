import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:running_laps/config/app_theme.dart';
import 'package:running_laps/features/analytics/data/workout_pattern.dart';
import 'package:running_laps/features/training/data/serie.dart';

class PatternComparisonView extends StatelessWidget {
  final WorkoutInstance instanceA;
  final WorkoutInstance instanceB;

  const PatternComparisonView({
    super.key,
    required this.instanceA,
    required this.instanceB,
  });

  @override
  Widget build(BuildContext context) {
    // Asegurar que A es el más antiguo para la comparación cronológica (opcional)
    // Pero mejor izquierda: A, derecha: B tal cual se pasaron.
    
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Comparar Entrenamientos'),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // HEADER COMPARACIÓN
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.white, Colors.grey.shade50],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.grey.shade200),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 15,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(child: _buildHeaderColumn(instanceA, Colors.blue)),
                  const SizedBox(width: 20),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Tema.brandPurple.withOpacity(0.1), Tema.brandPurple.withOpacity(0.05)],
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.compare_arrows, size: 28, color: Tema.brandPurple),
                  ),
                  const SizedBox(width: 20),
                  Expanded(child: _buildHeaderColumn(instanceB, Colors.purple)),
                ],
              ),
            ),
            const SizedBox(height: 32),
            
            // STATS COMPARISONS
            _buildComparisonRow(
              "Ritmo Medio",
              _formatPace(instanceA.averagePace.toInt()),
              _formatPace(instanceB.averagePace.toInt()),
              (instanceA.averagePace < instanceB.averagePace) ? -1 : 1, // -1: A gana (menor pace)
            ),
            const SizedBox(height: 16),
            _buildComparisonRow(
              "Consistencia (Var)",
              instanceA.consistency.toStringAsFixed(1),
              instanceB.consistency.toStringAsFixed(1),
              (instanceA.consistency < instanceB.consistency) ? -1 : 1, // menor var gana
            ),
             const SizedBox(height: 16),
             _buildComparisonRow(
               "Top Serie",
               _formatPace(_getBestSeriesPace(instanceA)),
               _formatPace(_getBestSeriesPace(instanceB)),
                (_getBestSeriesPace(instanceA) < _getBestSeriesPace(instanceB)) ? -1 : 1,
             ),

            const SizedBox(height: 32),
            
            // CHART: SERIES POR SERIES
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                "Comparativa Serie a Serie",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              height: 300,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.white, Colors.grey.shade50],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.grey.shade200),
                boxShadow: [
                  BoxShadow(
                    color: Tema.brandPurple.withOpacity(0.08),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                    spreadRadius: -4,
                  ),
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: BarChart(
                BarChartData(
                  barTouchData: BarTouchData(
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipColor: (group) => Colors.blueGrey,
                      getTooltipItem: (group, groupIndex, rod, rodIndex) {
                         String label = rodIndex == 0 ? "A" : "B";
                         return BarTooltipItem(
                           "$label: ${_formatPace(rod.toY.toInt())}",
                           const TextStyle(color: Colors.white),
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
                          return Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text(
                              "S${value.toInt() + 1}",
                              style: const TextStyle(fontSize: 10),
                            ),
                          );
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  borderData: FlBorderData(show: false),
                  gridData: FlGridData(show: false),
                  barGroups: _buildBarGroups(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderColumn(WorkoutInstance instance, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withOpacity(0.1), color.withOpacity(0.05)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3), width: 2),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              DateFormat('d MMM yyyy').format(instance.fecha),
              style: TextStyle(
                color: color.withOpacity(0.8),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            _formatPace(instance.averagePace.toInt()),
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 28,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            height: 4,
            width: 50,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [color, color.withOpacity(0.5)],
              ),
              borderRadius: BorderRadius.circular(2),
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.3),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildComparisonRow(String label, String valA, String valB, int winner) {
    // winner: -1 (A), 1 (B), 0 (Empate)
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.white, Colors.grey.shade50.withOpacity(0.5)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    gradient: winner == -1
                        ? LinearGradient(
                            colors: [Colors.green.shade50, Colors.green.shade100],
                          )
                        : null,
                    color: winner == -1 ? null : Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: winner == -1 ? Colors.green : Colors.grey.shade300,
                      width: winner == -1 ? 2 : 1,
                    ),
                  ),
                  child: Text(
                    valA,
                    style: TextStyle(
                      fontWeight: winner == -1 ? FontWeight.bold : FontWeight.w600,
                      color: winner == -1 ? Colors.green.shade700 : Colors.black87,
                      fontSize: 18,
                      letterSpacing: -0.3,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: winner == 0
                    ? Icon(Icons.remove, size: 20, color: Colors.grey.shade400)
                    : Icon(
                        winner == -1 ? Icons.arrow_back : Icons.arrow_forward,
                        color: Colors.green.shade600,
                        size: 24,
                      ),
              ),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    gradient: winner == 1
                        ? LinearGradient(
                            colors: [Colors.green.shade50, Colors.green.shade100],
                          )
                        : null,
                    color: winner == 1 ? null : Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: winner == 1 ? Colors.green : Colors.grey.shade300,
                      width: winner == 1 ? 2 : 1,
                    ),
                  ),
                  child: Text(
                    valB,
                    style: TextStyle(
                      fontWeight: winner == 1 ? FontWeight.bold : FontWeight.w600,
                      color: winner == 1 ? Colors.green.shade700 : Colors.black87,
                      fontSize: 18,
                      letterSpacing: -0.3,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ],
          )
        ],
      ),
    );
  }

  List<BarChartGroupData> _buildBarGroups() {
    final listA = instanceA.entrenamiento.series;
    final listB = instanceB.entrenamiento.series;
    final count = listA.length < listB.length ? listA.length : listB.length; // Comparar hasta el min length

    return List.generate(count, (index) {
      double valA = 0;
      double valB = 0;
      try { valA = listA[index].ritmoSecPorKm().toDouble(); } catch(e){}
      try { valB = listB[index].ritmoSecPorKm().toDouble(); } catch(e){}

      return BarChartGroupData(
        x: index,
        barRods: [
          BarChartRodData(toY: valA, color: Colors.blue, width: 8),
          BarChartRodData(toY: valB, color: Colors.purple, width: 8),
        ],
      );
    });
  }

  String _formatPace(int secKm) {
    final m = secKm ~/ 60;
    final s = secKm % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }
  
  int _getBestSeriesPace(WorkoutInstance i) {
    return i.bestSerie?.ritmoSecPorKm() ?? 0;
  }
}

