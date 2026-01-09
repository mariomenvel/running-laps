import '../models/challenge_models.dart';
import '../models/enums.dart';

/// Helper class for ranking challenge participants and validating goals
class ChallengeRankingHelper {
  /// Determines if a lower score is better for the given metric
  static bool isLowerScoreBetter(ChallengeMetric metric) {
    switch (metric) {
      case ChallengeMetric.bestPace:
      case ChallengeMetric.avgPace:
        return true; // Lower pace (e.g., 4:00/km) is better than higher (5:00/km)
      case ChallengeMetric.distance:
      case ChallengeMetric.time:
      case ChallengeMetric.sessions: // Assuming 'sessions' isn't used as a metric usually but if so, more is better
        return false; // Higher is better
    }
  }

  /// Determines if a participant has met the challenge goal
  static bool hasMetGoal(ChallengeParticipant participant, Challenge challenge) {
    if (participant.score <= 0 && isLowerScoreBetter(challenge.goal.kind.toMetric()) == false) {
       // If higher is better (distance, time) and score is 0, goal not met (unless goal is 0 which is trivial)
       if (challenge.goal.value > 0) return false;
    }
    
    // Convert goal kind to metric to check directionality
    // NOTE: GoalKind usually maps 1:1 to Metric for simple challenges, 
    // but a challenge could have metric=distance and goal=sessions? 
    // Phase 1 requirements implied consistency, but let's be safe.
    // For MVP, we compare participant.score against challenge.goal.value directly
    // based on the CHALLENGE METRIC direction key.
    
    final lowerIsBetter = isLowerScoreBetter(challenge.metric);
    
    if (lowerIsBetter) {
      // Example: Pace 4:30 <= Goal 5:00 -> True (Better)
      // Must have valid score (>0) to count as having a pace
      if (participant.score <= 0) return false; 
      return participant.score <= challenge.goal.value;
    } else {
      // Example: Distance 10km >= Goal 5km -> True
      return participant.score >= challenge.goal.value;
    }
  }

  /// Sorts participants based on challenge metric and tie-breakers
  /// Returns a new sorted list
  static List<ChallengeParticipant> sortParticipants(
    List<ChallengeParticipant> participants,
    Challenge challenge,
  ) {
    final sorted = List<ChallengeParticipant>.from(participants);
    final lowerIsBetter = isLowerScoreBetter(challenge.metric);

    sorted.sort((a, b) {
      // 1. Primary Metric (Score)
      if (a.score != b.score) {
        if (lowerIsBetter) {
          // ASC (smaller is better)
          // Handle 0 or nulls? Assuming score 0 means "no effort" for pace?
          // For pace, 0 usually means "undefined/slow", so it should be last.
          if (a.score <= 0) return 1; // a is worse (move to end)
          if (b.score <= 0) return -1; // b is worse
          return a.score.compareTo(b.score);
        } else {
          // DESC (larger is better)
          return b.score.compareTo(a.score);
        }
      }

      // 2. Tie Breakers
      for (final breaker in challenge.tieBreakers) {
        final result = _compareTieBreaker(a, b, breaker);
        if (result != 0) return result;
      }

      // 3. Fallback: Joined date (earliest wins strategy favored generally)
      return a.joinedAt.compareTo(b.joinedAt);
    });

    return sorted;
  }

  static int _compareTieBreaker(
    ChallengeParticipant a,
    ChallengeParticipant b,
    TieBreakerType type,
  ) {
    switch (type) {
      case TieBreakerType.sessions:
        // More sessions is better
        return b.sessions.compareTo(a.sessions);
        
      case TieBreakerType.distance:
        // More distance is better
        return b.distanceM.compareTo(a.distanceM);
        
      case TieBreakerType.time:
        // More time is better (usually implies more effort)
        return b.timeSec.compareTo(a.timeSec);
        
      case TieBreakerType.earliestJoin:
        // Earlier is better (ASC)
        return a.joinedAt.compareTo(b.joinedAt);
        
      case TieBreakerType.earliestCompletion:
        // Earlier last update is better (ASC) - implies they reached the score sooner
        // Using lastTrainingAt as proxy for "completion or progress time"
        final dateA = a.reachedGoalAt ?? a.lastTrainingAt ?? a.lastUpdatedAt;
        final dateB = b.reachedGoalAt ?? b.lastTrainingAt ?? b.lastUpdatedAt;
        return dateA.compareTo(dateB);

      case TieBreakerType.consistency:
         // TODO: Implement proper consistency check. For now, treat as equal or fallback.
         return 0;
    }
  }
}

extension GoalKindExtension on GoalKind {
  ChallengeMetric toMetric() {
    switch (this) {
      case GoalKind.distance: return ChallengeMetric.distance;
      case GoalKind.time: return ChallengeMetric.time;
      case GoalKind.sessions: return ChallengeMetric.sessions;
      case GoalKind.sessions: return ChallengeMetric.sessions;
      default: return ChallengeMetric.distance;
    }
  }
}


