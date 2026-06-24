import 'dart:math' as math;

import 'package:running_laps/features/ai_coach/data/ai_coach_models.dart';
import 'package:running_laps/features/ai_coach/data/vdot_calculator.dart';
import 'package:running_laps/features/athlete/data/athlete_session_model.dart';

class AiCoachSessionGenerator {
  const AiCoachSessionGenerator();

  int _roundRunDistance(int distanceM) {
    if (distanceM <= 500) return 500;
    return ((distanceM / 500).round() * 500);
  }

  int _roundSeriesDistance(int distanceM) {
    if (distanceM <= 50) return 50;
    return ((distanceM / 50).round() * 50);
  }

  List<AthleteSession> generateWeekSessions({
    required String uid,
    required DateTime weekStart,
    required AiCoachWeeklyDecision decision,
    AiCoachProfile? profile,
    Set<int> occupiedWeekdays = const <int>{},
    int? maxSessions,
  }) {
    final now = DateTime.now();
    final cycleId = '${weekStart.year}${weekStart.month.toString().padLeft(2, '0')}${weekStart.day.toString().padLeft(2, '0')}';
    final availableDays = _resolveAvailableDays(profile, decision);
    final freeAvailableSlots = availableDays
        .where((day) => !occupiedWeekdays.contains(day))
        .length;
    final normalizedMaxSessions = math.max(
      0,
      math.min(
        math.min(
          maxSessions ?? decision.targetSessions,
          decision.workoutTargets.length,
        ),
        freeAvailableSlots,
      ),
    );
    final assignedDates = _assignDates(
      weekStart: weekStart,
      availableDays: availableDays,
      occupiedDays: occupiedWeekdays,
      targets: decision.workoutTargets,
      maxTargets: normalizedMaxSessions,
      profile: profile,
    );

    final sessions = <AthleteSession>[];
    for (var i = 0; i < assignedDates.length; i++) {
      final target = assignedDates[i].target;
      final date = assignedDates[i].date;
      final category = _normalizeCategory(target.category);
      final suggestion = AthleteSessionSuggestion(
        origin: AthleteSessionOrigin.ai,
        status: AthleteSessionSuggestionStatus.accepted,
        decisionId: decision.id,
        cycleId: cycleId,
        rationale: decision.analysis,
        focus: decision.primaryFocus,
        estimatedLoad: target.targetLoad ?? decision.targetLoad / decision.targetSessions,
        sourceModel: decision.sourceModel,
        generatedAt: decision.generatedAt,
      );

      sessions.add(
        AthleteSession(
          id: 'ai_${decision.id}_$i',
          uid: uid,
          date: _dateKey(date),
          time: _defaultTimeForCategory(category),
          category: category,
          status: AthleteSessionStatus.planned,
          warmup: _buildWarmup(category),
          blocks: _buildBlocks(
            category: category,
            target: target,
            decision: decision,
            profile: profile,
            sessionIndex: i,
          ),
          cooldown: _buildCooldown(category),
          planningNotes: _buildPlanningNotes(
            decision: decision,
            target: target,
            profile: profile,
          ),
          suggestion: suggestion,
          createdAt: now,
          updatedAt: now,
        ),
      );
    }

    return sessions;
  }

  List<int> _resolveAvailableDays(
    AiCoachProfile? profile,
    AiCoachWeeklyDecision decision,
  ) {
    final profileDays = (profile?.availableWeekdays ?? const <int>[])
        .where((day) => day >= 1 && day <= 7)
        .toSet()
        .toList();
    if (profileDays.isNotEmpty) {
      final sorted = [...profileDays]..sort();
      return sorted;
    }
    switch (decision.targetSessions) {
      case 1:
        return const [6];
      case 2:
        return const [2, 6];
      case 3:
        return const [1, 3, 6];
      case 4:
        return const [1, 3, 5, 6];
      default:
        return const [1, 2, 4, 6, 7];
    }
  }

  List<_AssignedTarget> _assignDates({
    required DateTime weekStart,
    required List<int> availableDays,
    required Set<int> occupiedDays,
    required List<AiCoachWorkoutTarget> targets,
    required int maxTargets,
    required AiCoachProfile? profile,
  }) {
    final usedDays = {...occupiedDays};
    final assignments = <_AssignedTarget>[];
    final sortedTargets = [...targets]
      ..sort((a, b) {
        final placementCompare = _placementPriority(a).compareTo(
          _placementPriority(b),
        );
        if (placementCompare != 0) return placementCompare;
        return a.priority.compareTo(b.priority);
      });

    for (final target in sortedTargets) {
      if (assignments.length >= maxTargets) break;
      final preferred = _weekdayFromLabel(target.preferredDay);
      final isLongRunTarget = _isLongRunTarget(target);
      final day = _pickDay(
        availableDays: availableDays,
        preferredDay: preferred,
        usedDays: usedDays,
        category: _normalizeCategory(target.category),
        longRunDay: _resolvePreferredLongRunDay(
          target,
          profile: profile,
          isLongRunTarget: isLongRunTarget,
        ),
        isLongRunTarget: isLongRunTarget,
      );
      if (day == -1) continue;
      usedDays.add(day);
      assignments.add(
        _AssignedTarget(
          target: target,
          date: weekStart.add(Duration(days: day - 1)),
        ),
      );
    }
    assignments.sort((a, b) => a.date.compareTo(b.date));
    return assignments;
  }

