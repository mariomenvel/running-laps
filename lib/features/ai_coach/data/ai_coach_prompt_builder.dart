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
        OpenRouterChatMessage(
          role: 'system',
          content: _buildDecisionSystemPrompt(context.profile),
        ),
        OpenRouterChatMessage(
          role: 'user',
          content: jsonEncode(_jsonSafe(_contextPayload(context))),
        ),
      ],
      jsonSchema: _weeklyDecisionSchema,
    );
  }

  String _buildDecisionSystemPrompt(AiCoachProfile? profile) {
    final base =
        'Eres un entrenador profesional de running especializado en planificacion semanal de resistencia.'
        ' Tomas decisiones conservadoras, coherentes y progresivas.'
        ' Priorizas adherencia, gestion de fatiga, sobrecarga progresiva, semanas de descarga, taper y prevencion de lesion.'
        ' athleteProfile.preferredWeeklySessions es la preferencia habitual del atleta, pero puede superarse si el atleta lo solicita explícitamente en observaciones o si hay una razón deportiva clara (semana de carga, recuperación activa, etc.).'
        ' Si el contexto muestra paron, baja adherencia o detraining, debes reiniciar de forma gradual aunque el objetivo sea ambicioso.'
        ' Usa coachSignals y recentWeekHistory para detectar si el atleta suele responder mejor a series, tempo, fartlek o carrera continua.'
        ' Mantente alineado con el estilo real del atleta salvo que haya una razon deportiva clara para cambiarlo.'
        ' Si el atleta viene de entrenamientos estructurados, puedes proponer sesiones complejas. Si no, progresa la complejidad poco a poco.'
        ' No generes entrenamientos completos. Devuelve solo una decision semanal estructurada para que otro motor genere las sesiones.'
        ' Si el campo observaciones contiene una peticion concreta'
        ' (ej: "quiero entrenar el viernes", "esta semana 3 sesiones",'
        ' "necesito descansar el martes"), tratala como ORDEN del atleta'
        ' y reflejala en la decision semanal sin excepcion.\n'
        'Las categorías válidas para workoutTargets.category son '
        'EXCLUSIVAMENTE: series_cortas, series_largas, series_cuestas, '
        'series_mixtas, fartlek, tempo, rodaje_base, rodaje_largo, '
        'regenerativo, gimnasio_fuerza, test, competicion. '
        'NO uses otras categorías. Si el atleta pide "cuestas", '
        'usa "series_cuestas". Si pide "gimnasio" o "fuerza", '
        'usa "gimnasio_fuerza". Si pide "largo", usa "rodaje_largo".\n'
        'RESTRICCIONES RECURRENTES: Si athleteProfile.recurringConstraints '
        'contiene una restricción, DEBES incluirla en el plan TODAS las semanas '
        'sin excepción. Si la restricción dice "cuestas a la semana", '
        'uno de los workoutTargets DEBE tener category="series_cuestas". '
        'Las restricciones recurrentes tienen la misma prioridad que '
        'los mandatos del atleta en observaciones.\n'
        'Cada entrenamiento en recentTrainings puede incluir '
        'paceCompliance (% de cumplimiento del ritmo objetivo), '
        'execution ("más duro/fácil de lo esperado") y targetRpe. '
        'Usa estos datos para calibrar la dificultad real de las '
        'sesiones. Si el atleta consistentemente supera el RPE objetivo, '
        'reduce la intensidad. Si va más fácil de lo esperado, '
        'puedes progresar más agresivamente.\n'
        ' Responde unicamente con JSON valido que cumpla el esquema.';

    if (profile != null && profile.availableWeekdays.isNotEmpty) {
      final dayNames = _weekdayNamesList(profile.availableWeekdays);
      return '$base'
          ' IMPORTANTE: El atleta SOLO puede entrenar los dias: $dayNames.'
          ' Distribuye las sesiones UNICAMENTE en esos dias.'
          ' No pongas sesiones en otros dias.'
          ' Si el atleta tiene restricciones recurrentes o notas del entrenador (coachNotes),'
          ' respeta siempre esas preferencias al asignar dias.';
    }
    return base;
  }

  String _weekdayNamesList(List<int> weekdays) {
    const names = ['', 'lunes', 'martes', 'miercoles',
        'jueves', 'viernes', 'sabado', 'domingo'];
    final sorted = [...weekdays]..sort();
    return sorted.map((d) => d >= 1 && d <= 7 ? names[d] : '').join(', ');
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
      'weekdayMapping': {
        'lunes': 1, 'martes': 2, 'miercoles': 3, 'miércoles': 3,
        'jueves': 4, 'viernes': 5, 'sabado': 6, 'sábado': 6,
        'domingo': 7,
      },
      'currentWeekSessions': nextWeekSessions.map((s) {
        final date = DateTime.parse(s['date'] as String);
        return {
          'weekday': date.weekday,
          'dayName': _weekdayName(date.weekday),
          'category': s['category'],
          'date': s['date'],
        };
      }).toList(),
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
              ' Clasifica el intent del mensaje del atleta UNICAMENTE en uno de estos intents (lista cerrada):'
              ' - "move": mover/cambiar una sesion de un dia a otro.'
              '   -> localAction: sourceWeekday + targetWeekday.'
              ' - "cancel": eliminar/cancelar la sesion de un dia.'
              '   -> localAction: sourceWeekday.'
              ' - "complete": marcar una sesion como hecha/completada.'
              '   -> localAction: sourceWeekday.'
              ' - "adjust_session": bajar o subir la intensidad de una sesion concreta de un dia.'
              '   -> localAction: sourceWeekday + intensityDelta (-1 para bajar, 1 para subir).'
              ' - "add_series": anadir series a una sesion (mas series, mas repeticiones, intensificar volumen de series).'
              '   -> localAction: sourceWeekday + seriesCount (numero de series a anadir, minimo 1).'
              ' - "remove_series": quitar series de una sesion (menos series, reducir repeticiones).'
              '   -> localAction: sourceWeekday + seriesCount (numero de series a quitar, minimo 1).'
              ' - "unsupported": cualquier cosa que NO encaje en los intents anteriores'
              '   (preguntas informativas, cambiar el objetivo del atleta, modificar varios dias a la vez,'
              '   regenerar la semana entera, preguntas no relacionadas con running, etc.).'
              '   -> localAction: null. En response responde la pregunta si es informativa, o explica brevemente'
              '   que SI puedes hacer: cambiar el dia de una sesion, subir o bajar su intensidad,'
              '   anadir o quitar series, o eliminarla.'
              ' Para todos los intents, decisionOverride siempre es null.'
              ' response debe ser siempre en espanol, claro y breve, explicando que va a hacer o respondiendo la pregunta.'
              ' IMPORTANTE: usa el campo weekday de currentWeekSessions para sourceWeekday — NO lo calcules tu mismo.'
              ' Si el atleta dice "el jueves" y en currentWeekSessions hay una sesion con weekday=4 y dayName="jueves", usa sourceWeekday=4.'
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
      if (context.weeklyFeedback != null)
        'weeklyFeedback': {
          'sensaciones': context.weeklyFeedback!.sensaciones,
          'sueno': context.weeklyFeedback!.sueno,
          if (context.weeklyFeedback!.molestias != null)
            'molestias': context.weeklyFeedback!.molestias,
          if (context.weeklyFeedback!.motivoParon != null) ...{
            'motivoParon': context.weeklyFeedback!.motivoParon,
            if (context.weeklyFeedback!.motivoParon == 'lesion')
              'instruccionParon':
                  'MANDATO: El atleta paró por lesión. Sé especialmente '
                  'conservador: empieza con volumen e intensidad muy bajos, '
                  'prioriza rodajes suaves y regenerativos, y evita series '
                  'o cargas altas hasta confirmar que la molestia ha desaparecido.',
          },
          if (context.weeklyFeedback!.observaciones != null) ...{
            'observaciones': context.weeklyFeedback!.observaciones,
            'instruccionObservaciones':
                'MANDATO PRIORITARIO: Si el atleta indica en observaciones '
                'dias concretos, numero de sesiones, o cualquier restriccion '
                'o preferencia explicita para esta semana, DEBES respetarlo '
                'por encima de cualquier otra consideracion. '
                'Tiene prioridad sobre el perfil, la fatiga y el plan habitual.',
          },
          'instrucciones':
              [
                'Ten muy en cuenta este feedback al generar el plan de la semana siguiente.',
                if (context.weeklyFeedback!.sensaciones <= 2 ||
                    context.weeklyFeedback!.molestias != null)
                  'El atleta tuvo una semana difícil o tiene molestias: reduce la carga y la intensidad.',
                if (context.weeklyFeedback!.sensaciones >= 4 &&
                    context.weeklyFeedback!.sueno == 'bien')
                  'El atleta se sintió bien y durmió bien: puedes aumentar ligeramente la carga.',
              ].join(' '),
        },
      if (context.recentFeedbacks.length >= 2)
        'feedbackTendencias': () {
          final feedbacks = context.recentFeedbacks;
          final avgSensaciones = feedbacks
                  .map((f) => f.sensaciones)
                  .reduce((a, b) => a + b) /
              feedbacks.length;
          final malSueno =
              feedbacks.where((f) => f.sueno == 'mal').length;
          final conMolestias = feedbacks
              .where((f) => f.molestias != null && f.molestias!.isNotEmpty)
              .toList();

          final instrucciones = <String>[];
          if (malSueno >= 2) {
            instrucciones.add(
              'ATENCIÓN: el atleta ha dormido mal $malSueno de las últimas '
              '${feedbacks.length} semanas. Considera reducir la carga.',
            );
          }
          if (conMolestias.length >= 2) {
            final detalle = conMolestias
                .map((f) => 'semana ${f.weekStart}: ${f.molestias}')
                .join('; ');
            instrucciones.add(
              'ATENCIÓN: molestias recurrentes ($detalle). '
              'Prioriza la prevención de lesiones.',
            );
          }
          if (avgSensaciones <= 2.5) {
            instrucciones.add(
              'El atleta lleva varias semanas sintiéndose mal. '
              'Reduce intensidad y prioriza recuperación.',
            );
          } else if (avgSensaciones >= 4.0) {
            instrucciones.add(
              'El atleta se siente bien de forma sostenida. '
              'Puede asumir progresión de carga.',
            );
          }

          return {
            'semanas': feedbacks.length,
            'mediaSensaciones': double.parse(avgSensaciones.toStringAsFixed(1)),
            if (instrucciones.isNotEmpty) 'instrucciones': instrucciones,
          };
        }(),
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

  String _weekdayName(int weekday) {
    const names = ['', 'lunes', 'martes', 'miércoles',
        'jueves', 'viernes', 'sábado', 'domingo'];
    return names[weekday];
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
      'targetSessions': {'type': 'integer'},
      'targetVolumeKm': {'type': 'number'},
      'targetLoad': {'type': 'number'},
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
            'priority': {'type': 'integer'},
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
    'required': ['intent', 'response', 'localAction'],
    'properties': {
      'intent': {
        'type': 'string',
        'enum': ['move', 'cancel', 'complete', 'adjust_session', 'add_series', 'remove_series', 'unsupported'],
      },
      'response': {'type': 'string'},
      'localAction': {
        'anyOf': [
          {'type': 'null'},
          {
            'type': 'object',
            'additionalProperties': false,
            'required': ['type', 'sourceWeekday'],
            'properties': {
              'type': {
                'type': 'string',
                'enum': ['move', 'cancel', 'complete', 'adjust_session', 'add_series', 'remove_series'],
              },
              'sourceWeekday': {'type': 'integer'},
              'targetWeekday': {'type': 'integer'},
              'intensityDelta': {'type': 'integer', 'enum': [-1, 1]},
              'seriesCount': {'type': 'integer'},
            },
          },
        ],
      },
    },
  };
}
