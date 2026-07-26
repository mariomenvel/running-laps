import 'package:flutter/material.dart' show TimeOfDay;
import 'package:flutter_test/flutter_test.dart';
import 'package:running_laps/core/widgets/main_shell.dart';
import 'package:running_laps/features/athlete/data/athlete_session_model.dart';
import 'package:running_laps/features/templates/data/workout_block.dart';
import 'package:running_laps/features/templates/data/workout_segment.dart';
import 'package:running_laps/features/templates/data/workout_session.dart';
import 'package:running_laps/features/templates/viewmodels/workout_editor_view_model.dart';

/// Lógica extraída de WorkoutEditorScreen al refactorizar a MVVM (jul 2026).
/// Solo se prueba lo que no toca Firebase: composición de la sesión, nombre
/// automático, bloques por defecto y detección de cambios sin guardar.
/// `save()` solo se prueba en su rama bloqueada, que retorna antes de tocar
/// repositorios.
void main() {
  WorkoutSession sessionWith({
    required WorkoutType type,
    required List<WorkoutBlock> blocks,
    String title = 'Mi sesión',
    String? notes,
  }) =>
      WorkoutSession(title: title, type: type, blocks: blocks, notes: notes);

  List<WorkoutBlock> mainOnly(WorkoutSegment segment, {int reps = 1}) => [
        WorkoutBlock(role: BlockRole.main, repetitions: reps, segments: [segment]),
      ];

  group('bloques por defecto', () {
    test('cada tipo trae plantilla propia y siempre un bloque principal', () {
      final vm = WorkoutEditorViewModel();
      addTearDown(vm.dispose);

      for (final type in WorkoutType.values) {
        final blocks = vm.defaultBlocksForType(type);
        expect(blocks, isNotEmpty, reason: 'sin bloques para $type');
        expect(
          blocks.where((b) => b.role == BlockRole.main),
          hasLength(1),
          reason: '$type debe tener exactamente un bloque principal',
        );
        // WorkoutSession lo exige: calentamiento y vuelta a la calma van a 1.
        expect(
          blocks
              .where((b) =>
                  b.role == BlockRole.warmup || b.role == BlockRole.cooldown)
              .every((b) => b.repetitions == 1),
          isTrue,
        );
      }
    });

    test('series arranca en 5×1000m con recuperación', () {
      final vm = WorkoutEditorViewModel();
      addTearDown(vm.dispose);

      final main = vm
          .defaultBlocksForType(WorkoutType.intervals)
          .firstWhere((b) => b.role == BlockRole.main);

      expect(main.repetitions, 5);
      expect(main.segments.first.distanceM, 1000);
      expect(main.segments.last.type, SegmentType.recovery);
    });
  });

  group('onTypeSelected', () {
    test('rellena bloques y nombre automático cuando no hay nada', () {
      final vm = WorkoutEditorViewModel();
      addTearDown(vm.dispose);

      vm.onTypeSelected(WorkoutType.fartlek);

      expect(vm.selectedType.value, WorkoutType.fartlek);
      expect(vm.title.value, 'Fartlek');
      expect(vm.blocks.value, isNotEmpty);
    });

    test('no pisa el nombre que escribió el usuario', () {
      final vm = WorkoutEditorViewModel();
      addTearDown(vm.dispose);

      vm.onTitleEdited('Tirada del domingo');
      vm.onTypeSelected(WorkoutType.continuous);

      expect(vm.title.value, 'Tirada del domingo');
    });

    test('no pisa bloques ya cargados', () {
      final vm = WorkoutEditorViewModel();
      addTearDown(vm.dispose);

      final mine = mainOnly(
        WorkoutSegment(type: SegmentType.interval, distanceM: 3000),
      );
      vm.onBlocksChanged(mine);
      vm.onTypeSelected(WorkoutType.intervals);

      expect(vm.blocks.value, same(mine));
    });
  });

  group('nombre automático al guardar', () {
    test('series por distancia → 5×1km', () {
      final vm = WorkoutEditorViewModel();
      addTearDown(vm.dispose);

      vm.onTypeSelected(WorkoutType.intervals);
      expect(vm.buildSession().title, '5×1km');
    });

    test('series por distancia sub-kilómetro → 8×400m', () {
      final vm = WorkoutEditorViewModel();
      addTearDown(vm.dispose);

      vm.onTypeSelected(WorkoutType.intervals);
      vm.onBlocksChanged(mainOnly(
        WorkoutSegment(type: SegmentType.interval, distanceM: 400),
        reps: 8,
      ));

      expect(vm.buildSession().title, '8×400m');
    });

    test('cuestas por tiempo con segundos sueltos → 6×1\'30"', () {
      final vm = WorkoutEditorViewModel();
      addTearDown(vm.dispose);

      vm.onTypeSelected(WorkoutType.hills);
      vm.onBlocksChanged(mainOnly(
        WorkoutSegment(type: SegmentType.interval, durationSec: 90),
        reps: 6,
      ));

      expect(vm.buildSession().title, '6×1\'30"');
    });

    test('rodaje por distancia → Rodaje 10km', () {
      final vm = WorkoutEditorViewModel();
      addTearDown(vm.dispose);

      vm.onTypeSelected(WorkoutType.continuous);
      vm.onBlocksChanged(mainOnly(
        WorkoutSegment(type: SegmentType.interval, distanceM: 10000),
      ));

      expect(vm.buildSession().title, 'Rodaje 10km');
    });

    test('el nombre escrito a mano gana al automático', () {
      final vm = WorkoutEditorViewModel();
      addTearDown(vm.dispose);

      vm.onTypeSelected(WorkoutType.intervals);
      vm.onTitleEdited('Test de umbral');

      expect(vm.buildSession().title, 'Test de umbral');
    });

    test('un título autogenerado previo se recalcula al cambiar los bloques',
        () {
      // initialSession con título == titleFromType: el viewmodel lo trata como
      // automático, así que debe regenerarse en vez de quedarse en "Series".
      final initial = sessionWith(
        type: WorkoutType.intervals,
        title: 'Series',
        blocks: mainOnly(
          WorkoutSegment(type: SegmentType.interval, distanceM: 1000),
          reps: 4,
        ),
      );
      final vm = WorkoutEditorViewModel(initialSession: initial);
      addTearDown(vm.dispose);

      vm.onBlocksChanged(mainOnly(
        WorkoutSegment(type: SegmentType.interval, distanceM: 2000),
        reps: 3,
      ));

      expect(vm.buildSession().title, '3×2km');
    });
  });

  group('buildSession', () {
    test('conserva id, plantilla y fecha de la sesión original', () {
      final initial = sessionWith(
        type: WorkoutType.continuous,
        blocks: mainOnly(
          WorkoutSegment(type: SegmentType.interval, durationSec: 1800),
        ),
      );
      final vm = WorkoutEditorViewModel(initialSession: initial);
      addTearDown(vm.dispose);

      final built = vm.buildSession();

      expect(built.id, initial.id);
      expect(built.isTemplate, initial.isTemplate);
      expect(built.templateId, initial.templateId);
    });

    test('sin tipo cae en sesión libre y nunca deja la lista de bloques vacía',
        () {
      final vm = WorkoutEditorViewModel();
      addTearDown(vm.dispose);

      final built = vm.buildSession();

      expect(built.type, WorkoutType.free);
      expect(built.blocks, hasLength(1));
      expect(built.blocks.first.role, BlockRole.main);
    });

    test('notas en blanco se guardan como null, no como cadena vacía', () {
      final vm = WorkoutEditorViewModel();
      addTearDown(vm.dispose);

      vm.onTypeSelected(WorkoutType.continuous);
      vm.onNotesChanged('   ');

      expect(vm.buildSession().notes, isNull);
    });
  });

  group('hasChanges', () {
    test('sesión nueva sin tocar nada: no hay cambios', () {
      final vm = WorkoutEditorViewModel();
      addTearDown(vm.dispose);

      expect(vm.hasChanges(), isFalse);
    });

    test('sesión existente sin tocar nada: no hay cambios', () {
      final initial = sessionWith(
        type: WorkoutType.continuous,
        blocks: mainOnly(
          WorkoutSegment(type: SegmentType.interval, durationSec: 1800),
        ),
      );
      final vm = WorkoutEditorViewModel(initialSession: initial);
      addTearDown(vm.dispose);

      expect(vm.hasChanges(), isFalse);
    });

    test('sesión abierta desde el calendario sin tocar nada: no hay cambios',
        () {
      // Regresión (vista en dispositivo, 26 jul 2026): al abrir una sesión
      // planificada el editor la recibe por `shellParams.session`, no por
      // `initialSession`. Comparando solo contra `initialSession`, hasChanges()
      // caía en la rama de "sesión nueva" y devolvía true siempre, así que al
      // salir preguntaba "¿Salir sin guardar?" sin haber tocado nada.
      final planned = AthleteSession(
        id: 'planned-1',
        uid: 'u1',
        date: '2026-07-20',
        category: 'series_largas',
        status: AthleteSessionStatus.planned,
        blocks: const [
          SessionBlock(
            id: 'b1',
            order: 0,
            type: SessionBlockType.series,
            reps: 5,
            distanceM: 1000,
            restSeconds: 90,
          ),
        ],
        createdAt: DateTime(2026, 7, 19),
        updatedAt: DateTime(2026, 7, 19),
      );
      final vm = WorkoutEditorViewModel(
        shellParams: AthleteSessionShellParams(
          date: '2026-07-20',
          session: planned,
        ),
      );
      addTearDown(vm.dispose);

      expect(vm.hasChanges(), isFalse);

      vm.onNotesChanged('cambio de verdad');
      expect(vm.hasChanges(), isTrue);
    });

    test('detecta cambios en notas y en hora', () {
      final initial = sessionWith(
        type: WorkoutType.continuous,
        blocks: mainOnly(
          WorkoutSegment(type: SegmentType.interval, durationSec: 1800),
        ),
      );

      final vmNotes = WorkoutEditorViewModel(initialSession: initial);
      addTearDown(vmNotes.dispose);
      vmNotes.onNotesChanged('sensaciones raras');
      expect(vmNotes.hasChanges(), isTrue);

      final vmTime = WorkoutEditorViewModel(initialSession: initial);
      addTearDown(vmTime.dispose);
      vmTime.setScheduledTime(const TimeOfDay(hour: 7, minute: 30));
      expect(vmTime.hasChanges(), isTrue);
    });
  });

  group('save', () {
    test('bloquea el guardado sin tipo ni bloques', () async {
      final vm = WorkoutEditorViewModel();
      addTearDown(vm.dispose);

      final result = await vm.save();

      expect(result.blocked, isTrue);
      expect(result.session, isNull);
    });

    test('en inicio rápido no bloquea aunque no haya tipo ni bloques', () async {
      final vm = WorkoutEditorViewModel(isQuickStart: true);
      addTearDown(vm.dispose);

      final result = await vm.save();

      expect(result.blocked, isFalse);
      expect(result.session, isNotNull);
    });
  });
}
