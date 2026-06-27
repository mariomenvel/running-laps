import 'package:running_laps/features/ai_coach/data/ai_coach_decision_service.dart';
import 'package:running_laps/features/ai_coach/data/ai_coach_context_builder.dart';
import 'package:running_laps/features/ai_coach/data/ai_coach_models.dart';
import 'package:running_laps/features/ai_coach/data/ai_coach_repository.dart';
import 'package:running_laps/features/ai_coach/data/ai_coach_session_generator.dart';
import 'package:running_laps/features/athlete/data/athlete_session_model.dart';
import 'package:running_laps/features/athlete/data/athlete_session_repository.dart';
import 'package:running_laps/core/services/user_service.dart';
import 'package:flutter/foundation.dart';

class AiCoachWeeklyPlannerResult {
  final AiCoachWeeklyDecision decision;
  final List<AthleteSession> sessions;

  const AiCoachWeeklyPlannerResult({
    required this.decision,
    required this.sessions,
  });
}

class AiCoachWeeklyPlannerService {
  AiCoachWeeklyPlannerService({
    AiCoachDecisionService? decisionService,
    AiCoachContextBuilder? contextBuilder,
    AiCoachRepository? aiCoachRepository,
    AthleteSessionRepository? sessionRepository,
    AiCoachSessionGenerator? sessionGenerator,
    UserService? userService,
  })  : _decisionService = decisionService ?? AiCoachDecisionService(),
        _contextBuilder = contextBuilder ?? AiCoachContextBuilder(),
        _aiCoachRepository = aiCoachRepository ?? AiCoachRepository(),
        _sessionRepository = sessionRepository ?? AthleteSessionRepository(),
        _sessionGenerator = sessionGenerator ?? const AiCoachSessionGenerator(),
        _userService = userService ?? UserService();

  final AiCoachDecisionService _decisionService;
  final AiCoachContextBuilder _contextBuilder;
  final AiCoachRepository _aiCoachRepository;
  final AthleteSessionRepository _sessionRepository;
  final AiCoachSessionGenerator _sessionGenerator;
  final UserService _userService;

