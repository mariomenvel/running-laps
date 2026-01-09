import 'package:flutter_test/flutter_test.dart';
import 'package:running_laps/features/groups/data/helpers/challenge_ranking_helper.dart';
import 'package:running_laps/features/groups/data/models/challenge_models.dart';
import 'package:running_laps/features/groups/data/helpers/challenge_helpers.dart'; // Needed for ChallengeGoal
import 'package:running_laps/features/groups/data/models/enums.dart';

void main() {
  group('ChallengeRankingHelper', () {
    // Helpers to create dummy objects
    Challenge createChallenge({
      required ChallengeMetric metric,
      required double goalValue,
      List<TieBreakerType> tieBreakers = const [],
      ChallengeGoal? goal,
    }) {
      return Challenge(
        id: 'c1',
        title: 'Test',
        periodKey: '2025-W01', // Added
        aggregation: ChallengeAggregation.sum, // Added
        filters: const ChallengeFilters(), // Added
        awardsMedals: true, // Added
        awardsBadges: true, // Added
        metric: metric,
        goal: goal ?? ChallengeGoal(kind: GoalKind.distance, value: goalValue),
        startAt: DateTime(2025, 1, 1),
        endAt: DateTime(2025, 1, 8),
        origin: ChallengeOrigin.template,
        status: ChallengeStatus.active,
        tieBreakers: tieBreakers,
        createdAt: DateTime.now(),
        createdBy: 'system',
      );
    }

    ChallengeParticipant createParticipant({
      required String uid,
      required double score,
      DateTime? joinedAt,
      DateTime? reachedGoalAt,
      int sessions = 0,
      int distanceM = 0,
      double timeSec = 0,
    }) {
      return ChallengeParticipant(
        uid: uid,
        score: score,
        joinedAt: joinedAt ?? DateTime(2025, 1, 1),
        lastUpdatedAt: DateTime.now(),
        reachedGoalAt: reachedGoalAt,
        sessions: sessions,
        distanceM: distanceM,
        timeSec: timeSec,
      );
    }

    test('Sorts DISTANCE (higher is better)', () {
      final p1 = createParticipant(uid: 'p1', score: 100);
      final p2 = createParticipant(uid: 'p2', score: 200);
      final p3 = createParticipant(uid: 'p3', score: 50);
      
      final challenge = createChallenge(metric: ChallengeMetric.distance, goalValue: 1000);
      
      final sorted = ChallengeRankingHelper.sortParticipants([p1, p2, p3], challenge);
      
      expect(sorted.map((e) => e.uid).toList(), ['p2', 'p1', 'p3']);
    });

    test('Sorts BEST_PACE (lower is better, excluding 0/negative)', () {
      final p1 = createParticipant(uid: 'p1', score: 300); // 5 min/km
      final p2 = createParticipant(uid: 'p2', score: 240); // 4 min/km (Best)
      final p3 = createParticipant(uid: 'p3', score: 0);   // Invalid/No effort
      
      final challenge = createChallenge(metric: ChallengeMetric.bestPace, goalValue: 300);
      
      final sorted = ChallengeRankingHelper.sortParticipants([p1, p2, p3], challenge);
      
      // Best (lowest valid) first, then higher, then invalid (0) at end?
      // Helper logic: if score <= 0 return 1 (move to end).
      expect(sorted.map((e) => e.uid).toList(), ['p2', 'p1', 'p3']);
    });

    test('TieBreaker: EarliestJoin', () {
      // Same score
      final p1 = createParticipant(uid: 'p1', score: 100, joinedAt: DateTime(2025, 1, 2));
      final p2 = createParticipant(uid: 'p2', score: 100, joinedAt: DateTime(2025, 1, 1)); // Earlier join
      
      final challenge = createChallenge(
        metric: ChallengeMetric.distance, 
        goalValue: 1000,
        tieBreakers: [TieBreakerType.earliestJoin],
      );
      
      final sorted = ChallengeRankingHelper.sortParticipants([p1, p2], challenge);
      
      expect(sorted.first.uid, 'p2');
    });

    test('TieBreaker: EarliestCompletion', () {
      // Same score (met goal)
      final p1 = createParticipant(
        uid: 'p1', 
        score: 1000, 
        reachedGoalAt: DateTime(2025, 1, 5, 10, 0), // Later
      );
      final p2 = createParticipant(
        uid: 'p2', 
        score: 1000, 
        reachedGoalAt: DateTime(2025, 1, 5, 9, 0), // Earlier completion
      );
      
      final challenge = createChallenge(
        metric: ChallengeMetric.distance, 
        goalValue: 1000,
        tieBreakers: [TieBreakerType.earliestCompletion],
      );
      
      final sorted = ChallengeRankingHelper.sortParticipants([p1, p2], challenge);
      
      expect(sorted.first.uid, 'p2');
    });

    test('hasMetGoal validation', () {
      final challengeDist = createChallenge(metric: ChallengeMetric.distance, goalValue: 100);
      
      expect(ChallengeRankingHelper.hasMetGoal(createParticipant(uid: '1', score: 99), challengeDist), false);
      expect(ChallengeRankingHelper.hasMetGoal(createParticipant(uid: '1', score: 100), challengeDist), true);
      expect(ChallengeRankingHelper.hasMetGoal(createParticipant(uid: '1', score: 150), challengeDist), true);

      final challengePace = createChallenge(
        metric: ChallengeMetric.bestPace, 
        goalValue: 300, 
        goal: ChallengeGoal(kind: GoalKind.bestPace, value: 300)
      );
      
      // Lower is better. 290 is faster than 300.
      expect(ChallengeRankingHelper.hasMetGoal(createParticipant(uid: '1', score: 290), challengePace), true);
      // 310 is slower than 300.
      expect(ChallengeRankingHelper.hasMetGoal(createParticipant(uid: '1', score: 310), challengePace), false);
      // 0 is invalid
      expect(ChallengeRankingHelper.hasMetGoal(createParticipant(uid: '1', score: 0), challengePace), false);
    });
  });
}