  int _pickDay({
    required List<int> availableDays,
    required int? preferredDay,
    required Set<int> usedDays,
    required String category,
    required bool isLongRunTarget,
    int? longRunDay,
  }) {
    final openDays = availableDays.where((day) => !usedDays.contains(day)).toList()
      ..sort();
    if (openDays.isEmpty) return -1;

    if (preferredDay != null &&
        availableDays.contains(preferredDay) &&
        !usedDays.contains(preferredDay)) {
      return preferredDay;
    }

    if (isLongRunTarget &&
        longRunDay != null &&
        availableDays.contains(longRunDay) &&
        !usedDays.contains(longRunDay)) {
      return longRunDay;
    }

    if (isLongRunTarget) {
      final weekend = openDays.where((day) => day >= 6).toList();
      if (weekend.isNotEmpty) return weekend.last;
      return openDays.last;
    }

    if (_isQualityCategory(category)) {
      return _pickBestQualityDay(openDays, usedDays);
    }

    if (usedDays.isEmpty) return openDays.first;

    return openDays.reduce((best, day) {
      final distBest = usedDays
          .map((d) => (d - best).abs())
          .reduce(math.min);
      final distDay = usedDays
          .map((d) => (d - day).abs())
          .reduce(math.min);
      return distDay > distBest ? day : best;
    });
  }

  int? _resolvePreferredLongRunDay(
    AiCoachWorkoutTarget target, {
    required AiCoachProfile? profile,
    required bool isLongRunTarget,
  }) {
    if (!isLongRunTarget) return null;
    return profile?.preferredLongRunWeekday;
  }

  int _placementPriority(AiCoachWorkoutTarget target) {
    if (_isLongRunTarget(target)) return 2;
    final category = _normalizeCategory(target.category);
    if (_isQualityCategory(category)) return 1;
    return 3;
  }

  bool _isLongRunTarget(AiCoachWorkoutTarget target) {
    final category = _normalizeCategory(target.category);
    if (category == 'competicion') return true;
    final purpose = target.purpose.toLowerCase();
    final notes = (target.notes ?? '').toLowerCase();
    final mentionsLongRun = purpose.contains('tirada') ||
        purpose.contains('larga') ||
        purpose.contains('long run') ||
        notes.contains('tirada') ||
        notes.contains('larga') ||
        notes.contains('long run');
    final durationSuggestsLongRun =
        (target.targetDurationMinutes ?? 0) >= 60;
    final distanceSuggestsLongRun = (target.targetDistanceKm ?? 0) >= 10;
    return category == 'rodaje_base' &&
        (mentionsLongRun || durationSuggestsLongRun || distanceSuggestsLongRun);
  }

  int _pickBestQualityDay(List<int> openDays, Set<int> usedDays) {
    if (openDays.length == 1) return openDays.first;
    if (usedDays.isEmpty) {
      return openDays[openDays.length ~/ 2];
    }
    var bestDay = openDays.first;
    var bestScore = -1;
    for (final day in openDays) {
      final minDistance = usedDays
          .map((used) => (used - day).abs())
          .reduce(math.min);
      if (minDistance > bestScore) {
        bestScore = minDistance;
        bestDay = day;
      }
    }
    return bestDay;
  }

  SessionWarmupCooldown? _buildWarmup(String category) {
    if (category == 'gimnasio_fuerza') return null;
    if (_isQualityCategory(category)) {
      return const SessionWarmupCooldown(
        description: 'Movilidad + trote suave + progresivos',
        durationMinutes: 15,
      );
    }
    return const SessionWarmupCooldown(
      description: 'Trote suave',
      durationMinutes: 10,
    );
  }

  SessionWarmupCooldown? _buildCooldown(String category) {
    if (category == 'gimnasio_fuerza') return null;
    if (_isQualityCategory(category)) {
      return const SessionWarmupCooldown(
        description: 'Trote suave + respiración',
        durationMinutes: 10,
      );
    }
    return const SessionWarmupCooldown(
      description: 'Soltar suave',
      durationMinutes: 5,
    );
  }

