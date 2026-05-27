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

  Future<List<AthleteSession>> getSessionsInRange({
    required String uid,
    required String startDate,
    required String endDate,
  }) async {
    try {
      final snap = await _col(uid)
          .where('date', isGreaterThanOrEqualTo: startDate)
          .where('date', isLessThanOrEqualTo: endDate)
          .get();
      return snap.docs
          .map((doc) => AthleteSession.fromMap(doc.id, doc.data()))
          .toList();
    } catch (e) {
      debugPrint('[AthleteSessionRepository] getSessionsInRange error: $e');
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

  /// Sesiones con status=planned desde hoy hasta el domingo de esta semana.
  Future<List<AthleteSession>> getWeekSessions({required String uid}) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final daysUntilSunday = 7 - today.weekday;
    final sunday = today.add(Duration(days: daysUntilSunday));

    final result = <AthleteSession>[];
    for (var d = today; !d.isAfter(sunday); d = d.add(const Duration(days: 1))) {
      final dateStr =
          '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
      final sessions = await getSessionsForDate(uid: uid, date: dateStr);
      result.addAll(sessions.where((s) => s.status == AthleteSessionStatus.planned));
    }
    return result;
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

  Future<void> updateSuggestionStatus({
    required String uid,
    required String sessionId,
    required AthleteSessionSuggestionStatus status,
    String? responseNote,
  }) async {
    try {
      final sessionRef = _col(uid).doc(sessionId);
      final existing = await sessionRef.get();
      final existingData = existing.data();
      final now = Timestamp.fromDate(DateTime.now());
      final existingSuggestion = existingData?['suggestion'];
      final existingOrigin = existingSuggestion is Map
          ? existingSuggestion['origin']?.toString()
          : null;

      if (status == AthleteSessionSuggestionStatus.rejected &&
          existingOrigin == AthleteSessionOrigin.ai.toValue) {
        await sessionRef.delete();
        await _db.collection('users').doc(uid).collection('aiCoachEvents').add({
          'eventType': 'suggestion_status_updated',
          'payload': {
            'sessionId': sessionId,
            'date': existingData?['date'],
            'previousStatus': existingSuggestion is Map
                ? existingSuggestion['status']
                : null,
            'newStatus': 'rejected',
            'removed': true,
            if (responseNote != null) 'responseNote': responseNote,
          },
          'createdAt': now,
        });
        return;
      }

      await sessionRef.update({
        'suggestion.status': status.toValue,
        'suggestion.respondedAt': now,
        if (responseNote != null) 'suggestion.responseNote': responseNote,
        'updatedAt': now,
      });
      await _db.collection('users').doc(uid).collection('aiCoachEvents').add({
        'eventType': 'suggestion_status_updated',
        'payload': {
          'sessionId': sessionId,
          'date': existingData?['date'],
          'previousStatus': existingData?['suggestion'] is Map
              ? (existingData!['suggestion'] as Map)['status']
              : null,
          'newStatus': status.toValue,
          if (responseNote != null) 'responseNote': responseNote,
        },
        'createdAt': now,
      });
    } catch (e) {
      debugPrint('[AthleteSessionRepository] updateSuggestionStatus error: $e');
      rethrow;
    }
  }

  Future<void> deletePendingSuggestedSessionsInRange({
    required String uid,
    required String startDate,
    required String endDate,
  }) async {
    try {
      final snap = await _col(uid)
          .where('date', isGreaterThanOrEqualTo: startDate)
          .where('date', isLessThanOrEqualTo: endDate)
          .get();
      final batch = _db.batch();
      final docsToDelete = snap.docs.where((doc) {
        final session = AthleteSession.fromMap(doc.id, doc.data());
        return session.suggestion?.origin == AthleteSessionOrigin.ai &&
            session.suggestion?.status ==
                AthleteSessionSuggestionStatus.suggested;
      });
      for (final doc in docsToDelete) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    } catch (e) {
      debugPrint(
          '[AthleteSessionRepository] deletePendingSuggestedSessionsInRange error: $e');
      rethrow;
    }
  }
}
