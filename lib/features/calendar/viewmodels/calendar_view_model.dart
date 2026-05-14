import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:running_laps/core/services/user_service.dart';
import 'package:running_laps/features/athlete/data/athlete_session_model.dart';
import 'package:running_laps/features/athlete/data/athlete_session_repository.dart';
import 'package:running_laps/features/training/data/entrenamiento.dart';
import 'package:running_laps/features/training/data/training_repository.dart';

enum CalendarViewType { weekly, monthly, season }

class SeasonWeekData {
  final DateTime weekStart;
  final int weekNumber;
  final double volumeKm;
  final int sessionCount;
  final double loadScore;
  final String weekType;
  final bool hasRace;
  final List<AthleteSession> sessions;

  const SeasonWeekData({
    required this.weekStart,
    required this.weekNumber,
    required this.volumeKm,
    required this.sessionCount,
    required this.loadScore,
    required this.weekType,
    required this.hasRace,
    required this.sessions,
  });
}

class CalendarViewModel {
  CalendarViewModel({required this.userId});

  final String userId;

  bool _disposed = false;

  final _sessionRepo  = AthleteSessionRepository();
  final _trainingRepo = TrainingRepository();
  final _userService  = UserService();

  // ── Estado de vista ───────────────────────────────────────────────────────

  final viewType = ValueNotifier<CalendarViewType>(CalendarViewType.weekly);

  // ── Estado del calendario ─────────────────────────────────────────────────

  final isLoading     = ValueNotifier<bool>(true);
  final isAthleteMode = ValueNotifier<bool>(false);
  final selectedDay   = ValueNotifier<DateTime>(DateTime.now());
  final focusedMonth  = ValueNotifier<DateTime>(DateTime.now());

  // Modo atleta — stream reactivo del mes (vista mensual)
  final sessionsByDate      = ValueNotifier<Map<String, List<AthleteSession>>>({});
  final selectedDaySessions = ValueNotifier<List<AthleteSession>>([]);

  // Modo recreativo — lista completa cargada una vez
  final trainingDates       = ValueNotifier<Set<String>>({});
  final allWorkouts         = ValueNotifier<List<Entrenamiento>>([]);
  final selectedDayWorkouts = ValueNotifier<List<Entrenamiento>>([]);

  // Vista semanal
  final weekDays          = ValueNotifier<List<DateTime>>([]);
  final weekSessionsByDay = ValueNotifier<Map<String, List<AthleteSession>>>({});
  final weekWorkoutsByDay = ValueNotifier<Map<String, List<Entrenamiento>>>({});

  // Vista temporada (atleta)
  final seasonWeeks = ValueNotifier<List<SeasonWeekData>>([]);

  StreamSubscription<List<AthleteSession>>? _sessionSub;
  StreamSubscription<List<AthleteSession>>? _seasonSub;

  // ── API pública ───────────────────────────────────────────────────────────

  Future<void> loadAll() async {
    isLoading.value = true;
    try {
      isAthleteMode.value = await _userService.getIsAthleteMode(userId);
      // Siempre cargar todos los entrenamientos (necesario para vista semanal y temporada)
      await _loadTrainingDates();
      if (isAthleteMode.value) {
        _subscribeToMonth(DateTime.now());
        _subscribeToSeason();
      }
      _computeWeekDays();
      _updateWeekData();
      _updateSelectedDayWorkouts(selectedDay.value);
    } catch (e) {
      debugPrint('[CalendarViewModel] loadAll error: $e');
    }
    if (!_disposed) isLoading.value = false;
  }

  void onDaySelected(DateTime day, DateTime focused) {
    selectedDay.value = day;
    if (isAthleteMode.value) {
      selectedDaySessions.value = sessionsByDate.value[_dateKey(day)] ?? [];
      if (focused.month != focusedMonth.value.month ||
          focused.year  != focusedMonth.value.year) {
        focusedMonth.value = focused;
        _subscribeToMonth(focused);
      }
    } else {
      _updateSelectedDayWorkouts(day);
    }
    _computeWeekDays();
    _updateWeekData();
  }

