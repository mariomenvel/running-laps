import 'package:flutter_test/flutter_test.dart';
import 'package:running_laps/features/templates/data/athlete_session_mapper.dart';
import 'package:running_laps/features/templates/data/workout_block.dart';
import 'package:running_laps/features/templates/data/workout_segment.dart';
import 'package:running_laps/features/templates/data/workout_session.dart';

void main() {
  group('athlete_session_mapper', () {
    test('round-trip WorkoutType -> category -> WorkoutType preserva el tipo original', () {
      for (final type in WorkoutType.values) {
        final session = WorkoutSession(
          title: 'Sesión de prueba',
          type: type,
          blocks: [
            WorkoutBlock(
              role: BlockRole.main,
              repetitions: 1,
              segments: [WorkoutSegment(type: SegmentType.interval, durationSec: 60)],
            ),
          ],
        );

        final athleteSession = mapWorkoutSessionToAthlete(session, uid: 'test-uid');
        final roundTripped = mapAthleteSessionToWorkout(athleteSession);

        expect(
          roundTripped!.type,
          type,
          reason: "WorkoutType.${type.name} no sobrevive el round-trip "
              "(category guardada: '${athleteSession.category}')",
        );
      }
    });
  });
}
