import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:running_laps/core/services/user_service.dart';
import 'package:running_laps/features/ai_coach/data/ai_coach_models_config.dart';
import 'package:running_laps/features/ai_coach/data/ai_coach_repository.dart';
import 'package:running_laps/features/ai_coach/data/openrouter_client.dart';
import 'package:running_laps/features/athlete/data/athlete_session_model.dart';
import 'package:running_laps/features/athlete/data/athlete_session_repository.dart';
import 'package:running_laps/features/training/data/entrenamiento.dart';

/// Genera el análisis post-sesión del Coach IA: compara lo planificado
/// con lo ejecutado y persiste un texto breve en el training.
/// Fire-and-forget — nunca debe romper el flujo de guardado.
class AiCoachSessionAnalysisService {
  AiCoachSessionAnalysisService({
    AiCoachRepository? repository,
    OpenRouterClient? openRouterClient,
    AthleteSessionRepository? sessionRepository,
    UserService? userService,
    FirebaseFirestore? firestore,
  })  : _repository = repository ?? AiCoachRepository(),
        _openRouterClient = openRouterClient ?? OpenRouterClient(),
        _sessionRepository = sessionRepository ?? AthleteSessionRepository(),
        _userService = userService ?? UserService(),
        _db = firestore ?? FirebaseFirestore.instance;

  final AiCoachRepository _repository;
  final OpenRouterClient _openRouterClient;
  final AthleteSessionRepository _sessionRepository;
  final UserService _userService;
  final FirebaseFirestore _db;

  static const _jsonSchema = {
    'type': 'object',
    'properties': {
      'analysis': {'type': 'string'},
    },
    'required': ['analysis'],
    'additionalProperties': false,
  };

  Future<String?> generateAnalysis({
    required String uid,
    required Entrenamiento entrenamiento,
    required AthleteSession plannedSession,
  }) async {
    try {
      final isAthleteMode = await _userService.getIsAthleteMode(uid);
      if (!isAthleteMode) return null;

      final provider = await _repository.getProviderConfig(uid: uid);
      if (provider.provider != 'openrouter') return null;

      final profile = await _repository.getProfile(uid: uid);
      final upcomingSessions = await _loadUpcomingSessionTitles(uid);

      final contextMap = _buildAnalysisContext(
        entrenamiento: entrenamiento,
        plannedSession: plannedSession,
        profile: profile,
        upcomingSessions: upcomingSessions,
      );

      const systemPrompt =
          'Eres el entrenador del atleta. Analiza esta sesión ejecutada '
          'frente a lo planificado. Responde en 3-5 frases: '
          '(1) desviación principal si la hay, '
          '(2) qué implica para su progreso/fatiga, '
          '(3) una indicación accionable mirando a las próximas sesiones. '
          'Sé directo y específico con los números. '
          'Si la ejecución fue fiel al plan, dilo y refuerza. '
          'Nunca inventes datos que no estén en el contexto.';

      final completion = await _openRouterClient.createJsonCompletion(
        model: AiCoachModels.decision,
        messages: [
          OpenRouterChatMessage(role: 'system', content: systemPrompt),
          OpenRouterChatMessage(
            role: 'user',
            content: jsonEncode(contextMap),
          ),
        ],
        jsonSchema: _jsonSchema,
        schemaName: 'session_analysis',
      );

      final analysisText = _extractAnalysisText(completion.content);
      if (analysisText == null || analysisText.trim().isEmpty) return null;

      final trainingId = entrenamiento.id;
      if (trainingId == null) return null;

      await _db
          .collection('users')
          .doc(uid)
          .collection('trainings')
          .doc(trainingId)
          .update({
        'coachAnalysis': {
          'text': analysisText,
          'generatedAt': DateTime.now().toUtc().toIso8601String(),
        },
      });

      return analysisText;
    } catch (e) {
      debugPrint('[AiCoachSessionAnalysisService] generateAnalysis error: $e');
      return null;
    }
  }

  String? _extractAnalysisText(String raw) {
    try {
      final trimmed = raw.trim();
      final start = trimmed.indexOf('{');
      final end = trimmed.lastIndexOf('}');
      if (start < 0 || end <= start) return null;
      final decoded = trimmed.substring(start, end + 1);

      // Intento principal: JSON válido
      try {
        final map = jsonDecode(decoded);
        final text = map is Map ? map['analysis'] : null;
        if (text is String && text.trim().isNotEmpty) return text;
      } catch (_) {
        // JSON malformado — caer al regex de abajo
      }

      final match = RegExp(r'"analysis"\s*:\s*"((?:[^"\\]|\\.)*)"')
          .firstMatch(decoded);
      if (match == null) return null;
      return match
          .group(1)!
          .replaceAll(r'\n', '\n')
          .replaceAll(r'\"', '"')
          .replaceAll(r'\\', r'\');
    } catch (_) {
      return null;
    }
  }

  Future<List<String>> _loadUpcomingSessionTitles(String uid) async {
    final now = DateTime.now();
    final sessions = await _sessionRepository.getSessionsInRange(
      uid: uid,
      startDate: _dateKey(now),
      endDate: _dateKey(now.add(const Duration(days: 7))),
    );
    return sessions
        .where((s) => s.status == AthleteSessionStatus.planned)
        .map((s) => '${s.date}: ${s.title ?? s.category ?? 'sesión'}')
        .toList();
  }

  Map<String, dynamic> _buildAnalysisContext({
    required Entrenamiento entrenamiento,
    required AthleteSession plannedSession,
    required dynamic profile,
    required List<String> upcomingSessions,
  }) {
    final seriesData = entrenamiento.series.map((s) => {
          'distanciaM': s.distanciaM,
          'tiempoSec': s.tiempoSec,
          'paceSecPerKm': s.ritmoSecPorKm(),
          'rpe': s.rpe,
          if (s.fcMedia != null) 'fcMedia': s.fcMedia,
        }).toList();

    final blocksData = plannedSession.blocks
        .map((b) => {
              'type': b.type.toValue,
              if (b.reps != null) 'reps': b.reps,
              if (b.distanceM != null) 'distanceM': b.distanceM,
              if (b.targetPaceMinMin != null || b.targetPaceMaxMin != null)
                'targetPace': {
                  'minMin': b.targetPaceMinMin,
                  'minSec': b.targetPaceMinSec,
                  'maxMin': b.targetPaceMaxMin,
                  'maxSec': b.targetPaceMaxSec,
                },
              if (b.targetRpe != null) 'targetRpe': b.targetRpe,
              if (b.targetZone != null) 'targetZone': b.targetZone,
            })
        .toList();

    return {
      'perfil': profile != null
          ? {
              'nivel': profile.level.toString(),
              'objetivo': profile.goal.toString(),
            }
          : null,
      'sesionPlanificada': {
        'titulo': plannedSession.title,
        'categoria': plannedSession.category,
        'bloques': blocksData,
      },
      'ejecutado': {
        'titulo': entrenamiento.titulo,
        'series': seriesData,
        'rpePromedio': entrenamiento.rpePromedio(),
      },
      'proximasSesiones': upcomingSessions,
    };
  }

  String _dateKey(DateTime value) {
    return '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
  }
}
