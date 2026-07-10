import 'package:flutter_test/flutter_test.dart';
import 'package:running_laps/features/training/data/entrenamiento.dart';
import 'package:running_laps/features/training/data/serie.dart';
import 'package:running_laps/features/training/data/temporal_data_extractor.dart';

void main() {
  // Puntos GPS en línea recta hacia el norte: cada paso de latitud de 0.0009°
  // son ~100 m. Con 30 s por paso el ritmo es 3.33 m/s (~5:00 /km).
  List<Map<String, dynamic>> straightTrack({
    required int steps,
    required DateTime start,
    double startLat = 40.0,
    int secondsPerStep = 30,
    double latStepDeg = 0.0009,
  }) {
    return List.generate(steps + 1, (i) {
      return <String, dynamic>{
        'latitude': startLat + i * latStepDeg,
        'longitude': -3.7,
        'timestamp':
            start.add(Duration(seconds: i * secondsPerStep)).toIso8601String(),
      };
    });
  }

  group('TemporalDataExtractor.paceFromSerie', () {
    test('devuelve un punto por tramo con pace constante', () {
      final start = DateTime(2026, 7, 1, 10);
      final serie = Serie(
        tiempoSec: 180,
        distanciaM: 600,
        descansoSec: 0,
        rpe: 5,
        gpsPoints: straightTrack(steps: 6, start: start),
      );

      final points = TemporalDataExtractor.paceFromSerie(serie);

      expect(points.length, 6);
      // 100 m en 30 s → 300 s/km aprox (con el redondeo del haversine)
      for (final p in points) {
        expect(p.value, closeTo(300, 5));
      }
      // El eje X es tiempo desde el inicio de la serie
      expect(points.first.tSec, closeTo(30, 0.01));
      expect(points.last.tSec, closeTo(180, 0.01));
    });

    test('sin gpsPoints devuelve lista vacía', () {
      final serie = Serie(
        tiempoSec: 100,
        distanciaM: 500,
        descansoSec: 0,
        rpe: 5,
      );
      expect(TemporalDataExtractor.paceFromSerie(serie), isEmpty);
    });

    test('filtra paces irreales', () {
      final start = DateTime(2026, 7, 1, 10);
      // Paso gigante en 1 s → pace < 120 s/km → filtrado
      final serie = Serie(
        tiempoSec: 1,
        distanciaM: 1000,
        descansoSec: 0,
        rpe: 5,
        gpsPoints: [
          {
            'latitude': 40.0,
            'longitude': -3.7,
            'timestamp': start.toIso8601String(),
          },
          {
            'latitude': 40.01, // ~1.1 km en 1 s
            'longitude': -3.7,
            'timestamp':
                start.add(const Duration(seconds: 1)).toIso8601String(),
          },
        ],
      );
      expect(TemporalDataExtractor.paceFromSerie(serie), isEmpty);
    });
  });

  group('TemporalDataExtractor.sessionPacePerKm', () {
    test(
        'split que cruza el límite entre series usa el tiempo acumulado correcto',
        () {
      // Regresión: antes se restaba serie.tiempoSec del acumulado (que aún no
      // lo incluía), desplazando los splits que cruzan series.
      final start1 = DateTime(2026, 7, 1, 10);
      final serie1 = Serie(
        tiempoSec: 180,
        distanciaM: 600,
        descansoSec: 0,
        rpe: 5,
        gpsPoints: straightTrack(steps: 6, start: start1),
      );
      final start2 = start1.add(const Duration(seconds: 180));
      final serie2 = Serie(
        tiempoSec: 180,
        distanciaM: 600,
        descansoSec: 0,
        rpe: 5,
        gpsPoints: straightTrack(
          steps: 6,
          start: start2,
          startLat: 40.0054, // continúa la traza
        ),
      );

      final e = Entrenamiento(
        titulo: 'Test',
        fecha: DateTime(2026, 7, 1),
        gps: true,
        series: [serie1, serie2],
      );

      final splits = TemporalDataExtractor.sessionPacePerKm(e);

      // 1.2 km totales → exactamente 1 split (el km 1)
      expect(splits.length, 1);
      expect(splits.first.tSec, 1.0); // km número 1
      // El km se cruza ~120 s dentro de la serie 2 → 180 + 120 = ~300 s
      expect(splits.first.value, closeTo(300, 10));
    });

    test('series sin GPS aportan su distancia y tiempo declarados', () {
      final start = DateTime(2026, 7, 1, 10);
      // Serie 1 sin GPS: 600 m en 200 s. Serie 2 con GPS: 600 m en 180 s.
      final serie1 = Serie(
        tiempoSec: 200,
        distanciaM: 600,
        descansoSec: 0,
        rpe: 5,
      );
      final serie2 = Serie(
        tiempoSec: 180,
        distanciaM: 600,
        descansoSec: 0,
        rpe: 5,
        gpsPoints: straightTrack(steps: 6, start: start),
      );

      final e = Entrenamiento(
        titulo: 'Test',
        fecha: DateTime(2026, 7, 1),
        gps: true,
        series: [serie1, serie2],
      );

      final splits = TemporalDataExtractor.sessionPacePerKm(e);

      // El km 1 se cruza ~400 m dentro de la serie 2 (relTime ~120 s)
      // → tiempo total ~200 + 120 = 320 s desde el inicio.
      expect(splits.length, 1);
      expect(splits.first.value, closeTo(320, 10));
    });
  });
}
