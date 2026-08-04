import 'dart:math' as math;

import 'package:running_laps/features/ai_coach/data/ai_coach_autoregulation.dart';
import 'package:running_laps/features/ai_coach/data/ai_coach_decision_service.dart';
import 'package:running_laps/features/ai_coach/data/ai_coach_context_builder.dart';
import 'package:running_laps/features/ai_coach/data/ai_coach_mesocycle_engine.dart';
import 'package:running_laps/features/ai_coach/data/ai_coach_models.dart';
import 'package:running_laps/features/ai_coach/data/ai_coach_repository.dart';
import 'package:running_laps/features/ai_coach/data/ai_coach_session_generator.dart';
import 'package:running_laps/features/ai_coach/data/vdot_auto_updater.dart';
import 'package:running_laps/features/athlete/data/athlete_session_model.dart';
import 'package:running_laps/features/athlete/data/athlete_session_repository.dart';
import 'package:running_laps/core/services/health_consent_service.dart';
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
    HealthConsentService? healthConsentService,
  })  : _decisionServiceOverride = decisionService,
        _contextBuilderOverride = contextBuilder,
        _aiCoachRepositoryOverride = aiCoachRepository,
        _sessionRepositoryOverride = sessionRepository,
        _sessionGenerator = sessionGenerator ?? const AiCoachSessionGenerator(),
        _userServiceOverride = userService,
        _healthConsentOverride = healthConsentService;

  // Colaboradores perezosos: construir el planificador no debe exigir Firebase
  // inicializado (mismo criterio que AiCoachChatService). El reparto de días
  // es lógica pura y no los toca.
  final AiCoachDecisionService? _decisionServiceOverride;
  final AiCoachContextBuilder? _contextBuilderOverride;
  final AiCoachRepository? _aiCoachRepositoryOverride;
  final AthleteSessionRepository? _sessionRepositoryOverride;
  final UserService? _userServiceOverride;
  final HealthConsentService? _healthConsentOverride;

  late final AiCoachDecisionService _decisionService =
      _decisionServiceOverride ?? AiCoachDecisionService();
  late final AiCoachContextBuilder _contextBuilder =
      _contextBuilderOverride ?? AiCoachContextBuilder();
  late final AiCoachRepository _aiCoachRepository =
      _aiCoachRepositoryOverride ?? AiCoachRepository();
  late final AthleteSessionRepository _sessionRepository =
      _sessionRepositoryOverride ?? AthleteSessionRepository();
  late final UserService _userService = _userServiceOverride ?? UserService();
  late final HealthConsentService _healthConsent =
      _healthConsentOverride ?? HealthConsentService();

  final AiCoachSessionGenerator _sessionGenerator;

  static const _mesocycleEngine = AiCoachMesocycleEngine();
  static const _autoregulation = AiCoachAutoregulation();
  static const _vdotUpdater = VdotAutoUpdater();

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

    // Candado único de datos de salud: el contexto semanal lleva molestias,
    // lesiones, FC y zonas a un proveedor externo. Las cuatro rutas de
    // generacion (automatica, forzada, onboarding y chat) pasan por aqui, asi
    // que basta comprobarlo en este punto. Sin consentimiento no se genera.
    final hasConsent = await _healthConsent.hasConsent(
      HealthConsentScope.aiCoach,
      uid: uid,
    );
    if (!hasConsent) {
      throw const HealthConsentRequiredException(HealthConsentScope.aiCoach);
    }

    final anchor = referenceDate ?? DateTime.now();
    var nextWeekStart =
        targetWeekStart != null ? _mondayOf(targetWeekStart) : _mondayOf(anchor).add(const Duration(days: 7));
    var nextWeekEnd = nextWeekStart.add(const Duration(days: 6));
    final today = DateTime.now();
    final minDate = DateTime(today.year, today.month, today.day);

    final profile = await _aiCoachRepository.getProfile(uid: uid);
    final context = await _contextBuilder.buildWeeklyContext(uid);

    // El bloque y el veredicto de autorregulacion se resuelven ANTES de pedir
    // la decision: el LLM tiene que verlos para que su narrativa no contradiga
    // la carga que se le va a aplicar despues por codigo.
    final block = await _resolveActiveMesocycle(
      uid: uid,
      weekStart: nextWeekStart,
      profile: profile,
      context: context,
    );
    // Respuestas del cuestionario de la semana que se esta evaluando: explican
    // el PORQUE que los datos de ejecucion no pueden dar (fatiga real vs
    // agenda, molestia abierta, enfermedad).
    final lastFeedback = await _aiCoachRepository.getWeeklyFeedback(
      uid: uid,
      weekStart: _dateKey(nextWeekStart.subtract(const Duration(days: 7))),
    );
    final signal = _autoregulation.evaluate(
      lastWeekSessions: _lastWeekSessions(context, nextWeekStart),
      weeklyState: context.weeklyState,
      answers: lastFeedback?.adaptiveAnswers ?? const [],
    );

    AiCoachWeeklyDecision rawDecision;
    bool fallbackUsed = false;
    try {
      rawDecision = decisionOverride ??
          await _decisionService.generateWeeklyDecision(
            uid,
            mesocycle: block,
            autoregulation: signal,
            plannedWeekStart: nextWeekStart,
          );
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
    final memory = _extractAthleteMemory(context.coachSignals);
    final adapted = _adaptDecisionWithAthleteMemory(rawDecision, memory);
    // Periodizacion antes que diversidad: si el bloque manda descarga, las
    // reglas conservadoras de _ensureTargetDiversity tienen que verlo.
    final periodized = alignDecisionToMesocycle(
      adapted,
      block: block,
      signal: signal,
      weekStart: nextWeekStart,
      actualLastWeekKm: context.weeklyState.weeklyKm,
    );
    final aligned = _alignDecisionToProfile(
      periodized,
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
    var feasibleWeekdays = resolveFeasibleWeekdays(
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
      feasibleWeekdays = resolveFeasibleWeekdays(
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

    // El VDOT se revisa ANTES de generar: si el atleta ha mejorado, las
    // sesiones de esta semana ya salen con los ritmos nuevos.
    final vdot = await _refreshVdot(
      uid: uid,
      profile: profile,
      recentSessions: context.recentTrainings,
    );

    var sessions = _sessionGenerator.generateWeekSessions(
      uid: uid,
      weekStart: nextWeekStart,
      decision: decision,
      profile: profile,
      occupiedWeekdays: occupiedWeekdays,
      maxSessions: remainingSlots,
      vdotOverride: vdot,
    );
    sessions = enforceAvailableWeekdays(
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
      block: block,
      weekStart: nextWeekStart,
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
        'blockId': block.id,
        'blockPhase': block.phase.toValue,
        'blockWeek': block.weekIndexFor(nextWeekStart) + 1,
        'blockLengthWeeks': block.lengthWeeks,
        'autoregulationVerdict': signal.verdict.toValue,
        'autoregulationReason': signal.reason,
        'targetVolumeKm': decision.targetVolumeKm,
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

  /// Reubica las sesiones del plan en los días que el atleta dijo tener
  /// disponibles, sin poner dos el mismo día. Es lo que impide que el Coach te
  /// planifique un martes cuando dijiste que los martes no puedes.
  @visibleForTesting
  List<AthleteSession> enforceAvailableWeekdays({
    required List<AthleteSession> sessions,
    required AiCoachProfile? profile,
    required DateTime weekStart,
    required DateTime minDate,
    required Set<int> occupiedWeekdays,
  }) {
    final allowed = resolveFeasibleWeekdays(
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

  /// Normaliza los días disponibles del perfil al criterio de Dart
  /// (1 = lunes … 7 = domingo). Los perfiles antiguos los guardaban en 0..6 con
  /// 0 = domingo: si esto se equivoca, todo el plan se corre de día.
  @visibleForTesting
  List<int> normalizeAvailableWeekdays(List<int> rawDays) {
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

  /// Revisa la estimacion de VDOT con la evidencia reciente y la persiste si
  /// cambia. Devuelve el valor vigente para generar las sesiones.
  ///
  /// Nunca hace fallar la planificacion: si algo va mal, se sigue con los
  /// paces que hubiera.
  Future<double?> _refreshVdot({
    required String uid,
    required AiCoachProfile? profile,
    required List<AiCoachTrainingSummary> recentSessions,
  }) async {
    try {
      final stored = await _aiCoachRepository.getVdotEstimate(uid: uid);
      final current = stored?.vdot;

      final update = _vdotUpdater.review(
        currentVdot: current,
        profile: profile,
        recentSessions: recentSessions,
      );

      if (update == null || !update.changed) {
        if (current != null) return current;
        // Primera vez: sembrar desde las marcas del perfil para no perder el
        // valor entre semanas.
        final seed = profile == null ? null : _vdotUpdater.seedFromProfile(profile);
        if (seed == null) return null;
        await _aiCoachRepository.saveVdotEstimate(
          AiCoachVdotEstimate(
            vdot: seed,
            source: VdotSource.profilePb.toValue,
            updatedAt: DateTime.now(),
          ).withPoint(seed, DateTime.now(), VdotSource.profilePb.toValue),
          uid: uid,
        );
        return seed;
      }

      final base = stored ??
          AiCoachVdotEstimate(
            vdot: update.previousVdot,
            source: VdotSource.profilePb.toValue,
            updatedAt: DateTime.now(),
          );
      await _aiCoachRepository.saveVdotEstimate(
        base.withPoint(
          update.vdot,
          DateTime.now(),
          update.source.toValue,
          reason: update.reason,
          evidence: update.evidenceCount,
        ),
        uid: uid,
      );
      await _aiCoachRepository.logEvent(
        uid: uid,
        eventType: 'vdot_updated',
        payload: {
          'from': update.previousVdot,
          'to': update.vdot,
          'source': update.source.toValue,
          'evidenceCount': update.evidenceCount,
          'reason': update.reason,
        },
      );
      return update.vdot;
    } catch (e) {
      debugPrint('[AiCoachWeeklyPlanner] _refreshVdot error: $e');
      return null;
    }
  }

  /// Devuelve el bloque activo, creandolo si no existe, si la semana pedida
  /// cae fuera, o si el objetivo del atleta cambio de fase (p.ej. la carrera ya
  /// entro en rango de taper).
  Future<AiCoachMesocycle> _resolveActiveMesocycle({
    required String uid,
    required DateTime weekStart,
    required AiCoachProfile? profile,
    required AiCoachWeeklyContext context,
  }) async {
    final existing = await _aiCoachRepository.getMesocycle(uid: uid);
    if (existing != null &&
        existing.containsWeek(weekStart) &&
        !_blockPhaseIsStale(existing, profile, weekStart)) {
      return existing;
    }

    final block = _mesocycleEngine.buildBlock(
      weekStart: weekStart,
      profile: profile,
      weeklyState: context.weeklyState,
      previous: existing,
    );
    await _aiCoachRepository.saveMesocycle(block, uid: uid);
    await _aiCoachRepository.logEvent(
      uid: uid,
      eventType: 'mesocycle_started',
      payload: {
        'blockId': block.id,
        'weekStart': _dateKey(block.startWeek),
        'phase': block.phase.toValue,
        'lengthWeeks': block.lengthWeeks,
        'weekPattern': block.weekPattern.map((t) => t.toValue).toList(),
        'baselineVolumeKm': block.baselineVolumeKm,
        'volumeCeilingKm': block.volumeCeilingKm,
        'sequenceIndex': block.sequenceIndex,
        'replacedBlockId': existing?.id,
      },
    );
    return block;
  }

  /// El bloque se queda obsoleto si la carrera objetivo ya deberia haber
  /// disparado el taper y el bloque sigue en fase de construccion.
  bool _blockPhaseIsStale(
    AiCoachMesocycle block,
    AiCoachProfile? profile,
    DateTime weekStart,
  ) {
    final target = profile?.targetDate;
    if (target == null) return false;
    final weeksToRace = target.difference(weekStart).inDays ~/ 7;
    if (weeksToRace < 0) return false;
    final shouldTaper = weeksToRace <= 3;
    final isTapering = block.phase == AiCoachBlockPhase.taper ||
        block.phase == AiCoachBlockPhase.race;
    return shouldTaper && !isTapering;
  }

  /// Sesiones de la semana anterior a la que se planifica. Es la evidencia que
  /// alimenta la autorregulacion.
  List<AiCoachTrainingSummary> _lastWeekSessions(
    AiCoachWeeklyContext context,
    DateTime weekStart,
  ) {
    final from = weekStart.subtract(const Duration(days: 7));
    return context.recentTrainings
        .where((t) => !t.date.isBefore(from) && t.date.isBefore(weekStart))
        .toList();
  }

  /// Aplica la periodizacion a la decision del LLM.
  ///
  /// El bloque manda el tipo de semana; la autorregulacion manda la carga. El
  /// LLM solo puede pedir MENOS volumen del resultante, nunca mas: pedir menos
  /// es la valvula de seguridad ante fatiga, pedir mas es justo lo que no debe
  /// poder hacer.
  @visibleForTesting
  AiCoachWeeklyDecision alignDecisionToMesocycle(
    AiCoachWeeklyDecision decision, {
    required AiCoachMesocycle block,
    required AiCoachAutoregulationSignal signal,
    required DateTime weekStart,
    required double actualLastWeekKm,
  }) {
    final weekIndex = block.clampWeekIndex(block.weekIndexFor(weekStart));
    final ceiling = _mesocycleEngine.targetVolumeForWeek(block, weekIndex);
    final autoregulated = _autoregulation.resolveTargetVolume(
      signal: signal,
      actualLastWeekKm: actualLastWeekKm,
      blockCeilingKm: ceiling,
      baselineFallbackKm: block.baselineVolumeKm,
    );
    final volume = decision.targetVolumeKm > 0
        ? math.min(decision.targetVolumeKm, autoregulated)
        : autoregulated;

    // La carga escala con el volumen para que no queden descompensados.
    final load = decision.targetVolumeKm > 0
        ? decision.targetLoad * (volume / decision.targetVolumeKm)
        : decision.targetLoad;

    final weekType = block.weekTypeAt(weekIndex);

    return AiCoachWeeklyDecision(
      id: decision.id,
      generatedAt: decision.generatedAt,
      sourceModel: decision.sourceModel,
      analysis: decision.analysis,
      adjustment: _adjustmentForWeekType(weekType, signal, decision.adjustment),
      weekType: weekType,
      targetSessions: decision.targetSessions,
      targetVolumeKm: volume,
      targetLoad: load,
      primaryFocus: decision.primaryFocus,
      restrictions: decision.restrictions,
      workoutTargets: decision.workoutTargets,
    );
  }

  AiCoachAdjustmentType _adjustmentForWeekType(
    AiCoachWeekType weekType,
    AiCoachAutoregulationSignal signal,
    AiCoachAdjustmentType fallback,
  ) {
    switch (weekType) {
      case AiCoachWeekType.absorb:
      case AiCoachWeekType.recovery:
        return AiCoachAdjustmentType.deload;
      case AiCoachWeekType.taper:
      case AiCoachWeekType.race:
        return AiCoachAdjustmentType.taper;
      case AiCoachWeekType.restart:
        return AiCoachAdjustmentType.restart;
      case AiCoachWeekType.build:
        switch (signal.verdict) {
          case AiCoachReadinessVerdict.reset:
            return AiCoachAdjustmentType.restart;
          case AiCoachReadinessVerdict.regress:
            return AiCoachAdjustmentType.reduce;
          case AiCoachReadinessVerdict.hold:
            return AiCoachAdjustmentType.maintain;
          case AiCoachReadinessVerdict.progress:
            return fallback == AiCoachAdjustmentType.deload
                ? AiCoachAdjustmentType.progress
                : fallback;
        }
    }
  }

  _QualityGateResult _runQualityGate({
    required List<AthleteSession> sessions,
    required AiCoachWeeklyDecision decision,
    required AiCoachProfile? profile,
    AiCoachMesocycle? block,
    DateTime? weekStart,
  }) {
    final issues = <String>[];
    if (block != null && weekStart != null && decision.targetVolumeKm > 0) {
      final weekIndex = block.clampWeekIndex(block.weekIndexFor(weekStart));
      final ceiling = _mesocycleEngine.targetVolumeForWeek(block, weekIndex);
      // Defensa en profundidad: no deberia dispararse tras el align, pero si
      // lo hace queda registrado en el evento del planificador.
      if (ceiling > 0 && decision.targetVolumeKm > ceiling * 1.01) {
        issues.add('volume_exceeds_block_ceiling');
      }
      if (!block.weekPattern.any((t) =>
          t == AiCoachWeekType.absorb ||
          t == AiCoachWeekType.recovery ||
          t == AiCoachWeekType.taper ||
          t == AiCoachWeekType.race)) {
        issues.add('block_without_deload');
      }
    }
    if (sessions.isEmpty) {
      issues.add('no_sessions_generated');
    }
    final available = normalizeAvailableWeekdays(profile?.availableWeekdays ?? const []);
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
    patched = enforceAvailableWeekdays(
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

    final availableDays = resolveFeasibleWeekdays(
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
    final availableCount = resolveFeasibleWeekdays(
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

  /// Días en los que de verdad se puede planificar esta semana: los del perfil
  /// (o un reparto por defecto si no los ha dicho), descartando los que ya
  /// pasaron.
  @visibleForTesting
  List<int> resolveFeasibleWeekdays({
    required AiCoachProfile? profile,
    required DateTime weekStart,
    required DateTime minDate,
    required int fallbackTargetSessions,
  }) {
    var allowed = normalizeAvailableWeekdays(profile?.availableWeekdays ?? const []);
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
    final availableWeekdays = normalizeAvailableWeekdays(
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
