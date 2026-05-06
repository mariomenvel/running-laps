import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'entrenamiento.dart';
import 'serie.dart';
import '../../../core/services/gps_service.dart';
import '../../../core/services/rate_limit_service.dart';
import '../../../core/utils/rdp_smoother.dart';
import '../../../features/groups/data/services/training_challenge_sync_service.dart';
import '../../../features/home/data/home_estadistica_repository.dart';

class TrainingsPage {
  final List<Entrenamiento> trainings;
  final DocumentSnapshot? lastDocument;
  final bool hasMore;

  const TrainingsPage({
    required this.trainings,
    required this.hasMore,
    this.lastDocument,
  });
}

class TrainingRepository {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final TrainingChallengeSyncService _syncService = TrainingChallengeSyncService();
  final RateLimitService _rateLimitService = RateLimitService();

  TrainingRepository() {
    _rateLimitService.registerLimit('history:getTrainings', const Duration(seconds: 2));
    _rateLimitService.registerLimit('training:save', const Duration(seconds: 3));
  }

  String _requireUid() {
    final User? u = _auth.currentUser;
    if (u == null) {
      throw Exception('No hay usuario autenticado');
    }
    return u.uid;
  }

  CollectionReference<Map<String, dynamic>> _userTrainings(String uid) {
    return _db.collection('users').doc(uid).collection('trainings');
  }

  Future<String> createTraining(Entrenamiento e) async {
    _rateLimitService.checkLimit('training:save');
    final String uid = _requireUid();

    // RDP smoothing on trackPoints (whole-session trace)
    if (e.trackPoints.length > 10) {
      final smoothed = RDPSmoother.simplify(e.trackPoints, epsilon: 2.0);
      e = e.copyWith(trackPoints: smoothed);
    }

    // RDP smoothing on gpsPoints within each serie
    final smoothedSeries = e.series.map((serie) {
      final pts = serie.gpsPoints;
      if (pts == null || pts.length <= 10) return serie;
      final gpsPoints = pts.map((m) => GpsPoint.fromMap(m)).toList();
      final smoothed = RDPSmoother.simplify(gpsPoints, epsilon: 2.5);
      return Serie(
        tiempoSec: serie.tiempoSec,
        distanciaM: serie.distanciaM,
        descansoSec: serie.descansoSec,
        rpe: serie.rpe,
        usedGps: serie.usedGps,
        usedGpsDistance: serie.usedGpsDistance,
        gpsPoints: smoothed.map((p) => p.toMap()).toList(),
        finishedAt: serie.finishedAt,
      );
    }).toList();
    e = e.copyWith(series: smoothedSeries);

    final Map<String, dynamic> data = e.toMap();

    data['createdAt'] = FieldValue.serverTimestamp();
    data['updatedAt'] = FieldValue.serverTimestamp();

    final DocumentReference<Map<String, dynamic>> doc = await _userTrainings(
      uid,
    ).add(data);

    final trainingId = doc.id;

    // Actualizar contadores agregados en users/{uid} (atómico con FieldValue.increment)
    _db.collection('users').doc(uid).update({
      'totalSessions': FieldValue.increment(1),
      'totalKm': FieldValue.increment(e.distanciaTotalM() / 1000.0),
      'totalTimeMinutes': FieldValue.increment(e.tiempoTotalSec() / 60.0),
      'lastTrainingDate': e.fecha.toIso8601String(),
    }).catchError((_) {
      // No bloquear si el update falla (campo puede no existir en docs antiguos)
    });

    HomeEstadisticaRepository().clearCache();

    // Sync to challenges (async, don't await to avoid blocking)
    _syncService.onTrainingSaved(
      uid: uid,
      entrenamiento: e.copyWith(id: trainingId),
      trainingId: trainingId,
      isUpdate: false,
    ).catchError((error) {
      // Log error but don't fail training creation
    });

    return trainingId;
  }


  Future<TrainingsPage> getTrainings({
    String? uid,
    DocumentSnapshot? startAfter,
    int pageSize = 20,
  }) async {
    _rateLimitService.checkLimit('history:getTrainings');
    final resolvedUid = uid ?? _requireUid();

    Query<Map<String, dynamic>> query = _userTrainings(resolvedUid)
        .orderBy('fecha', descending: true)
        .limit(pageSize);

    if (startAfter != null) {
      query = query.startAfterDocument(startAfter);
    }

    final snapshot = await query.get();
    final trainings = snapshot.docs
        .map((doc) => Entrenamiento.fromMap(doc.data(), id: doc.id))
        .toList();

    return TrainingsPage(
      trainings: trainings,
      lastDocument: snapshot.docs.isNotEmpty ? snapshot.docs.last : null,
      hasMore: snapshot.docs.length == pageSize,
    );
  }

  /// Actualiza solo las etiquetas de un entrenamiento existente
  Future<void> updateTrainingTags(String trainingId, List<String> tags) async {
    final String uid = _requireUid();

    await _userTrainings(uid).doc(trainingId).update({
      'tags': tags,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // Re-sync to challenges on update (async)
    // Fetch the updated training document
    final doc = await _userTrainings(uid).doc(trainingId).get();
    if (doc.exists) {
      final training = Entrenamiento.fromMap(doc.data()!, id: doc.id);
      _syncService.onTrainingSaved(
        uid: uid,
        entrenamiento: training,
        trainingId: trainingId,
        isUpdate: true,
      ).catchError((error) {
        // Log error but don't fail update
      });
    }
  }
  Future<List<Entrenamiento>> getAllEntrenamientos(String uid) async {
    final page = await getTrainings(uid: uid, pageSize: 500);
    return page.trainings;
  }

  Future<void> updateTrainingAnalysis({
    required String uid,
    required String trainingId,
    Map<String, dynamic>? plannedComparison,
    double? loadScore,
    double? fcMediaSesion,
  }) async {
    final data = <String, dynamic>{};
    if (plannedComparison != null) data['plannedComparison'] = plannedComparison;
    if (loadScore != null) data['loadScore'] = loadScore;
    if (fcMediaSesion != null) data['fcMediaSesion'] = fcMediaSesion;
    if (data.isEmpty) return;
    await _userTrainings(uid).doc(trainingId).update(data);
  }
}

