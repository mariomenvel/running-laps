import 'package:flutter_test/flutter_test.dart';
import 'package:running_laps/features/ai_coach/data/race_goal.dart';

RaceGoal _goal({
  String id = 'g1',
  String date = '2026-08-12',
  RaceDistance distance = RaceDistance.k5,
  int? customDistanceM,
  String? name,
  int? targetTimeSeconds,
  RaceGoalPriority priority = RaceGoalPriority.high,
}) {
  final now = DateTime(2026, 7, 1);
  return RaceGoal(
    id: id,
    date: date,
    distance: distance,
    customDistanceM: customDistanceM,
    name: name,
    targetTimeSeconds: targetTimeSeconds,
    priority: priority,
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  group('RaceDistance', () {
    test('fromMeters mapea las distancias estándar', () {
      expect(RaceDistanceX.fromMeters(5000), RaceDistance.k5);
      expect(RaceDistanceX.fromMeters(10000), RaceDistance.k10);
      expect(RaceDistanceX.fromMeters(21097), RaceDistance.halfMarathon);
      expect(RaceDistanceX.fromMeters(42195), RaceDistance.marathon);
      expect(RaceDistanceX.fromMeters(15000), RaceDistance.other);
      expect(RaceDistanceX.fromMeters(null), RaceDistance.other);
    });

    test('toValue / fromValue son consistentes (round-trip)', () {
      for (final d in RaceDistance.values) {
        expect(RaceDistanceX.fromValue(d.toValue), d);
      }
    });

    test('standardMeters coincide con los metros oficiales', () {
      expect(RaceDistance.k5.standardMeters, 5000);
      expect(RaceDistance.k10.standardMeters, 10000);
      expect(RaceDistance.halfMarathon.standardMeters, 21097);
      expect(RaceDistance.marathon.standardMeters, 42195);
      expect(RaceDistance.other.standardMeters, isNull);
    });
  });

  group('RaceGoalPriority', () {
    test('toValue / fromValue round-trip', () {
      for (final p in RaceGoalPriority.values) {
        expect(RaceGoalPriorityX.fromValue(p.toValue), p);
      }
    });

    test('fromValue desconocido cae en medium', () {
      expect(RaceGoalPriorityX.fromValue('???'), RaceGoalPriority.medium);
    });
  });

  group('RaceGoal serialización', () {
    test('toMap/fromMap conserva todos los campos', () {
      final goal = _goal(
        name: 'Carrera del Cole',
        targetTimeSeconds: 1320,
        priority: RaceGoalPriority.medium,
      );
      final restored = RaceGoal.fromMap(goal.id, goal.toMap());

      expect(restored.id, goal.id);
      expect(restored.date, goal.date);
      expect(restored.distance, goal.distance);
      expect(restored.name, 'Carrera del Cole');
      expect(restored.targetTimeSeconds, 1320);
      expect(restored.priority, RaceGoalPriority.medium);
    });

    test('toMap omite los opcionales nulos', () {
      final map = _goal().toMap();
      expect(map.containsKey('name'), isFalse);
      expect(map.containsKey('targetTimeSeconds'), isFalse);
      expect(map.containsKey('customDistanceM'), isFalse);
    });

    test('distanceMeters usa el estándar o el custom', () {
      expect(_goal(distance: RaceDistance.k10).distanceMeters, 10000);
      expect(
        _goal(distance: RaceDistance.other, customDistanceM: 15000)
            .distanceMeters,
        15000,
      );
    });
  });

  group('displayTitle', () {
    test('distancia estándar sin nombre', () {
      expect(_goal(distance: RaceDistance.k5).displayTitle, '5K');
    });

    test('incluye el nombre cuando existe', () {
      expect(
        _goal(distance: RaceDistance.k10, name: '10K Villa').displayTitle,
        '10K · 10K Villa',
      );
    });

    test('distancia custom se expresa en km', () {
      expect(
        _goal(distance: RaceDistance.other, customDistanceM: 15000)
            .displayTitle,
        '15K',
      );
    });
  });

  group('selección de objetivos (RaceGoalListX)', () {
    final now = DateTime(2026, 8, 1);

    test('upcomingFrom descarta pasadas y ordena por fecha', () {
      final goals = [
        _goal(id: 'past', date: '2026-07-01'),
        _goal(id: 'later', date: '2026-09-10'),
        _goal(id: 'soon', date: '2026-08-05'),
      ];
      final upcoming = goals.upcomingFrom(now);
      expect(upcoming.map((g) => g.id), ['soon', 'later']);
    });

    test('nextPrimaryFrom devuelve la primera de prioridad alta', () {
      final goals = [
        _goal(id: 'b', date: '2026-08-05', priority: RaceGoalPriority.medium),
        _goal(id: 'a', date: '2026-08-20', priority: RaceGoalPriority.high),
      ];
      expect(goals.nextPrimaryFrom(now)?.id, 'a');
    });

    test('nextPrimaryFrom es null si no hay ninguna alta próxima', () {
      final goals = [
        _goal(id: 'b', date: '2026-08-05', priority: RaceGoalPriority.low),
      ];
      expect(goals.nextPrimaryFrom(now), isNull);
    });

    test('nextAnyFrom devuelve la próxima de cualquier prioridad', () {
      final goals = [
        _goal(id: 'a', date: '2026-08-20', priority: RaceGoalPriority.high),
        _goal(id: 'b', date: '2026-08-05', priority: RaceGoalPriority.low),
      ];
      expect(goals.nextAnyFrom(now)?.id, 'b');
    });

    test('incluye el día de hoy como próximo', () {
      final goals = [_goal(id: 'today', date: '2026-08-01')];
      expect(goals.upcomingFrom(now).map((g) => g.id), ['today']);
    });
  });
}