  Future<AiCoachWeeklyPlannerResult> planNextWeek(
    String uid, {
    DateTime? referenceDate,
    DateTime? targetWeekStart,
    AiCoachWeeklyDecision? decisionOverride,
    bool forceRegenerate = false,
  }) async {
    final isAthleteMode = await _userService.getIsAthleteMode(uid);
    if (!isAthleteMode) {
      throw Exception(
        'El plan IA solo esta disponible con modo atleta activado.',
      );
    }

    final anchor = referenceDate ?? DateTime.now();
    var nextWeekStart =
        targetWeekStart != null ? _mondayOf(targetWeekStart) : _mondayOf(anchor).add(const Duration(days: 7));
    var nextWeekEnd = nextWeekStart.add(const Duration(days: 6));
    final today = DateTime.now();
    final minDate = DateTime(today.year, today.month, today.day);

    final profile = await _aiCoachRepository.getProfile(uid: uid);
    AiCoachWeeklyDecision rawDecision;
    bool fallbackUsed = false;
    try {
      rawDecision =
          decisionOverride ?? await _decisionService.generateWeeklyDecision(uid);
    } catch (e) {
      fallbackUsed = true;
      rawDecision = _buildFallbackDecision(
        profile: profile,
        weekStart: nextWeekStart,
      );
      await _aiCoachRepository.logEvent(
        uid: uid,
        eventType: 'weekly_planner_fallback_decision',
        payload: {
          'reason': e.toString(),
          'weekStart': _dateKey(nextWeekStart),
        },
      );
    }
    final context = await _contextBuilder.buildWeeklyContext(uid);
    final memory = _extractAthleteMemory(context.coachSignals);
    final adapted = _adaptDecisionWithAthleteMemory(rawDecision, memory);
    final aligned = _alignDecisionToProfile(
      adapted,
      profile,
      weekStart: nextWeekStart,
      minDate: minDate,
    );
    final diversified = _ensureTargetDiversity(aligned, profile, memory);
    final decision = _ensureMinimumTargetsFromProfile(
      diversified,
      profile,
      weekStart: nextWeekStart,
      minDate: minDate,
      memory: memory,
    );

    final existingBeforeCleanup = await _sessionRepository.getSessionsInRange(
      uid: uid,
      startDate: _dateKey(nextWeekStart),
      endDate: _dateKey(nextWeekEnd),
    );

    await _sessionRepository.deletePendingSuggestedSessionsInRange(
      uid: uid,
      startDate: _dateKey(nextWeekStart),
      endDate: _dateKey(nextWeekEnd),
    );

    final preservedSessions = forceRegenerate
        ? existingBeforeCleanup.where((s) =>
            s.suggestion == null ||
            s.suggestion!.origin != AthleteSessionOrigin.ai).toList()
        : existingBeforeCleanup.where((session) {
            final suggestion = session.suggestion;
            if (suggestion == null) return true;
            if (suggestion.origin != AthleteSessionOrigin.ai) return true;
            return suggestion.status == AthleteSessionSuggestionStatus.accepted ||
                suggestion.status == AthleteSessionSuggestionStatus.edited;
          }).toList();
    final occupiedWeekdays = preservedSessions
        .map((session) => DateTime.tryParse(session.date)?.weekday)
        .whereType<int>()
        .toSet();
    var feasibleWeekdays = _resolveFeasibleWeekdays(
      profile: profile,
      weekStart: nextWeekStart,
      minDate: minDate,
      fallbackTargetSessions: decision.targetSessions,
    );

    // Si no quedan días válidos esta semana, generar para la semana siguiente
    if (feasibleWeekdays.isEmpty) {
      debugPrint(
        '[AiCoachWeeklyPlanner] No quedan días esta semana → '
        'generando para la semana siguiente',
      );
      nextWeekStart = nextWeekStart.add(const Duration(days: 7));
      nextWeekEnd = nextWeekStart.add(const Duration(days: 6));
      final today = DateTime.now();
      feasibleWeekdays = _resolveFeasibleWeekdays(
        profile: profile,
        weekStart: nextWeekStart,
        minDate: DateTime(today.year, today.month, today.day),
        fallbackTargetSessions: decision.targetSessions,
      );
    }

    final freeFeasibleSlots = feasibleWeekdays
        .where((day) => !occupiedWeekdays.contains(day))
        .length;
    final remainingSlots =
        (decision.targetSessions - preservedSessions.length).clamp(0, freeFeasibleSlots);

    var sessions = _sessionGenerator.generateWeekSessions(
      uid: uid,
      weekStart: nextWeekStart,
      decision: decision,
      profile: profile,
      occupiedWeekdays: occupiedWeekdays,
      maxSessions: remainingSlots,
    );
    sessions = _enforceAvailableWeekdays(
      sessions: sessions,
      profile: profile,
      weekStart: nextWeekStart,
      minDate: minDate,
      occupiedWeekdays: occupiedWeekdays,
    );

    debugPrint(
      '[AiCoachWeeklyPlanner] uid=$uid targetSessions=${decision.targetSessions} '
      'available=${profile?.availableWeekdays} occupied=$occupiedWeekdays '
      'feasibleWeekdays=$feasibleWeekdays remainingSlots=$remainingSlots generated=${sessions.length}',
    );
    final gate = _runQualityGate(
      sessions: sessions,
      decision: decision,
      profile: profile,
    );
    if (!gate.isValid) {
      sessions = _applyQualityGateFixes(
        sessions: sessions,
        profile: profile,
      );
    }

    for (final session in sessions) {
      await _sessionRepository.createSession(session);
    }

    await _aiCoachRepository.logEvent(
      uid: uid,
      eventType: 'weekly_planner_generated',
      payload: {
        'weekStart': _dateKey(nextWeekStart),
        'weekEnd': _dateKey(nextWeekEnd),
        'fallbackUsed': fallbackUsed,
        'decisionId': decision.id,
        'targetSessions': decision.targetSessions,
        'generatedSessions': sessions.length,
        'memoryStyle': memory?.preferredStyle,
        'qualityGateValid': gate.isValid,
        'qualityGateIssues': gate.issues,
      },
    );
    final kpis = await _aiCoachRepository.rebuildKpis(uid: uid);
    await _aiCoachRepository.logEvent(
      uid: uid,
      eventType: 'ai_coach_kpi_snapshot',
      payload: {
        'acceptanceRate': kpis.acceptanceRate,
        'completionRate': kpis.completionRate,
        'replansCount': kpis.replansCount,
        'suggestedCount': kpis.suggestedCount,
      },
    );

    return AiCoachWeeklyPlannerResult(
      decision: decision,
      sessions: sessions,
    );
  }

