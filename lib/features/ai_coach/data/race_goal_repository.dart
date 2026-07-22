import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:running_laps/features/ai_coach/data/race_goal.dart';

/// CRUD de competiciones objetivo en `users/{uid}/raceGoals`.
///
/// Fuente única de verdad de la fecha objetivo del atleta: el Coach deriva
/// de aquí el `targetDate`/taper, el calendario pinta los días y la Home
/// muestra la cuenta atrás.
class RaceGoalRepository {
  RaceGoalRepository({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
  })  : _auth = auth,
        _db = firestore ?? FirebaseFirestore.instance;

  // Perezoso: se resuelve solo si se llama a un método sin `uid` explícito.
  // Evita tocar FirebaseAuth.instance en el constructor (tests sin Firebase).
  final FirebaseAuth? _auth;
  final FirebaseFirestore _db;

  String _requireUid() {
    final user = (_auth ?? FirebaseAuth.instance).currentUser;
    if (user == null) {
      throw Exception('No hay usuario autenticado');
    }
    return user.uid;
  }

  CollectionReference<Map<String, dynamic>> _goalsCol(String uid) {
    return _db.collection('users').doc(uid).collection('raceGoals');
  }

  Stream<List<RaceGoal>> streamGoals({String? uid}) {
    final resolvedUid = uid ?? _requireUid();
    return _goalsCol(resolvedUid).orderBy('date').snapshots().map(
          (snap) => snap.docs
              .map((doc) => RaceGoal.fromMap(doc.id, doc.data()))
              .toList(),
        );
  }

  Future<List<RaceGoal>> getGoals({String? uid}) async {
    final resolvedUid = uid ?? _requireUid();
    try {
      final snap = await _goalsCol(resolvedUid).orderBy('date').get();
      return snap.docs
          .map((doc) => RaceGoal.fromMap(doc.id, doc.data()))
          .toList();
    } catch (e) {
      debugPrint('[RaceGoalRepository] getGoals error: $e');
      return const [];
    }
  }

  /// Crea o actualiza un objetivo. Si `goal.id` está vacío genera un id nuevo.
  /// Devuelve el objetivo persistido (con su id).
  Future<RaceGoal> saveGoal(RaceGoal goal, {String? uid}) async {
    final resolvedUid = uid ?? _requireUid();
    final doc = goal.id.isEmpty
        ? _goalsCol(resolvedUid).doc()
        : _goalsCol(resolvedUid).doc(goal.id);
    final persisted = goal.id.isEmpty ? goal.copyWith() : goal;
    await doc.set(persisted.toMap());
    return RaceGoal.fromMap(doc.id, persisted.toMap());
  }

  Future<void> deleteGoal(String id, {String? uid}) async {
    final resolvedUid = uid ?? _requireUid();
    await _goalsCol(resolvedUid).doc(id).delete();
  }
}
