import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:running_laps/features/templates/data/templates_repository.dart';
import 'package:running_laps/features/templates/data/workout_block.dart';
import 'package:running_laps/features/templates/data/workout_segment.dart';
import 'package:running_laps/features/templates/data/workout_session.dart';

// Subclase que inyecta el uid sin necesidad de Firebase Auth real.
class _TestableRepo extends TrainingTemplatesRepository {
  final String fakeUid;

  _TestableRepo({required FakeFirebaseFirestore firestore, required this.fakeUid})
      : super(firestore: firestore);

  @override
  String? get currentUserId => fakeUid;
}

const _uid = 'test-uid-123';

WorkoutSession _makeSession({String id = 'session-abc'}) => WorkoutSession(
      id: id,
      title: 'Test Session',
      type: WorkoutType.intervals,
      blocks: [
        WorkoutBlock(
          id: 'block-1',
          role: BlockRole.main,
          repetitions: 4,
          segments: [
            WorkoutSegment(
              id: 'seg-1',
              type: SegmentType.interval,
              distanceM: 400,
            ),
          ],
        ),
      ],
      isTemplate: true,
    );

// Acceso directo a la colección del usuario en el Firestore fake.
CollectionReference _col(FakeFirebaseFirestore fs) =>
    fs.collection('users').doc(_uid).collection('templates');

void main() {
  late FakeFirebaseFirestore fakeFs;
  late _TestableRepo repo;

  setUp(() {
    fakeFs = FakeFirebaseFirestore();
    repo = _TestableRepo(firestore: fakeFs, fakeUid: _uid);
  });

  // ─── saveWorkoutSession ────────────────────────────────────────────────────

  group('saveWorkoutSession', () {
    test('el documento existe en Firestore tras guardar', () async {
      final session = _makeSession();
      await repo.saveWorkoutSession(session);

      final doc = await _col(fakeFs).doc(session.id).get();
      expect(doc.exists, isTrue);
    });

    test('el documento guardado contiene el campo blocks', () async {
      final session = _makeSession();
      await repo.saveWorkoutSession(session);

      final doc = await _col(fakeFs).doc(session.id).get();
      final data = doc.data() as Map<String, dynamic>;
      expect(data.containsKey('blocks'), isTrue);
    });
  });

  // ─── getWorkoutSession ─────────────────────────────────────────────────────

  group('getWorkoutSession', () {
    test('devuelve la sesión correcta por id', () async {
      final session = _makeSession();
      await repo.saveWorkoutSession(session);

      final result = await repo.getWorkoutSession(session.id);
      expect(result, isNotNull);
      expect(result!.id, session.id);
      expect(result.title, 'Test Session');
      expect(result.type, WorkoutType.intervals);
    });

    test('devuelve null si el id no existe', () async {
      final result = await repo.getWorkoutSession('no-existe');
      expect(result, isNull);
    });

    test('ignora documentos legacy sin campo blocks', () async {
      await _col(fakeFs).doc('legacy-1').set({
        'title': 'Plantilla vieja',
        'createdAt': Timestamp.now(),
      });

      final result = await repo.getWorkoutSession('legacy-1');
      expect(result, isNull);
    });
  });

  // ─── getWorkoutSessions ────────────────────────────────────────────────────

  group('getWorkoutSessions', () {
    test('devuelve lista vacía si no hay documentos', () async {
      final result = await repo.getWorkoutSessions();
      expect(result, isEmpty);
    });

    test('ignora documentos legacy y devuelve solo los que tienen blocks', () async {
      // Documento legacy
      await _col(fakeFs).doc('legacy-1').set({
        'title': 'Plantilla vieja',
        'createdAt': Timestamp.now(),
      });
      // Documento nuevo
      await repo.saveWorkoutSession(_makeSession(id: 'session-1'));

      final result = await repo.getWorkoutSessions();
      expect(result.length, 1);
      expect(result.first.id, 'session-1');
    });

    test('devuelve todas las WorkoutSession correctamente deserializadas', () async {
      await repo.saveWorkoutSession(_makeSession(id: 'session-1'));
      await repo.saveWorkoutSession(_makeSession(id: 'session-2'));
      await repo.saveWorkoutSession(_makeSession(id: 'session-3'));

      final result = await repo.getWorkoutSessions();
      expect(result.length, 3);
      expect(result.map((s) => s.id).toSet(),
          {'session-1', 'session-2', 'session-3'});
      expect(result.every((s) => s.type == WorkoutType.intervals), isTrue);
    });
  });

  // ─── updateWorkoutSession ──────────────────────────────────────────────────

  group('updateWorkoutSession', () {
    test('actualiza el título y verifica el cambio en Firestore', () async {
      final session = _makeSession();
      await repo.saveWorkoutSession(session);

      final updated = session.copyWith(title: 'Título actualizado');
      await repo.updateWorkoutSession(updated);

      final doc = await _col(fakeFs).doc(session.id).get();
      final data = doc.data() as Map<String, dynamic>;
      expect(data['title'], 'Título actualizado');
    });
  });

  // ─── deleteWorkoutSession ──────────────────────────────────────────────────

  group('deleteWorkoutSession', () {
    test('elimina el documento y verifica que ya no existe', () async {
      final session = _makeSession();
      await repo.saveWorkoutSession(session);

      await repo.deleteWorkoutSession(session.id);

      final doc = await _col(fakeFs).doc(session.id).get();
      expect(doc.exists, isFalse);
    });
  });
}
