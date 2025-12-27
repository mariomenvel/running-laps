import 'package:running_laps/features/training/data/entrenamiento.dart';
import 'package:running_laps/features/analytics/data/series_pattern.dart';
import 'package:running_laps/features/analytics/data/workout_pattern.dart';

/// Servicio para detectar patrones en entrenamientos
/// Agrupa series y entrenamientos similares para análisis
class PatternDetector {
  /// Tolerancia para distancias GPS (5%)
  static const double gpsTolerance = 0.05;

  /// Detecta patrones de series similares
  /// 
  /// Agrupa todas las series por distancia, con opción de tolerancia GPS
  /// Retorna lista de SeriesPattern ordenada por distancia
  List<SeriesPattern> detectSeriesPatterns(
    List<Entrenamiento> entrenamientos, {
    bool useGpsTolerance = true,
  }) {
    if (entrenamientos.isEmpty) return [];

    // Mapa: distanciaBase -> lista de instancias
    final Map<int, List<SerieInstance>> grouped = {};

    for (var entreno in entrenamientos) {
      for (int i = 0; i < entreno.series.length; i++) {
        final serie = entreno.series[i];
        
        // Validar que la serie tiene datos válidos
        if (serie.distanciaM <= 0) continue;
        
        int? paceSecKm;
        try {
          paceSecKm = serie.ritmoSecPorKm();
        } catch (e) {
          // Serie sin distancia válida para calcular ritmo
          continue;
        }

        // Determinar distancia base para agrupar
        final int baseDistance = _getBaseDistance(
          serie.distanciaM,
          grouped.keys.toList(),
          useGpsTolerance: useGpsTolerance,
        );

        // Crear instancia
        final instance = SerieInstance(
          entrenamientoId: entreno.id ?? '',
          entrenamientoTitulo: entreno.titulo,
          serieIndex: i,
          serie: serie,
          fecha: entreno.fecha,
          paceSecKm: paceSecKm,
          rpe: serie.rpe,
        );

        // Agregar al grupo
        grouped.putIfAbsent(baseDistance, () => []);
        grouped[baseDistance]!.add(instance);
      }
    }

    // Convertir a SeriesPattern y ordenar por distancia
    final patterns = grouped.entries
        .map((entry) => SeriesPattern(
              distanceM: entry.key,
              instances: entry.value,
            ))
        .toList()
      ..sort((a, b) => a.distanceM.compareTo(b.distanceM));

    return patterns;
  }

  /// Determina la distancia base para agrupar una serie
  /// Si useGpsTolerance = true, busca si existe un grupo dentro del 5%
  int _getBaseDistance(
    int distanceM,
    List<int> existingDistances,
    {bool useGpsTolerance = true}
  ) {
    if (!useGpsTolerance || existingDistances.isEmpty) {
      return distanceM;
    }

    // Buscar si existe un grupo compatible (dentro del 5%)
    for (var baseDistance in existingDistances) {
      final lowerBound = baseDistance * (1 - gpsTolerance);
      final upperBound = baseDistance * (1 + gpsTolerance);
      
      if (distanceM >= lowerBound && distanceM <= upperBound) {
        return baseDistance; // Agregar a este grupo existente
      }
    }

    // No hay grupo compatible, crear nuevo con esta distancia
    return distanceM;
  }

