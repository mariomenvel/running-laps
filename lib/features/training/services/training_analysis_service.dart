import 'dart:math';
import 'package:running_laps/core/services/gps_service.dart';

class AnalysisResult {
  final Map<int, SplitResult> bestSplits;

  AnalysisResult({required this.bestSplits});

  Map<String, dynamic> toMap() {
    return {
      'bestSplits': bestSplits.map((k, v) => MapEntry(k.toString(), v.toMap())),
    };
  }

  factory AnalysisResult.fromMap(Map<String, dynamic> map) {
    if (map['bestSplits'] == null) return AnalysisResult(bestSplits: {});
    final rawSplits = map['bestSplits'] as Map<String, dynamic>;
    final splits = rawSplits.map((k, v) =>
        MapEntry(int.parse(k), SplitResult.fromMap(v as Map<String, dynamic>)));
    return AnalysisResult(bestSplits: splits);
  }
}

class SplitResult {
  final int distanceMeters;
  final double timeSeconds;
  final DateTime startTime;

  SplitResult({
    required this.distanceMeters,
    required this.timeSeconds,
    required this.startTime,
  });

  Map<String, dynamic> toMap() {
    return {
      'distanceMeters': distanceMeters,
      'timeSeconds': timeSeconds,
      'startTime': startTime.toIso8601String(),
    };
  }

  factory SplitResult.fromMap(Map<String, dynamic> map) {
    return SplitResult(
      distanceMeters: map['distanceMeters'] as int,
      timeSeconds: (map['timeSeconds'] as num).toDouble(),
      startTime: DateTime.parse(map['startTime']),
    );
  }
}

class TrainingAnalysisService {
  /// Calcula los mejores tiempos para distancias estándar (1km, 2km, etc.)
  /// usando una ventana deslizante sobre los puntos GPS.
  static AnalysisResult calculateBestSplits(List<GpsPoint> points) {
    if (points.isEmpty) return AnalysisResult(bestSplits: {});

    // Ordenar por tiempo (por si acaso vienen desordenados)
    points.sort((a, b) => a.timestamp.compareTo(b.timestamp));

    // Determinar distancia total y posibles "floors"
    // Calcular distancias acumuladas
    final List<double> distAcc = [0.0];
    final List<double> timeAcc = [0.0]; // segundos desde inicio
    DateTime start = points.first.timestamp;

    for (int i = 0; i < points.length - 1; i++) {
      final d = _distanceBetween(
        points[i].latitude,
        points[i].longitude,
        points[i + 1].latitude,
        points[i + 1].longitude,
      );
      distAcc.add(distAcc.last + d);
      final t = points[i + 1].timestamp.difference(start).inMilliseconds / 1000.0;
      timeAcc.add(t);
    }

    final double totalDist = distAcc.last;
    final int maxKm = (totalDist / 1000).floor();
    final Map<int, SplitResult> bestSplits = {};

    // Para cada K km (1, 2, ... maxKm)
    for (int k = 1; k <= maxKm; k++) {
      final int targetMeters = k * 1000;
      SplitResult? best = _findBestSplit(points, distAcc, timeAcc, targetMeters);
      if (best != null) {
        bestSplits[k] = best;
      }
    }

    return AnalysisResult(bestSplits: bestSplits);
  }

  static SplitResult? _findBestSplit(
      List<GpsPoint> points,
      List<double> distAcc,
      List<double> timeAcc,
      int targetMeters) {
    
    double minTime = double.infinity;
    int? bestStartIndex;

    // Ventana deslizante eficiente
    // Avanzamos 'start' e intentamos encontrar 'end' tal que dist(start, end) >= target
    
    int end = 0;
    for (int start = 0; start < points.length; start++) {
      // Avanzar end hasta cubrir distancia
      while (end < points.length && (distAcc[end] - distAcc[start]) < targetMeters) {
        end++;
      }

      if (end >= points.length) break; // No hay más segmentos posibles

      // Tenemos un segmento válido [start, end]
      // Ajuste fino: el punto 'end' puede pasarse un poco
      // (distAcc[end] - distAcc[start]) >= targetMeters
      
      // Calculamos tiempo
      final double duration = timeAcc[end] - timeAcc[start];
      
      // Si queremos ser muy precisos, podríamos interpolar, pero MVP: no interpolación.
      
      if (duration < minTime) {
        minTime = duration;
        bestStartIndex = start;
      }
    }

    if (bestStartIndex != null) {
      return SplitResult(
        distanceMeters: targetMeters,
        timeSeconds: minTime,
        startTime: points[bestStartIndex].timestamp,
      );
    }
    return null;
  }

  // Haversine simple
  static double _distanceBetween(double lat1, double lon1, double lat2, double lon2) {
    const p = 0.017453292519943295;
    const c = cos;
    final a = 0.5 -
        c((lat2 - lat1) * p) / 2 +
        c(lat1 * p) * c(lat2 * p) * (1 - c((lon2 - lon1) * p)) / 2;
    return 12742 * asin(sqrt(a)) * 1000; // Metros
  }
}