  DateTime _mondayOf(DateTime value) {
    final date = DateTime(value.year, value.month, value.day);
    return date.subtract(Duration(days: date.weekday - 1));
  }

  String _dateKey(DateTime value) {
    return '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
  }

  AiCoachWeeklyDecision _buildFallbackDecision({
    required AiCoachProfile? profile,
    required DateTime weekStart,
  }) {
    final now = DateTime.now();
    final preferredSessions =
        (profile?.preferredWeeklySessions ?? 3).clamp(2, 4);
    final conservativeSessions = profile == null ? 3 : preferredSessions;
    final targets = <AiCoachWorkoutTarget>[
      const AiCoachWorkoutTarget(
        category: 'rodaje_base',
        purpose: 'Reactivar base aeróbica con carga controlada',
        priority: 1,
        targetDurationMinutes: 40,
      ),
      const AiCoachWorkoutTarget(
        category: 'tempo',
        purpose: 'Estimulo moderado de umbral sin excesos',
        priority: 2,
        targetDurationMinutes: 30,
      ),
      const AiCoachWorkoutTarget(
        category: 'rodaje_base',
        purpose: 'Tirada progresiva suave de cierre semanal',
        priority: 3,
        targetDurationMinutes: 55,
      ),
    ].take(conservativeSessions).toList();
    return AiCoachWeeklyDecision(
      id: 'fallback_${weekStart.millisecondsSinceEpoch}',
      generatedAt: now,
      sourceModel: 'fallback_code',
      analysis: 'Fallback automatico por error de proveedor IA',
      adjustment: AiCoachAdjustmentType.maintain,
      weekType: AiCoachWeekType.absorb,
      targetSessions: conservativeSessions,
      targetVolumeKm: 24,
      targetLoad: 150,
      primaryFocus: 'consistencia_segura',
      restrictions: const ['fallback_mode_active'],
      workoutTargets: targets,
    );
  }

  List<AthleteSession> _enforceAvailableWeekdays({
    required List<AthleteSession> sessions,
    required AiCoachProfile? profile,
    required DateTime weekStart,
    required DateTime minDate,
    required Set<int> occupiedWeekdays,
  }) {
    final allowed = _resolveFeasibleWeekdays(
      profile: profile,
      weekStart: weekStart,
      minDate: minDate,
      fallbackTargetSessions: sessions.length,
    );
    if (allowed.isEmpty) return sessions;

    final used = <int>{...occupiedWeekdays};
    final result = <AthleteSession>[];
    for (final session in sessions) {
      final parsed = DateTime.tryParse(session.date);
      final currentWeekday = parsed?.weekday;
      if (currentWeekday != null &&
          allowed.contains(currentWeekday) &&
          !used.contains(currentWeekday)) {
        used.add(currentWeekday);
        result.add(session);
        continue;
      }

      final nextAllowed = allowed.where((day) => !used.contains(day)).toList()..sort();
      if (nextAllowed.isEmpty) {
        continue;
      }
      final reassignedDay = nextAllowed.first;
      used.add(reassignedDay);
      final reassignedDate = weekStart.add(Duration(days: reassignedDay - 1));
      result.add(
        session.copyWith(
          date: _dateKey(reassignedDate),
          updatedAt: DateTime.now(),
        ),
      );
    }
    return result;
  }

