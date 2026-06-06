import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:running_laps/features/ai_coach/data/ai_coach_models.dart';
import 'package:running_laps/features/ai_coach/data/openrouter_client.dart';

class AiCoachPromptBundle {
  final List<OpenRouterChatMessage> messages;
  final Map<String, dynamic> jsonSchema;

  const AiCoachPromptBundle({
    required this.messages,
    required this.jsonSchema,
  });
}

class AiCoachPromptBuilder {
  const AiCoachPromptBuilder();

  AiCoachPromptBundle buildWeeklyDecisionPrompt(
    AiCoachWeeklyContext context,
  ) {
    return AiCoachPromptBundle(
      messages: [
        const OpenRouterChatMessage(
          role: 'system',
          content:
              'Eres un entrenador profesional de running especializado en planificacion semanal de resistencia.'
              ' Tomas decisiones conservadoras, coherentes y progresivas.'
              ' Priorizas adherencia, gestion de fatiga, sobrecarga progresiva, semanas de descarga, taper y prevencion de lesion.'
              ' Debes respetar estrictamente la disponibilidad semanal del atleta y no programar sesiones fuera de athleteProfile.availableWeekdays.'
              ' Si athleteProfile.preferredWeeklySessions existe, targetSessions no debe superarlo.'
              ' Si el contexto muestra paron, baja adherencia o detraining, debes reiniciar de forma gradual aunque el objetivo sea ambicioso.'
              ' Usa coachSignals y recentWeekHistory para detectar si el atleta suele responder mejor a series, tempo, fartlek o carrera continua.'
              ' Mantente alineado con el estilo real del atleta salvo que haya una razon deportiva clara para cambiarlo.'
              ' Si el atleta viene de entrenamientos estructurados, puedes proponer sesiones complejas. Si no, progresa la complejidad poco a poco.'
              ' No generes entrenamientos completos. Devuelve solo una decision semanal estructurada para que otro motor genere las sesiones.'
              ' Responde unicamente con JSON valido que cumpla el esquema.',
        ),
        OpenRouterChatMessage(
          role: 'user',
          content: jsonEncode(_jsonSafe(_contextPayload(context))),
        ),
      ],
      jsonSchema: _weeklyDecisionSchema,
    );
  }

  AiCoachPromptBundle buildChatAdjustmentPrompt(
    AiCoachWeeklyContext context, {
    required String athleteMessage,
    required List<Map<String, dynamic>> nextWeekSessions,
    AiCoachWeeklyDecision? currentDecision,
  }) {
    final payload = <String, dynamic>{
      ..._contextPayload(context),
      'athleteMessage': athleteMessage,
      'currentDecision':
          currentDecision == null ? null : _jsonSafe(currentDecision.toMap()),
      'nextWeekSessions': nextWeekSessions,
    };

    return AiCoachPromptBundle(
      messages: [
        const OpenRouterChatMessage(
          role: 'system',
          content:
              'Eres un entrenador profesional de running.'
              ' El atleta quiere ajustar el plan de la proxima semana.'
              ' Responde en espanol, con un tono claro y directo.'
              ' Debes seguir respetando estrictamente athleteProfile.availableWeekdays y el tiempo real sin entrenar.'
              ' Usa coachSignals y recentWeekHistory para mantener un estilo de entrenamiento coherente con el historial del atleta.'
              ' Si hace falta modificar el plan, devuelve una decisionOverride completa y coherente.'
              ' Si no hace falta tocar el plan, deja decisionOverride como null.'
              ' Nunca generes entrenamientos finales; solo la decision semanal estructurada.'
              ' Responde unicamente con JSON valido que cumpla el esquema.',
        ),
        OpenRouterChatMessage(
          role: 'user',
          content: jsonEncode(_jsonSafe(payload)),
        ),
      ],
      jsonSchema: _chatAdjustmentSchema,
    );
  }

