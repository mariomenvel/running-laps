// Archivo: lib/features/home/views/home_view.dart

import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:running_laps/features/training/views/training_start_view.dart';
import 'package:running_laps/features/profile/views/profile_view.dart';
import '../../../app/tema.dart';
import '../../../core/widgets/app_footer.dart';

import '../viewmodels/homeEstadistica_Controller.dart';
import '../data/homeEstadistica_repository.dart';

class HomeView extends StatefulWidget {
  const HomeView({Key? key}) : super(key: key);

  @override
  _HomeViewState createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> {
  static const Color _bgGradientColor = Color(0xFFF9F5FB);
  static const Color _lightPurple = Color(0xFFC3A5D4);

  late final HomeEstadisticaController _estadisticaController;
  final Future<void> _initializationFuture = initializeDateFormatting(
    'es',
    null,
  );

  // Estado para el Tooltip
  DailyMetric? _selectedMetric;
  Offset? _tooltipPosition;

  @override
  void initState() {
    super.initState();
    _estadisticaController = HomeEstadisticaController();
  }

  @override
  void dispose() {
    _estadisticaController.dispose();
    super.dispose();
  }

  void _onPlayButtonTap() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const TrainingStartView()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _initializationFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(color: Tema.brandPurple),
            ),
          );
        }

        return Scaffold(
          backgroundColor: Colors.white,
          body: GestureDetector(
            // Al tocar fuera del gráfico, cerramos el tooltip
            onTap: () {
              if (_selectedMetric != null) {
                setState(() => _selectedMetric = null);
              }
            },
            child: SafeArea(
              child: Column(
                children: [
                  _buildHeader(),
                  Expanded(child: _buildNewBody()),
                  AppFooter(onTap: _onPlayButtonTap),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader() {
    return Container(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: Alignment.topCenter,
          radius: 1.2,
          colors: [_bgGradientColor, Colors.white],
          stops: const [0.0, 1.0],
        ),
        image: const DecorationImage(
          image: AssetImage('assets/images/fondo.png'),
          fit: BoxFit.cover,
        ),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 20.0,
              vertical: 16.0,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const CircleAvatar(
                  radius: 24.0,
                  backgroundColor: Tema.brandPurple,
                  backgroundImage: AssetImage('assets/images/logo.png'),
                ),
                GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const ProfileView(),
                      ),
                    );
                  },
                  child: AvatarHelper.construirImagenPerfil(radius: 24.0),
                ),
              ],
            ),
          ),
          Container(height: 1.0, color: Colors.grey.shade200),
        ],
      ),
    );
  }

  Widget _buildNewBody() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Center(child: _buildStatisticsCard()),
    );
  }

  Widget _buildStatisticsCard() {
    return Card(
      elevation: 4.0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.0)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            _buildTimeRangeSelector(),
            const SizedBox(height: 30),

            ValueListenableBuilder<bool>(
              valueListenable: _estadisticaController.isLoading,
              builder: (context, isLoading, child) {
                if (isLoading) {
                  return const SizedBox(
                    height: 250,
                    child: Center(
                      child: CircularProgressIndicator(color: Tema.brandPurple),
                    ),
                  );
                }

                return ValueListenableBuilder<String?>(
                  valueListenable: _estadisticaController.error,
                  builder: (context, error, _) {
                    if (error != null) {
                      return SizedBox(
                        height: 250,
                        child: Center(
                          child: Text(
                            'Error: $error',
                            textAlign: TextAlign.center,
                          ),
                        ),
                      );
                    }
                    return _buildChartArea();
                  },
                );
              },
            ),
            const SizedBox(height: 20),
            _buildMetricDropdown(),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeRangeSelector() {
    final List<TimeRange> ranges = [
      TimeRange.oneWeek,
      TimeRange.oneMonth,
      TimeRange.sixMonths,
      TimeRange.oneYear,
      TimeRange.max,
    ];
    final Map<TimeRange, String> rangeLabels = {
      TimeRange.oneWeek: '1S',
      TimeRange.oneMonth: '1M',
      TimeRange.sixMonths: '6M',
      TimeRange.oneYear: '1A',
      TimeRange.max: 'máx',
    };

    return ValueListenableBuilder<TimeRange>(
      valueListenable: _estadisticaController.selectedRange,
      builder: (context, currentRange, child) {
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: ranges.map((range) {
              final bool isSelected = currentRange == range;
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4.0),
                child: GestureDetector(
                  onTap: () {
                    _estadisticaController.setRange(range);
                    setState(() => _selectedMetric = null);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? _lightPurple.withOpacity(0.5)
                          : Colors.transparent,
                      border: Border.all(
                        color: isSelected
                            ? Tema.brandPurple
                            : Colors.grey.shade300,
                        width: isSelected ? 1.5 : 1.0,
                      ),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      rangeLabels[range]!,
                      style: TextStyle(
                        color: isSelected
                            ? Tema.brandPurple
                            : Colors.grey.shade700,
                        fontWeight: isSelected
                            ? FontWeight.bold
                            : FontWeight.normal,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        );
      },
    );
  }

  // --- ÁREA DEL GRÁFICO ---
  Widget _buildChartArea() {
    return ValueListenableBuilder<List<DailyMetric>>(
      valueListenable: _estadisticaController.graphData,
      builder: (context, data, child) {
        if (data.isEmpty) {
          return const SizedBox(
            height: 250,
            child: Center(child: Text("No hay datos para mostrar.")),
          );
        }

        return LayoutBuilder(
          builder: (context, constraints) {
            final double availableWidth = constraints.maxWidth;
            final double chartHeight = 250.0;

            return SizedBox(
              height: chartHeight,
              width: availableWidth,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTapUp: (details) =>
                        _handleChartTap(details, data, availableWidth),
                    child: CustomPaint(
                      size: Size(availableWidth, chartHeight),
                      painter: BarChartPainter(
                        data: data,
                        metric: _estadisticaController.selectedMetric.value,
                        range: _estadisticaController.selectedRange.value,
                        brandColor: Tema.brandPurple,
                      ),
                    ),
                  ),

                  if (_selectedMetric != null && _tooltipPosition != null)
                    Positioned(
                      left:
                          _tooltipPosition!.dx -
                          70, // Ajustado para centrar mejor
                      top: _tooltipPosition!.dy - 65, // Un poco más arriba
                      child: _buildTooltip(_selectedMetric!),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _handleChartTap(
    TapUpDetails details,
    List<DailyMetric> data,
    double availableWidth,
  ) {
    const double marginLeft = 40.0;
    const double marginRight = 10.0;
    final double chartDrawWidth = availableWidth - marginLeft - marginRight;
    final double localX = details.localPosition.dx - marginLeft;

    // Si tocas los márgenes, ignorar
    if (localX < 0 || localX > chartDrawWidth) return;

    final double spacing = chartDrawWidth / data.length;
    final int index = (localX / spacing).floor();

    if (index >= 0 && index < data.length) {
      final metric = data[index];
      // Permitir click incluso si es 0 para ver que ese día no hubo nada
      setState(() {
        _selectedMetric = metric;
        final double barCenter = marginLeft + (spacing * index) + (spacing / 2);
        _tooltipPosition = Offset(barCenter, details.localPosition.dy - 20);
      });
    }
  }

  // Helper para formatear valores según la métrica seleccionada
  String _formatValue(double value, HomeMetric metricType) {
    if (value == 0) return "-";

    switch (metricType) {
      case HomeMetric.ritmoMedio:
        // El valor viene en segundos/km. Convertir a min:seg
        final int minutes = value ~/ 60;
        final int seconds = (value % 60).toInt();
        final String secStr = seconds.toString().padLeft(2, '0');
        return "$minutes:$secStr /km";

      case HomeMetric.distanciaTotal:
        // El valor viene en km
        return "${value.toStringAsFixed(2)} km";

      case HomeMetric.tiempoTotal:
        // El valor viene en minutos
        final int h = value ~/ 60;
        final int m = (value % 60).toInt();
        if (h > 0) {
          return "${h}h ${m}min";
        }
        return "${value.toStringAsFixed(0)} min";

      case HomeMetric.rpePromedio:
        return "${value.toStringAsFixed(1)} RPE";
    }
  }

  Widget _buildTooltip(DailyMetric metric) {
    String dateStr;
    final metricType = _estadisticaController.selectedMetric.value;
    final range = _estadisticaController.selectedRange.value;

    // Formato de fecha
    if (range == TimeRange.oneYear || range == TimeRange.max) {
      dateStr = DateFormat('MMM yyyy', 'es').format(metric.date);
    } else {
      dateStr = DateFormat('EEEE d MMM', 'es').format(metric.date);
    }

    final String valueStr = _formatValue(metric.value, metricType);

    return Container(
      width: 140,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black87,
        borderRadius: BorderRadius.circular(8),
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            dateStr,
            style: const TextStyle(color: Colors.white70, fontSize: 11),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 2),
          Text(
            valueStr,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildMetricDropdown() {
    final Map<HomeMetric, String> metricLabels = {
      HomeMetric.ritmoMedio: 'Ritmo medio',
      HomeMetric.distanciaTotal: 'Distancia total (Km)',
      HomeMetric.tiempoTotal: 'Tiempo total (min)',
      HomeMetric.rpePromedio: 'RPE promedio',
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade400),
      ),
      child: ValueListenableBuilder<HomeMetric>(
        valueListenable: _estadisticaController.selectedMetric,
        builder: (context, currentMetric, child) {
          return DropdownButtonHideUnderline(
            child: DropdownButton<HomeMetric>(
              isExpanded: true,
              value: currentMetric,
              icon: const Icon(Icons.arrow_drop_down, color: Tema.brandPurple),
              onChanged: (HomeMetric? newMetric) {
                if (newMetric != null) {
                  _estadisticaController.setMetric(newMetric);
                  setState(() => _selectedMetric = null);
                }
              },
              items: metricLabels.keys.map((metric) {
                return DropdownMenuItem<HomeMetric>(
                  value: metric,
                  child: Text(
                    metricLabels[metric]!,
                    style: const TextStyle(fontSize: 14),
                  ),
                );
              }).toList(),
            ),
          );
        },
      ),
    );
  }
}

// ===================================================================
// CUSTOM PAINTER (CORREGIDO)
// ===================================================================
class BarChartPainter extends CustomPainter {
  final List<DailyMetric> data;
  final HomeMetric metric;
  final TimeRange range;
  final Color brandColor;

  BarChartPainter({
    required this.data,
    required this.metric,
    required this.range,
    required this.brandColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const double marginBottom = 30.0;
    const double marginLeft = 40.0;
    const double marginTop = 20.0;
    const double marginRight = 10.0;

    final double chartWidth = size.width - marginLeft - marginRight;
    final double chartHeight = size.height - marginBottom - marginTop;

    final Paint axisPaint = Paint()
      ..color = Colors.grey.shade300
      ..strokeWidth = 1.0;

    final Paint barPaint = Paint()..color = brandColor;
    final Paint shadowPaint = Paint()
      ..color = brandColor.withOpacity(0.3)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4.0);

    // 1. Calcular Máximos
    double maxValue = 0;
    for (var item in data) {
      if (item.value > maxValue) maxValue = item.value;
    }
    if (maxValue == 0) maxValue = 1;
    final double yMaxScale = maxValue * 1.1;

    // 2. Grid
    final int gridSteps = 4;
    for (int i = 0; i <= gridSteps; i++) {
      final double value = yMaxScale * (i / gridSteps);
      final double yPos =
          marginTop + chartHeight - (chartHeight * (i / gridSteps));

      canvas.drawLine(
        Offset(marginLeft, yPos),
        Offset(size.width - marginRight, yPos),
        axisPaint,
      );

      // Formato del eje Y inteligente
      String yLabel = value.toStringAsFixed(1);
      if (metric == HomeMetric.tiempoTotal || metric == HomeMetric.ritmoMedio) {
        if (value > 10) yLabel = value.toStringAsFixed(0);
      }

      final textSpan = TextSpan(
        text: yLabel,
        style: TextStyle(color: Colors.grey.shade600, fontSize: 10),
      );
      final textPainter = TextPainter(
        text: textSpan,
        textDirection: ui.TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(
          marginLeft - textPainter.width - 5,
          yPos - textPainter.height / 2,
        ),
      );
    }

    // 3. DIBUJO DE BARRAS (LÓGICA ROBUSTA)
    if (data.isEmpty) return;

    final double spacing = chartWidth / data.length;

    // Ratio según cantidad de datos
    double widthRatio = 0.65;
    if (data.length > 20) widthRatio = 0.75; // Para 1M

    double barWidth = spacing * widthRatio;

    // REGLAS DE ANCHO:
    // 1. Máximo 50px por estética
    if (barWidth > 50.0) barWidth = 50.0;

    // 2. Mínimo 2px para que se vea siempre
    if (barWidth < 2.0) barWidth = 2.0;

    // 3. Seguridad contra solapamiento:
    // Si el ancho calculado invade la siguiente celda, reducirlo
    // Dejamos al menos 0.5px de aire
    if (barWidth > spacing - 0.5) {
      barWidth = spacing - 0.5;
      if (barWidth < 0.5) barWidth = 0.5; // Caso extremo pantalla minúscula
    }

    for (int i = 0; i < data.length; i++) {
      final item = data[i];

      final double centerOfSlot = marginLeft + (spacing * i) + (spacing / 2);
      final double left = centerOfSlot - (barWidth / 2);
      final double bottom = marginTop + chartHeight;

      if (item.value > 0) {
        final double barHeight = (item.value / yMaxScale) * chartHeight;

        // Altura mínima visual (si tiene valor, que se vea algo)
        final double effectiveHeight = barHeight < 2.0 ? 2.0 : barHeight;
        final double top = bottom - effectiveHeight;

        final Rect rect = Rect.fromLTWH(left, top, barWidth, effectiveHeight);
        // Radio no puede ser mayor que la mitad del ancho
        final double radius = barWidth / 2;
        final RRect rrect = RRect.fromRectAndRadius(
          rect,
          Radius.circular(radius),
        );

        canvas.drawRRect(rrect.shift(const Offset(2, 2)), shadowPaint);
        canvas.drawRRect(rrect, barPaint);
      }

      // 4. Etiquetas
      bool shouldDrawLabel = false;
      String label = "";

      if (range == TimeRange.oneWeek) {
        shouldDrawLabel = true;
        label = DateFormat(
          'E',
          'es',
        ).format(item.date).substring(0, 1).toUpperCase();
      } else if (range == TimeRange.oneMonth) {
        // Etiquetas cada 5 días
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
        shouldDrawLabel = true;
        label = DateFormat(
          'MMM',
          'es',
        ).format(item.date).substring(0, 1).toUpperCase();
        if (data.length > 15 && i % 2 != 0) shouldDrawLabel = false;
      }

      if (shouldDrawLabel) {
        final xTextSpan = TextSpan(
          text: label,
          style: TextStyle(color: Colors.grey.shade700, fontSize: 10),
        );
        final xTextPainter = TextPainter(
          text: xTextSpan,
          textDirection: ui.TextDirection.ltr,
        );
        xTextPainter.layout();

        xTextPainter.paint(
          canvas,
          Offset(centerOfSlot - xTextPainter.width / 2, bottom + 8),
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
