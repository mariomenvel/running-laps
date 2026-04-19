import 'package:flutter/foundation.dart';
import 'package:running_laps/features/athlete/data/athlete_session_model.dart';
import 'package:running_laps/features/athlete/data/progress_repository.dart';

// ── State ─────────────────────────────────────────────────────────────────────

class ProgressViewModelState {
  final bool isLoading;
  final String? errorMessage;
  final Map<int, PersonalRecord> personalRecords;
  final List<SeriesProgressGroup> seriesProgress;
  final List<WeeklyVolume> weeklyVolume;
  final List<double> movingAverage;
  final List<PlannedVsExecuted> plannedVsExecuted;

  const ProgressViewModelState({
    this.isLoading        = false,
    this.errorMessage,
    this.personalRecords  = const {},
    this.seriesProgress   = const [],
    this.weeklyVolume     = const [],
    this.movingAverage    = const [],
    this.plannedVsExecuted = const [],
  });

  ProgressViewModelState copyWith({
    bool? isLoading,
    Object? errorMessage              = _sentinel,
    Map<int, PersonalRecord>? personalRecords,
    List<SeriesProgressGroup>? seriesProgress,
    List<WeeklyVolume>? weeklyVolume,
    List<double>? movingAverage,
    List<PlannedVsExecuted>? plannedVsExecuted,
  }) {
    return ProgressViewModelState(
      isLoading:         isLoading         ?? this.isLoading,
      errorMessage:      errorMessage      == _sentinel
          ? this.errorMessage
          : errorMessage as String?,
      personalRecords:   personalRecords   ?? this.personalRecords,
      seriesProgress:    seriesProgress    ?? this.seriesProgress,
      weeklyVolume:      weeklyVolume      ?? this.weeklyVolume,
      movingAverage:     movingAverage     ?? this.movingAverage,
      plannedVsExecuted: plannedVsExecuted ?? this.plannedVsExecuted,
    );
  }
}

const Object _sentinel = Object();

// ── ViewModel ─────────────────────────────────────────────────────────────────

class ProgressViewModel {
  ProgressViewModel({ProgressRepository? repository})
      : _repo = repository ?? ProgressRepository();

  final ProgressRepository _repo;

  final ValueNotifier<ProgressViewModelState> state =
      ValueNotifier(const ProgressViewModelState());

  // ── Public API ─────────────────────────────────────────────────────────────

  Future<void> init(String uid) async {
    state.value = state.value.copyWith(isLoading: true, errorMessage: null);

    try {
      final results = await Future.wait<dynamic>([
        _repo.getPersonalRecords(uid),        // [0]
        _repo.getSeriesProgress(uid),         // [1]
        _repo.getWeeklyVolume(uid, weeks: 12), // [2]
        _repo.getPlannedVsExecuted(uid, limit: 20), // [3]
      ]);

      final personalRecords   = results[0] as Map<int, PersonalRecord>;
      final seriesProgress    = results[1] as List<SeriesProgressGroup>;
      final weeklyVolume      = results[2] as List<WeeklyVolume>;
      final plannedVsExecuted = results[3] as List<PlannedVsExecuted>;

      final movingAverage = _computeMovingAverage(weeklyVolume);

      state.value = state.value.copyWith(
        isLoading:         false,
        personalRecords:   personalRecords,
        seriesProgress:    seriesProgress,
        weeklyVolume:      weeklyVolume,
        movingAverage:     movingAverage,
        plannedVsExecuted: plannedVsExecuted,
      );
    } catch (e) {
      debugPrint('[ProgressViewModel] init error: $e');
      state.value = state.value.copyWith(
        isLoading:    false,
        errorMessage: 'Error al cargar el progreso',
      );
    }
  }

  void dispose() => state.dispose();

  // ── Convenience getters ────────────────────────────────────────────────────

  bool get hasPersonalRecords    => state.value.personalRecords.isNotEmpty;
  bool get hasSeriesProgress     => state.value.seriesProgress.isNotEmpty;
  bool get hasPlannedVsExecuted  => state.value.plannedVsExecuted.isNotEmpty;

  // ── trendForGroup ──────────────────────────────────────────────────────────

  /// Positivo = mejorando (pace bajando), negativo = empeorando.
  /// Compara la media de la primera mitad del historial contra la segunda.
  /// Devuelve null si el grupo tiene menos de 6 puntos.
  double? trendForGroup(SeriesProgressGroup group) {
    if (group.count < 6) return null;
    final history = group.history;
    final mid     = history.length ~/ 2;

    final firstHalf  = history.sublist(0, mid);
    final secondHalf = history.sublist(mid);

    final avgFirst  = firstHalf.fold<double>(0, (s, p) => s + p.paceSecPerKm)
        / firstHalf.length;
    final avgSecond = secondHalf.fold<double>(0, (s, p) => s + p.paceSecPerKm)
        / secondHalf.length;

    // Positive result means pace went down (faster) → improving
    return avgFirst - avgSecond;
  }

  // ── paceDeviationSecPerKm ──────────────────────────────────────────────────

  /// Diferencia entre pace objetivo (primer bloque con targetPaceMinMin)
  /// y pace medio ejecutado.
  /// Negativo = más rápido que el objetivo; positivo = más lento.
  /// Devuelve null si la sesión planificada no tiene pace objetivo.
  double? paceDeviationSecPerKm(PlannedVsExecuted pve) {
    // Find the first block with a target pace defined
    SessionBlock? targetBlock;
    for (final block in pve.planned.blocks) {
      if (block.targetPaceMinMin != null) {
        targetBlock = block;
        break;
      }
    }
    if (targetBlock == null) return null;

    // Target pace mid-point: average of min and max if both set,
    // otherwise use the min bound alone
    final minSec = (targetBlock.targetPaceMinMin! * 60) +
        (targetBlock.targetPaceMinSec ?? 0);
    final int targetSec;
    if (targetBlock.targetPaceMaxMin != null) {
      final maxSec = (targetBlock.targetPaceMaxMin! * 60) +
          (targetBlock.targetPaceMaxSec ?? 0);
      targetSec = ((minSec + maxSec) / 2).round();
    } else {
      targetSec = minSec;
    }

    if (targetSec <= 0) return null;

    // Executed average pace across all series
    final series = pve.executed.series
        .where((s) => s.distanciaM > 0 && s.tiempoSec > 0)
        .toList();
    if (series.isEmpty) return null;

    final avgExecuted = series.fold<double>(
          0,
          (sum, s) => sum + s.tiempoSec / (s.distanciaM / 1000.0),
        ) /
        series.length;

    return avgExecuted - targetSec;
  }

  // ── Private ────────────────────────────────────────────────────────────────

  List<double> _computeMovingAverage(List<WeeklyVolume> volumes) {
    if (volumes.isEmpty) return [];
    return List.generate(volumes.length, (i) {
      final start = i < 3 ? 0 : i - 3;
      final slice = volumes.sublist(start, i + 1);
      return slice.fold<double>(0, (s, w) => s + w.km) / slice.length;
    });
  }
}
