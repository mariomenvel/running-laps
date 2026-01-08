import 'package:cloud_firestore/cloud_firestore.dart';
import 'rewards_models.dart';
import 'enums.dart';

/// Repository para gestión de recompensas (medallas y badges)
class RewardsRepository {
  final FirebaseFirestore _firestore;

  RewardsRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  // ============================================
  // MEDALS - READ
  // ============================================

  /// Stream del medallero del grupo (ordenado por oro > plata > bronce desc)
  Stream<List<GroupMedals>> streamGroupMedals(String groupId) {
    return _firestore
        .collection('groups')
        .doc(groupId)
        .collection('medals')
        .snapshots()
        .map((snapshot) {
      final medals = snapshot.docs
          .map((doc) => GroupMedals.fromMap(doc.data(), uid: doc.id))
          .toList();

      // Ordenar por oro, plata, bronce (descendente)
      medals.sort((a, b) {
        if (a.gold != b.gold) return b.gold.compareTo(a.gold);
        if (a.silver != b.silver) return b.silver.compareTo(a.silver);
        return b.bronze.compareTo(a.bronze);
      });

      return medals;
    });
  }

  /// Obtiene las medallas de un usuario específico
  Future<GroupMedals> getUserMedals(String groupId, String uid) async {
    try {
      final doc = await _firestore
          .collection('groups')
          .doc(groupId)
          .collection('medals')
          .doc(uid)
          .get();

      if (!doc.exists) {
        return GroupMedals(uid: uid);
      }

      return GroupMedals.fromMap(doc.data()!, uid: uid);
    } catch (e) {
      throw Exception('Error fetching user medals: $e');
    }
  }

  // ============================================
  // BADGES - READ
  // ============================================

  /// Stream de la tabla de badges del grupo (ordenado por completedCount desc)
  Stream<List<GroupBadges>> streamGroupBadges(String groupId) {
    return _firestore
        .collection('groups')
        .doc(groupId)
        .collection('badges')
        .snapshots()
        .map((snapshot) {
      final badges = snapshot.docs
          .map((doc) => GroupBadges.fromMap(doc.data(), uid: doc.id))
          .toList();

      // Ordenar por total de completados
      badges.sort((a, b) => b.completedCount.compareTo(a.completedCount));

      return badges;
    });
  }

  /// Obtiene los badges de un usuario específico
  Future<GroupBadges> getUserBadges(String groupId, String uid) async {
    try {
      final doc = await _firestore
          .collection('groups')
          .doc(groupId)
          .collection('badges')
          .doc(uid)
          .get();

      if (!doc.exists) {
        return GroupBadges(uid: uid);
      }

      return GroupBadges.fromMap(doc.data()!, uid: uid);
    } catch (e) {
      throw Exception('Error fetching user badges: $e');
    }
  }

  // ============================================
  // HISTORY - READ
  // ============================================



  // ============================================
  // SPECIFIC QUERIES (UI Helpers)
  // ============================================