  void onMonthChanged(DateTime month) {
    focusedMonth.value = month;
    if (isAthleteMode.value) {
      _subscribeToMonth(month);
    }
  }

  void navigateWeek(int deltaDays) {
    final newDay = selectedDay.value.add(Duration(days: deltaDays));
    selectedDay.value = newDay;
    if (isAthleteMode.value) {
      selectedDaySessions.value = sessionsByDate.value[_dateKey(newDay)] ?? [];
    } else {
      _updateSelectedDayWorkouts(newDay);
    }
    _computeWeekDays();
    _updateWeekData();
  }

  Future<void> toggleAthleteMode() async {
    isLoading.value = true;
    final newVal = !isAthleteMode.value;
    await _userService.setAthleteMode(userId, value: newVal);
    if (_disposed) return;
    isAthleteMode.value = newVal;
    if (newVal) {
      _subscribeToMonth(focusedMonth.value);
      _subscribeToSeason();
    } else {
      _sessionSub?.cancel();
      _sessionSub = null;
      _seasonSub?.cancel();
      _seasonSub = null;
      await _loadTrainingDates();
      if (_disposed) return;
      _updateSelectedDayWorkouts(selectedDay.value);
      seasonWeeks.value = [];
      if (viewType.value == CalendarViewType.season) {
        viewType.value = CalendarViewType.weekly;
      }
    }
    _computeWeekDays();
    _updateWeekData();
    isLoading.value = false;
  }

  void dispose() {
    _disposed = true;
    _sessionSub?.cancel();
    _seasonSub?.cancel();
    isLoading.dispose();
    isAthleteMode.dispose();
    selectedDay.dispose();
    focusedMonth.dispose();
    viewType.dispose();
    sessionsByDate.dispose();
    selectedDaySessions.dispose();
    trainingDates.dispose();
    allWorkouts.dispose();
    selectedDayWorkouts.dispose();
    weekDays.dispose();
    weekSessionsByDay.dispose();
    weekWorkoutsByDay.dispose();
    seasonWeeks.dispose();
  }

  // ── Privado — mes ─────────────────────────────────────────────────────────

  void _subscribeToMonth(DateTime month) {
    _sessionSub?.cancel();
    final first = DateTime(month.year, month.month, 1);
    final last  = DateTime(month.year, month.month + 1, 0);
    _sessionSub = _sessionRepo
        .streamSessionsInRange(
          uid:       userId,
          startDate: _dateKey(first),
          endDate:   _dateKey(last),
        )
        .listen(
          (sessions) {
            final map = <String, List<AthleteSession>>{};
            for (final s in sessions) {
              map.putIfAbsent(s.date, () => []).add(s);
            }
            sessionsByDate.value = map;
            selectedDaySessions.value = map[_dateKey(selectedDay.value)] ?? [];
            _updateWeekData(); // refrescar vista semanal con datos actualizados
          },
          onError: (Object e) => debugPrint('[CalendarViewModel] month stream error: $e'),
        );
  }

  // ── Privado — temporada ───────────────────────────────────────────────────

  void _subscribeToSeason() {
    _seasonSub?.cancel();
    final now   = DateTime.now();
    final start = now.subtract(Duration(days: now.weekday - 1 + (15 * 7)));
    final end   = now.add(const Duration(days: 6));

    _seasonSub = _sessionRepo
        .streamSessionsInRange(
          uid:       userId,
          startDate: _dateKey(start),
          endDate:   _dateKey(end),
        )
        .listen(
          (sessions) => _computeSeasonWeeks(sessions),
          onError: (Object e) => debugPrint('[CalendarViewModel] season stream error: $e'),
        );
  }

