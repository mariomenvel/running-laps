import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:running_laps/features/analytics/viewmodels/analytics_hub_controller.dart';
import 'package:running_laps/app/tema.dart';
import 'package:running_laps/features/training/data/entrenamiento.dart';

/// Tab de Insights - Muestra balance, consistencia y próximos hitos
/// Diseño super premium iOS-style con utilidad clara
class DistributionTab extends StatelessWidget {
  final AnalyticsHubController controller;

  const DistributionTab({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: controller.filteredData,
      builder: (context, data, _) {
        if (controller.isLoading.value) {
          return const Center(child: CircularProgressIndicator(color: Tema.brandPurple));
        }

        if (data.isEmpty) {
          return const Center(child: Text("No hay datos para el periodo seleccionado"));
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildTrainingBalanceSection(data),
              const SizedBox(height: 32),
              _buildConsistencySection(data),
              const SizedBox(height: 32),
              _buildNextMilestoneSection(data),
              const SizedBox(height: 40),
            ],
          ),
        );
      },
    );
  }

  /// Sección de balance de entrenamiento
  Widget _buildTrainingBalanceSection(List<Entrenamiento> data) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Balance de Entrenamiento',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.white, Colors.purple.shade50.withOpacity(0.3)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.grey.shade200),
            boxShadow: [
              BoxShadow(
                color: Tema.brandPurple.withOpacity(0.1),
                blurRadius: 20,
                offset: const Offset(0, 10),
                spreadRadius: -5,
              ),
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 15,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: _TagDistributionContent(workouts: data),
        ),
      ],
    );
  }

  /// Sección de consistencia
  Widget _buildConsistencySection(List<Entrenamiento> data) {
    final score = _calculateConsistencyScore(data);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Consistencia',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.white, Colors.green.shade50.withOpacity(0.3)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.grey.shade200),
            boxShadow: [
              BoxShadow(
                color: Colors.green.withOpacity(0.1),
                blurRadius: 20,
                offset: const Offset(0, 10),
                spreadRadius: -5,
              ),
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 15,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            children: [
              // Score circular
              SizedBox(
                width: 150,
                height: 150,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CircularProgressIndicator(
                      value: score / 100,
                      strokeWidth: 12,
                      backgroundColor: Colors.grey.shade200,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        _getConsistencyColor(score),
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${score.toInt()}',
                          style: TextStyle(
                            fontSize: 48,
                            fontWeight: FontWeight.bold,
                            color: _getConsistencyColor(score),
                            letterSpacing: -1,
                          ),
                        ),
                        Text(
                          'Score',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Text(
                _getConsistencyMessage(score),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey.shade700,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Sección de próximo hito
  Widget _buildNextMilestoneSection(List<Entrenamiento> data) {
    final totalKm = data.fold<double>(0, (sum, e) => sum + (e.distanciaTotalM() / 1000));
    final nextMilestone = ((totalKm ~/ 50) + 1) * 50;
    final remaining = nextMilestone - totalKm;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Próximo Hito',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.white, Colors.amber.shade50.withOpacity(0.3)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.grey.shade200),
            boxShadow: [
              BoxShadow(
                color: Colors.amber.withOpacity(0.1),
                blurRadius: 20,
                offset: const Offset(0, 10),
                spreadRadius: -5,
              ),
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 15,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.amber.shade400, Colors.amber.shade600],
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.amber.withOpacity(0.5),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: const Icon(Icons.emoji_events, color: Colors.white, size: 40),
              ),
              const SizedBox(height: 20),
              Text(
                '${remaining.toStringAsFixed(1)} km',
                style: const TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  color: Colors.amber,
                  letterSpacing: -1,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'para alcanzar $nextMilestone km',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey.shade700,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 20),
              LinearProgressIndicator(
                value: totalKm / nextMilestone,
                backgroundColor: Colors.grey.shade200,
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.amber),
                minHeight: 8,
                borderRadius: BorderRadius.circular(4),
              ),
            ],
          ),
        ),
      ],
    );
  }

  double _calculateConsistencyScore(List<Entrenamiento> data) {
    if (data.isEmpty) return 0;
    
    // Score basado en frecuencia de entrenamientos
    final days = DateTime.now().difference(data.last.fecha).inDays;
    if (days == 0) return 100;
    
    final frequency = data.length / (days / 7); // entrenamientos por semana
    final score = (frequency / 4 * 100).clamp(0, 100); // 4 entrenos/semana = 100%
    
    return score.toDouble();
  }

  Color _getConsistencyColor(double score) {
    if (score >= 75) return Colors.green;
    if (score >= 50) return Colors.orange;
    return Colors.red;
  }

  String _getConsistencyMessage(double score) {
    if (score >= 75) return '¡Excelente! Mantén este ritmo constante.';
    if (score >= 50) return 'Buen trabajo. Intenta entrenar más regularmente.';
    return 'Aumenta la frecuencia de tus entrenamientos.';
  }
}

/// Contenido de distribución de tags - Premium
class _TagDistributionContent extends StatelessWidget {
  final List<Entrenamiento> workouts;
  const _TagDistributionContent({required this.workouts});

  @override
  Widget build(BuildContext context) {
    final Map<String, double> distribution = {};
    double totalKm = 0;

    for (var e in workouts) {
      final km = e.distanciaTotalM() / 1000.0;
      totalKm += km;
      if (e.tags != null && e.tags!.isNotEmpty) {
        for (var tag in e.tags!) {
          distribution[tag] = (distribution[tag] ?? 0) + km;
        }
      } else {
        distribution['Sin etiqueta'] = (distribution['Sin etiqueta'] ?? 0) + km;
      }
    }

    if (distribution.isEmpty) return const SizedBox.shrink();

    // Top 3 tags
    final sortedEntries = distribution.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final top3 = sortedEntries.take(3).toList();

    return Column(
      children: [
        // Donut chart
        SizedBox(
          height: 180,
          child: Row(
            children: [
              Expanded(
                flex: 2,
                child: PieChart(
                  PieChartData(
                    sections: sortedEntries.asMap().entries.map((e) {
                      final index = e.key;
                      final entry = e.value;
                      final color = _getTagColor(index);
                      
                      return PieChartSectionData(
                        color: color,
                        value: entry.value,
                        title: '',
                        radius: 50,
                      );
                    }).toList(),
                    centerSpaceRadius: 40,
                    sectionsSpace: 2,
                    borderData: FlBorderData(show: false),
                  ),
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                flex: 1,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: sortedEntries.asMap().entries.map((e) {
                    final index = e.key;
                    final entry = e.value;
                    final color = _getTagColor(index);
                    final percent = (entry.value / totalKm * 100).toInt();
                    
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: color,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              entry.key,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            '$percent%',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade600,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        // Top 3 badges
        Wrap(
          spacing: 12,
          children: top3.asMap().entries.map((e) {
            final index = e.key;
            final entry = e.value;
            final color = _getTagColor(index);
            final percent = (entry.value / totalKm * 100).toInt();
            
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [color.withOpacity(0.2), color.withOpacity(0.1)],
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: color.withOpacity(0.5)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.label, color: color, size: 16),
                  const SizedBox(width: 8),
                  Text(
                    entry.key,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '$percent%',
                    style: TextStyle(
                      fontSize: 12,
                      color: color.withOpacity(0.8),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Color _getTagColor(int index) {
    final colors = [
      Colors.purple,
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.pink,
      Colors.teal,
    ];
    return colors[index % colors.length];
  }
}
