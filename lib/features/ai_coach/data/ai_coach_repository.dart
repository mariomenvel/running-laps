import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:running_laps/features/ai_coach/data/ai_coach_models.dart';
import 'package:running_laps/features/athlete/data/athlete_session_model.dart';

class AiCoachRepository {
  AiCoachRepository({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _db;

  String _requireUid() {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('No hay usuario autenticado');
    }
    return user.uid;
  }

  DocumentReference<Map<String, dynamic>> _settingsDoc(
    String uid,
    String docId,
  ) {
    return _db.collection('users').doc(uid).collection('settings').doc(docId);
  }

  CollectionReference<Map<String, dynamic>> _sessionsCol(String uid) {
    return _db.collection('users').doc(uid).collection('athleteSessions');
  }

  CollectionReference<Map<String, dynamic>> _eventsCol(String uid) {
    return _db.collection('users').doc(uid).collection('aiCoachEvents');
  }

  DocumentReference<Map<String, dynamic>> _globalProviderDoc() {
    return _db.collection('appConfig').doc('aiCoachProvider');
  }

  Future<AiCoachProfile?> getProfile({String? uid}) async {
    final resolvedUid = uid ?? _requireUid();
    try {
      final doc = await _settingsDoc(resolvedUid, 'aiCoachProfile').get();
      if (!doc.exists || doc.data() == null) return null;
      return AiCoachProfile.fromMap(resolvedUid, doc.data()!);
    } catch (e) {
      debugPrint('[AiCoachRepository] getProfile error: $e');
      return null;
    }
  }

  Stream<AiCoachProfile?> streamProfile({String? uid}) {
    final resolvedUid = uid ?? _requireUid();
    return _settingsDoc(resolvedUid, 'aiCoachProfile').snapshots().map((doc) {
      final data = doc.data();
      if (!doc.exists || data == null) return null;
      return AiCoachProfile.fromMap(resolvedUid, data);
    });
  }

  Future<void> saveProfile(AiCoachProfile profile) async {
    await _settingsDoc(profile.uid, 'aiCoachProfile').set(profile.toMap());
  }

  Future<AiCoachUsage?> getUsage({String? uid}) async {
    final resolvedUid = uid ?? _requireUid();
    try {
      final doc = await _settingsDoc(resolvedUid, 'aiCoachUsage').get();
      if (!doc.exists || doc.data() == null) return null;
      return AiCoachUsage.fromMap(doc.data()!);
    } catch (e) {
      debugPrint('[AiCoachRepository] getUsage error: $e');
      return null;
    }
  }

  Future<void> saveUsage(AiCoachUsage usage, {String? uid}) async {
    final resolvedUid = uid ?? _requireUid();
    await _settingsDoc(resolvedUid, 'aiCoachUsage').set(usage.toMap());
  }

  Future<void> incrementUsage({String? uid, int amount = 1}) async {
    final resolvedUid = uid ?? _requireUid();
    await _settingsDoc(resolvedUid, 'aiCoachUsage').set({
      'messagesUsed': FieldValue.increment(amount),
    }, SetOptions(merge: true));
  }

  /// Incrementa atómicamente un contador de uso sin pisar
  /// otros campos. Crea el documento si no existe.
  Future<void> incrementUsageField({
    required String uid,
    required String field,
    required DateTime periodStart,
    required DateTime periodEnd,
    int by = 1,
  }) async {
    final doc = _settingsDoc(uid, 'aiCoachUsage');
    await doc.set({
      field: FieldValue.increment(by),
      'periodStart': Timestamp.fromDate(periodStart),
      'periodEnd': Timestamp.fromDate(periodEnd),
      'plan': 'athlete_chat_weekly',
    }, SetOptions(merge: true));
  }

  Future<AiCoachWeeklyState?> getWeeklyState({String? uid}) async {
    final resolvedUid = uid ?? _requireUid();
    try {
      final doc = await _settingsDoc(resolvedUid, 'aiCoachState').get();
      if (!doc.exists || doc.data() == null) return null;
      return AiCoachWeeklyState.fromMap(doc.data()!);
    } catch (e) {
      debugPrint('[AiCoachRepository] getWeeklyState error: $e');
      return null;
    }
  }

  Future<void> saveWeeklyState(AiCoachWeeklyState state, {String? uid}) async {
    final resolvedUid = uid ?? _requireUid();
    await _settingsDoc(resolvedUid, 'aiCoachState').set(state.toMap());
  }

  Future<AiCoachWeeklyDecision?> getLastDecision({String? uid}) async {
    final resolvedUid = uid ?? _requireUid();
    try {
      final doc = await _settingsDoc(resolvedUid, 'aiCoachLastDecision').get();
      if (!doc.exists || doc.data() == null) return null;
      return AiCoachWeeklyDecision.fromMap(doc.data()!);
    } catch (e) {
      debugPrint('[AiCoachRepository] getLastDecision error: $e');
      return null;
    }
  }

  Future<void> saveLastDecision(
    AiCoachWeeklyDecision decision, {
    String? uid,
  }) async {
    final resolvedUid = uid ?? _requireUid();
    await _settingsDoc(resolvedUid, 'aiCoachLastDecision').set(decision.toMap());
  }

  Future<AiCoachProviderConfig?> getProviderConfig({String? uid}) async {
    try {
      final doc = await _globalProviderDoc().get();
      if (!doc.exists || doc.data() == null) {
        return null;
      }
      return AiCoachProviderConfig.fromMap(doc.data()!);
    } catch (e) {
      debugPrint('[AiCoachRepository] getProviderConfig error: $e');
      return null;
    }
  }

  Future<void> saveProviderConfig(
    AiCoachProviderConfig config, {
    String? uid,
  }) async {
    final resolvedUid = uid ?? _requireUid();
    await _settingsDoc(resolvedUid, 'aiCoachProvider').set(config.toMap());
  }

  Future<AiCoachAutomationState?> getAutomationState({String? uid}) async {
    final resolvedUid = uid ?? _requireUid();
    try {
      final doc = await _settingsDoc(resolvedUid, 'aiCoachAutomation').get();
      if (!doc.exists || doc.data() == null) return null;
      return AiCoachAutomationState.fromMap(doc.data()!);
    } catch (e) {
      debugPrint('[AiCoachRepository] getAutomationState error: $e');
      return null;
    }
  }

  Future<void> saveAutomationState(
    AiCoachAutomationState state, {
    String? uid,
  }) async {
    final resolvedUid = uid ?? _requireUid();
    await _settingsDoc(resolvedUid, 'aiCoachAutomation').set(
      state.toMap(),
      SetOptions(merge: true),
    );
  }

  Future<AiCoachKpiSnapshot?> getLatestKpis({String? uid}) async {
    final resolvedUid = uid ?? _requireUid();
    try {
      final doc = await _settingsDoc(resolvedUid, 'aiCoachKpiLatest').get();
      if (!doc.exists || doc.data() == null) return null;
      return AiCoachKpiSnapshot.fromMap(doc.data()!);
    } catch (e) {
      debugPrint('[AiCoachRepository] getLatestKpis error: $e');
      return null;
    }
  }

  Future<void> saveLatestKpis(
    AiCoachKpiSnapshot snapshot, {
    String? uid,
  }) async {
    final resolvedUid = uid ?? _requireUid();
    await _settingsDoc(resolvedUid, 'aiCoachKpiLatest').set(snapshot.toMap());
  }

  Future<void> clearPendingSuggestions({
    String? uid,
    required DateTime weekStart,
    required DateTime weekEnd,
  }) async {
    final resolvedUid = uid ?? _requireUid();
    final batch = _db.batch();
    final start = _dateKey(weekStart);
    final end = _dateKey(weekEnd);
    final snap = await _sessionsCol(resolvedUid)
        .where('date', isGreaterThanOrEqualTo: start)
        .where('date', isLessThanOrEqualTo: end)
        .where('suggestion.status', isEqualTo: 'suggested')
        .get();

    for (final doc in snap.docs) {
      batch.update(doc.reference, {
        'suggestion.status': 'rejected',
        'suggestion.respondedAt': Timestamp.fromDate(DateTime.now()),
        'suggestion.responseNote': 'replaced_by_new_cycle',
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });
    }
    await batch.commit();
  }

  Future<void> logEvent({
    String? uid,
    required String eventType,
    Map<String, dynamic> payload = const {},
  }) async {
    final resolvedUid = uid ?? _requireUid();
    try {
      await _eventsCol(resolvedUid).add({
        'eventType': eventType,
        'payload': payload,
        'createdAt': Timestamp.fromDate(DateTime.now()),
      });
    } catch (e) {
      debugPrint('[AiCoachRepository] logEvent skipped ($eventType): $e');
    }
  }

  Future<AiCoachAthleteMemory?> getAthleteMemory({String? uid}) async {
    final resolvedUid = uid ?? _requireUid();
    try {
      final doc = await _settingsDoc(resolvedUid, 'aiCoachAthleteMemory').get();
      if (!doc.exists || doc.data() == null) return null;
      return AiCoachAthleteMemory.fromMap(doc.data()!);
    } catch (e) {
      debugPrint('[AiCoachRepository] getAthleteMemory error: $e');
      return null;
    }
  }

  Future<void> saveAthleteMemory(
    AiCoachAthleteMemory memory, {
    String? uid,
  }) async {
    final resolvedUid = uid ?? _requireUid();
    await _settingsDoc(resolvedUid, 'aiCoachAthleteMemory').set(memory.toMap());
  }

  Future<AiCoachAthleteMemory> rebuildAthleteMemory({String? uid}) async {
    final resolvedUid = uid ?? _requireUid();
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day)
        .subtract(const Duration(days: 90));
    final startKey =
        '${start.year}-${start.month.toString().padLeft(2, '0')}-${start.day.toString().padLeft(2, '0')}';
    final endKey =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final sessions = await _sessionsCol(resolvedUid)
        .where('date', isGreaterThanOrEqualTo: startKey)
        .where('date', isLessThanOrEqualTo: endKey)
        .get();

    final acceptedByCategory = <String, int>{};
    final suggestedByCategory = <String, int>{};
    final completedByCategory = <String, int>{};
    final plannedByCategory = <String, int>{};
    final completedByWeekday = <int, int>{};
    final plannedByWeekday = <int, int>{};

    for (final doc in sessions.docs) {
      final session = AthleteSession.fromMap(doc.id, doc.data());
      final suggestion = session.suggestion;
      final category = session.category ?? 'rodaje_base';
      final weekday = DateTime.tryParse(session.date)?.weekday;
      if (suggestion != null && suggestion.origin == AthleteSessionOrigin.ai) {
        suggestedByCategory.update(category, (v) => v + 1, ifAbsent: () => 1);
      }
      if (session.status == AthleteSessionStatus.planned ||
          session.status == AthleteSessionStatus.completed) {
        plannedByCategory.update(category, (v) => v + 1, ifAbsent: () => 1);
        if (weekday != null) {
          plannedByWeekday.update(weekday, (v) => v + 1, ifAbsent: () => 1);
        }
      }
      final suggestionStatus = suggestion?.status;
      if (suggestionStatus == AthleteSessionSuggestionStatus.accepted ||
          suggestionStatus == AthleteSessionSuggestionStatus.edited) {
        acceptedByCategory.update(category, (v) => v + 1, ifAbsent: () => 1);
      }
      if (session.status == AthleteSessionStatus.completed) {
        completedByCategory.update(category, (v) => v + 1, ifAbsent: () => 1);
        if (weekday != null) {
          completedByWeekday.update(weekday, (v) => v + 1, ifAbsent: () => 1);
        }
      }
    }

    final categoryAcceptance = <String, double>{};
    final categoryCompletion = <String, double>{};
    for (final entry in suggestedByCategory.entries) {
      final accepted = acceptedByCategory[entry.key] ?? 0;
      categoryAcceptance[entry.key] =
          entry.value == 0 ? 0 : accepted / entry.value;
    }
    for (final entry in plannedByCategory.entries) {
      final completed = completedByCategory[entry.key] ?? 0;
      categoryCompletion[entry.key] =
          entry.value == 0 ? 0 : completed / entry.value;
    }
    final weekdayAdherence = <int, double>{};
    for (final entry in plannedByWeekday.entries) {
      final completed = completedByWeekday[entry.key] ?? 0;
      weekdayAdherence[entry.key] =
          entry.value == 0 ? 0 : completed / entry.value;
    }

    final style = _resolvePreferredStyle(
      categoryAcceptance: categoryAcceptance,
      categoryCompletion: categoryCompletion,
    );
    final memory = AiCoachAthleteMemory(
      preferredStyle: style,
      categoryAcceptance: categoryAcceptance,
      categoryCompletion: categoryCompletion,
      weekdayAdherence: weekdayAdherence,
      updatedAt: now,
    );
    await saveAthleteMemory(memory, uid: resolvedUid);
    return memory;
  }

