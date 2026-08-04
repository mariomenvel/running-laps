import 'package:flutter_test/flutter_test.dart';
import 'package:running_laps/features/training/data/session_plausibility.dart';

/// El caso que originó esto: un "Rodaje 45 min" que quedó registrado con
/// 17 h 06 m y 0,0 km porque el cronómetro siguió corriendo. Ese tiempo entra
/// en el volumen semanal, el TRIMP y el contexto del Coach IA.
///
/// Lo que más importa proteger aquí no son los positivos, sino los **falsos
/// positivos**: acusar de error a alguien que de verdad hizo una tirada larga
/// es peor que dejar pasar una sesión rara.
void main() {
  ImplausibleSession? check(double durationSec, int distanceM) =>
      SessionPlausibility.check(
        durationSec: durationSec,
        distanceM: distanceM,
      );

  group('sesiones normales que NO se deben marcar', () {
    test('un rodaje de 45 min a 5:30/km', () {
      expect(check(45 * 60, 8180), isNull);
    });

    test('series: poca distancia, poco tiempo', () {
      expect(check(43 * 60, 5900), isNull);
    });

    test('una maraton lenta de 5 h', () {
      expect(check(5 * 3600, 42195), isNull);
    });

    test('un ultra de 8 h', () {
      // Duro pero real: no se le puede decir a esta persona que se equivoco.
      expect(check(8 * 3600, 60000), isNull);
    });

    test('una caminata larga y lenta de 2 h a 12 min/km', () {
      expect(check(2 * 3600, 10000), isNull);
    });

    test('un calentamiento corto de 10 min sin GPS', () {
      // Sin distancia pero breve: pudo entrenar en cinta o sin permiso de GPS.
      expect(check(10 * 60, 0), isNull);
    });

    test('25 min parado tampoco salta todavia', () {
      expect(check(25 * 60, 0), isNull);
    });
  });

  group('el cronometro se quedo corriendo', () {
    test('el caso real: 17h 06m y 0 km', () {
      final r = check(17 * 3600 + 6 * 60, 0);
      expect(r, isNotNull);
      expect(r!.reason, ImplausibleReason.duracionExcesiva);
      expect(r.message, contains('17h 6min'));
    });

    test('mucho tiempo sin moverse del sitio', () {
      final r = check(90 * 60, 50);
      expect(r, isNotNull);
      expect(r!.reason, ImplausibleReason.sinDistancia);
    });

    test('ritmo mas lento que caminar sostenido una hora', () {
      // 2 km en 2 h = 60 min/km.
      final r = check(2 * 3600, 2000);
      expect(r, isNotNull);
      expect(r!.reason, ImplausibleReason.ritmoImposible);
    });

    test('mas de 9 h siempre salta, aunque haya distancia', () {
      final r = check(10 * 3600, 50000);
      expect(r, isNotNull);
      expect(r!.reason, ImplausibleReason.duracionExcesiva);
    });
  });

  group('bordes', () {
    test('duracion cero o negativa no se juzga', () {
      expect(check(0, 0), isNull);
      expect(check(-5, 1000), isNull);
    });

    test('justo en el umbral de duracion no salta', () {
      expect(check(9 * 3600, 40000), isNull);
      expect(check(9 * 3600 + 1, 40000), isNotNull);
    });

    test('el mensaje siempre es legible para una persona', () {
      final r = check(17 * 3600 + 6 * 60, 0);
      expect(r!.message, isNot(contains('null')));
      expect(r.message.endsWith('?'), isTrue);
    });
  });
}
