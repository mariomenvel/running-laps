import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:running_laps/features/athlete/data/athlete_session_model.dart';
import 'package:running_laps/features/athlete/data/athlete_session_repository.dart';

// ── State ─────────────────────────────────────────────────────────────────────

class AthleteCalendarState {
  final Map<String, List<AthleteSession>> sessionsByDate;
  final DateTime focusedMonth;
  final DateTime? selectedDay;
  final bool isLoading;
  final String? errorMessage;

  const AthleteCalendarState({
    this.sessionsByDate = const {},
    required this.focusedMonth,
    this.selectedDay,
    this.isLoading = false,
    this.errorMessage,
  });

  AthleteCalendarState copyWith({
    Map<String, List<AthleteSession>>? sessionsByDate,
    DateTime? focusedMonth,
    Object? selectedDay    = _sentinel,
    bool? isLoading,
    Object? errorMessage   = _sentinel,
  }) {
    return AthleteCalendarState(
      sessionsByDate: sessionsByDate ?? this.sessionsByDate,
      focusedMonth:   focusedMonth   ?? this.focusedMonth,
      selectedDay:    selectedDay  == _sentinel ? this.selectedDay  : selectedDay  as DateTime?,
      isLoading:      isLoading      ?? this.isLoading,
      errorMessage:   errorMessage == _sentinel ? this.errorMessage : errorMessage as String?,
    );
  }
}

const Object _sentinel = Object();

// ── ViewModel ─────────────────────────────────────────────────────────────────

class AthleteCalendarViewModel {
  AthleteCalendarViewModel({AthleteSessionRepository? repository})
      : _repository = repository ?? AthleteSessionRepository();

  final AthleteSessionRepository _repository;

  final ValueNotifier<AthleteCalendarState> state = ValueNotifier(
    AthleteCalendarState(focusedMonth: DateTime.now()),
  );

  String? _uid;
  StreamSubscription<List<AthleteSession>>? _subscription;

  // ── Public API ─────────────────────────────────────────────────────────────

  void init(String uid) {
    _uid = uid;
    _subscribeToMonth(DateTime.now());
  }

  void selectDay(DateTime day) {
    final current = state.value;
    final monthChanged = day.year != current.focusedMonth.year ||
        day.month != current.focusedMonth.month;
    state.value = current.copyWith(selectedDay: day);
    if (monthChanged) _subscribeToMonth(day);
  }

  void onPageChanged(DateTime month) {
    _subscribeToMonth(month);
  }

  List<AthleteSession> sessionsForDay(DateTime day) {
    return state.value.sessionsByDate[_normalize(day)] ?? [];
  }

  void dispose() {
    _subscription?.cancel();
    state.dispose();
  }

  // ── Private ────────────────────────────────────────────────────────────────

  void _subscribeToMonth(DateTime month) {
    if (_uid == null) return;
    _subscription?.cancel();

    final first = DateTime(month.year, month.month, 1);
    final last  = DateTime(month.year, month.month + 1, 0);

    state.value = state.value.copyWith(
      focusedMonth: month,
      isLoading: true,
      errorMessage: null,
    );

    _subscription = _repository
        .streamSessionsInRange(
          uid:       _uid!,
          startDate: _normalize(first),
          endDate:   _normalize(last),
        )
        .listen(
          (sessions) {
            final map = <String, List<AthleteSession>>{};
            for (final s in sessions) {
              map.putIfAbsent(s.date, () => []).add(s);
            }
            state.value = state.value.copyWith(
              sessionsByDate: map,
              isLoading: false,
              errorMessage: null,
            );
          },
          onError: (Object e) {
            debugPrint('[AthleteCalendarViewModel] stream error: $e');
            state.value = state.value.copyWith(
              isLoading: false,
              errorMessage: 'Error cargando sesiones',
            );
          },
        );
  }

  String _normalize(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