  List<SessionBlock> _buildBlocks({
    required String category,
    required AiCoachWorkoutTarget target,
    required AiCoachWeeklyDecision decision,
    required AiCoachProfile? profile,
    required int sessionIndex,
  }) {
    final complexityTier = _complexityTier(
      profile: profile,
      weekType: decision.weekType,
    );
    final targetMinutes = target.targetDurationMinutes ??
        _defaultDurationFor(category, decision: decision, target: target);
    final targetKm = target.targetDistanceKm ??
        _defaultDistanceFor(category, minutes: targetMinutes);
    final targetLoad =
        target.targetLoad ?? decision.targetLoad / math.max(1, decision.targetSessions);
    final rpe = _defaultRpeFor(category, decision.adjustment);
    final zone = _defaultZoneFor(category);

    // Paces personalizados si el perfil tiene marcas disponibles
    final vdot = profile != null
        ? VdotCalculator.bestVdotFromProfile(profile)
        : null;
    final paces = vdot != null ? VdotCalculator.pacesFromVdot(vdot) : null;

    int pMin(int secPerKm) => secPerKm ~/ 60;
    int pSec(int secPerKm) => secPerKm % 60;

    // FC objetivo por zona basada en fcMax del perfil
    // Límites: Z1 0-60%, Z2 60-70%, Z3 70-80%, Z4 80-90%, Z5 90%+
    // Punto medio de cada zona como target bpm
    final profileFcMax = profile?.fcMax;
    int? fcForZone(int targetZone) {
      if (profileFcMax == null) return null;
      switch (targetZone) {
        case 1: return (profileFcMax * 0.52).round();
        case 2: return (profileFcMax * 0.65).round();
        case 3: return (profileFcMax * 0.75).round();
        case 4: return (profileFcMax * 0.85).round();
        case 5: return (profileFcMax * 0.95).round();
        default: return null;
      }
    }

    // Guard lesión/recuperación: redirige sesiones intensas a rodaje suave
    final isRecoveryAdjustment =
        decision.adjustment == AiCoachAdjustmentType.recover ||
        decision.adjustment == AiCoachAdjustmentType.reduce;
    final isInjuryContext = decision.restrictions.any((r) {
      final l = r.toLowerCase();
      return l.contains('lesion') ||
          l.contains('lesión') ||
          l.contains('dolor') ||
          l.contains('molestia');
    });

    if ((isInjuryContext || isRecoveryAdjustment) &&
        _isQualityCategory(category)) {
      return _buildBaseRunBlocks(
        sessionIndex: sessionIndex,
        targetKm: math.min(targetKm, 6.0),
        targetMinutes: math.min(targetMinutes, 40),
        rpe: math.min(rpe, 5.5),
        zone: 2,
        fcBpm: fcForZone(2),
        notes: isInjuryContext
            ? 'Rodaje suave por precaución. '
              'Escucha tu cuerpo — para si hay molestias.'
            : 'Rodaje de recuperación activa. '
              'Mantén el esfuerzo bajo (Z2 máx).',
      );
    }

    final effectiveRpe = isRecoveryAdjustment ? math.min(rpe, 6.0) : rpe;
    final effectiveZone = isRecoveryAdjustment ? math.min(zone, 3) : zone;

    switch (category) {
      case 'series_cortas':
        final repDistance =
            target.targetSegmentDistanceM ??
            (complexityTier >= 2 ? 500 : 400);
        final reps = (target.targetReps ??
                (targetKm * 1000 / repDistance).round())
            .clamp(4, 12);
        return _buildRepeatedSeriesBlocks(
          sessionIndex: sessionIndex,
          reps: math.max(4, reps),
          distanceM: repDistance,
          restSeconds: complexityTier <= 1 ? 70 : 55,
          rpe: effectiveRpe,
          zone: effectiveZone,
          fcBpm: fcForZone(effectiveZone),
          paceMinMin: paces != null ? pMin(paces.z5MinSecPerKm) : 4,
          paceMinSec: paces != null ? pSec(paces.z5MinSecPerKm) : 10,
          paceMaxMin: paces != null ? pMin(paces.z5MaxSecPerKm) : 4,
          paceMaxSec: paces != null ? pSec(paces.z5MaxSecPerKm) : 45,
          notes: target.notes,
        );
      case 'series_largas':
        final repDistance =
            target.targetSegmentDistanceM ??
            (complexityTier >= 2 ? 1200 : 1000);
        final reps = (target.targetReps ??
                (targetKm * 1000 / repDistance).round())
            .clamp(3, 8);
        return _buildRepeatedSeriesBlocks(
          sessionIndex: sessionIndex,
          reps: math.max(3, reps),
          distanceM: repDistance,
          restSeconds: complexityTier == 0 ? 105 : 85,
          rpe: effectiveRpe,
          zone: effectiveZone,
          fcBpm: fcForZone(effectiveZone),
          paceMinMin: paces != null ? pMin(paces.z4MinSecPerKm) : 4,
          paceMinSec: paces != null ? pSec(paces.z4MinSecPerKm) : 35,
          paceMaxMin: paces != null ? pMin(paces.z4MaxSecPerKm) : 5,
          paceMaxSec: paces != null ? pSec(paces.z4MaxSecPerKm) : 10,
          notes: target.notes,
        );
      case 'series_cuestas':
        final hillReps =
            target.targetReps ??
            (complexityTier == 0 ? 6 : complexityTier == 1 ? 8 : 10);
        final hillDist =
            target.targetSegmentDistanceM ??
            (complexityTier == 0 ? 150 : complexityTier == 1 ? 200 : 250);
        final hillRest = complexityTier == 0 ? 90 : complexityTier == 1 ? 75 : 60;
        return _buildRepeatedSeriesBlocks(
          sessionIndex: sessionIndex,
          reps: hillReps,
          distanceM: hillDist,
          roundDistance: false,
          restSeconds: hillRest,
          rpe: math.min(8.5, effectiveRpe + 0.5),
          zone: 4,
          fcBpm: fcForZone(4),
          // Sin pace en cuestas — el ritmo depende del desnivel
          notes: target.notes ??
              'Cuesta constante, esfuerzo sostenido, '
              'técnica estable. Recupera trotando cuesta abajo.',
        );
      case 'series_mixtas':
        return _buildMixedSeriesBlocks(
          sessionIndex: sessionIndex,
          targetKm: targetKm,
          rpe: effectiveRpe,
          zone: 4,
          fcBpm: fcForZone(4),
          complexityTier: complexityTier,
          notes: target.notes,
        );
      case 'fartlek':
        return _buildFartlekBlocks(
          sessionIndex: sessionIndex,
          totalMinutes: math.max(20, targetMinutes),
          complexityTier: complexityTier,
          paces: paces,
          profileFcMax: profileFcMax,
          notes: target.notes,
        );
      case 'tempo':
        return _buildTempoBlocks(
          sessionIndex: sessionIndex,
          totalMinutes: math.max(20, targetMinutes),
          complexityTier: complexityTier,
          paces: paces,
          profileFcMax: profileFcMax,
          notes: target.notes,
        );
      case 'rodaje_base':
        if (complexityTier >= 2 && _shouldBuildProgressiveLongRun(
          target: target,
          targetMinutes: targetMinutes,
          targetKm: targetKm,
        )) {
          return _buildProgressiveLongRunBlocks(
            sessionIndex: sessionIndex,
            totalMinutes: math.max(50, targetMinutes),
            complexityTier: complexityTier,
            profileFcMax: profileFcMax,
            notes: target.notes,
          );
        }
        return _buildBaseRunBlocks(
          sessionIndex: sessionIndex,
          targetKm: targetKm,
          targetMinutes: targetMinutes,
          rpe: effectiveRpe,
          zone: effectiveZone,
          fcBpm: fcForZone(effectiveZone),
          notes: target.notes,
        );
      case 'regenerativo':
        return [
          SessionBlock(
            id: 'block_${sessionIndex}_1',
            order: 0,
            type: SessionBlockType.continuousTime,
            durationMinutes: math.max(25, targetMinutes),
            targetRpe: math.min(4.0, effectiveRpe),
            targetZone: 1,
            targetFcBpm: fcForZone(1),
            notes: target.notes ?? 'Muy suave, sensación de soltura',
          ),
        ];
      case 'gimnasio_fuerza':
        return [
          SessionBlock(
            id: 'block_${sessionIndex}_1',
            order: 0,
            type: SessionBlockType.continuousTime,
            durationMinutes: math.max(35, targetMinutes),
            targetRpe: 6,
            notes: target.notes ?? 'Fuerza general sin fatigar en exceso',
          ),
        ];
      case 'test':
        return _buildTestBlocks(
          sessionIndex: sessionIndex,
          targetKm: targetKm,
          profileFcMax: profileFcMax,
          notes: target.notes,
        );
      case 'evaluacion':
        return _buildBaseRunBlocks(
          sessionIndex: sessionIndex,
          targetKm: targetKm,
          targetMinutes: targetMinutes,
          rpe: effectiveRpe,
          zone: effectiveZone,
          fcBpm: fcForZone(effectiveZone),
          notes: target.notes ??
              'Rodaje de evaluación — corre por sensaciones '
              '(RPE ${effectiveRpe.toStringAsFixed(0)}), sin mirar el ritmo. '
              'El objetivo es conocer tu estado de forma actual.',
        );
      case 'rodaje_largo':
        if (complexityTier >= 2) {
          return _buildProgressiveLongRunBlocks(
            sessionIndex: sessionIndex,
            totalMinutes: math.max(50, targetMinutes),
            complexityTier: complexityTier,
            profileFcMax: profileFcMax,
            notes: target.notes,
          );
        }
        return _buildBaseRunBlocks(
          sessionIndex: sessionIndex,
          targetKm: targetKm,
          targetMinutes: math.max(50, targetMinutes),
          rpe: effectiveRpe,
          zone: effectiveZone,
          fcBpm: fcForZone(effectiveZone),
          notes: target.notes,
        );
      case 'series_medias':
        // Series medias: 800-1000m en Z4 (VO2max)
        // Entre velocidad pura (cortas) y umbral (largas)
        final repDistanceMed =
            target.targetSegmentDistanceM ??
            (complexityTier >= 2 ? 1000 : 800);
        final repsMed = math.max(
            4,
            target.targetReps ??
                (targetKm * 1000 / repDistanceMed).round());
        final restSecondsMed = complexityTier >= 2 ? 80 : 90;
        final paceMinSecMed = complexityTier >= 2 ? 10 : 25;
        final paceMaxSecMed = complexityTier >= 2 ? 45 : 55;
        return _buildRepeatedSeriesBlocks(
          sessionIndex: sessionIndex,
          reps: repsMed,
          distanceM: repDistanceMed,
          restSeconds: restSecondsMed,
          rpe: effectiveRpe,
          zone: effectiveZone,
          fcBpm: fcForZone(effectiveZone),
          paceMinMin: 4,
          paceMinSec: paceMinSecMed,
          paceMaxMin: 4,
          paceMaxSec: paceMaxSecMed,
          notes: target.notes ?? 'Series medias Z4 · VO2max',
        );
      default:
        return [
          SessionBlock(
            id: 'block_${sessionIndex}_1',
            order: 0,
            type: SessionBlockType.continuousDistance,
            distanceM: _roundRunDistance(
                math.max(5000, (targetKm * 1000).round())),
            targetRpe: effectiveRpe,
            targetZone: effectiveZone,
            targetFcBpm: fcForZone(effectiveZone),
            notes: '${target.notes ?? 'Rodaje controlado'} · carga estimada ${targetLoad.toStringAsFixed(0)}',
          ),
        ];
    }
  }

