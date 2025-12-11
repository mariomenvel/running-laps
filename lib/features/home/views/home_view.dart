// Archivo: lib/features/home/views/home_view.dart

import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:running_laps/features/training/views/training_start_view.dart';
import 'package:running_laps/features/profile/views/profile_view.dart';
import 'package:running_laps/features/profile/views/profile_menu_view.dart';

import '../../../app/tema.dart';
import '../../../core/widgets/app_footer.dart';

import '../viewmodels/homeEstadistica_Controller.dart';
import '../data/homeEstadistica_repository.dart';

// GROUPS FEATURE IMPORTS
import 'package:firebase_auth/firebase_auth.dart';
import '../../groups/home/data/groups_repository.dart';
import '../../groups/group_model.dart';
import '../../groups/home/view/groups_home_screen.dart';
import '../../groups/group/view/group_detail_screen.dart';

class HomeView extends StatefulWidget {
  const HomeView({Key? key}) : super(key: key);

  @override
  _HomeViewState createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> {
  static const Color _bgGradientColor = Color(0xFFF9F5FB);
  static const Color _lightPurple = Color(0xFFC3A5D4);

  late final HomeEstadisticaController _estadisticaController;
  final GroupsRepository _groupsRepository = GroupsRepository(); // Repository initialization

  final Future<void> _initializationFuture = initializeDateFormatting(
    'es',
    null,
  );

  // Estado para el Tooltip
  DailyMetric? _selectedMetric;
  Offset? _tooltipPosition;
  
  // Cache para grupos
  Future<List<GroupModel>>? _groupsFuture;

  @override
  void initState() {
    super.initState();
    _estadisticaController = HomeEstadisticaController();
    // Iniciar carga de grupos
    _loadGroups();
  }
  
  void _loadGroups() {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId != null) {
      _groupsFuture = _groupsRepository.fetchUserGroupsPreview(userId);
    } else {
      _groupsFuture = Future.value([]);
    }
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
          backgroundColor: const Color(0xFFF4F6F8), // Background gris suave para contraste
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
                        builder: (context) => const ProfileMenuView(),
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
      child: Column(
        children: [
          Center(child: _buildStatisticsCard()),
          const SizedBox(height: 25),
          _buildGroupsPreview(), // New Groups Preview Section
        ],
      ),
    );
  }

  Widget _buildGroupsPreview() {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return const SizedBox.shrink();

    // Safety for Hot Reload: Ensure future is initialized
    if (_groupsFuture == null) {
       _groupsFuture = _groupsRepository.fetchUserGroupsPreview(userId);
    }

    return Column(
      children: [
        // HEADER DE SECCIÓN
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Mis Comunidades",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const GroupsHomeScreen()),
                  ).then((_) {
                     // Recargar si vuelve de grupos (por si se salió de uno)
                     setState(() {
                       _loadGroups();
                     });
                  });
                },
                child: const Text(
                  "Ver todos",
                  style: TextStyle(
                    color: Tema.brandPurple,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),

        // LISTA DE TARJETAS (CACHED FUTURE)
        FutureBuilder<List<GroupModel>>(
          future: _groupsFuture,
          builder: (context, snapshot) {
             if (snapshot.connectionState == ConnectionState.waiting) {
              return const SizedBox(
                height: 150,
                child: Center(child: CircularProgressIndicator(color: Tema.brandPurple)),
              );
            }

            final groups = snapshot.data ?? [];

            if (groups.isEmpty) {
              return _buildEmptyGroupsState();
            }

            return SizedBox(
              height: 180, // Altura para las tarjetas
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: groups.length,
                separatorBuilder: (context, index) => const SizedBox(width: 15),
                itemBuilder: (context, index) {
                  return _GroupHighlightCard(group: groups[index]);
                },
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildEmptyGroupsState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))
        ],
      ),
      child: Column(
        children: [
          const Icon(Icons.group_off_rounded, size: 40, color: Colors.grey),
          const SizedBox(height: 10),
          const Text(
            "Aún no tienes equipos",
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey),
          ),
          const SizedBox(height: 5),
          ElevatedButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const GroupsHomeScreen()),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Tema.brandPurple,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            ),
            child: const Text("Explorar Grupos"),
          )
        ],
      ),
    );
  }

  Widget _buildStatisticsCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Selector de Métricas + Rango (en línea si cabe, o columna)
           Row(
             mainAxisAlignment: MainAxisAlignment.spaceBetween,
             children: [
               const Text("Tu Progreso", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
               // METRIC DROPDOWN SMALL
               SizedBox(
                  width: 140,
                  child: _buildMetricDropdown(),
               ),
             ],
           ),
           
           const SizedBox(height: 20),

          // Selector de Tiempo (Segmented Control Style)
          _buildTimeRangeSelector(),

          const SizedBox(height: 30),

          // CHART AREA
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
                          style: TextStyle(color: Colors.red.shade300),
                        ),
                      ),
                    );
                  }
                  return _buildChartArea();
                },
              );
            },
          ),
        ],
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
      TimeRange.max: 'Todo',
    };

    return ValueListenableBuilder<TimeRange>(
      valueListenable: _estadisticaController.selectedRange,
      builder: (context, currentRange, child) {
        return Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: ranges.map((range) {
              final bool isSelected = currentRange == range;
              return Expanded(
                child: GestureDetector(
                  onTap: () {
                    _estadisticaController.setRange(range);
                    setState(() => _selectedMetric = null);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeInOut,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected ? Colors.white : Colors.transparent,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: isSelected ? [
                        BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2))
                      ] : [],
                    ),
                    child: Text(
                      rangeLabels[range]!,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: isSelected ? Tema.brandPurple : Colors.grey.shade500,
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                        fontSize: 12,
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
                    child: _AnimatedBarChart(
                      data: data,
                      metric: _estadisticaController.selectedMetric.value,
                      range: _estadisticaController.selectedRange.value,
                      brandColor: Tema.brandPurple,
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
    height: 40, // más bajito
    padding: const EdgeInsets.symmetric(horizontal: 14),
    decoration: BoxDecoration(
      color: Colors.grey.shade50,
      borderRadius: BorderRadius.circular(24), // más redondeado
      border: Border.all(color: Colors.grey.shade300, width: 1),
    ),
    child: ValueListenableBuilder<HomeMetric>(
      valueListenable: _estadisticaController.selectedMetric,
      builder: (context, currentMetric, child) {
        return DropdownButtonHideUnderline(
          child: DropdownButton<HomeMetric>(
            isExpanded: true,
            isDense: true, // compacto
            value: currentMetric,
            icon: const Icon(
              Icons.arrow_drop_down_rounded,
              color: Tema.brandPurple,
              size: 20, // icono más pequeño
            ),
            borderRadius: BorderRadius.circular(16), // menú redondeado
            dropdownColor: Colors.white,
            style: const TextStyle(
              fontSize: 13,
              color: Colors.black,
            ),
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
                  style: const TextStyle(
                    fontSize: 13,
                  ),
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
  final double animationValue; // 0.0 a 1.0

  BarChartPainter({
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

    final double chartWidth = size.width - marginLeft - marginRight;
    final double chartHeight = size.height - marginBottom - marginTop;

    // Pintura del Grid (Líneas punteadas simuladas con opacidad baja)
    final Paint gridPaint = Paint()
      ..color = Colors.grey.shade200
      ..strokeWidth = 1.0;

    // Pintura de las barras con GRADIENTE
    final Paint barPaint = Paint()
      ..shader = LinearGradient(
        colors: [brandColor, brandColor.withOpacity(0.6)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTWH(0, marginTop, size.width, chartHeight));

    // 1. Calcular Máximos (igual que antes)
    double maxValue = 0;
    for (var item in data) {
      if (item.value > maxValue) maxValue = item.value;
    }
    if (maxValue == 0) maxValue = 1;
    
    final double yMaxScale = maxValue * 1.15;

    // 2. Grid y Etiquetas Eje Y (Grid estático, no animado, para dar contexto)
    final int gridSteps = 4;
    for (int i = 0; i <= gridSteps; i++) {
        final double value = yMaxScale * (i / gridSteps);
        final double yPos = marginTop + chartHeight - (chartHeight * (i / gridSteps));

        canvas.drawLine(
            Offset(marginLeft, yPos),
            Offset(size.width - marginRight, yPos),
            gridPaint,
        );
        
        // ETIQUETAS (Copiar lógica de formato existente)
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
        style: TextStyle(color: Colors.grey.shade400, fontSize: 10, fontWeight: FontWeight.w500),
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
    
    // 3. DIBUJO DE BARRAS ANIMADAS
    if (data.isEmpty) return;
    
    // Si la animación está empezando, quizás no pintar nada o pintar muy bajito
    // Pero si usamos animationValue como multiplicador de altura, funciona bien.

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
        // APLICAR ANIMACIÓN
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
      
      // Eje X (Etiquetas) - Solo pintar si animationValue > 0.5 para efecto escalonado? 
      // O pintarlas siempre. Pintémoslas siempre para que se vea el grid.
      // ... (Lógica de etiquetas X igual que antes) ...
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
           // ... logic from before ...
           if (i == 0 || i == data.length - 1 || i % 2 == 0) { // Simplificado
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
  bool shouldRepaint(covariant BarChartPainter oldDelegate) {
    // Repintar si cambian los datos o el valor de la animación
    return oldDelegate.animationValue != animationValue ||
           oldDelegate.data != data ||
           oldDelegate.metric != metric ||
           oldDelegate.range != range;
  }
}

// ===================================================================
// TARJETA DESTACADA DE GRUPO
// ===================================================================
class _GroupHighlightCard extends StatelessWidget {
  final GroupModel group;

  const _GroupHighlightCard({Key? key, required this.group}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Buscar al top runner (el primero de la lista)
    final topRunner = (group.topRunners != null && group.topRunners!.isNotEmpty)
        ? group.topRunners!.first
        : null;

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => GroupDetailScreen(
              groupId: group.id,
              groupName: group.name,
            ),
          ),
        );
      },
      child: Container(
        width: 160,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 4))
          ],
          border: Border.all(color: Colors.grey.shade100),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icono y Nombre
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Tema.brandPurple.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.emoji_events_rounded, size: 18, color: Tema.brandPurple),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    group.name,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            
            const Spacer(),
            
            // SECCIÓN TOP RUNNER
            if (topRunner != null) ...[
              const Text(
                "Líder actual",
                style: TextStyle(fontSize: 10, color: Colors.grey),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  // Avatar pequeño
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.amber, width: 1.5),
                    ),
                    child: ClipOval(
                      child: AvatarHelper.construirAvatar(
                        url: topRunner.photoUrl,
                        type: topRunner.profilePicType ?? 'none',
                        config: topRunner.avatarConfig,
                        radius: 12
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          topRunner.name,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          "${topRunner.totalKm.toStringAsFixed(1)} km",
                          style: const TextStyle(fontSize: 10, color: Tema.brandPurple, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  )
                ],
              )
            ] else ...[
               const Text(
                "¡Sé el primero!",
                style: TextStyle(fontSize: 11, color: Colors.grey, fontStyle: FontStyle.italic),
              ),
            ],

            const Spacer(),

            // Botón Entrar
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFF3E5F5), // Purple 50
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Center(
                child: Text(
                  "Ver Ranking",
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Tema.brandPurple,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ===================================================================
// ANIMATED BAR CHART
// ===================================================================
class _AnimatedBarChart extends StatefulWidget {
  final List<DailyMetric> data;
  final HomeMetric metric;
  final TimeRange range;
  final Color brandColor;

  const _AnimatedBarChart({
    Key? key,
    required this.data,
    required this.metric,
    required this.range,
    required this.brandColor,
  }) : super(key: key);

  @override
  State<_AnimatedBarChart> createState() => _AnimatedBarChartState();
}

class _AnimatedBarChartState extends State<_AnimatedBarChart>
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
  void didUpdateWidget(covariant _AnimatedBarChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Si cambian los datos o la métrica, reiniciar animación
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
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return CustomPaint(
          size: Size.infinite,
          painter: BarChartPainter(
            data: widget.data,
            metric: widget.metric,
            range: widget.range,
            brandColor: widget.brandColor,
            animationValue: _animation.value,
          ),
        );
      },
    );
  }
}
