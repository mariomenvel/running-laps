import 'package:cloud_firestore/cloud_firestore.dart';
import '../../groups/data/models/challenge_models.dart';
import '../../groups/data/models/enums.dart';

class AdminRepository {
  final FirebaseFirestore _firestore;

  AdminRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  /// Obtiene estadísticas globales avanzadas de negocio
  /// [startDate]: Si no es null, filtra entrenamientos desde esa fecha.
  Future<Map<String, dynamic>> getGlobalStats({DateTime? startDate}) async {
    int totalUsers = 0;
    int onboardedUsers = 0;
    int totalChallenges = 0;
    
    // Métricas de Entrenamientos
    int totalKm = 0;
    List<Map<String, dynamic>> recentTrainingsSample = [];

    try {
      // 1. Usuarios y Onboarding
      final usersSnap = await _firestore.collection('users').count().get();
      totalUsers = usersSnap.count ?? 0;

      final onboardedSnap = await _firestore
          .collection('users')
          .where('avatarConfig', isNull: false)
          .count()
          .get();
      onboardedUsers = onboardedSnap.count ?? 0;

      // 2. Retos Activos
      final challengesSnap = await _firestore.collection('global_challenges').count().get();
      totalChallenges = challengesSnap.count ?? 0;

      try {
        // Traemos "todos" (limitado a 1000 para seguridad) 
        // Intentamos ordenar por fecha para asegurar que los 1000 sean los más recientes.
        // Si no hay índice, fallará y saltará al catch, donde intentamos sin ordenar.
        QuerySnapshot<Map<String, dynamic>> rawSnap;
        try {
          rawSnap = await _firestore.collectionGroup('trainings')
              .orderBy('fecha', descending: true)
              .limit(1000) 
              .get();
        } catch (orderedError) {
          print("Aviso: No hay índice para ordenar trainings. Usando fallback no ordenado.");
          rawSnap = await _firestore.collectionGroup('trainings')
              .limit(1000) 
              .get();
        }
            
        final allDocs = rawSnap.docs.map((d) => d.data()).toList();
        
        // Procesamiento en Cliente (Dart)
        // a. Ordenar por fecha (descendente) - Por si el fallback no ordenado devolvió datos dispersos
        allDocs.sort((a, b) {
           final da = _parseFechaRobust(a['fecha']);
           final db = _parseFechaRobust(b['fecha']);
           return db.compareTo(da); // Descending
        });

        // b. Filtrar por Fecha (si aplica)
        List<Map<String, dynamic>> filteredDocs = allDocs;
        if (startDate != null) {
          filteredDocs = allDocs.where((d) {
             final f = d['fecha'];
             if (f == null) return false;
             final date = _parseFechaRobust(f);
             return date.isAfter(startDate) || date.isAtSameMomentAs(startDate);
          }).toList();
        }

        // c. Calcular Totales
        for (var doc in filteredDocs) {
          totalKm += (doc['distanciaTotalM'] as num? ?? 0).toInt();
        }

        // d. Extraer Muestra (Top 50 del periodo filtrado)
        recentTrainingsSample = filteredDocs.take(50).toList();

      } catch (e) {
         print("Error crítico leyendo trainings: $e");
         // Si falla collectionGroup, intentar fallback iterando usuarios (muy lento, último recurso)
         // O simplemente dejar en 0.
      }

    } catch (e) {
      print("Error fetching advanced stats: $e");
    }

    return {
      'totalUsers': totalUsers,
      'onboardedUsers': onboardedUsers,
      'activeChallenges': totalChallenges,
      'totalKm': totalKm,
      'recentTrainingsSample': recentTrainingsSample,
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

  /// Parsea una fecha de forma robusta aceptando ISO String, int (ms) o Timestamp
  DateTime _parseFechaRobust(dynamic v) {
    if (v == null) return DateTime(1970);
    if (v is String) return DateTime.tryParse(v) ?? DateTime(1970);
    if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
    if (v is Timestamp) return v.toDate();
    return DateTime(1970);
  }
}