  bool _shouldBuildProgressiveLongRun({
    required AiCoachWorkoutTarget target,
    required int targetMinutes,
    required double targetKm,
  }) {
    final purpose = target.purpose.toLowerCase();
    final notes = (target.notes ?? '').toLowerCase();
    if (purpose.contains('tirada') ||
        purpose.contains('long run') ||
        notes.contains('tirada') ||
        notes.contains('long run')) {
      return true;
    }
    return targetMinutes >= 55 || targetKm >= 9.5;
  }

  List<SessionBlock> _buildBaseRunBlocks({
    required int sessionIndex,
    required double targetKm,
    required int targetMinutes,
    required double rpe,
    required int zone,
    int? fcBpm,
    String? notes,
  }) {
    return [
      SessionBlock(
        id: 'block_${sessionIndex}_1',
        order: 0,
        type: targetMinutes >= 42
            ? SessionBlockType.continuousTime
            : SessionBlockType.continuousDistance,
        durationMinutes: targetMinutes >= 42 ? targetMinutes : null,
        distanceM: targetMinutes < 42
            ? _roundRunDistance(
                math.max(5000, (targetKm * 1000).round()))
            : null,
        targetRpe: rpe,
        targetZone: zone,
        targetFcBpm: fcBpm,
        notes: notes ?? 'Rodaje controlado',
      ),
    ];
  }

