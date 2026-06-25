import 'package:flutter_test/flutter_test.dart';
import 'package:running_laps/features/ai_coach/data/pb_detector.dart';
import 'package:running_laps/features/ai_coach/data/ai_coach_models.dart';

void main() {
  group('PbDetector', () {
    late AiCoachProfile emptyProfile;

    setUp(() {
      emptyProfile = _profileWithPbs();
    });

    group('detect', () {
      test('5K exacto sin PB previo devuelve resultado', () {
        final result = PbDetector.detect(
          distanceM: 5000,
          timeSeconds: 1500,
          profile: emptyProfile,
        );
        expect(result, isNotNull);
        expect(result!.field, 'pb5k');
        expect(result.seconds, 1500);
      });

      test('5K dentro del ±3% se detecta y el tiempo se ajusta', () {
        // 4900m está dentro del 3% de 5000m (lower = 4850)
        final result = PbDetector.detect(
          distanceM: 4900,
          timeSeconds: 1470,
          profile: emptyProfile,
        );
        expect(result, isNotNull);
        expect(result!.field, 'pb5k');
        // Tiempo ajustado a 5000m: 1470 * 5000/4900 ≈ 1500
        expect(result.seconds, closeTo(1500, 30));
      });

      test('distancia fuera del ±3% no se detecta', () {
        // 4700m está a 6% de 5000m → fuera del rango
        final result = PbDetector.detect(
          distanceM: 4700,
          timeSeconds: 1410,
          profile: emptyProfile,
        );
        expect(result, isNull);
      });

      test('no detecta si no mejora el PB existente', () {
        final profileWithPb = _profileWithPbs(pb5k: 1400);
        final result = PbDetector.detect(
          distanceM: 5000,
          timeSeconds: 1500, // más lento que 1400s
          profile: profileWithPb,
        );
        expect(result, isNull);
      });

      test('sí detecta si mejora el PB existente', () {
        final profileWithPb = _profileWithPbs(pb5k: 1500);
        final result = PbDetector.detect(
          distanceM: 5000,
          timeSeconds: 1450,
          profile: profileWithPb,
        );
        expect(result, isNotNull);
        expect(result!.seconds, 1450);
      });

      test('10K se detecta correctamente', () {
        final result = PbDetector.detect(
          distanceM: 10000,
          timeSeconds: 2700,
          profile: emptyProfile,
        );
        expect(result, isNotNull);
        expect(result!.field, 'pb10k');
      });
    });

    group('format', () {
      test('formato MM:SS correcto', () {
        expect(PbDetector.format(1530), '25:30');
        expect(PbDetector.format(600), '10:00');
      });

      test('formato H:MM:SS cuando hay horas', () {
        expect(PbDetector.format(3600), '1:00:00');
      });
    });
  });
}

AiCoachProfile _profileWithPbs({int? pb5k, int? pb10k}) {
  return AiCoachProfile(
    uid: 'test',
    goal: AiCoachGoalType.race5k,
    goalDescription: '',
    level: AiCoachAthleteLevel.beginner,
    preferredWeeklySessions: 3,
    createdAt: DateTime(2025),
    updatedAt: DateTime(2025),
    pb5kSeconds: pb5k,
    pb10kSeconds: pb10k,
  );
}