  Future<AiCoachKpiSnapshot> rebuildKpis({String? uid}) async {
    final resolvedUid = uid ?? _requireUid();
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day)
        .subtract(const Duration(days: 90));
    final startKey = _dateKey(start);
    final endKey = _dateKey(now);

    final sessionsSnap = await _sessionsCol(resolvedUid)
        .where('date', isGreaterThanOrEqualTo: startKey)
        .where('date', isLessThanOrEqualTo: endKey)
        .get();
    QuerySnapshot<Map<String, dynamic>>? eventsSnap;
    try {
      eventsSnap = await _eventsCol(resolvedUid)
          .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
          .get();
    } catch (e) {
      debugPrint('[AiCoachRepository] rebuildKpis events query skipped: $e');
    }

    var suggestedCount = 0;
    var acceptedCount = 0;
    var editedCount = 0;
    var rejectedCount = 0;
    var completedCount = 0;
    var plannedCount = 0;

    for (final doc in sessionsSnap.docs) {
      final session = AthleteSession.fromMap(doc.id, doc.data());
      final suggestion = session.suggestion;
      if (suggestion?.origin == AthleteSessionOrigin.ai) {
        suggestedCount += 1;
        if (suggestion?.status == AthleteSessionSuggestionStatus.accepted) {
          acceptedCount += 1;
        } else if (suggestion?.status == AthleteSessionSuggestionStatus.edited) {
          editedCount += 1;
        } else if (suggestion?.status == AthleteSessionSuggestionStatus.rejected) {
          rejectedCount += 1;
        }
      }
      if (session.status == AthleteSessionStatus.completed) {
        completedCount += 1;
      }
      if (session.status == AthleteSessionStatus.planned ||
          session.status == AthleteSessionStatus.completed) {
        plannedCount += 1;
      }
    }

