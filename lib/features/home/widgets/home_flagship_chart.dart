import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:running_laps/config/app_theme.dart';
import 'package:running_laps/core/theme/app_colors.dart';
import 'package:running_laps/features/training/data/entrenamiento.dart';
import 'dart:math' as math;

enum ChartFlagshipRange {
  oneWeek,
  oneMonth,
  sixMonths,
  oneYear,
  allTime,
}

enum ChartFlagshipMetric {
  distance,
  pace,
}

class HomeFlagshipChart extends StatefulWidget {
  final List<Entrenamiento> workouts;

  const HomeFlagshipChart({super.key, required this.workouts});

  @override
  State<HomeFlagshipChart> createState() => _HomeFlagshipChartState();
}

class _HomeFlagshipChartState extends State<HomeFlagshipChart> {
  ChartFlagshipRange _selectedRange = ChartFlagshipRange.oneWeek;
  ChartFlagshipMetric _selectedMetric = ChartFlagshipMetric.distance;
  int? _touchedIndex;

  // Cache processed data to avoid recalculation on every build if not needed
  // But for now, we'll calculate on the fly for simplicity as data size isn't huge

  @override
  Widget build(BuildContext context) {
    if (widget.workouts.isEmpty) {
      return const SizedBox.shrink(); 
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.transparent
                : Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          const SizedBox(height: 24),
          _buildFilters(),
          const SizedBox(height: 32),
          SizedBox(
            height: 220,
            child: _buildChart(),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Rendimiento",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _selectedMetric == ChartFlagshipMetric.distance
                  ? "Distancia acumulada"
                  : "Ritmo medio",
              style: TextStyle(
                fontSize: 14,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        _buildMetricToggle(),
      ],
    );
  }

  Widget _buildMetricToggle() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.06),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          _buildToggleBtn(Icons.directions_run, ChartFlagshipMetric.distance),
          const SizedBox(width: 4),
          _buildToggleBtn(Icons.speed, ChartFlagshipMetric.pace),
        ],
      ),
    );
  }

  Widget _buildToggleBtn(IconData icon, ChartFlagshipMetric metric) {
    final isSelected = _selectedMetric == metric;
    return GestureDetector(
      onTap: () => setState(() => _selectedMetric = metric),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isSelected ? Theme.of(context).colorScheme.surface : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.transparent
                        : Colors.black.withOpacity(0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  )
                ]
              : null,
        ),
        child: Icon(
          icon,
          size: 20,
          color: isSelected ? (Theme.of(context).brightness == Brightness.dark ? AppColors.brandLight : AppColors.brand) : Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
        ),
      ),
    );
  }

  Widget _buildFilters() {
    final filters = {
      ChartFlagshipRange.oneWeek: "1S",
      ChartFlagshipRange.oneMonth: "1M",
      ChartFlagshipRange.sixMonths: "6M",
      ChartFlagshipRange.oneYear: "1A",
      ChartFlagshipRange.allTime: "Todo",
    };

    return SizedBox(
      height: 32,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: filters.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final range = filters.keys.elementAt(index);
          final label = filters.values.elementAt(index);
          final isSelected = _selectedRange == range;
          
          return GestureDetector(
            onTap: () => setState(() {
              _selectedRange = range;
              _touchedIndex = null;
            }),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: isSelected ? _metricColor : Colors.transparent,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected ? _metricColor : Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
                ),
              ),
              child: Text(
                label,
                style: TextStyle(
                  color: isSelected ? Colors.white : Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // --- CHART LOGIC ---

  Widget _buildChart() {
    final groups = _processData();

    if (groups.isEmpty) {
      return Center(child: Text("Sin datos para este periodo", style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4))));
    }

    final maxY = groups.map((e) => e.displayValue).reduce(math.max);
    // Add 20% breathing room to top
    final targetMaxY = maxY * 1.2;

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: targetMaxY == 0 ? 1 : targetMaxY,
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (group) => Theme.of(context).colorScheme.surface,
            tooltipPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              final data = groups[groupIndex];
              return BarTooltipItem(
                '${data.label}\n',
                TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
                children: [
                  TextSpan(
                    text: _formatValue(data.value),
                    style: TextStyle(
                      color: Theme.of(context).brightness == Brightness.dark ? AppColors.brandLight : AppColors.brand,
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                ],
              );
            },
          ),
          touchCallback: (FlTouchEvent event, barTouchResponse) {
            setState(() {
              if (!event.isInterestedForInteractions ||
                  barTouchResponse == null ||
                  barTouchResponse.spot == null) {
                _touchedIndex = -1;
                return;
              }
              _touchedIndex = barTouchResponse.spot!.touchedBarGroupIndex;
            });
          },
        ),
        titlesData: FlTitlesData(
          show: true,
          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index < 0 || index >= groups.length) return const SizedBox.shrink();
                
                // Show label logic: optimize for density
                // If many items, show only some
                if (groups.length > 10 && index % 2 != 0) return const SizedBox.shrink();
                if (groups.length > 20 && index % 4 != 0) return const SizedBox.shrink();
                
                // Only show label if value > 0 OR if it's sparse? 
                // Let's keep existing logic but maybe lighter color
                
                return Padding(
                  padding: const EdgeInsets.only(top: 12.0),
                  child: Text(
                    groups[index].shortLabel,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
                      fontSize: 10,
                      fontWeight: FontWeight.w600,

                    ),
                  ),
                );
              },
              reservedSize: 32,
            ),
          ),
          leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: false),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: targetMaxY / 4 == 0 ? 1.0 : targetMaxY / 4, 
          getDrawingHorizontalLine: (value) => FlLine(
             color: Theme.of(context).colorScheme.onSurface.withOpacity(0.04),
             strokeWidth: 1,
             dashArray: [10, 10],
          ),
        ),
        barGroups: groups.asMap().entries.map((entry) {
          final index = entry.key;
          final data = entry.value;
          final isTouched = index == _touchedIndex;

          return BarChartGroupData(
            x: index,
            barRods: [
              BarChartRodData(
                toY: data.displayValue,
                gradient: _getGradient(isTouched),
                width: groups.length > 10 ? 8 : 12, // Slightly thinner for elegance
                borderRadius: BorderRadius.circular(50), // Maximum rounding
                backDrawRodData: BackgroundBarChartRodData(
                  show: false, // Hidden as requested ("invisible empty days")
                  toY: targetMaxY,
                  color: Colors.transparent,
                ),
              ),
            ],
          );
        }).toList(),
      ),
      duration: const Duration(milliseconds: 300), // Fixed: swapAnimationDuration -> duration
      curve: Curves.easeInOutCubic, // Fixed: swapAnimationCurve -> curve
    );
  }
  
  Color get _metricColor => _selectedMetric == ChartFlagshipMetric.distance
      ? AppColors.brand
      : const Color(0xFF2196F3);

  LinearGradient _getGradient(bool isTouched) {
    if (_selectedMetric == ChartFlagshipMetric.distance) {
       return LinearGradient(
        colors: isTouched 
            ? [AppColors.brand, AppColors.brand] 
            : [AppColors.brand, const Color(0xFFB39DDB)], // Purple scale
        begin: Alignment.bottomCenter,
        end: Alignment.topCenter,
      );
    } else {
      return LinearGradient(
        colors: isTouched 
            ? [const Color(0xFF2196F3), const Color(0xFF2196F3)] 
            : [const Color(0xFF2196F3), const Color(0xFF64B5F6)], // Blue scale
        begin: Alignment.bottomCenter,
        end: Alignment.topCenter,
      );
    }
  }

  String _formatValue(double value) {
    if (_selectedMetric == ChartFlagshipMetric.distance) {
      return '${value.toStringAsFixed(1)} km';
    } else {
      // Pace logic: value is seconds/km or speed?
      // For chart height we might use inverted or just seconds.
      // Let's assume we store seconds per km for simple visualization logic in bars
      // But displaying it needs formatted mm:ss
      final int seconds = value.toInt();
      final int m = seconds ~/ 60;
      final int s = seconds % 60;
      return '$m:${s.toString().padLeft(2, '0')} /km';
    }
  }

  // --- DATA PROCESSING ---
  
  List<_ChartGroup> _processData() {
    if (widget.workouts.isEmpty) return [];
    
    final now = DateTime.now();
    DateTime cutoff;
    List<_ChartGroup> rawGroups = [];
    
    switch (_selectedRange) {
      case ChartFlagshipRange.oneWeek:
        cutoff = now.subtract(const Duration(days: 7));
        rawGroups = _groupByDay(cutoff, now);
        break;
      case ChartFlagshipRange.oneMonth:
        cutoff = now.subtract(const Duration(days: 30));
        rawGroups = _groupByDay(cutoff, now);
        break;
      case ChartFlagshipRange.sixMonths:
        cutoff = now.subtract(const Duration(days: 180));
        rawGroups = _groupByWeek(cutoff, now);
        break;
      case ChartFlagshipRange.oneYear:
        cutoff = now.subtract(const Duration(days: 365));
        rawGroups = _groupByMonth(cutoff, now);
        break;
      case ChartFlagshipRange.allTime:
        final earliest = widget.workouts.map((e) => e.fecha).reduce((a, b) => a.isBefore(b) ? a : b);
        cutoff = earliest.subtract(const Duration(days: 1)); // Buffer
        rawGroups = _groupByMonth(cutoff, now);
        break;
    }

    // Post-process to invert pace height if needed
    if (_selectedMetric == ChartFlagshipMetric.pace) {
      // Find the fastest and slowest to normalize? 
      // Actually, speed logic (1/pace) is better as it handles 0 and is predictable.
      return rawGroups.map((g) {
        double height = 0;
        if (g.value > 0) {
          // Invert: higher bar for lower seconds/km
          // 10000 / 300s (5:00) = 33.3
          // 10000 / 240s (4:00) = 41.6
          height = 10000 / g.value;
        }
        return g.copyWith(displayValue: height);
      }).toList();
    } else {
      // Distance is direct
      return rawGroups.map((g) => g.copyWith(displayValue: g.value)).toList();
    }
  }

  // 1. Group by Day
  List<_ChartGroup> _groupByDay(DateTime start, DateTime end) {
    final Map<int, List<Entrenamiento>> grouped = {};
    
    // Initialize all days
    int days = end.difference(start).inDays;
    for (int i = 0; i <= days; i++) {
        final date = start.add(Duration(days: i));
        // Use simpler key: YYYYMMDD
        final key = date.year * 10000 + date.month * 100 + date.day;
        grouped[key] = [];
    }

    for (var w in widget.workouts) {
      if (w.fecha.isAfter(start) && w.fecha.isBefore(end.add(const Duration(days: 1)))) {
        final key = w.fecha.year * 10000 + w.fecha.month * 100 + w.fecha.day;
        if (grouped.containsKey(key)) {
          grouped[key]!.add(w);
        }
      }
    }

    return grouped.entries.map((entry) {
        final key = entry.key;
        final day = key % 100;
        final month = (key ~/ 100) % 100;
        final workouts = entry.value;
        double value = _calculateMetricValue(workouts);
        
        return _ChartGroup(
          value: value,
          label: '$day/${month.toString().padLeft(2, '0')}',
          shortLabel: day.toString(),
          sortKey: key,
        );
    }).toList()..sort((a, b) => a.sortKey.compareTo(b.sortKey));
  }

  // 2. Group by Week
  List<_ChartGroup> _groupByWeek(DateTime start, DateTime end) {
    // Week starts.. lets say Monday? 
    // Key: YYYYWW
    final Map<int, List<Entrenamiento>> grouped = {};
    
    for (var w in widget.workouts) {
      if (w.fecha.isAfter(start) && w.fecha.isBefore(end)) {
        // Simple week number
        int weekNum = _getWeekNumber(w.fecha);
        int key = w.fecha.year * 100 + weekNum;
        grouped.putIfAbsent(key, () => []).add(w);
      }
    }
    
    // Fill gaps? For 6M/1Y gap filling might be too sparse or too dense. 
    // Let's just show present weeks for now or better, iterate through weeks.
    // Iterating is safer for the carousel look.
    
    // Better strategy for "timeline": Generate weeks from start to end
    List<_ChartGroup> result = [];
    DateTime current = start;
    while(current.isBefore(end)) {
       int weekNum = _getWeekNumber(current);
       int key = current.year * 100 + weekNum;
       
       List<Entrenamiento> workouts = grouped[key] ?? [];
       double value = _calculateMetricValue(workouts);
       
        // Label: Start of week
        String label = 'Sem $weekNum';
        String shortLabel = 'S$weekNum';
        
        result.add(_ChartGroup(
          value: value,
          label: label,
          shortLabel: shortLabel, 
          sortKey: key,
        ));
       
       current = current.add(const Duration(days: 7));
    }
    return result;
  }
  
  // 3. Group by Month
  List<_ChartGroup> _groupByMonth(DateTime start, DateTime end) {
     final Map<int, List<Entrenamiento>> grouped = {};
     
     // Initialize keys from start to end
     DateTime current = DateTime(start.year, start.month);
     while (current.isBefore(end) || (current.month == end.month && current.year == end.year)) {
        int key = current.year * 100 + current.month;
        grouped[key] = [];
        current = DateTime(current.year, current.month + 1);
     }

     for (var w in widget.workouts) {
       if (w.fecha.isAfter(start)) {
          int key = w.fecha.year * 100 + w.fecha.month;
          if (grouped.containsKey(key)) {
             grouped[key]!.add(w);
          }
       }
     }
     
     return grouped.entries.map((e) {
        int year = e.key ~/ 100;
        int month = e.key % 100;
        List<String> months = ['', 'Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun', 'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic'];
        
        return _ChartGroup(
          value: _calculateMetricValue(e.value),
          label: '${months[month]} $year',
          shortLabel: months[month],
          sortKey: e.key,
        );
     }).toList()..sort((a,b) => a.sortKey.compareTo(b.sortKey));
  }
  
  
  int _getWeekNumber(DateTime date) {
    // Standard ISO-8601 week number calculation would be better but simple approximation:
    int dayOfYear = int.parse(DateFormat("D").format(date));
    return ((dayOfYear - date.weekday + 10) / 7).floor();
  }

  double _calculateMetricValue(List<Entrenamiento> workouts) {
    if (workouts.isEmpty) return 0;
    
    if (_selectedMetric == ChartFlagshipMetric.distance) {
      double totalMeters = workouts.fold(0, (sum, w) => sum + w.distanciaTotalM());
      return totalMeters / 1000.0;
    } else {
      // Pace Calculation
      // Average Pace (min/km) weighted by distance? OR simple average of paces?
      // Accurate: Total Time / Total Distance
      double totalMeters = 0;
      double totalSeconds = 0;
      
      for (var w in workouts) {
        double wDist = w.distanciaTotalM().toDouble(); // Fixed: cast to double
        if (wDist > 0) {
            totalMeters += wDist;
            totalSeconds += w.tiempoTotalSec();
        }
      }
      
      if (totalMeters == 0) return 0;
      
      double secPerKm = totalSeconds / (totalMeters / 1000.0);
      return secPerKm; // Return raw seconds/km for the chart value
    }
  }
}

class _ChartGroup {
  final double value; // Raw metric value
  final double displayValue; // Transformed value for chart height
  final String label;
  final String shortLabel;
  final int sortKey;

  _ChartGroup({
    required this.value,
    this.displayValue = 0,
    required this.label,
    required this.shortLabel,
    required this.sortKey,
  });

  _ChartGroup copyWith({
    double? value,
    double? displayValue,
    String? label,
    String? shortLabel,
    int? sortKey,
  }) {
    return _ChartGroup(
      value: value ?? this.value,
      displayValue: displayValue ?? this.displayValue,
      label: label ?? this.label,
      shortLabel: shortLabel ?? this.shortLabel,
      sortKey: sortKey ?? this.sortKey,
    );
  }
}

