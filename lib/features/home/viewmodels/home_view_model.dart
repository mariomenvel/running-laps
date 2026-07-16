import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:running_laps/core/services/session_recovery_service.dart';
import 'package:running_laps/core/services/user_service.dart';
import 'package:running_laps/core/services/zones_service.dart';
import 'package:running_laps/features/athlete/data/athlete_session_model.dart';
import 'package:running_laps/features/athlete/data/athlete_session_repository.dart';
import 'package:running_laps/features/athlete/data/progress_repository.dart';
import 'package:running_laps/features/training/data/entrenamiento.dart';
import 'package:running_laps/features/training/data/training_repository.dart';

class HomeViewModel {
  HomeViewModel({required this.userId});

  /// Incrementar para forzar recarga del Home.
  /// Usar tras marcar sesión como completada.
  static final needsReload = ValueNotifier<int>(0);

  final String userId;

  bool _disposed = false;

  final _trainingRepo = TrainingRepository();
  final _sessionRepo  = AthleteSessionRepository();
  final _progressRepo = ProgressRepository();
  final _userService  = UserService();
  final _recovery     = SessionRecoveryService();
  final _db           = FirebaseFirestore.instance;

  // ── Estado reactivo ──────────────────────────────────────────────────────

  final isLoading        = ValueNotifier<bool>(true);
  final isAthleteMode    = ValueNotifier<bool>(false);
  final userName         = ValueNotifier<String>('');
  final totalKm          = ValueNotifier<double>(0.0);
  final totalSessions    = ValueNotifier<int>(0);
  final recentWorkouts   = ValueNotifier<List<Entrenamiento>>([]);
  final recoveredSession = ValueNotifier<RecoveredSession?>(null);

  // Progreso semanal (ambos modos)
  final weeklyVolumeKm       = ValueNotifier<double>(0.0);
  final weeklySessionCount   = ValueNotifier<int>(0);
  final weeklyTimeMinutes    = ValueNotifier<int>(0);
  final weeklyRpeAvg         = ValueNotifier<double>(0.0);
  final weeklyLoadTotal      = ValueNotifier<double>(0.0);
  // Mapa zona (1..5) → segundos corridos en esa zona esta semana
  final weeklyZoneSeconds    = ValueNotifier<Map<int, double>>({});

  // Modo atleta
  final todaySession = ValueNotifier<AthleteSession?>(null);
  final completedTodaySession = ValueNotifier<AthleteSession?>(null);
  final completedTodayCoachAnalysis = ValueNotifier<String?>(null);
  final completedTodayCoachAnalysisPending = ValueNotifier<bool>(false);
  final weekSessions = ValueNotifier<List<AthleteSession>>([]);

  // Modo recreativo
  final personalRecords = ValueNotifier<Map<int, PersonalRecord>>({});

  // ── API pública ──────────────────────────────────────────────────────────

