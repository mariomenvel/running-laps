import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../repositories/challenges_repository.dart';
import '../repositories/rewards_repository.dart';
import '../models/challenge_models.dart';
import '../models/rewards_models.dart';
import '../models/enums.dart';
import '../helpers/challenge_ranking_helper.dart';
import '../models/result_notification_model.dart';

/// Service to handle automatic closure of challenges and distribution of rewards
/// Designed to be called client-side but safe against concurrency via transactions
class ChallengeFinalizeService {
  final FirebaseFirestore _firestore;
  final ChallengesRepository _challengesRepo;

  ChallengeFinalizeService({
    FirebaseFirestore? firestore,
    ChallengesRepository? challengesRepo,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _challengesRepo = challengesRepo ?? ChallengesRepository();

  /// Checks for expired active challenges in a group and finalizes them
  Future<void> finalizeExpiredChallengesForGroup(
    String groupId,
  ) async {
    final startTime = DateTime.now();
    int challengesClosed = 0;
  
    try {
      // 1. Obtener challenges activos del grupo
      final activeChallenges = await _challengesRepo.getActiveChallengesOnce(groupId);
      
      final now = DateTime.now();

      for (final challenge in activeChallenges) {
        // Check if expired (endAt exclusive: expired if now >= endAt)
        if (now.isAfter(challenge.endAt) || now.isAtSameMomentAs(challenge.endAt)) {
          try {
            // Call the existing finalizeChallenge method
            await finalizeChallenge(groupId, challenge, now);
            challengesClosed++;
          } catch (e) {
            // Continue with next challenge instead of aborting the whole group
          }
        }
      }

      debugPrint('[ChallengeFinalize] $challengesClosed retos cerrados '
          'en ${DateTime.now().difference(startTime).inMilliseconds}ms');
    } catch (e) {
      // Rethrow to let caller know.
      rethrow;
    }
  }

  /// Finalizes a single challenge: Close -> Award Medals -> Award Badges
  Future<void> finalizeChallenge(
    String groupId,
    Challenge challenge,
    DateTime now,
  ) async {
    final challengeId = challenge.id;

    // 1. Close Challenge (Status Active -> Finished)
    final isClosed = await _closeChallengeTransaction(groupId, challengeId);
    
    // If we successfully closed it OR it was already finished, proceed to rewards
    // (We distinguish to allow retrying rewards if they failed previously)
    if (!isClosed) {
       // Could check if it is indeed finished to be safe, but we assume
       // if not active, it might be finished.
    }

    // 0. Fetch Group Name for notifications
    String groupName = "Grupo";
    try {
      final groupDoc = await _firestore.collection('groups').doc(groupId).get();
      if (groupDoc.exists) {
        groupName = groupDoc.data()?['name'] ?? "Grupo";
      }
    } catch (e) {
      debugPrint('[ChallengeFinalize] error: $e');
    }

    // 2. Award Medals (if configured)
    if (challenge.awardsMedals) {
      await _awardMedalsTransaction(groupId, groupName, challenge);
    }

    // 3. Award Badges (if configured)
    if (challenge.awardsBadges) {
      await _awardBadgesTransaction(groupId, groupName, challenge);
    }
  }

  // ============================================
  // TRANSACTIONS
  // ============================================

  /// Sets status to finished atomically if it is currently active.
  /// Returns true if it was active and we closed it, or if it was already finished.
  Future<bool> _closeChallengeTransaction(String groupId, String challengeId) async {
    try {
      return await _firestore.runTransaction((transaction) async {
        final docRef = _firestore
            .collection('groups')
            .doc(groupId)
            .collection('challenges')
            .doc(challengeId);

        final snapshot = await transaction.get(docRef);
        if (!snapshot.exists) return false;

        final currentStatusStr = snapshot.data()?['status'] as String?;
        final currentStatus = ChallengeStatus.fromFirestore(currentStatusStr ?? '');

        if (currentStatus == ChallengeStatus.finished) {
          return true; // Already finished
        }

        if (currentStatus == ChallengeStatus.active) {
          transaction.update(docRef, {
            'status': ChallengeStatus.finished.toFirestore(),
          });
          return true;
        }

        return false; // Draft or other status
      });
    } catch (e) {

      return false;
    }
  }

  /// Calculates ranking and awards medals to Top 3.
  /// Uses transaction (or "lock" boolean) to ensure only one client awards medals.
  Future<void> _awardMedalsTransaction(String groupId, String groupName, Challenge challenge) async {
    try {
      // Pre-calculation: Fetch participants and sort them
      // We do this OUTSIDE transaction to minimize transaction duration/contention,
      // creating a list of "Winners" to verify inside.
      final participants = await _challengesRepo.getParticipantsOnce(groupId, challenge.id);
      
      // Filter valid: Score > 0 (assuming strictly > 0 needed for medal)
      final validParticipants = participants.where((p) => p.score > 0).toList();
      
      final sorted = ChallengeRankingHelper.sortParticipants(validParticipants, challenge);
      final top3 = sorted.take(3).toList();

      if (top3.isEmpty) return; // No one to award

      // Atomic Transaction: Check -> Write History -> Increment Aggregates -> Set Flag
      await _firestore.runTransaction((transaction) async {
        final challengeRef = _firestore.collection('groups').doc(groupId).collection('challenges').doc(challenge.id);
        final snapshot = await transaction.get(challengeRef);
        if (snapshot.data()?['medalsAwarded'] == true) return;

        // Perform Writes
        for (int i = 0; i < top3.length; i++) {
          final p = top3[i];
          final rank = i + 1;
          final medalType = _getMedalForRank(rank);

          // 1. History
          final historyRef = _firestore.collection('groups').doc(groupId).collection('medal_history').doc();
          final entry = MedalHistoryEntry(
            id: historyRef.id,
            uid: p.uid,
            challengeId: challenge.id,
            challengeTitle: challenge.title,
            periodKey: challenge.periodKey,
            origin: challenge.origin.toFirestore(),
            medal: medalType,
            rank: rank,
            score: p.score,
            awardedAt: DateTime.now(),
          );
          transaction.set(historyRef, entry.toMap());

          // 2. Aggregate
          final medalsRef = _firestore.collection('groups').doc(groupId).collection('medals').doc(p.uid);
          final medalsSnap = await transaction.get(medalsRef);
          
          if (!medalsSnap.exists) {
            final newMedals = GroupMedals(
              uid: p.uid,
              gold: medalType == MedalType.gold ? 1 : 0,
              silver: medalType == MedalType.silver ? 1 : 0,
              bronze: medalType == MedalType.bronze ? 1 : 0,
              lastMedalAt: DateTime.now(),
            );
            transaction.set(medalsRef, newMedals.toMap());
          } else {
            final field = _getMedalField(medalType);
            transaction.update(medalsRef, {
              field: FieldValue.increment(1),
              'lastMedalAt': DateTime.now().toIso8601String(),
            });
          }

          // 3. Notification (In-app alert)
          final notifRef = _firestore.collection('users').doc(p.uid).collection('result_notifications').doc(challenge.id);
          final notif = GroupResultNotification(
            id: challenge.id,
            groupId: groupId,
            groupName: groupName,
            challengeId: challenge.id,
            challengeTitle: challenge.title,
            medal: medalType,
            rank: rank,
            hasBadge: false, // Will be updated if badge awarded too
            createdAt: DateTime.now(),
          );
          transaction.set(notifRef, notif.toMap(), SetOptions(merge: true));
        }

        // Mark as awarded
        transaction.update(challengeRef, {'medalsAwarded': true});
      });

    } catch (e) {
      debugPrint('[ChallengeFinalize] error: $e');
    }
  }

  /// Awards Goal Completed badge to all passing participants.
  Future<void> _awardBadgesTransaction(String groupId, String groupName, Challenge challenge) async {
    try {
      final participants = await _challengesRepo.getParticipantsOnce(groupId, challenge.id);
      
      // Filter qualifiers
      final winners = participants.where((p) => ChallengeRankingHelper.hasMetGoal(p, challenge)).toList();
      
      if (winners.isEmpty) {
        // Even if no winners, we should mark as awarded so we don't retry forever
        await _markBadgesAwarded(groupId, challenge.id);
        return;
      }

      // Important: Badges might be many (e.g. 50 participants). Transaction limit 500 ops.
      // If winners > ~150 (each needs ~3 ops: history, agg read, agg write), we might hit limit.
      // For MVP we assume small group size. 
      // If large, we would need batching.
      
      await _firestore.runTransaction((transaction) async {
        final challengeRef = _firestore.collection('groups').doc(groupId).collection('challenges').doc(challenge.id);
        final snapshot = await transaction.get(challengeRef);
        if (snapshot.data()?['badgesAwarded'] == true) return;

        final isWeekly = challenge.periodKey.contains('-W');

        for (final p in winners) {
          // 1. History
          final historyRef = _firestore.collection('groups').doc(groupId).collection('badge_history').doc();
          final entry = BadgeHistoryEntry(
            id: historyRef.id,
            uid: p.uid,
            challengeId: challenge.id,
            challengeTitle: challenge.title,
            periodKey: challenge.periodKey,
            origin: challenge.origin.toFirestore(),
            badge: BadgeType.goalCompleted,
            scoreAtEnd: p.score,
            goalValue: challenge.goal.value,
            awardedAt: DateTime.now(),
          );
          transaction.set(historyRef, entry.toMap());

          // 2. Aggregate
          final badgesRef = _firestore.collection('groups').doc(groupId).collection('badges').doc(p.uid);
          final badgesSnap = await transaction.get(badgesRef);

          if (!badgesSnap.exists) {
            final newBadges = GroupBadges(
              uid: p.uid,
              completedCount: 1,
              weeklyCompleted: isWeekly ? 1 : 0,
              monthlyCompleted: isWeekly ? 0 : 1,
              lastCompletedAt: DateTime.now(),
            );
            transaction.set(badgesRef, newBadges.toMap());
          } else {
             final updateData = <String, dynamic>{
              'completedCount': FieldValue.increment(1),
              'lastCompletedAt': DateTime.now().toIso8601String(),
            };
            if (isWeekly) {
              updateData['weeklyCompleted'] = FieldValue.increment(1);
            } else {
              updateData['monthlyCompleted'] = FieldValue.increment(1);
            }
            transaction.update(badgesRef, updateData);
          }

          // 3. Notification (In-app alert)
          final notifRef = _firestore.collection('users').doc(p.uid).collection('result_notifications').doc(challenge.id);
          // Note: If medal already wrote here, we merge setting hasBadge to true
          transaction.set(notifRef, {
            'groupId': groupId,
            'groupName': groupName,
            'challengeId': challenge.id,
            'challengeTitle': challenge.title,
            'hasBadge': true,
            'createdAt': DateTime.now().toIso8601String(),
          }, SetOptions(merge: true));
        }

        transaction.update(challengeRef, {'badgesAwarded': true});
      });

    } catch (e) {
      debugPrint('[ChallengeFinalize] error: $e');
    }
  }

  Future<void> _markBadgesAwarded(String groupId, String challengeId) async {
     await _firestore.collection('groups').doc(groupId).collection('challenges').doc(challengeId).update({
       'badgesAwarded': true,
     });
  }

  MedalType _getMedalForRank(int rank) {
    switch (rank) {
      case 1: return MedalType.gold;
      case 2: return MedalType.silver;
      case 3: return MedalType.bronze;
      default: return MedalType.bronze; 
    }
  }

  String _getMedalField(MedalType type) {
    switch (type) {
      case MedalType.gold: return 'gold';
      case MedalType.silver: return 'silver';
      case MedalType.bronze: return 'bronze';
    }
  }
}


