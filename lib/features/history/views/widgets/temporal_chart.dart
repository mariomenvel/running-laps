import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:running_laps/core/theme/app_colors.dart';

/// Punto temporal genérico — eje X en segundos desde inicio
class TemporalPoint {
  final double tSec;   // tiempo en segundos
  final double value;  // valor (pace, bpm, etc.)

  const TemporalPoint({required this.tSec, required this.value});
}

/// Marcador vertical (línea + label) para indicar eventos
class TemporalMarker {
  final double tSec;
  final String label;

  const TemporalMarker({required this.tSec, required this.label});
}

class TemporalChart extends StatelessWidget {
  final List<TemporalPoint> points;
  final List<TemporalMarker> markers;
  final Color lineColor;
  final String unitLabel;          // "min/km", "bpm"
  final double height;
  final double? minY;
  final double? maxY;
  final bool invertYAxis;          // true para pace (menos = mejor arriba)
  final String Function(double)? formatY;

  const TemporalChart({
    super.key,
    required this.points,
    required this.lineColor,
    required this.unitLabel,
    this.markers = const [],
    this.height = 200,
    this.minY,
    this.maxY,
    this.invertYAxis = false,
    this.formatY,
  });

  String _formatTime(double sec) {
    final m = (sec ~/ 60).toInt();
    final s = (sec % 60).toInt();
    if (m == 0) return '${s}s';
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  String _defaultFormatY(double value) {
    return value.toStringAsFixed(1);
  }

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) {
      return SizedBox(
        height: height,
        child: Center(
          child: Text(
            'Sin datos',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary(context),
            ),
          ),
        ),
      );
    }

    final spots = points.map((p) => FlSpot(p.tSec, p.value)).toList();
    final tMax = points.last.tSec;
    final yValues = points.map((p) => p.value).toList();
    final computedMinY = minY ?? (yValues.reduce((a, b) => a < b ? a : b) * 0.95);
    final computedMaxY = maxY ?? (yValues.reduce((a, b) => a > b ? a : b) * 1.05);

    return SizedBox(
      height: height,
      child: LineChart(
        LineChartData(
          minX: 0,
          maxX: tMax,
          minY: invertYAxis ? -computedMaxY : computedMinY,
          maxY: invertYAxis ? -computedMinY : computedMaxY,
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: (computedMaxY - computedMinY) / 4,
            getDrawingHorizontalLine: (_) => FlLine(
              color: AppColors.borderOf(context).withValues(alpha: 0.2),
              strokeWidth: 1,
            ),
          ),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 42,
                getTitlesWidget: (value, _) {
                  final actual = invertYAxis ? -value : value;
                  return Text(
                    (formatY ?? _defaultFormatY)(actual),
                    style: TextStyle(
                      fontSize: 10,
                      color: AppColors.textSecondary(context),
                    ),
                  );
                },
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 22,
                interval: tMax / 4,
                getTitlesWidget: (value, _) => Text(
                  _formatTime(value),
                  style: TextStyle(
                    fontSize: 10,
                    color: AppColors.textSecondary(context),
                  ),
                ),
              ),
            ),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(show: false),
          extraLinesData: ExtraLinesData(
            verticalLines: markers.map((m) => VerticalLine(
              x: m.tSec,
              color: AppColors.textSecondary(context).withValues(alpha: 0.3),
              strokeWidth: 1,
              dashArray: [4, 4],
              label: VerticalLineLabel(
                show: true,
                alignment: Alignment.topCenter,
                padding: const EdgeInsets.only(bottom: 4),
                style: TextStyle(
                  fontSize: 9,
                  color: AppColors.textSecondary(context),
                ),
                labelResolver: (_) => m.label,
              ),
            )).toList(),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: invertYAxis
                  ? spots.map((s) => FlSpot(s.x, -s.y)).toList()
                  : spots,
              isCurved: true,
              curveSmoothness: 0.2,
              color: lineColor,
              barWidth: 2.5,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                color: lineColor.withValues(alpha: 0.1),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
