import 'package:cloud_firestore/cloud_firestore.dart';
import 'challenge_models.dart';
import 'enums.dart';

/// Repository para gestión de retos de grupos
class ChallengesRepository {
  final FirebaseFirestore _firestore;

  ChallengesRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  // ============================================
  // CREATE
  // ============================================

  /// Crea un nuevo reto en el grupo
  Future<String> createChallenge(String groupId, Challenge challenge) async {
    try {
      final docRef = await _firestore
          .collection('groups')
          .doc(groupId)
          .collection('challenges')
          .add(challenge.toMap());
      return docRef.id;
    } catch (e) {
      throw Exception('Error creating challenge: $e');
    }
  }

  /// Crea un nuevo reto con un ID determinista (para retos automáticos)
  /// Retorna true si se creó, false si ya existía
  Future<bool> createChallengeWithId(
    String groupId,
    String challengeId,
    Challenge challenge,
  ) async {
    try {
      final docRef = _firestore
          .collection('groups')
          .doc(groupId)
          .collection('challenges')
          .doc(challengeId);

      // Check if already exists
      final doc = await docRef.get();
      if (doc.exists) {
        return false; // Already exists, don't recreate
      }

      // Create with the custom ID
      await docRef.set(challenge.toMap());
      return true;
    } catch (e) {
      throw Exception('Error creating challenge with ID: $e');
    }
  }

  // ============================================
  // READ
  // ============================================

  /// Obtiene un reto específico
  Future<Challenge?> getChallenge(String groupId, String challengeId) async {
    try {
      final doc = await _firestore
          .collection('groups')
          .doc(groupId)
          .collection('challenges')
          .doc(challengeId)
          .get();

      if (!doc.exists) return null;

      return Challenge.fromMap(doc.data()!, id: doc.id);
    } catch (e) {
      throw Exception('Error fetching challenge: $e');
    }
  }

  /// Stream de retos activos del grupo (incluye tanto template como owner)
  Stream<List<Challenge>> streamActiveChallenges(String groupId) {
    return _firestore
        .collection('groups')
        .doc(groupId)
        .collection('challenges')
        .where('status', isEqualTo: ChallengeStatus.active.toFirestore())
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => Challenge.fromMap(doc.data(), id: doc.id))
          .toList();
    });
  }

  /// Obtiene retos activos del grupo (snapshot único)
  Future<List<Challenge>> getActiveChallengesOnce(String groupId) async {
    try {
      final snapshot = await _firestore
          .collection('groups')
          .doc(groupId)
          .collection('challenges')
          .where('status', isEqualTo: ChallengeStatus.active.toFirestore())
          .get();

      return snapshot.docs
          .map((doc) => Challenge.fromMap(doc.data(), id: doc.id))
          .toList();
    } catch (e) {
      throw Exception('Error fetching active challenges: $e');
    }
  }

  // ============================================
  // UPDATE
  // ============================================

  /// Actualiza el estado de un reto
  Future<void> updateChallengeStatus(
    String groupId,
    String challengeId,
    ChallengeStatus status,
  ) async {
    try {
      await _firestore
          .collection('groups')
          .doc(groupId)
          .collection('challenges')
          .doc(challengeId)
          .update({
        'status': status.toFirestore(),
      });
    } catch (e) {
      throw Exception('Error updating challenge status: $e');
    }
  }

  /// Marca que las medallas han sido otorgadas
  Future<void> markMedalsAwarded(String groupId, String challengeId) async {
    try {
      await _firestore
          .collection('groups')
          .doc(groupId)
          .collection('challenges')
          .doc(challengeId)
          .update({
        'medalsAwarded': true,
      });
    } catch (e) {
      throw Exception('Error marking medals awarded: $e');
    }
  }

  /// Marca que los badges han sido otorgados
  Future<void> markBadgesAwarded(String groupId, String challengeId) async {
    try {
      await _firestore
          .collection('groups')
          .doc(groupId)
          .collection('challenges')
          .doc(challengeId)
          .update({
        'badgesAwarded': true,
      });
    } catch (e) {
      throw Exception('Error marking badges awarded: $e');
    }
  }

  // ============================================
  // PARTICIPANTS
  // ============================================

  /// Crea o actualiza un participante en un reto
  Future<void> upsertParticipant(
    String groupId,
    String challengeId,
    ChallengeParticipant participant,
  ) async {
    try {
      await _firestore
          .collection('groups')
          .doc(groupId)
          .collection('challenges')
          .doc(challengeId)
          .collection('participants')
          .doc(participant.uid)
          .set(participant.toMap());
    } catch (e) {
      throw Exception('Error upserting participant: $e');
    }
  }

  /// Stream de todos los participantes de un reto
  Stream<List<ChallengeParticipant>> streamChallengeParticipants(
    String groupId,
    String challengeId,
  ) {
    return _firestore
        .collection('groups')
        .doc(groupId)
        .collection('challenges')
        .doc(challengeId)
        .collection('participants')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => ChallengeParticipant.fromMap(doc.data(), uid: doc.id))
          .toList();
    });
  }

  /// Stream del participante específico (el usuario actual)
  Stream<ChallengeParticipant?> streamMyParticipant(
    String groupId,
    String challengeId,
    String uid,
  ) {
    return _firestore
        .collection('groups')
        .doc(groupId)
        .collection('challenges')
        .doc(challengeId)
        .collection('participants')
        .doc(uid)
        .snapshots()
        .map((snapshot) {
      if (!snapshot.exists) return null;
      return ChallengeParticipant.fromMap(snapshot.data()!, uid: snapshot.id);
    });
  }

  /// Obtiene el participante específico (snapshot único)
  Future<ChallengeParticipant?> getParticipant(
    String groupId,
    String challengeId,
    String uid,
  ) async {
    try {
      final doc = await _firestore
          .collection('groups')
          .doc(groupId)
          .collection('challenges')
          .doc(challengeId)
          .collection('participants')
          .doc(uid)
          .get();

      if (!doc.exists) return null;

      return ChallengeParticipant.fromMap(doc.data()!, uid: doc.id);
    } catch (e) {
      throw Exception('Error fetching participant: $e');
    }
  }
  /// Obtiene todos los participantes de un reto (snapshot único)
  Future<List<ChallengeParticipant>> getParticipantsOnce(
    String groupId,
    String challengeId,
  ) async {
    try {
      final snapshot = await _firestore
          .collection('groups')
          .doc(groupId)
          .collection('challenges')
          .doc(challengeId)
          .collection('participants')
          .get();

      return snapshot.docs
          .map((doc) => ChallengeParticipant.fromMap(doc.data(), uid: doc.id))
          .toList();
    } catch (e) {
      throw Exception('Error fetching participants: $e');
    }
  }
}
