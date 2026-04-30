import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:running_laps/core/services/user_service.dart';
import 'package:running_laps/features/athlete/data/athlete_session_model.dart';
import 'package:running_laps/features/athlete/data/athlete_session_repository.dart';
import 'package:running_laps/features/training/data/entrenamiento.dart';
import 'package:running_laps/features/training/data/training_repository.dart';

class CalendarViewModel {
  CalendarViewModel({required this.userId});

  final String userId;

  final _sessionRepo  = AthleteSessionRepository();
  final _trainingRepo = TrainingRepository();
  final _userService  = UserService();

  // ── Estado ───────────────────────────────────────────────────────────────

  final isLoading      = ValueNotifier<bool>(true);
  final isAthleteMode  = ValueNotifier<bool>(false);
  final selectedDay    = ValueNotifier<DateTime>(DateTime.now());
  final focusedMonth   = ValueNotifier<DateTime>(DateTime.now());

  // Modo atleta — stream reactivo del mes
  final sessionsByDate       = ValueNotifier<Map<String, List<AthleteSession>>>({});
  final selectedDaySessions  = ValueNotifier<List<AthleteSession>>([]);

  // Modo recreativo — lista completa cargada una vez
  final trainingDates      = ValueNotifier<Set<String>>({});
  final allWorkouts        = ValueNotifier<List<Entrenamiento>>([]);
  final selectedDayWorkouts = ValueNotifier<List<Entrenamiento>>([]);

  StreamSubscription<List<AthleteSession>>? _sessionSub;

  // ── API pública ──────────────────────────────────────────────────────────

  Future<void> loadAll() async {
    isLoading.value = true;
    try {
      isAthleteMode.value = await _userService.getIsAthleteMode(userId);
      if (isAthleteMode.value) {
        _subscribeToMonth(DateTime.now());
      } else {
        await _loadTrainingDates();
        _updateSelectedDayWorkouts(selectedDay.value);
      }
    } catch (e) {
      debugPrint('[CalendarViewModel] loadAll error: $e');
    } finally {
      isLoading.value = false;
    }
  }

  void onDaySelected(DateTime day, DateTime focused) {
    selectedDay.value = day;
    if (isAthleteMode.value) {
      selectedDaySessions.value = sessionsByDate.value[_normalize(day)] ?? [];
      // If user tapped into a different month, re-subscribe
      if (focused.month != focusedMonth.value.month ||
          focused.year != focusedMonth.value.year) {
        focusedMonth.value = focused;
        _subscribeToMonth(focused);
      }
    } else {
      _updateSelectedDayWorkouts(day);
    }
  }

  void onMonthChanged(DateTime month) {
    focusedMonth.value = month;
    if (isAthleteMode.value) {
      _subscribeToMonth(month);
    }
  }

  Future<void> toggleAthleteMode() async {
    isLoading.value = true;
    final newVal = !isAthleteMode.value;
    await _userService.setAthleteMode(userId, value: newVal);
    isAthleteMode.value = newVal;
    if (newVal) {
      _subscribeToMonth(focusedMonth.value);
    } else {
      _sessionSub?.cancel();
      _sessionSub = null;
      await _loadTrainingDates();
      _updateSelectedDayWorkouts(selectedDay.value);
    }
    isLoading.value = false;
  }

  void dispose() {
    _sessionSub?.cancel();
    isLoading.dispose();
    isAthleteMode.dispose();
    selectedDay.dispose();
    focusedMonth.dispose();
    sessionsByDate.dispose();
    selectedDaySessions.dispose();
    trainingDates.dispose();
    allWorkouts.dispose();
    selectedDayWorkouts.dispose();
  }

  // ── Privado ──────────────────────────────────────────────────────────────

  /// Suscripción reactiva al mes — mismo patrón que AthleteCalendarViewModel.
  void _subscribeToMonth(DateTime month) {
    _sessionSub?.cancel();

    final first = DateTime(month.year, month.month, 1);
    final last  = DateTime(month.year, month.month + 1, 0);

    _sessionSub = _sessionRepo
        .streamSessionsInRange(
          uid:       userId,
          startDate: _normalize(first),
          endDate:   _normalize(last),
        )
        .listen(
          (sessions) {
            final map = <String, List<AthleteSession>>{};
            for (final s in sessions) {
              map.putIfAbsent(s.date, () => []).add(s);
            }
            sessionsByDate.value = map;
            // Refresh selected day
            selectedDaySessions.value =
                map[_normalize(selectedDay.value)] ?? [];
          },
          onError: (Object e) {
            debugPrint('[CalendarViewModel] stream error: $e');
          },
        );
  }

  Future<void> _loadTrainingDates() async {
    final workouts = await _trainingRepo.getAllEntrenamientos(userId);
    workouts.sort((a, b) => b.fecha.compareTo(a.fecha));
    allWorkouts.value = workouts;
    trainingDates.value = {
      for (final w in workouts) _normalize(w.fecha),
    };
  }

  void _updateSelectedDayWorkouts(DateTime day) {
    final key = _normalize(day);
    selectedDayWorkouts.value =
        allWorkouts.value.where((w) => _normalize(w.fecha) == key).toList();
  }

  String _normalize(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
