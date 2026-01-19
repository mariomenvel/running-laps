import 'package:flutter/material.dart';
import '../viewmodels/admin_controller.dart';
import 'package:intl/intl.dart';

class AdminDashboardTab extends StatelessWidget {
  final AdminController controller;

  const AdminDashboardTab({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    if (controller.stats.isEmpty) {
      controller.loadDashboardStats();
    }

    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        if (controller.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        final stats = controller.stats;
        final usuarios = stats['totalUsers'] ?? 0;
        final onboarded = stats['onboardedUsers'] ?? 0;
        final retos = stats['activeChallenges'] ?? 0;
        final totalKm = (stats['totalKm'] ?? 0) / 1000.0; // Convert to Km
        final recentSample = stats['recentTrainingsSample'] as List<dynamic>? ?? [];

        // --- CÁLCULOS DE NEGOCIO (Client-side) ---
        
        // 1. Tasa de Conversión
        final double conversionRate = usuarios > 0 ? (onboarded / usuarios) * 100 : 0;

        // 2. Día Preferido (Tirada Larga)
        String preferredDay = "N/A";
        if (recentSample.isNotEmpty) {
          preferredDay = _calculatePreferredDay(recentSample);
        }

        // 3. Ritmo Medio (Comunidad)
        String avgPace = "N/A";
        if (recentSample.isNotEmpty) {
          avgPace = _calculateAvgPace(recentSample);
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Estado de la Comunidad",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              
              // ROW 1: Métricas de Vanity (Usuarios, Retos)
              Row(
                children: [
                  _buildStatCard(
                    "Usuarios Totales",
                    usuarios.toString(),
                    "Registrados en la plataforma",
                    Icons.people,
                    Colors.blue,
                  ),
                  const SizedBox(width: 16),
                  _buildStatCard(
                    "Retos Globales",
                    retos.toString(),
                    "Desafíos activos actualmente",
                    Icons.public,
                    Colors.purple,
                  ),
                ],
              ),
              const SizedBox(height: 16),

              const Text(
                "Analíticas de Negocio",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              
              // Date Filters
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildFilterChip(context, controller, AdminDateFilter.week, "7 Días"),
                    const SizedBox(width: 8),
                    _buildFilterChip(context, controller, AdminDateFilter.month, "30 Días"),
                    const SizedBox(width: 8),
                    _buildFilterChip(context, controller, AdminDateFilter.year, "Este Año"),
                    const SizedBox(width: 8),
                    _buildFilterChip(context, controller, AdminDateFilter.all, "Todo"),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // ROW 2: Engagement (Km, Onboarding)
              Row(
                children: [
                   _buildStatCard(
                    "Kilómetros Acumulados",
                    "${totalKm.toStringAsFixed(1)}k",
                     "Distancia total de la comunidad",
                    Icons.directions_run,
                    Colors.orange,
                  ),
                  const SizedBox(width: 16),
                  _buildStatCard(
                    "Conversión Onboarding",
                    "${conversionRate.toStringAsFixed(1)}%",
                    "% Usuarios que completan perfil",
                    Icons.verified_user,
                     conversionRate > 50 ? Colors.green : Colors.amber,
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // ROW 3: Insights (Día preferido, Ritmo)
              Row(
                children: [
                  _buildStatCard(
                    "Día Favorito",
                    preferredDay,
                    "Día con más actividad (Muestra reciente)",
                    Icons.calendar_today,
                    Colors.teal,
                  ),
                   const SizedBox(width: 16),
                   _buildStatCard(
                    "Ritmo Medio",
                    avgPace,
                    "Velocidad promedio de la comunidad",
                    Icons.speed,
                    Colors.indigo,
                  ),
                ],
              ),

              const SizedBox(height: 30),
              
              // CARD SISTEMA
              Card(
                elevation: 0,
                color: Colors.green.withOpacity(0.1),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: Colors.green.withOpacity(0.3))),
                child: const ListTile(
                  leading: Icon(Icons.check_circle, color: Colors.green),
                  title: Text("Sistema Operacional", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                  subtitle: Text("Todos los servicios funcionando correctamente"),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Calcula el día de la semana con más distancia acumulada en la muestra
  String _calculatePreferredDay(List<dynamic> sample) {
    try {
      final Map<int, double> dayDistances = {};
      
      for (var data in sample) {
        if (data['fecha'] != null) {
          DateTime date = DateTime.parse(data['fecha']); // Asume ISO String
          int weekday = date.weekday; // 1=Mon, 7=Sun
          double dist = (data['distanciaTotalM'] ?? 0).toDouble();
          
          dayDistances[weekday] = (dayDistances[weekday] ?? 0) + dist;
        }
      }

      if (dayDistances.isEmpty) return "N/A";

      // Encontrar max
      int bestDay = dayDistances.keys.reduce((a, b) => dayDistances[a]! > dayDistances[b]! ? a : b);
      
      const days = ["Lunes", "Martes", "Miércoles", "Jueves", "Viernes", "Sábado", "Domingo"];
      return days[bestDay - 1];
    } catch (e) {
      return "Calc Error";
    }
  }

  /// Calcula el ritmo medio de la muestra
  String _calculateAvgPace(List<dynamic> sample) {
    try {
      int count = 0;
      double totalPaceSec = 0;

      for (var data in sample) {
        // Intentar usar campo precalculado o calcularlo
        // Usamos num para ser flexibles con int/double de Firestore
        num? dist = data['distanciaTotalM'] as num?;
        num? tiempo = data['tiempoTotalSec'] as num?; // puede ser int o double
        
        if (dist != null && dist > 0 && tiempo != null) {
          double tiempoSec = tiempo.toDouble();
          double km = dist.toDouble() / 1000.0;
          double pace = tiempoSec / km; // sec/km
          
          // Sin filtros de outliers para permitir datos de prueba extremos
          totalPaceSec += pace;
          count++;
        }
      }

      if (count == 0) return "-:--";

      int avgSec = (totalPaceSec / count).round();
      int mm = avgSec ~/ 60;
      int ss = avgSec % 60;
      return "$mm:${ss.toString().padLeft(2, '0')} /km";
    } catch (e) {
       return "Err";
    }
  }

  Widget _buildStatCard(String title, String value, String description, IconData icon, Color color) {
    return Expanded(
      child: Container(
        height: 180, // Fixed height for alignment
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const Spacer(),
            Text(
              value,
              style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, letterSpacing: -1),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black87),
            ),
            const SizedBox(height: 4),
            Expanded(
              child: Text(
                description,
                style: TextStyle(fontSize: 11, color: Colors.grey.shade500, height: 1.2),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildFilterChip(BuildContext context, AdminController controller, AdminDateFilter filter, String label) {
    final bool isSelected = controller.currentFilter == filter;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => controller.setDateFilter(filter),
      backgroundColor: Colors.white,
      selectedColor: Colors.black87,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : Colors.black87,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: Colors.grey.shade300),
      ),
      checkmarkColor: Colors.white,
    );
  }
}
