import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Or wherever Auth is
import 'package:flutter/foundation.dart';
import 'package:running_laps/core/services/rate_limit_service.dart';
// To get userId
import 'template_models.dart';
import 'workout_session.dart';

class TrainingTemplatesRepository {
  final FirebaseFirestore _firestore;
  final RateLimitService _rateLimitService = RateLimitService();

  TrainingTemplatesRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance {
    _rateLimitService.registerLimit('templates:save', const Duration(seconds: 2));
    _rateLimitService.registerLimit('templates:delete', const Duration(seconds: 3));
  }

  @visibleForTesting
  String? get currentUserId => FirebaseAuth.instance.currentUser?.uid;

  CollectionReference _getTemplatesCollection(String userId) {
    return _firestore.collection('users').doc(userId).collection('templates');
  }

  // CREATE
  Future<String> createTemplate(TrainingTemplate template) async {
    _rateLimitService.checkLimit('templates:save');
    final uid = currentUserId;
    if (uid == null) throw Exception('No authenticated user');

    final docRef = await _getTemplatesCollection(uid).add(template.toMap());
    return docRef.id;
  }

  // READ ALl
  Future<List<TrainingTemplate>> getUserTemplates() async {
    final uid = currentUserId;
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
    _rateLimitService.checkLimit('templates:save');
    final uid = currentUserId;
    if (uid == null) throw Exception('No authenticated user');

    await _getTemplatesCollection(uid).doc(template.id).update(template.toMap());
  }

  // DELETE
  Future<void> deleteTemplate(String templateId) async {
    _rateLimitService.checkLimit('templates:delete');
    final uid = currentUserId;
    if (uid == null) throw Exception('No authenticated user');

    await _getTemplatesCollection(uid).doc(templateId).delete();
  }

  // ── WorkoutSession (nuevo modelo) ──────────────────────────────────────────

  Future<void> saveWorkoutSession(WorkoutSession session) async {
    final uid = currentUserId;
    if (uid == null) throw Exception('Usuario no autenticado');

    debugPrint('[TemplatesRepo] saveWorkoutSession: ${session.id}');
    await _getTemplatesCollection(uid).doc(session.id).set(session.toMap());
  }

  Future<WorkoutSession?> getWorkoutSession(String id) async {
    final uid = currentUserId;
    if (uid == null) throw Exception('Usuario no autenticado');

    final doc = await _getTemplatesCollection(uid).doc(id).get();
    if (!doc.exists) return null;

    final data = doc.data() as Map<String, dynamic>;
    if (!data.containsKey('blocks')) return null;

    debugPrint('[TemplatesRepo] getWorkoutSession: $id');
    return WorkoutSession.fromMap(data);
  }

  Future<List<WorkoutSession>> getWorkoutSessions() async {
    final uid = currentUserId;
    if (uid == null) throw Exception('Usuario no autenticado');

    final snapshot = await _getTemplatesCollection(uid).get();

    final sessions = <WorkoutSession>[];
    for (final doc in snapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      if (!data.containsKey('blocks')) continue; // documento legacy, ignorar
      try {
        sessions.add(WorkoutSession.fromMap(data));
      } catch (e) {
        debugPrint('[TemplatesRepo] getWorkoutSessions: error parsing ${doc.id} — $e');
      }
    }
    debugPrint('[TemplatesRepo] getWorkoutSessions: ${sessions.length} sesiones');
    return sessions;
  }

  Future<void> deleteWorkoutSession(String id) async {
    final uid = currentUserId;
    if (uid == null) throw Exception('Usuario no autenticado');

    debugPrint('[TemplatesRepo] deleteWorkoutSession: $id');
    await _getTemplatesCollection(uid).doc(id).delete();
  }

  Future<void> updateWorkoutSession(WorkoutSession session) async {
    final uid = currentUserId;
    if (uid == null) throw Exception('Usuario no autenticado');

    debugPrint('[TemplatesRepo] updateWorkoutSession: ${session.id}');
    await _getTemplatesCollection(uid).doc(session.id).update(session.toMap());
  }
}