  void _computeSeasonWeeks(List<AthleteSession> allSessions) {
    final now    = DateTime.now();
    final weeks  = <SeasonWeekData>[];
    final loads  = <double>[];

    // Primera pasada: calcular carga por semana
    for (int i = 15; i >= 0; i--) {
      final monday = _mondayOf(now.subtract(Duration(days: i * 7)));
      final sunday = monday.add(const Duration(days: 6));

      final weekWorkouts = allWorkouts.value.where((w) {
        return !w.fecha.isBefore(monday) && !w.fecha.isAfter(sunday);
      }).toList();

      loads.add(weekWorkouts.fold(0.0, (s, e) => s + (e.loadScore ?? 0.0)));
    }

    final avgLoad = loads.isEmpty ? 0.0
        : loads.where((l) => l > 0).fold(0.0, (a, b) => a + b) /
          (loads.where((l) => l > 0).length.clamp(1, 16));

    // Segunda pasada: construir SeasonWeekData
    for (int i = 15; i >= 0; i--) {
      final monday = _mondayOf(now.subtract(Duration(days: i * 7)));
      final sunday = monday.add(const Duration(days: 6));
      final mondayKey = _dateKey(monday);
      final sundayKey = _dateKey(sunday);

      final weekWorkouts = allWorkouts.value.where((w) {
        return !w.fecha.isBefore(monday) && !w.fecha.isAfter(sunday);
      }).toList();

      final weekSessions = allSessions.where((s) {
        return s.date.compareTo(mondayKey) >= 0 && s.date.compareTo(sundayKey) <= 0;
      }).toList();

      final load   = weekWorkouts.fold(0.0, (s, e) => s + (e.loadScore ?? 0.0));
      final volume = weekWorkouts.fold(0.0, (s, e) => s + e.distanciaTotalM() / 1000.0);
      final hasRace = weekSessions.any((s) => s.category == 'competicion');

      String weekType;
      if (hasRace) {
        weekType = 'competición';
      } else if (avgLoad == 0 || load == 0) {
        weekType = 'transición';
      } else {
        final ratio = load / avgLoad;
        if (ratio < 0.6) weekType = 'transición';
        else if (ratio < 0.8) weekType = 'descarga';
        else if (ratio <= 1.1) weekType = 'base';
        else weekType = 'carga';
      }

      weeks.add(SeasonWeekData(
        weekStart:    monday,
        weekNumber:   _weekOfYear(monday),
        volumeKm:     volume,
        sessionCount: weekWorkouts.length,
        loadScore:    load,
        weekType:     weekType,
        hasRace:      hasRace,
        sessions:     weekSessions,
      ));
    }

    seasonWeeks.value = weeks;
  }

  // ── Privado — semana ──────────────────────────────────────────────────────

  void _computeWeekDays() {
    final monday = _mondayOf(selectedDay.value);
    weekDays.value = List.generate(7, (i) => monday.add(Duration(days: i)));
  }

  void _updateWeekData() {
    if (isAthleteMode.value) {
      final byDay = <String, List<AthleteSession>>{};
      for (final day in weekDays.value) {
        final key = _dateKey(day);
        byDay[key] = sessionsByDate.value[key] ?? [];
      }
      weekSessionsByDay.value = byDay;
    } else {
      final byDay = <String, List<Entrenamiento>>{};
      for (final day in weekDays.value) {
        final key = _dateKey(day);
        byDay[key] = allWorkouts.value
            .where((w) => _dateKey(w.fecha) == key)
            .toList();
      }
      weekWorkoutsByDay.value = byDay;
    }
  }

  // ── Privado — entrenamientos ──────────────────────────────────────────────

  Future<void> _loadTrainingDates() async {
    final workouts = await _trainingRepo.getAllEntrenamientos(userId);
    if (_disposed) return;
    workouts.sort((a, b) => b.fecha.compareTo(a.fecha));
    allWorkouts.value  = workouts;
    trainingDates.value = { for (final w in workouts) _dateKey(w.fecha) };
  }

  void _updateSelectedDayWorkouts(DateTime day) {
    final key = _dateKey(day);
    selectedDayWorkouts.value =
        allWorkouts.value.where((w) => _dateKey(w.fecha) == key).toList();
  }

  // ── Utilidades ────────────────────────────────────────────────────────────

  String _dateKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  DateTime _mondayOf(DateTime d) =>
      DateTime(d.year, d.month, d.day).subtract(Duration(days: d.weekday - 1));

  int _weekOfYear(DateTime date) {
    final firstDay = DateTime(date.year, 1, 1);
    final days = date.difference(firstDay).inDays;
    return ((days + firstDay.weekday - 1) / 7).ceil();
  }
}
