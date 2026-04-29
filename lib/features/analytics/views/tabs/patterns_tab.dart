import 'package:flutter/material.dart';
import 'package:running_laps/core/utils/app_transitions.dart';
import 'package:running_laps/features/analytics/viewmodels/analytics_hub_controller.dart';
import 'package:running_laps/features/analytics/data/pattern_detector.dart';
import 'package:running_laps/config/app_theme.dart';
import 'package:running_laps/features/analytics/data/series_pattern.dart';
import 'package:running_laps/features/analytics/data/workout_pattern.dart';
import 'package:running_laps/features/analytics/views/series_pattern_carousel_view.dart';
import 'package:running_laps/features/analytics/views/workout_pattern_carousel_view.dart';

import 'package:running_laps/core/constants/app_help_content.dart';
import 'package:running_laps/core/widgets/info_tooltip.dart';

class PatternsTab extends StatelessWidget {
  final AnalyticsHubController controller;

  const PatternsTab({super.key, required this.controller});

  // Calculate patterns on the fly from filtered data
  // In a real app with large data, this should be done in Isolate or Controller (cached)
  
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: controller.filteredData,
      builder: (context, data, _) {
        if (controller.isLoading.value) {
           return const Center(child: CircularProgressIndicator(color: AppColors.brand));
        }

        if (data.isEmpty) {
          return const Center(child: Text("No hay datos suficientes para detectar patrones"));
        }

        // Detect patterns
        final detector = PatternDetector();
        final seriesPatterns = detector.detectSeriesPatterns(data);
        final workoutPatterns = detector.detectWorkoutPatterns(data);

        // Filter valid ones (min count)
        final validSeries = seriesPatterns.where((p) => p.count >= 2).toList()
           ..sort((a, b) => b.count.compareTo(a.count));
        
        final validWorkouts = workoutPatterns.where((p) => p.count >= 2).toList()
           ..sort((a, b) => b.count.compareTo(a.count));

        if (validSeries.isEmpty && validWorkouts.isEmpty) {
           return const Center(child: Text("No se han detectado patrones frecuentes en este periodo"));
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
               if (validSeries.isNotEmpty) ...[
                 _buildSectionTitle(context, "Patrones de Series (Repeticiones)", helpText: AppHelpContent.patternsSeries),
                 const SizedBox(height: 12),
                 ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: validSeries.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                       return SeriesPatternCard(
                         pattern: validSeries[index],
                         allPatterns: validSeries,
                       );
                    },
                 ),
                 const SizedBox(height: 32),
               ],

               if (validWorkouts.isNotEmpty) ...[
                 _buildSectionTitle(context, "Entrenamientos Recurrentes", helpText: AppHelpContent.patternsWorkout),
                 const SizedBox(height: 12),
                 ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: validWorkouts.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                       return WorkoutPatternCard(
                         pattern: validWorkouts[index],
                         allPatterns: validWorkouts,
                       );
                    },
                 ),
               ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title, {String? helpText}) {
    return Row(
      children: [
        Text(
          title,
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface),
        ),
        if (helpText != null) ...[
          const SizedBox(width: 8),
          InfoTooltip(content: helpText),
        ],
      ],
    );
  }
}

class SeriesPatternCard extends StatelessWidget {
  final SeriesPattern pattern;
  final List<SeriesPattern> allPatterns;
  const SeriesPatternCard({super.key, required this.pattern, required this.allPatterns});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        final index = allPatterns.indexOf(pattern);
        Navigator.push(
          context,
          AppRoute(
            page: SeriesPatternCarouselView(
              patterns: allPatterns,
              initialIndex: index >= 0 ? index : 0,
            ),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.rest.withOpacity(0.1), width: 1),
          boxShadow: [
            BoxShadow(
              color: AppColors.rest.withOpacity(0.08),
              blurRadius: 20,
              offset: const Offset(0, 8),
              spreadRadius: -4,
            ),
            BoxShadow(
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.transparent
                  : Colors.black.withOpacity(0.03),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
             Row(
               mainAxisAlignment: MainAxisAlignment.spaceBetween,
               children: [
                  Row(
                    children: [
                       Container(
                         padding: const EdgeInsets.all(10),
                         decoration: BoxDecoration(
                            color: AppColors.rest,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.rest.withOpacity(0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                         ),
                         child: const Icon(Icons.repeat, color: Colors.white, size: 20),
                       ),
                       const SizedBox(width: 12),
                       Text(
                          pattern.distanceFormatted,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 20,
                            letterSpacing: -0.5,
                          ),
                       ),
                    ],
                  ),
                  Container(
                     padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                     decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(12),
                     ),
                     child: Text("${pattern.count} veces", style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  )
               ],
             ),
             const SizedBox(height: 12),
             const Divider(),
             const SizedBox(height: 8),
             Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                   _buildMetric(context, "Mejor Tiempo", pattern.bestTimeFormatted, subValue: pattern.bestPaceFormatted),
                   _buildMetric(context, "Tiempo Medio", pattern.averageTimeFormatted, subValue: pattern.averagePaceFormatted),
                ],
             )
          ],
        ),
      ),
    );
  }
}

