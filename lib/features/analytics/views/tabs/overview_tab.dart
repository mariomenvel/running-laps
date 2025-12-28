import 'package:flutter/material.dart';
import 'package:running_laps/features/analytics/viewmodels/analytics_hub_controller.dart';
import 'package:running_laps/core/widgets/kpi_card_with_delta.dart';
import 'package:running_laps/app/tema.dart';
import 'package:running_laps/features/analytics/data/coach_insight_service.dart';
import 'package:running_laps/features/analytics/widgets/coach_insight_widget.dart';

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
              
              CoachInsightWidget(insight: CoachInsightService().generateInsight(controller.filteredData.value)),
            ],
          ),
        );
      },
    );
  }
}
