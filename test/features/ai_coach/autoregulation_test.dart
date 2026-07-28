import 'package:flutter_test/flutter_test.dart';
import 'package:running_laps/features/ai_coach/data/ai_coach_autoregulation.dart';
import 'package:running_laps/features/ai_coach/data/ai_coach_models.dart';

/// Autorregulacion del Coach IA (docs/AI_COACH_MESOCYCLE.md §4.3).
///
/// La progresion se gana, no se calendariza: el bloque marca el techo y estos
/// veredictos marcan la posicion bajo ese techo a partir de la ejecucion real.
void main() {
  const auto = AiCoachAutoregulation();

  AiCoachTrainingSummary session({
    required String category,
    double? paceCompliance,
    bool? harder,
    bool? easier,
    double distanceKm = 8,
  }) {
    return AiCoachTrainingSummary(
      trainingId: 't-$category-$paceCompliance-$harder',
      date: DateTime(2026, 7, 21),
      title: 'Sesion',
      category: category,
      distanceKm: distanceKm,
      durationMinutes: 45,
      paceCompliancePercent: paceCompliance,
      wasHarderThanExpected: harder,
      wasEasierThanExpected: easier,
    );
  }

  AiCoachWeeklyState stateWith({
    double adherence = 1.0,
    int consecutiveMissedWeeks = 0,
    double tsb = 0,
    double weeklyKm = 30,
  }) {
    return AiCoachWeeklyState(
      weekStart: DateTime(2026, 7, 20),
      plannedSessions: 4,
      completedSessions: 4,
      skippedSessions: 0,
      adherenceRatio: adherence,
      weeklyKm: weeklyKm,
      weeklyLoad: 300,
      weeklyRpeAverage: 5,
      atl: 40,
      ctl: 35,
      tsb: tsb,
      daysSinceLastTraining: 1,
      consecutiveMissedWeeks: consecutiveMissedWeeks,
      raceInNext14Days: false,
      needsDeload: false,
      trend: 'stable',
    );
  }

  group('progresion ganada', () {
    test('dar los ritmos con margen sube la carga', () {
      final signal = auto.evaluate(
        lastWeekSessions: [
          session(category: 'tempo', paceCompliance: 98, easier: true),
          session(category: 'rodaje_base', paceCompliance: 100),
        ],
        weeklyState: stateWith(),
      );
      expect(signal.verdict, AiCoachReadinessVerdict.progress);
      expect(signal.volumeFactor, greaterThan(1.0));
    });

    test('dar los ritmos sin margen sube menos que con margen', () {
      final conMargen = auto.evaluate(
        lastWeekSessions: [
          session(category: 'tempo', paceCompliance: 98, easier: true),
        ],
        weeklyState: stateWith(),
      );
      final sinMargen = auto.evaluate(
        lastWeekSessions: [
          session(category: 'tempo', paceCompliance: 95),
        ],
        weeklyState: stateWith(),
      );
      expect(sinMargen.verdict, AiCoachReadinessVerdict.progress);
      expect(sinMargen.volumeFactor, lessThan(conMargen.volumeFactor));
    });

    test('nunca sube mas de un 10%', () {
      final signal = auto.evaluate(
        lastWeekSessions: [
          session(category: 'tempo', paceCompliance: 120, easier: true),
          session(category: 'series_largas', paceCompliance: 120, easier: true),
        ],
        weeklyState: stateWith(),
      );
      expect(signal.volumeFactor, lessThanOrEqualTo(1.10));
    });
  });

  group('consolidacion', () {
    test('sacarlo justo mantiene la carga, no la sube', () {
      final signal = auto.evaluate(
        lastWeekSessions: [
          session(category: 'tempo', paceCompliance: 88),
        ],
        weeklyState: stateWith(),
      );
      expect(signal.verdict, AiCoachReadinessVerdict.hold);
      expect(signal.volumeFactor, 1.0);
    });

    test('aparecer a medias no da derecho a subir', () {
      final signal = auto.evaluate(
        lastWeekSessions: [
          session(category: 'tempo', paceCompliance: 95),
        ],
        weeklyState: stateWith(adherence: 0.6),
      );
      expect(signal.verdict, AiCoachReadinessVerdict.hold);
    });

    test('sin evidencia no se inventa progresion', () {
      final signal = auto.evaluate(
        lastWeekSessions: const [],
        weeklyState: stateWith(adherence: 0.8),
      );
      expect(signal.verdict, AiCoachReadinessVerdict.hold);
      expect(signal.volumeFactor, 1.0);
      expect(signal.sessionsAnalyzed, 0);
    });
  });

  group('retroceso', () {
    test('quedarse corto en los ritmos baja la carga', () {
      final signal = auto.evaluate(
        lastWeekSessions: [
          session(category: 'tempo', paceCompliance: 78),
          session(category: 'series_cortas', paceCompliance: 80),
        ],
        weeklyState: stateWith(),
      );
      expect(signal.verdict, AiCoachReadinessVerdict.regress);
      expect(signal.volumeFactor, lessThan(1.0));
      expect(signal.reason, contains('corto'));
    });

    test('dos sesiones mas duras de lo previsto marcan fatiga y bajan', () {
      final signal = auto.evaluate(
        lastWeekSessions: [
          session(category: 'tempo', paceCompliance: 95, harder: true),
          session(category: 'series_largas', paceCompliance: 95, harder: true),
        ],
        weeklyState: stateWith(),
      );
      expect(signal.verdict, AiCoachReadinessVerdict.regress);
      expect(signal.fatigueFlag, isTrue);
      expect(signal.reason, contains('fatiga'));
    });

    test('un TSB muy negativo baja aunque los ritmos sean buenos', () {
      final signal = auto.evaluate(
        lastWeekSessions: [
          session(category: 'tempo', paceCompliance: 98),
        ],
        weeklyState: stateWith(tsb: -25),
      );
      expect(signal.verdict, AiCoachReadinessVerdict.regress);
      expect(signal.fatigueFlag, isTrue);
    });

    test('perder la mitad de las sesiones ajusta a lo que da la semana', () {
      final signal = auto.evaluate(
        lastWeekSessions: [
          session(category: 'rodaje_base', paceCompliance: 100),
        ],
        weeklyState: stateWith(adherence: 0.4),
      );
      expect(signal.verdict, AiCoachReadinessVerdict.regress);
    });
  });

  group('reinicio tras paron', () {
    test('dos semanas perdidas reentran por debajo', () {
      final signal = auto.evaluate(
        lastWeekSessions: const [],
        weeklyState: stateWith(consecutiveMissedWeeks: 2, adherence: 0),
      );
      expect(signal.verdict, AiCoachReadinessVerdict.reset);
      expect(signal.volumeFactor, lessThan(1.0));
      expect(signal.reason, contains('paron'));
    });

    test('el reinicio no es un castigo: baja menos que a cero', () {
      final signal = auto.evaluate(
        lastWeekSessions: const [],
        weeklyState: stateWith(consecutiveMissedWeeks: 3, adherence: 0),
      );
      expect(signal.volumeFactor, greaterThan(0.5));
    });
  });

  group('rodajes suaves demasiado rapidos', () {
    test('se detecta y bloquea la subida', () {
      final signal = auto.evaluate(
        lastWeekSessions: [
          session(category: 'tempo', paceCompliance: 95),
          session(category: 'rodaje_base', paceCompliance: 125),
          session(category: 'rodaje_base', paceCompliance: 120),
        ],
        weeklyState: stateWith(),
      );
      expect(signal.easyDaysTooHard, isTrue);
      expect(signal.verdict, isNot(AiCoachReadinessVerdict.progress));
      expect(signal.reason, contains('suaves'));
    });

    test('un facil corrido en su sitio no dispara la alerta', () {
      final signal = auto.evaluate(
        lastWeekSessions: [
          session(category: 'tempo', paceCompliance: 95),
          session(category: 'rodaje_base', paceCompliance: 100),
        ],
        weeklyState: stateWith(),
      );
      expect(signal.easyDaysTooHard, isFalse);
    });
  });

  group('volumen resultante', () {
    test('se ancla en lo corrido, no en lo planificado', () {
      final signal = auto.evaluate(
        lastWeekSessions: [session(category: 'tempo', paceCompliance: 95)],
        weeklyState: stateWith(),
      );
      // Planifico 40 pero corrio 25: la siguiente semana parte de 25.
      final volume = auto.resolveTargetVolume(
        signal: signal,
        actualLastWeekKm: 25,
        blockCeilingKm: 60,
        baselineFallbackKm: 40,
      );
      expect(volume, closeTo(25 * signal.volumeFactor, 0.01));
      expect(volume, lessThan(40));
    });

    test('el techo del bloque siempre acota', () {
      final signal = auto.evaluate(
        lastWeekSessions: [
          session(category: 'tempo', paceCompliance: 100, easier: true),
        ],
        weeklyState: stateWith(),
      );
      final volume = auto.resolveTargetVolume(
        signal: signal,
        actualLastWeekKm: 58,
        blockCeilingKm: 60,
        baselineFallbackKm: 40,
      );
      expect(volume, lessThanOrEqualTo(60));
    });

    test('sin semana previa cae al baseline del bloque', () {
      final signal = auto.evaluate(
        lastWeekSessions: const [],
        weeklyState: stateWith(adherence: 0.9),
      );
      final volume = auto.resolveTargetVolume(
        signal: signal,
        actualLastWeekKm: 0,
        blockCeilingKm: 60,
        baselineFallbackKm: 30,
      );
      expect(volume, 30);
    });

    test('una mala racha no deja que el plan se escape del atleta', () {
      // Escenario real: 4 semanas flojas seguidas. El volumen debe seguir al
      // atleta hacia abajo, no quedarse anclado a lo que decia el plan.
      var actual = 40.0;
      for (var week = 0; week < 4; week++) {
        final signal = auto.evaluate(
          lastWeekSessions: [
            session(category: 'tempo', paceCompliance: 75),
          ],
          weeklyState: stateWith(adherence: 0.5),
        );
        actual = auto.resolveTargetVolume(
          signal: signal,
          actualLastWeekKm: actual,
          blockCeilingKm: 60,
          baselineFallbackKm: 40,
        );
      }
      expect(actual, lessThan(30));
    });

    test('y el sistema puede volver a subir cuando el atleta vuelve', () {
      var actual = 20.0;
      for (var week = 0; week < 4; week++) {
        final signal = auto.evaluate(
          lastWeekSessions: [
            session(category: 'tempo', paceCompliance: 98, easier: true),
          ],
          weeklyState: stateWith(),
        );
        actual = auto.resolveTargetVolume(
          signal: signal,
          actualLastWeekKm: actual,
          blockCeilingKm: 60,
          baselineFallbackKm: 20,
        );
      }
      expect(actual, greaterThan(20));
      expect(actual, lessThanOrEqualTo(60));
    });
  });
}
