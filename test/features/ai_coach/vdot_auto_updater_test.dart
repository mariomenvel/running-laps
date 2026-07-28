import 'package:flutter_test/flutter_test.dart';
import 'package:running_laps/features/ai_coach/data/ai_coach_models.dart';
import 'package:running_laps/features/ai_coach/data/vdot_auto_updater.dart';
import 'package:running_laps/features/ai_coach/data/vdot_calculator.dart';

/// VDOT que se mantiene al día solo.
///
/// Hasta ahora los ritmos objetivo solo cambiaban si el atleta metía una marca
/// nueva a mano: alguien que mejoraba durante meses seguía entrenando con los
/// ritmos del día que se registró.
void main() {
  const updater = VdotAutoUpdater();

  AiCoachProfile profileWith({
    int? pb5k,
    int? pb10k,
    int? pbMarathon,
  }) =>
      AiCoachProfile(
        uid: 'u1',
        goal: AiCoachGoalType.improveEndurance,
        goalDescription: 'test',
        level: AiCoachAthleteLevel.intermediate,
        preferredWeeklySessions: 4,
        pb5kSeconds: pb5k,
        pb10kSeconds: pb10k,
        pbMarathonSeconds: pbMarathon,
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      );

  AiCoachTrainingSummary quality({
    String category = 'tempo',
    required double compliance,
    bool? harder,
    bool? easier,
  }) =>
      AiCoachTrainingSummary(
        trainingId: 't-$category-$compliance-$harder',
        date: DateTime(2026, 7, 21),
        title: 'Sesion',
        category: category,
        distanceKm: 10,
        durationMinutes: 50,
        paceCompliancePercent: compliance,
        wasHarderThanExpected: harder,
        wasEasierThanExpected: easier,
      );

  group('semilla desde el perfil', () {
    test('usa el mejor VDOT, no la media', () {
      // 5K en 20:00 (VDOT alto) junto a un maratón flojo de 4h30.
      final profile = profileWith(pb5k: 1200, pbMarathon: 16200);
      final best = VdotCalculator.bestVdotFromProfile(profile)!;
      final only5k =
          VdotCalculator.estimateVdot(distanceM: 5000, timeSeconds: 1200)!;
      final onlyMarathon =
          VdotCalculator.estimateVdot(distanceM: 42195, timeSeconds: 16200)!;

      expect(best, closeTo(only5k, 0.01));
      expect(best, greaterThan(onlyMarathon));
      // La media habría quedado por debajo del 5K y dejado ritmos blandos.
      expect(best, greaterThan((only5k + onlyMarathon) / 2));
    });

    test('sin marcas no hay semilla', () {
      expect(VdotCalculator.bestVdotFromProfile(profileWith()), isNull);
    });
  });

  group('sube cuando el atleta va por delante', () {
    test('tres sesiones batiendo el ritmo sin sufrir suben el VDOT', () {
      final update = updater.review(
        currentVdot: 50,
        profile: null,
        recentSessions: [
          quality(compliance: 104),
          quality(category: 'series_largas', compliance: 103),
          quality(category: 'series_cortas', compliance: 105),
        ],
      );
      expect(update, isNotNull);
      expect(update!.improved, isTrue);
      expect(update.vdot, greaterThan(50));
      expect(update.source, VdotSource.trainingEvidence);
    });

    test('dos sesiones buenas no bastan — hace falta evidencia', () {
      final update = updater.review(
        currentVdot: 50,
        profile: null,
        recentSessions: [
          quality(compliance: 104),
          quality(category: 'series_largas', compliance: 103),
        ],
      );
      expect(update, isNull);
    });

    test('batir el ritmo sufriendo no cuenta como mejora', () {
      final update = updater.review(
        currentVdot: 50,
        profile: null,
        recentSessions: [
          quality(compliance: 104, harder: true),
          quality(category: 'series_largas', compliance: 103, harder: true),
          quality(category: 'series_cortas', compliance: 104, harder: true),
        ],
      );
      expect(update?.improved, isNot(true));
    });
  });

  group('baja cuando se queda corto', () {
    test('dos sesiones cortas bastan para bajar — la asimetría es a propósito',
        () {
      final update = updater.review(
        currentVdot: 50,
        profile: null,
        recentSessions: [
          quality(compliance: 88),
          quality(category: 'series_largas', compliance: 86),
        ],
      );
      expect(update, isNotNull);
      expect(update!.vdot, lessThan(50));
      expect(update.reason, contains('corto'));
    });

    test('una marca vieja inflada se corrige sola con el entrenamiento real',
        () {
      // Semilla optimista de un PB antiguo.
      var vdot = 60.0;
      for (var week = 0; week < 4; week++) {
        final update = updater.review(
          currentVdot: vdot,
          profile: null,
          recentSessions: [
            quality(compliance: 85, harder: true),
            quality(category: 'series_largas', compliance: 87, harder: true),
          ],
        );
        if (update != null) vdot = update.vdot;
      }
      expect(vdot, lessThan(59));
    });
  });

  group('estabilidad', () {
    test('ejecutar en el objetivo no mueve nada', () {
      final update = updater.review(
        currentVdot: 50,
        profile: null,
        recentSessions: [
          quality(compliance: 99),
          quality(category: 'series_largas', compliance: 98),
          quality(category: 'series_cortas', compliance: 100),
        ],
      );
      expect(update, isNull);
    });

    test('los rodajes suaves no cuentan como evidencia de calidad', () {
      final update = updater.review(
        currentVdot: 50,
        profile: null,
        recentSessions: [
          quality(category: 'rodaje_base', compliance: 130),
          quality(category: 'rodaje_base', compliance: 125),
          quality(category: 'rodaje_base', compliance: 128),
        ],
      );
      expect(update, isNull);
    });

    test('sin VDOT previo ni perfil no se inventa nada', () {
      final update = updater.review(
        currentVdot: null,
        profile: null,
        recentSessions: [quality(compliance: 110)],
      );
      expect(update, isNull);
    });

    test('el VDOT se mantiene dentro del rango válido', () {
      var vdot = 30.5;
      for (var i = 0; i < 10; i++) {
        final update = updater.review(
          currentVdot: vdot,
          profile: null,
          recentSessions: [
            quality(compliance: 80),
            quality(category: 'series_largas', compliance: 80),
          ],
        );
        if (update != null) vdot = update.vdot;
      }
      expect(vdot, greaterThanOrEqualTo(30.0));
    });
  });

  group('test encubierto', () {
    test('un esfuerzo continuo a tope sube el VDOT de golpe', () {
      final update = updater.review(
        currentVdot: 40,
        profile: null,
        recentSessions: [
          AiCoachTrainingSummary(
            trainingId: 'tt',
            date: DateTime(2026, 7, 25),
            title: '10K a tope',
            category: 'rodaje_base',
            distanceKm: 10,
            durationMinutes: 42,
            rpe: 9.5,
          ),
        ],
      );
      expect(update, isNotNull);
      expect(update!.source, VdotSource.timeTrial);
      expect(update.vdot, greaterThan(40));
    });

    test('el salto está topado para que un GPS loco no dispare los ritmos', () {
      final update = updater.review(
        currentVdot: 40,
        profile: null,
        recentSessions: [
          AiCoachTrainingSummary(
            trainingId: 'tt',
            date: DateTime(2026, 7, 25),
            title: 'Lectura absurda',
            category: 'rodaje_base',
            distanceKm: 10,
            durationMinutes: 25, // 2:30/km — imposible
            rpe: 10,
          ),
        ],
      );
      expect(update!.vdot, lessThanOrEqualTo(42.0));
    });

    test('una sesión de series no se confunde con un test', () {
      // El tiempo total incluye descansos: aplicar Daniels daría un VDOT
      // absurdamente bajo y hundiría los ritmos.
      final update = updater.review(
        currentVdot: 50,
        profile: null,
        recentSessions: [
          AiCoachTrainingSummary(
            trainingId: 's1',
            date: DateTime(2026, 7, 25),
            title: '10x400',
            category: 'series_cortas',
            distanceKm: 8,
            durationMinutes: 60,
            rpe: 9.5,
          ),
        ],
      );
      expect(update?.source, isNot(VdotSource.timeTrial));
    });

    test('un esfuerzo suave no cuenta como test', () {
      final update = updater.review(
        currentVdot: 40,
        profile: null,
        recentSessions: [
          AiCoachTrainingSummary(
            trainingId: 'r1',
            date: DateTime(2026, 7, 25),
            title: 'Rodaje',
            category: 'rodaje_base',
            distanceKm: 10,
            durationMinutes: 42,
            rpe: 5,
          ),
        ],
      );
      expect(update, isNull);
    });
  });

  group('los ritmos se mueven de verdad', () {
    test('subir el VDOT acelera los ritmos objetivo', () {
      final antes = VdotCalculator.pacesFromVdot(50)!;
      final despues = VdotCalculator.pacesFromVdot(52)!;
      expect(despues.z4MinSecPerKm, lessThan(antes.z4MinSecPerKm));
      expect(despues.z2MinSecPerKm, lessThan(antes.z2MinSecPerKm));
    });
  });
}