  List<int> _normalizeAvailableWeekdays(List<int> rawDays) {
    final normalized = <int>{};
    for (final raw in rawDays) {
      if (raw >= 1 && raw <= 7) {
        normalized.add(raw);
        continue;
      }
      // Legacy fallback: 0..6 where 0=Sunday
      if (raw >= 0 && raw <= 6) {
        normalized.add(raw == 0 ? 7 : raw);
      }
    }
    if (normalized.isEmpty) return const [];
    final sorted = normalized.toList()..sort();
    return sorted;
  }

  _QualityGateResult _runQualityGate({
    required List<AthleteSession> sessions,
    required AiCoachWeeklyDecision decision,
    required AiCoachProfile? profile,
  }) {
    final issues = <String>[];
    if (sessions.isEmpty) {
      issues.add('no_sessions_generated');
    }
    final available = _normalizeAvailableWeekdays(profile?.availableWeekdays ?? const []);
    if (available.isNotEmpty) {
      final outOfRange = sessions.where((s) {
        final parsed = DateTime.tryParse(s.date);
        return parsed == null || !available.contains(parsed.weekday);
      });
      if (outOfRange.isNotEmpty) {
        issues.add('sessions_out_of_available_days');
      }
    }
    final qualityCount = sessions.where((s) {
      final c = s.category ?? '';
      return c == 'tempo' ||
          c == 'fartlek' ||
          c == 'series_cortas' ||
          c == 'series_largas' ||
          c == 'series_mixtas' ||
          c == 'series_cuestas';
    }).length;
    if (qualityCount > 2) {
      issues.add('too_many_quality_sessions');
    }
    if (decision.adjustment == AiCoachAdjustmentType.deload &&
        qualityCount > 1) {
      issues.add('deload_with_excess_quality');
    }
    return _QualityGateResult(
      isValid: issues.isEmpty,
      issues: issues,
    );
  }

  List<AthleteSession> _applyQualityGateFixes({
    required List<AthleteSession> sessions,
    required AiCoachProfile? profile,
  }) {
    var patched = [...sessions];
    final qualityIndexes = <int>[];
    for (var i = 0; i < patched.length; i++) {
      final c = patched[i].category ?? '';
      if (c == 'tempo' ||
          c == 'fartlek' ||
          c == 'series_cortas' ||
          c == 'series_largas' ||
          c == 'series_mixtas' ||
          c == 'series_cuestas') {
        qualityIndexes.add(i);
      }
    }
    while (qualityIndexes.length > 2) {
      final idx = qualityIndexes.removeLast();
      final session = patched[idx];
      patched[idx] = session.copyWith(
        category: 'rodaje_base',
        planningNotes:
            '${session.planningNotes ?? ''} · ajustado por quality gate',
      );
    }
    patched = _enforceAvailableWeekdays(
      sessions: patched,
      profile: profile,
      weekStart: patched.isNotEmpty && DateTime.tryParse(patched.first.date) != null
          ? DateTime.parse(patched.first.date).subtract(
              Duration(days: DateTime.parse(patched.first.date).weekday - 1),
            )
          : DateTime.now(),
      minDate: DateTime.now(),
      occupiedWeekdays: const <int>{},
    );
    return patched;
  }

  AiCoachWeeklyDecision _alignDecisionToProfile(
    AiCoachWeeklyDecision decision,
    AiCoachProfile? profile,
    {
    required DateTime weekStart,
    required DateTime minDate,
    }
  ) {
    if (profile == null) return decision;

    final availableDays = _resolveFeasibleWeekdays(
      profile: profile,
      weekStart: weekStart,
      minDate: minDate,
      fallbackTargetSessions: decision.targetSessions,
    ).length;
    final preferredWeeklySessions = profile.preferredWeeklySessions > 0
        ? profile.preferredWeeklySessions
        : decision.targetSessions;
    // Si el LLM propone MÁS sesiones que la preferencia del perfil,
    // respetamos al LLM — puede haber un mandato explícito del atleta
    // o una razón deportiva. Solo limitamos si el LLM propone menos.
    final effectiveTarget = decision.targetSessions > preferredWeeklySessions
        ? decision.targetSessions  // LLM manda más → respetar
        : preferredWeeklySessions; // LLM manda menos → usar perfil como piso

    final maxSessions = [
      effectiveTarget,
      if (availableDays > 0) availableDays,
    ].reduce((a, b) => a < b ? a : b);

    final normalizedTargets = [
      ...decision.workoutTargets,
    ]..sort((a, b) => a.priority.compareTo(b.priority));

    return AiCoachWeeklyDecision(
      id: decision.id,
      generatedAt: decision.generatedAt,
      sourceModel: decision.sourceModel,
      analysis: decision.analysis,
      adjustment: decision.adjustment,
      weekType: decision.weekType,
      targetSessions: maxSessions < 1 ? 1 : maxSessions,
      targetVolumeKm: decision.targetVolumeKm,
      targetLoad: decision.targetLoad,
      primaryFocus: decision.primaryFocus,
      restrictions: decision.restrictions,
      workoutTargets: normalizedTargets.take(maxSessions < 1 ? 1 : maxSessions).toList(),
    );
  }

