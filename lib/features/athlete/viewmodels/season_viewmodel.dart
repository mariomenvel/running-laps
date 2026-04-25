import 'package:flutter/foundation.dart';
import 'package:running_laps/core/services/training_load_service.dart';
import 'package:running_laps/features/athlete/data/athlete_session_model.dart';
import 'package:running_laps/features/athlete/data/athlete_session_repository.dart';
import 'package:running_laps/features/training/data/entrenamiento.dart';
import 'package:running_laps/features/training/data/training_repository.dart';

// ── WeeklyLoad ────────────────────────────────────────────────────────────────

class WeeklyLoad {
  final DateTime weekStart;
  final double totalKm;
  final double loadScore;
  final int sessionCount;
  final bool isRaceWeek;
  final bool hasRace;

  const WeeklyLoad({
    required this.weekStart,
    required this.totalKm,
    required this.loadScore,
    required this.sessionCount,
    required this.isRaceWeek,
    required this.hasRace,
  });
}

// ── State ─────────────────────────────────────────────────────────────────────

class SeasonViewModelState {
  final bool isLoading;
  final String? errorMessage;
  final List<WeeklyLoad> weeklyLoads;
  final List<AthleteSession> upcomingRaces;

  const SeasonViewModelState({
    this.isLoading = false,
    this.errorMessage,
    this.weeklyLoads = const [],
    this.upcomingRaces = const [],
  });

  SeasonViewModelState copyWith({
    bool? isLoading,
    Object? errorMessage = _sentinel,
    List<WeeklyLoad>? weeklyLoads,
    List<AthleteSession>? upcomingRaces,
  }) {
    return SeasonViewModelState(
      isLoading:     isLoading     ?? this.isLoading,
      errorMessage:  errorMessage  == _sentinel ? this.errorMessage : errorMessage as String?,
      weeklyLoads:   weeklyLoads   ?? this.weeklyLoads,
      upcomingRaces: upcomingRaces ?? this.upcomingRaces,
    );
  }
}

const Object _sentinel = Object();

// ── ViewModel ─────────────────────────────────────────────────────────────────

class SeasonViewModel {
  SeasonViewModel({
    AthleteSessionRepository? sessionRepository,
    TrainingRepository? trainingRepository,
  })  : _sessionRepo   = sessionRepository   ?? AthleteSessionRepository(),
        _trainingRepo  = trainingRepository   ?? TrainingRepository();

  final AthleteSessionRepository _sessionRepo;
  final TrainingRepository       _trainingRepo;

  final ValueNotifier<SeasonViewModelState> state =
      ValueNotifier(const SeasonViewModelState());

  // ── Public API ─────────────────────────────────────────────────────────────

  Future<void> init(String uid) async {
    state.value = state.value.copyWith(isLoading: true, errorMessage: null);
    try {
      final now       = DateTime.now();
      final today     = DateTime(now.year, now.month, now.day);

      // 16 weeks back — find the Monday of the oldest week
      final currentMonday = today.subtract(Duration(days: today.weekday - 1));
      final oldestMonday  = currentMonday.subtract(const Duration(days: 15 * 7));

      final periodStart = _fmt(oldestMonday);
      final futureEnd   = _fmt(today.add(const Duration(days: 90)));

      // Load in parallel
      final results = await Future.wait<dynamic>([
        _trainingRepo.getTrainings(pageSize: 500),                          // [0]
        _sessionsOnce(uid: uid, start: periodStart, end: futureEnd),        // [1]
      ]);

      final trainings   = (results[0] as TrainingsPage).trainings;
      final allSessions = results[1] as List<AthleteSession>;

      // ── Build weekly loads ───────────────────────────────────────────────
      final weeklyLoads = <WeeklyLoad>[];

      for (var w = 0; w < 16; w++) {
        final weekStart = oldestMonday.add(Duration(days: w * 7));
        final weekEnd   = weekStart.add(const Duration(days: 7));

        final weekTrainings = trainings.where((t) {
          final d = DateTime(t.fecha.year, t.fecha.month, t.fecha.day);
          return !d.isBefore(weekStart) && d.isBefore(weekEnd);
        }).toList();

        double totalKm    = 0;
        double loadScore  = 0;
        for (final t in weekTrainings) {
          final km  = t.distanciaTotalM() / 1000.0;
          final min = t.tiempoTotalSec()  / 60.0;
          final rpe = t.rpePromedio();
          totalKm   += km;
          loadScore += TrainingLoadService.instance.calculateLoad(
            distanceKm:      km,
            durationMinutes: min,
            rpeAverage:      rpe > 0 ? rpe : null,
          );
        }

        final weekStartDate = _fmt(weekStart);
        final weekEndDate   = _fmt(weekEnd.subtract(const Duration(days: 1)));
        final hasRace = allSessions.any((s) =>
            s.category == 'competicion' &&
            s.date.compareTo(weekStartDate) >= 0 &&
            s.date.compareTo(weekEndDate)   <= 0);

        weeklyLoads.add(WeeklyLoad(
          weekStart:    weekStart,
          totalKm:      totalKm,
          loadScore:    loadScore,
          sessionCount: weekTrainings.length,
          isRaceWeek:   TrainingLoadService.instance.isRaceWeek(weekStart, allSessions),
          hasRace:      hasRace,
        ));
      }

      // ── Upcoming races ───────────────────────────────────────────────────
      final upcomingRaces = allSessions
          .where((s) =>
              s.category == 'competicion' &&
              s.date.compareTo(_fmt(today)) >= 0)
          .toList()
        ..sort((a, b) => a.date.compareTo(b.date));

      state.value = state.value.copyWith(
        isLoading:     false,
        weeklyLoads:   weeklyLoads,
        upcomingRaces: upcomingRaces,
      );
    } catch (e) {
      debugPrint('[SeasonViewModel] init error: $e');
      state.value = state.value.copyWith(
        isLoading:    false,
        errorMessage: 'Error al cargar la temporada',
      );
    }
  }

  void dispose() => state.dispose();

  // ── Private ────────────────────────────────────────────────────────────────

  Future<List<AthleteSession>> _sessionsOnce({
    required String uid,
    required String start,
    required String end,
  }) async {
    try {
      return await _sessionRepo
          .streamSessionsInRange(uid: uid, startDate: start, endDate: end)
          .first;
    } catch (_) {
      return [];
    }
  }

  String _fmt(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
