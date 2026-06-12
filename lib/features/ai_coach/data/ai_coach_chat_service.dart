import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:running_laps/features/ai_coach/data/ai_coach_context_builder.dart';
import 'package:running_laps/features/ai_coach/data/ai_coach_models.dart';
import 'package:running_laps/features/ai_coach/data/ai_coach_models_config.dart';
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

  /// Genera un preview del ajuste SIN aplicarlo.
  /// No gasta cuota de ajustes, pero suma al contador de previews (anti-abuso).
  Future<AiCoachAdjustmentPreview> previewAdjustment({
    required String uid,
    required String athleteMessage,
    required DateTime targetWeekStart,
  }) async {
    final isAthleteMode = await _userService.getIsAthleteMode(uid);
    if (!isAthleteMode) {
      return AiCoachAdjustmentPreview.limitReached(
        'El Entrenador IA solo está disponible con modo atleta activado.',
      );
    }

    final provider = await _repository.getProviderConfig(uid: uid);
    if (provider == null ||
        !provider.chatAdjustmentsEnabled ||
        provider.provider != 'openrouter' ||
        (provider.apiKey == null || provider.apiKey!.trim().isEmpty)) {
      return AiCoachAdjustmentPreview.limitReached(
        'Ajustes IA no configurados.',
      );
    }

    final usageBeforeLlm = await _prepareAndGetCurrentWeekUsage(uid);

    if (usageBeforeLlm.previewsGenerated >= 10) {
      return AiCoachAdjustmentPreview.limitReached(
        'Has alcanzado el máximo de peticiones esta semana. '
        'Inténtalo de nuevo la semana que viene.',
      );
    }

    try {
      final llmResult = await _callLlmForAdjustment(
        uid: uid,
        athleteMessage: athleteMessage,
        targetWeekStart: targetWeekStart,
        provider: provider,
      );

      final intent = llmResult.intent;
      final localAction = llmResult.localAction;

      // Siempre suma al contador anti-abuso, sea info o no
      debugPrint('[Cuota] preview: previewsGenerated ${usageBeforeLlm.previewsGenerated} → ${usageBeforeLlm.previewsGenerated + 1}');
      await _repository.incrementUsageField(
        uid: uid,
        field: 'previewsGenerated',
        periodStart: usageBeforeLlm.periodStart,
        periodEnd: usageBeforeLlm.periodEnd,
      );

      // Para ajustes reales, comprobar cuota de mensajes DESPUÉS de conocer intent
      if (intent != AiCoachAdjustIntent.unsupported) {
        final usageNow = await _prepareAndGetCurrentWeekUsage(uid);
        final limit = usageNow.messagesLimit ?? _weeklyChatLimit;
        if (usageNow.messagesUsed >= limit) {
          return AiCoachAdjustmentPreview(
            response: '${llmResult.response}\n\n'
                'Pero ya has usado tus $limit ajustes de esta semana. '
                'Podrás aplicar cambios la semana que viene.',
            intent: intent,
            willModifyPlan: false,
            decisionOverride: null,
            localAction: null,
          );
        }
      }

      return AiCoachAdjustmentPreview(
        response: llmResult.response,
        willModifyPlan: intent != AiCoachAdjustIntent.unsupported,
        intent: intent,
        localAction: localAction,
      );
    } catch (e) {
      throw Exception(
        'Fallo al generar preview: ${e.toString().replaceFirst('Exception: ', '')}',
      );
    }
  }

  /// Aplica un ajuste previamente generado en preview.
  /// Gasta 1 de la cuota de ajustes (3/semana).
  Future<bool> applyAdjustment({
    required String uid,
    required AiCoachAdjustmentPreview preview,
    required DateTime targetWeekStart,
  }) async {
    debugPrint('[Cuota] applyAdjustment llamado, intent=${preview.intent}, localAction=${preview.localAction?.type}');
    try {
      var didModify = false;

      if (preview.localAction != null) {
        await _applyLocalAction(uid, preview.localAction!, targetWeekStart);
        didModify = true;
      }

      if (didModify) {
        final usage = await _prepareAndGetCurrentWeekUsage(uid);
        debugPrint('[Cuota] apply: didModify=$didModify, messagesUsed ${usage.messagesUsed} → ${usage.messagesUsed + 1}');
        await _repository.incrementUsageField(
          uid: uid,
          field: 'messagesUsed',
          periodStart: usage.periodStart,
          periodEnd: usage.periodEnd,
        );
      }

      return didModify;
    } catch (e) {
      debugPrint('[AiCoachChat] applyAdjustment error: $e');
      rethrow;
    }
  }

  Future<void> _applyLocalAction(
    String uid,
    AiCoachLocalAction action,
    DateTime weekStart,
  ) async {
    final monday = _mondayOf(weekStart);
    final sunday = monday.add(const Duration(days: 6));
    final sessions = await _sessionRepository.getSessionsInRange(
      uid: uid,
      startDate: _dateKey(monday),
      endDate: _dateKey(sunday),
    );

    final sourceDate = monday.add(Duration(days: action.sourceWeekday - 1));
    final sourceDateKey = _dateKey(sourceDate);
    final sourceSessions = sessions
        .where((s) =>
            s.status == AthleteSessionStatus.planned && s.date == sourceDateKey)
        .toList();

    if (sourceSessions.isEmpty) {
      final completedThatDay = sessions.any((s) =>
          s.status == AthleteSessionStatus.completed && s.date == sourceDateKey);
      if (completedThatDay) {
        throw Exception('No se pueden modificar sesiones ya completadas');
      }
      throw Exception('No hay sesión planificada ese día');
    }
    final session = sourceSessions.first;

    switch (action.type) {
      case 'move':
        if (action.targetWeekday == null) return;
        final targetDate = monday.add(Duration(days: action.targetWeekday! - 1));
        await _sessionRepository.updateSession(
          session.copyWith(date: _dateKey(targetDate), updatedAt: DateTime.now()),
        );
        break;
      case 'cancel':
        await _sessionRepository.deleteSession(
          uid: uid,
          id: session.id,
        );
        break;
      case 'complete':
        await _sessionRepository.updateSession(
          session.copyWith(
            status: AthleteSessionStatus.completed,
            updatedAt: DateTime.now(),
          ),
        );
        break;
      case 'adjust_session':
        final delta = action.intensityDelta ?? -1;
        await _adjustSessionIntensity(uid, session, delta);
        break;
      case 'add_series':
        await _changeSeriesCount(uid, session, action.seriesCount ?? 1);
        break;
      case 'remove_series':
        await _changeSeriesCount(uid, session, -(action.seriesCount ?? 1));
        break;
    }
  }

  Future<void> _changeSeriesCount(
    String uid,
    AthleteSession session,
    int delta,
  ) async {
    final updatedBlocks = session.blocks.map((block) {
      if (block.type != SessionBlockType.series) return block;
      final currentReps = block.reps ?? 1;
      final newReps = (currentReps + delta).clamp(1, 20);
      return block.copyWith(reps: newReps);
    }).toList();

    final cleanTitle = (session.title ?? '')
        .replaceAll(' · ajustada', '')
        .replaceAll(' · intensificada', '')
        .replaceAll(RegExp(r' · \d+ series'), '')
        .trim();

    final mainBlock = updatedBlocks.firstWhere(
      (b) => b.type == SessionBlockType.series,
      orElse: () => updatedBlocks.first,
    );
    final newTitle = '$cleanTitle · ${mainBlock.reps ?? 1} series';

    await _sessionRepository.updateSession(
      session.copyWith(
        blocks: updatedBlocks,
        title: newTitle,
        updatedAt: DateTime.now(),
      ),
    );
  }

  Future<void> _adjustSessionIntensity(
    String uid,
    AthleteSession session,
    int delta,
  ) async {
    final updatedBlocks = session.blocks.map((block) {
      double? newRpe = block.targetRpe;
      if (newRpe != null) {
        newRpe = (newRpe + delta * 2.0).clamp(1.0, 10.0);
      }

      int? newZone = block.targetZone;
      if (newZone != null) {
        newZone = (newZone + delta).clamp(1, 5);
      }

      // Pace: más lento cuando baja intensidad (delta<0 → sumar segundos)
      // Convertir min:sec → segundos totales, ajustar ±15s, descomponer
      int? newPaceMinMin = block.targetPaceMinMin;
      int? newPaceMinSec = block.targetPaceMinSec;
      int? newPaceMaxMin = block.targetPaceMaxMin;
      int? newPaceMaxSec = block.targetPaceMaxSec;

      if (newPaceMinMin != null && newPaceMinSec != null) {
        final totalSec = (newPaceMinMin * 60 + newPaceMinSec - delta * 15)
            .clamp(120, 600); // 2:00–10:00 min/km
        newPaceMinMin = totalSec ~/ 60;
        newPaceMinSec = totalSec % 60;
      }
      if (newPaceMaxMin != null && newPaceMaxSec != null) {
        final totalSec = (newPaceMaxMin * 60 + newPaceMaxSec - delta * 15)
            .clamp(120, 600);
        newPaceMaxMin = totalSec ~/ 60;
        newPaceMaxSec = totalSec % 60;
      }

      return block.copyWith(
        targetRpe: newRpe,
        targetZone: newZone,
        targetPaceMinMin: newPaceMinMin,
        targetPaceMinSec: newPaceMinSec,
        targetPaceMaxMin: newPaceMaxMin,
        targetPaceMaxSec: newPaceMaxSec,
      );
    }).toList();

    final noteText = delta < 0
        ? 'El atleta encontró esta sesión demasiado dura'
        : 'El atleta pidió más intensidad en esta sesión';

    final currentTitle = session.title ?? '';
    final cleanTitle = currentTitle
        .replaceAll(' · ajustada', '')
        .replaceAll(' · intensificada', '')
        .trim();
    final newTitle = delta < 0
        ? '$cleanTitle · ajustada'
        : '$cleanTitle · intensificada';

    await _sessionRepository.updateSession(
      session.copyWith(
        title: newTitle,
        blocks: updatedBlocks,
        athleteNote: noteText,
        updatedAt: DateTime.now(),
      ),
    );
  }

  /// Compatibilidad con el settings view actual.
  /// Internamente hace preview + apply en un solo paso.
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
      final nextWeekMonday = _mondayOf(DateTime.now()).add(const Duration(days: 7));
      final result = await _callLlmForAdjustment(
        uid: uid,
        athleteMessage: athleteMessage,
        targetWeekStart: nextWeekMonday,
        provider: provider,
      );

      await _repository.incrementUsageField(
        uid: uid,
        field: 'messagesUsed',
        periodStart: usage.periodStart,
        periodEnd: usage.periodEnd,
      );

      if (result.decisionOverride != null) {
        await _weeklyPlannerService.planNextWeek(
          uid,
          decisionOverride: result.decisionOverride,
          targetWeekStart: nextWeekMonday,
        );
        await _repository.saveLastDecision(result.decisionOverride!, uid: uid);
      } else {
        final moved = await _tryLocalWeekdayMoveFallback(
          uid: uid,
          athleteMessage: athleteMessage,
        );
        if (moved) {
          return AiCoachChatAdjustmentResult(
            response: result.response.isEmpty
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

  /// Llama al LLM y devuelve la decisión propuesta sin aplicarla ni tocar la cuota.
  Future<AiCoachChatAdjustmentResult> _callLlmForAdjustment({
    required String uid,
    required String athleteMessage,
    required DateTime targetWeekStart,
    required AiCoachProviderConfig provider,
  }) async {
    final context = await _contextBuilder.buildWeeklyContext(uid);
    final currentDecision = await _repository.getLastDecision(uid: uid);
    final sessions = await _loadSessionsForWeek(uid, targetWeekStart);
    final prompt = _promptBuilder.buildChatAdjustmentPrompt(
      context,
      athleteMessage: athleteMessage,
      nextWeekSessions: sessions,
      currentDecision: currentDecision,
    );

    final completion = await _openRouterClient.createJsonCompletion(
      apiKey: provider.apiKey!.trim(),
      model: AiCoachModels.chatClassify,
      messages: prompt.messages,
      jsonSchema: prompt.jsonSchema,
    );

    final rawResponse = completion.content;
    debugPrint('[Adjust] respuesta LLM raw: $rawResponse');
    final parsed = _parseJsonObject(rawResponse);
    return _buildResultFromResponse(parsed, fallbackModel: AiCoachModels.chatClassify);
  }

  Future<List<Map<String, dynamic>>> _loadSessionsForWeek(
    String uid,
    DateTime weekStart,
  ) async {
    final monday = _mondayOf(weekStart);
    final sunday = monday.add(const Duration(days: 6));
    final sessions = await _sessionRepository.getSessionsInRange(
      uid: uid,
      startDate: _dateKey(monday),
      endDate: _dateKey(sunday),
    );
    sessions.sort((a, b) {
      final d = a.date.compareTo(b.date);
      return d != 0 ? d : (a.time ?? '').compareTo(b.time ?? '');
    });
    return sessions.map((s) => {
      'sessionId': s.id,
      'date': s.date,
      'time': s.time,
      'category': s.category,
      'status': s.status.toValue,
      'suggestionStatus': s.suggestion?.status.toValue,
      'planningNotes': s.planningNotes,
    }).toList();
  }

  Map<String, dynamic> _parseJsonObject(String raw) {
    final trimmed = raw.trim();
    try {
      return Map<String, dynamic>.from(jsonDecode(trimmed) as Map);
    } catch (e) {
      debugPrint('[Adjust] error parseando JSON: $e');
      debugPrint('[Adjust] contenido que falló: $trimmed');
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
    final rawResponseText = (map['response'] as String?)?.trim() ?? '';
    final isCorrupt = rawResponseText.length < 10 ||
        rawResponseText
            .replaceAll(RegExp(r'[^\w\sáéíóúñ]'), '')
            .trim()
            .isEmpty;

    final intent = AiCoachAdjustIntentX.fromValue(map['intent'] as String? ?? '');

    final localActionMap = map['localAction'];
    final localAction = localActionMap is Map<String, dynamic>
        ? AiCoachLocalAction.fromMap(localActionMap)
        : null;

    final overrideMap = map['decisionOverride'];

    if (overrideMap is! Map) {
      return AiCoachChatAdjustmentResult(
        response: rawResponseText,
        intent: intent,
        localAction: localAction,
      );
    }

    final rawDecision = Map<String, dynamic>.from(overrideMap);
    final generatedAt = DateTime.now();
    final decision = AiCoachWeeklyDecision.fromMap({
      'id': rawDecision['id'] ?? generatedAt.millisecondsSinceEpoch.toString(),
      'generatedAt': rawDecision['generatedAt'] ?? generatedAt.toIso8601String(),
      'sourceModel': rawDecision['sourceModel'] ?? fallbackModel,
      ...rawDecision,
    });

    final responseText =
        isCorrupt ? _buildChangeDescription(decision) : rawResponseText;

    return AiCoachChatAdjustmentResult(
      response: responseText,
      decisionOverride: decision,
      intent: intent,
      localAction: localAction,
    );
  }

  String _buildChangeDescription(AiCoachWeeklyDecision decision) {
    final parts = <String>[];

    switch (decision.weekType) {
      case AiCoachWeekType.recovery:
        parts.add('He preparado una semana de recuperación más suave.');
      case AiCoachWeekType.build:
        parts.add('He preparado una semana de aumento de carga.');
      case AiCoachWeekType.taper:
        parts.add('He preparado una semana de descarga progresiva (taper).');
      case AiCoachWeekType.race:
        parts.add('He preparado la semana de competición.');
      case AiCoachWeekType.restart:
        parts.add('He preparado una semana de reactivación.');
      case AiCoachWeekType.absorb:
        parts.add('He preparado una semana de asimilación.');
    }

    parts.add('${decision.targetSessions} sesiones esta semana.');

    if (decision.primaryFocus.isNotEmpty) {
      parts.add('Enfoque: ${decision.primaryFocus}.');
    }

    if (decision.workoutTargets.isNotEmpty) {
      final categorias =
          decision.workoutTargets.map((t) => _categoryLabel(t.category)).toList();
      parts.add('Incluye: ${categorias.join(', ')}.');
    }

    return parts.join(' ');
  }

  String _categoryLabel(String category) {
    switch (category) {
      case 'rodaje_base':
        return 'rodaje suave';
      case 'series_medias':
        return 'series medias';
      case 'series_cortas':
        return 'series cortas';
      case 'series_largas':
        return 'series largas';
      case 'series_cuestas':
        return 'cuestas';
      case 'tempo':
        return 'tempo';
      case 'fartlek':
        return 'fartlek';
      default:
        return category.replaceAll('_', ' ');
    }
  }

  String _dateKey(DateTime value) {
    return '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
  }

  Future<AiCoachUsage> _prepareAndGetCurrentWeekUsage(String uid) async {
    final now = DateTime.now();
    final weekStart = _mondayOf(now);
    final sundayStart = weekStart.add(const Duration(days: 6));
    final weekEnd = DateTime(
      sundayStart.year,
      sundayStart.month,
      sundayStart.day,
      23, 59, 59,
    );
    final current = await _repository.getUsage(uid: uid);
    debugPrint('[Prep] usage leído: used=${current?.messagesUsed}, prev=${current?.previewsGenerated}');
    debugPrint('[Prep] periodStart=${current?.periodStart}, periodEnd=${current?.periodEnd}');
    debugPrint('[Prep] now=${DateTime.now()}');
    debugPrint('[Prep] ¿resetear? current==null: ${current == null}, '
        'periodStart.isAfter(now): ${current?.periodStart.isAfter(DateTime.now())}, '
        'periodEnd.isBefore(now): ${current?.periodEnd.isBefore(DateTime.now())}');
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
