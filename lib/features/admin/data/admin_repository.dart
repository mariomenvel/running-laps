import 'package:cloud_firestore/cloud_firestore.dart';
import '../../groups/data/models/challenge_models.dart';
import '../../groups/data/models/enums.dart';

class AdminRepository {
  final FirebaseFirestore _firestore;

  AdminRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  /// Obtiene estadísticas globales avanzadas de negocio
  /// [startDate] y [endDate] definen el rango de filtro.
  Future<Map<String, dynamic>> getGlobalStats({DateTime? startDate, DateTime? endDate}) async {
    int totalUsers = 0;
    int onboardedUsers = 0;
    int totalChallenges = 0;
    
    // Métricas de Entrenamientos
    int totalKm = 0;
    List<Map<String, dynamic>> recentTrainingsSample = [];
    double avgWeeklyDistance = 0;
    double avgDistancePerTraining = 0;
    double avgRpe = 0;
    double totalRpe = 0;
    int rpeCount = 0;

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

      // 2. Retos Activos (Totales absolutos siempre, o filtrados? Normalmente totales)
      final challengesSnap = await _firestore.collection('global_challenges').count().get();
      totalChallenges = challengesSnap.count ?? 0;

      try {
        // Traemos "todos" (limitado a 1000)
        QuerySnapshot<Map<String, dynamic>> rawSnap;
        try {
          rawSnap = await _firestore.collectionGroup('trainings')
              .orderBy('fecha', descending: true)
              .limit(1000) 
              .get();
        } catch (orderedError) {
          rawSnap = await _firestore.collectionGroup('trainings')
              .limit(1000) 
              .get();
        }
            
        final allDocs = rawSnap.docs.map((d) {
          final data = d.data();
          if (data['userId'] == null && d.reference.parent.parent != null) {
            data['userId'] = d.reference.parent.parent!.id;
          }
          return data;
        }).toList();
        
        // a. Ordenar por fecha (descendente)
        allDocs.sort((a, b) {
           final da = _parseFechaRobust(a['fecha']);
           final db = _parseFechaRobust(b['fecha']);
           return db.compareTo(da); 
        });

        // b. Filtrar por RANGO DE FECHA
        List<Map<String, dynamic>> filteredDocs = allDocs;
        if (startDate != null) {
          filteredDocs = allDocs.where((d) {
             final f = d['fecha'];
             if (f == null) return false;
             final date = _parseFechaRobust(f);
             
             bool afterStart = date.isAfter(startDate) || date.isAtSameMomentAs(startDate);
             bool beforeEnd = true;
             if (endDate != null) {
               // EndDate suele ser el final del día, aseguramos comparación
               beforeEnd = date.isBefore(endDate) || date.isAtSameMomentAs(endDate);
             }
             return afterStart && beforeEnd;
          }).toList();
        } else if (endDate != null) {
           // Solo end date (raro pero posible)
           filteredDocs = allDocs.where((d) {
             final f = d['fecha'];
             final date = _parseFechaRobust(f);
             return date.isBefore(endDate) || date.isAtSameMomentAs(endDate);
           }).toList();
        }

        // c. Calcular Totales (Km) y RPE
        for (var doc in filteredDocs) {
          totalKm += (doc['distanciaTotalM'] as num? ?? 0).toInt();
          final rpe = (doc['rpePromedio'] as num? ?? 0).toDouble();
          if (rpe > 0) {
            totalRpe += rpe;
            rpeCount++;
          }
        }

        // d. Extraer Muestra
        recentTrainingsSample = filteredDocs.take(50).toList();

        // e. Calcular "Active Users" en el periodo
        // Definición dinámica: Usuarios que tienen al menos 1 entreno en el periodo filtrado.
        // Si el filtro es "Todo", son usuarios activos históricos (todos los que han entrenado alguna vez).
        int activeUsersCount = 0;
        Set<String> activeUserIds = {};
        
        if (filteredDocs.isNotEmpty) {
           activeUserIds = filteredDocs.map((d) => d['userId'] as String).toSet();
           activeUsersCount = activeUserIds.length;
        }

        // f. Calcular Consistencia (Entrenos / Usuario / Semana)
        double consistencyRate = 0;
        
        // Filtramos (ya están filtrados por fecha, y si activeUserIds sale de filteredDocs, son todos)
        // La lógica de "Activos" vs "Churned" se unifica: En el periodo seleccionado, 
        // la consistencia es sobre los usuarios que participaron en ese periodo.
        
        if (filteredDocs.isNotEmpty) {
           double weeks = 1; 
           if (startDate != null) {
              final end = endDate ?? DateTime.now();
              final diff = end.difference(startDate);
              weeks = diff.inDays / 7;
              if (weeks < 1) weeks = 1;
           } else {
              if (filteredDocs.isNotEmpty) {
                 final oldest = _parseFechaRobust(filteredDocs.last['fecha']); 
                 final newest = _parseFechaRobust(filteredDocs.first['fecha']);
                 final diff = newest.difference(oldest);
                 weeks = diff.inDays / 7;
                 if (weeks < 1) weeks = 1;
              }
           }
           
           if (activeUsersCount > 0) {
              consistencyRate = (filteredDocs.length / activeUsersCount) / weeks;
           }

           // i. Calcular Distancia Media Semanal (km/semana por usuario activo)
           if (activeUsersCount > 0 && weeks > 0) {
             avgWeeklyDistance = (totalKm / 1000.0) / activeUsersCount / weeks;
           }

           // j. Calcular Distancia Media por Entrenamiento
           if (filteredDocs.isNotEmpty) {
             avgDistancePerTraining = (totalKm / 1000.0) / filteredDocs.length;
           }

           // k. Calcular RPE Medio
           avgRpe = rpeCount > 0 ? totalRpe / rpeCount : 0.0;
        }

        // g. Calcular Métricas de Retos (Global vs Grupo)
        // Filtrar participaciones también por fecha? 
        // Los challenges tienen startAt/endAt. Participations joinedAt.
        // Si filtro la dashboard "Semana Pasada", ¿quiero ver quién se unió a retos esa semana?
        // SÍ, para mantener coherencia.
        
        Set<String> globalUniqueParticipants = {};
        Set<String> groupUniqueParticipants = {};
        int globalTotalEnrollments = 0;
        int groupTotalEnrollments = 0;
        int globalCompletedCount = 0;
        int groupCompletedCount = 0;

        try {
           final partSnap = await _firestore.collectionGroup('participations')
              .limit(500) 
              .get();
              
           if (partSnap.docs.isNotEmpty) {
             for (var doc in partSnap.docs) {
               final data = doc.data();
               final uid = data['userId'] as String? ?? doc.id; 
               
               // Solo consideramos si el usuario está activo en este periodo (ha entrenado)
               // OJO: Puede haber usuarios que se unieron a retos pero no entrenaron. 
               // Pero para coherencia "Active Users", mantenemos el filtro de activeUserIds.
               if (activeUserIds.contains(uid)) {
                 final joinedAt = _parseFechaRobust(data['joinedAt']);
                 
                 // Aplicar filtro de fecha a la participación
                 bool inRange = true;
                 if (startDate != null) {
                   inRange = joinedAt.isAfter(startDate) || joinedAt.isAtSameMomentAs(startDate);
                   if (inRange && endDate != null) {
                     inRange = joinedAt.isBefore(endDate) || joinedAt.isAtSameMomentAs(endDate);
                   }
                 }
                 
                 if (inRange) {
                   final path = doc.reference.path;
                   final isGlobal = path.contains('global_challenges');
                   final isGroup = path.contains('groups'); 
                   final isCompleted = data['reachedGoalAt'] != null;

                   if (isGlobal) {
                     globalUniqueParticipants.add(uid);
                     globalTotalEnrollments++;
                     if (isCompleted) globalCompletedCount++;
                   } else if (isGroup) {
                     groupUniqueParticipants.add(uid);
                     groupTotalEnrollments++;
                     if (isCompleted) groupCompletedCount++;
                   }
                 }
               }
             }
           }
        } catch (e) {
           // Error metrics
        }
        
        double globalParticipationRate = 0;
        double groupParticipationRate = 0;
        
        if (activeUsersCount > 0) {
           globalParticipationRate = (globalUniqueParticipants.length / activeUsersCount) * 100;
           groupParticipationRate = (groupUniqueParticipants.length / activeUsersCount) * 100;
        }

        double globalCompletionRate = 0;
        double groupCompletionRate = 0;

        if (globalTotalEnrollments > 0) {
          globalCompletionRate = (globalCompletedCount / globalTotalEnrollments) * 100;
        }
        
        if (groupTotalEnrollments > 0) {
          groupCompletionRate = (groupCompletedCount / groupTotalEnrollments) * 100;
        }

        // h. Contar Retos de Grupo (Totales)
        int groupChallengesCount = 0;
        try {
           final groupChallSnap = await _firestore.collectionGroup('challenges').count().get();
           groupChallengesCount = groupChallSnap.count ?? 0;
        } catch (e) {
           // Error
        }

        // l. Peak Hours (Franjas Horarias)
        String peakHourLabel = "N/A";
        if (filteredDocs.isNotEmpty) {
          Map<int, int> hourCounts = {};
          for (var doc in filteredDocs) {
            final date = _parseFechaRobust(doc['fecha']);
            final hour = date.hour;
            hourCounts[hour] = (hourCounts[hour] ?? 0) + 1;
          }
          int bestHour = hourCounts.entries.first.key;
          int maxCount = hourCounts.entries.first.value;
          hourCounts.forEach((h, c) {
            if (c > maxCount) {
              maxCount = c;
              bestHour = h;
            }
          });
          
          if (bestHour >= 6 && bestHour < 12) peakHourLabel = "Mañana ($bestHour:00)";
          else if (bestHour >= 12 && bestHour < 16) peakHourLabel = "Mediodía ($bestHour:00)";
          else if (bestHour >= 16 && bestHour < 21) peakHourLabel = "Tarde ($bestHour:00)";
          else peakHourLabel = "Noche/Madrugada ($bestHour:00)";
        }

        // m. GPS Adoption Rate
        double gpsAdoptionRate = 0;
        if (filteredDocs.isNotEmpty) {
           int gpsCount = filteredDocs.where((d) => d['gps'] == true).length;
           gpsAdoptionRate = (gpsCount / filteredDocs.length) * 100;
        }

        // n. Retention & MoM Growth (Comparando con periodo anterior)
        double retentionRate = 0;
        double momGrowthKm = 0;
        
        if (startDate != null && filteredDocs.isNotEmpty) {
           final duration = (endDate ?? DateTime.now()).difference(startDate);
           final prevStartDate = startDate.subtract(duration);
           final prevEndDate = startDate;

           final prevPeriodDocs = allDocs.where((d) {
             final date = _parseFechaRobust(d['fecha']);
             return (date.isAfter(prevStartDate) || date.isAtSameMomentAs(prevStartDate)) && 
                    date.isBefore(prevEndDate);
           }).toList();

           // Growth
           double prevKm = 0;
           for (var doc in prevPeriodDocs) {
             prevKm += (doc['distanciaTotalM'] as num? ?? 0) / 1000.0;
           }
           double currentKm = totalKm / 1000.0;
           if (prevKm > 0) {
             momGrowthKm = ((currentKm - prevKm) / prevKm) * 100;
           } else {
             momGrowthKm = 100; // 100% growth if no previous data
           }

           // Retention (Loyalty)
           if (prevPeriodDocs.isNotEmpty) {
             final prevUids = prevPeriodDocs.map((d) => d['userId'] as String).toSet();
             final currentUids = filteredDocs.map((d) => d['userId'] as String).toSet();
             final commonUids = currentUids.intersection(prevUids);
             retentionRate = (commonUids.length / prevUids.length) * 100;
           }
        }

        return {
          'totalUsers': totalUsers,
          'onboardedUsers': onboardedUsers,
          'activeChallenges': totalChallenges, 
          'groupChallengesCount': groupChallengesCount, 
          'totalKm': totalKm,
          'recentTrainingsSample': recentTrainingsSample,
          'consistencyRate': consistencyRate,
          'activeUsersCount': activeUsersCount,
          'avgWeeklyDistance': avgWeeklyDistance,
          'avgDistancePerTraining': avgDistancePerTraining,
          'avgRpe': avgRpe,
          'peakHour': peakHourLabel,
          'gpsAdoptionRate': gpsAdoptionRate,
          'retentionRate': retentionRate,
          'momGrowthKm': momGrowthKm,
          'globalParticipationRate': globalParticipationRate,
          'groupParticipationRate': groupParticipationRate,
          'globalCompletionRate': globalCompletionRate,
          'groupCompletionRate': groupCompletionRate,
          'systemHealth': 'Operational',
        };
      } catch (e) {
         // Error critical
         return {
          'totalUsers': totalUsers,
          'onboardedUsers': onboardedUsers,
          'activeChallenges': totalChallenges,
          'groupChallengesCount': 0,
          'totalKm': totalKm,
          'recentTrainingsSample': [],
          'consistencyRate': 0.0,
          'activeUsersCount': 0,
          'avgWeeklyDistance': 0.0,
          'avgDistancePerTraining': 0.0,
          'avgRpe': 0.0,
          'globalParticipationRate': 0.0,
          'groupParticipationRate': 0.0,
          'globalCompletionRate': 0.0,
          'groupCompletionRate': 0.0,
          'systemHealth': 'Degraded',
        };
      }

    } catch (e) {
      return {};
    }
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

  /// Publica un reto global (cambia estado de draft a active)
  Future<void> publishChallenge(String challengeId) async {
    await _firestore
        .collection('global_challenges')
        .doc(challengeId)
        .update({'status': ChallengeStatus.active.toFirestore()});
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
