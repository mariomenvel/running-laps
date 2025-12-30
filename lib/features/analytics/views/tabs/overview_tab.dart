import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:running_laps/features/analytics/viewmodels/analytics_hub_controller.dart';
import 'package:running_laps/core/constants/app_help_content.dart';
import 'package:running_laps/core/widgets/kpi_card_with_delta.dart';
import 'package:running_laps/app/tema.dart';
import 'package:running_laps/features/analytics/data/coach_insight_service.dart';
import 'package:running_laps/features/analytics/widgets/coach_insight_widget.dart';
import 'package:running_laps/features/training/data/entrenamiento.dart';

class OverviewTab extends StatelessWidget {
  final AnalyticsHubController controller;

  const OverviewTab({
    super.key,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: controller.filteredData,
      builder: (context, data, _) {
        if (controller.isLoading.value) {
           return const Center(child: CircularProgressIndicator(color: Tema.brandPurple));
        }

        if (data.isEmpty) {
          return const Center(
            child: Text(
              "No hay datos para el periodo seleccionado",
              style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold),
            ),
          );
        }

        final totalKm = controller.totalDistanceKm;
        final totalWorkouts = controller.totalWorkouts;
        final avgPace = controller.formattedAvgPace;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1000),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. COACH INSIGHT (Top priority)
                  CoachInsightWidget(insight: CoachInsightService().generateInsight(data)),
                  const SizedBox(height: 32),
    
                  // 2. RESUMEN GLOBAL (KPIs)
                  const Text(
                    'Resumen Global',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: -0.5),
                  ),
                  const SizedBox(height: 16),
                  GridView.count(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    childAspectRatio: 1.1,
                    children: [
                      KpiCardWithDelta(
                        title: 'Distancia',
                        value: '${totalKm.toStringAsFixed(1)} km',
                        subtitle: 'En periodo',
                        icon: Icons.map,
                        primaryColor: Colors.blue,
                        helpText: AppHelpContent.analyticsDistancia,
                      ),
                      KpiCardWithDelta(
                        title: 'Sesiones',
                        value: '$totalWorkouts',
                        subtitle: 'Entrenamientos',
                        icon: Icons.directions_run,
                        primaryColor: Colors.orange,
                        helpText: AppHelpContent.analyticsSesiones,
                      ),
                      KpiCardWithDelta(
                        title: 'Ritmo Medio',
                        value: avgPace,
                        subtitle: '/km',
                        icon: Icons.speed,
                        primaryColor: Colors.purple,
                        isInverted: true,
                        helpText: AppHelpContent.analyticsRitmo,
                      ),
                      KpiCardWithDelta(
                        title: 'Tiempo Total',
                        value: controller.formattedTotalDuration,
                        subtitle: 'En periodo',
                        icon: Icons.timer,
                        primaryColor: Colors.teal,
                        helpText: AppHelpContent.analyticsTiempoTotal, 
                      ),
                    ],
                  ),
                  const SizedBox(height: 40),
    
                  // 3. TENDENCIAS (Trends)
                  _buildBestPerformancesSection(data),
                  const SizedBox(height: 32),
                  _buildWeeklyProgressSection(data),
                  const SizedBox(height: 32),
                  _buildPaceEvolutionSection(data),
                  const SizedBox(height: 40),
    
                  // 4. DISTRIBUCIÓN (Distribution)
                  _buildTrainingBalanceSection(data),
                  const SizedBox(height: 32),
                  _buildConsistencySection(data),
                  const SizedBox(height: 32),
                  _buildNextMilestoneSection(data),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // --- TRENDS BUILDERS ---

