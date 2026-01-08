import 'package:running_laps/features/training/data/entrenamiento.dart';
import 'challenge_models.dart';
import 'challenge_ranking_helper.dart';
import 'enums.dart';

/// Pure logic calculator for converting a list of trainings into a ChallengeParticipant state
class ChallengeCalculator {
  
  /// Computes the new state for a participant given a list of valid trainings
  static ChallengeParticipant computeState({
    required ChallengeParticipant currentParticipant,
    required List<Entrenamiento> validTrainings, // Filtered and sorted by date ASC
    required Challenge challenge,
  }) {
    // Calculate aggregated metrics
    double totalDistanceM = 0;
    double totalTimeSec = 0;
    int totalSessions = 0;
    
    // Pace: Best vs Avg
    double bestPaceVal = double.maxFinite;
    double weightedPaceSum = 0;
    double weightedDistSum = 0;

    DateTime? reachedGoalAt;
    
    // Logic for finding "earliest completion"
    final double goalValue = challenge.goal.value;
    final bool lowerIsBetter = ChallengeRankingHelper.isLowerScoreBetter(challenge.metric);

    for (final t in validTrainings) {
      final tDist = t.distanciaTotalM();
      final tTime = t.tiempoTotalSec();
      final tPace = _computePaceSecPerKm(t);

      // Aggregate
      totalDistanceM += tDist;
      totalTimeSec += tTime;
      totalSessions++; // Count every valid training as a session

      // Pace logic
      if (tDist > 0 && tPace > 0) {
        if (tPace < bestPaceVal) bestPaceVal = tPace;
        
        weightedPaceSum += tPace * tDist;
        weightedDistSum += tDist;
      }
      
      // Calculate hypothetical score at this point in time (cumulative)
      double currentScore = 0;
      switch (challenge.metric) {
        case ChallengeMetric.distance: currentScore = totalDistanceM; break;
        case ChallengeMetric.time: currentScore = totalTimeSec; break;
        case ChallengeMetric.sessions: currentScore = totalSessions.toDouble(); break;
        case ChallengeMetric.bestPace: currentScore = (bestPaceVal == double.maxFinite) ? 0 : bestPaceVal; break;
        case ChallengeMetric.avgPace: currentScore = (weightedDistSum > 0) ? (weightedPaceSum / weightedDistSum) : 0; break;
      }

      // Check specific Goal Completion moment
      if (reachedGoalAt == null) {
        bool met = false;
        if (lowerIsBetter) {
           // For Best Pace: if we just achieved a pace <= goal
           // Note: "currentScore" here updates as we iterate. 
           // If metric is bestPace, currentScore IS the best pace so far.
           if (currentScore > 0 && currentScore <= goalValue) met = true;
        } else {
           // Cumulative (Distance, Time, Sessions): currentScore >= goalValue
           if (currentScore >= goalValue) met = true;
        }
        
        if (met) {
          // We assume the goal was reached at the end of this training session
          reachedGoalAt = t.fecha.add(Duration(seconds: t.tiempoTotalSec().toInt()));
        }
      }
    }

    // Final scores
    final avgPaceVal = (weightedDistSum > 0) ? (weightedPaceSum / weightedDistSum) : 0.0;
    
    double finalScore = 0;
    switch (challenge.metric) {
      case ChallengeMetric.distance: finalScore = totalDistanceM; break;
      case ChallengeMetric.time: finalScore = totalTimeSec; break;
      case ChallengeMetric.sessions: finalScore = totalSessions.toDouble(); break;
      case ChallengeMetric.bestPace: finalScore = (bestPaceVal == double.maxFinite) ? 0 : bestPaceVal; break;
      case ChallengeMetric.avgPace: finalScore = avgPaceVal; break;
    }

    // Guardrails for data integrity
    if (finalScore.isNaN || finalScore < 0) {
      // Log warning if possible, but here we just sanitize
      finalScore = 0;
    }
    
    return currentParticipant.copyWith(
      lastUpdatedAt: DateTime.now(),
      score: finalScore,
      distanceM: totalDistanceM < 0 ? 0 : totalDistanceM.toInt(),
      timeSec: totalTimeSec < 0 ? 0 : totalTimeSec,
      sessions: totalSessions < 0 ? 0 : totalSessions,
      bestPaceSecPerKm: (bestPaceVal == double.maxFinite || bestPaceVal < 0) ? 0.0 : bestPaceVal,
      // avgPaceSecPerKm: (avgPaceVal.isNaN || avgPaceVal < 0) ? 0.0 : avgPaceVal, // Field does not exist in model
      lastTrainingAt: validTrainings.isNotEmpty ? validTrainings.last.fecha : null,
      reachedGoalAt: reachedGoalAt,
    );
  }

  static double _computePaceSecPerKm(Entrenamiento t) {
    if (t.distanciaTotalM() <= 0) return 0;
    return t.tiempoTotalSec() / (t.distanciaTotalM() / 1000.0);
  }
}
