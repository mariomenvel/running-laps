import 'dart:convert';

import 'package:running_laps/features/ai_coach/data/ai_coach_context_builder.dart';
import 'package:running_laps/features/ai_coach/data/ai_coach_models.dart';
import 'package:running_laps/features/ai_coach/data/ai_coach_prompt_builder.dart';
import 'package:running_laps/features/ai_coach/data/ai_coach_repository.dart';
import 'package:running_laps/features/ai_coach/data/ai_coach_weekly_planner_service.dart';
import 'package:running_laps/features/ai_coach/data/openrouter_client.dart';
import 'package:running_laps/features/athlete/data/athlete_session_model.dart';
import 'package:running_laps/features/athlete/data/athlete_session_repository.dart';
import 'package:running_laps/core/services/user_service.dart';

class AiCoachChatService {
  AiCoachChatService({
    AiCoachRepository? repository,
    AiCoachContextBuilder? contextBuilder,
    AiCoachPromptBuilder? promptBuilder,
    OpenRouterClient? openRouterClient,
    AthleteSessionRepository? sessionRepository,
    AiCoachWeeklyPlannerService? weeklyPlannerService,
    UserService? userService,
  })  : _repository = repository ?? AiCoachRepository(),
        _contextBuilder = contextBuilder ?? AiCoachContextBuilder(),
        _promptBuilder = promptBuilder ?? const AiCoachPromptBuilder(),
        _openRouterClient = openRouterClient ?? OpenRouterClient(),
        _sessionRepository = sessionRepository ?? AthleteSessionRepository(),
        _weeklyPlannerService =
            weeklyPlannerService ?? AiCoachWeeklyPlannerService(),
        _userService = userService ?? UserService();

  final AiCoachRepository _repository;
  final AiCoachContextBuilder _contextBuilder;
  final AiCoachPromptBuilder _promptBuilder;
  final OpenRouterClient _openRouterClient;
  final AthleteSessionRepository _sessionRepository;
  final AiCoachWeeklyPlannerService _weeklyPlannerService;
  final UserService _userService;
  static const int _weeklyChatLimit = 3;

  Future<AiCoachChatAdjustmentResult> adjustNextWeekPlan(
    String uid, {
    required String athleteMessage,
  }) async {
    final isAthleteMode = await _userService.getIsAthleteMode(uid);
    if (!isAthleteMode) {
      throw Exception(
        'El Entrenador IA solo esta disponible con modo atleta activado.',
      );
    }

    final usage = await _prepareAndGetCurrentWeekUsage(uid);
    if (usage.messagesUsed >= _weeklyChatLimit) {
      throw Exception(
        'Has alcanzado el limite de 3 consultas esta semana. '
        'Vuelve a intentarlo la proxima semana.',
      );
    }

    final provider = await _repository.getProviderConfig(uid: uid);
    if (provider == null ||
        !provider.chatAdjustmentsEnabled ||
        provider.provider != 'openrouter' ||
        (provider.apiKey == null || provider.apiKey!.trim().isEmpty)) {
      throw Exception('Ajustes IA no configurados');
    }

    try {
      final context = await _contextBuilder.buildWeeklyContext(uid);
      final currentDecision = await _repository.getLastDecision(uid: uid);
      final nextWeekSessions = await _loadNextWeekSessions(uid);
      final prompt = _promptBuilder.buildChatAdjustmentPrompt(
        context,
        athleteMessage: athleteMessage,
        nextWeekSessions: nextWeekSessions,
        currentDecision: currentDecision,
      );

      final completion = await _openRouterClient.createJsonCompletion(
        apiKey: provider.apiKey!.trim(),
        model: provider.model,
        messages: prompt.messages,
        jsonSchema: prompt.jsonSchema,
      );

      final parsed = _parseJsonObject(completion.content);
      final result = _buildResultFromResponse(
        parsed,
        fallbackModel: provider.model,
      );

      await _repository.saveUsage(
        AiCoachUsage(
          plan: usage.plan,
          messagesUsed: usage.messagesUsed + 1,
          messagesLimit: _weeklyChatLimit,
          periodStart: usage.periodStart,
          periodEnd: usage.periodEnd,
        ),
        uid: uid,
      );

      if (result.decisionOverride != null) {
        await _weeklyPlannerService.planNextWeek(
          uid,
          decisionOverride: result.decisionOverride,
        );
        await _repository.saveLastDecision(result.decisionOverride!, uid: uid);
      } else {
        final moved = await _tryLocalWeekdayMoveFallback(
          uid: uid,
          athleteMessage: athleteMessage,
        );
        if (moved) {
          return AiCoachChatAdjustmentResult(
            response:
                result.response.isEmpty
                    ? 'He aplicado el cambio de dia solicitado.'
                    : '${result.response}\n\nHe aplicado el cambio de dia solicitado en el plan.',
          );
        }
      }

      return result;
    } catch (e) {
      throw Exception(
        'Fallo al ajustar el plan con OpenRouter: '
        '${e.toString().replaceFirst('Exception: ', '')}',
      );
    }
  }

