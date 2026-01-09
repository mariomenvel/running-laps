import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:running_laps/features/analytics/data/workout_pattern.dart';
import 'package:running_laps/features/analytics/widgets/pattern_carousel.dart';
import 'package:running_laps/features/analytics/views/pattern_comparison_view.dart';
import 'package:running_laps/config/app_theme.dart';

class WorkoutPatternCarouselView extends StatefulWidget {
  final List<WorkoutPattern> patterns;
  final int initialIndex;

  const WorkoutPatternCarouselView({
    super.key,
    required this.patterns,
    this.initialIndex = 0,
  });

  @override
  State<WorkoutPatternCarouselView> createState() =>
      _WorkoutPatternCarouselViewState();
}

class _WorkoutPatternCarouselViewState
    extends State<WorkoutPatternCarouselView> {
  late int _currentPatternIndex;

  @override
  void initState() {
    super.initState();
    _currentPatternIndex = widget.initialIndex;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      appBar: AppBar(
        title: const Text('Patrones de Entrenamientos'),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Tema.brandPurple),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          // Compare button
          if (widget.patterns[_currentPatternIndex].instances.length >= 2)
            IconButton(
              icon: const Icon(Icons.compare_arrows, color: Tema.brandPurple),
              onPressed: () => _showComparisonSelector(),
            ),
        ],
        titleTextStyle: const TextStyle(
          color: Colors.black,
          fontSize: 17,
          fontWeight: FontWeight.w600,
        ),
      ),
      body: PatternCarousel<WorkoutPattern>(
        items: widget.patterns,
        initialPage: widget.initialIndex,
        onPageChanged: (index) {
          setState(() => _currentPatternIndex = index);
        },
        itemBuilder: (context, pattern, index) {
          return _WorkoutPatternContent(pattern: pattern);
        },
      ),
    );
  }

  void _showComparisonSelector() {
    final pattern = widget.patterns[_currentPatternIndex];
    final instances = pattern.instances;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _ComparisonSelectorSheet(instances: instances),
    );
  }
}

class _ComparisonSelectorSheet extends StatefulWidget {
  final List<WorkoutInstance> instances;

  const _ComparisonSelectorSheet({required this.instances});

  @override
  State<_ComparisonSelectorSheet> createState() =>
      _ComparisonSelectorSheetState();
}

class _ComparisonSelectorSheetState extends State<_ComparisonSelectorSheet> {
  WorkoutInstance? _selectedA;
  WorkoutInstance? _selectedB;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Selecciona 2 entrenamientos para comparar',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Flexible(
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: widget.instances.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final instance = widget.instances[index];
                final isSelectedA = _selectedA == instance;
                final isSelectedB = _selectedB == instance;
                final isSelected = isSelectedA || isSelectedB;

                return ListTile(
                  tileColor: isSelected
                      ? Tema.brandPurple.withOpacity(0.1)
                      : Colors.grey.shade50,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: isSelected ? Tema.brandPurple : Colors.transparent,
                      width: 2,
                    ),
                  ),
                  leading: CircleAvatar(
                    backgroundColor:
                        isSelected ? Tema.brandPurple : Colors.grey.shade300,
                    child: Text(
                      isSelectedA ? 'A' : isSelectedB ? 'B' : '${index + 1}',
                      style: TextStyle(
                        color: isSelected ? Colors.white : Colors.black,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  title: Text(
                    "${instance.fecha.day}/${instance.fecha.month}/${instance.fecha.year}",
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    _formatPace(instance.averagePace.round()),
                  ),
                  onTap: () {
                    setState(() {
                      if (isSelected) {
                        // Deselect
                        if (isSelectedA) _selectedA = null;
                        if (isSelectedB) _selectedB = null;
                      } else {
                        // Select
                        if (_selectedA == null) {
                          _selectedA = instance;
                        } else if (_selectedB == null) {
                          _selectedB = instance;
                        } else {
                          // Replace A
                          _selectedA = instance;
                        }
                      }
                    });
                  },
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _selectedA != null && _selectedB != null
                  ? () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => PatternComparisonView(
                            instanceA: _selectedA!,
                            instanceB: _selectedB!,
                          ),
                        ),
                      );
                    }
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: Tema.brandPurple,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Comparar',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatPace(int secKm) {
    final m = secKm ~/ 60;
    final s = secKm % 60;
    return '$m:${s.toString().padLeft(2, '0')} /km';
  }
}

class _WorkoutPatternContent extends StatelessWidget {
  final WorkoutPattern pattern;

  const _WorkoutPatternContent({required this.pattern});

  @override
  Widget build(BuildContext context) {
    final sortedInstances = List<WorkoutInstance>.from(pattern.instances)
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
                  pattern.patternKey,
                  style: TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                    foreground: Paint()
                      ..shader = LinearGradient(
                        colors: [Tema.brandPurple, Colors.deepPurple.shade600],
                      ).createShader(const Rect.fromLTWH(0, 0, 200, 70)),
                    letterSpacing: -1,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                Text(
                  pattern.description,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
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
                  "Ritmo Medio",
                  pattern.averagePaceFormatted,
                  Icons.speed,
                  Colors.blue,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildKpiCard(
                  "Consistencia",
                  "${(pattern.averageConsistency * 100).toInt()}%",
                  Icons.track_changes,
                  Colors.green,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildKpiCard(
                  "Sesiones",
                  "${pattern.count}",
                  Icons.calendar_today,
                  Colors.orange,
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Stats Chart
          Container(
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Evolución del Rendimiento",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
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
          const Align(
            alignment: Alignment.centerLeft,
            child: Text(
              "Sesiones Realizadas",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: Colors.grey,
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
              return _buildHistoryItem(instance);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildKpiCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.white, color.withOpacity(0.05)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
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
            color: Colors.black.withOpacity(0.03),
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
              color: Colors.grey.shade600,
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

  Widget _buildHistoryItem(WorkoutInstance instance) {
    final paceSec = instance.averagePace.round();
    final m = paceSec ~/ 60;
    final s = (paceSec % 60).toInt();
    final pace = '$m:${s.toString().padLeft(2, '0')}';

    return Container(
      padding: const EdgeInsets.all(18),
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
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.purple.shade300, Colors.purple.shade500],
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.purple.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(Icons.fitness_center,
                    color: Colors.white, size: 16),
              ),
              const SizedBox(width: 12),
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
                    "Consistencia: ${(instance.consistency * 100).toInt()}%",
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
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

class _PerformanceChart extends StatelessWidget {
  final List<WorkoutInstance> instances;
  const _PerformanceChart({required this.instances});

  @override
  Widget build(BuildContext context) {
    final spots = instances.asMap().entries.map((e) {
      return FlSpot(e.key.toDouble(), e.value.averagePace.toDouble());
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
          getDrawingHorizontalLine: (_) => FlLine(color: Colors.grey.shade100),
        ),
        titlesData: FlTitlesData(show: false),
        borderData: FlBorderData(show: false),
        minY: targetMinY,
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: Colors.blueAccent,
            barWidth: 3,
            dotData: const FlDotData(show: true),
            belowBarData: BarAreaData(
              show: true,
              color: Colors.blueAccent.withOpacity(0.1),
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

