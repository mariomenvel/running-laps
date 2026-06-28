import 'package:running_laps/features/training/data/entrenamiento.dart';
import 'package:running_laps/features/training/data/serie.dart';

/// Instancia individual de un entrenamiento dentro del patrón
class WorkoutInstance {
  final String entrenamientoId;
  final Entrenamiento entrenamiento;
  final double averagePace; // Ritmo medio del entrenamiento (sec/km)
  final double consistency; // Desviación estándar de los paces de las series
  final DateTime fecha;

  WorkoutInstance({
    required this.entrenamientoId,
    required this.entrenamiento,
    required this.averagePace,
    required this.consistency,
    required this.fecha,
  });

  /// Mejor serie del entrenamiento (por pace)
  Serie? get bestSerie {
    if (entrenamiento.series.isEmpty) return null;
    return entrenamiento.series.reduce((a, b) {
      final paceA = a.ritmoSecPorKm();
      final paceB = b.ritmoSecPorKm();
      if (paceA == null) return b;
      if (paceB == null) return a;
      return paceA < paceB ? a : b;
    });
  }

  /// Ritmo de la mejor serie
  int? get bestSeriePace => bestSerie?.ritmoSecPorKm();
}

/// Patrón de entrenamientos similares agrupados por estructura
/// Ejemplo: todos los entrenamientos "4x400"
class WorkoutPattern {
  final String patternKey; // "4x400", "6x1000", "400-800-400", etc.
  final int numSeries; // Número de series del patrón
  final List<int> distances; // Estructura: [400, 400, 400, 400]
  final List<WorkoutInstance> instances;

  WorkoutPattern({
    required this.patternKey,
    required this.numSeries,
    required this.distances,
    required this.instances,
  });

  /// Mejor entrenamiento del patrón (por average pace)
  WorkoutInstance? get bestWorkout {
    if (instances.isEmpty) return null;
    return instances.reduce((a, b) => a.averagePace < b.averagePace ? a : b);
  }

  /// Ritmo promedio del patrón
  double get averagePace {
    if (instances.isEmpty) return 0;
    final sum = instances.fold<double>(0, (sum, i) => sum + i.averagePace);
    return sum / instances.length;
  }

  /// Consistencia promedio (menor = más consistente)
  double get averageConsistency {
    if (instances.isEmpty) return 0;
    final sum = instances.fold<double>(0, (sum, i) => sum + i.consistency);
    return sum / instances.length;
  }

  /// Progresión de pace promedio en el tiempo
  List<MapEntry<DateTime, double>> get paceProgression {
    final sorted = List<WorkoutInstance>.from(instances)
      ..sort((a, b) => a.fecha.compareTo(b.fecha));
    return sorted.map((i) => MapEntry(i.fecha, i.averagePace)).toList();
  }

  /// Progresión de mejor serie por entrenamiento
  List<MapEntry<DateTime, int?>> get bestSerieProgression {
    final sorted = List<WorkoutInstance>.from(instances)
      ..sort((a, b) => a.fecha.compareTo(b.fecha));
    return sorted.map((i) => MapEntry(i.fecha, i.bestSeriePace)).toList();
  }

  /// Últimos N entrenamientos
  List<WorkoutInstance> getLastN(int n) {
    final sorted = List<WorkoutInstance>.from(instances)
      ..sort((a, b) => b.fecha.compareTo(a.fecha));
    return sorted.take(n).toList();
  }

  /// Número de instancias
  int get count => instances.length;

  /// Distancia total del patrón (suma de todas las series)
  int get totalDistance => distances.fold<int>(0, (sum, d) => sum + d);

  /// Distancia formateada
  String get totalDistanceFormatted {
    final totalM = totalDistance;
    if (totalM >= 1000) {
      final km = totalM / 1000.0;
      return km % 1 == 0 ? '${km.toInt()}km' : '${km.toStringAsFixed(1)}km';
    }
    return '${totalM}m';
  }

  /// Mejor ritmo formateado
  String get bestPaceFormatted {
    final workout = bestWorkout;
    if (workout == null) return '-';
    final secKm = workout.averagePace.round();
    final mm = secKm ~/ 60;
    final ss = secKm % 60;
    final ss2 = ss < 10 ? '0$ss' : '$ss';
    return '$mm:$ss2 /km';
  }

  /// Ritmo promedio formateado
  String get averagePaceFormatted {
    if (instances.isEmpty) return '-';
    final secKm = averagePace.round();
    final mm = secKm ~/ 60;
    final ss = secKm % 60;
    final ss2 = ss < 10 ? '0$ss' : '$ss';
    return '$mm:$ss2 /km';
  }