  AiCoachWeeklyDecision _ensureMinimumTargetsFromProfile(
    AiCoachWeeklyDecision decision,
    AiCoachProfile? profile,
    {
    required DateTime weekStart,
    required DateTime minDate,
    required AiCoachAthleteMemory? memory,
    }
  ) {
    if (profile == null) return decision;
    final availableCount = _resolveFeasibleWeekdays(
      profile: profile,
      weekStart: weekStart,
      minDate: minDate,
      fallbackTargetSessions: decision.targetSessions,
    ).length;
    if (availableCount <= 0) return decision;

    final desired = profile.preferredWeeklySessions > 0
        ? profile.preferredWeeklySessions
        : decision.targetSessions;
    final minimumSessions = desired < availableCount ? desired : availableCount;
    final targetSessions =
        decision.targetSessions >= minimumSessions ? decision.targetSessions : minimumSessions;

    final normalizedTargets = [...decision.workoutTargets]
      ..sort((a, b) => a.priority.compareTo(b.priority));
    var nextPriority = normalizedTargets.isEmpty
        ? 1
        : normalizedTargets.last.priority + 1;
    final fallbackPool = _fallbackCategoriesForWeekType(
      decision.weekType,
      memory: memory,
      conservative: decision.adjustment == AiCoachAdjustmentType.deload ||
          decision.adjustment == AiCoachAdjustmentType.recover ||
          decision.adjustment == AiCoachAdjustmentType.restart,
    );
    var fallbackIndex = 0;
    while (normalizedTargets.length < targetSessions) {
      final category = fallbackPool[fallbackIndex % fallbackPool.length];
      fallbackIndex += 1;
      normalizedTargets.add(
        AiCoachWorkoutTarget(
          category: category,
          purpose: 'Sesion de consistencia para completar disponibilidad semanal',
          priority: nextPriority++,
          targetDurationMinutes: category == 'rodaje_base' ? 45 : 35,
          notes: 'Autogenerada por regla minima de disponibilidad',
        ),
      );
    }

    return AiCoachWeeklyDecision(
      id: decision.id,
      generatedAt: decision.generatedAt,
      sourceModel: decision.sourceModel,
      analysis: decision.analysis,
      adjustment: decision.adjustment,
      weekType: decision.weekType,
      targetSessions: targetSessions,
      targetVolumeKm: decision.targetVolumeKm,
      targetLoad: decision.targetLoad,
      primaryFocus: decision.primaryFocus,
      restrictions: decision.restrictions,
      workoutTargets: normalizedTargets.take(targetSessions).toList(),
    );
  }

