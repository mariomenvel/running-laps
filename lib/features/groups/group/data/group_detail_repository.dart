import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../training/data/entrenamiento.dart'; // Importa tus modelos existentes
import '../../group_model.dart';   // Reusamos GroupMemberStats
import '../data/challenge_model.dart';

class GroupDetailRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // --- 1. RANKING CON FILTRO DE FECHA ---
  
  /// Calcula el ranking. Si [onlyThisMonth] es true, filtra entrenos del mes actual.
  Future<List<GroupMemberStats>> fetchMemberStats(String groupId, {bool onlyThisMonth = true}) async {
    try {
      // A. Obtener IDs de miembros del grupo
      final groupDoc = await _db.collection('groups').doc(groupId).get();
      if (!groupDoc.exists) return [];
      
      final List<String> memberIds = List<String>.from(groupDoc.data()?['members'] ?? []);
      
      // B. Calcular stats en paralelo
      List<Future<GroupMemberStats?>> futures = [];
      for (String uid in memberIds) {
        futures.add(_calculateUserDist(uid, onlyThisMonth));
      }
      
      final results = await Future.wait(futures);
      final validStats = results.whereType<GroupMemberStats>().toList();
      
      // C. Ordenar (Ranking)
      validStats.sort((a, b) => b.totalKm.compareTo(a.totalKm));
      return validStats;

    } catch (e) {
      print("Error fetching details: $e");
      return [];
    }
  }

  Future<GroupMemberStats?> _calculateUserDist(String uid, bool onlyThisMonth) async {
    try {
      final userDoc = await _db.collection('User').doc(uid).get();
      if (!userDoc.exists) return null;

      final userData = userDoc.data()!;
      // Optimización: Podríamos filtrar en la Query de Firestore por fecha, 
      // pero como guardas fecha como String ISO8601 en tu modelo Entrenamiento,
      // descargamos y filtramos en memoria (para MVP está bien).
      final trainingsSnap = await _db.collection('User').doc(uid).collection('trainings').get();

      double totalKm = 0;
      final now = DateTime.now();

      for (var doc in trainingsSnap.docs) {
        final t = Entrenamiento.fromMap(doc.data());
        
        bool include = true;
        if (onlyThisMonth) {
          include = t.fecha.month == now.month && t.fecha.year == now.year;
        }

        if (include) {
          totalKm += (t.distanciaTotalM() / 1000.0);
        }
      }

      return GroupMemberStats(
        uid: uid,
        name: userData['nombre'] ?? 'Usuario',
        totalKm: totalKm,
        photoUrl: userData['photoUrl'],
      );
    } catch (e) {
      return null;
    }
  }

  // --- 2. RETOS (CHALLENGES) ---

  Stream<List<ChallengeModel>> getChallengesStream(String groupId) {
    return _db
        .collection('groups')
        .doc(groupId)
        .collection('challenges')
        .orderBy('endDate', descending: false)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ChallengeModel.fromFirestore(doc.data(), doc.id))
            .toList());
  }

  // --- 3. GENERADOR DE DATOS (SEEDING) ---
  // Llama a esto al iniciar la pantalla para crear retos si no existen
  Future<void> checkAndSeedChallenges(String groupId) async {
    final ref = _db.collection('groups').doc(groupId).collection('challenges');
    final snap = await ref.get();
    
    if (snap.docs.isEmpty) {
      print("SEEDING: Creando retos por defecto...");
      // Reto 1: Mensual
      await ref.add({
        'title': 'El Gran Fondo de Noviembre',
        'description': 'Completa 100km acumulados este mes.',
        'targetKm': 100,
        'endDate': Timestamp.fromDate(DateTime.now().add(const Duration(days: 30))),
        'participantsCount': 3,
      });
      // Reto 2: Semanal
      await ref.add({
        'title': 'Velocidad Pura',
        'description': 'Corre 3 veces esta semana.',
        'targetKm': 15,
        'endDate': Timestamp.fromDate(DateTime.now().add(const Duration(days: 7))),
        'participantsCount': 5,
      });
    }
  }
}