  Widget _buildBestPerformancesSection(List<Entrenamiento> data) {
    final best400m = _findBestPaceForDistance(data, 400);
    final best1km = _findBestPaceForDistance(data, 1000);
    final best5km = _findBestPaceForDistance(data, 5000);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Mejores Marcas',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black87, letterSpacing: -0.5),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(child: _buildBestMarkCard('400m', best400m, Icons.bolt, Colors.amber)),
            const SizedBox(width: 12),
            Expanded(child: _buildBestMarkCard('1km', best1km, Icons.speed, Colors.blue)),
            const SizedBox(width: 12),
            Expanded(child: _buildBestMarkCard('5km', best5km, Icons.emoji_events, Colors.purple)),
          ],
        ),
      ],
    );
  }

  Widget _buildBestMarkCard(String distance, String? pace, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [Colors.white, color.withOpacity(0.05)], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: color.withOpacity(0.3), width: 2),
        boxShadow: [
          BoxShadow(color: color.withOpacity(0.2), blurRadius: 20, offset: const Offset(0, 10), spreadRadius: -5),
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 15, offset: const Offset(0, 5)),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [color.withOpacity(0.8), color]),
              shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: color.withOpacity(0.5), blurRadius: 12, offset: const Offset(0, 6))],
            ),
            child: Icon(icon, color: Colors.white, size: 28),
          ),
          const SizedBox(height: 16),
          Text(distance, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey.shade600, letterSpacing: 0.5)),
          const SizedBox(height: 8),
          Text(pace ?? '-', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color, letterSpacing: -0.5)),
        ],
      ),
    );
  }

  Widget _buildWeeklyProgressSection(List<Entrenamiento> data) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Volumen Semanal',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black87, letterSpacing: -0.5),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.white, Colors.blue.shade50.withOpacity(0.3)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.grey.shade200),
            boxShadow: [
              BoxShadow(color: Colors.blue.withOpacity(0.1), blurRadius: 20, offset: const Offset(0, 10), spreadRadius: -5),
              BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 15, offset: const Offset(0, 5)),
            ],
          ),
          child: SizedBox(height: 200, child: _WeeklyVolumeChart(workouts: data)),
        ),
      ],
    );
  }

  Widget _buildPaceEvolutionSection(List<Entrenamiento> data) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Evolución de Ritmo',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black87, letterSpacing: -0.5),
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
              BoxShadow(color: Tema.brandPurple.withOpacity(0.1), blurRadius: 20, offset: const Offset(0, 10), spreadRadius: -5),
              BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 15, offset: const Offset(0, 5)),
            ],
          ),
          child: SizedBox(height: 200, child: _PaceEvolutionChart(workouts: data)),
        ),
      ],
    );
  }

  String? _findBestPaceForDistance(List<Entrenamiento> data, int targetDistance) {
    double? bestPace;
    for (var workout in data) {
      for (var serie in workout.series) {
        if ((serie.distanciaM - targetDistance).abs() <= targetDistance * 0.05) {
          final pace = serie.ritmoSecPorKm().toDouble();
          if (pace > 0 && (bestPace == null || pace < bestPace)) {
            bestPace = pace;
          }
        }
      }
    }
    if (bestPace == null) return null;
    final m = bestPace ~/ 60;
    final s = (bestPace % 60).toInt();
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  // --- DISTRIBUTION BUILDERS ---

  Widget _buildTrainingBalanceSection(List<Entrenamiento> data) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Balance de Entrenamiento',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black87, letterSpacing: -0.5),
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
              BoxShadow(color: Tema.brandPurple.withOpacity(0.1), blurRadius: 20, offset: const Offset(0, 10), spreadRadius: -5),
              BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 15, offset: const Offset(0, 5)),
            ],
          ),
          child: _TagDistributionContent(workouts: data),
        ),
      ],
    );
  }

  Widget _buildConsistencySection(List<Entrenamiento> data) {
    final score = _calculateConsistencyScore(data);
    final color = _getConsistencyColor(score);
    final label = _getConsistencyLabel(score);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Consistencia',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black87, letterSpacing: -0.5),
        ),
        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [Colors.white, color.withOpacity(0.05)], begin: Alignment.topLeft, end: Alignment.bottomRight),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.grey.shade200),
            boxShadow: [BoxShadow(color: color.withOpacity(0.1), blurRadius: 20, offset: const Offset(0, 10), spreadRadius: -5)],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 180, height: 180,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(width: 140, height: 140, decoration: BoxDecoration(shape: BoxShape.circle, boxShadow: [BoxShadow(color: color.withOpacity(0.2), blurRadius: 30, spreadRadius: 5)])),
                    SizedBox(width: 160, height: 160, child: CircularProgressIndicator(value: 1.0, strokeWidth: 14, strokeCap: StrokeCap.round, valueColor: AlwaysStoppedAnimation<Color>(Colors.grey.shade100))),
                    SizedBox(width: 160, height: 160, child: CircularProgressIndicator(value: score / 100, strokeWidth: 14, strokeCap: StrokeCap.round, valueColor: AlwaysStoppedAnimation<Color>(color))),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('${score.toInt()}', style: TextStyle(fontSize: 56, fontWeight: FontWeight.w900, color: color, letterSpacing: -2, height: 1.0)),
                        Text('PUNTOS', style: TextStyle(fontSize: 10, color: Colors.grey.shade500, fontWeight: FontWeight.w800, letterSpacing: 2)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: color.withOpacity(0.3))),
                child: Text(label.toUpperCase(), style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 1.0)),
              ),
              const SizedBox(height: 16),
              Text(_getConsistencyMessage(score), textAlign: TextAlign.center, style: TextStyle(fontSize: 16, color: Colors.grey.shade700, fontWeight: FontWeight.w500, height: 1.4)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildNextMilestoneSection(List<Entrenamiento> data) {
    final totalKm = data.fold<double>(0, (sum, e) => sum + (e.distanciaTotalM() / 1000));
    final nextMilestone = ((totalKm ~/ 50) + 1) * 50;
    final remaining = nextMilestone - totalKm;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Próximo Hito',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black87, letterSpacing: -0.5),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [Colors.white, Colors.amber.shade50.withOpacity(0.3)], begin: Alignment.topLeft, end: Alignment.bottomRight),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.grey.shade200),
            boxShadow: [
              BoxShadow(color: Colors.amber.withOpacity(0.1), blurRadius: 20, offset: const Offset(0, 10), spreadRadius: -5),
              BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 15, offset: const Offset(0, 5)),
            ],
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [Colors.amber.shade400, Colors.amber.shade600]),
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: Colors.amber.withOpacity(0.5), blurRadius: 12, offset: const Offset(0, 6))],
                ),
                child: const Icon(Icons.emoji_events, color: Colors.white, size: 40),
              ),
              const SizedBox(height: 20),
              Text('${remaining.toStringAsFixed(1)} km', style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: Colors.amber, letterSpacing: -1)),
              const SizedBox(height: 8),
              Text('para alcanzar $nextMilestone km', style: TextStyle(fontSize: 16, color: Colors.grey.shade700, fontWeight: FontWeight.w600)),
              const SizedBox(height: 20),
              LinearProgressIndicator(value: totalKm / nextMilestone, backgroundColor: Colors.grey.shade200, valueColor: const AlwaysStoppedAnimation<Color>(Colors.amber), minHeight: 8, borderRadius: BorderRadius.circular(4)),
            ],
          ),
        ),
      ],
    );
  }

  double _calculateConsistencyScore(List<Entrenamiento> data) {
    if (data.isEmpty) return 0;
    final days = DateTime.now().difference(data.last.fecha).inDays;
    if (days == 0) return 100;
    final frequency = data.length / (days / 7);
    final score = (frequency / 4 * 100).clamp(0, 100);
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

// --- SHARED CHART WIDGETS ---

class _WeeklyVolumeChart extends StatelessWidget {
  final List<Entrenamiento> workouts;
  const _WeeklyVolumeChart({required this.workouts});

  @override
  Widget build(BuildContext context) {
    final sorted = List<Entrenamiento>.from(workouts)..sort((a, b) => a.fecha.compareTo(b.fecha));
    final displayData = sorted.length > 12 ? sorted.sublist(sorted.length - 12) : sorted;
    final barGroups = displayData.asMap().entries.map((e) {
      final km = e.value.distanciaTotalM() / 1000.0;
      return BarChartGroupData(x: e.key, barRods: [BarChartRodData(toY: km, gradient: LinearGradient(colors: [Colors.blue.shade400, Colors.blue.shade600], begin: Alignment.bottomCenter, end: Alignment.topCenter), width: 20, borderRadius: const BorderRadius.vertical(top: Radius.circular(8)))]);
    }).toList();

    return BarChart(BarChartData(alignment: BarChartAlignment.spaceAround, barTouchData: BarTouchData(touchTooltipData: BarTouchTooltipData(getTooltipColor: (_) => Colors.blueGrey.shade900, tooltipBorderRadius: BorderRadius.circular(8), tooltipPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), getTooltipItem: (group, groupIndex, rod, rodIndex) {
      final workout = displayData[groupIndex];
      final date = "${workout.fecha.day}/${workout.fecha.month}";
      return BarTooltipItem("$date\n", const TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold), children: [TextSpan(text: "${rod.toY.toStringAsFixed(1)} km", style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold))]);
    })), gridData: FlGridData(show: true, drawVerticalLine: false, getDrawingHorizontalLine: (value) => FlLine(color: Colors.grey.shade200, strokeWidth: 1)), titlesData: const FlTitlesData(show: false), borderData: FlBorderData(show: false), barGroups: barGroups));
  }
}