  List<SessionBlock> _buildProgressiveLongRunBlocks({
    required int sessionIndex,
    required int totalMinutes,
    required int complexityTier,
    int? profileFcMax,
    String? notes,
  }) {
    int? fcZ(int z) {
      if (profileFcMax == null) return null;
      switch (z) {
        case 1: return (profileFcMax * 0.52).round();
        case 2: return (profileFcMax * 0.65).round();
        case 3: return (profileFcMax * 0.75).round();
        default: return null;
      }
    }

    final baseA = complexityTier >= 2 ? 0.45 : 0.55;
    final baseB = complexityTier >= 2 ? 0.35 : 0.30;
    final blockA = (totalMinutes * baseA).round();
    final blockB = (totalMinutes * baseB).round();
    final blockC = math.max(complexityTier >= 2 ? 10 : 8, totalMinutes - blockA - blockB);
    final finalZone = complexityTier >= 2 ? 3 : 2;
    return [
      SessionBlock(
        id: 'block_${sessionIndex}_1',
        order: 0,
        type: SessionBlockType.continuousTime,
        durationMinutes: blockA,
        targetRpe: 5.0,
        targetZone: 2,
        targetFcBpm: fcZ(2),
        notes: notes ?? 'Inicio cómodo, respiración controlada',
      ),
      SessionBlock(
        id: 'block_${sessionIndex}_2',
        order: 1,
        type: SessionBlockType.continuousTime,
        durationMinutes: blockB,
        targetRpe: 5.8,
        targetZone: 2,
        targetFcBpm: fcZ(2),
        notes: 'Parte media sostenida',
      ),
      SessionBlock(
        id: 'block_${sessionIndex}_3',
        order: 2,
        type: SessionBlockType.continuousTime,
        durationMinutes: blockC,
        targetRpe: 6.4,
        targetZone: finalZone,
        targetFcBpm: fcZ(finalZone),
        notes: complexityTier >= 2
            ? 'Final progresivo en ritmo controlado de umbral bajo'
            : 'Final progresivo sin entrar en fatiga excesiva',
      ),
    ];
  }

  String _buildPlanningNotes({
    required AiCoachWeeklyDecision decision,
    required AiCoachWorkoutTarget target,
    required AiCoachProfile? profile,
  }) {
    final buffer = StringBuffer();
    buffer.write(target.purpose);
    if (decision.primaryFocus.trim().isNotEmpty) {
      buffer.write(' · foco: ${decision.primaryFocus}');
    }
    if (target.notes != null && target.notes!.trim().isNotEmpty) {
      buffer.write(' · ${target.notes!.trim()}');
    }
    final activeStatuses = profile?.temporaryStatuses.where((item) => item.active).toList() ?? const [];
    if (activeStatuses.isNotEmpty) {
      buffer.write(' · contexto: ${activeStatuses.map((item) => item.message).join(' | ')}');
    }
    return buffer.toString();
  }

  String _normalizeCategory(String rawCategory) {
    switch (rawCategory.trim().toLowerCase()) {
      case 'easy':
      case 'easy_run':
      case 'base':
      case 'rodaje':
      case 'rodaje_base':
        return 'rodaje_base';
      case 'long_run':
      case 'rodaje_largo':
      case 'tirada_larga':
        return 'rodaje_largo';
      case 'recovery':
      case 'recuperacion':
      case 'recuperación':
      case 'regenerativo':
        return 'regenerativo';
      case 'tempo':
      case 'threshold':
      case 'umbral':
        return 'tempo';
      case 'fartlek':
        return 'fartlek';
      case 'short_intervals':
      case 'speed':
      case 'velocidad':
      case 'series_cortas':
        return 'series_cortas';
      case 'long_intervals':
      case 'series':
      case 'intervals':
      case 'series_largas':
        return 'series_largas';
      case 'series_medias':
        return 'series_medias';
      case 'hills':
      case 'hill':
      case 'cuestas':
      case 'series_hills':
      case 'series_cuestas':
        return 'series_cuestas';
      case 'mixed_intervals':
      case 'series_mixtas':
        return 'series_mixtas';
      case 'strength':
      case 'strength_training':
      case 'gym_strength':
      case 'gym':
      case 'fuerza':
      case 'gimnasio':
      case 'gimnasio_fuerza':
        return 'gimnasio_fuerza';
      case 'test':
        return 'test';
      case 'evaluacion':
      case 'evaluation':
      case 'baseline':
        return 'evaluacion';
      case 'race':
      case 'competicion':
        return 'competicion';
      default:
        return 'rodaje_base';
    }
  }

