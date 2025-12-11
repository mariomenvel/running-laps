import 'package:cloud_firestore/cloud_firestore.dart';
// Como están en la misma carpeta data, la importación es directa:
import '../../group_model.dart';
import '../../../training/data/entrenamiento.dart';
import '../../invitation_model.dart';

class GroupsRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<List<GroupModel>> fetchUserGroupsPreview(String currentUserId) async {
    try {
      final QuerySnapshot groupSnapshot = await _db
          .collection('groups')
          .where('members', arrayContains: currentUserId)
          .get();

      List<GroupModel> groups = [];

      for (var doc in groupSnapshot.docs) {
        final groupData = doc.data() as Map<String, dynamic>;
        final group = GroupModel.fromFirestore(groupData, doc.id);

        final List<GroupMemberStats> stats = await _getGroupStats(
          group.memberIds,
        );

        groups.add(
          GroupModel(
            id: group.id,
            name: group.name,
            memberIds: group.memberIds,
            topRunners: stats,
          ),
        );
      }
      return groups;
    } catch (e) {
      print("Error repo: $e");
      return []; // Retorna vacío en error para no romper la app
    }
  }

  Future<List<GroupMemberStats>> _getGroupStats(List<String> memberIds) async {
    List<Future<GroupMemberStats?>> futures = [];
    for (String uid in memberIds) {
      futures.add(_calculateUserTotalDistance(uid));
    }
    final results = await Future.wait(futures);
    final validStats = results.whereType<GroupMemberStats>().toList();

    validStats.sort((a, b) => b.totalKm.compareTo(a.totalKm));
    return validStats;
  }

  Future<GroupMemberStats?> _calculateUserTotalDistance(String uid) async {
    try {
      final userDoc = await _db.collection('users').doc(uid).get();
      if (!userDoc.exists) return null;

      final userData = userDoc.data()!;
      final String name = userData['nombre'] ?? 'Usuario';

      final trainingsSnapshot = await _db
          .collection('users')
          .doc(uid)
          .collection('trainings')
          .get();

      int totalMetros = 0;

      for (var tDoc in trainingsSnapshot.docs) {
        // Usamos tu clase Entrenamiento
        final entrenamiento = Entrenamiento.fromMap(tDoc.data());
        totalMetros += entrenamiento.distanciaTotalM();
      }

      return GroupMemberStats(
        uid: uid,
        name: name,
        totalKm: totalMetros / 1000.0,
      );
    } catch (e) {
      return null;
    }
  }
  // ... (código anterior del fetchUserGroupsPreview) ...

  // 1. LÓGICA PARA CREAR GRUPO
  Future<void> createGroup(String groupName, String adminUserId) async {
    try {
      await _db.collection('groups').add({
        'name': groupName,
        'members': [adminUserId], // El creador es el primer miembro
        'createdAt': FieldValue.serverTimestamp(),
        'adminId': adminUserId, // Opcional: para saber quién manda
      });
    } catch (e) {
      print("Error creando grupo: $e");
      rethrow;
    }
  }

  // 2. LÓGICA PARA ABANDONAR (O BORRAR) GRUPO
  Future<void> leaveGroup(String groupId, String userId) async {
    try {
      final docRef = _db.collection('groups').doc(groupId);

      // A. Sacar al usuario del array 'members'
      await docRef.update({
        'members': FieldValue.arrayRemove([userId]),
      });

      // B. Limpieza: Si el grupo se queda vacío, lo borramos completamente
      final docSnap = await docRef.get();
      if (docSnap.exists) {
        final List members = docSnap.data()?['members'] ?? [];
        if (members.isEmpty) {
          await docRef.delete(); // Borrado físico
        }
      }
    } catch (e) {
      print("Error abandonando grupo: $e");
      rethrow;
    }
  }

  Stream<List<InvitationModel>> getInvitationsStream(String userId) {
    return _db
        .collection('users') // O 'users' según tu DB final
        .doc(userId)
        .collection('invitations')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => InvitationModel.fromFirestore(doc.data(), doc.id))
              .toList(),
        );
  }

  // 2. ENVIAR INVITACIÓN POR EMAIL
  Future<void> sendInvitationByEmail(
    String groupId,
    String groupName,
    String inviterName,
    String targetEmail,
  ) async {
    try {
      // A. Buscar si existe un usuario con ese email
      final query = await _db
          .collection('users') // O 'users'
          .where('email', isEqualTo: targetEmail)
          .limit(1)
          .get();

      if (query.docs.isEmpty) {
        throw Exception("No existe ningún usuario con el email $targetEmail");
      }

      final targetUserId = query.docs.first.id;

      // B. Verificar si ya está en el grupo (Opcional, pero recomendado)
      final groupDoc = await _db.collection('groups').doc(groupId).get();
      final List members = groupDoc.data()?['members'] ?? [];
      if (members.contains(targetUserId)) {
        throw Exception("El usuario ya pertenece al grupo.");
      }

      // C. Crear la invitación en el perfil del destinatario
      await _db
          .collection('users')
          .doc(targetUserId)
          .collection('invitations')
          .add({
            'groupId': groupId,
            'groupName': groupName,
            'invitedBy': inviterName,
            'createdAt': FieldValue.serverTimestamp(),
          });
    } catch (e) {
      print("Error enviando invitación: $e");
      rethrow;
    }
  }

  // 3. RESPONDER INVITACIÓN (Aceptar o Rechazar)
  Future<void> answerInvitation(
    String userId,
    InvitationModel invitation,
    bool accept,
  ) async {
    final batch = _db.batch();

    // Referencia a la invitación
    final inviteRef = _db
        .collection('users')
        .doc(userId)
        .collection('invitations')
        .doc(invitation.id);

    if (accept) {
      // A. Añadir al usuario al grupo
      final groupRef = _db.collection('groups').doc(invitation.groupId);
      batch.update(groupRef, {
        'members': FieldValue.arrayUnion([userId]),
      });
    }

    // B. Borrar la invitación (tanto si acepta como si rechaza)
    batch.delete(inviteRef);

    await batch.commit();
  }
}
