import 'package:flutter_test/flutter_test.dart';
import 'package:running_laps/features/templates/data/target_config.dart';
import 'package:running_laps/features/templates/data/workout_block.dart';
import 'package:running_laps/features/templates/data/workout_segment.dart';
import 'package:running_laps/features/templates/data/workout_session.dart';
import 'package:running_laps/features/training/data/serie.dart';
import 'package:running_laps/features/training/data/workout_execution_controller.dart';
import 'package:running_laps/features/training/data/workout_execution_state.dart';

void main() {
  Serie makeSerie() => Serie(
        tiempoSec: 120,
        distanciaM: 400,
        descansoSec: 60,
        rpe: 6,
      );

  WorkoutSession makeSession() {
    return WorkoutSession(
      title: 'Series 2×400',
      type: WorkoutType.intervals,
      blocks: [
        WorkoutBlock(
          role: BlockRole.warmup,
          repetitions: 1,
          segments: [WorkoutSegment(type: SegmentType.interval, durationSec: 600)],
        ),
        WorkoutBlock(
          role: BlockRole.main,
          repetitions: 2,
          segments: [
            WorkoutSegment(
              type: SegmentType.interval,
              distanceM: 400,
              target: const TargetConfig(paceMinSecPerKm: 250, paceMaxSecPerKm: 270),
            ),
            WorkoutSegment(
              type: SegmentType.recovery,
              durationSec: 90,
            ),
          ],
        ),
        WorkoutBlock(
          role: BlockRole.cooldown,
          repetitions: 1,
          segments: [WorkoutSegment(type: SegmentType.interval, durationSec: 300)],
        ),
      ],
    );
  }

  group('WorkoutExecutionController', () {
    test('el estado inicial arranca en warmup con bloque 0', () {
      final controller = WorkoutExecutionController(makeSession());

      expect(controller.value.phase, ExecutionPhase.warmup);
      expect(controller.value.currentBlockIndex, 0);
      expect(controller.value.totalCompletedReps, 0);
      expect(controller.value.isLastBlock, isFalse);
    });

    test('completar un bloque pasa a transition y advanceToNextBlock avanza',
        () {
      final controller = WorkoutExecutionController(makeSession());

      controller.recordSerie(makeSerie()); // warmup: 1/1 → completo
      expect(controller.value.phase, ExecutionPhase.transition);

      controller.advanceToNextBlock();
      expect(controller.value.currentBlockIndex, 1);
      expect(controller.value.phase, ExecutionPhase.main);
    });

    test('el bloque main requiere todas las repeticiones', () {
      final controller = WorkoutExecutionController(makeSession());
      controller.recordSerie(makeSerie()); // warmup
      controller.advanceToNextBlock();

      controller.recordSerie(makeSerie()); // main 1/2
      expect(controller.value.phase, ExecutionPhase.main,
          reason: 'con 1 de 2 reps el bloque sigue activo');

      controller.recordSerie(makeSerie()); // main 2/2
      expect(controller.value.phase, ExecutionPhase.transition);
      expect(controller.value.currentBlock.completedReps, 2);
    });

    test('completar el último bloque termina la sesión', () {
      final controller = WorkoutExecutionController(makeSession());
      controller.recordSerie(makeSerie()); // warmup
      controller.advanceToNextBlock();
      controller.recordSerie(makeSerie());
      controller.recordSerie(makeSerie()); // main completo
      controller.advanceToNextBlock();

      expect(controller.value.phase, ExecutionPhase.cooldown);
      expect(controller.value.isLastBlock, isTrue);

      controller.recordSerie(makeSerie()); // cooldown 1/1
      expect(controller.value.phase, ExecutionPhase.done);
      expect(controller.value.finishedAt, isNotNull);
      expect(controller.value.allSeries, hasLength(4));
    });

    test('finishEarly termina en cualquier punto', () {
      final controller = WorkoutExecutionController(makeSession());
      controller.recordSerie(makeSerie());

      controller.finishEarly();

      expect(controller.value.phase, ExecutionPhase.done);
      expect(controller.value.finishedAt, isNotNull);
      expect(controller.value.allSeries, hasLength(1));
    });

    test('paramsForCurrentRep expone objetivos del segmento interval', () {
      final controller = WorkoutExecutionController(makeSession());
      controller.recordSerie(makeSerie()); // warmup
      controller.advanceToNextBlock(); // → main

      final params = controller.paramsForCurrentRep();

      expect(params['distancia'], '400');
      expect(params['descanso'], '90');
      expect(params['targetPaceMinutes'], 4); // 250 s → 4:10
      expect(params['targetPaceSeconds'], 10);
      expect(params['targetPaceMaxMinutes'], 4); // 270 s → 4:30
      expect(params['targetPaceMaxSeconds'], 30);
      expect(params['currentSeries'], 1);
      expect(params['totalSeries'], 2);
    });
  });
}