  /// Detecta patrones de entrenamientos similares
  /// 
  /// Agrupa entrenamientos por estructura (ej: 4x400, 6x1000)
  /// Retorna lista de WorkoutPattern ordenada por frecuencia (más común primero)
  List<WorkoutPattern> detectWorkoutPatterns(
    List<Entrenamiento> entrenamientos
  ) {
    if (entrenamientos.isEmpty) return [];

    // Mapa: patternKey -> lista de instancias
    final Map<String, List<WorkoutInstance>> grouped = {};

    for (var entreno in entrenamientos) {
      // Generar clave del patrón
      final patternKey = generateWorkoutPatternKey(entreno);
      
      // Calcular métricas del entrenamiento
      double averagePace;
      try {
        averagePace = entreno.ritmoMedioSecPorKm().toDouble();
      } catch (e) {
        // Entrenamiento sin distancia válida
        continue;
      }

      final consistency = calculatePaceConsistency(entreno);

      // Crear instancia
      final instance = WorkoutInstance(
        entrenamientoId: entreno.id ?? '',
        entrenamiento: entreno,
        averagePace: averagePace,
        consistency: consistency,
        fecha: entreno.fecha,
      );

      // Agregar al grupo
      grouped.putIfAbsent(patternKey, () => []);
      grouped[patternKey]!.add(instance);
    }

    // Convertir a WorkoutPattern
    final patterns = <WorkoutPattern>[];
    
    for (var entry in grouped.entries) {
      final instances = entry.value;
      if (instances.isEmpty) continue;

      // Tomar el primer entrenamiento como referencia para estructura
      final reference = instances.first.entrenamiento;
      
      patterns.add(WorkoutPattern(
        patternKey: entry.key,
        numSeries: reference.series.length,
        distances: reference.series.map((s) => s.distanciaM).toList(),
        instances: instances,
      ));
    }

    // Ordenar por frecuencia (más común primero) y luego por distancia total
    patterns.sort((a, b) {
      // Primero por número de instancias
      final countCompare = b.count.compareTo(a.count);
      if (countCompare != 0) return countCompare;
      
      // Luego por distancia total
      return a.totalDistance.compareTo(b.totalDistance);
    });

    return patterns;
  }

  /// Obtiene las distancias más comunes en los entrenamientos
  /// 
  /// Útil para sugerir al usuario qué patrones de series explorar
  /// Retorna lista ordenada de distancias (de más a menos común)
  List<int> getCommonDistances(
    List<Entrenamiento> entrenamientos,
    {int minOccurrences = 3}
  ) {
    final patterns = detectSeriesPatterns(entrenamientos, useGpsTolerance: true);
    
    return patterns
        .where((p) => p.count >= minOccurrences)
        .map((p) => p.distanceM)
        .toList();
  }

  /// Obtiene los patrones de entrenamiento más comunes
  /// 
  /// Retorna lista de pattern keys ordenada por frecuencia
  List<String> getCommonWorkoutPatterns(
    List<Entrenamiento> entrenamientos,
    {int minOccurrences = 2}
  ) {
    final patterns = detectWorkoutPatterns(entrenamientos);
    
    return patterns
        .where((p) => p.count >= minOccurrences)
        .map((p) => p.patternKey)
        .toList();
  }

  /// Filtra patrones de series que cumplen criterios mínimos
  /// 
  /// Útil para no mostrar patrones con muy pocas instancias
  List<SeriesPattern> filterMinimumInstances(
    List<SeriesPattern> patterns,
    {int minInstances = 3}
  ) {
    return patterns.where((p) => p.count >= minInstances).toList();
  }

  /// Filtra patrones de entrenamientos que cumplen criterios mínimos
  List<WorkoutPattern> filterMinimumWorkouts(
    List<WorkoutPattern> patterns,
    {int minWorkouts = 2}
  ) {
    return patterns.where((p) => p.count >= minWorkouts).toList();
  }

  /// Estadísticas generales de patrones detectados
  PatternStats getPatternStats(List<Entrenamiento> entrenamientos) {
    final seriesPatterns = detectSeriesPatterns(entrenamientos);
    final workoutPatterns = detectWorkoutPatterns(entrenamientos);

    return PatternStats(
      totalEntrenamientos: entrenamientos.length,
      uniqueSeriesPatterns: seriesPatterns.length,
      uniqueWorkoutPatterns: workoutPatterns.length,
      mostCommonSeriesDistance: seriesPatterns.isNotEmpty 
          ? seriesPatterns.first.distanceM 
          : null,
      mostCommonWorkoutPattern: workoutPatterns.isNotEmpty 
          ? workoutPatterns.first.patternKey 
          : null,
    );
  }
}

/// Estadísticas generales de patrones
class PatternStats {
  final int totalEntrenamientos;
  final int uniqueSeriesPatterns;
  final int uniqueWorkoutPatterns;
  final int? mostCommonSeriesDistance;
  final String? mostCommonWorkoutPattern;

  PatternStats({
    required this.totalEntrenamientos,
    required this.uniqueSeriesPatterns,
    required this.uniqueWorkoutPatterns,
    this.mostCommonSeriesDistance,
    this.mostCommonWorkoutPattern,
  });
}
