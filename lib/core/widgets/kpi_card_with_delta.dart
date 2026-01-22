import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:running_laps/core/widgets/info_tooltip.dart';
import 'dart:ui';

/// Card KPI premium con estilo Glassmorphism inspirado en diseños modernos.
/// Versión optimizada para legibilidad y estética premium.
class KpiCardWithDelta extends StatelessWidget {
  final String title;
  final String value;
  final String? subtitle;
  final double? deltaPercentage;
  final List<double>? sparklineData;
  final Color primaryColor;
  final Color? gradientColor;
  final IconData? icon;
  final bool isInverted;
  final VoidCallback? onTap;
  final String? helpText;

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
    this.helpText,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double width = constraints.maxWidth;
        // Responsive scaling
        final double titleSize = (width * 0.08).clamp(12.0, 14.0);
        final double valueSize = (width * 0.18).clamp(24.0, 32.0);
        final double iconBoxSize = (width * 0.3).clamp(36.0, 44.0);

        return GestureDetector(
          onTap: onTap,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: primaryColor.withOpacity(0.12),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: Stack(
                children: [
                  // Glass background
                  BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.7),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.5),
                          width: 1.5,
                        ),
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            primaryColor.withOpacity(0.08),
                            Colors.white.withOpacity(0.4),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Background glow circle (decorative)
                  Positioned(
                    bottom: -30,
                    right: -30,
                    child: Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: primaryColor.withOpacity(0.05),
                      ),
                    ),
                  ),

                  // Content
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header: Icon Box + Sparkline/Trend
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            if (icon != null)
                              Container(
                                width: iconBoxSize,
                                height: iconBoxSize,
                                decoration: BoxDecoration(
                                  color: primaryColor.withOpacity(0.8),
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: [
                                    BoxShadow(
                                      color: primaryColor.withOpacity(0.3),
                                      blurRadius: 8,
                                      offset: const Offset(0, 4),
                                    )
                                  ],
                                ),
                                child: Icon(icon, color: Colors.white, size: iconBoxSize * 0.6),
                              ),
                            
                            // Trend or Sparkline
                            if (sparklineData != null && sparklineData!.isNotEmpty)
                              SizedBox(
                                width: width * 0.35,
                                height: 30,
                                child: _buildSparkline(),
                              )
                            else if (deltaPercentage != null)
                              _buildSimpleTrendIcon(),
                          ],
                        ),
                        
                        const Spacer(),

                        // Title
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                title,
                                style: TextStyle(
                                  color: Colors.blueGrey.shade700,
                                  fontSize: titleSize,
                                  fontWeight: FontWeight.w500,
                                  letterSpacing: -0.2,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (helpText != null)
                              Padding(
                                padding: const EdgeInsets.only(left: 4),
                                child: InfoTooltip(content: helpText!, iconSize: 14),
                              ),
                          ],
                        ),

                        const SizedBox(height: 4),

                        // Value + Unit
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: RichText(
                            text: TextSpan(
                              children: [
                                TextSpan(
                                  text: value.split(' ')[0], // Value
                                  style: TextStyle(
                                    fontSize: valueSize,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.black.withOpacity(0.75),
                                    letterSpacing: -0.3,
                                  ),
                                ),
                                if (value.contains(' ')) ...[ 
                                  const TextSpan(text: ' '),
                                  TextSpan(
                                    text: value.split(' ')[1], // Unit
                                    style: TextStyle(
                                      fontSize: valueSize * 0.5,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.blueGrey.shade400,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSimpleTrendIcon() {
    final isUp = deltaPercentage! > 0;
    final color = isInverted 
        ? (isUp ? Colors.red : Colors.green) 
        : (isUp ? Colors.green : Colors.red);
        
    return Icon(
      isUp ? Icons.trending_up_rounded : Icons.trending_down_rounded,
      color: color.withOpacity(0.8),
      size: 20,
    );
  }

  Widget _buildSparkline() {
    return LineChart(
      LineChartData(
        gridData: const FlGridData(show: false),
        titlesData: const FlTitlesData(show: false),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: sparklineData!
                .asMap()
                .entries
                .map((e) => FlSpot(e.key.toDouble(), e.value))
                .toList(),
            isCurved: true,
            color: primaryColor.withOpacity(0.8),
            barWidth: 2.5,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              color: primaryColor.withOpacity(0.1),
            ),
          ),
        ],
        lineTouchData: const LineTouchData(enabled: false),
      ),
    );
  }
}