  AiCoachWeeklyDecision _ensureTargetDiversity(
    AiCoachWeeklyDecision decision,
    AiCoachProfile? profile,
    AiCoachAthleteMemory? memory,
  ) {
    final targets = [...decision.workoutTargets]
      ..sort((a, b) => a.priority.compareTo(b.priority));
    if (targets.length < 3) return decision;

    final conservativeWeek = decision.adjustment == AiCoachAdjustmentType.deload ||
        decision.adjustment == AiCoachAdjustmentType.recover ||
        decision.adjustment == AiCoachAdjustmentType.restart;
    if (conservativeWeek) return decision;

    bool hasQuality = targets.any((t) => _isQualityCategory(t.category));
    bool hasBase = targets.any((t) => t.category == 'rodaje_base');
    bool hasLongish = targets.any((t) =>
        t.category == 'rodaje_base' &&
        ((t.targetDurationMinutes ?? 0) >= 55 || (t.targetDistanceKm ?? 0) >= 9.5));

    final updated = [...targets];
    int nextIdx = 0;
    int nextPriority = updated.isEmpty ? 1 : updated.last.priority + 1;

    if (!hasQuality) {
      final preferredQuality = _preferredQualityCategory(memory);
      final idx = _findReplaceableBaseIndex(updated, startAt: nextIdx);
      if (idx >= 0) {
        updated[idx] = _replaceCategory(updated[idx], preferredQuality);
      } else {
        updated.add(_newTarget(preferredQuality, nextPriority++));
      }
      hasQuality = true;
      nextIdx = idx + 1;
    }
    if (!hasBase) {
      final idx = _findFirstIndex(updated, (t) => !_isQualityCategory(t.category));
      if (idx >= 0) {
        updated[idx] = _replaceCategory(updated[idx], 'rodaje_base');
      } else {
        updated.add(_newTarget('rodaje_base', nextPriority++));
      }
      hasBase = true;
    }
    if (!hasLongish) {
      final idx = _findFirstIndex(updated, (t) => t.category == 'rodaje_base');
      if (idx >= 0) {
        final base = updated[idx];
        updated[idx] = AiCoachWorkoutTarget(
          category: base.category,
          purpose: base.purpose,
          priority: base.priority,
          preferredDay: base.preferredDay,
          targetLoad: base.targetLoad,
          targetDistanceKm: (base.targetDistanceKm ?? 9.5) < 9.5 ? 9.5 : base.targetDistanceKm,
          targetDurationMinutes: (base.targetDurationMinutes ?? 60) < 55 ? 60 : base.targetDurationMinutes,
          notes: base.notes,
        );
      }
    }

    final targetSessions = decision.targetSessions;
    final normalized = updated..sort((a, b) => a.priority.compareTo(b.priority));
    return AiCoachWeeklyDecision(
      id: decision.id,
      generatedAt: decision.generatedAt,
      sourceModel: decision.sourceModel,
      analysis: decision.analysis,
      adjustment: decision.adjustment,
      weekType: decision.weekType,
      targetSessions: targetSessions,
      targetVolumeKm: decision.targetVolumeKm,
      targetLoad: decision.targetLoad,
      primaryFocus: decision.primaryFocus,
      restrictions: decision.restrictions,
      workoutTargets: normalized.take(targetSessions).toList(),
    );
  }

  bool _isQualityCategory(String category) {
    return category == 'tempo' ||
        category == 'fartlek' ||
        category == 'series_cortas' ||
        category == 'series_largas' ||
        category == 'series_mixtas' ||
        category == 'series_cuestas' ||
        category == 'test';
  }

  List<String> _fallbackCategoriesForWeekType(
    AiCoachWeekType weekType, {
    required AiCoachAthleteMemory? memory,
    required bool conservative,
  }) {
    final preferredQuality = _preferredQualityCategory(memory);
    final secondaryQuality =
        preferredQuality == 'tempo' ? 'fartlek' : 'tempo';
    if (conservative) {
      return const ['rodaje_base', 'regenerativo', 'rodaje_base'];
    }
    switch (weekType) {
      case AiCoachWeekType.recovery:
      case AiCoachWeekType.taper:
      case AiCoachWeekType.restart:
        return const ['rodaje_base', 'regenerativo', 'rodaje_base'];
      case AiCoachWeekType.race:
        return ['rodaje_base', preferredQuality, 'rodaje_base'];
      case AiCoachWeekType.absorb:
      case AiCoachWeekType.build:
        return ['rodaje_base', preferredQuality, 'rodaje_base', secondaryQuality];
    }
  }

