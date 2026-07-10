import 'dart:math' as math;

import 'package:running_laps/features/templates/data/workout_session.dart';
import 'entrenamiento.dart';
import 'serie.dart';

/// Calcula stats específicos de cada tipo de sesión para mostrar
/// en el summary. Cada tipo tiene métricas diferentes destacadas.
class SummaryStatsCalculator {
  final Entrenamiento entrenamiento;
  final WorkoutType type;

  const SummaryStatsCalculator({
    required this.entrenamiento,
    required this.type,
  });

  List<Serie> get _mainSeries {
    final pc = entrenamiento.plannedComparison;
    if (pc == null) return entrenamiento.series;

    final blocks = pc['blocks'] as List? ?? [];
    int currentIndex = 0;

    for (final block in blocks) {
      final role = block['role'] as String?;
      final reps = (block['plannedReps'] as num?)?.toInt() ?? 1;
      final segments = (block['segments'] as List?)?.length ?? 1;
      final totalForBlock = reps * segments;

      if (role == 'main') {
        return entrenamiento.series
            .skip(currentIndex)
            .take(totalForBlock)
            .toList();
      }

      currentIndex += totalForBlock;
    }

    return entrenamiento.series;
  }

  /// Stats comunes a todos los tipos
  CommonStats common() {
    final totalDistanceM = entrenamiento.series
        .fold<int>(0, (sum, s) => sum + s.distanciaM);
    final totalTimeSec = entrenamiento.series
        .fold<double>(0, (sum, s) => sum + s.tiempoSec);
    final avgPaceSecPerKm = totalDistanceM > 0
        ? (totalTimeSec / (totalDistanceM / 1000))
        : null;
    final avgRpe = entrenamiento.series.isNotEmpty
        ? entrenamiento.series
            .map((s) => s.rpe)
            .reduce((a, b) => a + b) / entrenamiento.series.length
        : null;
    return CommonStats(
      totalDistanceM: totalDistanceM.toDouble(),
      totalDuration: Duration(milliseconds: (totalTimeSec * 1000).round()),
      avgPaceSecPerKm: avgPaceSecPerKm,
      avgRpe: avgRpe,
      avgFc: entrenamiento.fcMediaSesion,
    );
  }

  /// Stats específicos para SERIES
  IntervalStats intervalStats() {
    final series = _mainSeries;
    if (series.isEmpty) return IntervalStats.empty();

    // Mejor serie (menor pace)
    Serie? bestSerie;
    double? bestPace;
    for (final s in series) {
      if (s.distanciaM == 0) continue;
      final pace = s.tiempoSec / (s.distanciaM / 1000);
      if (bestPace == null || pace < bestPace) {
        bestPace = pace;
        bestSerie = s;
      }
    }

    // Consistencia: desviación estándar de paces
    final paces = series
        .where((s) => s.distanciaM > 0)
        .map((s) => s.tiempoSec / (s.distanciaM / 1000))
        .toList();
    double? consistencyPctVariation;
    if (paces.length > 1) {
      final mean = paces.reduce((a, b) => a + b) / paces.length;
      final variance = paces
          .map((p) => (p - mean) * (p - mean))
          .reduce((a, b) => a + b) / paces.length;
      final stdDev = variance > 0 ? math.sqrt(variance) : 0.0;
      consistencyPctVariation = mean > 0 ? (stdDev / mean) * 100 : null;
    }

    // % de series en objetivo (si hay plannedComparison)
    final percentInTarget = _calculateInTargetPercent();

    return IntervalStats(
      totalSeries: series.length,
      bestSerieIndex: bestSerie != null ? series.indexOf(bestSerie) : null,
      bestSeriePace: bestPace,
      consistencyPctVariation: consistencyPctVariation,
      percentInTarget: percentInTarget,
    );
  }

