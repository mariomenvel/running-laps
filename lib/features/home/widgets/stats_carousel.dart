import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:running_laps/config/app_theme.dart';
import 'package:running_laps/core/theme/app_colors.dart';
import 'package:running_laps/features/history/viewmodels/history_analytics_view_model.dart';
// import 'package:running_laps/features/profile/views/analytics_detail_screen.dart'; // Deleted/Moved

class StatsCarousel extends StatefulWidget {
  final HistoryAnalyticsViewModel viewModel;
  final VoidCallback onTapExplore; // Callback para ir a pantalla de detalle genérica

  const StatsCarousel({
    Key? key,
    required this.viewModel,
    required this.onTapExplore,
  }) : super(key: key);

  @override
  State<StatsCarousel> createState() => _StatsCarouselState();
}

class _StatsCarouselState extends State<StatsCarousel> {
  late PageController _pageController;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 0.92);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Si no hay datos, mostrar algo básico
    if (widget.viewModel.trainings.isEmpty) {
      return _buildEmptyState();
    }

    final pages = [
      _buildWeeklyActivityCard(),
      _buildPaceTrendCard(),
      _buildExploreCard(),
    ];

    return Column(
      children: [
        SizedBox(
          height: 180, // Altura compacta
          child: PageView(
            controller: _pageController,
            onPageChanged: (idx) => setState(() => _currentPage = idx),
            children: pages.map((p) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4.0),
              child: p,
            )).toList(),
          ),
        ),
        const SizedBox(height: 12),
        // Dots Indicator
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(pages.length, (index) {
            return AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: _currentPage == index ? 24 : 8,
              height: 8,
              decoration: BoxDecoration(
                color: _currentPage == index ? Tema.brandPurple : Theme.of(context).colorScheme.onSurface.withOpacity(0.2),
                borderRadius: BorderRadius.circular(4),
              ),
            );
          }),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Container(
      height: 180,
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
      ),
      child: const Center(
        child: Text("Realiza tu primer entrenamiento para ver estadísticas"),
      ),
    );
  }

  // 1. TARJETA SEMANAL (BARRAS)
  Widget _buildWeeklyActivityCard() {
    final data = widget.viewModel.getWeeklyDistance(weeks: 7); // Últimas 7
    // Invertir keys para gráfico: 6 (hace 6 semanas) -> 0 (esta semana)
    // El mapa es: 0=This week. Queremos visual de izquierda a derecha (antiguo -> nuevo)
    
    // Preparar BarGroups
    List<BarChartGroupData> barGroups = [];
    double maxVal = 0;

    for (int i = 6; i >= 0; i--) {
       final val = data[i] ?? 0.0;
       if (val > maxVal) maxVal = val;
       
       barGroups.add(
         BarChartGroupData(
           x: 6 - i, // 0..6
           barRods: [
             BarChartRodData(
               toY: val,
               color: i == 0 ? Tema.brandPurple : Tema.brandPurple.withOpacity(0.3), // Highlight this week
               width: 12,
               borderRadius: BorderRadius.circular(4),
             )
           ],
         )
       );
    }

    return _buildBaseCard(
      title: "Actividad Semanal",
      subtitle: "${(data[0] ?? 0).toStringAsFixed(1)} km esta semana",
      icon: Icons.bar_chart_rounded,
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceEvenly,
          maxY: maxVal * 1.2,
          barTouchData: BarTouchData(enabled: false),
          titlesData: FlTitlesData(show: false),
          gridData: FlGridData(show: false),
          borderData: FlBorderData(show: false),
          barGroups: barGroups,
        ),
      ),
    );
  }

  // 2. TARJETA RITMO (LÍNEA)
  Widget _buildPaceTrendCard() {
    final points = widget.viewModel.getPaceTrend();
    // Tomar últimos 20 ptos para que no se sature
    final recentPoints = points.length > 20 ? points.sublist(points.length - 20) : points;
    
    if (recentPoints.length < 2) {
      return _buildBaseCard(
        title: "Tendencia de Ritmo",
        subtitle: "Necesitas más datos",
        icon: Icons.show_chart_rounded,
        child: const Center(child: Text("Sigue entrenando...", style: TextStyle(color: Colors.grey))),
      );
    }

    // Convertir a Spots
    // Invertir Y (Ritmo bajo es mejor). trick: mostrar negativo o invertir labels.
    // Simplificación visual: Usamos valor real, pero mentalmente 'arriba' es lento.
    // Mejor: Normalizar. 
    // Para MVP visual: Graficamos ritmo (seg/km). Si baja es bueno.
    
    double minPace = 9999;
    double maxPace = 0;
    
    final spots = <FlSpot>[];
    for (int i = 0; i < recentPoints.length; i++) {
       final val = (recentPoints[i]['paceSeconds'] as int).toDouble();
       if (val < minPace) minPace = val;
       if (val > maxPace) maxPace = val;
       spots.add(FlSpot(i.toDouble(), val));
    }

    return _buildBaseCard(
      title: "Tendencia de Ritmo",
      subtitle: "Últimas ${recentPoints.length} sesiones",
      icon: Icons.speed,
      child: LineChart(
        LineChartData(
          minY: minPace * 0.9,
          maxY: maxPace * 1.1,
          lineTouchData: LineTouchData(enabled: false),
          gridData: FlGridData(show: false),
          titlesData: FlTitlesData(show: false),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              color: Colors.green.shade400,
              barWidth: 3,
              dotData: FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true, 
                color: Colors.green.withOpacity(0.1)
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 3. TARJETA EXPLORAR
  Widget _buildExploreCard() {
    final frequentDist = widget.viewModel.getMostFrequentSeriesDistances();
    final frequentWorkouts = widget.viewModel.getMostFrequentSignatures();

    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
         boxShadow: [
          BoxShadow(
            color: isDark ? Colors.transparent : Colors.black.withOpacity(0.04),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.auto_awesome, size: 20, color: Colors.orange),
              SizedBox(width: 8),
              Text("Explora tus Datos", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
          const SizedBox(height: 16),
          // Chips de sugerencia
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (var dist in frequentDist)
                ActionChip(
                  label: Text("${dist}m"),
                  backgroundColor: Tema.brandPurple.withOpacity(0.1),
                  labelStyle: TextStyle(color: Theme.of(context).brightness == Brightness.dark ? AppColors.brandPurpleLight : Tema.brandPurple, fontWeight: FontWeight.bold),
                  onPressed: () {
                    // TODO: Navegar a Detalle Distancia
                    // Callback(type: distance, val: dist)
                  },
                ),
              for (var sig in frequentWorkouts)
                 ActionChip(
                  label: Text(sig),
                  backgroundColor: Colors.blue.shade50,
                  labelStyle: TextStyle(color: Colors.blue.shade700, fontWeight: FontWeight.bold),
                  onPressed: () {
                    // TODO: Navegar a Detalle Workout
                  },
                ),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildBaseCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Widget child,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.transparent : Colors.black.withOpacity(0.04),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                   Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Theme.of(context).colorScheme.onSurface)),
                   Text(subtitle, style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5), fontSize: 12)),
                ],
              ),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.06),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 20, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.8)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(child: child),
        ],
      ),
    );
  }
}