    var replansCount = 0;
    if (eventsSnap != null) {
      for (final doc in eventsSnap.docs) {
        final payload = doc.data()['payload'];
        final eventType = doc.data()['eventType']?.toString() ?? '';
        if (eventType == 'suggestion_status_updated' &&
            payload is Map &&
            payload['newStatus'] == 'edited') {
          replansCount += 1;
        }
      }
    }

    final acceptedOrEdited = acceptedCount + editedCount;
    final acceptanceRate = suggestedCount == 0
        ? 0.0
        : acceptedOrEdited / suggestedCount;
    final completionRate = plannedCount == 0 ? 0.0 : completedCount / plannedCount;

    final snapshot = AiCoachKpiSnapshot(
      computedAt: now,
      suggestedCount: suggestedCount,
      acceptedCount: acceptedCount,
      editedCount: editedCount,
      rejectedCount: rejectedCount,
      completedCount: completedCount,
      plannedCount: plannedCount,
      acceptanceRate: acceptanceRate,
      completionRate: completionRate,
      replansCount: replansCount,
    );
    await saveLatestKpis(snapshot, uid: resolvedUid);
    return snapshot;
  }

  String _resolvePreferredStyle({
    required Map<String, double> categoryAcceptance,
    required Map<String, double> categoryCompletion,
  }) {
    final qualityCategories = {
      'tempo',
      'fartlek',
      'series_cortas',
      'series_largas',
      'series_mixtas',
      'series_cuestas',
    };
    final continuousCategories = {
      'rodaje_base',
      'regenerativo',
    };
    double qualityScore = 0;
    double continuousScore = 0;
    for (final key in categoryAcceptance.keys) {
      final accept = categoryAcceptance[key] ?? 0;
      final complete = categoryCompletion[key] ?? 0;
      final score = (accept * 0.6) + (complete * 0.4);
      if (qualityCategories.contains(key)) qualityScore += score;
      if (continuousCategories.contains(key)) continuousScore += score;
    }
    if (qualityScore > continuousScore * 1.15) return 'interval_dominant';
    if (continuousScore > qualityScore * 1.15) return 'continuous_dominant';
    return 'mixed';
  }

  String _dateKey(DateTime value) {
    final date = DateTime(value.year, value.month, value.day);
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  Future<void> saveWeeklyFeedback(AiCoachWeeklyFeedback feedback) async {
    await _db
        .collection('users')
        .doc(feedback.uid)
        .collection('aiCoachFeedback')
        .doc(feedback.weekStart)
        .set(feedback.toMap());
  }

  Future<AiCoachWeeklyFeedback?> getWeeklyFeedback({
    required String uid,
    required String weekStart,
  }) async {
    try {
      final doc = await _db
          .collection('users')
          .doc(uid)
          .collection('aiCoachFeedback')
          .doc(weekStart)
          .get();
      if (!doc.exists) return null;
      return AiCoachWeeklyFeedback.fromMap(doc.data()!);
    } catch (e) {
      debugPrint('[AiCoachRepository] getWeeklyFeedback error: $e');
      return null;
    }
  }

  /// Devuelve los últimos N feedbacks semanales, más recientes primero.
  Future<List<AiCoachWeeklyFeedback>> getRecentFeedbacks({
    required String uid,
    int limit = 4,
  }) async {
    try {
      final snapshot = await _db
          .collection('users')
          .doc(uid)
          .collection('aiCoachFeedback')
          .orderBy('weekStart', descending: true)
          .limit(limit)
          .get();
      return snapshot.docs
          .map((d) => AiCoachWeeklyFeedback.fromMap(d.data()))
          .toList();
    } catch (e) {
      debugPrint('[AiCoachRepository] getRecentFeedbacks error: $e');
      return [];
    }
  }
}