  List<SessionBlock> _buildRepeatedSeriesBlocks({
    required int sessionIndex,
    required int reps,
    required int distanceM,
    required int restSeconds,
    required double rpe,
    required int zone,
    int? fcBpm,
    bool roundDistance = true,
    int? paceMinMin,
    int? paceMinSec,
    int? paceMaxMin,
    int? paceMaxSec,
    String? notes,
  }) {
    final finalDistance =
        roundDistance ? _roundSeriesDistance(distanceM) : distanceM;
    return [
      SessionBlock(
        id: 'block_${sessionIndex}_1',
        order: 0,
        type: SessionBlockType.series,
        reps: reps,
        distanceM: finalDistance,
        restSeconds: restSeconds,
        targetRpe: rpe,
        targetZone: zone,
        targetFcBpm: fcBpm,
        targetPaceMinMin: paceMinMin,
        targetPaceMinSec: paceMinSec,
        targetPaceMaxMin: paceMaxMin,
        targetPaceMaxSec: paceMaxSec,
        notes: notes,
      ),
    ];
  }

  List<SessionBlock> _buildMixedSeriesBlocks({
    required int sessionIndex,
    required double targetKm,
    required double rpe,
    required int zone,
    int? fcBpm,
    required int complexityTier,
    String? notes,
  }) {
    final distances = complexityTier >= 2
        ? (targetKm >= 6.5
            ? const <int>[1400, 1200, 1000, 800, 600]
            : const <int>[1200, 1000, 800, 600, 400])
        : (targetKm >= 6.5
            ? const <int>[1200, 1000, 800, 600]
            : const <int>[1000, 800, 600, 400]);
    return List.generate(distances.length, (index) {
      final distance = distances[index];
      return SessionBlock(
        id: 'block_${sessionIndex}_${index + 1}',
        order: index,
        type: SessionBlockType.series,
        reps: 1,
        distanceM: distance,
        restSeconds: index == distances.length - 1 ? 0 : (complexityTier >= 2 ? 75 : 90),
        targetRpe: math.min(8.3, rpe + (index * 0.1)),
        targetZone: zone,
        targetFcBpm: fcBpm,
        targetPaceMinMin: 4,
        targetPaceMinSec: 20,
        targetPaceMaxMin: 5,
        targetPaceMaxSec: 5,
        notes: index == 0
            ? (notes ?? 'Bloques decrecientes con control técnico')
            : null,
      );
    });
  }

  List<SessionBlock> _buildFartlekBlocks({
    required int sessionIndex,
    required int totalMinutes,
    required int complexityTier,
    TrainingPaces? paces,
    int? profileFcMax,
    String? notes,
  }) {
    int? fcZ(int z) {
      if (profileFcMax == null) return null;
      switch (z) {
        case 1: return (profileFcMax * 0.52).round();
        case 3: return (profileFcMax * 0.75).round();
        default: return null;
      }
    }

    final workMinutes = complexityTier >= 2 ? 4 : (totalMinutes >= 40 ? 4 : 3);
    final reps = complexityTier >= 2 ? 6 : (totalMinutes >= 40 ? 5 : 4);
    final recoveryMinutes = (workMinutes / 2).ceil(); // 2 min típicamente

    final blocks = <SessionBlock>[];
    var blockOrder = 0;

    for (var i = 0; i < reps; i++) {
      // Bloque de esfuerzo (Z3)
      blocks.add(
        SessionBlock(
          id: 'block_${sessionIndex}_${blockOrder + 1}',
          order: blockOrder,
          type: SessionBlockType.continuousTime,
          durationMinutes: workMinutes,
          targetRpe: complexityTier >= 2 ? 7.2 : 7.0,
          targetZone: 3,
          targetFcBpm: fcZ(3),
          targetPaceMinMin: paces != null ? paces.z3MinSecPerKm ~/ 60 : null,
          targetPaceMinSec: paces != null ? paces.z3MinSecPerKm % 60 : null,
          targetPaceMaxMin: paces != null ? paces.z3MaxSecPerKm ~/ 60 : null,
          targetPaceMaxSec: paces != null ? paces.z3MaxSecPerKm % 60 : null,
          notes: i == 0 ? (notes ?? 'Esfuerzo controlado, Z3') : null,
        ),
      );
      blockOrder++;

      // Bloque de recuperación entre estímulos (Z1), no tras el último
      if (i < reps - 1) {
        blocks.add(
          SessionBlock(
            id: 'block_${sessionIndex}_${blockOrder + 1}',
            order: blockOrder,
            type: SessionBlockType.continuousTime,
            durationMinutes: recoveryMinutes,
            targetRpe: 4.0,
            targetZone: 1,
            targetFcBpm: fcZ(1),
            notes: i == 0 ? 'Trote suave de recuperación' : null,
          ),
        );
        blockOrder++;
      }
    }

    return blocks;
  }