  /// Stats específicos para CONTINUO/RODAJE
  ContinuousStats continuousStats() {
    final c = common();
    return ContinuousStats(
      distanceKm: c.totalDistanceM / 1000,
      duration: c.totalDuration,
      avgPaceSecPerKm: c.avgPaceSecPerKm,
      avgFc: c.avgFc,
      percentInTargetZone: _calculatePercentInTargetZone(),
    );
  }

  /// Stats específicos para FARTLEK
  FartlekStats fartlekStats() {
    // Asume series alternadas: pares = rápido, impares = suave
    // (o usa el target.zone para distinguir)
    final fastSegments = <Serie>[];
    final slowSegments = <Serie>[];

    final mainSeries = _mainSeries;
    for (var i = 0; i < mainSeries.length; i++) {
      final s = mainSeries[i];
      // Heurística simple: alternancia por posición
      if (i.isEven) {
        fastSegments.add(s);
      } else {
        slowSegments.add(s);
      }
    }

    double? avgFc(List<Serie> segments) {
      final fcs = segments
          .map((s) => s.fcMedia)
          .where((fc) => fc != null)
          .cast<double>()
          .toList();
      if (fcs.isEmpty) return null;
      return fcs.reduce((a, b) => a + b) / fcs.length;
    }

    return FartlekStats(
      fastSegmentsCount: fastSegments.length,
      slowSegmentsCount: slowSegments.length,
      avgFcFast: avgFc(fastSegments),
      avgFcSlow: avgFc(slowSegments),
    );
  }

  /// Stats específicos para CUESTAS
  HillsStats hillsStats() {
    final climbs = _mainSeries;
    int fcPeak = 0;
    int fcSumClimbs = 0;
    int fcCountClimbs = 0;
    int totalClimbingTimeSec = 0;

    for (final s in climbs) {
      totalClimbingTimeSec += s.tiempoSec.round();
      if (s.fcMedia != null) {
        fcSumClimbs += s.fcMedia!.round();
        fcCountClimbs++;
      }
      // Buscar pico en lecturas
      if (s.fcReadings != null) {
        for (final r in s.fcReadings!) {
          if (r.bpm > fcPeak) fcPeak = r.bpm;
        }
      }
    }

    return HillsStats(
      totalClimbs: climbs.length,
      totalClimbingTime: Duration(seconds: totalClimbingTimeSec),
      avgFcClimbs: fcCountClimbs > 0 ? fcSumClimbs / fcCountClimbs : null,
      peakFc: fcPeak > 0 ? fcPeak : null,
    );
  }

  /// Stats específicos para COMPETICIÓN
  CompetitionStats competitionStats() {
    final c = common();
    // Parciales por kilómetro (split de la única serie)
    final List<KmSplit> splits = [];
    if (entrenamiento.series.isNotEmpty) {
      final s = entrenamiento.series.first;
      if (s.gpsPoints != null && s.gpsPoints!.isNotEmpty) {
        splits.addAll(_calculateKmSplits(s));
      }
    }
    return CompetitionStats(
      totalDistanceKm: c.totalDistanceM / 1000,
      finishTime: c.totalDuration,
      avgPaceSecPerKm: c.avgPaceSecPerKm,
      kmSplits: splits,
      // TODO: comparar con plannedComparison para detectar marca personal
      isNewPersonalBest: null,
    );
  }

  /// Stats específicos para LIBRE (solo lo esencial)
  FreeStats freeStats() {
    final c = common();
    return FreeStats(
      distanceKm: c.totalDistanceM / 1000,
      duration: c.totalDuration,
      avgPaceSecPerKm: c.avgPaceSecPerKm,
      avgFc: c.avgFc,
    );
  }

  // ─── Helpers privados ───

