import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:running_laps/core/services/session_recovery_service.dart';
import 'package:running_laps/core/services/user_service.dart';
import 'package:running_laps/features/athlete/data/athlete_session_model.dart';
import 'package:running_laps/features/athlete/data/athlete_session_repository.dart';
import 'package:running_laps/features/athlete/data/progress_repository.dart';
import 'package:running_laps/features/training/data/entrenamiento.dart';
import 'package:running_laps/features/training/data/training_repository.dart';

class HomeViewModel {
  HomeViewModel({required this.userId});

  final String userId;

  final _trainingRepo = TrainingRepository();
  final _sessionRepo  = AthleteSessionRepository();
  final _progressRepo = ProgressRepository();
  final _userService  = UserService();
  final _recovery     = SessionRecoveryService();

  // ── Estado reactivo ──────────────────────────────────────────────────────

  final isLoading        = ValueNotifier<bool>(true);
  final isAthleteMode    = ValueNotifier<bool>(false);
  final userName         = ValueNotifier<String>('');
  final totalKm          = ValueNotifier<double>(0.0);
  final totalSessions    = ValueNotifier<int>(0);
  final recentWorkouts   = ValueNotifier<List<Entrenamiento>>([]);
  final recoveredSession = ValueNotifier<RecoveredSession?>(null);

  // Modo atleta
  final todaySession   = ValueNotifier<AthleteSession?>(null);
  final weekSessions   = ValueNotifier<List<AthleteSession>>([]);
  final weeklyVolumeKm = ValueNotifier<double>(0.0);

  // Modo recreativo
  final personalRecords = ValueNotifier<Map<int, PersonalRecord>>({});

  // ── API pública ──────────────────────────────────────────────────────────

  Future<void> loadAll() async {
    isLoading.value = true;
    try {
      final results = await Future.wait([
        _trainingRepo.getAllEntrenamientos(userId),
        FirebaseFirestore.instance.collection('users').doc(userId).get(),
        _userService.getIsAthleteMode(userId),
        _recovery.loadSession(),
      ]);

      final allWorkouts  = results[0] as List<Entrenamiento>;
      final userDoc      = results[1] as DocumentSnapshot;
      final athleteMode  = results[2] as bool;
      final recovered    = results[3] as RecoveredSession?;

      final data = userDoc.data() as Map<String, dynamic>? ?? {};
      userName.value      = data['nombre'] as String? ?? 'Usuario';
      totalKm.value       = (data['totalKm'] as num?)?.toDouble() ?? 0.0;
      totalSessions.value = (data['totalSessions'] as num?)?.toInt() ?? 0;
      isAthleteMode.value = athleteMode;
      recoveredSession.value = recovered;

      allWorkouts.sort((a, b) => b.fecha.compareTo(a.fecha));
      recentWorkouts.value = allWorkouts.take(5).toList();

      if (athleteMode) {
        await _loadAthleteData(allWorkouts);
      } else {
        await _loadRecreativoData();
      }
    } catch (e) {
      debugPrint('[HomeViewModel] loadAll error: $e');
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> refresh() => loadAll();

  Future<void> toggleAthleteMode() async {
    final newValue = !isAthleteMode.value;
    await _userService.setAthleteMode(userId, value: newValue);
    isAthleteMode.value = newValue;
    isLoading.value = true;
    try {
      final allWorkouts = await _trainingRepo.getAllEntrenamientos(userId);
      allWorkouts.sort((a, b) => b.fecha.compareTo(a.fecha));
      recentWorkouts.value = allWorkouts.take(5).toList();
      if (newValue) {
        await _loadAthleteData(allWorkouts);
      } else {
        await _loadRecreativoData();
      }
    } finally {
      isLoading.value = false;
    }
  }

  void dispose() {
    isLoading.dispose();
    isAthleteMode.dispose();
    userName.dispose();
    totalKm.dispose();
    totalSessions.dispose();
    recentWorkouts.dispose();
    recoveredSession.dispose();
    todaySession.dispose();
    weekSessions.dispose();
    weeklyVolumeKm.dispose();
    personalRecords.dispose();
  }

  // ── Privado ──────────────────────────────────────────────────────────────

  Future<void> _loadAthleteData(List<Entrenamiento> allWorkouts) async {
    final now = DateTime.now();
    final dateStr =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    final results = await Future.wait([
      _sessionRepo.getSessionsForDate(uid: userId, date: dateStr),
      _sessionRepo.getWeekSessions(uid: userId),
    ]);

    final todaySessions = results[0] as List<AthleteSession>;
    final week          = results[1] as List<AthleteSession>;

    todaySession.value =
        todaySessions.where((s) => s.status == AthleteSessionStatus.planned).firstOrNull;
    weekSessions.value = week;

    // Volumen ejecutado esta semana (lunes → hoy)
    final monday = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: now.weekday - 1));
    weeklyVolumeKm.value = allWorkouts
        .where((e) => !e.fecha.isBefore(monday))
        .fold(0.0, (sum, e) => sum + e.distanciaTotalM() / 1000.0);
  }

  Future<void> _loadRecreativoData() async {
    personalRecords.value = await _progressRepo.getPersonalRecords(userId);
  }
}
