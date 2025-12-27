import 'package:flutter_test/flutter_test.dart';
import 'package:running_laps/features/analytics/data/pattern_detector.dart';
import 'package:running_laps/features/training/data/entrenamiento.dart';
import 'package:running_laps/features/training/data/serie.dart';
import 'package:running_laps/features/analytics/data/series_pattern.dart';
import 'package:running_laps/features/analytics/data/workout_pattern.dart';

void main() {
  late PatternDetector detector;

  setUp(() {
    detector = PatternDetector();
  });

  group('PatternDetector - Series Patterns', () {
    test('Should group exact distances together', () {
      final entrenamientos = [
        _createEntrenamiento([400, 400, 400]),
        _createEntrenamiento([400, 400]),
        _createEntrenamiento([800, 800]),
      ];

      final patterns = detector.detectSeriesPatterns(entrenamientos, useGpsTolerance: false);

      expect(patterns.length, 2);
      
      final p400 = patterns.firstWhere((p) => p.distanceM == 400);
      expect(p400.instances.length, 5); // 3 + 2

      final p800 = patterns.firstWhere((p) => p.distanceM == 800);
      expect(p800.instances.length, 2);
    });

    test('Should group similar distances with GPS tolerance (5%)', () {
      final entrenamientos = [
        _createEntrenamiento([400]),
        _createEntrenamiento([405]), // +1.25%
        _createEntrenamiento([390]), // -2.5%
        _createEntrenamiento([425]), // +6.25% (Should be separate if base is 400? or handled by tolerance logic)
      ];

      // Note: Logic depends on which comes first or how base is determined.
      // Usually defaults to the first encountered as base.
      
      final patterns = detector.detectSeriesPatterns(entrenamientos, useGpsTolerance: true);

      // 400, 405 (1.25%), 390 (2.5%) should group.
      // 425 is > 400 * 1.05 (420), so it should be separate.
      
      final p400 = patterns.firstWhere((p) => p.distanceM == 400);
      expect(p400.instances.length, 3); // 400, 405, 390

      final p425 = patterns.firstWhere((p) => p.distanceM == 425);
      expect(p425.instances.length, 1);
    });

    test('Should ignore 0m series', () {
       final entrenamientos = [
        _createEntrenamiento([0, 400]),
      ];
      final patterns = detector.detectSeriesPatterns(entrenamientos);
      expect(patterns.length, 1);
      expect(patterns.first.distanceM, 400);
      expect(patterns.first.instances.length, 1);
    });
  });

  group('PatternDetector - Workout Patterns', () {
    test('Should detect simple patterns (e.g. 4x400)', () {
       final entrenamientos = [
        _createEntrenamiento([400, 400, 400, 400]), // 4x400
        _createEntrenamiento([400, 400, 400, 400]), // 4x400
        _createEntrenamiento([1000, 1000]),         // 2x1000
      ];

      final patterns = detector.detectWorkoutPatterns(entrenamientos);

      expect(patterns.length, 2);
      
      final p4x400 = patterns.firstWhere((p) => p.patternKey == '4x400');
      expect(p4x400.count, 2);

      final p2x1000 = patterns.firstWhere((p) => p.patternKey == '2x1000');
      expect(p2x1000.count, 1);
    });

    test('Should detect mixed patterns', () {
      final entrenamientos = [
        _createEntrenamiento([400, 800, 400]),
        _createEntrenamiento([400, 800, 400]),
      ];

      final patterns = detector.detectWorkoutPatterns(entrenamientos);

      expect(patterns.length, 1);
      expect(patterns.first.patternKey, '400-800-400');
      expect(patterns.first.count, 2);
    });
  });
}

// Helper to create dummy Entrenamiento
Entrenamiento _createEntrenamiento(List<int> distances) {
  return Entrenamiento(
    id: 'test_${DateTime.now().microsecondsSinceEpoch}',
    titulo: 'Test Workout',
    fecha: DateTime.now(),
    gps: true,
    series: distances.map((d) => Serie(
      distanciaM: d,
      tiempoSec: d * 0.3, // Dummy random pace
      rpe: 5,
      descansoSec: 60,
    )).toList(),
  );
}
