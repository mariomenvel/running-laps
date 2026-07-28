import 'package:flutter_test/flutter_test.dart';
import 'package:running_laps/features/ai_coach/data/ai_coach_mesocycle_engine.dart';
import 'package:running_laps/features/ai_coach/data/ai_coach_models.dart';

/// Motor de periodizacion del Coach IA (docs/AI_COACH_MESOCYCLE.md).
///
/// Todo lo que se prueba aqui es logica pura: el motor no toca Firebase ni el
/// LLM. El objetivo de la suite es que las reglas de entrenamiento que antes
/// vivian solo como texto en el prompt (10% semanal, descarga cada 3-4 semanas)
/// pasen a estar garantizadas por aritmetica y verificadas por tests.
void main() {
  const engine = AiCoachMesocycleEngine();

  AiCoachProfile profileWith({
    AiCoachAthleteLevel level = AiCoachAthleteLevel.intermediate,
    AiCoachGoalType goal = AiCoachGoalType.improveEndurance,
    int sessions = 4,
    DateTime? targetDate,
  }) {
    return AiCoachProfile(
      uid: 'uid-1',
      goal: goal,
      goalDescription: 'Objetivo de prueba',
      level: level,
      availableWeekdays: const [1, 3, 5, 6],
      preferredWeeklySessions: sessions,
      targetDate: targetDate,
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    );
  }

  AiCoachWeeklyState stateWith({
    double weeklyKm = 30,
    double ctl = 0,
    int consecutiveMissedWeeks = 0,
  }) {
    return AiCoachWeeklyState(
      weekStart: DateTime(2026, 7, 20),
      plannedSessions: 4,
      completedSessions: 4,
      skippedSessions: 0,
      adherenceRatio: 1,
      weeklyKm: weeklyKm,
      weeklyLoad: 300,
      weeklyRpeAverage: 5,
      atl: 40,
      ctl: ctl,
      tsb: 0,
      daysSinceLastTraining: 1,
      consecutiveMissedWeeks: consecutiveMissedWeeks,
      raceInNext14Days: false,
      needsDeload: false,
      trend: 'stable',
    );
  }

  final monday = DateTime(2026, 8, 3);

  group('techo de volumen', () {
    test('manda la disponibilidad cuando es mas restrictiva que el objetivo', () {
      // Intermedio + media maraton => 70 * 0.75 = 52.5 por objetivo,
      // pero solo 3 sesiones * 15 km = 45 por disponibilidad.
      final ceiling = engine.volumeCeilingFor(profileWith(
        goal: AiCoachGoalType.raceHalfMarathon,
        sessions: 3,
      ));
      expect(ceiling, 45);
    });

    test('manda el objetivo cuando la disponibilidad es holgada', () {
      // Novato + vuelta a correr => 30 * 0.5 = 15, frente a 5 * 9 = 45.
      final ceiling = engine.volumeCeilingFor(profileWith(
        level: AiCoachAthleteLevel.beginner,
        goal: AiCoachGoalType.returnToRunning,
        sessions: 5,
      ));
      expect(ceiling, 15);
    });

    test('el maratoniano avanzado tiene mas techo que el de 5k', () {
      final marathon = engine.volumeCeilingFor(profileWith(
        level: AiCoachAthleteLevel.advanced,
        goal: AiCoachGoalType.raceMarathon,
        sessions: 5,
      ));
      final fiveK = engine.volumeCeilingFor(profileWith(
        level: AiCoachAthleteLevel.advanced,
        goal: AiCoachGoalType.race5k,
        sessions: 5,
      ));
      expect(marathon, greaterThan(fiveK));
    });
  });

  group('curva de volumen', () {
    test('nunca sube mas de un 10% de una semana a la siguiente', () {
      // Se fuerza un step por encima del tope para comprobar el clamp.
      final block = engine
          .buildBlock(
            weekStart: monday,
            profile: profileWith(level: AiCoachAthleteLevel.advanced),
            weeklyState: stateWith(weeklyKm: 20),
            now: DateTime(2026, 7, 28),
          );
      final abusive = AiCoachMesocycle(
        id: block.id,
        startWeek: block.startWeek,
        lengthWeeks: 4,
        phase: block.phase,
        weekPattern: const [
          AiCoachWeekType.build,
          AiCoachWeekType.build,
          AiCoachWeekType.build,
          AiCoachWeekType.absorb,
        ],
        baselineVolumeKm: 20,
        volumeCeilingKm: 200,
        volumeStepPct: 0.50, // muy por encima del tope
        deloadVolumePct: 0.60,
        focus: 'test',
        createdAt: block.createdAt,
      );

      for (var week = 1; week < 3; week++) {
        final prev = engine.targetVolumeForWeek(abusive, week - 1);
        final current = engine.targetVolumeForWeek(abusive, week);
        expect(
          current / prev,
          lessThanOrEqualTo(1.0 + AiCoachMesocycleEngine.maxWeeklyStepPct),
          reason: 'semana $week supera el 10%',
        );
      }
    });

    test('es monotona creciente en las semanas de carga', () {
      final block = engine.buildBlock(
        weekStart: monday,
        profile: profileWith(),
        weeklyState: stateWith(weeklyKm: 30),
        now: DateTime(2026, 7, 28),
      );
      final w0 = engine.targetVolumeForWeek(block, 0);
      final w1 = engine.targetVolumeForWeek(block, 1);
      final w2 = engine.targetVolumeForWeek(block, 2);
      expect(w1, greaterThan(w0));
      expect(w2, greaterThan(w1));
    });

    test('nunca supera el techo, por muchas semanas que pasen', () {
      final block = AiCoachMesocycle(
        id: 'b',
        startWeek: monday,
        lengthWeeks: 40,
        phase: AiCoachBlockPhase.base,
        weekPattern: List.filled(40, AiCoachWeekType.build),
        baselineVolumeKm: 30,
        volumeCeilingKm: 45,
        volumeStepPct: 0.08,
        deloadVolumePct: 0.60,
        focus: 'test',
        createdAt: DateTime(2026, 7, 28),
      );
      for (var week = 0; week < 40; week++) {
        expect(engine.targetVolumeForWeek(block, week), lessThanOrEqualTo(45));
      }
    });

    test('la progresion desacelera al acercarse al techo', () {
      final block = AiCoachMesocycle(
        id: 'b',
        startWeek: monday,
        lengthWeeks: 20,
        phase: AiCoachBlockPhase.base,
        weekPattern: List.filled(20, AiCoachWeekType.build),
        baselineVolumeKm: 20,
        volumeCeilingKm: 50,
        volumeStepPct: 0.08,
        deloadVolumePct: 0.60,
        focus: 'test',
        createdAt: DateTime(2026, 7, 28),
      );
      final firstStep = engine.targetVolumeForWeek(block, 1) -
          engine.targetVolumeForWeek(block, 0);
      final lateStep = engine.targetVolumeForWeek(block, 15) -
          engine.targetVolumeForWeek(block, 14);
      expect(lateStep, lessThan(firstStep));
    });

    test('la descarga se calcula sobre el pico, no sobre el baseline', () {
      final block = engine.buildBlock(
        weekStart: monday,
        profile: profileWith(),
        weeklyState: stateWith(weeklyKm: 30),
        now: DateTime(2026, 7, 28),
      );
      final peak = engine.targetVolumeForWeek(block, 2);
      final deload = engine.targetVolumeForWeek(block, 3);
      expect(deload, closeTo(peak * block.deloadVolumePct, 0.01));
      // Y por tanto es mayor que un 60% del baseline, que seria mas duro.
      expect(deload, greaterThan(block.baselineVolumeKm * 0.5));
    });
  });

  group('patron del bloque', () {
    test('el intermedio lleva bloque de 4 con descarga al final', () {
      final block = engine.buildBlock(
        weekStart: monday,
        profile: profileWith(),
        weeklyState: stateWith(),
        now: DateTime(2026, 7, 28),
      );
      expect(block.lengthWeeks, 4);
      expect(block.weekPattern.last, AiCoachWeekType.absorb);
    });

    test('el novato lleva bloque de 3, paso reducido y descarga mas suave', () {
      final block = engine.buildBlock(
        weekStart: monday,
        profile: profileWith(level: AiCoachAthleteLevel.beginner),
        weeklyState: stateWith(weeklyKm: 12),
        now: DateTime(2026, 7, 28),
      );
      expect(block.lengthWeeks, 3);
      expect(block.weekPattern.last, AiCoachWeekType.absorb);
      expect(block.volumeStepPct, 0.05);
      expect(block.deloadVolumePct, 0.70);
    });

    test('siempre hay una descarga cada 4 semanas como maximo', () {
      for (final level in AiCoachAthleteLevel.values) {
        final block = engine.buildBlock(
          weekStart: monday,
          profile: profileWith(level: level),
          weeklyState: stateWith(),
          now: DateTime(2026, 7, 28),
        );
        final buildStreak = block.weekPattern
            .takeWhile((type) => type == AiCoachWeekType.build)
            .length;
        expect(buildStreak, lessThanOrEqualTo(3), reason: 'nivel $level');
      }
    });

    test('dos semanas perdidas abren un bloque que empieza en restart', () {
      final block = engine.buildBlock(
        weekStart: monday,
        profile: profileWith(),
        weeklyState: stateWith(consecutiveMissedWeeks: 2),
        now: DateTime(2026, 7, 28),
      );
      expect(block.weekPattern.first, AiCoachWeekType.restart);
      expect(block.volumeStepPct, 0.05);
      expect(block.focus, contains('Volver'));
    });

    test('la semana de restart entra por debajo del baseline', () {
      final block = engine.buildBlock(
        weekStart: monday,
        profile: profileWith(),
        weeklyState: stateWith(weeklyKm: 30, consecutiveMissedWeeks: 3),
        now: DateTime(2026, 7, 28),
      );
      expect(
        engine.targetVolumeForWeek(block, 0),
        lessThan(block.baselineVolumeKm),
      );
    });

    test('con carrera a 2 semanas el patron es taper, no build', () {
      final block = engine.buildBlock(
        weekStart: monday,
        profile: profileWith(targetDate: monday.add(const Duration(days: 14))),
        weeklyState: stateWith(),
        now: DateTime(2026, 7, 28),
      );
      expect(block.phase, AiCoachBlockPhase.taper);
      expect(block.weekPattern, isNot(contains(AiCoachWeekType.build)));
      expect(block.weekPattern.last, AiCoachWeekType.race);
    });

    test('el taper baja volumen respecto a una semana de carga', () {
      final taper = engine.buildBlock(
        weekStart: monday,
        profile: profileWith(targetDate: monday.add(const Duration(days: 14))),
        weeklyState: stateWith(weeklyKm: 40),
        now: DateTime(2026, 7, 28),
      );
      expect(
        engine.targetVolumeForWeek(taper, 0),
        lessThan(taper.baselineVolumeKm),
      );
    });
  });

  group('fase sin carrera objetivo', () {
    test('siempre hay fase aunque no haya targetDate', () {
      final block = engine.buildBlock(
        weekStart: monday,
        profile: profileWith(),
        weeklyState: stateWith(),
        now: DateTime(2026, 7, 28),
      );
      expect(block.phase, isNotNull);
      expect(block.focus, isNotEmpty);
    });

    test('los bloques encadenados rotan el enfasis', () {
      final phases = <AiCoachBlockPhase>[];
      AiCoachMesocycle? previous;
      for (var i = 0; i < 4; i++) {
        previous = engine.buildBlock(
          weekStart: monday.add(Duration(days: 28 * i)),
          profile: profileWith(),
          weeklyState: stateWith(),
          previous: previous,
          now: DateTime(2026, 7, 28),
        );
        phases.add(previous.phase);
      }
      expect(phases.toSet().length, greaterThan(1),
          reason: 'sin rotacion todos los bloques serian iguales');
      expect(phases, contains(AiCoachBlockPhase.specific));
    });
  });

  group('encadenado de bloques', () {
    test('el baseline sale del pico anterior, no de su semana de descarga', () {
      final first = engine.buildBlock(
        weekStart: monday,
        profile: profileWith(),
        weeklyState: stateWith(weeklyKm: 30),
        now: DateTime(2026, 7, 28),
      );
      final second = engine.buildBlock(
        weekStart: monday.add(const Duration(days: 28)),
        profile: profileWith(),
        weeklyState: stateWith(weeklyKm: 30),
        previous: first,
        now: DateTime(2026, 8, 25),
      );
      final firstPeak = engine.targetVolumeForWeek(first, 2);
      expect(second.baselineVolumeKm, closeTo(firstPeak, 0.01));
      expect(second.sequenceIndex, first.sequenceIndex + 1);
    });

    test('un ano encadenado no dispara el volumen — asintota en el techo', () {
      // El fallo que motivo la curva logistica: baseline * 1.08^n encadenado
      // daba ~19x de volumen en un ano.
      AiCoachMesocycle? block;
      for (var i = 0; i < 13; i++) {
        block = engine.buildBlock(
          weekStart: monday.add(Duration(days: 28 * i)),
          profile: profileWith(),
          weeklyState: stateWith(weeklyKm: 30),
          previous: block,
          now: DateTime(2026, 7, 28),
        );
      }
      expect(block!.baselineVolumeKm, lessThanOrEqualTo(block.volumeCeilingKm));
      // 30 km/sem de partida no pueden convertirse en cientos.
      expect(block.baselineVolumeKm, lessThan(70));
    });

    test('el baseline nunca supera el techo del atleta', () {
      final block = engine.buildBlock(
        weekStart: monday,
        profile: profileWith(
          level: AiCoachAthleteLevel.beginner,
          goal: AiCoachGoalType.returnToRunning,
          sessions: 3,
        ),
        // Semana anomala muy por encima de lo que el perfil sostiene.
        weeklyState: stateWith(weeklyKm: 90),
        now: DateTime(2026, 7, 28),
      );
      expect(block.baselineVolumeKm, lessThanOrEqualTo(block.volumeCeilingKm));
    });
  });

  group('baseline sin historial', () {
    test('usa un default conservador por nivel', () {
      final beginner = engine.buildBlock(
        weekStart: monday,
        profile: profileWith(level: AiCoachAthleteLevel.beginner),
        now: DateTime(2026, 7, 28),
      );
      final advanced = engine.buildBlock(
        weekStart: monday,
        profile: profileWith(level: AiCoachAthleteLevel.advanced),
        now: DateTime(2026, 7, 28),
      );
      expect(beginner.baselineVolumeKm, lessThan(advanced.baselineVolumeKm));
      expect(beginner.baselineVolumeKm, greaterThan(0));
    });

    test('cae a CTL*7 cuando no hay km de la semana pasada', () {
      final block = engine.buildBlock(
        weekStart: monday,
        profile: profileWith(),
        weeklyState: stateWith(weeklyKm: 0, ctl: 5),
        now: DateTime(2026, 7, 28),
      );
      expect(block.baselineVolumeKm, closeTo(35, 0.01));
    });
  });

  group('posicion dentro del bloque', () {
    test('weekIndexFor cuenta semanas desde el arranque', () {
      final block = engine.buildBlock(
        weekStart: monday,
        profile: profileWith(),
        weeklyState: stateWith(),
        now: DateTime(2026, 7, 28),
      );
      expect(block.weekIndexFor(monday), 0);
      expect(block.weekIndexFor(monday.add(const Duration(days: 7))), 1);
      expect(block.weekIndexFor(monday.add(const Duration(days: 21))), 3);
    });

    test('containsWeek detecta cuando toca abrir bloque nuevo', () {
      final block = engine.buildBlock(
        weekStart: monday,
        profile: profileWith(),
        weeklyState: stateWith(),
        now: DateTime(2026, 7, 28),
      );
      expect(block.containsWeek(monday.add(const Duration(days: 21))), isTrue);
      expect(block.containsWeek(monday.add(const Duration(days: 28))), isFalse);
      expect(block.containsWeek(monday.subtract(const Duration(days: 7))), isFalse);
    });
  });

  group('serializacion', () {
    test('round-trip conserva el bloque', () {
      final block = engine.buildBlock(
        weekStart: monday,
        profile: profileWith(),
        weeklyState: stateWith(),
        now: DateTime(2026, 7, 28),
      );
      final restored = AiCoachMesocycle.fromMap(block.toMap());
      expect(restored.id, block.id);
      expect(restored.lengthWeeks, block.lengthWeeks);
      expect(restored.phase, block.phase);
      expect(restored.weekPattern, block.weekPattern);
      expect(restored.baselineVolumeKm, block.baselineVolumeKm);
      expect(restored.volumeCeilingKm, block.volumeCeilingKm);
      expect(restored.sequenceIndex, block.sequenceIndex);
    });
  });
}
