import 'package:flutter/foundation.dart';
import 'package:running_laps/features/athlete/data/athlete_session_model.dart';
import 'package:running_laps/features/athlete/data/athlete_session_repository.dart';
import 'package:running_laps/features/training/data/entrenamiento.dart';
import 'package:running_laps/features/training/data/training_repository.dart';

// ── Models ────────────────────────────────────────────────────────────────────

class PersonalRecord {
  final int distanceM;
  final double paceSecPerKm;
  final DateTime date;
  final String trainingId;

  const PersonalRecord({
    required this.distanceM,
    required this.paceSecPerKm,
    required this.date,
    required this.trainingId,
  });
}

class SeriesDataPoint {
  final DateTime date;
  final double paceSecPerKm;
  final double rpe;
  final String trainingId;

  const SeriesDataPoint({
    required this.date,
    required this.paceSecPerKm,
    required this.rpe,
    required this.trainingId,
  });
}

class SeriesProgressGroup {
  final int baseDistanceM;
  final List<SeriesDataPoint> history;
  final int count;

  const SeriesProgressGroup({
    required this.baseDistanceM,
    required this.history,
    required this.count,
  });
}

class WeeklyVolume {
  final DateTime weekStart;
  final double km;
  final int sessionCount;

  const WeeklyVolume({
    required this.weekStart,
    required this.km,
    required this.sessionCount,
  });
}

class PlannedVsExecuted {
  final AthleteSession planned;
  final Entrenamiento executed;

  const PlannedVsExecuted({
    required this.planned,
    required this.executed,
  });
}

// ── ProgressRepository ────────────────────────────────────────────────────────

class ProgressRepository {
  ProgressRepository({
    TrainingRepository? trainingRepository,
    AthleteSessionRepository? sessionRepository,
  })  : _trainingRepo = trainingRepository ?? TrainingRepository(),
        _sessionRepo  = sessionRepository  ?? AthleteSessionRepository();

  final TrainingRepository       _trainingRepo;
  final AthleteSessionRepository _sessionRepo;

  // ── Standard distances with tolerance ranges ───────────────────────────────

  static const Map<int, (int, int)> _stdDistances = {
    400:   (320,   480),   // ±20 %
    1000:  (900,   1100),  // ±10 %
    1500:  (1275,  1725),  // ±15 %
    5000:  (4250,  5750),  // ±15 %
    10000: (8500,  11500), // ±15 %
  };

  // ── getPersonalRecords ─────────────────────────────────────────────────────

  Future<Map<int, PersonalRecord>> getPersonalRecords(String uid) async {
    final trainings = await _trainingRepo.getTrainings();
    final records   = <int, PersonalRecord>{};

    for (final training in trainings) {
      final id = training.id;
      if (id == null) continue;

      for (final serie in training.series) {
        if (serie.distanciaM <= 0 || serie.tiempoSec <= 0) continue;
        final pace = serie.tiempoSec / (serie.distanciaM / 1000.0);

        for (final entry in _stdDistances.entries) {
          final stdDist = entry.key;
          final range   = entry.value;
          if (serie.distanciaM < range.$1 || serie.distanciaM > range.$2) {
            continue;
          }
          final existing = records[stdDist];
          if (existing == null || pace < existing.paceSecPerKm) {
            records[stdDist] = PersonalRecord(
              distanceM:    stdDist,
              paceSecPerKm: pace,
              date:         training.fecha,
              trainingId:   id,
            );
          }
        }
      }
    }

    return records;
  }

  // ── getSeriesProgress ──────────────────────────────────────────────────────

  Future<List<SeriesProgressGroup>> getSeriesProgress(String uid) async {
    final trainings = await _trainingRepo.getTrainings();

    // Map from base distance (m) → list of data points
    final groups = <int, List<SeriesDataPoint>>{};

    for (final training in trainings) {
      final id = training.id;
      if (id == null) continue;

      for (final serie in training.series) {
        if (serie.distanciaM <= 0 || serie.tiempoSec <= 0) continue;

        final base = _findOrCreateBase(groups.keys, serie.distanciaM);
        final pace = serie.tiempoSec / (serie.distanciaM / 1000.0);

        groups.putIfAbsent(base, () => []).add(SeriesDataPoint(
          date:         training.fecha,
          paceSecPerKm: pace,
          rpe:          serie.rpe,
          trainingId:   id,
        ));
      }
    }

    return groups.entries
        .where((e) => e.value.length >= 3)
        .map((e) {
          final sorted = e.value.toList()
            ..sort((a, b) => a.date.compareTo(b.date));
          return SeriesProgressGroup(
            baseDistanceM: e.key,
            history:       sorted,
            count:         sorted.length,
          );
        })
        .toList()
      ..sort((a, b) => b.count.compareTo(a.count)); // most frequent first
  }