  /// Lunes de la semana actual a medianoche local — límite inferior de las
  /// stats semanales. La query lo convierte a UTC, así que el bound es exacto.
  DateTime get _mondayOfThisWeek {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: now.weekday - 1));
  }

  Future<void> loadAll() async {
    isLoading.value = true;
    try {
      // Solo lo que la home necesita: 5 recientes + la semana en curso.
      // (Antes: getAllEntrenamientos → hasta 500 docs con gpsPoints dentro.)
      final results = await Future.wait([
        _trainingRepo.getTrainings(uid: userId, pageSize: 5),
        _trainingRepo.getTrainingsSince(_mondayOfThisWeek, uid: userId),
        FirebaseFirestore.instance.collection('users').doc(userId).get(),
        _userService.getIsAthleteMode(userId),
        _recovery.loadSession(),
      ]);

      final recentPage   = results[0] as TrainingsPage;
      final weekWorkouts = results[1] as List<Entrenamiento>;
      final userDoc      = results[2] as DocumentSnapshot;
      final athleteMode  = results[3] as bool;
      final recovered    = results[4] as RecoveredSession?;

      if (_disposed) return;
      final data = userDoc.data() as Map<String, dynamic>? ?? {};
      userName.value      = data['nombre'] as String? ?? 'Usuario';
      totalKm.value       = (data['totalKm'] as num?)?.toDouble() ?? 0.0;
      totalSessions.value = (data['totalSessions'] as num?)?.toInt() ?? 0;
      isAthleteMode.value = athleteMode;
      recoveredSession.value = recovered;

      recentWorkouts.value = recentPage.trainings;

      final fcMax = (data['fcMax'] as num?)?.toInt() ?? 0;
      _computeWeeklyStats(weekWorkouts, fcMax);

      if (athleteMode) {
        await _loadAthleteData();
      } else {
        await _loadRecreativoData();
      }
    } catch (e) {
      debugPrint('[HomeViewModel] loadAll error: $e');
    }
    if (!_disposed) isLoading.value = false;
  }

  Future<void> refresh() => loadAll();

  Future<void> toggleAthleteMode() async {
    final newValue = !isAthleteMode.value;
    await _userService.setAthleteMode(userId, value: newValue);
    if (_disposed) return;
    isAthleteMode.value = newValue;
    isLoading.value = true;
    try {
      final results = await Future.wait([
        _trainingRepo.getTrainings(uid: userId, pageSize: 5),
        _trainingRepo.getTrainingsSince(_mondayOfThisWeek, uid: userId),
        FirebaseFirestore.instance.collection('users').doc(userId).get(),
      ]);
      if (_disposed) return;
      final recentPage   = results[0] as TrainingsPage;
      final weekWorkouts = results[1] as List<Entrenamiento>;
      final userDoc      = results[2] as DocumentSnapshot;
      final data         = userDoc.data() as Map<String, dynamic>? ?? {};
      final fcMax        = (data['fcMax'] as num?)?.toInt() ?? 0;

      recentWorkouts.value = recentPage.trainings;
      _computeWeeklyStats(weekWorkouts, fcMax);

      if (newValue) {
        await _loadAthleteData();
      } else {
        await _loadRecreativoData();
      }
    } catch (e) {
      debugPrint('[HomeViewModel] toggleAthleteMode error: $e');
    }
    if (!_disposed) isLoading.value = false;
  }

  void dispose() {
    _disposed = true;
    isLoading.dispose();
    isAthleteMode.dispose();
    userName.dispose();
    totalKm.dispose();
    totalSessions.dispose();
    recentWorkouts.dispose();
    recoveredSession.dispose();
    weeklyVolumeKm.dispose();
    weeklySessionCount.dispose();
    weeklyTimeMinutes.dispose();
    weeklyRpeAvg.dispose();
    weeklyLoadTotal.dispose();
    weeklyZoneSeconds.dispose();
    todaySession.dispose();
    completedTodaySession.dispose();
    completedTodayCoachAnalysis.dispose();
    completedTodayCoachAnalysisPending.dispose();
    weekSessions.dispose();
    personalRecords.dispose();
  }

  // ── Privado ──────────────────────────────────────────────────────────────

  void _computeWeeklyStats(List<Entrenamiento> allWorkouts, int fcMax) {
    final now    = DateTime.now();
    final monday = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: now.weekday - 1));

    final thisWeek = allWorkouts.where((e) => !e.fecha.isBefore(monday)).toList();

    weeklySessionCount.value = thisWeek.length;
    weeklyVolumeKm.value     = thisWeek.fold(0.0, (s, e) => s + e.distanciaTotalM() / 1000.0);
    weeklyTimeMinutes.value  = thisWeek.fold(0, (s, e) => s + (e.tiempoTotalSec() / 60).round());

    // RPE promedio (solo sesiones con RPE calculado)
    final rpeList = thisWeek
        .map((e) => e.rpePromedio())
        .where((r) => r > 0)
        .toList();
    weeklyRpeAvg.value = rpeList.isEmpty
        ? 0.0
        : rpeList.reduce((a, b) => a + b) / rpeList.length;

    // Carga total (loadScore almacenado)
    weeklyLoadTotal.value = thisWeek.fold(
      0.0,
      (s, e) => s + (e.loadScore ?? 0.0),
    );

    // Distribución de zonas: sumar segundos por zona usando fcMedia por serie
    final zoneMap = <int, double>{};
    if (fcMax > 0) {
      for (final e in thisWeek) {
        for (final serie in e.series) {
          final fc = serie.fcMedia;
          if (fc != null && fc > 0) {
            final zone = ZonesService().zoneFor(fc.toInt(), fcMax);
            if (zone != null) {
              zoneMap[zone] = (zoneMap[zone] ?? 0.0) + serie.tiempoSec;
            }
          }
        }
      }
    }
    weeklyZoneSeconds.value = zoneMap;
  }

  Future<void> _loadAthleteData() async {
    final now     = DateTime.now();
    final dateStr =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    final results = await Future.wait([
      _sessionRepo.getSessionsForDate(uid: userId, date: dateStr),
      _sessionRepo.getWeekSessions(uid: userId),
    ]);

    final todaySessions = results[0];
    final week          = results[1];

    if (_disposed) return;
    todaySession.value =
        todaySessions.where((s) => s.status == AthleteSessionStatus.planned).firstOrNull;
    final completed =
        todaySessions.where((s) => s.status == AthleteSessionStatus.completed).firstOrNull;
    completedTodaySession.value = completed;
    weekSessions.value = week;

    completedTodayCoachAnalysis.value = null;
    completedTodayCoachAnalysisPending.value = false;
    final completedTrainingId = completed?.completedTrainingId;
    if (completedTrainingId != null) {
      try {
        final doc = await _db
            .collection('users')
            .doc(userId)
            .collection('trainings')
            .doc(completedTrainingId)
            .get();
        if (_disposed) return;
        final data = doc.data();
        final analysis = data?['coachAnalysis'];
        final analysisText = analysis is Map ? analysis['text'] : null;
        if (analysisText is String && analysisText.isNotEmpty) {
          completedTodayCoachAnalysis.value = analysisText;
        } else if (data?['plannedComparison'] != null) {
          final createdAtRaw = data?['createdAt'] ?? data?['fecha'];
          final createdAt = _parseTimestamp(createdAtRaw);
          if (createdAt != null &&
              DateTime.now().difference(createdAt) < const Duration(minutes: 2)) {
            completedTodayCoachAnalysisPending.value = true;
          }
        }
      } catch (e) {
        debugPrint('[HomeViewModel] coachAnalysis fetch error: $e');
      }
    }
  }

  DateTime? _parseTimestamp(dynamic v) {
    if (v == null) return null;
    if (v is String) return DateTime.tryParse(v);
    try {
      final ts = v as dynamic;
      if (ts.toDate != null) return (ts.toDate() as DateTime).toLocal();
    } catch (_) {}
    return null;
  }

  Future<void> _loadRecreativoData() async {
    final records = await _progressRepo.getPersonalRecords(userId);
    if (_disposed) return;
    personalRecords.value = records;
  }
}
