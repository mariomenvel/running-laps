import 'package:flutter/material.dart';
import '../viewmodels/admin_controller.dart';
import 'package:intl/intl.dart';
import '../../../../core/widgets/premium_date_range_picker.dart';
import '../../../../config/app_theme.dart';

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
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "Estado de la Comunidad",
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  TextButton.icon(
                    onPressed: () => _showExportDialog(context, controller),
                    icon: const Icon(Icons.picture_as_pdf, size: 20),
                    label: const Text("Exportar"),
                    style: TextButton.styleFrom(foregroundColor: Tema.brandPurple),
                  ),
                ],
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
                  const Spacer(),
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

              // --- SECCIÓN 3: ANALÍTICAS DE NEGOCIO ---
              const Text(
                "Analíticas de Negocio",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                   _buildStatCard(
                    "Hora Punta",
                    stats['peakHour'] ?? "N/A",
                    "Franja horaria con más actividad en la comunidad",
                    Icons.access_time_filled,
                    Colors.amber.shade700,
                  ),
                  const SizedBox(width: 16),
                   _buildStatCard(
                    "Adopción GPS",
                    "${(stats['gpsAdoptionRate'] as num? ?? 0).toStringAsFixed(1)}%",
                    "% de entrenamientos rastreados con GPS",
                    Icons.gps_fixed,
                    Colors.indigoAccent,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                   _buildStatCard(
                    "Fidelidad Usuarios",
                    "${(stats['retentionRate'] as num? ?? 0).toStringAsFixed(1)}%",
                    "% de usuarios que repiten entre periodos (Sticky)",
                    Icons.favorite,
                    Colors.pinkAccent,
                  ),
                  const SizedBox(width: 16),
                   _buildStatCard(
                    "Crecimiento (Distancia)",
                    "${(stats['momGrowthKm'] as num? ?? 0) >= 0 ? "+" : ""}${(stats['momGrowthKm'] as num? ?? 0).toStringAsFixed(1)}%",
                    "Evolución de kilómetros vs periodo anterior",
                    Icons.trending_up,
                    (stats['momGrowthKm'] as num? ?? 0) >= 0 ? Colors.green : Colors.red,
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // --- SECCIÓN 4: ENGAGEMENT & MÉTRICAS ---
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
              const SizedBox(height: 16),
              Row(
                children: [
                   _buildStatCard(
                    "Distancia Media Semanal",
                    "${(stats['avgWeeklyDistance'] as double? ?? 0).toStringAsFixed(1)} km",
                    "Kilómetros promedio por semana (usuarios activos)",
                    Icons.trending_up,
                    Colors.cyan,
                  ),
                  const SizedBox(width: 16),
                   _buildStatCard(
                    "Distancia por Entreno",
                    "${(stats['avgDistancePerTraining'] as double? ?? 0).toStringAsFixed(1)} km",
                    "Kilómetros promedio por sesión",
                    Icons.route,
                    Colors.deepPurple,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                   _buildStatCard(
                    "Esfuerzo Medio (RPE)",
                    (stats['avgRpe'] as double? ?? 0).toStringAsFixed(1),
                    "Nivel de intensidad percibida (Escala 1-10)",
                    Icons.bolt,
                    Colors.redAccent,
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
    return Builder(
      builder: (context) {
        final cs = Theme.of(context).colorScheme;
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Expanded(
          child: Container(
            height: 180,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cs.surface,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: isDark ? Colors.transparent : Colors.black.withOpacity(0.05),
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
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: cs.onSurface),
                ),
                const SizedBox(height: 4),
                Expanded(
                  child: Text(
                    description,
                    style: TextStyle(fontSize: 11, color: cs.onSurface.withOpacity(0.5), height: 1.2),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
  
  Widget _buildFilterChip(BuildContext context, AdminController controller, AdminDateFilter filter, String label) {
    final bool isSelected = controller.currentFilter == filter;
    final cs = Theme.of(context).colorScheme;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => controller.setDateFilter(filter),
      backgroundColor: cs.surface,
      selectedColor: cs.onSurface,
      labelStyle: TextStyle(
        color: isSelected ? cs.surface : cs.onSurface,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: cs.outline.withOpacity(0.2)),
      ),
      checkmarkColor: cs.surface,
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
    final cs = Theme.of(context).colorScheme;

    return FilterChip(
      label: Text(label),
      avatar: isSelected
          ? Icon(Icons.date_range, size: 16, color: cs.surface)
          : Icon(Icons.date_range, size: 16, color: cs.onSurface.withOpacity(0.6)),
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
      backgroundColor: cs.surface,
      selectedColor: cs.onSurface,
      labelStyle: TextStyle(
        color: isSelected ? cs.surface : cs.onSurface,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: cs.outline.withOpacity(0.2)),
      ),
      checkmarkColor: cs.surface,
    );
  }

  void _showExportDialog(BuildContext context, AdminController controller) {
    final Map<String, String> availableMetrics = {
      'totalUsers': 'Total de Usuarios',
      'onboardedUsers': 'Usuarios con Onboarding',
      'activeUsersCount': 'Usuarios Activos (Mes)',
      'totalKm': 'Kilómetros Totales',
      'consistencyRate': 'Tasa de Consistencia',
      'preferredDay': 'Día más Activo',
      'avgPace': 'Ritmo Medio Comunidad',
      'avgDistancePerTraining': 'Distancia Media / Entreno',
      'avgWeeklyDistance': 'Distancia Media Semanal',
      'avgRpe': 'Esfuerzo Percibido (RPE)',
      'peakHour': 'Hora Punta de Actividad',
      'gpsAdoptionRate': 'Tasa de Adopción GPS',
      'retentionRate': 'Fidelidad (Retención)',
      'momGrowthKm': 'Crecimiento de kilómetros',
    };

    List<String> selectedMetrics = availableMetrics.keys.toList();
    DateTimeRange exportRange = controller.customRange ??
        DateTimeRange(
          start: DateTime.now().subtract(const Duration(days: 30)),
          end: DateTime.now(),
        );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          final cs = Theme.of(context).colorScheme;
          return Container(
            height: MediaQuery.of(context).size.height * 0.85,
            decoration: BoxDecoration(
              color: cs.surface,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(30),
                topRight: Radius.circular(30),
              ),
            ),
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.symmetric(vertical: 20),
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: cs.outline.withOpacity(0.1))),
                ),
                child: Column(
                  children: [
                    Container(
                      width: 40,
                      height: 5,
                      decoration: BoxDecoration(
                        color: cs.onSurface.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    const SizedBox(height: 15),
                    const Text(
                      "Exportar Reporte Premium",
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),

              // Content
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(24),
                  children: [
                    // Date Range Section
                    Text(
                      "Rango de Fechas",
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: cs.onSurface.withOpacity(0.5)),
                    ),
                    const SizedBox(height: 12),
                    InkWell(
                      onTap: () async {
                        final picked = await showModalBottomSheet<DateTimeRange>(
                          context: context,
                          isScrollControlled: true,
                          backgroundColor: Colors.transparent,
                          builder: (context) => SizedBox(
                            height: MediaQuery.of(context).size.height * 0.8,
                            child: PremiumDateRangePicker(
                              firstDate: DateTime(2020),
                              lastDate: DateTime.now(),
                              initialDateRange: exportRange,
                              onRangeSelected: (range) {},
                            ),
                          ),
                        );
                        if (picked != null) {
                          setState(() => exportRange = picked);
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Tema.brandPurple.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(15),
                          border: Border.all(color: Tema.brandPurple.withOpacity(0.2)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.calendar_today, color: Tema.brandPurple, size: 20),
                            const SizedBox(width: 12),
                            Text(
                              "${DateFormat('dd/MM/yyyy').format(exportRange.start)} - ${DateFormat('dd/MM/yyyy').format(exportRange.end)}",
                              style: const TextStyle(fontWeight: FontWeight.bold, color: Tema.brandPurple),
                            ),
                            const Spacer(),
                            const Icon(Icons.edit, color: Tema.brandPurple, size: 18),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 30),

                    // Metrics Section
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "Métricas a incluir",
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: cs.onSurface.withOpacity(0.5)),
                        ),
                        TextButton(
                          onPressed: () {
                            setState(() {
                              if (selectedMetrics.length == availableMetrics.length) {
                                selectedMetrics.clear();
                              } else {
                                selectedMetrics = availableMetrics.keys.toList();
                              }
                            });
                          },
                          child: Text(selectedMetrics.length == availableMetrics.length ? "Ninguna" : "Todas"),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ...availableMetrics.entries.map((entry) {
                      final isSelected = selectedMetrics.contains(entry.key);
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: InkWell(
                          onTap: () {
                            setState(() {
                              if (isSelected) {
                                selectedMetrics.remove(entry.key);
                              } else {
                                selectedMetrics.add(entry.key);
                              }
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              color: isSelected ? cs.surface : cs.onSurface.withOpacity(0.04),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSelected ? Tema.brandPurple.withOpacity(0.3) : cs.outline.withOpacity(0.2),
                                width: isSelected ? 2 : 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  isSelected ? Icons.check_circle : Icons.circle_outlined,
                                  color: isSelected ? Tema.brandPurple : cs.onSurface.withOpacity(0.4),
                                  size: 22,
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  entry.value,
                                  style: TextStyle(
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                    color: isSelected ? cs.onSurface : cs.onSurface.withOpacity(0.5),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ),

              // Bottom Action
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Tema.brandPurple,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                        elevation: 0,
                      ),
                      onPressed: selectedMetrics.isEmpty
                          ? null
                          : () async {
                              Navigator.pop(context);
                              await controller.exportToPdf(
                                selectedMetrics: selectedMetrics,
                                range: exportRange,
                              );
                            },
                      child: const Text(
                        "Generar PDF",
                        style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          );
        },
      ),
    );
  }
}