  Map<String, dynamic> _contextPayload(AiCoachWeeklyContext context) {
    final profile = context.profile;
    return <String, dynamic>{
      'generatedAt': context.generatedAt.toIso8601String(),
      'athleteProfile': profile == null
          ? null
          : {
              'goal': profile.goal.toValue,
              'goalDescription': profile.goalDescription,
              'targetDate': profile.targetDate?.toIso8601String(),
              'level': profile.level.toValue,
              'availableWeekdays': profile.availableWeekdays,
              'preferredWeeklySessions': profile.preferredWeeklySessions,
              'preferredLongRunWeekday': profile.preferredLongRunWeekday,
              'recurringConstraints': profile.recurringConstraints
                  .map((item) => item.toMap())
                  .toList(),
              'temporaryStatuses': profile.temporaryStatuses
                  .where((item) => item.active)
                  .map((item) => item.toMap())
                  .toList(),
              'coachNotes': profile.coachNotes,
              if (profile.fcMax != null) 'fcMax': profile.fcMax,
            },
      'weeklyState': context.weeklyState.toMap(),
      'coachSignals': context.coachSignals,
      'recentWeekHistory': context.recentWeekHistory,
      'recentTrainings':
          context.recentTrainings.map((item) => item.toMap()).toList(),
      'recentPlannedSessions':
          context.recentPlannedSessions.map((item) => item.toMap()).toList(),
    };
  }

  dynamic _jsonSafe(dynamic value) {
    if (value == null ||
        value is String ||
        value is num ||
        value is bool) {
      return value;
    }
    if (value is DateTime) {
      return value.toIso8601String();
    }
    if (value is Timestamp) {
      return value.toDate().toIso8601String();
    }
    if (value is Map) {
      return value.map(
        (key, item) => MapEntry(key.toString(), _jsonSafe(item)),
      );
    }
    if (value is Iterable) {
      return value.map(_jsonSafe).toList();
    }
    return value.toString();
  }

  static const Map<String, dynamic> _weeklyDecisionSchema = {
    'type': 'object',
    'additionalProperties': false,
    'required': [
      'analysis',
      'adjustment',
      'weekType',
      'targetSessions',
      'targetVolumeKm',
      'targetLoad',
      'primaryFocus',
      'restrictions',
      'workoutTargets',
    ],
    'properties': {
      'analysis': {
        'type': 'string',
      },
      'adjustment': {
        'type': 'string',
        'enum': [
          'progress',
          'maintain',
          'reduce',
          'deload',
          'taper',
          'restart',
          'recover',
        ],
      },
      'weekType': {
        'type': 'string',
        'enum': [
          'build',
          'absorb',
          'recovery',
          'taper',
          'race',
          'restart',
        ],
      },
      'targetSessions': {
        'type': 'integer',
        'minimum': 1,
        'maximum': 7,
      },
      'targetVolumeKm': {
        'type': 'number',
        'minimum': 0,
      },
      'targetLoad': {
        'type': 'number',
        'minimum': 0,
      },
      'primaryFocus': {
        'type': 'string',
      },
      'restrictions': {
        'type': 'array',
        'items': {'type': 'string'},
      },
      'workoutTargets': {
        'type': 'array',
        'minItems': 1,
        'items': {
          'type': 'object',
          'additionalProperties': false,
          'required': [
            'category',
            'purpose',
            'priority',
          ],
          'properties': {
            'category': {'type': 'string'},
            'purpose': {'type': 'string'},
            'priority': {'type': 'integer', 'minimum': 1, 'maximum': 4},
            'preferredDay': {'type': 'string'},
            'targetLoad': {'type': 'number'},
            'targetDistanceKm': {'type': 'number'},
            'targetDurationMinutes': {'type': 'integer'},
            'notes': {'type': 'string'},
          },
        },
      },
    },
  };

  static const Map<String, dynamic> _chatAdjustmentSchema = {
    'type': 'object',
    'additionalProperties': false,
    'required': [
      'response',
      'decisionOverride',
    ],
    'properties': {
      'response': {'type': 'string'},
      'decisionOverride': {
        'anyOf': [
          {'type': 'null'},
          _weeklyDecisionSchema,
        ],
      },
    },
  };
}
