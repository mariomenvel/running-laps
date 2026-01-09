import 'package:running_laps/features/training/data/serie.dart';

/// Instancia individual de una serie dentro del patrón
class SerieInstance {
  final String entrenamientoId;
  final String entrenamientoTitulo;
  final int serieIndex; // Índice dentro del entrenamiento (0-based)
  final Serie serie;
  final DateTime fecha;
  final int paceSecKm;
  final double rpe;

  SerieInstance({
    required this.entrenamientoId,
    required this.entrenamientoTitulo,
    required this.serieIndex,
    required this.serie,
    required this.fecha,
    required this.paceSecKm,
    required this.rpe,
  });
}

/// Patrón de series similares agrupadas por distancia
/// Ejemplo: todas las series de 400m a través de distintos entrenamientos
class SeriesPattern {
  final int distanceM; // Distancia del patrón (400, 800, 1000, etc.)
  final List<SerieInstance> instances;

  SeriesPattern({
    required this.distanceM,
    required this.instances,
  });

  /// Mejor pace de todas las series del patrón
  int get bestPaceSecKm {
    if (instances.isEmpty) return 0;
    return instances.map((i) => i.paceSecKm).reduce((a, b) => a < b ? a : b);
  }

  /// Pace promedio de todas las series
  double get averagePaceSecKm {
    if (instances.isEmpty) return 0;
    final sum = instances.fold<int>(0, (sum, i) => sum + i.paceSecKm);
    return sum / instances.length;
  }

  /// RPE promedio
  double get averageRPE {
    if (instances.isEmpty) return 0;
    final sum = instances.fold<double>(0, (sum, i) => sum + i.rpe);
    return sum / instances.length;
  }

  /// Progresión de pace en el tiempo (para gráfica de línea)
  /// Retorna lista ordenada por fecha
  List<MapEntry<DateTime, int>> get paceProgression {
    final sorted = List<SerieInstance>.from(instances)
      ..sort((a, b) => a.fecha.compareTo(b.fecha));
    return sorted.map((i) => MapEntry(i.fecha, i.paceSecKm)).toList();
  }

  /// Últimas N series
  List<SerieInstance> getLastN(int n) {
    final sorted = List<SerieInstance>.from(instances)
      ..sort((a, b) => b.fecha.compareTo(a.fecha));
    return sorted.take(n).toList();
  }

  /// Mejor serie (por pace)
  SerieInstance? get bestInstance {
    if (instances.isEmpty) return null;
    return instances.reduce((a, b) => a.paceSecKm < b.paceSecKm ? a : b);
  }

  /// Distancia formateada (ej: "400m", "1km")
  String get distanceFormatted {
    if (distanceM >= 1000) {
      final km = distanceM / 1000.0;
      return km % 1 == 0 ? '${km.toInt()}km' : '${km}km';
    }
    return '${distanceM}m';
  }

  /// Ritmo formateado del mejor
  String get bestPaceFormatted {
    if (instances.isEmpty) return '-';
    final secKm = bestPaceSecKm;
    final mm = secKm ~/ 60;
    final ss = secKm % 60;
    final ss2 = ss < 10 ? '0$ss' : '$ss';
    return '$mm:$ss2 /km';
  }

  /// Ritmo promedio formateado
  String get averagePaceFormatted {
    if (instances.isEmpty) return '-';
    final secKm = averagePaceSecKm.round();
    final mm = secKm ~/ 60;
    final ss = secKm % 60;
    final ss2 = ss < 10 ? '0$ss' : '$ss';
    return '$mm:$ss2 /km';
  }

  /// Mejor tiempo formateado de todas las series del patrón
  String get bestTimeFormatted {
    if (instances.isEmpty) return '-';
    final bestTime = instances.map((i) => i.serie.tiempoSec).reduce((a, b) => a < b ? a : b);
    return formatDuration(bestTime);
  }

  /// Tiempo promedio formateado
  String get averageTimeFormatted {
    if (instances.isEmpty) return '-';
    final sum = instances.fold<double>(0, (sum, i) => sum + i.serie.tiempoSec);
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

  /// Número de instancias
  int get count => instances.length;

  /// Número de entrenamientos únicos
  int get uniqueWorkoutsCount {
    final uniqueIds = <String>{};
    for (var instance in instances) {
      uniqueIds.add(instance.entrenamientoId);
    }
    return uniqueIds.length;
  }

  /// Distribución de paces para histograma
  /// Retorna mapa: pace bucket (en segundos) -> count
  Map<int, int> getPaceDistribution({int bucketSizeSeconds = 10}) {
    final distribution = <int, int>{};
    
    for (var instance in instances) {
      // Redondear al bucket más cercano
      final bucket = (instance.paceSecKm / bucketSizeSeconds).round() * bucketSizeSeconds;
      distribution[bucket] = (distribution[bucket] ?? 0) + 1;
    }
    
    return Map.fromEntries(
      distribution.entries.toList()..sort((a, b) => a.key.compareTo(b.key))
    );
  }
}

