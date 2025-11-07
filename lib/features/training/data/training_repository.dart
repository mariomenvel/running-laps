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

    return doc.id; // útil para navegar luego al detalle
  }
}
