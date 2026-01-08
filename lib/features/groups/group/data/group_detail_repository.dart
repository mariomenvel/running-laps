import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../training/data/entrenamiento.dart'; // Importa tus modelos existentes
import '../../group_model.dart';   // Reusamos GroupMemberStats
import '../data/challenge_model.dart';
import '../../data/enums.dart'; // MemberStatus

class GroupDetailRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // --- 1. RANKING CON FILTRO DE FECHA ---
  
  /// Calcula el ranking. Si [onlyThisMonth] es true, filtra entrenos del mes actual.
  Future<List<GroupMemberStats>> fetchMemberStats(String groupId, {bool onlyThisMonth = true}) async {
    try {
    // A. Obtener miembros de la subcolección 'members'
      final membersSnap = await _db
          .collection('groups')
          .doc(groupId)
          .collection('members')
          .get();
      
      if (membersSnap.docs.isEmpty) return [];
      
      // Map UID -> Status
      final memberStatusMap = <String, MemberStatus>{};
      for (var doc in membersSnap.docs) {
        final data = doc.data();
        memberStatusMap[doc.id] = MemberStatus.fromFirestore(data['status'] ?? 'active');
      }
      
      // B. Calcular stats en paralelo
      List<Future<GroupMemberStats?>> futures = [];
      for (String uid in memberStatusMap.keys) {
        futures.add(_calculateUserDist(uid, onlyThisMonth, memberStatusMap[uid]!));
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

  Future<GroupMemberStats?> _calculateUserDist(String uid, bool onlyThisMonth, MemberStatus status) async {
    try {
      final userDoc = await _db.collection('users').doc(uid).get();
      if (!userDoc.exists) return null;

      final userData = userDoc.data()!;
      // Optimización: Podríamos filtrar en la Query de Firestore por fecha, 
      // pero como guardas fecha como String ISO8601 en tu modelo Entrenamiento,
      // descargamos y filtramos en memoria (para MVP está bien).
      final trainingsSnap = await _db.collection('users').doc(uid).collection('trainings').get();

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
        profilePicType: userData['profilePicType'],
        avatarConfig: userData['avatarConfig'],
        status: status,
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

  // --- 3. LOGICA DE RETO (JOIN & PROGRESS) ---

  Future<void> joinChallenge(String groupId, String challengeId, String uid) async {
    await _db
        .collection('groups')
        .doc(groupId)
        .collection('challenges')
        .doc(challengeId)
        .update({
      'participants': FieldValue.arrayUnion([uid])
    });
  }

  Future<double> calculateChallengeProgress(String uid, DateTime start, DateTime end) async {
    try {
      // Aseguramos que 'start' sea el inicio del día (00:00:00) para incluir todos los entrenos de ese día
      final DateTime startOfDay = DateTime(start.year, start.month, start.day);
      final DateTime endOfDay = DateTime(end.year, end.month, end.day, 23, 59, 59);

      // Reusamos logica de filtrar entrenamientos
      // Idealmente, harías una query con filtro de fecha si tienes muchos, pero por ahora encadenamos en memoria
      // NOTA: Firestore guarda String ISO8601. La comparación lexicográfica funciona si el formato es estándar 'YYYY-MM-DD...'
      final trainingsSnap = await _db
          .collection('users')
          .doc(uid)
          .collection('trainings')
          .where('fecha', isGreaterThanOrEqualTo: startOfDay.toIso8601String())
          .get();

      double totalM = 0;
      for (var doc in trainingsSnap.docs) {
        final t = Entrenamiento.fromMap(doc.data());
        
        // Verificamos rango exacto en memoria
        if (t.fecha.isAfter(startOfDay.subtract(const Duration(seconds: 1))) && 
            t.fecha.isBefore(endOfDay)) { 
           totalM += t.distanciaTotalM();
        }
      }
      return totalM / 1000.0; // Return KM
    } catch (e) {
      print("Error calculating progress: $e");
      return 0.0;
    }
  }

  // --- 4. DATOS PARA PERFIL (Gamification) ---
  Future<List<Entrenamiento>> fetchUserTrainings(String uid) async {
    try {
      final snap = await _db.collection('users').doc(uid).collection('trainings').orderBy('fecha', descending: true).get();
      return snap.docs.map((d) => Entrenamiento.fromMap(d.data())).toList();
    } catch (e) {
      print("Error fetching user history: $e");
      return [];
    }
  }

  // --- 5. LEADERBOARD RETO ---
  Future<List<GroupMemberStats>> fetchChallengeLeaderboard(List<String> uids, DateTime start, DateTime end) async {
     List<Future<GroupMemberStats?>> futures = [];
     
     for (String uid in uids) {
       futures.add(_getChallengeUserStat(uid, start, end));
     }
     
     final results = await Future.wait(futures);
     final validStats = results.whereType<GroupMemberStats>().toList();
     
     // Ordenar por mayor distancia
     validStats.sort((a, b) => b.totalKm.compareTo(a.totalKm));
     return validStats;
  }

  Future<GroupMemberStats?> _getChallengeUserStat(String uid, DateTime start, DateTime end) async {
    try {
      // 1. Datos usuario
      final userDoc = await _db.collection('users').doc(uid).get();
      if (!userDoc.exists) return null;
      final userData = userDoc.data()!;

      // 2. Progreso
      final km = await calculateChallengeProgress(uid, start, end);

      return GroupMemberStats(
        uid: uid,
        name: userData['nombre'] ?? 'Usuario',
        totalKm: km, // Aquí guardamos el progreso del reto
        photoUrl: userData['photoUrl'],
        profilePicType: userData['profilePicType'],
        avatarConfig: userData['avatarConfig'],
      );
    } catch (e) {
      return null;
    }
  }  

  // --- 6. GENERADOR DE DATOS (SEEDING) ---
  // Llama a esto al iniciar la pantalla para crear retos si no existen
  Future<void> checkAndSeedChallenges(String groupId) async {
    final ref = _db.collection('groups').doc(groupId).collection('challenges');
    final snap = await ref.get();
    
    if (snap.docs.isEmpty) {
      print("SEEDING: Creando retos por defecto...");
      final now = DateTime.now();
      
      // Reto 1: Mensual
      await ref.add({
        'title': 'El Gran Fondo de Noviembre',
        'description': 'Completa 100km acumulados este mes.',
        'targetKm': 100,
        'startDate': Timestamp.fromDate(now),
        'endDate': Timestamp.fromDate(now.add(const Duration(days: 30))),
        'participants': [],
        'participantsCount': 0,
      });
      // Reto 2: Semanal
      await ref.add({
        'title': 'Velocidad Pura',
        'description': 'Corre 3 veces esta semana.',
        'targetKm': 15,
        'startDate': Timestamp.fromDate(now),
        'endDate': Timestamp.fromDate(now.add(const Duration(days: 7))),
        'participants': [],
        'participantsCount': 0,
      });
    }
  }
}