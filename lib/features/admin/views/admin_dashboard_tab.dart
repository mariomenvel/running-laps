import 'package:flutter/material.dart';
import '../viewmodels/admin_controller.dart';
import 'package:intl/intl.dart';
import '../../../../core/widgets/premium_date_range_picker.dart';

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
        final retosGrupo = stats['groupChallengesCount'] ?? 0; // Nueva métrica
        final totalKm = (stats['totalKm'] ?? 0) / 1000.0;
        final recentSample = stats['recentTrainingsSample'] as List<dynamic>? ?? [];

        // --- CÁLCULOS DE NEGOCIO (Client-side) ---
        final double conversionRate = usuarios > 0 ? (onboarded / usuarios) * 100 : 0;
        
        String preferredDay = "N/A";
        if (recentSample.isNotEmpty) preferredDay = _calculatePreferredDay(recentSample);

        String avgPace = "N/A";
        if (recentSample.isNotEmpty) avgPace = _calculateAvgPace(recentSample);

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Estado de la Comunidad",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              
              // GLOBAL DATE FILTERS
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
                     const SizedBox(width: 8),
                    _buildCustomFilterChip(context, controller),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // --- SECCIÓN 1: USUARIOS ---
              const Text(
                "Usuarios",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
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
                  Builder(
                    builder: (context) {
                      final total = usuarios > 0 ? usuarios : 1;
                      final activeCount = stats['activeUsersCount'] as int? ?? 0;
                      final activePct = (activeCount / total) * 100;
                      
                      return _buildStatCard(
                        "Usuarios Activos (30d)",
                        "${activePct.toStringAsFixed(0)}%",
                        "$activeCount de $total usuarios han entrenado este mes",
                        Icons.local_fire_department,
                        Colors.deepOrange,
                      );
                    }
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // --- SECCIÓN 2: RETOS ---
               const Text(
                "Retos",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  _buildStatCard(
                    "Retos Globales",
                    retos.toString(),
                    "Desafíos globales activos",
                    Icons.public,
                    Colors.purple,
                  ),
                  const SizedBox(width: 16),
                   _buildStatCard(
                    "Retos de Grupo",
                    retosGrupo.toString(),
                    "Total retos en grupos",
                    Icons.groups,
                    Colors.indigo,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const SizedBox(height: 16),
              Row(
                children: [
                   _buildStatCard(
                    "Participación Global",
                    "${(stats['globalParticipationRate'] as double? ?? 0).toStringAsFixed(1)}%",
                    "% Activos en retos globales",
                    Icons.public,
                    Colors.purpleAccent,
                  ),
                  const SizedBox(width: 16),
                   _buildStatCard(
                    "Participación Grupo",
                    "${(stats['groupParticipationRate'] as double? ?? 0).toStringAsFixed(1)}%",
                    "% Activos en retos de grupo",
                    Icons.groups,
                    Colors.indigoAccent,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                   _buildStatCard(
                    "Finalización Global",
                    "${(stats['globalCompletionRate'] as double? ?? 0).toStringAsFixed(1)}%",
                    "% Aceptados que se completan",
                    Icons.flag,
                    Colors.green,
                  ),
                  const SizedBox(width: 16),
                   _buildStatCard(
                    "Finalización Grupo",
                    "${(stats['groupCompletionRate'] as double? ?? 0).toStringAsFixed(1)}%",
                    "% Aceptados que se completan",
                    Icons.sports_score,
                    Colors.teal,
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // --- SECCIÓN 3: ENGAGEMENT & MÉTRICAS ---
              const Text(
                "Engagement & Métricas",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              
              Row(
                children: [
                   _buildStatCard(
                    "Tasa de Consistencia",
                    "${(stats['consistencyRate'] as double? ?? 0).toStringAsFixed(1)} /sem",
                    "Entrenamientos promedio por usuario (activo) semanal",
                    Icons.repeat,
                    Colors.blueGrey,
                  ),
                  const SizedBox(width: 16),
                   _buildStatCard(
                    "Kilómetros Acumulados",
                    "${totalKm.toStringAsFixed(1)}k",
                     "Distancia total de la comunidad",
                    Icons.directions_run,
                    Colors.orange,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  _buildStatCard(
                    "Conversión Onboarding",
                    "${conversionRate.toStringAsFixed(1)}%",
                    "% Usuarios que completan perfil",
                    Icons.verified_user,
                     conversionRate > 50 ? Colors.green : Colors.amber,
                  ),
                  const SizedBox(width: 16),
                  _buildStatCard(
                    "Día Favorito",
                    preferredDay,
                    "Día con más actividad (Muestra reciente)",
                    Icons.calendar_today,
                    Colors.teal,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                   _buildStatCard(
                    "Ritmo Medio",
                    avgPace,
                    "Velocidad promedio de la comunidad",
                    Icons.speed,
                    Colors.indigo,
                  ),
                  const Spacer(),
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

  Widget _buildCustomFilterChip(BuildContext context, AdminController controller) {
    bool isSelected = controller.currentFilter == AdminDateFilter.custom;
    String label = "Personalizado";
    if (isSelected && controller.customRange != null) {
      final start = DateFormat('dd/MM').format(controller.customRange!.start);
      final end = DateFormat('dd/MM').format(controller.customRange!.end);
      label = "$start - $end";
    }

    return FilterChip(
      label: Text(label),
      avatar: isSelected ? const Icon(Icons.date_range, size: 16, color: Colors.white) : const Icon(Icons.date_range, size: 16, color: Colors.black54),
      selected: isSelected,
      onSelected: (_) async {
        final DateTimeRange? picked = await showModalBottomSheet<DateTimeRange>(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent, // Para ver bordes redondeados
          builder: (context) => SizedBox(
            height: MediaQuery.of(context).size.height * 0.85,
            child: PremiumDateRangePicker(
              firstDate: DateTime(2020),
              lastDate: DateTime.now(),
              initialDateRange: controller.customRange,
              onRangeSelected: (range) {
                 // El botón "Aplicar" del widget se encarga de cerrar con Navigator.pop(context, range)
                 // Aquí solo se llama cuando se completa una selección si quisiéramos auto-cierre, 
                 // pero el widget tiene botón explícito.
                 // Ajuste: El widget PremiumDateRangePicker debería manejar el pop.
              },
            ),
          ),
        );

        if (picked != null) {
          controller.setCustomDateRange(picked);
        }
      },
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
