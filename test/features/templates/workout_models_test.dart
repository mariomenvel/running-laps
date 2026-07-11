import 'package:flutter_test/flutter_test.dart';
import 'package:running_laps/features/templates/data/target_config.dart';
import 'package:running_laps/features/templates/data/workout_block.dart';
import 'package:running_laps/features/templates/data/workout_segment.dart';
import 'package:running_laps/features/templates/data/workout_session.dart';

void main() {
  // ─── TargetConfig ───────────────────────────────────────────────────────────

  group('TargetConfig', () {
    test('toMap/fromMap roundtrip con todos los campos', () {
      const config = TargetConfig(
        paceMinSecPerKm: 240,
        paceMaxSecPerKm: 300,
        zone: HeartRateZone.z3,
        rpe: 7,
        fcMaxPercent: 85,
      );
      final map = config.toMap();
      final restored = TargetConfig.fromMap(map);

      expect(restored.paceMinSecPerKm, 240);
      expect(restored.paceMaxSecPerKm, 300);
      expect(restored.zone, HeartRateZone.z3);
      expect(restored.rpe, 7);
      expect(restored.fcMaxPercent, 85);
    });

    test('toMap/fromMap con todos los campos null', () {
      const config = TargetConfig();
      final map = config.toMap();
      final restored = TargetConfig.fromMap(map);

      expect(restored.paceMinSecPerKm, isNull);
      expect(restored.paceMaxSecPerKm, isNull);
      expect(restored.zone, isNull);
      expect(restored.rpe, isNull);
      expect(restored.fcMaxPercent, isNull);
    });

    test('assert falla si paceMin > paceMax', () {
      expect(
        () => TargetConfig(paceMinSecPerKm: 350, paceMaxSecPerKm: 300),
        throwsA(isA<AssertionError>()),
      );
    });

    test('assert falla si rpe < 1', () {
      expect(
        () => TargetConfig(rpe: 0),
        throwsA(isA<AssertionError>()),
      );
    });

    test('assert falla si rpe > 10', () {
      expect(
        () => TargetConfig(rpe: 11),
        throwsA(isA<AssertionError>()),
      );
    });

    test('assert falla si fcMaxPercent < 1', () {
      expect(
        () => TargetConfig(fcMaxPercent: 0),
        throwsA(isA<AssertionError>()),
      );
    });

    test('assert falla si fcMaxPercent > 100', () {
      expect(
        () => TargetConfig(fcMaxPercent: 101),
        throwsA(isA<AssertionError>()),
      );
    });

    test('copyWith cambia solo el campo indicado', () {
      const original = TargetConfig(rpe: 5, fcMaxPercent: 80);
      final copy = original.copyWith(rpe: 8);

      expect(copy.rpe, 8);
      expect(copy.fcMaxPercent, 80);
      expect(copy.zone, isNull);
    });
  });

  // ─── WorkoutSegment ─────────────────────────────────────────────────────────

  group('WorkoutSegment', () {
    test('toMap/fromMap roundtrip segment interval por distancia', () {
      final segment = WorkoutSegment(
        id: 'seg-1',
        type: SegmentType.interval,
        distanceM: 400,
        target: const TargetConfig(rpe: 8),
      );
      final map = segment.toMap();
      final restored = WorkoutSegment.fromMap(map);

      expect(restored.id, 'seg-1');
      expect(restored.type, SegmentType.interval);
      expect(restored.distanceM, 400);
      expect(restored.durationSec, isNull);
      expect(restored.target?.rpe, 8);
    });

    test('toMap/fromMap roundtrip segment recovery por tiempo', () {
      final segment = WorkoutSegment(
        id: 'seg-2',
        type: SegmentType.recovery,
        durationSec: 90,
        recoveryType: RecoveryType.active,
      );
      final map = segment.toMap();
      final restored = WorkoutSegment.fromMap(map);

      expect(restored.id, 'seg-2');
      expect(restored.type, SegmentType.recovery);
      expect(restored.durationSec, 90);
      expect(restored.distanceM, isNull);
      expect(restored.recoveryType, RecoveryType.active);
    });

    test('assert falla si durationSec y distanceM son ambos null', () {
      expect(
        () => WorkoutSegment(type: SegmentType.interval),
        throwsA(isA<AssertionError>()),
      );
    });

    test('copyWith funciona correctamente', () {
      final original = WorkoutSegment(
        id: 'seg-3',
        type: SegmentType.interval,
        distanceM: 200,
      );
      final copy = original.copyWith(distanceM: 400, type: SegmentType.recovery);

      expect(copy.id, 'seg-3');
      expect(copy.distanceM, 400);
      expect(copy.type, SegmentType.recovery);
    });
  });

  // ─── WorkoutBlock ────────────────────────────────────────────────────────────

  group('WorkoutBlock', () {
    WorkoutSegment makeSegment(String id) => WorkoutSegment(
          id: id,
          type: SegmentType.interval,
          distanceM: 400,
        );

    test('toMap/fromMap roundtrip bloque main con 2 segmentos', () {
      final block = WorkoutBlock(
        id: 'block-1',
        role: BlockRole.main,
        repetitions: 4,
        segments: [makeSegment('s1'), makeSegment('s2')],
        label: 'Series 400',
      );
      final map = block.toMap();
      final restored = WorkoutBlock.fromMap(map);

      expect(restored.id, 'block-1');
      expect(restored.role, BlockRole.main);
      expect(restored.repetitions, 4);
      expect(restored.segments.length, 2);
      expect(restored.label, 'Series 400');
    });

    test('assert falla si warmup tiene repetitions != 1', () {
      expect(
        () => WorkoutBlock(
          role: BlockRole.warmup,
          repetitions: 3,
          segments: [makeSegment('s1')],
        ),
        throwsA(isA<AssertionError>()),
      );
    });

    test('assert falla si cooldown tiene repetitions != 1', () {
      expect(
        () => WorkoutBlock(
          role: BlockRole.cooldown,
          repetitions: 2,
          segments: [makeSegment('s1')],
        ),
        throwsA(isA<AssertionError>()),
      );
    });

    test('main permite repetitions > 1', () {
      final block = WorkoutBlock(
        role: BlockRole.main,
        repetitions: 6,
        segments: [makeSegment('s1')],
      );
      expect(block.repetitions, 6);
    });

    test('copyWith funciona correctamente', () {
      final original = WorkoutBlock(
        id: 'block-2',
        role: BlockRole.main,
        repetitions: 3,
        segments: [makeSegment('s1')],
      );
      final copy = original.copyWith(repetitions: 5, label: 'Nuevo label');

      expect(copy.id, 'block-2');
      expect(copy.repetitions, 5);
      expect(copy.label, 'Nuevo label');
      expect(copy.role, BlockRole.main);
    });
  });

  // ─── WorkoutSession ──────────────────────────────────────────────────────────

  group('WorkoutSession', () {
    WorkoutBlock makeBlock(String id, BlockRole role, {int reps = 1}) =>
        WorkoutBlock(
          id: id,
          role: role,
          repetitions: reps,
          segments: [
            WorkoutSegment(
              id: '$id-s1',
              type: SegmentType.interval,
              distanceM: 400,
            ),
          ],
        );

    WorkoutSession makeSession() => WorkoutSession(
          id: 'session-1',
          title: 'Test sesión',
          type: WorkoutType.intervals,
          blocks: [
            makeBlock('b-warmup', BlockRole.warmup),
            makeBlock('b-main', BlockRole.main, reps: 5),
            makeBlock('b-cooldown', BlockRole.cooldown),
          ],
          scheduledDate: DateTime(2026, 6, 1),
          isTemplate: false,
        );

    test('toMap/fromMap roundtrip sesión completa (warmup + main + cooldown)',
        () {
      final session = makeSession();
      final map = session.toMap();
      final restored = WorkoutSession.fromMap(map);

      expect(restored.id, 'session-1');
      expect(restored.title, 'Test sesión');
      expect(restored.type, WorkoutType.intervals);
      expect(restored.blocks.length, 3);
      expect(restored.scheduledDate, DateTime(2026, 6, 1));
      expect(restored.isTemplate, false);
    });

    test('getter warmupBlock devuelve el bloque correcto', () {
      final session = makeSession();
      expect(session.warmupBlock?.id, 'b-warmup');
    });

    test('getter warmupBlock devuelve null cuando no existe', () {
      final session = WorkoutSession(
        id: 's',
        title: 'Sin warmup',
        type: WorkoutType.free,
        blocks: [makeBlock('b-main', BlockRole.main)],
      );
      expect(session.warmupBlock, isNull);
    });

    test('getter mainBlocks devuelve solo los bloques main', () {
      final session = WorkoutSession(
        id: 's',
        title: 'Dos bloques main',
        type: WorkoutType.intervals,
        blocks: [
          makeBlock('b-main-1', BlockRole.main),
          makeBlock('b-main-2', BlockRole.main),
          makeBlock('b-cooldown', BlockRole.cooldown),
        ],
      );
      expect(session.mainBlocks.length, 2);
      expect(session.mainBlocks.every((b) => b.role == BlockRole.main), isTrue);
    });

    test('getter cooldownBlock devuelve el bloque correcto', () {
      final session = makeSession();
      expect(session.cooldownBlock?.id, 'b-cooldown');
    });

    test('getter cooldownBlock devuelve null cuando no existe', () {
      final session = WorkoutSession(
        id: 's',
        title: 'Sin cooldown',
        type: WorkoutType.free,
        blocks: [makeBlock('b-main', BlockRole.main)],
      );
      expect(session.cooldownBlock, isNull);
    });

    test('assert falla si blocks está vacío', () {
      expect(
        () => WorkoutSession(
          id: 's',
          title: 'Vacía',
          type: WorkoutType.free,
          blocks: [],
        ),
        throwsA(isA<AssertionError>()),
      );
    });

    test('assert falla si no hay ningún bloque con role == main', () {
      expect(
        () => WorkoutSession(
          id: 's',
          title: 'Sin main',
          type: WorkoutType.free,
          blocks: [makeBlock('b-warmup', BlockRole.warmup)],
        ),
        throwsA(isA<AssertionError>()),
      );
    });

    test('isTemplate true se serializa correctamente', () {
      final session = WorkoutSession(
        id: 's',
        title: 'Plantilla',
        type: WorkoutType.intervals,
        blocks: [makeBlock('b-main', BlockRole.main)],
        isTemplate: true,
        templateId: 'tmpl-42',
      );
      final map = session.toMap();
      final restored = WorkoutSession.fromMap(map);

      expect(restored.isTemplate, true);
      expect(restored.templateId, 'tmpl-42');
    });

    test('scheduledDate null se serializa correctamente', () {
      final session = WorkoutSession(
        id: 's',
        title: 'Sin fecha',
        type: WorkoutType.free,
        blocks: [makeBlock('b-main', BlockRole.main)],
      );
      final map = session.toMap();
      expect(map.containsKey('scheduledDate'), false);

      final restored = WorkoutSession.fromMap(map);
      expect(restored.scheduledDate, isNull);
    });
  });
}
