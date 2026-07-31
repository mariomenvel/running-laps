import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
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
  // Inyección opcional para tests (fake_cloud_firestore); los defaults
  // conservan el comportamiento de producción exacto.
  TrainingRepository({
    FirebaseFirestore? firestore,
    TrainingChallengeSyncService? syncService,
  })  : _db = firestore ?? FirebaseFirestore.instance,
        _syncService = syncService ?? TrainingChallengeSyncService() {
    _rateLimitService.registerLimit('training:save', const Duration(seconds: 3));
  }

  final FirebaseFirestore _db;
  final TrainingChallengeSyncService _syncService;
  final RateLimitService _rateLimitService = RateLimitService();

  /// Uid del usuario autenticado. Sobrescribible en tests
  /// (mismo patrón que TrainingTemplatesRepository).
  String? get currentUserId => FirebaseAuth.instance.currentUser?.uid;

  String _requireUid() {
    final uid = currentUserId;
    if (uid == null) {
      throw Exception('No hay usuario autenticado');
    }
    return uid;
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
      return serie.copyWith(
        gpsPoints: smoothed.map((p) => p.toMap()).toList(),
      );
    }).toList();
    e = e.copyWith(series: smoothedSeries);

    // El documento del entrenamiento va SIN trazas: listar entrenamientos
    // (calendario, analytics, historial) traía megas de coordenadas que esas
    // pantallas no usan. La traza se guarda aparte, en `track/data`.
    final Map<String, dynamic> data = e.toMap(includeTrack: false);

    data['createdAt'] = FieldValue.serverTimestamp();
    data['updatedAt'] = FieldValue.serverTimestamp();

    final DocumentReference<Map<String, dynamic>> doc = await _userTrainings(
      uid,
    ).add(data);

    final trainingId = doc.id;

    // Deliberadamente DESPUÉS y tolerante a fallos: si la traza no cabe o la
    // escritura falla, se pierde el mapa pero NO el entrenamiento. Al revés
    // (batch atómico) un fallo de la traza tiraría la sesión entera.
    await _saveTrack(uid: uid, trainingId: trainingId, training: e);

    // Actualizar contadores agregados en users/{uid} (atómico con FieldValue.increment)
    _db.collection('users').doc(uid).update({
      'totalSessions': FieldValue.increment(1),
      'totalKm': FieldValue.increment(e.distanciaTotalM() / 1000.0),
      'totalTimeMinutes': FieldValue.increment(e.tiempoTotalSec() / 60.0),
      'lastTrainingDate': e.fecha.toIso8601String(),
    }).catchError((Object error) {
      // No bloquear si el update falla (campo puede no existir en docs antiguos)
      debugPrint('[TrainingRepository] update contadores falló: $error');
    });

    HomeEstadisticaRepository().clearCache();

    // Sync to challenges (async, don't await to avoid blocking)
    _syncService.onTrainingSaved(
      uid: uid,
      entrenamiento: e.copyWith(id: trainingId),
      trainingId: trainingId,
      isUpdate: false,
    ).catchError((Object error) {
      debugPrint('[TrainingRepository] sync retos falló: $error');
    });

    return trainingId;
  }


  Future<TrainingsPage> getTrainings({
    String? uid,
    DocumentSnapshot? startAfter,
    int pageSize = 20,
  }) async {
    final resolvedUid = uid ?? _requireUid();

    // limit() se aplica DESPUÉS del cursor: en Firestore real el orden da
    // igual, pero fake_cloud_firestore (tests) ignora el cursor si el limit
    // va antes.
    Query<Map<String, dynamic>> query =
        _userTrainings(resolvedUid).orderBy('fecha', descending: true);

    if (startAfter != null) {
      query = query.startAfterDocument(startAfter);
    }
    query = query.limit(pageSize);

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
      ).catchError((Object error) {
        debugPrint('[TrainingRepository] re-sync retos falló: $error');
      });
    }
  }

  /// Entrenamientos con `fecha >= since`, ordenados descendente.
  /// El bound se construye en UTC (convención `fecha` string ISO UTC).
  Future<List<Entrenamiento>> getTrainingsSince(
    DateTime since, {
    String? uid,
  }) async {
    final resolvedUid = uid ?? _requireUid();
    final bound = since.toUtc().toIso8601String();

    final snapshot = await _userTrainings(resolvedUid)
        .where('fecha', isGreaterThanOrEqualTo: bound)
        .orderBy('fecha', descending: true)
        .get();

    return snapshot.docs
        .map((doc) => Entrenamiento.fromMap(doc.data(), id: doc.id))
        .toList();
  }

  /// Devuelve un entrenamiento por id, o null si no existe.
  Future<Entrenamiento?> getTrainingById(String trainingId) async {
    final String uid = _requireUid();
    final doc = await _userTrainings(uid).doc(trainingId).get();
    final data = doc.data();
    if (data == null) return null;
    return Entrenamiento.fromMap(data, id: doc.id);
  }

  /// Reescribe el documento completo (`set` sin merge): los campos que no
  /// vengan en [data] **se pierden**. Es lo que necesita la pantalla de
  /// resumen, que reenvía el entrenamiento entero con sus correcciones.
  /// Para cambios parciales, usar los métodos `update*`.
  Future<void> overwriteTraining(
    String trainingId,
    Map<String, dynamic> data,
  ) async {
    final String uid = _requireUid();
    // `merge: true` a propósito: los entrenamientos anteriores a jul 2026
    // llevan la traza embebida en el propio documento, y un `set` sin merge
    // la borraría al reenviar el entrenamiento sin ella.
    await _userTrainings(uid).doc(trainingId).set({
      ...data,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> deleteTraining(String trainingId) async {
    final String uid = _requireUid();
    await _userTrainings(uid).doc(trainingId).delete();
  }

  // ── Trazas GPS ────────────────────────────────────────────────────────────
  // Viven en `users/{uid}/trainings/{id}/track/data`, fuera del documento del
  // entrenamiento, y solo se leen cuando alguien va a pintar un mapa.

  DocumentReference<Map<String, dynamic>> _trackDoc(String uid, String id) =>
      _userTrainings(uid).doc(id).collection('track').doc('data');

  Future<void> _saveTrack({
    required String uid,
    required String trainingId,
    required Entrenamiento training,
  }) async {
    final seriesGps = <String, dynamic>{};
    for (int i = 0; i < training.series.length; i++) {
      final points = training.series[i].gpsPoints;
      if (points != null && points.isNotEmpty) {
        seriesGps['$i'] = points;
      }
    }

    final hasTrack = training.trackPoints.isNotEmpty;
    if (!hasTrack && seriesGps.isEmpty) return;

    try {
      await _trackDoc(uid, trainingId).set({
        if (hasTrack)
          'trackPoints': training.trackPoints.map((p) => p.toMap()).toList(),
        if (seriesGps.isNotEmpty) 'seriesGps': seriesGps,
        'savedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('[TrainingRepository] no se pudo guardar la traza: $e');
    }
  }

  /// Devuelve [training] con sus trazas cargadas, o el mismo objeto si ya las
  /// trae (entrenamientos anteriores a jul 2026, que las llevan embebidas) o
  /// si no hay ninguna guardada.
  ///
  /// Solo debe llamarse cuando se va a pintar el recorrido: es la lectura
  /// pesada que se sacó del listado.
  Future<Entrenamiento> withTrack(Entrenamiento training) async {
    final id = training.id;
    if (id == null) return training;
    if (training.trackPoints.isNotEmpty) return training; // formato antiguo

    final String uid = _requireUid();
    try {
      final snap = await _trackDoc(uid, id).get();
      final data = snap.data();
      if (data == null) return training;

      final rawTrack = data['trackPoints'] as List<dynamic>?;
      final trackPoints = rawTrack == null
          ? const <GpsPoint>[]
          : rawTrack
              .map((p) => GpsPoint.fromMap(Map<String, dynamic>.from(p as Map)))
              .toList();

      final seriesGps = data['seriesGps'] as Map<String, dynamic>?;
      final series = <Serie>[];
      for (int i = 0; i < training.series.length; i++) {
        final points = seriesGps?['$i'] as List<dynamic>?;
        series.add(points == null
            ? training.series[i]
            : training.series[i].copyWith(
                gpsPoints: points
                    .map((p) => Map<String, dynamic>.from(p as Map))
                    .toList(),
              ));
      }

      return training.copyWith(trackPoints: trackPoints, series: series);
    } catch (e) {
      debugPrint('[TrainingRepository] no se pudo leer la traza: $e');
      return training;
    }
  }

  Future<void> updateTrainingAnalysis({
    required String uid,
    required String trainingId,
    Map<String, dynamic>? plannedComparison,
    double? loadScore,
    double? fcMediaSesion,
    int? fcMaxSesion,
  }) async {
    final data = <String, dynamic>{};
    if (plannedComparison != null) data['plannedComparison'] = plannedComparison;
    if (loadScore != null) data['loadScore'] = loadScore;
    if (fcMediaSesion != null) data['fcMediaSesion'] = fcMediaSesion;
    if (fcMaxSesion != null) data['fcMaxSesion'] = fcMaxSesion;
    if (data.isEmpty) return;
    await _userTrainings(uid).doc(trainingId).update(data);
  }
}

