import 'dart:math' as math;

import 'package:running_laps/features/ai_coach/data/ai_coach_models.dart';
import 'package:running_laps/features/athlete/data/athlete_session_model.dart';

class AiCoachSessionGenerator {
  const AiCoachSessionGenerator();

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
        status: AthleteSessionSuggestionStatus.suggested,
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

    return openDays.first;
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

    switch (category) {
      case 'series_cortas':
        final repDistance = complexityTier >= 2 ? 500 : 400;
        final reps = math.max(6, (targetKm * 1000 / repDistance).round());
        return _buildRepeatedSeriesBlocks(
          sessionIndex: sessionIndex,
          reps: reps,
          distanceM: repDistance,
          restSeconds: complexityTier <= 1 ? 70 : 55,
          rpe: rpe,
          zone: zone,
          paceMinMin: 4,
          paceMinSec: 10,
          paceMaxMin: 4,
          paceMaxSec: 45,
          notes: target.notes,
        );
      case 'series_largas':
        final repDistance = complexityTier >= 2 ? 1200 : 1000;
        final reps = math.max(3, (targetKm * 1000 / repDistance).round());
        return _buildRepeatedSeriesBlocks(
          sessionIndex: sessionIndex,
          reps: reps,
          distanceM: repDistance,
          restSeconds: complexityTier == 0 ? 105 : 85,
          rpe: rpe,
          zone: zone,
          paceMinMin: 4,
          paceMinSec: 35,
          paceMaxMin: 5,
          paceMaxSec: 10,
          notes: target.notes,
        );
      case 'series_cuestas':
        return _buildRepeatedSeriesBlocks(
          sessionIndex: sessionIndex,
          reps: 10,
          distanceM: 200,
          restSeconds: 75,
          rpe: math.min(8.5, rpe + 0.5),
          zone: 4,
          notes: target.notes ?? 'Cuesta constante, técnica estable',
        );
      case 'series_mixtas':
        return _buildMixedSeriesBlocks(
          sessionIndex: sessionIndex,
          targetKm: targetKm,
          rpe: rpe,
          zone: 4,
          complexityTier: complexityTier,
          notes: target.notes,
        );
      case 'fartlek':
        return _buildFartlekBlocks(
          sessionIndex: sessionIndex,
          totalMinutes: math.max(20, targetMinutes),
          complexityTier: complexityTier,
          notes: target.notes,
        );
      case 'tempo':
        return _buildTempoBlocks(
          sessionIndex: sessionIndex,
          totalMinutes: math.max(20, targetMinutes),
          complexityTier: complexityTier,
          notes: target.notes,
        );
      case 'rodaje_base':
        if (_shouldBuildProgressiveLongRun(
          target: target,
          targetMinutes: targetMinutes,
          targetKm: targetKm,
        )) {
          return _buildProgressiveLongRunBlocks(
            sessionIndex: sessionIndex,
            totalMinutes: math.max(50, targetMinutes),
            complexityTier: complexityTier,
            notes: target.notes,
          );
        }
        return _buildBaseRunBlocks(
          sessionIndex: sessionIndex,
          targetKm: targetKm,
          targetMinutes: targetMinutes,
          rpe: rpe,
          zone: zone,
          notes: target.notes,
        );
      case 'regenerativo':
        return [
          SessionBlock(
            id: 'block_${sessionIndex}_1',
            order: 0,
            type: SessionBlockType.continuousTime,
            durationMinutes: math.max(25, targetMinutes),
            targetRpe: math.min(4.0, rpe),
            targetZone: 1,
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
          notes: target.notes,
        );
      default:
        return [
          SessionBlock(
            id: 'block_${sessionIndex}_1',
            order: 0,
            type: SessionBlockType.continuousDistance,
            distanceM: math.max(5000, (targetKm * 1000).round()),
            targetRpe: rpe,
            targetZone: zone,
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
    String? notes,
  }) {
    if (targetMinutes >= 42) {
      final firstPart = (targetMinutes * 0.7).round();
      final secondPart = math.max(10, targetMinutes - firstPart);
      return [
        SessionBlock(
          id: 'block_${sessionIndex}_1',
          order: 0,
          type: SessionBlockType.continuousTime,
          durationMinutes: firstPart,
          targetRpe: math.max(4.5, rpe - 0.4),
          targetZone: zone,
          notes: notes ?? 'Rodaje base estable y cómodo',
        ),
        SessionBlock(
          id: 'block_${sessionIndex}_2',
          order: 1,
          type: SessionBlockType.continuousTime,
          durationMinutes: secondPart,
          targetRpe: math.min(6.2, rpe + 0.5),
          targetZone: math.min(3, zone + 1),
          notes: 'Último bloque ligeramente progresivo',
        ),
      ];
    }
    return [
      SessionBlock(
        id: 'block_${sessionIndex}_1',
        order: 0,
        type: SessionBlockType.continuousDistance,
        distanceM: math.max(5000, (targetKm * 1000).round()),
        targetRpe: rpe,
        targetZone: zone,
        notes: notes ?? 'Rodaje controlado',
      ),
    ];
  }

  List<SessionBlock> _buildProgressiveLongRunBlocks({
    required int sessionIndex,
    required int totalMinutes,
    required int complexityTier,
    String? notes,
  }) {
    final baseA = complexityTier >= 2 ? 0.45 : 0.55;
    final baseB = complexityTier >= 2 ? 0.35 : 0.30;
    final blockA = (totalMinutes * baseA).round();
    final blockB = (totalMinutes * baseB).round();
    final blockC = math.max(complexityTier >= 2 ? 10 : 8, totalMinutes - blockA - blockB);
    return [
      SessionBlock(
        id: 'block_${sessionIndex}_1',
        order: 0,
        type: SessionBlockType.continuousTime,
        durationMinutes: blockA,
        targetRpe: 5.0,
        targetZone: 2,
        notes: notes ?? 'Inicio cómodo, respiración controlada',
      ),
      SessionBlock(
        id: 'block_${sessionIndex}_2',
        order: 1,
        type: SessionBlockType.continuousTime,
        durationMinutes: blockB,
        targetRpe: 5.8,
        targetZone: 2,
        notes: 'Parte media sostenida',
      ),
      SessionBlock(
        id: 'block_${sessionIndex}_3',
        order: 2,
        type: SessionBlockType.continuousTime,
        durationMinutes: blockC,
        targetRpe: 6.4,
        targetZone: complexityTier >= 2 ? 3 : 2,
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
      case 'long_run':
      case 'rodaje_largo':
      case 'rodaje':
      case 'rodaje_base':
        return 'rodaje_base';
      case 'recovery':
      case 'regenerativo':
        return 'regenerativo';
      case 'tempo':
      case 'threshold':
      case 'umbral':
        return 'tempo';
      case 'fartlek':
        return 'fartlek';
      case 'short_intervals':
      case 'series_cortas':
        return 'series_cortas';
      case 'long_intervals':
      case 'series_largas':
        return 'series_largas';
      case 'hills':
      case 'series_cuestas':
        return 'series_cuestas';
      case 'mixed_intervals':
      case 'series_mixtas':
        return 'series_mixtas';
      case 'strength':
      case 'strength_training':
      case 'gym_strength':
      case 'gym':
      case 'gimnasio_fuerza':
        return 'gimnasio_fuerza';
      case 'test':
        return 'test';
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
    int? paceMinMin,
    int? paceMinSec,
    int? paceMaxMin,
    int? paceMaxSec,
    String? notes,
  }) {
    return List.generate(reps, (index) {
      return SessionBlock(
        id: 'block_${sessionIndex}_${index + 1}',
        order: index,
        type: SessionBlockType.series,
        reps: 1,
        distanceM: distanceM,
        restSeconds: index == reps - 1 ? 0 : restSeconds,
        targetRpe: rpe,
        targetZone: zone,
        targetPaceMinMin: paceMinMin,
        targetPaceMinSec: paceMinSec,
        targetPaceMaxMin: paceMaxMin,
        targetPaceMaxSec: paceMaxSec,
        notes: index == 0 ? notes : null,
      );
    });
  }

  List<SessionBlock> _buildMixedSeriesBlocks({
    required int sessionIndex,
    required double targetKm,
    required double rpe,
    required int zone,
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
    String? notes,
  }) {
    final workMinutes = complexityTier >= 2 ? 4 : (totalMinutes >= 40 ? 4 : 3);
    final reps = complexityTier >= 2 ? 6 : (totalMinutes >= 40 ? 5 : 4);
    final blocks = <SessionBlock>[];
    for (var index = 0; index < reps; index++) {
      blocks.add(
        SessionBlock(
          id: 'block_${sessionIndex}_${index + 1}',
          order: index,
          type: SessionBlockType.continuousTime,
          durationMinutes: workMinutes,
          targetRpe: complexityTier >= 2 ? 7.2 : 7,
          targetZone: 3,
          notes: index == 0
              ? (notes ?? 'Cambio de ritmo sostenido, recupera trotando suave')
              : null,
        ),
      );
    }
    return blocks;
  }

  List<SessionBlock> _buildTempoBlocks({
    required int sessionIndex,
    required int totalMinutes,
    required int complexityTier,
    String? notes,
  }) {
    if (complexityTier >= 2 && totalMinutes >= 34) {
      return [
        SessionBlock(
          id: 'block_${sessionIndex}_1',
          order: 0,
          type: SessionBlockType.continuousTime,
          durationMinutes: 10,
          targetRpe: 6.8,
          targetZone: 3,
          targetPaceMinMin: 4,
          targetPaceMinSec: 55,
          targetPaceMaxMin: 5,
          targetPaceMaxSec: 20,
          notes: notes ?? 'Bloque 1 controlado',
        ),
        SessionBlock(
          id: 'block_${sessionIndex}_2',
          order: 1,
          type: SessionBlockType.continuousTime,
          durationMinutes: 8,
          targetRpe: 7.2,
          targetZone: 3,
          targetPaceMinMin: 4,
          targetPaceMinSec: 45,
          targetPaceMaxMin: 5,
          targetPaceMaxSec: 10,
          notes: 'Recuperación activa corta',
        ),
        SessionBlock(
          id: 'block_${sessionIndex}_3',
          order: 2,
          type: SessionBlockType.continuousTime,
          durationMinutes: 8,
          targetRpe: 7.4,
          targetZone: 3,
          targetPaceMinMin: 4,
          targetPaceMinSec: 40,
          targetPaceMaxMin: 5,
          targetPaceMaxSec: 5,
          notes: 'Cierre en control de umbral',
        ),
      ];
    }
    if (totalMinutes >= 32) {
      return [
        SessionBlock(
          id: 'block_${sessionIndex}_1',
          order: 0,
          type: SessionBlockType.continuousTime,
          durationMinutes: 12,
          targetRpe: 6.8,
          targetZone: 3,
          targetPaceMinMin: 4,
          targetPaceMinSec: 50,
          targetPaceMaxMin: 5,
          targetPaceMaxSec: 15,
          notes: notes ?? 'Primer bloque controlado',
        ),
        SessionBlock(
          id: 'block_${sessionIndex}_2',
          order: 1,
          type: SessionBlockType.continuousTime,
          durationMinutes: 10,
          targetRpe: 7.1,
          targetZone: 3,
          targetPaceMinMin: 4,
          targetPaceMinSec: 45,
          targetPaceMaxMin: 5,
          targetPaceMaxSec: 10,
          notes: 'Recupera trotando entre bloques',
        ),
      ];
    }
    return [
      SessionBlock(
        id: 'block_${sessionIndex}_1',
        order: 0,
        type: SessionBlockType.continuousTime,
        durationMinutes: math.max(20, totalMinutes),
        targetRpe: 7,
        targetZone: 3,
        targetPaceMinMin: 4,
        targetPaceMinSec: 45,
        targetPaceMaxMin: 5,
        targetPaceMaxSec: 20,
        notes: notes ?? 'Ritmo estable, sin ir al limite',
      ),
    ];
  }

  List<SessionBlock> _buildTestBlocks({
    required int sessionIndex,
    required double targetKm,
    String? notes,
  }) {
    final distance = targetKm >= 5 ? 5000 : 3000;
    return [
      SessionBlock(
        id: 'block_${sessionIndex}_1',
        order: 0,
        type: SessionBlockType.continuousDistance,
        distanceM: distance,
        targetRpe: 8.5,
        targetZone: 4,
        notes: notes ?? 'Test controlado para medir estado de forma',
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