  /// Mejor tiempo total de entrenamiento (suma de tiempos de series)
  String get bestTotalTimeFormatted {
    final workout = bestWorkout;
    if (workout == null) return '-';
    final totalSec = workout.entrenamiento.tiempoTotalSec();
    return formatDuration(totalSec);
  }

  /// Tiempo total promedio
  String get averageTotalTimeFormatted {
    if (instances.isEmpty) return '-';
    final sum = instances.fold<double>(0, (sum, i) => sum + i.entrenamiento.tiempoTotalSec());
    final avg = sum / instances.length;
    return formatDuration(avg);
  }

  static String formatDuration(double totalSeconds) {
    final int h = totalSeconds ~/ 3600;
    final int m = (totalSeconds % 3600) ~/ 60;
    final int s = (totalSeconds % 60).toInt();
    
    if (h > 0) {
      return '$h:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  /// Descripción del patrón (ej: "4 series de 400m")
  String get description {
    if (distances.isEmpty) return patternKey;
    
    // Caso simple: todas las series iguales
    if (distances.toSet().length == 1) {
      final distM = distances[0];
      final distStr = distM >= 1000 
          ? '${(distM / 1000.0).toStringAsFixed(distM % 1000 == 0 ? 0 : 1)}km'
          : '${distM}m';
      return '$numSeries series de $distStr';
    }
    
    // Caso mixto
    return patternKey;
  }

  /// ¿Es un patrón simple? (todas las series iguales)
  bool get isSimplePattern => distances.toSet().length == 1;

  /// Mejora porcentual (si hay al menos 2 entrenamientos)
  /// Compara el último con el promedio de los 3 anteriores
  double? get improvementPercentage {
    if (instances.length < 2) return null;
    
    final sorted = List<WorkoutInstance>.from(instances)
      ..sort((a, b) => a.fecha.compareTo(b.fecha));
    
    final last = sorted.last.averagePace;
    final previous = sorted.reversed.skip(1).take(3).toList();
    
    if (previous.isEmpty) return null;
    
    final avgPrevious = previous.fold<double>(0, (sum, i) => sum + i.averagePace) / previous.length;
    
    // Mejora = pace más bajo (mejor)
    // % = ((anterior - actual) / anterior) * 100
    return ((avgPrevious - last) / avgPrevious) * 100;
  }
}

/// Genera la clave de patrón para un entrenamiento
String generateWorkoutPatternKey(Entrenamiento entrenamiento) {
  if (entrenamiento.series.isEmpty) return 'empty';
  
  // Agrupar series consecutivas con misma distancia
  final groups = <int, int>{};
  int? lastDistance;
  
  for (var serie in entrenamiento.series) {
    final dist = serie.distanciaM;
    if (dist == lastDistance || lastDistance == null) {
      groups[dist] = (groups[dist] ?? 0) + 1;
      lastDistance = dist;
    } else {
      // Cambio de distancia, patrón mixto
      lastDistance = null;
      break;
    }
  }
  
  // Caso simple: todas las series iguales
  if (lastDistance != null && groups.length == 1) {
    final dist = groups.keys.first;
    final count = groups[dist]!;
    return '${count}x$dist';
  }
  
  // Caso mixto: unir distancias con guiones
  final pattern = entrenamiento.series.map((s) => s.distanciaM).join('-');
  
  // Si es muy largo, simplificar
  if (pattern.length > 30) {
    return 'mixed-${entrenamiento.series.length}series';
  }
  
  return pattern;
}

/// Calcula la desviación estándar de los paces de un entrenamiento
double calculatePaceConsistency(Entrenamiento entrenamiento) {
  if (entrenamiento.series.length < 2) return 0;
  
  final paces = <int>[];
  for (var serie in entrenamiento.series) {
    final pace = serie.ritmoSecPorKm();
    if (pace == null) {
      // Ignorar series sin distancia válida
      continue;
    }
    paces.add(pace);
  }
  
  if (paces.length < 2) return 0;
  
  // Media
  final mean = paces.fold<int>(0, (sum, p) => sum + p) / paces.length;
  
  // Varianza
  final variance = paces.fold<double>(0, (sum, p) => sum + (p - mean) * (p - mean)) / paces.length;
  
  // Desviación estándar
  return variance > 0 ? variance : 0; // sqrt en UI si se necesita
}

