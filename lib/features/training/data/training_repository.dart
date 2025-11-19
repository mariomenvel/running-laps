import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'entrenamiento.dart';

class TrainingRepository {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

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

    return doc.id;
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
      // Usamos tu modelo de dominio centralizado
      result.add(Entrenamiento.fromMap(data));
    }

    return result;
  }
}
