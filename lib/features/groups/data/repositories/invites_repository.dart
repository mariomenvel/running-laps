import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/group_models.dart';
import '../models/enums.dart';
import '../repositories/user_groups_repository.dart';
import '../services/user_lookup_service.dart';
import '../helpers/invite_token_helper.dart';

/// Repository para gestión de invitaciones a grupos
class InvitesRepository {
  final FirebaseFirestore _firestore;
  final UserGroupsRepository _userGroupsRepo;
  final UserLookupService _userLookup;

  InvitesRepository({
    FirebaseFirestore? firestore,
    UserGroupsRepository? userGroupsRepo,
    UserLookupService? userLookup,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _userGroupsRepo = userGroupsRepo ?? UserGroupsRepository(),
        _userLookup = userLookup ?? UserLookupService();

  // ============================================
  // CREATE
  // ============================================

  /// Crea una nueva invitación
  Future<void> createInvite(String groupId, Invite invite) async {
    try {
      await _firestore
          .collection('groups')
          .doc(groupId)
          .collection('invites')
          .doc(invite.inviteId)
          .set(invite.toMap());
    } catch (e) {
      throw Exception('Error creating invite: $e');
    }
  }

  // ============================================
  // CODE-BASED INVITES
  // ============================================

  /// Creates a new invite with a [shortCode] + token, stores the invite under
  /// `groups/{groupId}/invites/{id}` AND writes a lookup entry to
  /// `invite_codes/{shortCode}` so it can be resolved without knowing the groupId.
  ///
  /// Returns a record with [inviteId], [shortCode], and the raw [token] (the
  /// token is NOT stored — only its hash is). The caller should present the
  /// shortCode/token to the user.
  Future<({String inviteId, String shortCode, String token})> createInviteWithCode(
    String groupId,
    String createdBy, {
    int maxUses = 50,
    Duration validity = const Duration(days: 7),
  }) async {
    try {
      final token = InviteTokenHelper.generateToken();
      final tokenHash = InviteTokenHelper.hashToken(token);
      final shortCode = InviteTokenHelper.generateShortCode();
      final now = DateTime.now();
      final expiresAt = now.add(validity);

      final inviteRef = _firestore
          .collection('groups')
          .doc(groupId)
          .collection('invites')
          .doc();

      final codeRef = _firestore.collection('invite_codes').doc(shortCode);

      final invite = Invite(
        inviteId: inviteRef.id,
        createdAt: now,
        createdBy: createdBy,
        expiresAt: expiresAt,
        maxUses: maxUses,
        uses: 0,
        revoked: false,
        tokenHash: tokenHash,
        shortCode: shortCode,
      );

      // Atomic write: invite doc + shortCode lookup
      final batch = _firestore.batch();
      batch.set(inviteRef, invite.toMap());
      batch.set(codeRef, {
        'groupId': groupId,
        'inviteId': inviteRef.id,
        'createdAt': now.toIso8601String(),
        'expiresAt': expiresAt.toIso8601String(),
      });
      await batch.commit();

      return (inviteId: inviteRef.id, shortCode: shortCode, token: token);
    } catch (e) {
      throw Exception('Error creating invite with code: $e');
    }
  }

  /// Resolves a [shortCode] → fetches the corresponding [Invite] and its groupId.
  /// Returns null if the code doesn't exist.
  Future<({Invite invite, String groupId})?> getInviteByShortCode(
      String shortCode) async {
    try {
      final codeDoc = await _firestore
          .collection('invite_codes')
          .doc(shortCode.toUpperCase().trim())
          .get();

      if (!codeDoc.exists) return null;

      final data = codeDoc.data()!;
      final groupId = data['groupId'] as String;
      final inviteId = data['inviteId'] as String;

      final inviteDoc = await _firestore
          .collection('groups')
          .doc(groupId)
          .collection('invites')
          .doc(inviteId)
          .get();

      if (!inviteDoc.exists) return null;

      final invite = Invite.fromMap(inviteDoc.data()!, inviteId: inviteDoc.id);
      return (invite: invite, groupId: groupId);
    } catch (e) {
      throw Exception('Error fetching invite by short code: $e');
    }
  }

  /// Validates [shortCode] and joins [uid] to the group.
  /// Throws descriptive exceptions on validation failure.
  Future<GroupMember?> joinByShortCode(
    String shortCode,
    String uid, {
    String? email,
  }) async {
    debugPrint('[InvitesRepo] joinByShortCode — code=$shortCode uid=$uid');
    final result = await getInviteByShortCode(shortCode);

    if (result == null) {
      debugPrint('[InvitesRepo] joinByShortCode — invite_codes/$shortCode not found');
      throw Exception('Código de invitación no encontrado');
    }

    debugPrint('[InvitesRepo] joinByShortCode — resolved groupId=${result.groupId} inviteId=${result.invite.inviteId}');
    debugPrint('[InvitesRepo] joinByShortCode — invite state: revoked=${result.invite.revoked} uses=${result.invite.uses}/${result.invite.maxUses} expiresAt=${result.invite.expiresAt}');

    if (result.invite.revoked) {
      throw Exception('Este código ha sido revocado');
    }

    if (result.invite.uses >= result.invite.maxUses) {
      throw Exception('Este código ha alcanzado el límite de usos');
    }

    if (DateTime.now().isAfter(result.invite.expiresAt)) {
      throw Exception('Este código ha caducado');
    }

    // Reuse the existing acceptInvite transaction (validates + increments uses)
    return acceptInvite(
      result.groupId,
      result.invite.tokenHash,
      uid,
      email: email,
    );
  }

  /// Invita un usuario por email (lo añade como pendiente directamente)
  /// Retorna el UID del usuario invitado si tuvo éxito, o null si no existe.
  Future<String?> inviteUserByEmail(String groupId, String email) async {
    try {
      // 1. Buscar UID
      final targetUid = await _userLookup.lookupUserUidByEmail(email);
      if (targetUid == null) {
        return null; // Usuario no encontrado
      }

      // 2. Transacción para asegurar consistencia
      await _firestore.runTransaction((transaction) async {
        // A. Verificar si ya es miembro
        final memberRef = _firestore
            .collection('groups')
            .doc(groupId)
            .collection('members')
            .doc(targetUid);
        
        final memberDoc = await transaction.get(memberRef);
        if (memberDoc.exists) {
          throw Exception('User is already a member or pending');
        }

        // B. Crear miembro Pending en Grupo
        final newMember = GroupMember(
          uid: targetUid,
          status: MemberStatus.pending,
          joinedAt: DateTime.now(),
        );
        transaction.set(memberRef, newMember.toMap());

        // C. Añadir a lista del usuario como Pending
        final userGroupRef = _firestore
            .collection('users')
            .doc(targetUid)
            .collection('groups')
            .doc(groupId);
        
        transaction.set(userGroupRef, {
          'joinedAt': DateTime.now().toIso8601String(),
          'status': MemberStatus.pending.toFirestore(),
        });
      });

      return targetUid;
    } catch (e) {
      throw Exception('Error inviting user by email: $e');
    }
  }

  // ============================================
  // READ
  // ============================================

  /// Busca una invitación por tokenHash
  Future<Invite?> getInviteByTokenHash(
      String groupId, String tokenHash) async {
    try {
      final querySnapshot = await _firestore
          .collection('groups')
          .doc(groupId)
          .collection('invites')
          .where('tokenHash', isEqualTo: tokenHash)
          .limit(1)
          .get();

      if (querySnapshot.docs.isEmpty) return null;

      final doc = querySnapshot.docs.first;
      return Invite.fromMap(doc.data(), inviteId: doc.id);
    } catch (e) {
      throw Exception('Error fetching invite by token: $e');
    }
  }

  // ============================================
  // UPDATE
  // ============================================

  /// Revoca una invitación
  Future<void> revokeInvite(String groupId, String inviteId) async {
    try {
      await _firestore
          .collection('groups')
          .doc(groupId)
          .collection('invites')
          .doc(inviteId)
          .update({'revoked': true});
    } catch (e) {
      throw Exception('Error revoking invite: $e');
    }
  }

  /// Incrementa el contador de usos de una invitación (atómicamente)
  Future<void> incrementInviteUsesAtomically(
      String groupId, String inviteId) async {
    try {
      await _firestore
          .collection('groups')
          .doc(groupId)
          .collection('invites')
          .doc(inviteId)
          .update({
        'uses': FieldValue.increment(1),
      });
    } catch (e) {
      throw Exception('Error incrementing invite uses: $e');
    }
  }

  // ============================================
  // ACCEPT INVITE (Transaction compleja)
  // ============================================

  /// Acepta una invitación: valida, incrementa uses, crea/actualiza member
  /// Retorna el GroupMember creado/actualizado o null si falló la validación
  Future<GroupMember?> acceptInvite(
    String groupId,
    String tokenHash,
    String uid, {
    String? email,
  }) async {
    debugPrint('[InvitesRepo] acceptInvite — groupId=$groupId uid=$uid');
    try {
      // 1. Buscar invitación por tokenHash
      final invite = await getInviteByTokenHash(groupId, tokenHash);

      if (invite == null) {
        debugPrint('[InvitesRepo] acceptInvite — invite not found by tokenHash');
        throw Exception('Invite not found');
      }

      debugPrint('[InvitesRepo] acceptInvite — found invite inviteId=${invite.inviteId}');

      // 2. Validaciones
      if (invite.revoked) {
        throw Exception('Invite has been revoked');
      }

      if (invite.uses >= invite.maxUses) {
        throw Exception('Invite has reached maximum uses');
      }

      if (DateTime.now().isAfter(invite.expiresAt)) {
        throw Exception('Invite has expired');
      }

      // Si targetEmail está definido, validar que coincida
      if (invite.targetEmail != null &&
          email != null &&
          invite.targetEmail != email) {
        throw Exception('This invite is for a different email address');
      }

      // 3. Verificar si el usuario ya es miembro activo
      final memberDoc = await _firestore
          .collection('groups')
          .doc(groupId)
          .collection('members')
          .doc(uid)
          .get();

      if (memberDoc.exists) {
        final existingMember = GroupMember.fromMap(memberDoc.data()!, uid: uid);
        if (existingMember.status == MemberStatus.active) {
          debugPrint('[InvitesRepo] acceptInvite — user already active member, skipping');
          return existingMember;
        }
      }

      // 4. Usar transacción para operaciones atómicas
      GroupMember? newMember;

      await _firestore.runTransaction((transaction) async {
        // Incrementar uses
        final inviteRef = _firestore
            .collection('groups')
            .doc(groupId)
            .collection('invites')
            .doc(invite.inviteId);
        debugPrint('[InvitesRepo] acceptInvite — writing: groups/$groupId/invites/${invite.inviteId} (update uses)');
        transaction.update(inviteRef, {
          'uses': FieldValue.increment(1),
        });

        // Crear/actualizar miembro
        final memberRef = _firestore
            .collection('groups')
            .doc(groupId)
            .collection('members')
            .doc(uid);
        debugPrint('[InvitesRepo] acceptInvite — writing: groups/$groupId/members/$uid (set member)');

        newMember = GroupMember(
          uid: uid,
          status: MemberStatus.active,
          joinedAt: DateTime.now(),
        );

        transaction.set(memberRef, newMember!.toMap());

        // Incrementar memberCount
        final groupRef = _firestore.collection('groups').doc(groupId);
        debugPrint('[InvitesRepo] acceptInvite — writing: groups/$groupId (update memberCount)');
        transaction.update(groupRef, {
          'memberCount': FieldValue.increment(1),
        });

        // Añadir grupo a la lista de grupos del usuario
        final userGroupRef = _firestore
            .collection('users')
            .doc(uid)
            .collection('groups')
            .doc(groupId);
        debugPrint('[InvitesRepo] acceptInvite — writing: users/$uid/groups/$groupId (set userGroup)');
        transaction.set(userGroupRef, {
          'joinedAt': DateTime.now().toIso8601String(),
        });
      });

      debugPrint('[InvitesRepo] acceptInvite — transaction committed successfully');
      return newMember;
    } catch (e) {
      debugPrint('[InvitesRepo] acceptInvite — ERROR: $e');
      throw Exception('Error accepting invite: $e');
    }
  }

  // ============================================
  // DIRECT INVITE ACTIONS
  // ============================================

  Future<void> acceptDirectInvite(String groupId, String uid) async {
    try {
      await _firestore.runTransaction((transaction) async {
        // 1. Update Group Member Status
        final memberRef = _firestore
            .collection('groups')
            .doc(groupId)
            .collection('members')
            .doc(uid);
        
        transaction.update(memberRef, {
          'status': MemberStatus.active.toFirestore(),
          'joinedAt': DateTime.now().toIso8601String(),
        });

        // 2. Increase Group Member Count
        final groupRef = _firestore.collection('groups').doc(groupId);
        transaction.update(groupRef, {
          'memberCount': FieldValue.increment(1),
        });

        // 3. Update User Group Status
        final userGroupRef = _firestore
            .collection('users')
            .doc(uid)
            .collection('groups')
            .doc(groupId);
        
        transaction.update(userGroupRef, {
          'status': MemberStatus.active.toFirestore(),
        });
      });
    } catch (e) {
      throw Exception('Error accepting direct invite: $e');
    }
  }

  Future<void> declineDirectInvite(String groupId, String uid) async {
    try {
      await _firestore.runTransaction((transaction) async {
        // 1. Remove from Group Members
        final memberRef = _firestore
            .collection('groups')
            .doc(groupId)
            .collection('members')
            .doc(uid);
        
        transaction.delete(memberRef);

        // 2. Remove from User Groups
        final userGroupRef = _firestore
            .collection('users')
            .doc(uid)
            .collection('groups')
            .doc(groupId);
        
        transaction.delete(userGroupRef);
      });
    } catch (e) {
      throw Exception('Error declining direct invite: $e');
    }
  }
}



