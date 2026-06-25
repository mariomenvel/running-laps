import 'package:flutter_test/flutter_test.dart';
import 'package:running_laps/features/ai_coach/data/vdot_calculator.dart';
import 'package:running_laps/features/ai_coach/data/ai_coach_models.dart';

void main() {
  group('VdotCalculator', () {
    group('estimateVdot', () {
      test('5K en 20:00 da VDOT ~53', () {
        final vdot = VdotCalculator.estimateVdot(
          distanceM: 5000,
          timeSeconds: 1200,
        );
        expect(vdot, isNotNull);
        expect(vdot!, inInclusiveRange(47.0, 56.0));
      });

      test('5K en 25:00 da VDOT ~38-42', () {
        final vdot = VdotCalculator.estimateVdot(
          distanceM: 5000,
          timeSeconds: 1500,
        );
        expect(vdot, isNotNull);
        expect(vdot!, inInclusiveRange(36.0, 45.0));
      });

      test('10K en 45:00 da VDOT similar a 5K en ~22:20', () {
        final vdot10k = VdotCalculator.estimateVdot(
          distanceM: 10000,
          timeSeconds: 2700,
        );
        final vdot5k = VdotCalculator.estimateVdot(
          distanceM: 5000,
          timeSeconds: 1340,
        );
        expect(vdot10k, isNotNull);
        expect(vdot5k, isNotNull);
        expect((vdot10k! - vdot5k!).abs(), lessThan(3.0));
      });

      test('parámetros inválidos devuelven null', () {
        expect(
          VdotCalculator.estimateVdot(distanceM: 0, timeSeconds: 1200),
          isNull,
        );
        expect(
          VdotCalculator.estimateVdot(distanceM: 5000, timeSeconds: 0),
          isNull,
        );
      });

      test('VDOT siempre entre 30 y 85', () {
        final slow = VdotCalculator.estimateVdot(
          distanceM: 5000,
          timeSeconds: 2700, // 45 min
        );
        final fast = VdotCalculator.estimateVdot(
          distanceM: 5000,
          timeSeconds: 780, // 13 min
        );
        expect(slow!, greaterThanOrEqualTo(30.0));
        expect(fast!, lessThanOrEqualTo(85.0));
      });
    });

    group('pacesFromVdot', () {
      test('Z4 más rápido que Z3, Z3 más rápido que Z2, Z2 más rápido que Z1', () {
        final paces = VdotCalculator.pacesFromVdot(50.0);
        expect(paces, isNotNull);
        expect(paces!.z4MinSecPerKm, lessThan(paces.z3MinSecPerKm));
        expect(paces.z3MinSecPerKm, lessThan(paces.z2MinSecPerKm));
        expect(paces.z2MinSecPerKm, lessThan(paces.z1MinSecPerKm));
      });

      test('paces razonables para VDOT 50 (5K ~20:30)', () {
        final paces = VdotCalculator.pacesFromVdot(50.0);
        expect(paces, isNotNull);
        // Z3 tempo: 4:00–5:00 /km
        expect(paces!.z3MinSecPerKm, inInclusiveRange(240, 300));
        // Z4 intervalo: 3:30–4:20 /km
        expect(paces.z4MinSecPerKm, inInclusiveRange(210, 260));
      });
    });

    group('bestVdotFromProfile', () {
      test('sin marcas devuelve null', () {
        final profile = _profileWithPbs();
        expect(VdotCalculator.bestVdotFromProfile(profile), isNull);
      });

      test('con una sola marca devuelve su VDOT', () {
        final profile = _profileWithPbs(pb5k: 1500); // 25 min
        final vdot = VdotCalculator.bestVdotFromProfile(profile);
        expect(vdot, isNotNull);
        expect(vdot!, inInclusiveRange(36.0, 45.0));
      });

      test('media de varias marcas coherente', () {
        final profile = _profileWithPbs(
          pb5k: 1200,  // 20 min → VDOT ~50
          pb10k: 2520, // 42 min → VDOT ~50
        );
        final vdot = VdotCalculator.bestVdotFromProfile(profile);
        expect(vdot, isNotNull);
        expect(vdot!, inInclusiveRange(47.0, 56.0));
      });
    });
  });
}

AiCoachProfile _profileWithPbs({
  int? pb5k,
  int? pb10k,
  int? pbHalfMarathon,
  int? pbMarathon,
}) {
  return AiCoachProfile(
    uid: 'test-uid',
    goal: AiCoachGoalType.race10k,
    goalDescription: 'test',
    level: AiCoachAthleteLevel.intermediate,
    preferredWeeklySessions: 3,
    createdAt: DateTime(2025),
    updatedAt: DateTime(2025),
    pb5kSeconds: pb5k,
    pb10kSeconds: pb10k,
    pbHalfMarathonSeconds: pbHalfMarathon,
    pbMarathonSeconds: pbMarathon,
  );
}
