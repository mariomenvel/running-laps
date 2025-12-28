import 'package:flutter/material.dart';
import 'package:running_laps/features/analytics/viewmodels/analytics_hub_controller.dart';
import 'package:running_laps/core/widgets/kpi_card_with_delta.dart';
import 'package:running_laps/app/tema.dart';

class OverviewTab extends StatelessWidget {
  final AnalyticsHubController controller;

  const OverviewTab({
    super.key,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: controller.filteredData,
      builder: (context, data, _) {
        if (controller.isLoading.value) {
           return const Center(child: CircularProgressIndicator(color: Tema.brandPurple));
        }

        // Calculations are done using getters on the controller which use filteredData.value
        // However, the getters in controller access filteredData.value directly.
        // Since we are inside the builder, 'data' is the value, but we can also just call the getters 
        // because the builder triggered the rebuild.
        
        final totalKm = controller.totalDistanceKm;
        final totalWorkouts = controller.totalWorkouts;
        final avgPace = controller.formattedAvgPace;
        final last30Km = controller.distanceLast30Days;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Resumen Global',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),

              // GRID DE KPIs
              GridView.count(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                childAspectRatio: 1.3,
                children: [
                  KpiCardWithDelta(
                    title: 'Distancia',
                    value: '${totalKm.toStringAsFixed(1)} km',
                    subtitle: 'En periodo',
                    icon: Icons.map,
                    primaryColor: Colors.blue,
                  ),
                  KpiCardWithDelta(
                    title: 'Sesiones',
                    value: '$totalWorkouts',
                    subtitle: 'Entrenamientos',
                    icon: Icons.directions_run,
                    primaryColor: Colors.orange,
                  ),
                  KpiCardWithDelta(
                    title: 'Ritmo Medio',
                    value: avgPace,
                    subtitle: '/km',
                    icon: Icons.speed,
                    primaryColor: Colors.purple,
                    isInverted: true,
                  ),
                  KpiCardWithDelta(
                    title: 'Tiempo Total',
                    value: controller.formattedTotalDuration,
                    subtitle: 'En periodo',
                    icon: Icons.timer,
                    primaryColor: Colors.teal,
                  ),
                ],
              ),

              const SizedBox(height: 32),
              
              // INSIGHT MOCK
              Container(
                 padding: const EdgeInsets.all(20),
                 decoration: BoxDecoration(
                   gradient: const LinearGradient(
                     colors: [Color(0xFF2196F3), Color(0xFF1976D2)],
                     begin: Alignment.topLeft,
                     end: Alignment.bottomRight,
                   ),
                   borderRadius: BorderRadius.circular(16),
                   boxShadow: [
                     BoxShadow(color: Colors.blue.withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 6)),
                   ],
                 ),
                 child: Row(
                   children: [
                     Container(
                       padding: const EdgeInsets.all(12),
                       decoration: BoxDecoration(
                         color: Colors.white.withOpacity(0.2),
                         shape: BoxShape.circle,
                       ),
                       child: const Icon(Icons.tips_and_updates, color: Colors.white, size: 28),
                     ),
                     const SizedBox(width: 16),
                     Expanded(
                       child: Column(
                         crossAxisAlignment: CrossAxisAlignment.start,
                         children: const [
                           Text(
                             "Insight Semanal",
                             style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600),
                           ),
                           SizedBox(height: 4),
                           Text(
                             "¡Sigue así! Mantienes un buen ritmo constante.",
                             style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                           ),
                         ],
                       ),
                     )
                   ],
                 ),
              ),
            ],
          ),
        );
      },
    );
  }
}