  List<SessionBlock> _buildTempoBlocks({
    required int sessionIndex,
    required int totalMinutes,
    required int complexityTier,
    TrainingPaces? paces,
    int? profileFcMax,
    String? notes,
  }) {
    final fcZ3 = profileFcMax != null ? (profileFcMax * 0.75).round() : null;

    // Pace base Z3: personalizado si hay marcas, hardcoded si no
    final z3Min = paces?.z3MinSecPerKm;
    final z3Max = paces?.z3MaxSecPerKm;

    int? pMin(int? secPerKm) => secPerKm != null ? secPerKm ~/ 60 : null;
    int? pSec(int? secPerKm) => secPerKm != null ? secPerKm % 60 : null;

    if (complexityTier >= 2 && totalMinutes >= 34) {
      // Variante A: 3 bloques progresivos (82% → 88% → 91% de vVO2max aproximado)
      // Si no hay paces VDOT, los paces son ligeramente más duros que Z3 nominal
      final minA = z3Min != null ? (z3Min * 1.04).round() : null; // ~82%
      final maxA = z3Max;
      final minB = z3Min;
      final maxB = z3Max != null ? (z3Max * 0.97).round() : null;
      final minC = z3Min != null ? (z3Min * 0.96).round() : null;
      final maxC = z3Max != null ? (z3Max * 0.94).round() : null;

      return [
        SessionBlock(
          id: 'block_${sessionIndex}_1',
          order: 0,
          type: SessionBlockType.continuousTime,
          durationMinutes: 10,
          targetRpe: 6.8,
          targetZone: 3,
          targetFcBpm: fcZ3,
          targetPaceMinMin: pMin(minA) ?? 4,
          targetPaceMinSec: pSec(minA) ?? 55,
          targetPaceMaxMin: pMin(maxA) ?? 5,
          targetPaceMaxSec: pSec(maxA) ?? 20,
          notes: notes ?? 'Bloque 1 controlado',
        ),
        SessionBlock(
          id: 'block_${sessionIndex}_2',
          order: 1,
          type: SessionBlockType.continuousTime,
          durationMinutes: 8,
          targetRpe: 7.2,
          targetZone: 3,
          targetFcBpm: fcZ3,
          targetPaceMinMin: pMin(minB) ?? 4,
          targetPaceMinSec: pSec(minB) ?? 45,
          targetPaceMaxMin: pMin(maxB) ?? 5,
          targetPaceMaxSec: pSec(maxB) ?? 10,
          notes: 'Recuperación activa corta',
        ),
        SessionBlock(
          id: 'block_${sessionIndex}_3',
          order: 2,
          type: SessionBlockType.continuousTime,
          durationMinutes: 8,
          targetRpe: 7.4,
          targetZone: 3,
          targetFcBpm: fcZ3,
          targetPaceMinMin: pMin(minC) ?? 4,
          targetPaceMinSec: pSec(minC) ?? 40,
          targetPaceMaxMin: pMin(maxC) ?? 5,
          targetPaceMaxSec: pSec(maxC) ?? 5,
          notes: 'Cierre en control de umbral',
        ),
      ];
    }
    if (totalMinutes >= 32) {
      // Variante B: 2 bloques
      return [
        SessionBlock(
          id: 'block_${sessionIndex}_1',
          order: 0,
          type: SessionBlockType.continuousTime,
          durationMinutes: 12,
          targetRpe: 6.8,
          targetZone: 3,
          targetFcBpm: fcZ3,
          targetPaceMinMin: pMin(z3Min != null ? (z3Min * 1.02).round() : null) ?? 4,
          targetPaceMinSec: pSec(z3Min != null ? (z3Min * 1.02).round() : null) ?? 50,
          targetPaceMaxMin: pMin(z3Max) ?? 5,
          targetPaceMaxSec: pSec(z3Max) ?? 15,
          notes: notes ?? 'Primer bloque controlado',
        ),
        SessionBlock(
          id: 'block_${sessionIndex}_2',
          order: 1,
          type: SessionBlockType.continuousTime,
          durationMinutes: 10,
          targetRpe: 7.1,
          targetZone: 3,
          targetFcBpm: fcZ3,
          targetPaceMinMin: pMin(z3Min) ?? 4,
          targetPaceMinSec: pSec(z3Min) ?? 45,
          targetPaceMaxMin: pMin(z3Max != null ? (z3Max * 0.97).round() : null) ?? 5,
          targetPaceMaxSec: pSec(z3Max != null ? (z3Max * 0.97).round() : null) ?? 10,
          notes: 'Recupera trotando entre bloques',
        ),
      ];
    }
    // Variante C: 1 bloque continuo
    return [
      SessionBlock(
        id: 'block_${sessionIndex}_1',
        order: 0,
        type: SessionBlockType.continuousTime,
        durationMinutes: math.max(20, totalMinutes),
        targetRpe: 7,
        targetZone: 3,
        targetFcBpm: fcZ3,
        targetPaceMinMin: pMin(z3Min) ?? 4,
        targetPaceMinSec: pSec(z3Min) ?? 45,
        targetPaceMaxMin: pMin(z3Max) ?? 5,
        targetPaceMaxSec: pSec(z3Max) ?? 20,
        notes: notes ?? 'Ritmo estable, sin ir al limite',
      ),
    ];
  }

  List<SessionBlock> _buildTestBlocks({
    required int sessionIndex,
    required double targetKm,
    int? profileFcMax,
    String? notes,
  }) {
    final testDistance = targetKm >= 5 ? 5000 : 3000;
    final label = testDistance == 5000 ? '5K' : '3K';
    final fcZ3 = profileFcMax != null ? (profileFcMax * 0.75).round() : null;
    final fcZ4 = profileFcMax != null ? (profileFcMax * 0.85).round() : null;
    final fcZ1 = profileFcMax != null ? (profileFcMax * 0.52).round() : null;

    return [
      SessionBlock(
        id: 'block_${sessionIndex}_warmup_extra',
        order: 0,
        type: SessionBlockType.continuousTime,
        durationMinutes: 5,
        targetRpe: 6.5,
        targetZone: 3,
        targetFcBpm: fcZ3,
        notes: '2-3 progresivos de 100m para activar. '
            'Último minuto a ritmo de test.',
      ),
      SessionBlock(
        id: 'block_${sessionIndex}_test',
        order: 1,
        type: SessionBlockType.continuousDistance,
        distanceM: testDistance,
        targetRpe: 8.5,
        targetZone: 4,
        targetFcBpm: fcZ4,
        notes: notes ??
            'Test de $label — esfuerzo máximo sostenible y uniforme. '
            'No salgas demasiado rápido. '
            'Apunta el tiempo al terminar: '
            'es tu nueva marca de referencia para el plan.',
      ),
      SessionBlock(
        id: 'block_${sessionIndex}_cooldown_extra',
        order: 2,
        type: SessionBlockType.continuousTime,
        durationMinutes: 10,
        targetRpe: 3.0,
        targetZone: 1,
        targetFcBpm: fcZ1,
        notes: 'Trote muy suave. Tómate el tiempo para '
            'recuperarte bien después del test.',
      ),
    ];
  }

