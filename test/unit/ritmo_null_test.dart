import 'package:flutter_test/flutter_test.dart';
import 'package:running_laps/features/training/data/entrenamiento.dart';
import 'package:running_laps/features/training/data/serie.dart';

// Regresión: entrenamientos/series sin distancia (GPS desactivado o fallo de
// GPS) rompían el historial con un StateError al llamar a ritmoMedioSecPorKm()
// / ritmoSecPorKm(). Ahora devuelven null en vez de lanzar excepción.
void main() {
  group('Serie.ritmoSecPorKm', () {
    test('devuelve null si distanciaM es 0', () {
      final serie = Serie(
        distanciaM: 0,
        tiempoSec: 120,
        rpe: 5,
        descansoSec: 60,
      );

      expect(serie.ritmoSecPorKm(), isNull);
    });

    test('devuelve el ritmo calculado si distanciaM > 0', () {
      final serie = Serie(
        distanciaM: 1000,
        tiempoSec: 300,
        rpe: 5,
        descansoSec: 60,
      );

      expect(serie.ritmoSecPorKm(), 300);
    });

    test('ritmoTexto() devuelve "--:--" si no hay distancia', () {
      final serie = Serie(
        distanciaM: 0,
        tiempoSec: 120,
        rpe: 5,
        descansoSec: 60,
      );

      expect(serie.ritmoTexto(), '--:--');
    });
  });

  group('Entrenamiento.ritmoMedioSecPorKm', () {
    test('devuelve null si no hay distancia total', () {
      final entrenamiento = Entrenamiento(
        titulo: 'Sin GPS',
        fecha: DateTime.now(),
        gps: false,
        series: [
          Serie(distanciaM: 0, tiempoSec: 120, rpe: 5, descansoSec: 60),
        ],
      );

      expect(entrenamiento.ritmoMedioSecPorKm(), isNull);
    });

    test('devuelve el ritmo calculado si hay distancia total', () {
      final entrenamiento = Entrenamiento(
        titulo: 'Con GPS',
        fecha: DateTime.now(),
        gps: true,
        series: [
          Serie(distanciaM: 1000, tiempoSec: 300, rpe: 5, descansoSec: 60),
        ],
      );

      expect(entrenamiento.ritmoMedioSecPorKm(), 300);
    });

    test('ritmoMedioTexto() devuelve "--:--" si no hay distancia', () {
      final entrenamiento = Entrenamiento(
        titulo: 'Sin GPS',
        fecha: DateTime.now(),
        gps: false,
        series: [
          Serie(distanciaM: 0, tiempoSec: 120, rpe: 5, descansoSec: 60),
        ],
      );

      expect(entrenamiento.ritmoMedioTexto(), '--:--');
    });

    test('toMap() no lanza excepción sin distancia y guarda ritmoMedioSecKm null', () {
      final entrenamiento = Entrenamiento(
        titulo: 'Sin GPS',
        fecha: DateTime.now(),
        gps: false,
        series: [
          Serie(distanciaM: 0, tiempoSec: 120, rpe: 5, descansoSec: 60),
        ],
      );

      final map = entrenamiento.toMap();

      expect(map['ritmoMedioSecKm'], isNull);
    });
  });
}
