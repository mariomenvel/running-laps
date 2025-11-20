// Archivo: lib/features/home/views/home_view.dart

import 'dart:ui' as ui; // Importación con prefijo para resolver TextDirection
import 'package:flutter/material.dart';
import 'package:get/get_navigation/src/extension_navigation.dart';
import 'package:running_laps/features/training/views/training_start_view.dart';
import 'package:running_laps/features/profile/views/profile_view.dart';
import 'package:intl/intl.dart';
import '../../../app/tema.dart'; // Importar la clase Tema
import '../../../core/widgets/app_footer.dart'; // Importar el footer reutilizable
import '../../../core/widgets/app_header.dart'; // Importar el header reutilizable

// Importar las clases de estadísticas
import '../viewmodels/homeEstadistica_controller';
import '../data/homeEstadistica_repository.dart'; // Necesario para los tipos de datos (Enums, DailyMetric)

class HomeView extends StatefulWidget {
  const HomeView({Key? key}) : super(key: key);

  @override
  _HomeViewState createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> {
  // --- Colores ---
  static const Color _lightPurple = Color(0xFFC3A5D4);
  static const Color _bgGradientColor = Color(0xFFF9F5FB);

  // --- CONTROLADOR DE ESTADÍSTICAS ---
  late final HomeEstadisticaController _estadisticaController;

  @override
  void initState() {
    super.initState();
    // Inicializar el controlador (usará el constructor único)
    _estadisticaController = HomeEstadisticaController();
  }

  @override
  void dispose() {
    // Liberar recursos
    _estadisticaController.dispose();
    super.dispose();
  }

  // ===================================================================
  // Widgets de la UI
  // ===================================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // 1. HEADER
            _buildHeader(),

            // 2. BODY (Contiene el gráfico)
            Expanded(child: _buildNewBody()),

            // 3. FOOTER
            _buildFooter(),
          ],
        ),
      ),
    );
  }

  // ===================================================================
  // 1. HEADER
  // ===================================================================
  Widget _buildHeader() {
    return AppHeader(
      onTapLeft: () {},
      onTapRight: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const ProfileView()),
        );
      },
    );
  }

  // ===================================================================
  // 2. FOOTER
  // ===================================================================
  Widget _buildFooter() {
    return AppFooter(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const TrainingStartView()),
        );
      },
    );
  }

  // ===================================================================
  // 3. BODY (Contiene la tarjeta del gráfico)
  // ===================================================================
  Widget _buildNewBody() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Center(child: _buildStatisticsCard()),
    );
  }

  // ===================================================================
  // WIDGET PRINCIPAL DEL GRÁFICO (El contenido de la foto)
  // ===================================================================
  Widget _buildStatisticsCard() {
    return Card(
      elevation: 4.0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.0)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // 1. SELECTOR DE RANGO DE TIEMPO (1S, 1M, etc.)
            _buildTimeRangeSelector(),
            const SizedBox(height: 20),

            // 2. CONTENEDOR REACTIVO DEL GRÁFICO Y ESTADO DE CARGA/ERROR
            ValueListenableBuilder<bool>(
              valueListenable: _estadisticaController.isLoading,
              builder: (context, isLoading, child) {
                if (isLoading) {
                  return const SizedBox(
                    height: 200,
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
                        height: 200,
                        child: Center(child: Text('Error: $error')),
                      );
                    }
                    return _buildChartArea(); // Contiene el gráfico real
                  },
                );
              },
            ),
            const SizedBox(height: 20),

            // 3. SELECTOR DE RITMO/MÉTRICA
            _buildMetricDropdown(),
          ],
        ),
      ),
    );
  }

  // --- 1. Selector de Rango de Tiempo (1S, 1M, ...) ---
  Widget _buildTimeRangeSelector() {
    final List<TimeRange> ranges = [
      TimeRange.oneWeek,
      TimeRange.oneMonth,
      TimeRange.threeMonths,
      TimeRange.sixMonths,
      TimeRange.oneYear,
      TimeRange.max,
    ];

    final Map<TimeRange, String> rangeLabels = {
      TimeRange.oneWeek: '1S',
      TimeRange.oneMonth: '1M',
      TimeRange.threeMonths: '3M',
      TimeRange.sixMonths: '6M',
      TimeRange.oneYear: '1Y',
      TimeRange.max: 'max',
    };

    return ValueListenableBuilder<TimeRange>(
      valueListenable: _estadisticaController.selectedRange,
      builder: (context, currentRange, child) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: ranges.map((range) {
            final bool isSelected = currentRange == range;
            return GestureDetector(
              onTap: () => _estadisticaController.setRange(range),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? _lightPurple.withOpacity(0.5)
                      : Colors.white,
                  border: Border.all(
                    color: isSelected ? Tema.brandPurple : Colors.grey.shade400,
                    width: isSelected ? 1.5 : 1.0,
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  rangeLabels[range]!,
                  style: TextStyle(
                    color: isSelected ? Tema.brandPurple : Colors.black87,
                    fontWeight: isSelected
                        ? FontWeight.bold
                        : FontWeight.normal,
                  ),
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  // --- 2. Área del Gráfico ---
  Widget _buildChartArea() {
    return ValueListenableBuilder<List<DailyMetric>>(
      valueListenable: _estadisticaController.graphData,
      builder: (context, data, child) {
        if (data.isEmpty) {
          return const SizedBox(
            height: 200,
            child: Center(
              child: Text("No hay datos de entrenamiento para este periodo."),
            ),
          );
        }

        return SizedBox(
          height: 200,
          child: CustomPaint(
            painter: BarChartPainter(
              data: data,
              metric: _estadisticaController.selectedMetric.value,
              brandColor: Tema.brandPurple,
            ),
            child: Container(),
          ),
        );
      },
    );
  }

  // --- 3. Selector de Métrica (Ritmo medio, Distancia, ...) ---
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
              icon: const Icon(Icons.arrow_drop_down),
              onChanged: (HomeMetric? newMetric) {
                if (newMetric != null) {
                  _estadisticaController.setMetric(newMetric);
                }
              },
              items: metricLabels.keys.map((metric) {
                return DropdownMenuItem<HomeMetric>(
                  value: metric,
                  child: Text(metricLabels[metric]!),
                );
              }).toList(),
            ),
          );
        },
      ),
    );
  }

  /// Helper para botón circular
  Widget _buildCircularButton({
    required IconData icon,
    required VoidCallback onTap,
    Color? color,
    bool isLoading = false,
  }) {
    return GestureDetector(
      onTap: isLoading ? null : onTap,
      child: Container(
        padding: const EdgeInsets.all(20.0),
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.12),
              blurRadius: 15.0,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: isLoading
            ? SizedBox(
                width: 40.0,
                height: 40.0,
                child: CircularProgressIndicator(
                  strokeWidth: 3.0,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    color ?? Tema.brandPurple,
                  ),
                ),
              )
            : Icon(icon, color: color ?? Tema.brandPurple, size: 40.0),
      ),
    );
  }
}

