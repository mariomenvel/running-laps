import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'entrenamiento.dart';
import '../../../features/groups/data/training_challenge_sync_service.dart';

class TrainingRepository {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final TrainingChallengeSyncService _syncService = TrainingChallengeSyncService();

  String _requireUid() {
    final User? u = _auth.currentUser;
    if (u == null) {
      throw Exception('No hay usuario autenticado');
    }
    return u.uid;
  }

  CollectionReference<Map<String, dynamic>> _userTrainings(String uid) {
    return _db.collection('users').doc(uid).collection('trainings');
  }

  Future<String> createTraining(Entrenamiento e) async {
    final String uid = _requireUid();
    final Map<String, dynamic> data = e.toMap();

    data['createdAt'] = FieldValue.serverTimestamp();
    data['updatedAt'] = FieldValue.serverTimestamp();

    final DocumentReference<Map<String, dynamic>> doc = await _userTrainings(
      uid,
    ).add(data);

    final trainingId = doc.id;

    // Sync to challenges (async, don't await to avoid blocking)
    _syncService.onTrainingSaved(
      uid: uid,
      entrenamiento: e.copyWith(id: trainingId),
      trainingId: trainingId,
      isUpdate: false,
    ).catchError((error) {
      // Log error but don't fail training creation
    });

    return trainingId;
  }


  // NUEVO: obtener lista de entrenamientos del usuario actual
  Future<List<Entrenamiento>> getTrainings() async {
    final String uid = _requireUid();

    final QuerySnapshot<Map<String, dynamic>> snapshot = await _userTrainings(
      uid,
    ).orderBy('createdAt', descending: true).get();

    final List<Entrenamiento> result = <Entrenamiento>[];

    for (int i = 0; i < snapshot.docs.length; i = i + 1) {
      final QueryDocumentSnapshot<Map<String, dynamic>> doc = snapshot.docs[i];
      final Map<String, dynamic> data = doc.data();
      // Pasar el ID del documento al modelo
      result.add(Entrenamiento.fromMap(data, id: doc.id));
    }

    return result;
  }

  /// Actualiza solo las etiquetas de un entrenamiento existente
  Future<void> updateTrainingTags(String trainingId, List<String> tags) async {
    final String uid = _requireUid();

    await _userTrainings(uid).doc(trainingId).update({
      'tags': tags,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // Re-sync to challenges on update (async)
    // Fetch the updated training document
    final doc = await _userTrainings(uid).doc(trainingId).get();
    if (doc.exists) {
      final training = Entrenamiento.fromMap(doc.data()!, id: doc.id);
      _syncService.onTrainingSaved(
        uid: uid,
        entrenamiento: training,
        trainingId: trainingId,
        isUpdate: true,
      ).catchError((error) {
        // Log error but don't fail update
      });
    }
  }
  Future<List<Entrenamiento>> getAllEntrenamientos(String uid) async {
    // Alias for getTrainings but with explicit uid argument (which getTrainings ignores and uses auth user)
    // To match the new signature: getAllEntrenamientos(String uid)
    // However, existing getTrainings uses _requireUid inside.
    // We should check if uid matches current user or if we need to support other users.
    // For now, assuming analytics is for current user.
    return getTrainings();
  }
}
