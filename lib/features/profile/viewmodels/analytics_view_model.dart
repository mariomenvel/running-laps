import 'package:flutter/material.dart';
import 'package:running_laps/features/training/data/entrenamiento.dart';

class AnalyticsViewModel {
  final List<Entrenamiento> trainings;
  final Color Function(String?) colorProvider;

  AnalyticsViewModel(this.trainings, this.colorProvider);

  // 1. DISTRIBUCIÓN POR TAGS (para Pie Chart)
  Map<String, int> get trainingsByTag {
    final Map<String, int> counts = {};
    int untagged = 0;

    for (var t in trainings) {
      if (t.tags == null || t.tags!.isEmpty) {
        untagged++;
        continue;
      }
      
      // Si tiene múltiples tags, podemos contar uno principal o todos. 
      // Para simplificar, contaremos cada aparición de tag.
      // Ojo: esto significa que la suma total > número de entrenos.
      // Si queremos un PieChart que sume 100%, deberíamos priorizar el primer tag o tener categoría "Múltiples".
      // Vamos a priorizar el PRIMER tag como "categoría principal".
      final mainTag = t.tags!.first;
      counts[mainTag] = (counts[mainTag] ?? 0) + 1;
    }

    if (untagged > 0) {
      counts['Sin etiqueta'] = untagged;
    }

    return counts;
  }

  // 2. DISTANCIA POR TAG (para Bar Chart)
  Map<String, double> get distanceByTag {
    final Map<String, double> dists = {};
    double untaggedDist = 0;

    for (var t in trainings) {
      final double km = t.distanciaTotalM() / 1000.0;
      
      if (t.tags == null || t.tags!.isEmpty) {
        untaggedDist += km;
        continue;
      }

      // Sumamos al primer tag
      final mainTag = t.tags!.first;
      dists[mainTag] = (dists[mainTag] ?? 0) + km;
    }

    if (untaggedDist > 0) {
      dists['Sin etiqueta'] = untaggedDist;
    }

    return dists;
  }

  // 3. TAG MÁS USADO
  String get mostFrequentTag {
    final counts = trainingsByTag;
    if (counts.isEmpty) return '-';
    
    var maxKey = '-';
    var maxVal = -1;
    
    counts.forEach((k, v) {
      if (v > maxVal) {
        maxVal = v;
        maxKey = k;
      }
    });

    return '$maxKey ($maxVal)';
  }

   // 4. KM TOTALES
   double get totalKm {
     return trainings.fold(0.0, (sum, t) => sum + (t.distanciaTotalM() / 1000.0));
   }
}
