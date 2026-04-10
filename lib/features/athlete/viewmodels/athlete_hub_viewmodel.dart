import 'package:flutter/foundation.dart';
import 'package:running_laps/features/athlete/data/athlete_session_model.dart';
import 'package:running_laps/features/athlete/data/athlete_session_repository.dart';

// ── Weekly summary ────────────────────────────────────────────────────────────

class WeeklySummary {
  final int sessionCount;
  final int plannedCount;
  final int completedCount;

  const WeeklySummary({
    this.sessionCount = 0,
    this.plannedCount = 0,
    this.completedCount = 0,
  });
}

// ── State ─────────────────────────────────────────────────────────────────────

class AthleteHubState {
  final bool isLoading;
  final WeeklySummary weeklySummary;
  final AthleteSession? nextSession;
  final bool hasAnyData;

  const AthleteHubState({
    this.isLoading = false,
    this.weeklySummary = const WeeklySummary(),
    this.nextSession,
    this.hasAnyData = false,
  });

  AthleteHubState copyWith({
    bool? isLoading,
    WeeklySummary? weeklySummary,
    Object? nextSession = _sentinel,
    bool? hasAnyData,
  }) {
    return AthleteHubState(
      isLoading:     isLoading     ?? this.isLoading,
      weeklySummary: weeklySummary ?? this.weeklySummary,
      nextSession:   nextSession == _sentinel ? this.nextSession : nextSession as AthleteSession?,
      hasAnyData:    hasAnyData    ?? this.hasAnyData,
    );
  }
}

const Object _sentinel = Object();

// ── ViewModel ─────────────────────────────────────────────────────────────────

class AthleteHubViewModel {
  AthleteHubViewModel({AthleteSessionRepository? repository})
      : _repository = repository ?? AthleteSessionRepository();

  final AthleteSessionRepository _repository;

  final ValueNotifier<AthleteHubState> state =
      ValueNotifier(const AthleteHubState());

  // ── Public API ─────────────────────────────────────────────────────────────

  Future<void> init(String uid) async {
    state.value = state.value.copyWith(isLoading: true);
    try {
      final now   = DateTime.now();
      final today = _normalize(now);

      // Current week: Monday → Sunday
      final weekStart = now.subtract(Duration(days: now.weekday - 1));
      final weekEnd   = weekStart.add(const Duration(days: 6));

      final sessions = await _weekSessions(
        uid:   uid,
        start: _normalize(DateTime(weekStart.year, weekStart.month, weekStart.day)),
        end:   _normalize(DateTime(weekEnd.year,   weekEnd.month,   weekEnd.day)),
      );

      final summary = WeeklySummary(
        sessionCount:   sessions.length,
        plannedCount:   sessions.where((s) => s.status == AthleteSessionStatus.planned).length,
        completedCount: sessions.where((s) => s.status == AthleteSessionStatus.completed).length,
      );

      // Next planned session: today or later, status == planned, sorted by date+time
      final upcoming = sessions
          .where((s) =>
              s.status == AthleteSessionStatus.planned &&
              s.date.compareTo(today) >= 0)
          .toList()
        ..sort((a, b) {
          final dateCmp = a.date.compareTo(b.date);
          if (dateCmp != 0) return dateCmp;
          return (a.time ?? '').compareTo(b.time ?? '');
        });

      state.value = state.value.copyWith(
        isLoading:     false,
        weeklySummary: summary,
        nextSession:   upcoming.isNotEmpty ? upcoming.first : null,
        hasAnyData:    sessions.isNotEmpty,
      );
    } catch (e) {
      debugPrint('[AthleteHubViewModel] init error: $e');
      state.value = state.value.copyWith(isLoading: false);
    }
  }

  void dispose() {
    state.dispose();
  }

  // ── Private ────────────────────────────────────────────────────────────────

  Future<List<AthleteSession>> _weekSessions({
    required String uid,
    required String start,
    required String end,
  }) async {
    // One-off snapshot of the stream's first emission
    final completer = <AthleteSession>[];
    try {
      await _repository
          .streamSessionsInRange(uid: uid, startDate: start, endDate: end)
          .first
          .then((list) => completer.addAll(list));
    } catch (_) {}
    return completer;
  }

  String _normalize(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
