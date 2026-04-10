import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:running_laps/features/calendar/data/planned_session_model.dart';

class PlannedSessionRepository {
  FirebaseFirestore get _db => FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _col(String uid) =>
      _db.collection('users').doc(uid).collection('plannedSessions');

  // ── Read ──────────────────────────────────────────────────────────────────

  /// Stream of sessions whose [date] falls within [startDate]..[endDate] (inclusive).
  /// ISO8601 date strings sort lexicographically, so string comparison is correct.
  Stream<List<PlannedSession>> streamSessionsInRange({
    required String uid,
    required String startDate,
    required String endDate,
  }) {
    return _col(uid)
        .where('date', isGreaterThanOrEqualTo: startDate)
        .where('date', isLessThanOrEqualTo: endDate)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => PlannedSession.fromMap(doc.id, doc.data()))
            .toList())
        .handleError((Object e) {
      debugPrint('[PlannedSessionRepository] streamSessionsInRange error: $e');
    });
  }

  /// Returns a single session by id, or null if not found.
  Future<PlannedSession?> getSession({
    required String uid,
    required String id,
  }) async {
    try {
      final doc = await _col(uid).doc(id).get();
      if (!doc.exists) return null;
      return PlannedSession.fromMap(doc.id, doc.data()!);
    } catch (e) {
      debugPrint('[PlannedSessionRepository] getSession error: $e');
      return null;
    }
  }

  // ── Write ─────────────────────────────────────────────────────────────────

  Future<void> createSession(PlannedSession session) async {
    try {
      await _col(session.uid).doc(session.id).set(session.toMap());
    } catch (e) {
      debugPrint('[PlannedSessionRepository] createSession error: $e');
      rethrow;
    }
  }

  Future<void> updateSession(PlannedSession session) async {
    try {
      await _col(session.uid).doc(session.id).update(session.toMap());
    } catch (e) {
      debugPrint('[PlannedSessionRepository] updateSession error: $e');
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
      debugPrint('[PlannedSessionRepository] deleteSession error: $e');
      rethrow;
    }
  }

  /// Returns all planned (status == 'planned') sessions for a given date.
  /// One-shot query — not a stream.
  Future<List<PlannedSession>> getPlannedSessionsForDate({
    required String uid,
    required String date,
  }) async {
    try {
      final snap = await _col(uid)
          .where('date', isEqualTo: date)
          .where('status', isEqualTo: 'planned')
          .get();
      return snap.docs
          .map((doc) => PlannedSession.fromMap(doc.id, doc.data()))
          .toList();
    } catch (e) {
      debugPrint('[PlannedSessionRepository] getPlannedSessionsForDate error: $e');
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
        'status':               'completed',
        'completedTrainingId':  trainingId,
        'updatedAt':            Timestamp.fromDate(DateTime.now()),
      });
    } catch (e) {
      debugPrint('[PlannedSessionRepository] markAsCompleted error: $e');
      rethrow;
    }
  }
}

