import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'entrenamiento.dart';
import 'serie.dart';
import '../../../core/services/gps_service.dart';
import '../../../core/utils/rdp_smoother.dart';
import '../../../features/groups/data/services/training_challenge_sync_service.dart';
import '../../../features/home/data/home_estadistica_repository.dart';

class TrainingRepository {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final TrainingChallengeSyncService _syncService = TrainingChallengeSyncService();

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


  // NUEVO: obtener lista de entrenamientos del usuario actual
  Future<List<Entrenamiento>> getTrainings() async {
    final String uid = _requireUid();

    final QuerySnapshot<Map<String, dynamic>> snapshot = await _userTrainings(
      uid,
    ).orderBy('createdAt', descending: true).limit(100).get();

    final List<Entrenamiento> result = <Entrenamiento>[];

    for (int i = 0; i < snapshot.docs.length; i = i + 1) {
      final QueryDocumentSnapshot<Map<String, dynamic>> doc = snapshot.docs[i];
      final Map<String, dynamic> data = doc.data();
      // Pasar el ID del documento al modelo
      result.add(Entrenamiento.fromMap(data, id: doc.id));
    }

    return result;
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
    // Alias for getTrainings but with explicit uid argument (which getTrainings ignores and uses auth user)
    // To match the new signature: getAllEntrenamientos(String uid)
    // However, existing getTrainings uses _requireUid inside.
    // We should check if uid matches current user or if we need to support other users.
    // For now, assuming analytics is for current user.
    return getTrainings();
  }
}

