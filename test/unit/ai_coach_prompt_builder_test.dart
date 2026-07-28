import 'package:flutter_test/flutter_test.dart';
import 'package:running_laps/features/ai_coach/data/ai_coach_autoregulation.dart';
import 'package:running_laps/features/ai_coach/data/ai_coach_models.dart';
import 'package:running_laps/features/ai_coach/data/ai_coach_prompt_builder.dart';

AiCoachProfile _profile({String? trainingFocus}) {
  final now = DateTime(2026, 1, 1);
  return AiCoachProfile(
    uid: 'u1',
    goal: AiCoachGoalType.improveEndurance,
    goalDescription: 'test',
    level: AiCoachAthleteLevel.intermediate,
    preferredWeeklySessions: 4,
    trainingFocus: trainingFocus,
    createdAt: now,
    updatedAt: now,
  );
}

AiCoachWeeklyContext _context({String? trainingFocus}) {
  final now = DateTime(2026, 1, 1);
  return AiCoachWeeklyContext(
    profile: _profile(trainingFocus: trainingFocus),
    weeklyState: AiCoachWeeklyState(
      weekStart: now,
      plannedSessions: 0,
      completedSessions: 0,
      skippedSessions: 0,
      adherenceRatio: 1,
      weeklyKm: 0,
      weeklyLoad: 0,
      weeklyRpeAverage: 0,
      atl: 0,
      ctl: 0,
      tsb: 0,
      daysSinceLastTraining: 0,
      consecutiveMissedWeeks: 0,
      raceInNext14Days: false,
      needsDeload: false,
      trend: 'stable',
    ),
    recentTrainings: const [],
    recentPlannedSessions: const [],
    generatedAt: now,
  );
}

void main() {
  group('AiCoachPromptBuilder.buildWeeklyDecisionPrompt', () {
    const builder = AiCoachPromptBuilder();

    String systemPromptFor(String? trainingFocus) {
      final bundle = builder.buildWeeklyDecisionPrompt(
        _context(trainingFocus: trainingFocus),
      );
      return bundle.messages.first.content;
    }

    test('trainingFocus=volume inyecta el bloque de preferencia', () {
      final prompt = systemPromptFor('volume');
      expect(prompt, contains('PREFERENCIA DEL ATLETA: prioriza volumen aeróbico'));
      expect(prompt, contains('SIEMPRE SECUNDARIA a cualquier instrucción marcada como MANDATO'));
    });

    test('trainingFocus=quality inyecta el bloque de preferencia', () {
      final prompt = systemPromptFor('quality');
      expect(prompt, contains('PREFERENCIA DEL ATLETA: prioriza calidad'));
      expect(prompt, contains('SIEMPRE SECUNDARIA a cualquier instrucción marcada como MANDATO'));
    });

    test('trainingFocus=null no añade ningún bloque de preferencia', () {
      final prompt = systemPromptFor(null);
      expect(prompt, isNot(contains('PREFERENCIA DEL ATLETA')));
    });

    test("trainingFocus='balanced' no añade ningún bloque de preferencia", () {
      final prompt = systemPromptFor('balanced');
      expect(prompt, isNot(contains('PREFERENCIA DEL ATLETA')));
    });
  });

  group('mesociclo en el prompt', () {
    const builder = AiCoachPromptBuilder();

    final block = AiCoachMesocycle(
      id: 'meso-1',
      startWeek: DateTime(2026, 1, 1),
      lengthWeeks: 4,
      phase: AiCoachBlockPhase.base,
      weekPattern: const [
        AiCoachWeekType.build,
        AiCoachWeekType.build,
        AiCoachWeekType.build,
        AiCoachWeekType.absorb,
      ],
      baselineVolumeKm: 30,
      volumeCeilingKm: 45,
      volumeStepPct: 0.08,
      deloadVolumePct: 0.60,
      focus: 'Construyendo base aerobica',
      createdAt: DateTime(2026, 1, 1),
    );

    const signal = AiCoachAutoregulationSignal(
      verdict: AiCoachReadinessVerdict.hold,
      volumeFactor: 1.0,
      sessionsAnalyzed: 3,
      adherence: 1,
      reason: 'Semana sacada justa: consolidamos antes de subir.',
    );

    test('sin bloque no se inyectan reglas de periodización', () {
      final bundle = builder.buildWeeklyDecisionPrompt(_context());
      expect(bundle.messages.first.content, isNot(contains('Bloque activo')));
    });

    test('con bloque se le dice al LLM que el volumen no se negocia', () {
      final bundle = builder.buildWeeklyDecisionPrompt(
        _context(),
        mesocycle: block,
        autoregulation: signal,
      );
      final system = bundle.messages.first.content;
      expect(system, contains('Bloque activo'));
      expect(system, contains('NO negociable'));
      expect(system, contains('nunca más'));
    });

    test('el payload lleva la posición dentro del bloque y el veredicto', () {
      final bundle = builder.buildWeeklyDecisionPrompt(
        _context(),
        mesocycle: block,
        autoregulation: signal,
      );
      final payload = bundle.messages.last.content;
      expect(payload, contains('"blockWeek":1'));
      expect(payload, contains('"blockLengthWeeks":4'));
      expect(payload, contains('"blockPhase":"base"'));
      expect(payload, contains('"verdict":"hold"'));
    });
  });
}
