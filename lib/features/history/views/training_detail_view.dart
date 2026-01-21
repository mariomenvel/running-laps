import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:running_laps/config/app_theme.dart';
import 'package:running_laps/features/training/data/entrenamiento.dart';
import 'package:running_laps/features/training/data/serie.dart';
import 'package:running_laps/features/training/services/training_analysis_service.dart';
import 'package:intl/intl.dart';

class TrainingDetailView extends StatelessWidget {
  final Entrenamiento training;

  const TrainingDetailView({Key? key, required this.training}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: CustomScrollView(
        slivers: [
          _buildSliverAppBar(context),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildStatsGrid(),
                  const SizedBox(height: 24),
                  if (training.analysis != null && training.analysis!.bestSplits.isNotEmpty)
                    _buildBestSplitsSection(),
                  const SizedBox(height: 24),
                  _buildSeriesList(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSliverAppBar(BuildContext context) {
    return SliverAppBar(
      expandedHeight: 300.0,
      floating: false,
      pinned: true,
      backgroundColor: Tema.brandPurple,
      flexibleSpace: FlexibleSpaceBar(
        title: Text(
          training.titulo,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16.0,
            shadows: [Shadow(color: Colors.black45, blurRadius: 2)],
          ),
        ),
        background: _buildRouteMap(),
      ),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
        onPressed: () => Navigator.pop(context),
      ),
    );
  }

  Widget _buildRouteMap() {
    if (training.trackPoints.isEmpty) {
      return Container(
        color: Colors.grey.shade300,
        alignment: Alignment.center,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.gps_off, size: 48, color: Colors.grey.shade500),
            const SizedBox(height: 8),
            Text("Sin datos GPS", style: TextStyle(color: Colors.grey.shade600)),
          ],
        ),
      );
    }

    // Convert Points to FlSpots
    // Longitude = X, Latitude = Y
    // Normalize to handle scale? FlChart handles auto-scaling.
    final points = training.trackPoints
        .map((p) => FlSpot(p.longitude, p.latitude))
        .toList();

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(0), 
      child: Stack(
        children: [
          // Background pattern or map aesthetic
          Container(color: const Color(0xFFE5E3DF)), // Google Maps-ish bg color
          
          LineChart(
            LineChartData(
              gridData: FlGridData(show: false),
              titlesData: FlTitlesData(show: false),
              borderData: FlBorderData(show: false),
              lineBarsData: [
                LineChartBarData(
                  spots: points,
                  isCurved: false, // Polyline shouldn't be curved usually
                  color: Tema.brandPurple,
                  barWidth: 4,
                  dotData: FlDotData(show: false),
                  belowBarData: BarAreaData(show: false),
                ),
              ],
              lineTouchData: LineTouchData(enabled: false),
            ),
          ),
          
          // Map Label Overlay
          Positioned(
            bottom: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.8),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                "Ruta (Proyección)",
                style: TextStyle(fontSize: 10, color: Colors.black54),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsGrid() {
    final double distKm = training.distanciaTotalM() / 1000.0;
    final String timeStr = _formatDuration(training.tiempoTotalSec().round());
    final String paceStr = training.ritmoMedioTexto();
    final double rpe = training.rpePromedio();

    return Column(
      children: [
        Row(
          children: [
            Expanded(child: _buildStatCard("Distancia", "${distKm.toStringAsFixed(2)} km", Icons.straighten, Colors.blue)),
            const SizedBox(width: 12),
            Expanded(child: _buildStatCard("Tiempo", timeStr, Icons.timer, Colors.orange)),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _buildStatCard("Ritmo Medio", paceStr, Icons.speed, Colors.green)),
            const SizedBox(width: 12),
            Expanded(child: _buildStatCard("RPE Promedio", rpe.toStringAsFixed(1), Icons.bolt, Colors.red)),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            offset: const Offset(0, 4),
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Text(
                label.toUpperCase(),
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade500,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBestSplitsSection() {
    final sortedSplits = training.analysis!.bestSplits.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Mejores Marcas (Splits)",
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            children: sortedSplits.map((entry) {
              return _buildSplitRow(entry.value, entry.key);
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildSplitRow(SplitResult split, int distanceKey) {
    // Generate name based on distance key (e.g., 1 -> 1 km)
    final String name = "$distanceKey km";

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.purple.shade50,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.emoji_events_rounded, size: 16, color: Tema.brandPurple),
              ),
              const SizedBox(width: 12),
              Text(
                name,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _formatDuration(split.timeSeconds.round()),
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              Text(
                _formatPace(split.timeSeconds, split.distanceMeters.toDouble()),
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSeriesList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Desglose de Series",
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: training.series.length,
          itemBuilder: (context, index) {
            final serie = training.series[index];
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 2)),
                ],
              ),
              child: Row(
                children: [
                  Text(
                    "#${index + 1}",
                    style: TextStyle(
                      fontSize: 18, 
                      fontWeight: FontWeight.bold, 
                      color: Colors.grey.shade300
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              "${serie.distanciaM}m",
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            Text(
                              _formatDuration(serie.tiempoSec.round()),
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              "${serie.ritmoTexto()} /km",
                              style: TextStyle(fontSize: 14, color: Colors.green.shade700),
                            ),
                            if (serie.rpe > 0)
                            Text(
                              "RPE ${serie.rpe}",
                              style: const TextStyle(fontSize: 12, color: Colors.red),
                            ),
                          ],
                        )
                      ],
                    ),
                  )
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  String _formatDuration(int totalSeconds) {
    if (totalSeconds < 60) return "${totalSeconds}s";
    final int minutes = totalSeconds ~/ 60;
    final int seconds = totalSeconds % 60;
    if (minutes > 60) {
      final int hours = minutes ~/ 60;
      final int mins = minutes % 60;
      return "${hours}h ${mins}m";
    }
    return "${minutes}m ${seconds.toString().padLeft(2, '0')}s";
  }

  String _formatPace(double seconds, double distanceMeters) {
    if (distanceMeters == 0) return "-:--";
    double paceMinPerKm = (seconds / 60.0) / (distanceMeters / 1000.0);
    int pMin = paceMinPerKm.floor();
    int pSec = ((paceMinPerKm - pMin) * 60).round();
    return "$pMin:${pSec.toString().padLeft(2, '0')} /km";
  }
}