  Future<List<Map<String, dynamic>>> _loadNextWeekSessions(String uid) async {
    final anchor = DateTime.now();
    final monday = DateTime(anchor.year, anchor.month, anchor.day)
        .subtract(Duration(days: anchor.weekday - 1))
        .add(const Duration(days: 7));
    final sunday = monday.add(const Duration(days: 6));
    final sessions = await _sessionRepository.getSessionsInRange(
      uid: uid,
      startDate: _dateKey(monday),
      endDate: _dateKey(sunday),
    );
    sessions.sort((a, b) {
      final dateCompare = a.date.compareTo(b.date);
      if (dateCompare != 0) return dateCompare;
      return (a.time ?? '').compareTo(b.time ?? '');
    });
    return sessions
        .map(
          (session) => {
            'sessionId': session.id,
            'date': session.date,
            'time': session.time,
            'category': session.category,
            'status': session.status.toValue,
            'suggestionStatus': session.suggestion?.status.toValue,
            'planningNotes': session.planningNotes,
          },
        )
        .toList();
  }

  Map<String, dynamic> _parseJsonObject(String raw) {
    final trimmed = raw.trim();
    try {
      return Map<String, dynamic>.from(jsonDecode(trimmed) as Map);
    } catch (_) {
      final start = trimmed.indexOf('{');
      final end = trimmed.lastIndexOf('}');
      if (start >= 0 && end > start) {
        final candidate = trimmed.substring(start, end + 1);
        return Map<String, dynamic>.from(jsonDecode(candidate) as Map);
      }
      rethrow;
    }
  }

  AiCoachChatAdjustmentResult _buildResultFromResponse(
    Map<String, dynamic> map, {
    required String fallbackModel,
  }) {
    final response = (map['response'] as String? ?? '').trim();
    final overrideMap = map['decisionOverride'];

    if (overrideMap is! Map) {
      return AiCoachChatAdjustmentResult(response: response);
    }

    final rawDecision = Map<String, dynamic>.from(overrideMap);
    final generatedAt = DateTime.now();
    final decision = AiCoachWeeklyDecision.fromMap({
      'id': rawDecision['id'] ?? generatedAt.millisecondsSinceEpoch.toString(),
      'generatedAt': rawDecision['generatedAt'] ?? generatedAt.toIso8601String(),
      'sourceModel': rawDecision['sourceModel'] ?? fallbackModel,
      ...rawDecision,
    });

    return AiCoachChatAdjustmentResult(
      response: response,
      decisionOverride: decision,
    );
  }

  String _dateKey(DateTime value) {
    return '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
  }

  Future<AiCoachUsage> _prepareAndGetCurrentWeekUsage(String uid) async {
    final now = DateTime.now();
    final weekStart = _mondayOf(now);
    final weekEnd = weekStart.add(const Duration(days: 6));
    final current = await _repository.getUsage(uid: uid);
    if (current == null ||
        current.periodStart.isAfter(now) ||
        current.periodEnd.isBefore(now)) {
      final reset = AiCoachUsage(
        plan: 'athlete_chat_weekly',
        messagesUsed: 0,
        messagesLimit: _weeklyChatLimit,
        periodStart: weekStart,
        periodEnd: weekEnd,
      );
      await _repository.saveUsage(reset, uid: uid);
      return reset;
    }
    if (current.messagesLimit != _weeklyChatLimit ||
        current.periodStart != weekStart ||
        current.periodEnd != weekEnd) {
      final normalized = AiCoachUsage(
        plan: current.plan,
        messagesUsed: current.messagesUsed,
        messagesLimit: _weeklyChatLimit,
        periodStart: weekStart,
        periodEnd: weekEnd,
      );
      await _repository.saveUsage(normalized, uid: uid);
      return normalized;
    }
    return current;
  }