  String _preferredQualityCategory(AiCoachAthleteMemory? memory) {
    if (memory == null) return 'tempo';
    const candidates = <String>[
      'tempo',
      'fartlek',
      'series_largas',
      'series_mixtas',
      'series_cortas',
      'series_cuestas',
    ];
    String best = 'tempo';
    double bestScore = -1;
    for (final category in candidates) {
      final accept = memory.categoryAcceptance[category] ?? 0.0;
      final complete = memory.categoryCompletion[category] ?? 0.0;
      final score = (accept * 0.65) + (complete * 0.35);
      if (score > bestScore) {
        bestScore = score;
        best = category;
      }
    }
    return best;
  }

  int _findReplaceableBaseIndex(List<AiCoachWorkoutTarget> targets, {int startAt = 0}) {
    for (var i = startAt; i < targets.length; i++) {
      if (targets[i].category == 'rodaje_base') return i;
    }
    for (var i = 0; i < startAt && i < targets.length; i++) {
      if (targets[i].category == 'rodaje_base') return i;
    }
    return -1;
  }

  int _findFirstIndex(List<AiCoachWorkoutTarget> targets, bool Function(AiCoachWorkoutTarget) test) {
    for (var i = 0; i < targets.length; i++) {
      if (test(targets[i])) return i;
    }
    return -1;
  }

  AiCoachWorkoutTarget _replaceCategory(AiCoachWorkoutTarget source, String category) {
    return AiCoachWorkoutTarget(
      category: category,
      purpose: source.purpose,
      priority: source.priority,
      preferredDay: source.preferredDay,
      targetLoad: source.targetLoad,
      targetDistanceKm: source.targetDistanceKm,
      targetDurationMinutes: source.targetDurationMinutes,
      notes: source.notes,
    );
  }

  AiCoachWorkoutTarget _newTarget(String category, int priority) {
    return AiCoachWorkoutTarget(
      category: category,
      purpose: 'Objetivo generado para diversidad semanal',
      priority: priority,
      targetDurationMinutes: category == 'rodaje_base' ? 45 : 35,
    );
  }

  List<int> _resolveFeasibleWeekdays({
    required AiCoachProfile? profile,
    required DateTime weekStart,
    required DateTime minDate,
    required int fallbackTargetSessions,
  }) {
    var allowed = _normalizeAvailableWeekdays(profile?.availableWeekdays ?? const []);
    if (allowed.isEmpty) {
      allowed = _defaultWeekdaysForTargetSessions(fallbackTargetSessions);
    }
    if (allowed.isEmpty) return const [];
    return allowed.where((weekday) {
      final date = weekStart.add(Duration(days: weekday - 1));
      final normalizedDate = DateTime(date.year, date.month, date.day);
      return !normalizedDate.isBefore(minDate);
    }).toList()
      ..sort();
  }

