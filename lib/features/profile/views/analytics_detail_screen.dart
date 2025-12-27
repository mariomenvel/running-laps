import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:running_laps/app/tema.dart';
import 'package:running_laps/features/profile/viewmodels/analytics_view_model.dart';

class AnalyticsDetailScreen extends StatefulWidget {
  final AnalyticsViewModel viewModel;
  final int? targetDistance; // Ej: 400
  final String? targetSignature; // Ej: "10x400" (Futuro)

  const AnalyticsDetailScreen({
    Key? key,
    required this.viewModel,
    this.targetDistance,
    this.targetSignature,
  }) : super(key: key);

  @override
  State<AnalyticsDetailScreen> createState() => _AnalyticsDetailScreenState();
}

class _AnalyticsDetailScreenState extends State<AnalyticsDetailScreen> {
  late List<Map<String, dynamic>> _dataPoints;
  
  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() {
    if (widget.targetDistance != null) {
      _dataPoints = widget.viewModel.getAllSeriesByDistance(widget.targetDistance!);
    } else {
      _dataPoints = [];
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_dataPoints.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text("Detalle")),
        body: const Center(child: Text("No hay datos suficientes")),
      );
    }

    final title = widget.targetDistance != null 
        ? "Evolución ${widget.targetDistance}m" 
        : "Análisis";

    return Scaffold(
      backgroundColor: const Color(0xFFF9F9F9),
      appBar: AppBar(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // 1. CHART PRINCIPAL
            Container(
              height: 300,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                   BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, 10))
                ],
              ),
              child: _buildChart(),
            ),

            const SizedBox(height: 24),

            // 2. KPIs
            _buildKPIs(),

            const SizedBox(height: 24),

            // 3. LISTA HISTÓRICA
            const Align(
              alignment: Alignment.centerLeft,
              child: Text("Historial", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 12),
            _buildHistoryList(),
          ],
        ),
      ),
    );
  }

  Widget _buildChart() {
    // Convertir a Spots
    // Eje X: Indice (0..n). Eje Y: Ritmo (seg/km)
    // Mostrar tooltip con fecha
    final spots = <FlSpot>[];
    double minPace = 9999;
    double maxPace = 0;

    for (int i = 0; i < _dataPoints.length; i++) {
      final p = _dataPoints[i];
      final val = (p['paceSeconds'] as int).toDouble();
      if (val < minPace) minPace = val;
      if (val > maxPace) maxPace = val;
      spots.add(FlSpot(i.toDouble(), val));
    }

    // Invertir Y visualmente no es facil con LineChart sin tocar titles.
    // Simplemente graficamos normal: Arriba = Lento (tiempo alto), Abajo = Rápido (tiempo bajo).
    // OJO: Normalmente "subir" es mejorar, pero en running "bajar" tiempo es mejorar.
    // Dejemoslo estándar: Alto = Lento. Si la gráfica baja, estás mejorando.

    return LineChart(
      LineChartData(
        minY: minPace * 0.9,
        maxY: maxPace * 1.1,
        gridData: FlGridData(show: false),
        titlesData: FlTitlesData(show: false),
        borderData: FlBorderData(show: false),
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipItems: (touchedSpots) {
              return touchedSpots.map((spot) {
                final idx = spot.x.toInt();
                final date = _dataPoints[idx]['date'] as DateTime;
                final paceSec = spot.y.toInt();
                final m = paceSec ~/ 60;
                final s = paceSec % 60;
                final formattedPace = "$m:${s.toString().padLeft(2, '0')}";
                final dateStr = DateFormat('d MMM', 'es').format(date);
                
                return LineTooltipItem(
                  "$formattedPace /km\n$dateStr",
                  const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                );
              }).toList();
            }
          )
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: Tema.brandPurple,
            barWidth: 4,
            dotData: FlDotData(show: true, getDotPainter: (spot, percent, barData, index) {
               return FlDotCirclePainter(
                 radius: 4,
                 color: Colors.white,
                 strokeWidth: 2,
                 strokeColor: Tema.brandPurple
               );
            }),
            belowBarData: BarAreaData(show: true, color: Tema.brandPurple.withOpacity(0.1)),
          )
        ]
      )
    );
  }

  Widget _buildKPIs() {
    double totalPace = 0;
    double bestPace = 9999;
    
    for (var p in _dataPoints) {
      final val = (p['paceSeconds'] as int).toDouble();
      totalPace += val;
      if (val < bestPace) bestPace = val;
    }
    
    final avgPace = totalPace / _dataPoints.length;

    return Row(
      children: [
        Expanded(child: _buildKPICard("Mejor Ritmo", _formatPace(bestPace), Icons.emoji_events, Colors.amber)),
        const SizedBox(width: 12),
        Expanded(child: _buildKPICard("Ritmo Medio", _formatPace(avgPace), Icons.speed, Colors.blue)),
      ],
    );
  }

  Widget _buildKPICard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 16, offset: const Offset(0, 8))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 12),
          Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
        ],
      ),
    );
  }

  Widget _buildHistoryList() {
    return ListView.separated(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      itemCount: _dataPoints.reversed.length, // Más reciente arriba
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final reversedList = _dataPoints.reversed.toList();
        final item = reversedList[index];
        final date = item['date'] as DateTime;
        final pace = item['paceSeconds'] as int;
        
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                DateFormat('d MMM yyyy', 'es').format(date),
                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey),
              ),
              Row(
                children: [
                  Text(_formatPace(pace.toDouble()), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const Text(" /km", style: TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              )
            ],
          ),
        );
      },
    );
  }
  
  String _formatPace(double paceSeconds) {
    final m = paceSeconds ~/ 60;
    final s = (paceSeconds % 60).toInt();
    return "$m:${s.toString().padLeft(2, '0')}";
  }
}
