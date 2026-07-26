import 'package:flutter_test/flutter_test.dart';
import 'package:running_laps/features/athlete/data/athlete_session_model.dart';
import 'package:running_laps/features/templates/data/athlete_session_mapper.dart';
import 'package:running_laps/features/templates/data/workout_block.dart';
import 'package:running_laps/features/templates/data/workout_segment.dart';
import 'package:running_laps/features/templates/data/workout_session.dart';

/// El mapeo entre la sesión planificada (`AthleteSession`, lo que se guarda en
/// Firestore y pinta el calendario) y la sesión del editor (`WorkoutSession`).
///
/// Es el paso por el que viaja **el contenido del entrenamiento**: si pierde
/// repeticiones, distancias o descansos, el usuario planifica 6×1000 y la app
/// le ofrece ejecutar otra cosa. El test existente cubría solo el tipo de
/// sesión; esto cubre los bloques.
void main() {
  AthleteSession plannedWith({
    List<SessionBlock> blocks = const [],
    SessionWarmupCooldown? warmup,
    SessionWarmupCooldown? cooldown,
    String category = 'series_largas',
  }) {
    return AthleteSession(
      id: 'sesion-1',
      uid: 'uid-1',
      date: '2026-07-20',
      category: category,
      status: AthleteSessionStatus.planned,
      warmup: warmup,
      blocks: blocks,
      cooldown: cooldown,
      createdAt: DateTime(2026, 7, 19),
      updatedAt: DateTime(2026, 7, 19),
    );
  }

  group('sesión planificada → editor', () {
    test('un bloque de series conserva repeticiones, distancia y descanso', () {
      final session = mapAthleteSessionToWorkout(plannedWith(blocks: const [
        SessionBlock(
          id: 'b1',
          order: 0,
          type: SessionBlockType.series,
          reps: 6,
          distanceM: 1000,
          restSeconds: 90,
        ),
      ]))!;

      final main = session.blocks.firstWhere((b) => b.role == BlockRole.main);
      expect(main.repetitions, 6);

      final esfuerzo = main.segments.first;
      expect(esfuerzo.type, SegmentType.interval);
      expect(esfuerzo.distanceM, 1000);

      final descanso = main.segments.last;
      expect(descanso.type, SegmentType.recovery);
      expect(descanso.durationSec, 90);
    });

    test('sin descanso no se inventa un segmento de recuperación', () {
      final session = mapAthleteSessionToWorkout(plannedWith(blocks: const [
        SessionBlock(
          id: 'b1',
          order: 0,
          type: SessionBlockType.continuousDistance,
          distanceM: 10000,
        ),
      ]))!;

      final main = session.blocks.firstWhere((b) => b.role == BlockRole.main);
      expect(main.segments, hasLength(1));
      expect(main.segments.single.type, SegmentType.interval);
    });

    test('un bloque por tiempo pasa los minutos a segundos', () {
      final session = mapAthleteSessionToWorkout(plannedWith(blocks: const [
        SessionBlock(
          id: 'b1',
          order: 0,
          type: SessionBlockType.continuousTime,
          durationMinutes: 45,
        ),
      ]))!;

      final main = session.blocks.firstWhere((b) => b.role == BlockRole.main);
      expect(main.segments.single.durationSec, 45 * 60);
    });

    test('calentamiento y vuelta a la calma llegan como bloques propios', () {
      final session = mapAthleteSessionToWorkout(plannedWith(
        warmup: const SessionWarmupCooldown(durationMinutes: 10),
        blocks: const [
          SessionBlock(
            id: 'b1',
            order: 0,
            type: SessionBlockType.series,
            reps: 4,
            distanceM: 400,
            restSeconds: 60,
          ),
        ],
        cooldown: const SessionWarmupCooldown(durationMinutes: 12),
      ))!;

      expect(session.blocks.map((b) => b.role), [
        BlockRole.warmup,
        BlockRole.main,
        BlockRole.cooldown,
      ]);
      // WorkoutSession lo exige: calentamiento y vuelta a la calma van a 1.
      expect(
        session.blocks
            .where((b) => b.role != BlockRole.main)
            .every((b) => b.repetitions == 1),
        isTrue,
      );
      expect(session.blocks.first.segments.single.durationSec, 10 * 60);
      expect(session.blocks.last.segments.single.durationSec, 12 * 60);
    });

    test('una sesión sin bloques sigue produciendo una sesión válida', () {
      // WorkoutSession exige al menos un bloque main: el mapper inventa uno
      // mínimo en vez de reventar con el assert del modelo.
      final session = mapAthleteSessionToWorkout(plannedWith())!;

      expect(session.blocks.where((b) => b.role == BlockRole.main), hasLength(1));
      expect(session.blocks.first.segments, isNotEmpty);
    });

    test('un bloque sin distancia ni tiempo no genera segmentos vacíos', () {
      final session = mapAthleteSessionToWorkout(plannedWith(blocks: const [
        SessionBlock(id: 'b1', order: 0, type: SessionBlockType.series, reps: 3),
      ]))!;

      // No hay métrica con la que construir el esfuerzo, así que ese bloque no
      // aporta segmentos; el invariante de "al menos un main" lo cubre el
      // bloque mínimo.
      final main = session.blocks.firstWhere((b) => b.role == BlockRole.main);
      expect(main.segments, isNotEmpty);
    });

    test('null entra, null sale', () {
      expect(mapAthleteSessionToWorkout(null), isNull);
    });
  });

  group('editor → sesión planificada', () {
    test('el bloque principal viaja con sus repeticiones y su descanso', () {
      final workout = WorkoutSession(
        title: '6×1km',
        type: WorkoutType.intervals,
        scheduledDate: DateTime(2026, 7, 20),
        blocks: [
          WorkoutBlock(role: BlockRole.warmup, repetitions: 1, segments: [
            WorkoutSegment(type: SegmentType.interval, durationSec: 600),
          ]),
          WorkoutBlock(role: BlockRole.main, repetitions: 6, segments: [
            WorkoutSegment(type: SegmentType.interval, distanceM: 1000),
            WorkoutSegment(type: SegmentType.recovery, durationSec: 90),
          ]),
          WorkoutBlock(role: BlockRole.cooldown, repetitions: 1, segments: [
            WorkoutSegment(type: SegmentType.interval, durationSec: 600),
          ]),
        ],
      );

      final planned = mapWorkoutSessionToAthlete(workout, uid: 'uid-1');

      expect(planned.date, '2026-07-20');
      expect(planned.status, AthleteSessionStatus.planned);
      expect(planned.warmup, isNotNull);
      expect(planned.cooldown, isNotNull);

      final main = planned.blocks.single;
      expect(main.reps, 6);
      expect(main.distanceM, 1000);
      expect(main.restSeconds, 90);
    });

    test('ida y vuelta completa: 6×1km sobrevive el viaje entero', () {
      // El caso real: planificas en el editor, se guarda, y al abrirlo desde el
      // calendario (o al completarlo manualmente) tiene que decir lo mismo.
      final original = WorkoutSession(
        title: '6×1km',
        type: WorkoutType.intervals,
        scheduledDate: DateTime(2026, 7, 20),
        blocks: [
          WorkoutBlock(role: BlockRole.main, repetitions: 6, segments: [
            WorkoutSegment(type: SegmentType.interval, distanceM: 1000),
            WorkoutSegment(type: SegmentType.recovery, durationSec: 90),
          ]),
        ],
      );

      final roundTripped = mapAthleteSessionToWorkout(
        mapWorkoutSessionToAthlete(original, uid: 'uid-1'),
      )!;

      final main =
          roundTripped.blocks.firstWhere((b) => b.role == BlockRole.main);
      expect(main.repetitions, 6);
      expect(main.segments.first.distanceM, 1000);
      expect(main.segments.last.durationSec, 90);
      expect(roundTripped.type, WorkoutType.intervals);
      expect(roundTripped.scheduledDate, DateTime(2026, 7, 20));
    });
  });
}