class _PaceEvolutionChart extends StatelessWidget {
  final List<Entrenamiento> workouts;
  const _PaceEvolutionChart({required this.workouts});

  @override
  Widget build(BuildContext context) {
    final sorted = List<Entrenamiento>.from(workouts)..sort((a, b) => a.fecha.compareTo(b.fecha));
    final displayData = sorted.length > 20 ? sorted.sublist(sorted.length - 20) : sorted;
    final spots = displayData.asMap().entries.map((e) {
      double pace = 0;
      try { pace = e.value.ritmoMedioSecPorKm().toDouble(); } catch (_) {}
      return FlSpot(e.key.toDouble(), pace);
    }).toList();
    if (spots.isEmpty) return const Center(child: Text('Sin datos'));
    final maxY = spots.map((e) => e.y).reduce((a, b) => a > b ? a : b);
    final minY = spots.map((e) => e.y).reduce((a, b) => a < b ? a : b);
    final targetMinY = (minY * 0.95).floorToDouble();

    return LineChart(LineChartData(lineTouchData: LineTouchData(touchTooltipData: LineTouchTooltipData(getTooltipColor: (_) => Colors.blueGrey.shade900, tooltipBorderRadius: BorderRadius.circular(8), tooltipPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), getTooltipItems: (touchedSpots) {
      return touchedSpots.map((spot) {
        final workout = displayData[spot.x.toInt()];
        final date = "${workout.fecha.day}/${workout.fecha.month}";
        final totalSeconds = spot.y.toInt();
        final m = totalSeconds ~/ 60;
        final s = (totalSeconds % 60).toString().padLeft(2, '0');
        return LineTooltipItem("$date\n", const TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold), children: [TextSpan(text: "$m:$s /km", style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold))]);
      }).toList();
    })), gridData: FlGridData(show: true, drawVerticalLine: false, getDrawingHorizontalLine: (value) => FlLine(color: Colors.grey.shade200, strokeWidth: 1)), titlesData: const FlTitlesData(show: false), borderData: FlBorderData(show: false), minY: targetMinY > 0 ? targetMinY : 0, lineBarsData: [LineChartBarData(spots: spots, isCurved: true, curveSmoothness: 0.4, gradient: LinearGradient(colors: [Tema.brandPurple, Colors.purple.shade300]), barWidth: 4, isStrokeCapRound: true, dotData: const FlDotData(show: false), belowBarData: BarAreaData(show: true, gradient: LinearGradient(colors: [Tema.brandPurple.withOpacity(0.3), Tema.brandPurple.withOpacity(0.0)], begin: Alignment.topCenter, end: Alignment.bottomCenter))) ]));
  }
}

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
      if (e.tags != null && e.tags!.isNotEmpty) { for (var tag in e.tags!) { distribution[tag] = (distribution[tag] ?? 0) + km; } } else { distribution['Sin etiqueta'] = (distribution['Sin etiqueta'] ?? 0) + km; }
    }
    if (distribution.isEmpty) return const SizedBox.shrink();
    final sortedEntries = distribution.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final top3 = sortedEntries.take(3).toList();
    return Column(children: [SizedBox(height: 220, child: Row(children: [Expanded(flex: 3, child: Stack(alignment: Alignment.center, children: [PieChart(PieChartData(pieTouchData: PieTouchData(touchCallback: (FlTouchEvent event, pieTouchResponse) { setState(() { if (!event.isInterestedForInteractions || pieTouchResponse == null || pieTouchResponse.touchedSection == null) { touchedIndex = -1; return; } touchedIndex = pieTouchResponse.touchedSection!.touchedSectionIndex; }); }), sections: sortedEntries.asMap().entries.map((e) { final index = e.key; final entry = e.value; final isTouched = index == touchedIndex; final color = _getTagColor(index); final fontSize = isTouched ? 16.0 : 12.0; final radius = isTouched ? 60.0 : 50.0; return PieChartSectionData(color: color, value: entry.value, title: isTouched ? '${entry.value.toStringAsFixed(0)}km' : '', radius: radius, titleStyle: TextStyle(fontSize: fontSize, fontWeight: FontWeight.bold, color: Colors.white, shadows: const [Shadow(color: Colors.black26, blurRadius: 4)])); }).toList(), centerSpaceRadius: 55, sectionsSpace: 3, borderData: FlBorderData(show: false))), Column(mainAxisSize: MainAxisSize.min, children: [Text(totalKm >= 100 ? totalKm.toStringAsFixed(0) : totalKm.toStringAsFixed(1), style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: Tema.brandPurple, letterSpacing: -1, height: 1.0)), Text('KM TOTALES', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: Colors.grey.shade500, letterSpacing: 1.2))])])), const SizedBox(width: 16), Expanded(flex: 2, child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: sortedEntries.take(5).toList().asMap().entries.map((e) { final index = e.key; final entry = e.value; final isTouched = index == touchedIndex; final color = _getTagColor(index); final percent = (entry.value / totalKm * 100).toInt(); return AnimatedContainer(duration: const Duration(milliseconds: 200), padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8), decoration: BoxDecoration(color: isTouched ? color.withOpacity(0.1) : Colors.transparent, borderRadius: BorderRadius.circular(8)), child: Row(children: [Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle, boxShadow: [BoxShadow(color: color.withOpacity(0.3), blurRadius: 4, spreadRadius: 1)])), const SizedBox(width: 8), Expanded(child: Text(entry.key, style: TextStyle(fontSize: 13, fontWeight: isTouched ? FontWeight.bold : FontWeight.w600, color: isTouched ? color : Colors.black87), overflow: TextOverflow.ellipsis)), Text('$percent%', style: TextStyle(fontSize: 12, color: isTouched ? color : Colors.grey.shade600, fontWeight: isTouched ? FontWeight.w800 : FontWeight.w500))])); }).toList()))])), const SizedBox(height: 24), Wrap(spacing: 12, runSpacing: 12, alignment: WrapAlignment.center, children: top3.asMap().entries.map((e) { final index = e.key; final entry = e.value; final color = _getTagColor(index); final percent = (entry.value / totalKm * 100).toInt(); return Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: color.withOpacity(0.15), blurRadius: 10, offset: const Offset(0, 4))], border: Border.all(color: color.withOpacity(0.2))), child: IntrinsicWidth(child: Row(children: [Icon(Icons.stars_rounded, color: color, size: 18), const SizedBox(width: 6), Text(entry.key, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black87)), const SizedBox(width: 6), Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(6)), child: Text('$percent%', style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w900)))]))); }).toList())]);
  }

  Color _getTagColor(int index) {
    final colors = [Tema.brandPurple, const Color(0xFF2196F3), const Color(0xFF4CAF50), const Color(0xFFFF9800), const Color(0xFFE91E63), const Color(0xFF00BCD4)];
    return colors[index % colors.length];
  }
}
