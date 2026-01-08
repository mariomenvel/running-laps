import 'package:flutter_test/flutter_test.dart';
import 'package:running_laps/features/groups/data/challenge_calculator.dart';
import 'package:running_laps/features/groups/data/challenge_models.dart';
import 'package:running_laps/features/groups/data/challenge_helpers.dart'; // Needed for ChallengeGoal
import 'package:running_laps/features/groups/data/enums.dart';
import 'package:running_laps/features/training/data/entrenamiento.dart';
import 'package:running_laps/features/training/data/serie.dart';

void main() {
  group('ChallengeCalculator', () {
    // Helpers
    Challenge createChallenge({
      required ChallengeMetric metric,
      required double goalValue,
    }) {
      return Challenge(
        id: 'c1',
        title: 'Test',
        periodKey: '2025-W01', // Added periodKey
        metric: metric,
        goal: ChallengeGoal(kind: GoalKind.distance, value: goalValue), // Kind mapping simplified for test
        startAt: DateTime(2025, 1, 1),
        endAt: DateTime(2025, 1, 8),
        origin: ChallengeOrigin.template,
        status: ChallengeStatus.active,
        aggregation: ChallengeAggregation.sum, // Added
        filters: const ChallengeFilters(), // Added
        tieBreakers: const [], // Added
        awardsMedals: true, // Added
        awardsBadges: true, // Added
        createdAt: DateTime.now(),
        createdBy: 'system',
      );
    }

    ChallengeParticipant createBaseParticipant() {
      return ChallengeParticipant(
        uid: 'u1',
        score: 0,
        joinedAt: DateTime(2025, 1, 1),
        lastUpdatedAt: DateTime.now(),
      );
    }
    
    Entrenamiento createTraining({
      required DateTime fecha,
      required int distanceM,
      required double timeSec,
    }) {
      return Entrenamiento(
        id: 't_${fecha.millisecondsSinceEpoch}',
        // uid: 'u1', // Removed invalid uid
        titulo: 'Test Run', // Added required title
        fecha: fecha,
        // origen: 'manual', // invalid field? Check model. Model doesn't have origen.
        gps: false, // Added required gps
        // validado: true, // invalid field? Check model.
        series: [
          Serie(
            // tipo: 'Carrera', // Removed invalid
            distanciaM: distanceM,
            tiempoSec: timeSec,
            // repeticiones: 1, // Removed invalid
            descansoSec: 0,
            rpe: 5.0,
          )
        ],
      );
    }

    test('Calculates earliestCompletion for DISTANCE (Cumulative)', () {
      final challenge = createChallenge(metric: ChallengeMetric.distance, goalValue: 1000); // Goal: 1000m
      
      final t1 = createTraining(fecha: DateTime(2025, 1, 1, 10, 0), distanceM: 400, timeSec: 100);
      final t2 = createTraining(fecha: DateTime(2025, 1, 2, 10, 0), distanceM: 400, timeSec: 100); // 800m total
      final t3 = createTraining(fecha: DateTime(2025, 1, 3, 10, 0), distanceM: 400, timeSec: 100); // 1200m total (Goal met here!)
      final t4 = createTraining(fecha: DateTime(2025, 1, 4, 10, 0), distanceM: 400, timeSec: 100); // 1600m total
      
      final result = ChallengeCalculator.computeState(
        currentParticipant: createBaseParticipant(),
        validTrainings: [t1, t2, t3, t4],
        challenge: challenge,
      );
      
      expect(result.score, 1600);
      expect(result.distanceM, 1600);
      expect(result.reachedGoalAt, isNotNull);
      // specific moment: t3 end. t3 starts 10:00, duration 100s -> 10:01:40
      expect(result.reachedGoalAt, t3.fecha.add(const Duration(seconds: 100)));
    });

    test('Calculates earliestCompletion for TIME (Cumulative)', () {
      final challenge = createChallenge(metric: ChallengeMetric.time, goalValue: 3600); // Goal: 1h (3600s)
      
      final t1 = createTraining(fecha: DateTime(2025, 1, 1), distanceM: 5000, timeSec: 2000);
      final t2 = createTraining(fecha: DateTime(2025, 1, 2), distanceM: 5000, timeSec: 2000); // 4000s total (Goal met)
      
      final result = ChallengeCalculator.computeState(
        currentParticipant: createBaseParticipant(),
        validTrainings: [t1, t2],
        challenge: challenge,
      );
      
      expect(result.score, 4000);
      expect(result.reachedGoalAt, t2.fecha.add(const Duration(seconds: 2000)));
    });

    test('Calculates earliestCompletion for BEST PACE', () {
      // Goal: 300 s/km (5:00 min/km). Lower is better.
      final challenge = createChallenge(metric: ChallengeMetric.bestPace, goalValue: 300);
      
      // T1: 6:00 min/km (360s). Not met.
      final t1 = createTraining(fecha: DateTime(2025, 1, 1), distanceM: 1000, timeSec: 360);
      // T2: 5:00 min/km (300s). Met exactly!
      final t2 = createTraining(fecha: DateTime(2025, 1, 2), distanceM: 1000, timeSec: 300); 
      // T3: 4:00 min/km (240s). Met (better), but earliest was T2.
      final t3 = createTraining(fecha: DateTime(2025, 1, 3), distanceM: 1000, timeSec: 240);
      
      final result = ChallengeCalculator.computeState(
        currentParticipant: createBaseParticipant(),
        validTrainings: [t1, t2, t3],
        challenge: challenge,
      );
      
      expect(result.bestPaceSecPerKm, 240); // Score tracks best ever
      expect(result.reachedGoalAt, t2.fecha.add(const Duration(seconds: 300))); // Earliest met
    });

    test('Handles null result if goal never met', () {
      final challenge = createChallenge(metric: ChallengeMetric.distance, goalValue: 1000);
      final t1 = createTraining(fecha: DateTime(2025, 1, 1), distanceM: 500, timeSec: 300);
      
      final result = ChallengeCalculator.computeState(
        currentParticipant: createBaseParticipant(),
        validTrainings: [t1],
        challenge: challenge,
      );
      
      expect(result.score, 500);
      expect(result.reachedGoalAt, isNull);
    });
  });
}
