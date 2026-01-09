import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/challenge_models.dart';

/// Repository para gestión de preferencias de usuario en grupos
class GroupPrefsRepository {
  final FirebaseFirestore _firestore;

  GroupPrefsRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  // ============================================
  // READ
  // ============================================

  /// Obtiene las preferencias de un usuario en un grupo
  Future<GroupPrefs> getPrefs(String groupId, String uid) async {
    try {
      final doc = await _firestore
          .collection('groups')
          .doc(groupId)
          .collection('prefs')
          .doc(uid)
          .get();

      if (!doc.exists) {
        // Retornar preferencias por defecto si no existen
        return GroupPrefs(uid: uid);
      }

      return GroupPrefs.fromMap(doc.data()!, uid: uid);
    } catch (e) {
      throw Exception('Error fetching group prefs: $e');
    }
  }

  /// Stream de las preferencias de un usuario en un grupo
  Stream<GroupPrefs> streamPrefs(String groupId, String uid) {
    return _firestore
        .collection('groups')
        .doc(groupId)
        .collection('prefs')
        .doc(uid)
        .snapshots()
        .map((snapshot) {
      if (!snapshot.exists) {
        return GroupPrefs(uid: uid);
      }
      return GroupPrefs.fromMap(snapshot.data()!, uid: uid);
    });
  }

  // ============================================
  // CREATE / UPDATE
  // ============================================

  /// Crea o actualiza las preferencias de un usuario
  Future<void> upsertPrefs(String groupId, GroupPrefs prefs) async {
    try {
      await _firestore
          .collection('groups')
          .doc(groupId)
          .collection('prefs')
          .doc(prefs.uid)
          .set(prefs.toMap());
    } catch (e) {
      throw Exception('Error upserting group prefs: $e');
    }
  }
}