  /// Returns the existing base distance within ±10 % of [distanceM],
  /// or [distanceM] itself if no matching base exists yet.
  int _findOrCreateBase(Iterable<int> existing, int distanceM) {
    for (final base in existing) {
      final lower = base * 0.90;
      final upper = base * 1.10;
      if (distanceM >= lower && distanceM <= upper) return base;
    }
    return distanceM;
  }

  // ── getWeeklyVolume ────────────────────────────────────────────────────────

  Future<List<WeeklyVolume>> getWeeklyVolume(
    String uid, {
    int weeks = 12,
  }) async {
    final trainings = await _trainingRepo.getTrainings();
    final now       = DateTime.now();
    final today     = DateTime(now.year, now.month, now.day);

    // Monday of the oldest week
    final currentMonday = today.subtract(Duration(days: today.weekday - 1));
    final oldestMonday  =
        currentMonday.subtract(Duration(days: (weeks - 1) * 7));

    // Build a map weekStart → WeeklyVolume for every requested week
    final volumeMap = <DateTime, _MutableWeeklyVolume>{};
    for (var w = 0; w < weeks; w++) {
      final weekStart = oldestMonday.add(Duration(days: w * 7));
      volumeMap[weekStart] = _MutableWeeklyVolume();
    }

    for (final training in trainings) {
      final d = DateTime(
          training.fecha.year, training.fecha.month, training.fecha.day);
      if (d.isBefore(oldestMonday)) continue;

      // Find this training's Monday
      final monday = d.subtract(Duration(days: d.weekday - 1));
      final bucket = volumeMap[monday];
      if (bucket == null) continue; // outside the requested window

      bucket.km           += training.distanciaTotalM() / 1000.0;
      bucket.sessionCount += 1;
    }

    return volumeMap.entries
        .map((e) => WeeklyVolume(
              weekStart:    e.key,
              km:           e.value.km,
              sessionCount: e.value.sessionCount,
            ))
        .toList()
      ..sort((a, b) => a.weekStart.compareTo(b.weekStart));
  }

  // ── getPlannedVsExecuted ───────────────────────────────────────────────────

  Future<List<PlannedVsExecuted>> getPlannedVsExecuted(
    String uid, {
    int limit = 20,
  }) async {
    // Load all data without new Firestore queries — cross join client-side
    final now       = DateTime.now();
    final pastStart = _fmt(now.subtract(const Duration(days: 365 * 2)));
    final futureEnd = _fmt(now.add(const Duration(days: 90)));

    List<AthleteSession> sessions;
    try {
      sessions = await _sessionRepo
          .streamSessionsInRange(
            uid:       uid,
            startDate: pastStart,
            endDate:   futureEnd,
          )
          .first;
    } catch (e) {
      debugPrint('[ProgressRepository] getPlannedVsExecuted sessions error: $e');
      sessions = [];
    }

    // Keep only completed sessions that have a linked training
    final linked = sessions
        .where((s) =>
            s.status == AthleteSessionStatus.completed &&
            s.completedTrainingId != null &&
            s.completedTrainingId!.isNotEmpty)
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));

    if (linked.isEmpty) return [];

    // Load trainings and index by id
    List<Entrenamiento> trainings;
    try {
      trainings = await _trainingRepo.getTrainings();
    } catch (e) {
      debugPrint('[ProgressRepository] getPlannedVsExecuted trainings error: $e');
      trainings = [];
    }
    final trainingById = {
      for (final t in trainings)
        if (t.id != null) t.id!: t,
    };

    // Cross join — skip records where the training is not in the local cache
    final result = <PlannedVsExecuted>[];
    for (final session in linked) {
      if (result.length >= limit) break;
      final training = trainingById[session.completedTrainingId];
      if (training == null) {
        debugPrint(
          '[ProgressRepository] training ${session.completedTrainingId} '
          'not found in cache — skipping session ${session.id}',
        );
        continue;
      }
      result.add(PlannedVsExecuted(planned: session, executed: training));
    }

    return result;
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  String _fmt(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

// ── Internal mutable accumulator ──────────────────────────────────────────────

class _MutableWeeklyVolume {
  double km           = 0;
  int    sessionCount = 0;
}
