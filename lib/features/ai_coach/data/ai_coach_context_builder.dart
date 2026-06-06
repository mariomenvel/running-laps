import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:running_laps/features/ai_coach/data/ai_coach_models.dart';
import 'package:running_laps/features/ai_coach/data/ai_coach_repository.dart';
import 'package:running_laps/features/athlete/data/athlete_session_model.dart';
import 'package:running_laps/features/athlete/data/athlete_session_repository.dart';
import 'package:running_laps/features/profile/data/user_profile_model.dart';
import 'package:running_laps/features/training/data/entrenamiento.dart';
import 'package:running_laps/features/training/data/training_repository.dart';

class AiCoachContextBuilder {
  AiCoachContextBuilder({
    TrainingRepository? trainingRepository,
    AthleteSessionRepository? sessionRepository,
    AiCoachRepository? aiCoachRepository,
    FirebaseFirestore? firestore,
  })  : _trainingRepository = trainingRepository ?? TrainingRepository(),
        _sessionRepository = sessionRepository ?? AthleteSessionRepository(),
        _aiCoachRepository = aiCoachRepository ?? AiCoachRepository(),
        _db = firestore ?? FirebaseFirestore.instance;

  final TrainingRepository _trainingRepository;
  final AthleteSessionRepository _sessionRepository;
  final AiCoachRepository _aiCoachRepository;
  final FirebaseFirestore _db;