  int _defaultDurationFor(
    String category, {
    required AiCoachWeeklyDecision decision,
    required AiCoachWorkoutTarget target,
  }) {
    final base = switch (category) {
      'regenerativo' => 30,
      'rodaje_base' => 45,
      'tempo' => 35,
      'fartlek' => 40,
      'series_cortas' => 30,
      'series_largas' => 40,
      'series_cuestas' => 35,
      'series_mixtas' => 42,
      'gimnasio_fuerza' => 45,
      _ => 40,
    };
    if (decision.adjustment == AiCoachAdjustmentType.reduce ||
        decision.adjustment == AiCoachAdjustmentType.deload ||
        decision.adjustment == AiCoachAdjustmentType.recover) {
      return math.max(25, base - 10);
    }
    if (decision.adjustment == AiCoachAdjustmentType.progress) {
      return base + 5;
    }
    return base;
  }

  double _defaultDistanceFor(String category, {required int minutes}) {
    switch (category) {
      case 'series_cortas':
        return 4.8;
      case 'series_largas':
        return 6.0;
      case 'series_mixtas':
        return 6.5;
      case 'tempo':
        return 7.0;
      case 'regenerativo':
        return 5.0;
      case 'rodaje_base':
        return math.max(6.0, minutes / 6.0);
      default:
        return math.max(5.0, minutes / 6.2);
    }
  }

  double _defaultRpeFor(String category, AiCoachAdjustmentType adjustment) {
    final base = switch (category) {
      'regenerativo' => 3.5,
      'rodaje_base' => 5.0,
      'tempo' => 7.0,
      'fartlek' => 6.5,
      'series_cortas' => 7.5,
      'series_largas' => 7.0,
      'series_cuestas' => 7.5,
      'series_mixtas' => 7.4,
      'gimnasio_fuerza' => 6.0,
      _ => 5.5,
    };
    if (adjustment == AiCoachAdjustmentType.reduce ||
        adjustment == AiCoachAdjustmentType.deload ||
        adjustment == AiCoachAdjustmentType.recover) {
      return math.max(3.0, base - 1.0);
    }
    if (adjustment == AiCoachAdjustmentType.progress) {
      return math.min(8.5, base + 0.3);
    }
    return base;
  }

  int _complexityTier({
    required AiCoachProfile? profile,
    required AiCoachWeekType weekType,
  }) {
    final byLevel = switch (profile?.level) {
      AiCoachAthleteLevel.advanced => 2,
      AiCoachAthleteLevel.intermediate => 1,
      _ => 0,
    };
    final deltaByWeekType = switch (weekType) {
      AiCoachWeekType.build => 1,
      AiCoachWeekType.absorb => 0,
      AiCoachWeekType.recovery => -1,
      AiCoachWeekType.taper => -1,
      AiCoachWeekType.race => -1,
      AiCoachWeekType.restart => -1,
    };
    final tier = byLevel + deltaByWeekType;
    if (tier < 0) return 0;
    if (tier > 2) return 2;
    return tier;
  }

  int _defaultZoneFor(String category) {
    switch (category) {
      case 'regenerativo':
        return 1;
      case 'rodaje_base':
        return 2;
      case 'tempo':
        return 3;
      case 'fartlek':
        return 3;
      case 'series_cortas':
      case 'series_largas':
      case 'series_cuestas':
      case 'series_mixtas':
        return 4;
      default:
        return 2;
    }
  }

  String? _defaultTimeForCategory(String category) {
    if (_isLongRunCategory(category)) return '09:00';
    if (_isQualityCategory(category)) return '19:00';
    return '08:00';
  }

  bool _isQualityCategory(String category) {
    return category == 'tempo' ||
        category == 'fartlek' ||
        category == 'series_cortas' ||
        category == 'series_largas' ||
        category == 'series_cuestas' ||
        category == 'series_mixtas' ||
        category == 'test';
  }

  bool _isLongRunCategory(String category) {
    return category == 'competicion' || category == 'rodaje_base';
  }

  int? _weekdayFromLabel(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    switch (raw.trim().toLowerCase()) {
      case 'monday':
      case 'lunes':
        return 1;
      case 'tuesday':
      case 'martes':
        return 2;
      case 'wednesday':
      case 'miercoles':
      case 'miércoles':
        return 3;
      case 'thursday':
      case 'jueves':
        return 4;
      case 'friday':
      case 'viernes':
        return 5;
      case 'saturday':
      case 'sabado':
      case 'sábado':
        return 6;
      case 'sunday':
      case 'domingo':
        return 7;
      default:
        return null;
    }
  }

  String _dateKey(DateTime value) {
    return '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
  }
}

class _AssignedTarget {
  final AiCoachWorkoutTarget target;
  final DateTime date;

  const _AssignedTarget({
    required this.target,
    required this.date,
  });
}