Widget _buildMetric(BuildContext context, String label, String value, {String? subValue}) {
   return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
         Text(
           label,
           style: TextStyle(
             color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
             fontSize: 11,
             fontWeight: FontWeight.w500,
             letterSpacing: 0.5,
           ),
         ),
         const SizedBox(height: 4),
         Row(
           crossAxisAlignment: CrossAxisAlignment.baseline,
           textBaseline: TextBaseline.alphabetic,
           children: [
             Text(
               value,
               style: const TextStyle(
                 fontWeight: FontWeight.bold,
                 fontSize: 22,
                 letterSpacing: -0.5,
               ),
             ),
             if (subValue != null) ...[
               const SizedBox(width: 8),
               Text(
                 subValue,
                 style: TextStyle(
                   fontSize: 12,
                   color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                   fontWeight: FontWeight.w500,
                 ),
               ),
             ],
           ],
         ),
      ],
   );
}

class WorkoutPatternCard extends StatelessWidget {
  final WorkoutPattern pattern;
  final List<WorkoutPattern> allPatterns;
  const WorkoutPatternCard({super.key, required this.pattern, required this.allPatterns});

  @override
  Widget build(BuildContext context) {
    // Generate a simple name based on structure
    // e.g. "6x400" if mostly uniform, or list distances
    String title = "Entrenamiento Mixto";
    // Simple heuristic: check if mostly uniform distances
    if (pattern.distances.isNotEmpty) {
       title = pattern.patternKey; // The key often contains the structure representation
    }

    return GestureDetector(
      onTap: () {
        final index = allPatterns.indexOf(pattern);
        Navigator.push(
          context,
          AppRoute(
            page: WorkoutPatternCarouselView(
              patterns: allPatterns,
              initialIndex: index >= 0 ? index : 0,
            ),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.brand.withOpacity(0.1), width: 1),
          boxShadow: [
            BoxShadow(
              color: AppColors.brand.withOpacity(0.08),
              blurRadius: 20,
              offset: const Offset(0, 8),
              spreadRadius: -4,
            ),
            BoxShadow(
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.transparent
                  : Colors.black.withOpacity(0.03),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
             Row(
               mainAxisAlignment: MainAxisAlignment.spaceBetween,
               children: [
                  Expanded(
                    child: Row(
                      children: [
                         Container(
                           padding: const EdgeInsets.all(10),
                           decoration: BoxDecoration(
                              color: AppColors.brand,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.brand.withOpacity(0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                           ),
                           child: const Icon(Icons.fitness_center, color: Colors.white, size: 20),
                         ),
                         const SizedBox(width: 12),
                         Expanded(
                           child: Text(
                              title,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                                letterSpacing: -0.5,
                              ),
                              overflow: TextOverflow.ellipsis,
                           ),
                         ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                     padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                     decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(12),
                     ),
                     child: Text("${pattern.count} veces", style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  )
               ],
             ),
             const SizedBox(height: 12),
             Wrap(
               spacing: 8,
               runSpacing: 8,
               children: pattern.distances.take(4).map((d) =>
                  Container(
                     padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                     decoration: BoxDecoration(
                        border: Border.all(color: Theme.of(context).colorScheme.outline.withOpacity(0.2)),
                        borderRadius: BorderRadius.circular(4),
                     ),
                     child: Text("${d}m", style: TextStyle(fontSize: 10, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5))),
                  )
               ).toList(),
             ),
              const SizedBox(height: 8),
              const Divider(),
              const SizedBox(height: 8),
              Row(
                 mainAxisAlignment: MainAxisAlignment.spaceBetween,
                 children: [
                    _buildMetric(context, "Mejor Tiempo Total", pattern.bestTotalTimeFormatted, subValue: pattern.bestPaceFormatted),
                    _buildMetric(context, "Tiempo Medio Total", pattern.averageTotalTimeFormatted, subValue: pattern.averagePaceFormatted),
                 ],
              )
          ],
        ),
      ),
    );
  }
}