  List<int> _defaultWeekdaysForTargetSessions(int targetSessions) {
    switch (targetSessions) {
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

  AiCoachAthleteMemory? _extractAthleteMemory(Map<String, dynamic> signals) {
    final raw = signals['athleteMemory'];
    if (raw is! Map) return null;
    try {
      return AiCoachAthleteMemory.fromMap(Map<String, dynamic>.from(raw));
    } catch (_) {
      return null;
    }
  }

  AiCoachWeeklyDecision _adaptDecisionWithAthleteMemory(
    AiCoachWeeklyDecision decision,
    AiCoachAthleteMemory? memory,
  ) {
    if (memory == null || decision.workoutTargets.isEmpty) return decision;
    final qualityCategories = <String>{
      'tempo',
      'fartlek',
      'series_cortas',
      'series_largas',
      'series_mixtas',
      'series_cuestas',
      'test',
    };
    final availableWeekdays = _normalizeAvailableWeekdays(
      decision.workoutTargets
          .map((target) => _weekdayFromLabel(target.preferredDay))
          .whereType<int>()
          .toList(),
    );
    final bestWeekday = _pickBestAdherenceWeekday(
      memory: memory,
      fallbackAllowed: availableWeekdays,
    );
    final adaptedTargets = [...decision.workoutTargets];
    if (memory.preferredStyle == 'continuous_dominant') {
      for (var i = 0; i < adaptedTargets.length; i++) {
        final current = adaptedTargets[i];
        final c = current.category;
        final isQuality = qualityCategories.contains(c);
        if (isQuality && i >= 1) {
          adaptedTargets[i] = AiCoachWorkoutTarget(
            category: 'rodaje_base',
            purpose: '${current.purpose} (ajuste por preferencia de estilo)',
            priority: current.priority,
            preferredDay: current.preferredDay,
            targetLoad: current.targetLoad,
            targetDistanceKm: current.targetDistanceKm,
            targetDurationMinutes: current.targetDurationMinutes,
            notes: current.notes,
          );
        }
      }
    } else if (memory.preferredStyle == 'interval_dominant') {
      final hasQuality = adaptedTargets.any(
        (t) => qualityCategories.contains(t.category) || t.category.startsWith('series_'),
      );
      if (!hasQuality && adaptedTargets.isNotEmpty) {
        final first = adaptedTargets.first;
        adaptedTargets[0] = AiCoachWorkoutTarget(
          category: 'tempo',
          purpose: '${first.purpose} (ajuste por preferencia de estilo)',
          priority: first.priority,
          preferredDay: first.preferredDay,
          targetLoad: first.targetLoad,
          targetDistanceKm: first.targetDistanceKm,
          targetDurationMinutes: first.targetDurationMinutes,
          notes: first.notes,
        );
      }
    }

    for (var i = 0; i < adaptedTargets.length; i++) {
      final target = adaptedTargets[i];
      final category = target.category;
      final accept = memory.categoryAcceptance[category] ?? 0.5;
      final complete = memory.categoryCompletion[category] ?? 0.5;
      final score = (accept * 0.6) + (complete * 0.4);
      final shouldSofterCategory = qualityCategories.contains(category) && score < 0.35;
      final mappedCategory = shouldSofterCategory ? 'rodaje_base' : category;
      final preferredDay = target.preferredDay ??
          (bestWeekday != null ? _weekdayToEnglishLabel(bestWeekday) : null);

      adaptedTargets[i] = AiCoachWorkoutTarget(
        category: mappedCategory,
        purpose: target.purpose,
        priority: target.priority,
        preferredDay: preferredDay,
        targetLoad: target.targetLoad,
        targetDistanceKm: target.targetDistanceKm,
        targetDurationMinutes: target.targetDurationMinutes,
        notes: target.notes,
      );
    }

    return AiCoachWeeklyDecision(
      id: decision.id,
      generatedAt: decision.generatedAt,
      sourceModel: decision.sourceModel,
      analysis: decision.analysis,
      adjustment: decision.adjustment,
      weekType: decision.weekType,
      targetSessions: decision.targetSessions,
      targetVolumeKm: decision.targetVolumeKm,
      targetLoad: decision.targetLoad,
      primaryFocus: decision.primaryFocus,
      restrictions: decision.restrictions,
      workoutTargets: adaptedTargets,
    );
  }

  int? _pickBestAdherenceWeekday({
    required AiCoachAthleteMemory memory,
    required List<int> fallbackAllowed,
  }) {
    if (memory.weekdayAdherence.isEmpty && fallbackAllowed.isEmpty) return null;
    final candidateDays = fallbackAllowed.isEmpty
        ? const <int>[1, 2, 3, 4, 5, 6, 7]
        : fallbackAllowed;
    var bestDay = candidateDays.first;
    var bestScore = -1.0;
    for (final day in candidateDays) {
      final score = memory.weekdayAdherence[day] ?? 0.0;
      if (score > bestScore) {
        bestDay = day;
        bestScore = score;
      }
    }
    return bestDay;
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

  String _weekdayToEnglishLabel(int weekday) {
    switch (weekday) {
      case 1:
        return 'monday';
      case 2:
        return 'tuesday';
      case 3:
        return 'wednesday';
      case 4:
        return 'thursday';
      case 5:
        return 'friday';
      case 6:
        return 'saturday';
      case 7:
      default:
        return 'sunday';
    }
  }
}

class _QualityGateResult {
  final bool isValid;
  final List<String> issues;

  const _QualityGateResult({
    required this.isValid,
    required this.issues,
  });
}