  Future<AiCoachWeeklyContext> buildWeeklyContext(String uid) async {
    final now = DateTime.now();
    final weekStart = _mondayOf(now);
    final weekEnd = weekStart.add(const Duration(days: 6));

    final trainings = (await _trainingRepository.getTrainings(
      uid: uid,
      pageSize: 200,
    ))
        .trainings;
    final sessions = await _sessionRepository.getSessionsInRange(
      uid: uid,
      startDate: _dateKey(now.subtract(const Duration(days: 84))),
      endDate: _dateKey(now.add(const Duration(days: 21))),
    );
    final profile = await _aiCoachRepository.getProfile(uid: uid);
    final athleteMemory = await _aiCoachRepository.getAthleteMemory(uid: uid) ??
        await _aiCoachRepository.rebuildAthleteMemory(uid: uid);
    final userProfile = await _loadUserProfile(uid);

    final weeklyState = _buildWeeklyState(
      now: now,
      weekStart: weekStart,
      weekEnd: weekEnd,
      trainings: trainings,
      sessions: sessions,
    );

    final linkedSessionByTrainingId = <String, AthleteSession>{};
    for (final session in sessions) {
      final trainingId = session.completedTrainingId;
      if (trainingId != null && trainingId.isNotEmpty) {
        linkedSessionByTrainingId[trainingId] = session;
      }
    }

    final recentTrainings = trainings.take(20).map((training) {
      final linkedSession = training.id != null
          ? linkedSessionByTrainingId[training.id!]
          : null;
      return AiCoachTrainingSummary(
        trainingId: training.id ?? '',
        date: training.fecha,
        title: training.titulo,
        category: linkedSession?.category ?? _inferCategory(training),
        distanceKm: training.distanciaTotalM() / 1000.0,
        durationMinutes: training.tiempoTotalSec() / 60.0,
        paceSecPerKm: training.distanciaTotalM() > 0
            ? training.ritmoMedioSecPorKm().toDouble()
            : null,
        rpe: training.series.isEmpty ? null : training.rpePromedio(),
        load: training.loadScore,
        fcAvg: training.fcMediaSesion,
        note: training.notas,
      );
    }).toList();

    final recentPlannedSessions = sessions
        .where((session) => DateTime.tryParse(session.date) != null)
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));

    final plannedSummaries = recentPlannedSessions.take(16).map((session) {
      return AiCoachPlannedSessionSummary(
        sessionId: session.id,
        date: session.date,
        category: session.category,
        status: session.status.toValue,
        isAiSuggested: session.suggestion?.origin == AthleteSessionOrigin.ai,
        suggestionStatus: session.suggestion?.status.toValue,
      );
    }).toList();

    final effectiveProfile = _mergeProfileWithUserProfile(profile, userProfile);

    final recentWeekHistory = _buildRecentWeekHistory(
      now: now,
      trainings: trainings,
      sessions: sessions,
      weeks: 8,
    );
    final coachSignals = <String, dynamic>{
      'daysSinceLastTraining': weeklyState.daysSinceLastTraining,
      'consecutiveMissedWeeks': weeklyState.consecutiveMissedWeeks,
      'longestRecentBreakDays': _calculateLongestRecentBreakDays(
        now: now,
        trainings: trainings,
        lookbackDays: 84,
      ),
      'hasRecentDetraining':
          weeklyState.daysSinceLastTraining >= 10 ||
          weeklyState.consecutiveMissedWeeks >= 1,
      'shouldRestart':
          weeklyState.daysSinceLastTraining >= 21 ||
          weeklyState.consecutiveMissedWeeks >= 3,
      'availableWeekdays': effectiveProfile?.availableWeekdays ?? const [1, 3, 5],
      'preferredWeeklySessions':
          effectiveProfile?.preferredWeeklySessions ?? 3,
      'preferredLongRunWeekday': effectiveProfile?.preferredLongRunWeekday,
      'needsConservativeWeek': weeklyState.needsDeload ||
          weeklyState.daysSinceLastTraining >= 10,
      'athleteMemory': athleteMemory.toMap(),
      ..._buildAthleteStyleSignals(trainings.take(20).toList()),
    };

    return AiCoachWeeklyContext(
      profile: effectiveProfile,
      weeklyState: weeklyState,
      recentTrainings: recentTrainings,
      recentPlannedSessions: plannedSummaries,
      recentWeekHistory: recentWeekHistory,
      coachSignals: coachSignals,
      generatedAt: now,
    );
  }

  Future<UserProfileModel?> _loadUserProfile(String uid) async {
    try {
      final doc = await _db.collection('users').doc(uid).get();
      final data = doc.data();
      if (!doc.exists || data == null) return null;
      return UserProfileModel.fromMap(uid, data);
    } catch (e) {
      debugPrint('[AiCoachContextBuilder] _loadUserProfile error: $e');
      return null;
    }
  }

  AiCoachProfile? _mergeProfileWithUserProfile(
    AiCoachProfile? profile,
    UserProfileModel? userProfile,
  ) {
    if (userProfile == null) return profile;
    if (profile != null) {
      final merged = userProfile.fcMax != null && profile.fcMax == null
          ? profile.copyWith(fcMax: userProfile.fcMax)
          : profile;
      return merged;
    }
    final now = DateTime.now();
    return AiCoachProfile(
      uid: userProfile.uid,
      goal: AiCoachGoalType.improveEndurance,
      goalDescription: 'Mejorar la consistencia semanal',
      level: AiCoachAthleteLevel.beginner,
      preferredWeeklySessions: 3,
      availableWeekdays: const [1, 3, 5],
      fcMax: userProfile.fcMax,
      createdAt: now,
      updatedAt: now,
    );
  }

  AiCoachWeeklyState _buildWeeklyState({
    required DateTime now,
    required DateTime weekStart,
    required DateTime weekEnd,
    required List<Entrenamiento> trainings,
    required List<AthleteSession> sessions,
  }) {
    final weekTrainings = trainings.where((training) {
      final day = DateTime(
        training.fecha.year,
        training.fecha.month,
        training.fecha.day,
      );
      return !day.isBefore(weekStart) && !day.isAfter(weekEnd);
    }).toList();

    final weekSessions = sessions.where((session) {
      final date = DateTime.tryParse(session.date);
      if (date == null) return false;
      final day = DateTime(date.year, date.month, date.day);
      return !day.isBefore(weekStart) && !day.isAfter(weekEnd);
    }).toList();

    final plannedSessions = weekSessions.length;
    final completedSessions = weekSessions
        .where((session) => session.status == AthleteSessionStatus.completed)
        .length;
    final skippedSessions = weekSessions
        .where((session) => session.status == AthleteSessionStatus.skipped)
        .length;

    final weeklyKm = weekTrainings.fold<double>(
      0,
      (totalKm, training) => totalKm + training.distanciaTotalM() / 1000.0,
    );
    final weeklyLoad = weekTrainings.fold<double>(
      0,
      (totalLoad, training) =>
          totalLoad + (training.loadScore ?? _fallbackLoad(training)),
    );
    final rpeValues = weekTrainings
        .map((training) => training.series.isEmpty ? null : training.rpePromedio())
        .whereType<double>()
        .toList();
    final weeklyRpeAverage = rpeValues.isEmpty
        ? 0.0
        : rpeValues.reduce((a, b) => a + b) / rpeValues.length;

    final atl = _calculateEwmaLoad(
      now: now,
      trainings: trainings,
      timeConstantDays: 7,
    );
    final ctl = _calculateEwmaLoad(
      now: now,
      trainings: trainings,
      timeConstantDays: 42,
    );
    final tsb = ctl - atl;

    final lastTraining = trainings.isEmpty ? null : trainings.first.fecha;
    final daysSinceLastTraining = lastTraining == null
        ? 999
        : DateTime(
                now.year,
                now.month,
                now.day,
              )
            .difference(DateTime(
              lastTraining.year,
              lastTraining.month,
              lastTraining.day,
            ))
            .inDays;

    final consecutiveMissedWeeks = _calculateConsecutiveMissedWeeks(
      now: now,
      trainings: trainings,
    );
    final raceInNext14Days = sessions.any((session) {
      if (session.category != 'competicion') return false;
      final parsed = DateTime.tryParse(session.date);
      if (parsed == null) return false;
      final diff = parsed.difference(DateTime(now.year, now.month, now.day)).inDays;
      return diff >= 0 && diff <= 14;
    });
    final adherenceRatio = plannedSessions == 0
        ? 1.0
        : completedSessions / plannedSessions;

    final trend = _buildTrend(
      adherenceRatio: adherenceRatio,
      atl: atl,
      ctl: ctl,
      weeklyKm: weeklyKm,
    );

    return AiCoachWeeklyState(
      weekStart: weekStart,
      plannedSessions: plannedSessions,
      completedSessions: completedSessions,
      skippedSessions: skippedSessions,
      adherenceRatio: adherenceRatio,
      weeklyKm: weeklyKm,
      weeklyLoad: weeklyLoad,
      weeklyRpeAverage: weeklyRpeAverage,
      atl: atl,
      ctl: ctl,
      tsb: tsb,
      daysSinceLastTraining: daysSinceLastTraining,
      consecutiveMissedWeeks: consecutiveMissedWeeks,
      raceInNext14Days: raceInNext14Days,
      needsDeload: tsb < -10 || weeklyRpeAverage >= 8,
      trend: trend,
    );
  }

  double _calculateEwmaLoad({
    required DateTime now,
    required List<Entrenamiento> trainings,
    required int timeConstantDays,
  }) {
    final today = DateTime(now.year, now.month, now.day);
    final dailyLoads = <DateTime, double>{};
    for (final training in trainings) {
      final day = DateTime(
        training.fecha.year,
        training.fecha.month,
        training.fecha.day,
      );
      dailyLoads.update(
        day,
        (value) => value + (training.loadScore ?? _fallbackLoad(training)),
        ifAbsent: () => training.loadScore ?? _fallbackLoad(training),
      );
    }

    var ewma = 0.0;
    final alpha = 2 / (timeConstantDays + 1);
    for (var offset = 90; offset >= 0; offset--) {
      final day = today.subtract(Duration(days: offset));
      final load = dailyLoads[day] ?? 0.0;
      ewma = ewma + alpha * (load - ewma);
    }
    return double.parse(ewma.toStringAsFixed(2));
  }

  int _calculateConsecutiveMissedWeeks({
    required DateTime now,
    required List<Entrenamiento> trainings,
  }) {
    final todayMonday = _mondayOf(now);
    var missed = 0;
    for (var i = 0; i < 6; i++) {
      final weekStart = todayMonday.subtract(Duration(days: i * 7));
      final weekEnd = weekStart.add(const Duration(days: 6));
      final hasTraining = trainings.any((training) {
        final day = DateTime(
          training.fecha.year,
          training.fecha.month,
          training.fecha.day,
        );
        return !day.isBefore(weekStart) && !day.isAfter(weekEnd);
      });
      if (hasTraining) break;
      missed += 1;
    }
    return math.max(0, missed - 1);
  }

  double _fallbackLoad(Entrenamiento training) {
    final distanceKm = training.distanciaTotalM() / 1000.0;
    final durationMin = training.tiempoTotalSec() / 60.0;
    final rpe = training.series.isEmpty ? 5.0 : training.rpePromedio();
    return double.parse(
      ((distanceKm * 0.8) + (durationMin * 0.2) + (rpe * 0.5)).toStringAsFixed(2),
    );
  }

  String _buildTrend({
    required double adherenceRatio,
    required double atl,
    required double ctl,
    required double weeklyKm,
  }) {
    if (adherenceRatio < 0.5) return 'underperforming';
    if (atl > ctl * 1.2) return 'fatigued';
    if (weeklyKm <= 0) return 'inactive';
    if (adherenceRatio >= 0.8 && ctl >= atl * 0.8) return 'progressing';
    return 'stable';
  }

  List<Map<String, dynamic>> _buildRecentWeekHistory({
    required DateTime now,
    required List<Entrenamiento> trainings,
    required List<AthleteSession> sessions,
    int weeks = 8,
  }) {
    final currentWeekStart = _mondayOf(now);
    return List.generate(weeks, (index) {
      final weekStart = currentWeekStart.subtract(Duration(days: index * 7));
      final weekEnd = weekStart.add(const Duration(days: 6));
      final weekTrainings = trainings.where((training) {
        final day = DateTime(
          training.fecha.year,
          training.fecha.month,
          training.fecha.day,
        );
        return !day.isBefore(weekStart) && !day.isAfter(weekEnd);
      }).toList();
      final weekSessions = sessions.where((session) {
        final date = DateTime.tryParse(session.date);
        if (date == null) return false;
        final day = DateTime(date.year, date.month, date.day);
        return !day.isBefore(weekStart) && !day.isAfter(weekEnd);
      }).toList();
      final planned = weekSessions.length;
      final completed = weekSessions
          .where((session) => session.status == AthleteSessionStatus.completed)
          .length;
      final weeklyKm = weekTrainings.fold<double>(
        0,
        (total, training) => total + training.distanciaTotalM() / 1000.0,
      );
      final weeklyLoad = weekTrainings.fold<double>(
        0,
        (total, training) =>
            total + (training.loadScore ?? _fallbackLoad(training)),
      );
      final rpeValues = weekTrainings
          .map((training) => training.series.isEmpty ? null : training.rpePromedio())
          .whereType<double>()
          .toList();

      return <String, dynamic>{
        'weekStart': weekStart.toIso8601String(),
        'weekEnd': weekEnd.toIso8601String(),
        'plannedSessions': planned,
        'completedSessions': completed,
        'daysTrained': weekTrainings.length,
        'weeklyKm': double.parse(weeklyKm.toStringAsFixed(2)),
        'weeklyLoad': double.parse(weeklyLoad.toStringAsFixed(2)),
        'weeklyRpeAverage': rpeValues.isEmpty
            ? 0.0
            : double.parse(
                (rpeValues.reduce((a, b) => a + b) / rpeValues.length)
                    .toStringAsFixed(2),
              ),
      };
    });
  }

  int _calculateLongestRecentBreakDays({
    required DateTime now,
    required List<Entrenamiento> trainings,
    int lookbackDays = 84,
  }) {
    final today = DateTime(now.year, now.month, now.day);
    final trainedDays = trainings
        .map((training) => DateTime(
              training.fecha.year,
              training.fecha.month,
              training.fecha.day,
            ))
        .where((day) => !day.isBefore(today.subtract(Duration(days: lookbackDays))))
        .toSet()
        .toList()
      ..sort();

    if (trainedDays.isEmpty) return lookbackDays;

    var longestGap = 0;
    var previousDay = today.subtract(Duration(days: lookbackDays));
    for (final day in trainedDays) {
      final gap = day.difference(previousDay).inDays - 1;
      if (gap > longestGap) longestGap = gap;
      previousDay = day;
    }
    final tailGap = today.difference(previousDay).inDays;
    if (tailGap > longestGap) longestGap = tailGap;
    return longestGap;
  }

  Map<String, dynamic> _buildAthleteStyleSignals(
    List<Entrenamiento> trainings,
  ) {
    if (trainings.isEmpty) {
      return const <String, dynamic>{
        'recentTrainingStyle': 'unknown',
        'complexityLevel': 'basic',
        'prefersStructuredWorkouts': false,
        'intervalSessionRatio': 0.0,
        'continuousSessionRatio': 1.0,
        'averageSeriesPerWorkout': 0.0,
        'averageWorkoutDurationMinutes': 0.0,
        'averageWorkoutDistanceKm': 0.0,
        'commonWorkoutCategories': <String>[],
        'typicalTrainingWeekdays': <int>[],
      };
    }

    var intervalCount = 0;
    var continuousCount = 0;
    var totalSeries = 0;
    double totalMinutes = 0;
    double totalKm = 0;
    final categoryCounts = <String, int>{};
    final weekdayCounts = <int, int>{};

    for (final training in trainings) {
      final inferredCategory = _inferCategory(training);
      categoryCounts.update(
        inferredCategory,
        (value) => value + 1,
        ifAbsent: () => 1,
      );
      weekdayCounts.update(
        training.fecha.weekday,
        (value) => value + 1,
        ifAbsent: () => 1,
      );

      final seriesCount = training.series.length;
      totalSeries += seriesCount;
      totalMinutes += training.tiempoTotalSec() / 60.0;
      totalKm += training.distanciaTotalM() / 1000.0;

      if (_isIntervalCategory(inferredCategory) || seriesCount >= 3) {
        intervalCount += 1;
      } else {
        continuousCount += 1;
      }
    }

    final totalTrainings = trainings.length;
    final intervalRatio = intervalCount / totalTrainings;
    final continuousRatio = continuousCount / totalTrainings;
    final averageSeries = totalSeries / totalTrainings;
    final averageMinutes = totalMinutes / totalTrainings;
    final averageKm = totalKm / totalTrainings;

    final recentTrainingStyle = intervalRatio >= 0.6
        ? 'interval_dominant'
        : continuousRatio >= 0.6
            ? 'continuous_dominant'
            : 'mixed';

    final complexityLevel = averageSeries >= 5 || intervalRatio >= 0.55
        ? 'advanced'
        : averageSeries >= 2 || intervalRatio >= 0.3
            ? 'moderate'
            : 'basic';

    final commonWorkoutCategories = categoryCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final typicalWeekdays = weekdayCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return <String, dynamic>{
      'recentTrainingStyle': recentTrainingStyle,
      'complexityLevel': complexityLevel,
      'prefersStructuredWorkouts': intervalRatio >= 0.4 || averageSeries >= 3,
      'intervalSessionRatio': double.parse(intervalRatio.toStringAsFixed(2)),
      'continuousSessionRatio':
          double.parse(continuousRatio.toStringAsFixed(2)),
      'averageSeriesPerWorkout': double.parse(averageSeries.toStringAsFixed(2)),
      'averageWorkoutDurationMinutes':
          double.parse(averageMinutes.toStringAsFixed(1)),
      'averageWorkoutDistanceKm': double.parse(averageKm.toStringAsFixed(2)),
      'commonWorkoutCategories':
          commonWorkoutCategories.take(4).map((e) => e.key).toList(),
      'typicalTrainingWeekdays':
          typicalWeekdays.take(4).map((e) => e.key).toList(),
    };
  }

  bool _isIntervalCategory(String category) {
    return category == 'series_cortas' ||
        category == 'series_largas' ||
        category == 'series_cuestas' ||
        category == 'tempo' ||
        category == 'fartlek';
  }

  String _inferCategory(Entrenamiento training) {
    final totalDistance = training.distanciaTotalM();
    final seriesCount = training.series.length;
    if (seriesCount == 0) return 'rodaje_base';
    if (seriesCount == 1 && totalDistance >= 8000) return 'rodaje_base';
    if (seriesCount >= 6 && totalDistance / seriesCount <= 500) {
      return 'series_cortas';
    }
    if (seriesCount >= 3 && totalDistance / seriesCount >= 800) {
      return 'series_largas';
    }
    if (training.rpePromedio() >= 7.5) return 'tempo';
    return 'rodaje_base';
  }

  DateTime _mondayOf(DateTime value) {
    final date = DateTime(value.year, value.month, value.day);
    return date.subtract(Duration(days: date.weekday - 1));
  }

  String _dateKey(DateTime value) {
    return '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
  }
}
