import 'package:flutter_test/flutter_test.dart';
import 'package:running_laps/core/services/gps_service.dart';
import 'package:running_laps/features/training/services/training_analysis_service.dart';

void main() {
  // Traza recta hacia el norte: 0.0009° ≈ 100 m por paso.
  List<GpsPoint> straightTrack({
    required int steps,
    int secondsPerStep = 30,
    DateTime? start,
  }) {
    final t0 = start ?? DateTime(2026, 7, 1, 10);
    return List.generate(steps + 1, (i) {
      return GpsPoint(
        latitude: 40.0 + i * 0.0009,
        longitude: -3.7,
        timestamp: t0.add(Duration(seconds: i * secondsPerStep)),
      );
    });
  }

  group('TrainingAnalysisService.calculateBestSplits', () {
    test('lista vacía devuelve resultado vacío', () {
      final result = TrainingAnalysisService.calculateBestSplits([]);
      expect(result.bestSplits, isEmpty);
    });

    test('recorrido de 1.2 km produce el mejor split de 1 km', () {
      final points = straightTrack(steps: 12); // ~1200 m en 360 s
      final result = TrainingAnalysisService.calculateBestSplits(points);

      expect(result.bestSplits.containsKey(1), isTrue);
      expect(result.bestSplits.containsKey(2), isFalse);
      // 1 km a ~3.33 m/s → ~300 s (la ventana puede pasarse un punto)
      expect(result.bestSplits[1]!.timeSeconds, closeTo(300, 31));
    });

    test('detecta el tramo rápido como mejor split', () {
      final t0 = DateTime(2026, 7, 1, 10);
      // Primeros 10 pasos lentos (40 s por 100 m), luego 10 rápidos (25 s).
      final points = <GpsPoint>[];
      var elapsed = 0;
      for (var i = 0; i <= 20; i++) {
        points.add(GpsPoint(
          latitude: 40.0 + i * 0.0009,
          longitude: -3.7,
          timestamp: t0.add(Duration(seconds: elapsed)),
        ));
        elapsed += i < 10 ? 40 : 25;
      }

      final result = TrainingAnalysisService.calculateBestSplits(points);
      final best1k = result.bestSplits[1];

      expect(best1k, isNotNull);
      // El mejor km debe salir del tramo rápido: ~10 × 25 s = 250 s
      expect(best1k!.timeSeconds, lessThan(300));
      // Y su inicio debe estar dentro del tramo rápido o su borde
      expect(
        best1k.startTime.isAfter(t0.add(const Duration(seconds: 359))),
        isTrue,
      );
    });

    test('no muta la lista de entrada', () {
      final ordered = straightTrack(steps: 12);
      final shuffled = [ordered[3], ordered[0], ordered[7], ordered[1]];
      final copy = List<GpsPoint>.of(shuffled);

      TrainingAnalysisService.calculateBestSplits(shuffled);

      for (var i = 0; i < copy.length; i++) {
        expect(identical(shuffled[i], copy[i]), isTrue,
            reason: 'el orden original del caller no debe cambiar');
      }
    });
  });
}
