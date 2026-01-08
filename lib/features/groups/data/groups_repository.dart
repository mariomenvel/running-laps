import 'package:cloud_firestore/cloud_firestore.dart';
import 'group_models.dart';
import 'enums.dart';

/// Repository para gestión de grupos
class GroupsRepository {
  final FirebaseFirestore _firestore;

  GroupsRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  // ============================================
  // CREATE
  // ============================================

  /// Crea un nuevo grupo en Firestore
  Future<String> createGroup(Group group) async {
    try {
      final docRef = await _firestore.collection('groups').add(group.toMap());
      return docRef.id;
    } catch (e) {
      throw Exception('Error creating group: $e');
    }
  }

  /// Añade un miembro al grupo (usado principalmente para crear el owner al inicio)
  Future<void> addMember(String groupId, GroupMember member) async {
    try {
      await _firestore
          .collection('groups')
          .doc(groupId)
          .collection('members')
          .doc(member.uid)
          .set(member.toMap());
    } catch (e) {
      throw Exception('Error adding member to group: $e');
    }
  }

  // ============================================
  // READ
  // ============================================

  /// Obtiene un grupo por su ID
  Future<Group?> getGroupById(String groupId) async {
    try {
      final doc = await _firestore.collection('groups').doc(groupId).get();
      if (!doc.exists) return null;
      return Group.fromMap(doc.data()!, id: doc.id);
    } catch (e) {
      throw Exception('Error fetching group: $e');
    }
  }

  /// Stream de un grupo en tiempo real
  Stream<Group?> streamGroup(String groupId) {
    return _firestore
        .collection('groups')
        .doc(groupId)
        .snapshots()
        .map((snapshot) {
      if (!snapshot.exists) return null;
      return Group.fromMap(snapshot.data()!, id: snapshot.id);
    });
  }

  /// Stream de miembros del grupo
  Stream<List<GroupMember>> streamMembers(String groupId) {
    return _firestore
        .collection('groups')
        .doc(groupId)
        .collection('members')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => GroupMember.fromMap(doc.data(), uid: doc.id))
          .toList();
    });
  }

  // ============================================
  // UPDATE
  // ============================================

  /// Actualiza el contador de miembros
  Future<void> updateMemberCount(String groupId, int newCount) async {
    try {
      await _firestore.collection('groups').doc(groupId).update({
        'memberCount': newCount,
      });
    } catch (e) {
      throw Exception('Error updating member count: $e');
    }
  }

  /// Actualiza el campo activeChallengeId del grupo
  Future<void> updateActiveChallengeId(
      String groupId, String? challengeId) async {
    try {
      await _firestore.collection('groups').doc(groupId).update({
        'activeChallengeId': challengeId,
      });
    } catch (e) {
      throw Exception('Error updating active challenge: $e');
    }
  }

  // ============================================
  // DELETE / KICK
  // ============================================

  /// Expulsa o elimina un miembro (marca como kicked, no borra el documento)
  /// performedBy debe ser el uid del usuario que realiza la acción (para validación posterior)
  Future<void> removeMemberOrKick(
    String groupId,
    String uid, {
    required String performedBy,
  }) async {
    try {
      await _firestore
          .collection('groups')
          .doc(groupId)
          .collection('members')
          .doc(uid)
          .update({
        'status': MemberStatus.kicked.toFirestore(),
        'kickedAt': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      throw Exception('Error removing/kicking member: $e');
    }
  }
}
