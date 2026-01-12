import 'package:cloud_firestore/cloud_firestore.dart';
import '../../groups/data/models/challenge_models.dart';
import '../../groups/data/models/enums.dart';

class AdminRepository {
  final FirebaseFirestore _firestore;

  AdminRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  /// Obtiene estadísticas globales (simuladas o agregadas)
  Future<Map<String, dynamic>> getGlobalStats() async {
    // NOTA: En una app real de producción, hacer count() de todos los usuarios
    // o sumar todas las distancias cada vez es costoso. 
    // Lo ideal es tener Cloud Functions que actualicen un documento 'stats/global'.
    
    // Aquí haremos algunas consultas simples para demostrar.
    int totalUsers = 0;
    int totalChallenges = 0;

    try {
      final usersSnap = await _firestore.collection('users').count().get();
      totalUsers = usersSnap.count ?? 0;

      final challengesSnap = await _firestore.collection('global_challenges').count().get();
      totalChallenges = challengesSnap.count ?? 0;
    } catch (e) {
      print("Error fetching stats: $e");
    }

    return {
      'totalUsers': totalUsers,
      'activeChallenges': totalChallenges, // Simplificación
      'systemHealth': 'Operational',
    };
  }

  /// Crea un reto global
  Future<void> createGlobalChallenge(Challenge challenge) async {
    await _firestore
        .collection('global_challenges')
        .doc(challenge.id)
        .set(challenge.toMap());
  }

  /// Obtiene los retos globales
  Stream<List<Challenge>> getGlobalChallenges() {
    return _firestore
        .collection('global_challenges')
        .orderBy('startAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return Challenge.fromMap(doc.data(), id: doc.id);
      }).toList();
    });
  }

  /// Elimina un reto global
  Future<void> deleteGlobalChallenge(String challengeId) async {
    await _firestore.collection('global_challenges').doc(challengeId).delete();
  }
}
