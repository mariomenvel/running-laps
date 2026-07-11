import 'package:flutter_test/flutter_test.dart';
import 'package:running_laps/features/ai_coach/data/ai_coach_session_generator.dart';
import 'package:running_laps/features/ai_coach/data/ai_coach_models.dart';

void main() {
  group('AiCoachSessionGenerator', () {
    const generator = AiCoachSessionGenerator();

    // complexityTier = byLevel + deltaByWeekType
    // null/beginner=0, absorb=+0  → tier=0  (6 reps × 150m)
    // null/beginner=0, build=+1   → tier=1  (8 reps × 200m)
    // advanced=2,      build=+1   → tier=3 → clamp 2  (10 reps × 250m)

    AiCoachWeeklyDecision decision({
      AiCoachWeekType weekType = AiCoachWeekType.absorb,
      AiCoachAdjustmentType adjustment = AiCoachAdjustmentType.maintain,
      List<AiCoachWorkoutTarget> targets = const [],
    }) =>
        AiCoachWeeklyDecision(
          id: 'test-decision',
          generatedAt: DateTime(2025),
          sourceModel: 'test',
          analysis: 'test',
          adjustment: adjustment,
          weekType: weekType,
          targetSessions: targets.length,
          targetVolumeKm: 40,
          targetLoad: 200,
          primaryFocus: 'test',
          workoutTargets: targets,
        );

    AiCoachWorkoutTarget target(
      String category, {
      double? km,
      int? minutes,
    }) =>
        AiCoachWorkoutTarget(
          category: category,
          purpose: 'test',
          priority: 1,
          targetDistanceKm: km,
          targetDurationMinutes: minutes,
        );

    // ── Regresión: rodaje no fragmentado ──────────────────────────────────────

    group('Regresión: rodaje no fragmentado', () {
      test('rodaje_base con tier < 2 genera 1 solo bloque', () {
        // null profile → byLevel=0; absorb → delta=0; tier=0
        final sessions = generator.generateWeekSessions(
          uid: 'test',
          weekStart: DateTime(2025, 6, 23),
          decision: decision(
            weekType: AiCoachWeekType.absorb,
            targets: [target('rodaje_base', minutes: 70)],
          ),
          profile: null,
        );
        expect(sessions, hasLength(1));
        expect(sessions.first.blocks, hasLength(1));
      });

      test('rodaje_base con tier=2 (advanced+build) puede fragmentar', () {
        // advanced → byLevel=2; build → delta=1; tier=3 → clamp 2
        final sessions = generator.generateWeekSessions(
          uid: 'test',
          weekStart: DateTime(2025, 6, 23),
          decision: decision(
            weekType: AiCoachWeekType.build,
            adjustment: AiCoachAdjustmentType.progress,
            targets: [target('rodaje_base', minutes: 70)],
          ),
          profile: _advancedProfile(),
        );
        expect(sessions, hasLength(1));
        // tier=2 + targetMinutes=70 (≥55) → 3 bloques progresivos
        expect(sessions.first.blocks.length, greaterThanOrEqualTo(1));
      });
    });

    // ── series_cuestas escala al nivel ────────────────────────────────────────

    group('series_cuestas escala al nivel', () {
      test('tier=0 (beginner+absorb): 6 reps × 150m', () {
        final sessions = generator.generateWeekSessions(
          uid: 'test',
          weekStart: DateTime(2025, 6, 23),
          decision: decision(
            weekType: AiCoachWeekType.absorb,
            targets: [target('series_cuestas')],
          ),
          profile: null,
        );
        final block =
            sessions.first.blocks.firstWhere((b) => b.reps != null);
        expect(block.reps, 6);
        expect(block.distanceM, 150);
      });

      test('tier=2 (advanced+build): 10 reps × 250m', () {
        final sessions = generator.generateWeekSessions(
          uid: 'test',
          weekStart: DateTime(2025, 6, 23),
          decision: decision(
            weekType: AiCoachWeekType.build,
            adjustment: AiCoachAdjustmentType.progress,
            targets: [target('series_cuestas')],
          ),
          profile: _advancedProfile(),
        );
        final block =
            sessions.first.blocks.firstWhere((b) => b.reps != null);
        expect(block.reps, 10);
        expect(block.distanceM, 250);
      });
    });

    // ── series_cortas: tope de repeticiones ───────────────────────────────────

    group('series_cortas: tope de repeticiones', () {
      test('máximo 12 reps aunque targetKm sea alto', () {
        // 20km / 400m = 50 reps sin tope; debe clampear a 12
        final sessions = generator.generateWeekSessions(
          uid: 'test',
          weekStart: DateTime(2025, 6, 23),
          decision: decision(
            weekType: AiCoachWeekType.absorb,
            targets: [target('series_cortas', km: 20)],
          ),
          profile: null,
        );
        final block =
            sessions.first.blocks.firstWhere((b) => b.reps != null);
        expect(block.reps, lessThanOrEqualTo(12));
      });
    });
  });
}

AiCoachProfile _advancedProfile() => AiCoachProfile(
      uid: 'test',
      goal: AiCoachGoalType.raceMarathon,
      goalDescription: '',
      level: AiCoachAthleteLevel.advanced,
      availableWeekdays: [1, 3, 6],
      preferredWeeklySessions: 5,
      createdAt: DateTime(2025),
      updatedAt: DateTime(2025),
    );
