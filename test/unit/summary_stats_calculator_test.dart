import 'package:flutter_test/flutter_test.dart';
import 'package:running_laps/features/templates/data/workout_session.dart';
import 'package:running_laps/features/training/data/entrenamiento.dart';
import 'package:running_laps/features/training/data/serie.dart';
import 'package:running_laps/features/training/data/summary_stats_calculator.dart';

void main() {
  Serie makeSerie({
    required int distanciaM,
    required double tiempoSec,
    double rpe = 5,
    double? fcMedia,
  }) {
    return Serie(
      tiempoSec: tiempoSec,
      distanciaM: distanciaM,
      descansoSec: 60,
      rpe: rpe,
      fcMedia: fcMedia,
    );
  }

  Entrenamiento makeEntrenamiento({
    required List<Serie> series,
    Map<String, dynamic>? plannedComparison,
    double? fcMediaSesion,
  }) {
    return Entrenamiento(
      titulo: 'Test',
      fecha: DateTime(2026, 7, 1),
      gps: false,
      series: series,
      plannedComparison: plannedComparison,
      fcMediaSesion: fcMediaSesion,
    );
  }

  group('SummaryStatsCalculator.common', () {
    test('agrega distancia, tiempo, pace y RPE', () {
      final e = makeEntrenamiento(series: [
        makeSerie(distanciaM: 1000, tiempoSec: 300, rpe: 6),
        makeSerie(distanciaM: 1000, tiempoSec: 240, rpe: 8),
      ]);
      final calc = SummaryStatsCalculator(
        entrenamiento: e,
        type: WorkoutType.intervals,
      );
      final c = calc.common();
      expect(c.totalDistanceM, 2000);
      expect(c.totalDuration, const Duration(seconds: 540));
      expect(c.avgPaceSecPerKm, closeTo(270, 0.01)); // 540s / 2km
      expect(c.avgRpe, closeTo(7, 0.01));
    });

    test('sin distancia: pace nulo, sin series: rpe nulo', () {
      final e = makeEntrenamiento(series: []);
      final calc = SummaryStatsCalculator(
        entrenamiento: e,
        type: WorkoutType.free,
      );
      final c = calc.common();
      expect(c.avgPaceSecPerKm, isNull);
      expect(c.avgRpe, isNull);
    });
  });

  group('SummaryStatsCalculator.intervalStats', () {
    test('detecta la mejor serie por pace', () {
      final e = makeEntrenamiento(series: [
        makeSerie(distanciaM: 400, tiempoSec: 96), // 4:00 /km
        makeSerie(distanciaM: 400, tiempoSec: 88), // 3:40 /km ← mejor
        makeSerie(distanciaM: 400, tiempoSec: 100), // 4:10 /km
      ]);
      final stats = SummaryStatsCalculator(
        entrenamiento: e,
        type: WorkoutType.intervals,
      ).intervalStats();

      expect(stats.totalSeries, 3);
      expect(stats.bestSerieIndex, 1);
      expect(stats.bestSeriePace, closeTo(220, 0.01)); // 88 / 0.4
    });

    test('consistencia usa desviación estándar (no varianza)', () {
      // Paces: 300 y 320 → media 310, varianza 100, stdDev 10.
      // CV = 10/310*100 ≈ 3.23%. Con el bug (varianza directa) daría ≈32.3%.
      final e = makeEntrenamiento(series: [
        makeSerie(distanciaM: 1000, tiempoSec: 300),
        makeSerie(distanciaM: 1000, tiempoSec: 320),
      ]);
      final stats = SummaryStatsCalculator(
        entrenamiento: e,
        type: WorkoutType.intervals,
      ).intervalStats();

      expect(stats.consistencyPctVariation, isNotNull);
      expect(stats.consistencyPctVariation!, closeTo(3.226, 0.01));
    });

    test('series idénticas → variación 0%', () {
      final e = makeEntrenamiento(series: [
        makeSerie(distanciaM: 500, tiempoSec: 150),
        makeSerie(distanciaM: 500, tiempoSec: 150),
      ]);
      final stats = SummaryStatsCalculator(
        entrenamiento: e,
        type: WorkoutType.intervals,
      ).intervalStats();
      expect(stats.consistencyPctVariation, closeTo(0, 0.0001));
    });

    test('vacío devuelve IntervalStats.empty', () {
      final e = makeEntrenamiento(series: []);
      final stats = SummaryStatsCalculator(
        entrenamiento: e,
        type: WorkoutType.intervals,
      ).intervalStats();
      expect(stats.totalSeries, 0);
      expect(stats.bestSerieIndex, isNull);
    });
  });

  group('SummaryStatsCalculator con plannedComparison', () {
    Map<String, dynamic> plannedWithWarmup() => {
          'blocks': [
            {
              'role': 'warmup',
              'plannedReps': 1,
              'segments': [
                {'type': 'interval'},
              ],
            },
            {
              'role': 'main',
              'plannedReps': 2,
              'segments': [
                {
                  'type': 'interval',
                  'target': {'paceMinSecPerKm': 240, 'paceMaxSecPerKm': 260},
                },
                {'type': 'recovery'}, // sin target — no debe desalinear
              ],
            },
          ],
        };

    test('_mainSeries salta el calentamiento', () {
      final e = makeEntrenamiento(
        series: [
          makeSerie(distanciaM: 1000, tiempoSec: 400), // warmup
          makeSerie(distanciaM: 1000, tiempoSec: 250), // main 1 interval
          makeSerie(distanciaM: 200, tiempoSec: 90), // main 1 recovery
          makeSerie(distanciaM: 1000, tiempoSec: 245), // main 2 interval
          makeSerie(distanciaM: 200, tiempoSec: 90), // main 2 recovery
        ],
        plannedComparison: plannedWithWarmup(),
      );
      final stats = SummaryStatsCalculator(
        entrenamiento: e,
        type: WorkoutType.intervals,
      ).intervalStats();

      // main = 2 reps × 2 segments = 4 series (sin el warmup)
      expect(stats.totalSeries, 4);
    });

    test(
        'percentInTarget alinea índices aunque haya segmentos sin objetivo',
        () {
      // Serie 0 (warmup, sin target), series main: interval en target,
      // recovery sin target, interval en target, recovery sin target.
      final e = makeEntrenamiento(
        series: [
          makeSerie(distanciaM: 1000, tiempoSec: 400), // warmup
          makeSerie(distanciaM: 1000, tiempoSec: 250), // en target (240-260)
          makeSerie(distanciaM: 200, tiempoSec: 90),
          makeSerie(distanciaM: 1000, tiempoSec: 300), // fuera de target
          makeSerie(distanciaM: 200, tiempoSec: 90),
        ],
        plannedComparison: plannedWithWarmup(),
      );
      final stats = SummaryStatsCalculator(
        entrenamiento: e,
        type: WorkoutType.intervals,
      ).intervalStats();

      // 2 segmentos con target, 1 dentro (250 ∈ [235, 265] con margen ±5)
      expect(stats.percentInTarget, closeTo(50, 0.01));
    });
  });

  group('SummaryStatsCalculator.fartlekStats / hillsStats', () {
    test('fartlek alterna rápido/suave por posición', () {
      final e = makeEntrenamiento(series: [
        makeSerie(distanciaM: 400, tiempoSec: 90, fcMedia: 170),
        makeSerie(distanciaM: 400, tiempoSec: 150, fcMedia: 140),
        makeSerie(distanciaM: 400, tiempoSec: 92, fcMedia: 172),
      ]);
      final stats = SummaryStatsCalculator(
        entrenamiento: e,
        type: WorkoutType.fartlek,
      ).fartlekStats();

      expect(stats.fastSegmentsCount, 2);
      expect(stats.slowSegmentsCount, 1);
      expect(stats.avgFcFast, closeTo(171, 0.01));
      expect(stats.avgFcSlow, closeTo(140, 0.01));
    });

    test('hills agrega tiempo de subida y FC media', () {
      final e = makeEntrenamiento(series: [
        makeSerie(distanciaM: 200, tiempoSec: 60, fcMedia: 160),
        makeSerie(distanciaM: 200, tiempoSec: 62, fcMedia: 164),
      ]);
      final stats = SummaryStatsCalculator(
        entrenamiento: e,
        type: WorkoutType.hills,
      ).hillsStats();

      expect(stats.totalClimbs, 2);
      expect(stats.totalClimbingTime, const Duration(seconds: 122));
      expect(stats.avgFcClimbs, closeTo(162, 0.01));
      expect(stats.peakFc, isNull); // sin fcReadings no hay pico
    });
  });
}
