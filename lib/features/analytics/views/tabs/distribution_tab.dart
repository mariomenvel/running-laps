import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:running_laps/features/analytics/viewmodels/analytics_hub_controller.dart';
import 'package:running_laps/config/app_theme.dart';
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
    final color = _getConsistencyColor(score);
    final label = _getConsistencyLabel(score);
    
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
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.white, color.withOpacity(0.05)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.grey.shade200),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.1),
                blurRadius: 20,
                offset: const Offset(0, 10),
                spreadRadius: -5,
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Score circular centrado y mejorado
              SizedBox(
                width: 180,
                height: 180,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Sombra de fondo (glow)
                    Container(
                      width: 140,
                      height: 140,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: color.withOpacity(0.2),
                            blurRadius: 30,
                            spreadRadius: 5,
                          ),
                        ],
                      ),
                    ),
                    // Track de fondo
                    SizedBox(
                      width: 160,
                      height: 160,
                      child: CircularProgressIndicator(
                        value: 1.0,
                        strokeWidth: 14,
                        strokeCap: StrokeCap.round,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.grey.shade100),
                      ),
                    ),
                    // Progreso real
                    SizedBox(
                      width: 160,
                      height: 160,
                      child: CircularProgressIndicator(
                        value: score / 100,
                        strokeWidth: 14,
                        strokeCap: StrokeCap.round,
                        valueColor: AlwaysStoppedAnimation<Color>(color),
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${score.toInt()}',
                          style: TextStyle(
                            fontSize: 56,
                            fontWeight: FontWeight.w900,
                            color: color,
                            letterSpacing: -2,
                            height: 1.0,
                          ),
                        ),
                        Text(
                          'PUNTOS',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey.shade500,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 2,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              // Badge de estado
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: color.withOpacity(0.3)),
                ),
                child: Text(
                  label.toUpperCase(),
                  style: TextStyle(
                    color: color,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.0,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                _getConsistencyMessage(score),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey.shade700,
                  fontWeight: FontWeight.w500,
                  height: 1.4,
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
    if (score >= 80) return Colors.green.shade600;
    if (score >= 50) return Colors.orange.shade600;
    return Colors.red.shade600;
  }

  String _getConsistencyLabel(double score) {
    if (score >= 80) return 'Excelente';
    if (score >= 50) return 'Mantenimiento';
    return 'Mejorable';
  }

  String _getConsistencyMessage(double score) {
    if (score >= 80) return '¡Increíble! Tu disciplina es de atleta profesional.';
    if (score >= 50) return 'Buen ritmo. Mantente constante para ver mejores resultados.';
    return '¡Ánimo! El primer paso es ponerse las zapatillas.';
  }
}

/// Contenido de distribución de tags - Premium
class _TagDistributionContent extends StatefulWidget {
  final List<Entrenamiento> workouts;
  const _TagDistributionContent({required this.workouts});

  @override
  State<_TagDistributionContent> createState() => _TagDistributionContentState();
}

class _TagDistributionContentState extends State<_TagDistributionContent> {
  int touchedIndex = -1;

  @override
  Widget build(BuildContext context) {
    final Map<String, double> distribution = {};
    double totalKm = 0;

    for (var e in widget.workouts) {
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

    final sortedEntries = distribution.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final top3 = sortedEntries.take(3).toList();

    return Column(
      children: [
        // Donut chart with Central Label
        SizedBox(
          height: 220,
          child: Row(
            children: [
              Expanded(
                flex: 3,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    PieChart(
                      PieChartData(
                        pieTouchData: PieTouchData(
                          touchCallback: (FlTouchEvent event, pieTouchResponse) {
                            setState(() {
                              if (!event.isInterestedForInteractions ||
                                  pieTouchResponse == null ||
                                  pieTouchResponse.touchedSection == null) {
                                touchedIndex = -1;
                                return;
                              }
                              touchedIndex = pieTouchResponse.touchedSection!.touchedSectionIndex;
                            });
                          },
                        ),
                        sections: sortedEntries.asMap().entries.map((e) {
                          final index = e.key;
                          final entry = e.value;
                          final isTouched = index == touchedIndex;
                          final color = _getTagColor(index);
                          final fontSize = isTouched ? 16.0 : 12.0;
                          final radius = isTouched ? 60.0 : 50.0;
                          
                          return PieChartSectionData(
                            color: color,
                            value: entry.value,
                            title: isTouched ? '${entry.value.toStringAsFixed(0)}km' : '',
                            radius: radius,
                            titleStyle: TextStyle(
                              fontSize: fontSize,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              shadows: const [Shadow(color: Colors.black26, blurRadius: 4)],
                            ),
                          );
                        }).toList(),
                        centerSpaceRadius: 55,
                        sectionsSpace: 3,
                        borderData: FlBorderData(show: false),
                      ),
                    ),
                    // Central Text
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          totalKm >= 100 ? totalKm.toStringAsFixed(0) : totalKm.toStringAsFixed(1),
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w900,
                            color: Tema.brandPurple,
                            letterSpacing: -1,
                            height: 1.0,
                          ),
                        ),
                        Text(
                          'KM TOTALES',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            color: Colors.grey.shade500,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              // Legend Side
              Expanded(
                flex: 2,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: sortedEntries.take(5).toList().asMap().entries.map((e) {
                    final index = e.key;
                    final entry = e.value;
                    final isTouched = index == touchedIndex;
                    final color = _getTagColor(index);
                    final percent = (entry.value / totalKm * 100).toInt();
                    
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                      decoration: BoxDecoration(
                        color: isTouched ? color.withOpacity(0.1) : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(color: color.withOpacity(0.3), blurRadius: 4, spreadRadius: 1)
                              ]
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              entry.key,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: isTouched ? FontWeight.bold : FontWeight.w600,
                                color: isTouched ? color : Colors.black87,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            '$percent%',
                            style: TextStyle(
                              fontSize: 12,
                              color: isTouched ? color : Colors.grey.shade600,
                              fontWeight: isTouched ? FontWeight.w800 : FontWeight.w500,
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
        // Premium Badges for Top 3
        Wrap(
          spacing: 12,
          runSpacing: 12,
          alignment: WrapAlignment.center,
          children: top3.asMap().entries.map((e) {
            final index = e.key;
            final entry = e.value;
            final color = _getTagColor(index);
            final percent = (entry.value / totalKm * 100).toInt();
            
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: color.withOpacity(0.15),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
                border: Border.all(color: color.withOpacity(0.2)),
              ),
              child: IntrinsicWidth(
                child: Row(
                  children: [
                    Icon(Icons.stars_rounded, color: color, size: 18),
                    const SizedBox(width: 6),
                    Text(
                      entry.key,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '$percent%',
                        style: TextStyle(
                          fontSize: 11,
                          color: color,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Color _getTagColor(int index) {
    final colors = [
      Tema.brandPurple,
      const Color(0xFF2196F3),
      const Color(0xFF4CAF50),
      const Color(0xFFFF9800),
      const Color(0xFFE91E63),
      const Color(0xFF00BCD4),
    ];
    return colors[index % colors.length];
  }
}