  double? _calculateInTargetPercent() {
    final pc = entrenamiento.plannedComparison;
    if (pc == null) return null;
    final blocks = pc['blocks'] as List?;
    if (blocks == null) return null;

    int total = 0;
    int inTarget = 0;

    int serieIdx = 0;
    for (final block in blocks) {
      final reps = (block['plannedReps'] as num?)?.toInt() ?? 1;
      final segments = block['segments'] as List? ?? [];

      // Cada segmento ejecutado produce una serie (mismo mapeo que _mainSeries),
      // tenga o no objetivo de ritmo — el índice avanza siempre.
      for (var r = 0; r < reps; r++) {
        for (final seg in segments) {
          if (serieIdx >= entrenamiento.series.length) break;
          final target = seg['target'] as Map?;
          if (target?['paceMinSecPerKm'] != null) {
            total++;
            final serie = entrenamiento.series[serieIdx];
            if (serie.distanciaM > 0) {
              final pace = serie.tiempoSec / (serie.distanciaM / 1000);
              final tMin = (target!['paceMinSecPerKm'] as num).toDouble();
              final tMax = (target['paceMaxSecPerKm'] as num?)?.toDouble() ?? tMin + 15;
              if (pace >= tMin - 5 && pace <= tMax + 5) inTarget++;
            }
          }
          serieIdx++;
        }
      }
    }

    return total > 0 ? (inTarget / total) * 100 : null;
  }

  double? _calculatePercentInTargetZone() {
    // TODO: requiere lecturas FC tiempo a tiempo + zona objetivo
    return null;
  }

  List<KmSplit> _calculateKmSplits(Serie serie) {
    // TODO: parsear gpsPoints y agrupar por kilómetro
    return [];
  }
}

// ─── Data classes ───

class CommonStats {
  final double totalDistanceM;
  final Duration totalDuration;
  final double? avgPaceSecPerKm;
  final double? avgRpe;
  final double? avgFc;

  const CommonStats({
    required this.totalDistanceM,
    required this.totalDuration,
    this.avgPaceSecPerKm,
    this.avgRpe,
    this.avgFc,
  });
}

class IntervalStats {
  final int totalSeries;
  final int? bestSerieIndex;
  final double? bestSeriePace;
  final double? consistencyPctVariation;
  final double? percentInTarget;

  const IntervalStats({
    required this.totalSeries,
    this.bestSerieIndex,
    this.bestSeriePace,
    this.consistencyPctVariation,
    this.percentInTarget,
  });

  factory IntervalStats.empty() => const IntervalStats(totalSeries: 0);
}

class ContinuousStats {
  final double distanceKm;
  final Duration duration;
  final double? avgPaceSecPerKm;
  final double? avgFc;
  final double? percentInTargetZone;

  const ContinuousStats({
    required this.distanceKm,
    required this.duration,
    this.avgPaceSecPerKm,
    this.avgFc,
    this.percentInTargetZone,
  });
}

class FartlekStats {
  final int fastSegmentsCount;
  final int slowSegmentsCount;
  final double? avgFcFast;
  final double? avgFcSlow;

  const FartlekStats({
    required this.fastSegmentsCount,
    required this.slowSegmentsCount,
    this.avgFcFast,
    this.avgFcSlow,
  });
}

class HillsStats {
  final int totalClimbs;
  final Duration totalClimbingTime;
  final double? avgFcClimbs;
  final int? peakFc;

  const HillsStats({
    required this.totalClimbs,
    required this.totalClimbingTime,
    this.avgFcClimbs,
    this.peakFc,
  });
}

class CompetitionStats {
  final double totalDistanceKm;
  final Duration finishTime;
  final double? avgPaceSecPerKm;
  final List<KmSplit> kmSplits;
  final bool? isNewPersonalBest;

  const CompetitionStats({
    required this.totalDistanceKm,
    required this.finishTime,
    required this.kmSplits,
    this.avgPaceSecPerKm,
    this.isNewPersonalBest,
  });
}

class KmSplit {
  final int kmNumber;
  final double paceSecPerKm;

  const KmSplit({required this.kmNumber, required this.paceSecPerKm});
}

class FreeStats {
  final double distanceKm;
  final Duration duration;
  final double? avgPaceSecPerKm;
  final double? avgFc;

  const FreeStats({
    required this.distanceKm,
    required this.duration,
    this.avgPaceSecPerKm,
    this.avgFc,
  });
}
