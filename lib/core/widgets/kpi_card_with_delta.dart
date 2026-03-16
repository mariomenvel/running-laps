import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:running_laps/core/widgets/info_tooltip.dart';

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
  // compact: reduces vertical padding by ~19% (16 → 13 px)
  final bool compact;
  // coloredBackground: use gradient background with primaryColor instead of white card
  final bool coloredBackground;

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
    this.compact = false,
    this.coloredBackground = false,
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

        final Color titleColor = coloredBackground
            ? Colors.white.withOpacity(0.85)
            : Theme.of(context).colorScheme.onSurface;
        final Color valueColor = coloredBackground
            ? Colors.white
            : Theme.of(context).colorScheme.onSurface.withOpacity(0.85);
        final Color unitColor = coloredBackground
            ? Colors.white.withOpacity(0.75)
            : Theme.of(context).colorScheme.onSurface.withOpacity(0.5);

        return GestureDetector(
          onTap: onTap,
          child: Container(
            decoration: coloredBackground
                ? BoxDecoration(
                    gradient: LinearGradient(
                      colors: [primaryColor, gradientColor ?? primaryColor.withOpacity(0.7)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: primaryColor.withOpacity(0.35),
                        blurRadius: 12,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  )
                : BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.transparent
                            : const Color(0x14000000),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: Stack(
                children: [
                  // Glow circle decoration (colored mode only)
                  if (coloredBackground)
                    Positioned(
                      top: -20,
                      right: -20,
                      child: Container(
                        width: 80,
                        height: 80,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Color(0x1AFFFFFF),
                        ),
                      ),
                    ),

                  // Content
                  Padding(
                    padding: compact
                        ? const EdgeInsets.symmetric(horizontal: 16, vertical: 13)
                        : const EdgeInsets.all(16.0),
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
                                  color: coloredBackground
                                      ? Colors.white.withOpacity(0.2)
                                      : primaryColor.withOpacity(0.8),
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: coloredBackground
                                      ? null
                                      : [
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
                                  color: titleColor,
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
                                    color: valueColor,
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
                                      color: unitColor,
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
