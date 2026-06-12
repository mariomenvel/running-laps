import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:running_laps/features/ai_coach/data/ai_coach_context_builder.dart';
import 'package:running_laps/features/ai_coach/data/ai_coach_models_config.dart';
import 'package:running_laps/features/ai_coach/data/ai_coach_models.dart';
import 'package:running_laps/features/ai_coach/data/ai_coach_prompt_builder.dart';
import 'package:running_laps/features/ai_coach/data/ai_coach_repository.dart';
import 'package:running_laps/features/ai_coach/data/openrouter_client.dart';

class AiCoachDecisionService {
  AiCoachDecisionService({
    AiCoachContextBuilder? contextBuilder,
    AiCoachRepository? repository,
    AiCoachPromptBuilder? promptBuilder,
    OpenRouterClient? openRouterClient,
  })  : _contextBuilder = contextBuilder ?? AiCoachContextBuilder(),
        _repository = repository ?? AiCoachRepository(),
        _promptBuilder = promptBuilder ?? const AiCoachPromptBuilder(),
        _openRouterClient = openRouterClient ?? OpenRouterClient();

  final AiCoachContextBuilder _contextBuilder;
  final AiCoachRepository _repository;
  final AiCoachPromptBuilder _promptBuilder;
  final OpenRouterClient _openRouterClient;

  Future<AiCoachWeeklyDecision> generateWeeklyDecision(String uid) async {
    final provider = await _repository.getProviderConfig(uid: uid);
    if (provider == null ||
        !provider.weeklyPlanningEnabled ||
        provider.provider != 'openrouter' ||
        (provider.apiKey == null || provider.apiKey!.trim().isEmpty)) {
      throw Exception('Proveedor OpenRouter no configurado');
    }

    try {
      final context = await _contextBuilder.buildWeeklyContext(uid);
      final prompt = _promptBuilder.buildWeeklyDecisionPrompt(context);
      debugPrint('[Decision] system prompt: ${prompt.messages.first.content}');
      debugPrint('[Decision] payload: ${prompt.messages.last.content}');
      final completion = await _openRouterClient.createJsonCompletion(
        apiKey: provider.apiKey!.trim(),
        model: AiCoachModels.decision,
        messages: prompt.messages,
        jsonSchema: prompt.jsonSchema,
      );
      debugPrint('[Decision] respuesta LLM raw: ${completion.content}');

      final parsed = _parseJsonObject(completion.content);
      final decision = _buildDecisionFromResponse(
        parsed,
        fallbackModel: AiCoachModels.decision,
      );

      await _repository.saveWeeklyState(context.weeklyState, uid: uid);
      await _repository.saveLastDecision(decision, uid: uid);

      return decision;
    } catch (e) {
      throw Exception(
        'Fallo al generar la decision semanal con OpenRouter: '
        '${e.toString().replaceFirst('Exception: ', '')}',
      );
    }
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

  AiCoachWeeklyDecision _buildDecisionFromResponse(
    Map<String, dynamic> map, {
    required String fallbackModel,
  }) {
    final now = DateTime.now();
    final workoutTargets = (map['workoutTargets'] as List? ?? const [])
        .map((item) =>
            AiCoachWorkoutTarget.fromMap(Map<String, dynamic>.from(item as Map)))
        .toList();

    if (workoutTargets.isEmpty) {
      throw Exception('La IA no devolvió workoutTargets');
    }

    final decision = AiCoachWeeklyDecision(
      id: now.millisecondsSinceEpoch.toString(),
      generatedAt: now,
      sourceModel: fallbackModel,
      analysis: map['analysis'] as String? ?? '',
      adjustment: AiCoachAdjustmentTypeX.fromValue(
        map['adjustment'] as String? ?? '',
      ),
      weekType: AiCoachWeekTypeX.fromValue(
        map['weekType'] as String? ?? '',
      ),
      targetSessions: (map['targetSessions'] as num?)?.toInt() ?? 0,
      targetVolumeKm: (map['targetVolumeKm'] as num?)?.toDouble() ?? 0,
      targetLoad: (map['targetLoad'] as num?)?.toDouble() ?? 0,
      primaryFocus: map['primaryFocus'] as String? ?? '',
      restrictions: List<String>.from(
        map['restrictions'] as List? ?? const [],
      ),
      workoutTargets: workoutTargets,
    );

    return _sanitizeDecision(decision);
  }

  AiCoachWeeklyDecision _sanitizeDecision(AiCoachWeeklyDecision decision) {
    final targetSessions = decision.targetSessions.clamp(1, 7);
    final sanitizedTargets = decision.workoutTargets
        .where((target) => target.category.trim().isNotEmpty)
        .toList()
      ..sort((a, b) => a.priority.compareTo(b.priority));

    return AiCoachWeeklyDecision(
      id: decision.id,
      generatedAt: decision.generatedAt,
      sourceModel: decision.sourceModel,
      analysis: decision.analysis.trim(),
      adjustment: decision.adjustment,
      weekType: decision.weekType,
      targetSessions: targetSessions,
      targetVolumeKm: decision.targetVolumeKm < 0 ? 0 : decision.targetVolumeKm,
      targetLoad: decision.targetLoad < 0 ? 0 : decision.targetLoad,
      primaryFocus: decision.primaryFocus.trim(),
      restrictions: decision.restrictions.map((item) => item.trim()).where((item) => item.isNotEmpty).toList(),
      workoutTargets: sanitizedTargets,
    );
  }
}
