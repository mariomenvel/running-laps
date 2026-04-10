import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:running_laps/features/athlete/data/athlete_session_model.dart';

class AthleteSessionRepository {
  FirebaseFirestore get _db => FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _col(String uid) =>
      _db.collection('users').doc(uid).collection('athleteSessions');

  // ── Read ──────────────────────────────────────────────────────────────────

  /// Stream of sessions whose [date] falls within [startDate]..[endDate] (inclusive).
  /// ISO8601 date strings are lexicographically ordered — string comparison works.
  Stream<List<AthleteSession>> streamSessionsInRange({
    required String uid,
    required String startDate,
    required String endDate,
  }) {
    return _col(uid)
        .where('date', isGreaterThanOrEqualTo: startDate)
        .where('date', isLessThanOrEqualTo: endDate)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => AthleteSession.fromMap(doc.id, doc.data()))
            .toList())
        .handleError((Object e) {
      debugPrint('[AthleteSessionRepository] streamSessionsInRange error: $e');
    });
  }

  /// One-shot query for sessions on a specific date.
  /// Used to offer linking a finished training to a planned session.
  Future<List<AthleteSession>> getSessionsForDate({
    required String uid,
    required String date,
  }) async {
    try {
      final snap = await _col(uid).where('date', isEqualTo: date).get();
      return snap.docs
          .map((doc) => AthleteSession.fromMap(doc.id, doc.data()))
          .toList();
    } catch (e) {
      debugPrint('[AthleteSessionRepository] getSessionsForDate error: $e');
      return [];
    }
  }

  Future<AthleteSession?> getSession({
    required String uid,
    required String id,
  }) async {
    try {
      final doc = await _col(uid).doc(id).get();
      if (!doc.exists) return null;
      return AthleteSession.fromMap(doc.id, doc.data()!);
    } catch (e) {
      debugPrint('[AthleteSessionRepository] getSession error: $e');
      return null;
    }
  }

  // ── Write ─────────────────────────────────────────────────────────────────

  Future<void> createSession(AthleteSession session) async {
    try {
      final id = session.id.isEmpty
          ? DateTime.now().millisecondsSinceEpoch.toString()
          : session.id;
      await _col(session.uid).doc(id).set(session.toMap());
    } catch (e) {
      debugPrint('[AthleteSessionRepository] createSession error: $e');
      rethrow;
    }
  }

  Future<void> updateSession(AthleteSession session) async {
    try {
      await _col(session.uid).doc(session.id).update(session.toMap());
    } catch (e) {
      debugPrint('[AthleteSessionRepository] updateSession error: $e');
      rethrow;
    }
  }

  Future<void> deleteSession({
    required String uid,
    required String id,
  }) async {
    try {
      await _col(uid).doc(id).delete();
    } catch (e) {
      debugPrint('[AthleteSessionRepository] deleteSession error: $e');
      rethrow;
    }
  }

  /// Marks a session as completed and records the fulfilled training id.
  Future<void> markAsCompleted({
    required String uid,
    required String sessionId,
    required String trainingId,
  }) async {
    try {
      await _col(uid).doc(sessionId).update({
        'status':              'completed',
        'completedTrainingId': trainingId,
        'updatedAt':           Timestamp.fromDate(DateTime.now()),
      });
    } catch (e) {
      debugPrint('[AthleteSessionRepository] markAsCompleted error: $e');
      rethrow;
    }
  }
}
