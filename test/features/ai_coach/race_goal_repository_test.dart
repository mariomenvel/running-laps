import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:running_laps/features/ai_coach/data/race_goal.dart';
import 'package:running_laps/features/ai_coach/data/race_goal_repository.dart';

const _uid = 'test-uid-123';

RaceGoal _goal({
  String id = '',
  String date = '2026-08-12',
  RaceDistance distance = RaceDistance.k5,
  RaceGoalPriority priority = RaceGoalPriority.high,
  String? name,
}) {
  final now = DateTime(2026, 7, 1);
  return RaceGoal(
    id: id,
    date: date,
    distance: distance,
    name: name,
    priority: priority,
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  late FakeFirebaseFirestore fakeFs;
  late RaceGoalRepository repo;

  setUp(() {
    fakeFs = FakeFirebaseFirestore();
    repo = RaceGoalRepository(firestore: fakeFs);
  });

  group('saveGoal', () {
    test('crea el documento y devuelve el objetivo con id generado', () async {
      final saved = await repo.saveGoal(_goal(), uid: _uid);

      expect(saved.id, isNotEmpty);
      final doc = await fakeFs
          .collection('users')
          .doc(_uid)
          .collection('raceGoals')
          .doc(saved.id)
          .get();
      expect(doc.exists, isTrue);
      expect(doc.data()!['distance'], '5k');
      expect(doc.data()!['priority'], 'high');
    });

    test('respeta el id existente al actualizar', () async {
      final created = await repo.saveGoal(_goal(name: 'Original'), uid: _uid);
      final edited = created.copyWith(name: 'Editada');
      await repo.saveGoal(edited, uid: _uid);

      final goals = await repo.getGoals(uid: _uid);
      expect(goals.length, 1);
      expect(goals.first.id, created.id);
      expect(goals.first.name, 'Editada');
    });
  });

  group('getGoals', () {
    test('devuelve lista vacía sin objetivos', () async {
      expect(await repo.getGoals(uid: _uid), isEmpty);
    });

    test('devuelve los objetivos ordenados por fecha ascendente', () async {
      await repo.saveGoal(_goal(date: '2026-09-10'), uid: _uid);
      await repo.saveGoal(_goal(date: '2026-08-01'), uid: _uid);
      await repo.saveGoal(_goal(date: '2026-08-20'), uid: _uid);

      final goals = await repo.getGoals(uid: _uid);
      expect(goals.map((g) => g.date),
          ['2026-08-01', '2026-08-20', '2026-09-10']);
    });
  });

  group('streamGoals', () {
    test('emite los objetivos actuales', () async {
      await repo.saveGoal(_goal(date: '2026-08-05'), uid: _uid);
      final goals = await repo.streamGoals(uid: _uid).first;
      expect(goals.length, 1);
      expect(goals.first.date, '2026-08-05');
    });
  });

  group('deleteGoal', () {
    test('elimina el objetivo', () async {
      final saved = await repo.saveGoal(_goal(), uid: _uid);
      await repo.deleteGoal(saved.id, uid: _uid);
      expect(await repo.getGoals(uid: _uid), isEmpty);
    });
  });
}
