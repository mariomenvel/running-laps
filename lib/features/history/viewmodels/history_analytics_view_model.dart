import 'package:flutter/material.dart';
import 'package:running_laps/features/training/data/entrenamiento.dart';

class HistoryAnalyticsViewModel {
  final List<Entrenamiento> trainings;
  final Color Function(String?) colorProvider;

  HistoryAnalyticsViewModel(this.trainings, this.colorProvider);

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

   // 5. DISTANCIA SEMANAL
  Map<int, double> getWeeklyDistance({int weeks = 7}) {
    final Map<int, double> weeklyDist = {};
    for (int i = 0; i < weeks; i++) {
      weeklyDist[i] = 0.0;
    }
    
    final now = DateTime.now();

    for (var t in trainings) {
      final daysDiff = now.difference(t.fecha).inDays;
      if (daysDiff < 0) continue; 

      final wIndex = (daysDiff / 7).floor();
      
      if (wIndex >= 0 && wIndex < weeks) {
         weeklyDist[wIndex] = (weeklyDist[wIndex] ?? 0) + (t.distanciaTotalM() / 1000.0);
      }
    }
    return weeklyDist;
  }

  // 6. TENDENCIA RITMO
  List<Map<String, dynamic>> getPaceTrend() {
    // Sort by date ascending
    final sorted = List<Entrenamiento>.from(trainings)..sort((a,b) => a.fecha.compareTo(b.fecha));
    
    return sorted.map((t) {
      final pace = t.ritmoMedioSecPorKm() ?? 0;

      return {
        'date': t.fecha,
        'paceSeconds': pace,
      };
    }).toList();
  }
  
  // 7. DISTANCIAS FRECUENTES (Series)
  List<int> getMostFrequentSeriesDistances() {
     final Map<int, int> counts = {};
     for(var t in trainings) {
       // Considerar distancia total si es rodaje continuo (1 sola serie) o series individuales
       // Para ser más útil en chips, usaremos series individuales.
       for(var s in t.series) {
         if (s.distanciaM > 0) {
           counts[s.distanciaM] = (counts[s.distanciaM] ?? 0) + 1;
         }
       }
     }
     
     final sortedKeys = counts.keys.toList()..sort((a,b) => counts[b]!.compareTo(counts[a]!));
     return sortedKeys.take(5).toList();
  }

  // 8. SIGNATURES (Tags)
  List<String> getMostFrequentSignatures() {
      final Map<String, int> counts = {};
      
      for(var t in trainings) {
        if (t.tags != null && t.tags!.isNotEmpty) {
           for(var tag in t.tags!) {
             counts[tag] = (counts[tag] ?? 0) + 1;
           }
        }
      }
       
     final sortedKeys = counts.keys.toList()..sort((a,b) => counts[b]!.compareTo(counts[a]!));
     return sortedKeys.take(5).toList();
  }
}

