import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:ui' as ui;
import 'package:running_laps/app/tema.dart';

// Enum definitions if they aren't available globally
enum HomeMetric { distancia, tiempoTotal, ritmoMedio, calorias }
enum TimeRange { oneWeek, oneMonth, sixMonths, oneYear, max }

class DailyMetric {
  final DateTime date;
  final double value; // Distancia (km) o Tiempo (min) o Ritmo (s/km)

  DailyMetric(this.date, this.value);
}

class LegacyBarChart extends StatefulWidget {
  final List<DailyMetric> data;
  final HomeMetric metric;
  final TimeRange range;
  final Color brandColor;

  const LegacyBarChart({
    Key? key,
    required this.data,
    required this.metric,
    required this.range,
    required this.brandColor,
  }) : super(key: key);

  @override
  State<LegacyBarChart> createState() => _LegacyBarChartState();
}

class _LegacyBarChartState extends State<LegacyBarChart>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutQuart,
    );
    _controller.forward();
  }

  @override
  void didUpdateWidget(covariant LegacyBarChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.data != widget.data ||
        oldWidget.metric != widget.metric ||
        oldWidget.range != widget.range) {
      _controller.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 250,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 16,
              offset: const Offset(0, 8))
        ],
      ),
      child: CustomPaint(
        size: Size.infinite,
        painter: _BarChartPainter(
          data: widget.data,
          metric: widget.metric,
          range: widget.range,
          brandColor: widget.brandColor,
          animationValue: _animation.value,
        ),
      ),
    );
  }
}

class _BarChartPainter extends CustomPainter {
  final List<DailyMetric> data;
  final HomeMetric metric;
  final TimeRange range;
  final Color brandColor;
  final double animationValue;

  _BarChartPainter({
    required this.data,
    required this.metric,
    required this.range,
    required this.brandColor,
    required this.animationValue,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const double marginBottom = 30.0;
    const double marginLeft = 45.0;
    const double marginTop = 20.0;
    const double marginRight = 10.0;

    final double chartHeight = size.height - marginBottom - marginTop;

    final Paint gridPaint = Paint()
      ..color = Colors.grey.shade200
      ..strokeWidth = 1.0;

    final Paint barPaint = Paint()
      ..shader = LinearGradient(
        colors: [brandColor, brandColor.withOpacity(0.6)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTWH(0, marginTop, size.width, chartHeight));

    double maxValue = 0;
    for (var item in data) {
      if (item.value > maxValue) maxValue = item.value;
    }
    if (maxValue == 0) maxValue = 1;

    final double yMaxScale = maxValue * 1.15;
    final int gridSteps = 4;

    for (int i = 0; i <= gridSteps; i++) {
      final double value = yMaxScale * (i / gridSteps);
      final double yPos = marginTop + chartHeight - (chartHeight * (i / gridSteps));

      canvas.drawLine(
        Offset(marginLeft, yPos),
        Offset(size.width - marginRight, yPos),
        gridPaint,
      );

      String yLabel = value.toStringAsFixed(1);
      if (metric == HomeMetric.ritmoMedio) {
        final int m = value ~/ 60;
        final int s = (value % 60).toInt();
        yLabel = "$m:${s.toString().padLeft(2, '0')}";
      } else if (metric == HomeMetric.tiempoTotal) {
        if (value >= 60) {
          final h = (value / 60).toStringAsFixed(1);
          yLabel = "${h}h";
        } else {
          yLabel = "${value.toStringAsFixed(0)}m";
        }
      } else {
        if (value >= 10) yLabel = value.toStringAsFixed(0);
      }

      final textSpan = TextSpan(
        text: yLabel,
        style: TextStyle(
            color: Colors.grey.shade400,
            fontSize: 10,
            fontWeight: FontWeight.w500),
      );
      final textPainter = TextPainter(
        text: textSpan,
        textDirection: ui.TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(marginLeft - textPainter.width - 6, yPos - textPainter.height / 2),
      );
    }

    if (data.isEmpty) return;

    final double chartWidth = size.width - marginLeft - marginRight;
    final double spacing = chartWidth / data.length;
    double widthRatio = 0.6;
    if (data.length > 20) widthRatio = 0.7;
    double barWidth = spacing * widthRatio;
    if (barWidth > 32.0) barWidth = 32.0;
    if (barWidth < 2.0) barWidth = 2.0;
    if (barWidth > spacing - 1) barWidth = spacing - 1;

    for (int i = 0; i < data.length; i++) {
      final item = data[i];
      final double centerOfSlot = marginLeft + (spacing * i) + (spacing / 2);
      final double left = centerOfSlot - (barWidth / 2);
      final double bottom = marginTop + chartHeight;

      if (item.value > 0) {
        final double rawHeight = (item.value / yMaxScale) * chartHeight;
        final double animatedHeight = rawHeight * animationValue;
        final double effectiveHeight = animatedHeight < 1.0 ? 0.0 : animatedHeight;

        if (effectiveHeight > 0) {
          final double top = bottom - effectiveHeight;
          final RRect rrect = RRect.fromRectAndRadius(
            Rect.fromLTWH(left, top, barWidth, effectiveHeight),
            Radius.circular(barWidth / 2.5),
          );
          canvas.drawRRect(rrect, barPaint);
        }
      }

       bool shouldDrawLabel = false;
       String label = "";

       if (range == TimeRange.oneWeek) {
         shouldDrawLabel = true;
         label = DateFormat('E', 'es').format(item.date).substring(0, 1).toUpperCase();
       } else if (range == TimeRange.oneMonth) {
         if (i == 0 || i == data.length - 1 || (i + 1) % 5 == 0) {
           shouldDrawLabel = true;
           label = DateFormat('d').format(item.date);
         }
       } else if (range == TimeRange.sixMonths) {
         if (i % 4 == 0) {
           shouldDrawLabel = true;
           label = DateFormat('MMM', 'es').format(item.date);
         }
       } else if (range == TimeRange.oneYear || range == TimeRange.max) {
           if (i == 0 || i == data.length - 1 || i % 2 == 0) { 
               shouldDrawLabel = true;
               label = DateFormat('MMM', 'es').format(item.date);
           }
       }
       
       if (shouldDrawLabel) {
         final textSpan = TextSpan(
            text: label,
            style: TextStyle(color: Colors.grey.shade400, fontSize: 10),
         );
         final tp = TextPainter(text: textSpan, textDirection: ui.TextDirection.ltr);
         tp.layout();
         tp.paint(canvas, Offset(centerOfSlot - tp.width / 2, marginTop + chartHeight + 6));
       }
    }
  }

  @override
  bool shouldRepaint(covariant _BarChartPainter oldDelegate) {
    return oldDelegate.animationValue != animationValue ||
        oldDelegate.data != data ||
        oldDelegate.metric != metric ||
        oldDelegate.range != range;
  }
}
