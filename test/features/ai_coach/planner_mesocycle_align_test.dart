import 'package:flutter_test/flutter_test.dart';
import 'package:running_laps/features/ai_coach/data/ai_coach_autoregulation.dart';
import 'package:running_laps/features/ai_coach/data/ai_coach_mesocycle_engine.dart';
import 'package:running_laps/features/ai_coach/data/ai_coach_models.dart';
import 'package:running_laps/features/ai_coach/data/ai_coach_weekly_planner_service.dart';

/// Integracion de la periodizacion en el planificador (fase 2).
///
/// `alignDecisionToMesocycle` es la frontera donde la decision del LLM se
/// somete al bloque y a la autorregulacion. Es logica pura: no toca Firebase.
void main() {
  final planner = AiCoachWeeklyPlannerService();
  const engine = AiCoachMesocycleEngine();

  final monday = DateTime(2026, 8, 3);

  AiCoachProfile profileWith({
    AiCoachAthleteLevel level = AiCoachAthleteLevel.intermediate,
  }) =>
      AiCoachProfile(
        uid: 'uid-1',
        goal: AiCoachGoalType.improveEndurance,
        goalDescription: 'Mejorar la base',
        level: level,
        availableWeekdays: const [1, 3, 5, 6],
        preferredWeeklySessions: 4,
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      );

  AiCoachWeeklyState stateWith({double weeklyKm = 30}) => AiCoachWeeklyState(
        weekStart: DateTime(2026, 7, 27),
        plannedSessions: 4,
        completedSessions: 4,
        skippedSessions: 0,
        adherenceRatio: 1,
        weeklyKm: weeklyKm,
        weeklyLoad: 300,
        weeklyRpeAverage: 5,
        atl: 40,
        ctl: 0,
        tsb: 0,
        daysSinceLastTraining: 1,
        consecutiveMissedWeeks: 0,
        raceInNext14Days: false,
        needsDeload: false,
        trend: 'stable',
      );

  AiCoachMesocycle blockFor({
    AiCoachAthleteLevel level = AiCoachAthleteLevel.intermediate,
    double weeklyKm = 30,
  }) =>
      engine.buildBlock(
        weekStart: monday,
        profile: profileWith(level: level),
        weeklyState: stateWith(weeklyKm: weeklyKm),
        now: DateTime(2026, 7, 28),
      );

  AiCoachWeeklyDecision decisionWith({
    double targetVolumeKm = 30,
    double targetLoad = 300,
    AiCoachAdjustmentType adjustment = AiCoachAdjustmentType.progress,
    AiCoachWeekType weekType = AiCoachWeekType.build,
  }) =>
      AiCoachWeeklyDecision(
        id: 'dec-1',
        generatedAt: DateTime(2026, 7, 28),
        sourceModel: 'test',
        analysis: 'analisis',
        adjustment: adjustment,
        weekType: weekType,
        targetSessions: 4,
        targetVolumeKm: targetVolumeKm,
        targetLoad: targetLoad,
        primaryFocus: 'base',
      );

  AiCoachAutoregulationSignal signalOf(
    AiCoachReadinessVerdict verdict, {
    double factor = 1.0,
  }) =>
      AiCoachAutoregulationSignal(
        verdict: verdict,
        volumeFactor: factor,
        sessionsAnalyzed: 3,
        adherence: 1,
        reason: 'test',
      );

  group('el LLM no puede subir la carga por encima del sistema', () {
    test('un volumen inflado por el LLM se recorta al techo del bloque', () {
      final block = blockFor();
      final result = planner.alignDecisionToMesocycle(
        decisionWith(targetVolumeKm: 200),
        block: block,
        signal: signalOf(AiCoachReadinessVerdict.progress, factor: 1.05),
        weekStart: monday,
        actualLastWeekKm: 30,
      );
      // Semana 1 del bloque: el techo es el baseline, asi que ni el LLM ni la
      // autorregulacion pueden subir de ahi. Quien limita al alza es el bloque.
      expect(result.targetVolumeKm, engine.targetVolumeForWeek(block, 0));
      expect(result.targetVolumeKm, lessThan(200));
    });

    test('con margen dentro del bloque, la subida se permite pero acotada', () {
      final block = blockFor();
      final result = planner.alignDecisionToMesocycle(
        decisionWith(targetVolumeKm: 200),
        block: block,
        signal: signalOf(AiCoachReadinessVerdict.progress, factor: 1.05),
        weekStart: monday.add(const Duration(days: 14)),
        actualLastWeekKm: 30,
      );
      final ceiling = engine.targetVolumeForWeek(block, 2);
      expect(result.targetVolumeKm, greaterThan(30));
      expect(result.targetVolumeKm, lessThanOrEqualTo(ceiling));
    });

    test('pero si pide menos, se le respeta — la valvula abre hacia abajo', () {
      final block = blockFor();
      final result = planner.alignDecisionToMesocycle(
        decisionWith(targetVolumeKm: 18),
        block: block,
        signal: signalOf(AiCoachReadinessVerdict.progress, factor: 1.05),
        weekStart: monday,
        actualLastWeekKm: 30,
      );
      expect(result.targetVolumeKm, 18);
    });

    test('la carga escala con el volumen recortado', () {
      final block = blockFor();
      final result = planner.alignDecisionToMesocycle(
        decisionWith(targetVolumeKm: 60, targetLoad: 600),
        block: block,
        signal: signalOf(AiCoachReadinessVerdict.hold),
        weekStart: monday,
        actualLastWeekKm: 30,
      );
      expect(result.targetVolumeKm, lessThan(60));
      expect(result.targetLoad, lessThan(600));
      // Proporcion mantenida: km/carga sigue siendo coherente.
      expect(
        result.targetLoad / result.targetVolumeKm,
        closeTo(600 / 60, 0.01),
      );
    });
  });

  group('el bloque manda el tipo de semana', () {
    test('la semana de descarga fuerza deload aunque el LLM diga progress', () {
      final block = blockFor();
      // Semana 4 del bloque de intermedio = absorb.
      final result = planner.alignDecisionToMesocycle(
        decisionWith(adjustment: AiCoachAdjustmentType.progress),
        block: block,
        signal: signalOf(AiCoachReadinessVerdict.progress, factor: 1.05),
        weekStart: monday.add(const Duration(days: 21)),
        actualLastWeekKm: 30,
      );
      expect(result.weekType, AiCoachWeekType.absorb);
      expect(result.adjustment, AiCoachAdjustmentType.deload);
    });

    test('y baja el volumen respecto a la semana de carga anterior', () {
      final block = blockFor();
      final carga = planner.alignDecisionToMesocycle(
        decisionWith(targetVolumeKm: 100),
        block: block,
        signal: signalOf(AiCoachReadinessVerdict.progress, factor: 1.05),
        weekStart: monday.add(const Duration(days: 14)),
        actualLastWeekKm: 30,
      );
      final descarga = planner.alignDecisionToMesocycle(
        decisionWith(targetVolumeKm: 100),
        block: block,
        signal: signalOf(AiCoachReadinessVerdict.progress, factor: 1.05),
        weekStart: monday.add(const Duration(days: 21)),
        actualLastWeekKm: 30,
      );
      expect(descarga.targetVolumeKm, lessThan(carga.targetVolumeKm));
    });
  });

  group('el veredicto de autorregulacion manda el ajuste', () {
    test('regress convierte una semana de carga en reduccion', () {
      final block = blockFor();
      final result = planner.alignDecisionToMesocycle(
        decisionWith(adjustment: AiCoachAdjustmentType.progress),
        block: block,
        signal: signalOf(AiCoachReadinessVerdict.regress, factor: 0.85),
        weekStart: monday,
        actualLastWeekKm: 30,
      );
      expect(result.weekType, AiCoachWeekType.build);
      expect(result.adjustment, AiCoachAdjustmentType.reduce);
      expect(result.targetVolumeKm, lessThan(30));
    });

    test('hold mantiene: ni sube ni baja', () {
      final block = blockFor();
      final result = planner.alignDecisionToMesocycle(
        decisionWith(targetVolumeKm: 100),
        block: block,
        signal: signalOf(AiCoachReadinessVerdict.hold),
        weekStart: monday,
        actualLastWeekKm: 30,
      );
      expect(result.adjustment, AiCoachAdjustmentType.maintain);
      expect(result.targetVolumeKm, 30);
    });

    test('reset reentra por debajo y marca restart', () {
      final block = blockFor();
      final result = planner.alignDecisionToMesocycle(
        decisionWith(targetVolumeKm: 100),
        block: block,
        signal: signalOf(AiCoachReadinessVerdict.reset, factor: 0.70),
        weekStart: monday,
        actualLastWeekKm: 30,
      );
      expect(result.adjustment, AiCoachAdjustmentType.restart);
      expect(result.targetVolumeKm, closeTo(21, 0.01));
    });
  });

  group('anclaje en lo ejecutado', () {
    test('planificar 40 y correr 25 hace que la siguiente parta de 25', () {
      final block = blockFor(weeklyKm: 40);
      final result = planner.alignDecisionToMesocycle(
        decisionWith(targetVolumeKm: 44),
        block: block,
        signal: signalOf(AiCoachReadinessVerdict.hold),
        weekStart: monday,
        actualLastWeekKm: 25,
      );
      expect(result.targetVolumeKm, 25);
    });

    test('sin semana previa cae al baseline del bloque', () {
      final block = blockFor();
      final result = planner.alignDecisionToMesocycle(
        decisionWith(targetVolumeKm: 100),
        block: block,
        signal: signalOf(AiCoachReadinessVerdict.hold),
        weekStart: monday,
        actualLastWeekKm: 0,
      );
      expect(result.targetVolumeKm, closeTo(block.baselineVolumeKm, 0.01));
    });
  });

  group('el fallback sin LLM tambien obedece al bloque', () {
    test('una decision de plantilla queda periodizada igual', () {
      final block = blockFor();
      // _buildFallbackDecision emite targetVolumeKm: 24 fijo.
      final result = planner.alignDecisionToMesocycle(
        decisionWith(targetVolumeKm: 24, adjustment: AiCoachAdjustmentType.maintain),
        block: block,
        signal: signalOf(AiCoachReadinessVerdict.regress, factor: 0.85),
        weekStart: monday,
        actualLastWeekKm: 30,
      );
      expect(result.adjustment, AiCoachAdjustmentType.reduce);
      expect(result.targetVolumeKm, lessThanOrEqualTo(24));
    });
  });
}