  /// Stream del historial de medallas de un usuario (ALIAS con nombre explícito)
  Stream<List<MedalHistoryEntry>> streamMyMedalHistory(
    String groupId,
    String uid,
  ) {
    return _firestore
        .collection('groups')
        .doc(groupId)
        .collection('medal_history')
        .where('uid', isEqualTo: uid)
        .orderBy('awardedAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => MedalHistoryEntry.fromMap(doc.data(), id: doc.id))
          .toList();
    });
  }

    /// Stream del historial de badges de un usuario (ALIAS con nombre explícito)
  Stream<List<BadgeHistoryEntry>> streamMyBadgeHistory(
    String groupId,
    String uid,
  ) {
    return _firestore
        .collection('groups')
        .doc(groupId)
        .collection('badge_history')
        .where('uid', isEqualTo: uid)
        .orderBy('awardedAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => BadgeHistoryEntry.fromMap(doc.data(), id: doc.id))
          .toList();
    });
  }

  /// Verifica si el usuario tiene el badge "Objetivo logrado" para un reto específico
  /// Retorna stream de bool
  Stream<bool> streamHasGoalCompletedBadge(
    String groupId,
    String uid,
    String challengeId,
  ) {
    return _firestore
        .collection('groups')
        .doc(groupId)
        .collection('badge_history')
        .where('uid', isEqualTo: uid)
        .where('challengeId', isEqualTo: challengeId)
        .where('badge', isEqualTo: BadgeType.goalCompleted.toFirestore())
        .limit(1)
        .snapshots()
        .map((snapshot) => snapshot.docs.isNotEmpty);
  }

  // ============================================
  // MEDALS - WRITE (con transacción)
  // ============================================

  /// Añade una medalla al historial e incrementa el contador agregado (atómico)
  Future<void> addMedalHistoryAndAggregate(
    String groupId,
    MedalHistoryEntry entry,
  ) async {
    try {
      await _firestore.runTransaction((transaction) async {
        // 1. Crear entrada en historial
        final historyRef = _firestore
            .collection('groups')
            .doc(groupId)
            .collection('medal_history')
            .doc(); // Auto-genera ID

        transaction.set(historyRef, entry.copyWith(id: historyRef.id).toMap());

        // 2. Incrementar contador en medals/{uid}
        final medalsRef = _firestore
            .collection('groups')
            .doc(groupId)
            .collection('medals')
            .doc(entry.uid);

        // Leer el documento actual para verificar si existe
        final medalsSnapshot = await transaction.get(medalsRef);

        if (!medalsSnapshot.exists) {
          // Crear nuevo documento con la medalla
          final newMedals = GroupMedals(
            uid: entry.uid,
            gold: entry.medal == MedalType.gold ? 1 : 0,
            silver: entry.medal == MedalType.silver ? 1 : 0,
            bronze: entry.medal == MedalType.bronze ? 1 : 0,
            lastMedalAt: entry.awardedAt,
          );
          transaction.set(medalsRef, newMedals.toMap());
        } else {
          // Incrementar el contador correspondiente
          final updateData = <String, dynamic>{
            'lastMedalAt': entry.awardedAt.toIso8601String(),
          };

          switch (entry.medal) {
            case MedalType.gold:
              updateData['gold'] = FieldValue.increment(1);
              break;
            case MedalType.silver:
              updateData['silver'] = FieldValue.increment(1);
              break;
            case MedalType.bronze:
              updateData['bronze'] = FieldValue.increment(1);
              break;
          }

          transaction.update(medalsRef, updateData);
        }
      });
    } catch (e) {
      throw Exception('Error adding medal history: $e');
    }
  }

  // ============================================
  // BADGES - WRITE (con transacción)
  // ============================================

  /// Añade un badge al historial e incrementa el contador agregado (atómico)
  Future<void> addBadgeHistoryAndAggregate(
    String groupId,
    BadgeHistoryEntry entry,
  ) async {
    try {
      await _firestore.runTransaction((transaction) async {
        // 1. Crear entrada en historial
        final historyRef = _firestore
            .collection('groups')
            .doc(groupId)
            .collection('badge_history')
            .doc(); // Auto-genera ID

        transaction.set(historyRef, entry.copyWith(id: historyRef.id).toMap());

        // 2. Incrementar contador en badges/{uid}
        final badgesRef = _firestore
            .collection('groups')
            .doc(groupId)
            .collection('badges')
            .doc(entry.uid);

        // Leer el documento actual para verificar si existe
        final badgesSnapshot = await transaction.get(badgesRef);

        // Determinar si es weekly o monthly basándose en el periodKey del entry
        // Asumimos que periodKey tiene formato "2026-W01" para weekly o "2026-01" para monthly
        final isWeekly = entry.periodKey.contains('-W');

        if (!badgesSnapshot.exists) {
          // Crear nuevo documento con el badge
          final newBadges = GroupBadges(
            uid: entry.uid,
            completedCount: 1,
            weeklyCompleted: isWeekly ? 1 : 0,
            monthlyCompleted: isWeekly ? 0 : 1,
            lastCompletedAt: entry.awardedAt,
          );
          transaction.set(badgesRef, newBadges.toMap());
        } else {
          // Incrementar contadores
          final updateData = <String, dynamic>{
            'completedCount': FieldValue.increment(1),
            'lastCompletedAt': entry.awardedAt.toIso8601String(),
          };

          if (isWeekly) {
            updateData['weeklyCompleted'] = FieldValue.increment(1);
          } else {
            updateData['monthlyCompleted'] = FieldValue.increment(1);
          }

          transaction.update(badgesRef, updateData);
        }
      });
    } catch (e) {
      throw Exception('Error adding badge history: $e');
    }
  }

  // ============================================
  // COMBINED HISTORY STREAM (opcional)
  // ============================================

  /// Stream combinando medallas y badges del usuario (para sección de recompensas)
  /// Retorna dos streams separados que pueden combinarse en el ViewModel
  (Stream<List<MedalHistoryEntry>>, Stream<List<BadgeHistoryEntry>>)
      streamMyRewardHistory(String groupId, String uid) {
    return (
      streamMyMedalHistory(groupId, uid),
      streamMyBadgeHistory(groupId, uid),
    );
  }
}
