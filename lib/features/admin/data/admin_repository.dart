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

      // 3. Totales de Entrenamientos - ESTRATEGIA ROBUSTA (SIN ÍNDICES)
      // Firestore requiere índices para queries collectionGroup con filtros+orden.
      // Para asegurar que el usuario vea datos SIN configurar nada en consola,
      // traemos los documentos "raw" y procesamos en memoria.
      try {
        // Traemos "todos" (limitado a 1000 para seguridad) sin ordenar ni filtrar
        // Esto suele funcionar por defecto en collectionGroup.
        final rawSnap = await _firestore.collectionGroup('trainings')
            .limit(1000) 
            .get();
            
        final allDocs = rawSnap.docs.map((d) => d.data()).toList();
        
        // Procesamiento en Cliente (Dart)
        // a. Ordenar por fecha (descendente)
        allDocs.sort((a, b) {
           final da = DateTime.tryParse(a['fecha'] ?? '') ?? DateTime(1970);
           final db = DateTime.tryParse(b['fecha'] ?? '') ?? DateTime(1970);
           return db.compareTo(da); // Descending
        });

        // b. Filtrar por Fecha (si aplica)
        List<Map<String, dynamic>> filteredDocs = allDocs;
        if (startDate != null) {
          final startIso = startDate.toIso8601String();
          filteredDocs = allDocs.where((d) {
             final f = d['fecha'];
             // Comparación simple de strings ISO8601 funciona cronológicamente
             return f != null && (f as String).compareTo(startIso) >= 0;
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
}
