import 'package:running_laps/features/ai_coach/data/ai_coach_repository.dart';
import 'package:running_laps/features/ai_coach/data/ai_coach_weekly_planner_service.dart';
import 'package:running_laps/features/ai_coach/data/ai_coach_models.dart';
import 'package:running_laps/features/athlete/data/athlete_session_model.dart';
import 'package:running_laps/features/athlete/data/athlete_session_repository.dart';
import 'package:running_laps/core/services/user_service.dart';
import 'package:flutter/foundation.dart';

class AiCoachAutomationResult {
  final bool generated;
  final int generatedSessions;

  const AiCoachAutomationResult({
    required this.generated,
    required this.generatedSessions,
  });
}

class AiCoachAutomationService {
  AiCoachAutomationService({
    AiCoachRepository? repository,
    AthleteSessionRepository? sessionRepository,
    AiCoachWeeklyPlannerService? weeklyPlannerService,
    UserService? userService,
  })  : _repository = repository ?? AiCoachRepository(),
        _sessionRepository = sessionRepository ?? AthleteSessionRepository(),
        _weeklyPlannerService =
            weeklyPlannerService ?? AiCoachWeeklyPlannerService(),
        _userService = userService ?? UserService();

  final AiCoachRepository _repository;
  final AthleteSessionRepository _sessionRepository;
  final AiCoachWeeklyPlannerService _weeklyPlannerService;
  final UserService _userService;

  /// Fuerza la generación del plan de la próxima semana,
  /// saltándose las guardas de ventana temporal y ciclo.
  /// Se usa cuando el usuario rellena el cuestionario manualmente.
  /// Mantiene las validaciones de perfil, API key y modo atleta.
  Future<bool> forceGenerateNextWeekPlan(String uid) async {
    final profile = await _repository.getProfile(uid: uid);
    if (profile == null) {
      debugPrint('[AiCoachAutomation] force: sin perfil AI');
      return false;
    }

    final providerConfig = await _repository.getProviderConfig(uid: uid);
    if (providerConfig?.apiKey == null ||
        (providerConfig!.apiKey?.trim().isEmpty ?? true)) {
      debugPrint('[AiCoachAutomation] force: sin API key');
      return false;
    }

    try {
      final result = await _weeklyPlannerService.planNextWeek(uid);
      debugPrint(
        '[AiCoachAutomation] force: ${result.sessions.length} sesiones generadas',
      );
      return result.sessions.isNotEmpty;
    } catch (e) {
      debugPrint('[AiCoachAutomation] force error: $e');
      return false;
    }
  }

  Future<AiCoachAutomationResult> ensureNextWeekPlanIfDue(
    String uid, {
    DateTime? referenceDate,
  }) async {
    final now = referenceDate ?? DateTime.now();
    final isAthleteMode = await _userService.getIsAthleteMode(uid);
    if (!isAthleteMode) {
      debugPrint('[AiCoachAutomation] skipped (athlete mode disabled) uid=$uid');
      return const AiCoachAutomationResult(
        generated: false,
        generatedSessions: 0,
      );
    }

    final profile = await _repository.getProfile(uid: uid);
    if (profile == null) {
      debugPrint('[AiCoach] No profile found, skipping auto-plan');
      return const AiCoachAutomationResult(
        generated: false,
        generatedSessions: 0,
      );
    }

    final provider = await _repository.getProviderConfig(uid: uid);
    if (provider == null ||
        !provider.weeklyPlanningEnabled ||
        provider.provider != 'openrouter' ||
        (provider.apiKey?.trim().isEmpty ?? true)) {
      return const AiCoachAutomationResult(
        generated: false,
        generatedSessions: 0,
      );
    }

    if (!_isAutomationWindowOpen(now)) {
      return const AiCoachAutomationResult(
        generated: false,
        generatedSessions: 0,
      );
    }

    final nextWeekStart = _mondayOf(now).add(const Duration(days: 7));
    final nextWeekEnd = nextWeekStart.add(const Duration(days: 6));
    final cycleId = _dateKey(nextWeekStart);
    final automationState = await _repository.getAutomationState(uid: uid);
    if (automationState?.lastGeneratedCycleId == cycleId) {
      debugPrint(
        '[AiCoachAutomation] skipped (already generated cycle) uid=$uid cycleId=$cycleId',
      );
      return const AiCoachAutomationResult(
        generated: false,
        generatedSessions: 0,
      );
    }
    final nextWeekSessions = await _sessionRepository.getSessionsInRange(
      uid: uid,
      startDate: _dateKey(nextWeekStart),
      endDate: _dateKey(nextWeekEnd),
    );

    final alreadyHasPlan = nextWeekSessions.any(
      (session) =>
          session.status == AthleteSessionStatus.planned &&
          (session.suggestion?.origin == AthleteSessionOrigin.ai ||
              session.category != null),
    );
    if (alreadyHasPlan) {
      await _repository.saveAutomationState(
        AiCoachAutomationState(
          lastGeneratedCycleId: cycleId,
          lastGeneratedAt: now,
          lastGenerationSource: 'detected_existing_plan',
        ),
        uid: uid,
      );
      return const AiCoachAutomationResult(
        generated: false,
        generatedSessions: 0,
      );
    }

    final result = await _weeklyPlannerService.planNextWeek(
      uid,
      referenceDate: now,
    );
    if (result.sessions.isNotEmpty) {
      await _repository.saveAutomationState(
        AiCoachAutomationState(
          lastGeneratedCycleId: cycleId,
          lastGeneratedAt: now,
          lastGenerationSource: 'automation_window',
        ),
        uid: uid,
      );
    }
    return AiCoachAutomationResult(
      generated: result.sessions.isNotEmpty,
      generatedSessions: result.sessions.length,
    );
  }

  bool _isAutomationWindowOpen(DateTime now) {
    if (now.weekday == DateTime.sunday) {
      return now.hour >= 20;
    }
    return now.weekday == DateTime.monday;
  }

  DateTime _mondayOf(DateTime value) {
    final date = DateTime(value.year, value.month, value.day);
    return date.subtract(Duration(days: date.weekday - 1));
  }

  String _dateKey(DateTime value) {
    return '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
  }
}
