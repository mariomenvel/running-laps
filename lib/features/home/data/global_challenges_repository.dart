import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:running_laps/features/groups/data/models/challenge_models.dart';
import 'package:running_laps/features/groups/data/models/enums.dart';

/// Repository for global challenges visible to all users.
///
/// Global challenges live at:
///   global_challenges/{challengeId}
///   global_challenges/{challengeId}/participations/{userId}
///
/// The special sentinel groupId 'global' is used when navigating to
/// ChallengeDetailScreen so the detail controller routes to this collection.
class GlobalChallengesRepository {
  final FirebaseFirestore _firestore;

  GlobalChallengesRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  /// Stream of all active global challenges, ordered by endAt ascending
  /// so the most urgent challenges appear first.
  Stream<List<Challenge>> streamActiveChallenges() {
    return _firestore
        .collection('global_challenges')
        .where('status', isEqualTo: ChallengeStatus.active.toFirestore())
        .orderBy('endAt')
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => Challenge.fromMap(doc.data(), id: doc.id))
            .toList());
  }

  /// Stream of the current user's participation document for a given challenge.
  /// Emits null when the user has not joined yet.
  Stream<ChallengeParticipant?> streamMyParticipation(
    String userId,
    String challengeId,
  ) {
    return _firestore
        .collection('global_challenges')
        .doc(challengeId)
        .collection('participations')
        .doc(userId)
        .snapshots()
        .map((snap) {
      if (!snap.exists) return null;
      return ChallengeParticipant.fromMap(snap.data()!, uid: snap.id);
    });
  }

  /// Returns the total number of participants in a challenge.
  Future<int> getParticipantCount(String challengeId) async {
    try {
      final snap = await _firestore
          .collection('global_challenges')
          .doc(challengeId)
          .collection('participations')
          .count()
          .get();
      return snap.count ?? 0;
    } catch (_) {
      return 0;
    }
  }

  /// Enrolls a user in the challenge. Idempotent — no-op if already joined.
  Future<void> joinChallenge(String userId, String challengeId) async {
    final docRef = _firestore
        .collection('global_challenges')
        .doc(challengeId)
        .collection('participations')
        .doc(userId);

    final existing = await docRef.get();
    if (existing.exists) return;

    final participant = ChallengeParticipant(
      uid: userId,
      joinedAt: DateTime.now(),
      lastUpdatedAt: DateTime.now(),
      score: 0,
    );
    await docRef.set(participant.toMap());
  }
}
