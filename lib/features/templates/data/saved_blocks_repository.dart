import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'saved_block.dart';
import 'workout_block.dart';

class SavedBlocksRepository {
  static const int freeLimit = 30;

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference _col(String uid) =>
      _db.collection('users').doc(uid).collection('savedBlocks');

  String get _uid =>
      FirebaseAuth.instance.currentUser?.uid ??
      (throw Exception('Usuario no autenticado'));

  Future<List<SavedBlock>> getSavedBlocks() async {
    final snap = await _col(_uid)
        .orderBy('usageCount', descending: true)
        .get();
    return snap.docs
        .map((d) => SavedBlock.fromMap(d.id, d.data() as Map<String, dynamic>))
        .toList();
  }

  Future<List<SavedBlock>> getSavedBlocksByRole(BlockRole role) async {
    final snap = await _col(_uid)
        .where('role', isEqualTo: role.name)
        .orderBy('usageCount', descending: true)
        .get();
    return snap.docs
        .map((d) => SavedBlock.fromMap(d.id, d.data() as Map<String, dynamic>))
        .toList();
  }

  Future<void> saveBlock(SavedBlock block) async {
    final count = await getCount();
    if (count >= freeLimit) {
      throw Exception('Límite de bloques guardados alcanzado');
    }
    await _col(_uid).doc(block.id).set(block.toMap());
  }

  Future<void> deleteBlock(String blockId) async {
    await _col(_uid).doc(blockId).delete();
  }

  Future<void> incrementUsage(String blockId) async {
    await _col(_uid).doc(blockId).update({
      'usageCount': FieldValue.increment(1),
    });
  }

  Future<int> getCount() async {
    final snap = await _col(_uid).count().get();
    return snap.count ?? 0;
  }
}
