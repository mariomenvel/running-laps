import 'package:cloud_firestore/cloud_firestore.dart';
import 'template_models.dart';
import '../../auth/data/auth_repository.dart'; // To get userId
import 'package:firebase_auth/firebase_auth.dart'; // Or wherever Auth is

class TrainingTemplatesRepository {
  final FirebaseFirestore _firestore;
  // Assuming Auth is handled by checking current user, or passed in.
  // Using generic FirebaseAuth for now or strictly checking current user.
  
  TrainingTemplatesRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  String? get _currentUserId => FirebaseAuth.instance.currentUser?.uid;

  CollectionReference _getTemplatesCollection(String userId) {
    return _firestore.collection('users').doc(userId).collection('templates');
  }

  // CREATE
  Future<String> createTemplate(TrainingTemplate template) async {
    final uid = _currentUserId;
    if (uid == null) throw Exception('No authenticated user');

    final docRef = await _getTemplatesCollection(uid).add(template.toMap());
    return docRef.id;
  }

  // READ ALl
  Future<List<TrainingTemplate>> getUserTemplates() async {
    final uid = _currentUserId;
    if (uid == null) return [];

    final snapshot = await _getTemplatesCollection(uid)
        .orderBy('updatedAt', descending: true)
        .get();

    return snapshot.docs.map((doc) {
      return TrainingTemplate.fromMap(
        doc.data() as Map<String, dynamic>,
        id: doc.id,
      );
    }).toList();
  }

  // UPDATE
  Future<void> updateTemplate(TrainingTemplate template) async {
    final uid = _currentUserId;
    if (uid == null) throw Exception('No authenticated user');

    await _getTemplatesCollection(uid).doc(template.id).update(template.toMap());
  }

  // DELETE
  Future<void> deleteTemplate(String templateId) async {
    final uid = _currentUserId;
    if (uid == null) throw Exception('No authenticated user');

    await _getTemplatesCollection(uid).doc(templateId).delete();
  }
}