// ===================================================================
// CUSTOM PAINTER (AQUÍ ES CORRECTO)
// ===================================================================
class BarChartPainter extends CustomPainter {
  final List<DailyMetric> data;
  final HomeMetric metric;
  final Color brandColor;

  BarChartPainter({
    required this.data,
    required this.metric,
    required this.brandColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    final barPaint = Paint()..color = brandColor.withOpacity(0.8);
    // Encontrar valor máximo para escalar
    final maxValue = data.map((e) => e.value).reduce((a, b) => a > b ? a : b);
    if (maxValue == 0) return; // Evitar división por cero

    final barWidth = size.width / (data.length * 2);
    final spacing = size.width / (data.length * 2);

    for (int i = 0; i < data.length; i++) {
      final metric = data[i];
      final x = spacing * (i * 2 + 1);
      final barHeight = (metric.value / maxValue) * (size.height - 20);

      // Dibuja la barra
      // 🚨 RRect SÍ USA 'ui.' porque está en dart:ui
      final barRect = ui.RRect.fromRectAndRadius(
        Rect.fromLTWH(x, size.height - barHeight, barWidth, barHeight),
        const Radius.circular(5),
      );
      canvas.drawRRect(barRect, barPaint);

      // Dibuja la etiqueta del día (Lu, Ma, Mi...)
      final dayLabel = DateFormat(
        'E',
        'es',
      ).format(metric.date).substring(0, 2);
      final textSpan = TextSpan(
        text: dayLabel,
        style: const TextStyle(color: Colors.black, fontSize: 12),
      );

      // 🚨 TextPainter NO USA 'ui.' porque está en painting.dart (material.dart)
      final textPainter = TextPainter(
        text: textSpan,
        // 🚨 TextDirection SÍ USA 'ui.' para evitar la colisión con intl
        textDirection: ui.TextDirection.ltr,
      );

      textPainter.layout(minWidth: 0, maxWidth: barWidth * 2);
      textPainter.paint(
        canvas,
        Offset(x + barWidth / 2 - textPainter.width / 2, size.height + 5),
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