  Future<bool> _tryLocalWeekdayMoveFallback({
    required String uid,
    required String athleteMessage,
  }) async {
    final normalized = athleteMessage.toLowerCase();
    final sourceDay = _extractWeekdayFromText(
      normalized,
      preferFromTokens: const ['de ', 'del ', 'mover ', 'cambiar '],
    );
    final targetDay = _extractWeekdayFromText(
      normalized,
      preferFromTokens: const [' a ', ' al ', ' para ', ' al dia '],
      pickLast: true,
    );
    if (sourceDay == null || targetDay == null || sourceDay == targetDay) {
      return false;
    }

    final nextWeekSessions = await _loadNextWeekSessionsRaw(uid);
    final sourceCandidates = nextWeekSessions.where((session) {
      final date = DateTime.tryParse(session.date);
      if (date == null) return false;
      return date.weekday == sourceDay &&
          session.status == AthleteSessionStatus.planned;
    }).toList();
    if (sourceCandidates.isEmpty) return false;

    final weekStart = _mondayOf(DateTime.now()).add(const Duration(days: 7));
    final targetDate = weekStart.add(Duration(days: targetDay - 1));
    final targetDateKey = _dateKey(targetDate);
    final targetOccupied = nextWeekSessions.any((session) {
      final date = DateTime.tryParse(session.date);
      if (date == null) return false;
      return date.weekday == targetDay &&
          session.status == AthleteSessionStatus.planned;
    });
    if (targetOccupied) return false;

    final moving = sourceCandidates.first;
    await _sessionRepository.updateSession(
      moving.copyWith(
        date: targetDateKey,
        updatedAt: DateTime.now(),
        suggestion: moving.suggestion?.copyWith(
          responseNote: 'moved_by_chat_fallback_${sourceDay}_to_$targetDay',
          respondedAt: DateTime.now(),
        ),
      ),
    );
    await _repository.logEvent(
      uid: uid,
      eventType: 'chat_fallback_weekday_move',
      payload: {
        'sessionId': moving.id,
        'fromWeekday': sourceDay,
        'toWeekday': targetDay,
        'fromDate': moving.date,
        'toDate': targetDateKey,
      },
    );
    return true;
  }

  Future<List<AthleteSession>> _loadNextWeekSessionsRaw(String uid) async {
    final anchor = DateTime.now();
    final monday = _mondayOf(anchor).add(const Duration(days: 7));
    final sunday = monday.add(const Duration(days: 6));
    final sessions = await _sessionRepository.getSessionsInRange(
      uid: uid,
      startDate: _dateKey(monday),
      endDate: _dateKey(sunday),
    );
    sessions.sort((a, b) {
      final dateCompare = a.date.compareTo(b.date);
      if (dateCompare != 0) return dateCompare;
      return (a.time ?? '').compareTo(b.time ?? '');
    });
    return sessions;
  }

  DateTime _mondayOf(DateTime value) {
    final date = DateTime(value.year, value.month, value.day);
    return date.subtract(Duration(days: date.weekday - 1));
  }

  int? _extractWeekdayFromText(
    String text, {
    required List<String> preferFromTokens,
    bool pickLast = false,
  }) {
    const weekdayTokens = <int, List<String>>{
      DateTime.monday: ['lunes'],
      DateTime.tuesday: ['martes'],
      DateTime.wednesday: ['miercoles', 'miércoles'],
      DateTime.thursday: ['jueves'],
      DateTime.friday: ['viernes'],
      DateTime.saturday: ['sabado', 'sábado'],
      DateTime.sunday: ['domingo'],
    };

    final hits = <MapEntry<int, int>>[];
    weekdayTokens.forEach((weekday, tokens) {
      for (final token in tokens) {
        final idx = text.indexOf(token);
        if (idx >= 0) {
          hits.add(MapEntry(weekday, idx));
        }
      }
    });
    if (hits.isEmpty) return null;

    hits.sort((a, b) => a.value.compareTo(b.value));
    for (final token in preferFromTokens) {
      final tokenIndex = text.indexOf(token);
      if (tokenIndex < 0) continue;
      final candidate = pickLast
          ? hits.where((h) => h.value > tokenIndex).toList()
          : hits.where((h) => h.value >= tokenIndex).toList();
      if (candidate.isNotEmpty) {
        return pickLast ? candidate.last.key : candidate.first.key;
      }
    }
    return pickLast ? hits.last.key : hits.first.key;
  }
}
