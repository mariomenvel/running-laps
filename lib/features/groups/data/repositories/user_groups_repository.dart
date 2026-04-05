import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/enums.dart';

class UserGroupMembership {
  final String groupId;
  final MemberStatus status;
  final DateTime joinedAt;

  UserGroupMembership({
    required this.groupId,
    required this.status,
    required this.joinedAt,
  });

  factory UserGroupMembership.fromMap(Map<String, dynamic> map, String groupId) {
    return UserGroupMembership(
      groupId: groupId,
      status: MemberStatus.fromFirestore(map['status'] ?? 'active'),
      joinedAt: DateTime.tryParse(map['joinedAt'] ?? '') ?? DateTime.now(),
    );
  }
}

/// Repository para gestionar la pertenencia de usuarios a grupos
class UserGroupsRepository {
  final FirebaseFirestore _firestore;

  UserGroupsRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  // ============================================
  // CREATE / UPDATE
  // ============================================

  /// Añade un grupo a la lista de grupos del usuario
  Future<void> addUserToGroup(String uid, String groupId, {MemberStatus status = MemberStatus.active}) async {
    try {
      await _firestore
          .collection('users')
          .doc(uid)
          .collection('groups')
          .doc(groupId)
          .set({
        'joinedAt': DateTime.now().toIso8601String(),
        'status': status.toFirestore(),
      });
    } catch (e) {
      throw Exception('Error adding user to group: $e');
    }
  }

  /// Elimina un grupo de la lista del usuario
  Future<void> removeUserFromGroup(String uid, String groupId) async {
    try {
      await _firestore
          .collection('users')
          .doc(uid)
          .collection('groups')
          .doc(groupId)
          .delete();
    } catch (e) {
      throw Exception('Error removing user from group: $e');
    }
  }

  /// Actualiza el estado de un usuario en su lista de grupos (ej. de pending a active)
  Future<void> updateUserGroupStatus(String uid, String groupId, MemberStatus status) async {
    try {
      await _firestore
          .collection('users')
          .doc(uid)
          .collection('groups')
          .doc(groupId)
          .update({
            'status': status.toFirestore(),
          });
    } catch (e) {
       throw Exception('Error updating user group status: $e');
    }
  }

  // ============================================
  // READ
  // ============================================

  /// Obtiene todos los IDs de grupos del usuario
  Future<List<String>> getUserGroupIds(String uid) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(uid)
          .collection('groups')
          .get();

      return snapshot.docs.map((doc) => doc.id).toList();
    } catch (e) {
      throw Exception('Error fetching user groups: $e');
    }
  }

  /// Stream de los grupos del usuario (Legacy: solo IDs)
  Stream<List<String>> streamUserGroupIds(String uid) {
    return _firestore
        .collection('users')
        .doc(uid)
        .collection('groups')
        .limit(50)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => doc.id).toList());
  }

  /// Stream de membresías detalladas (IDs + Status)
  Stream<List<UserGroupMembership>> streamUserGroups(String uid) {
    return _firestore
        .collection('users')
        .doc(uid)
        .collection('groups')
        .limit(50)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            return UserGroupMembership.fromMap(doc.data(), doc.id);
          }).toList();
        });
  }
}

