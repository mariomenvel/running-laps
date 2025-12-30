import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

/// Card KPI premium con valor principal, delta vs periodo anterior y sparkline
/// 
/// Diseño iOS-style con gradientes, sombras suaves y animaciones
class KpiCardWithDelta extends StatelessWidget {
  final String title;
  final String value;
  final String? subtitle;
  final double? deltaPercentage; // % de cambio (positivo = mejora)
  final List<double>? sparklineData; // Datos para mini sparkline
  final Color primaryColor;
  final Color? gradientColor;
  final IconData? icon;
  final bool isInverted; // true si valores bajos son mejor (ej: ritmo)
  final VoidCallback? onTap;

  const KpiCardWithDelta({
    super.key,
    required this.title,
    required this.value,
    this.subtitle,
    this.deltaPercentage,
    this.sparklineData,
    this.primaryColor = const Color(0xFF8E24AA),
    this.gradientColor,
    this.icon,
    this.isInverted = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveGradientColor = gradientColor ?? primaryColor.withOpacity(0.6);
    final screenWidth = MediaQuery.of(context).size.width;
    
    // Tamaños responsivos basados en el ancho de pantalla
    // Escalamos entre un mínimo razonable y un máximo para pantallas grandes
    final double responsiveValueSize = (32 * (screenWidth / 375)).clamp(28.0, 42.0);
    final double responsiveTitleSize = (14 * (screenWidth / 375)).clamp(12.0, 16.0);
    final double responsiveSubtitleSize = (12.5 * (screenWidth / 375)).clamp(11.0, 15.0);
    
    // Determinar si es mejora (positivo en deltas normales, negativo si inverted)
    final bool? isImprovement = deltaPercentage == null
        ? null
        : isInverted
            ? deltaPercentage! < 0
            : deltaPercentage! > 0;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              primaryColor.withOpacity(0.1),
              effectiveGradientColor.withOpacity(0.05),
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: primaryColor.withOpacity(0.3),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: primaryColor.withOpacity(0.15),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: título + icono
            Row(
              children: [
                if (icon != null) ...[
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: primaryColor.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      icon,
                      size: 18,
                      color: primaryColor,
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      title,
                      style: TextStyle(
                        fontSize: responsiveTitleSize,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[700],
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            
            // Valor principal (grande, animado, responsive)
            TweenAnimationBuilder<double>(
              duration: const Duration(milliseconds: 600),
              tween: Tween(begin: 0.0, end: 1.0),
              curve: Curves.easeOutCubic,
              builder: (context, animValue, child) {
                return Opacity(
                  opacity: animValue,
                  child: Transform.translate(
                    offset: Offset(0, 10 * (1 - animValue)),
                    child: child,
                  ),
                );
              },
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  value,
                  style: TextStyle(
                    fontSize: responsiveValueSize,
                    fontWeight: FontWeight.bold,
                    color: primaryColor,
                    height: 1.0,
                  ),
                ),
              ),
            ),
            
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(
                subtitle!,
                style: TextStyle(
                  fontSize: responsiveSubtitleSize,
                  color: Colors.grey[600],
                ),
              ),
            ],
            
            if (deltaPercentage != null || (sparklineData != null && sparklineData!.isNotEmpty)) ...[
              const SizedBox(height: 8),
              
              // Delta y sparkline
              Row(
                children: [
                  if (deltaPercentage != null) ...[
                    _buildDeltaChip(isImprovement, deltaPercentage!),
                    const SizedBox(width: 12),
                  ],
                  
                  if (sparklineData != null && sparklineData!.isNotEmpty)
                    Expanded(child: _buildSparkline()),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Chip con delta porcentual
  Widget _buildDeltaChip(bool? isImprovement, double delta) {
    final Color chipColor = isImprovement == null
        ? Colors.grey
        : isImprovement
            ? Colors.green
            : Colors.red;

    final IconData deltaIcon = isImprovement == null
        ? Icons.remove
        : isImprovement
            ? Icons.trending_up
            : Icons.trending_down;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: chipColor.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: chipColor.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            deltaIcon,
            size: 16,
            color: chipColor,
          ),
          const SizedBox(width: 4),
          Text(
            '${delta.abs().toStringAsFixed(1)}%',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: chipColor,
            ),
          ),
        ],
      ),
    );
  }

  /// Mini sparkline (últimos datos)
  Widget _buildSparkline() {
    if (sparklineData == null || sparklineData!.isEmpty) {
      return const SizedBox.shrink();
    }

    return SizedBox(
      height: 30,
      child: LineChart(
        LineChartData(
          gridData: const FlGridData(show: false),
          titlesData: const FlTitlesData(show: false),
          borderData: FlBorderData(show: false),
          minX: 0,
          maxX: (sparklineData!.length - 1).toDouble(),
          minY: sparklineData!.reduce((a, b) => a < b ? a : b) * 0.9,
          maxY: sparklineData!.reduce((a, b) => a > b ? a : b) * 1.1,
          lineBarsData: [
            LineChartBarData(
              spots: sparklineData!
                  .asMap()
                  .entries
                  .map((e) => FlSpot(e.key.toDouble(), e.value))
                  .toList(),
              isCurved: true,
              color: primaryColor.withOpacity(0.6),
              barWidth: 2,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                color: primaryColor.withOpacity(0.1),
              ),
            ),
          ],
          lineTouchData: const LineTouchData(enabled: false),
        ),
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      ),
    );
  }
}
