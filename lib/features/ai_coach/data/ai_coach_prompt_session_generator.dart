import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:running_laps/features/ai_coach/data/ai_coach_models.dart';
import 'package:running_laps/features/ai_coach/data/ai_coach_models_config.dart';
import 'package:running_laps/features/ai_coach/data/openrouter_client.dart';
import 'package:running_laps/features/templates/data/target_config.dart';
import 'package:running_laps/features/templates/data/workout_block.dart';
import 'package:running_laps/features/templates/data/workout_segment.dart';
import 'package:running_laps/features/templates/data/workout_session.dart';

class AiCoachPromptSessionGenerator {
  const AiCoachPromptSessionGenerator();

  Future<WorkoutSession> generate({
    required String prompt,
    AiCoachProfile? profile,
  }) async {
    final client = OpenRouterClient();
    final messages = _buildMessages(prompt: prompt, profile: profile);
    debugPrint('[Generator] llamando LLM...');
    final result = await client.createJsonCompletion(
      model: AiCoachModels.promptGenerator,
      messages: messages,
      jsonSchema: _sessionSchema,
      temperature: 0.4,
      schemaName: 'prompt_session',
    ).timeout(
      const Duration(seconds: 30),
      onTimeout: () {
        debugPrint('[Generator] TIMEOUT tras 30s');
        throw TimeoutException('El generador tardó demasiado. Inténtalo de nuevo.');
      },
    );
    debugPrint('[Generator] respuesta recibida: ${result.content.substring(0, result.content.length.clamp(0, 100))}');
    return _parseResult(result.content);
  }

  List<OpenRouterChatMessage> _buildMessages({
    required String prompt,
    AiCoachProfile? profile,
  }) {
    final profileContext = profile == null
        ? null
        : {
            'level': profile.level.toValue,
            'goal': profile.goal.toValue,
            if (profile.goalDescription.isNotEmpty)
              'goalDescription': profile.goalDescription,
            if (profile.fcMax != null) 'fcMax': profile.fcMax,
          };

    final userPayload = <String, dynamic>{
      'prompt': prompt,
      if (profileContext != null) 'athleteProfile': profileContext,
    };

    return [
      const OpenRouterChatMessage(
        role: 'system',
        content:
            'Eres un entrenador profesional de running.'
            ' El atleta describe con sus propias palabras el entrenamiento que quiere hacer hoy.'
            ' Genera una sesión estructurada con calentamiento, bloque(s) principal(es) y vuelta a la calma.'
            ' Sé conservador con la intensidad si el atleta es principiante.'
            ' Usa pace (seg/km) cuando el atleta mencione ritmos, distancias o tiempos concretos.'
            ' Usa rpe cuando el atleta solo mencione sensaciones o esfuerzo percibido.'
            ' Usa fcMaxPercent solo si mencionan frecuencia cardíaca.'
            ' Para alerts: solo incluye enabled=true si el usuario menciona'
            ' explícitamente avisos, beeps, metrónomo, o "cada X metros/segundos".'
            ' mode="time": beep cada timeSec segundos (ej: "avisa cada 30s" → timeSec=30).'
            ' mode="pace": beep cada segmentDistanceM metros'
            ' (ej: "avisos cada 100m" → mode="pace", segmentDistanceM=100).'
            ' En modo pace NO generes paceMin ni paceSec; el ritmo se toma del target.'
            ' Si no se mencionan avisos, omite el campo alerts o pon enabled=false.'
            ' REGLAS DE ESTRUCTURA DE BLOQUES:\n'
            '- Un rodaje continuo (continuous) SIEMPRE tiene exactamente'
            '  UN bloque main con UN segmento. Nunca múltiples bloques main.\n'
            '- Los intervalos (intervals) tienen UN bloque main con'
            '  repetitions > 1. Cada repetición alterna interval + recovery.'
            '  Ejemplo 5x400m: un bloque main con repetitions=5 y dos'
            '  segmentos: interval 400m + recovery.\n'
            '- Fartlek: UN bloque main con múltiples segmentos alternando'
            '  ritmos, sin repetitions (repetitions=1).\n'
            '- Hills: UN bloque main con repetitions=N. Segmentos:'
            '  subida (interval) + bajada recuperación (recovery).\n'
            '- NUNCA pongas múltiples bloques main con la misma zona'
            '  o ritmo — fúndelos en uno solo.\n'
            '- Los descansos van DENTRO del bloque main como segmentos'
            '  de type recovery, NO como bloques separados.\n'
            '- warmup y cooldown son opcionales pero recomendados.'
            '  Duración máxima warmup: 15 min. Cooldown: 10 min.\n'
            ' RANGOS NUMÉRICOS: repetitions entre 1 y 30; rpe entre 1 y 10;'
            ' fcMaxPercent entre 1 y 100; paces en segundos por km (mínimo 120);'
            ' durationSec y distanceM siempre positivos.\n'
            ' Responde únicamente con JSON válido que cumpla el esquema.',
      ),
      OpenRouterChatMessage(
        role: 'user',
        content: jsonEncode(userPayload),
      ),
    ];
  }

  WorkoutSession _parseResult(String content) {
    final Map<String, dynamic> json;
    try {
      json = jsonDecode(content) as Map<String, dynamic>;
    } catch (e) {
      throw Exception('Respuesta del LLM no es JSON válido: $e');
    }

    final title = (() {
      final raw = (json['title'] as String? ?? '').trim();
      if (raw.length < 3 || raw.replaceAll(RegExp(r'[^\w\s]'), '').trim().isEmpty) {
        debugPrint('[Generator] título corrupto: "$raw", usando fallback');
        return 'Entrenamiento generado por IA';
      }
      return raw;
    })();
    final description = json['description'] as String?;
    final typeStr = json['type'] as String? ?? 'free';
    final type = WorkoutType.values.asNameMap()[typeStr] ?? WorkoutType.free;
    final blocksRaw = json['blocks'] as List<dynamic>? ?? const [];

    final blocks = blocksRaw.map((b) {
      final bMap = Map<String, dynamic>.from(b as Map);
      return _parseBlock(bMap);
    }).toList();

    if (blocks.isEmpty || !blocks.any((b) => b.role == BlockRole.main)) {
      throw Exception('La sesión generada no tiene bloque principal.');
    }

    return WorkoutSession(
      title: title,
      description: description,
      type: type,
      blocks: blocks,
    );
  }

  WorkoutBlock _parseBlock(Map<String, dynamic> map) {
    final roleStr = map['role'] as String? ?? 'main';
    final role = BlockRole.values.asNameMap()[roleStr] ?? BlockRole.main;
    final repetitions = ((map['repetitions'] as num?)?.toInt() ?? 1).clamp(1, 30);
    final label = map['label'] as String?;
    final segmentsRaw = map['segments'] as List<dynamic>? ?? const [];

    final segments = segmentsRaw.map((s) {
      return _parseSegment(Map<String, dynamic>.from(s as Map));
    }).toList();

    if (segments.isEmpty) {
      segments.add(WorkoutSegment(type: SegmentType.interval, durationSec: 600));
    }

    return WorkoutBlock(
      role: role,
      repetitions: (role == BlockRole.warmup || role == BlockRole.cooldown)
          ? 1
          : repetitions,
      segments: segments,
      label: label,
    );
  }

  WorkoutSegment _parseSegment(Map<String, dynamic> map) {
    final typeStr = map['type'] as String? ?? 'interval';
    final type = SegmentType.values.asNameMap()[typeStr] ?? SegmentType.interval;
    // Sin minimum en el esquema (no soportado), valores no positivos se
    // descartan y caen en los defaults.
    final rawDurationSec = (map['durationSec'] as num?)?.toInt();
    final durationSec = (rawDurationSec != null && rawDurationSec > 0)
        ? rawDurationSec
        : null;
    final rawDistanceM = (map['distanceM'] as num?)?.toInt();
    final distanceM =
        (rawDistanceM != null && rawDistanceM > 0) ? rawDistanceM : null;
    final recoveryTypeStr = map['recoveryType'] as String?;
    final recoveryType = recoveryTypeStr != null
        ? RecoveryType.values.asNameMap()[recoveryTypeStr]
        : null;
    final targetMap = map['target'] as Map<String, dynamic>?;
    final target = targetMap != null ? _parseTarget(targetMap) : null;

    final alertsJson = map['alerts'] as Map<String, dynamic>?;
    SegmentAlerts? alerts;
    if (alertsJson != null && alertsJson['enabled'] == true) {
      final mode = alertsJson['mode'] as String? ?? 'time';

      int alertPaceMin = 0;
      int alertPaceSec = 0;
      if (mode == 'pace') {
        final targetPace = target?.paceMinSecPerKm ?? target?.paceMaxSecPerKm;
        if (targetPace != null) {
          alertPaceMin = targetPace ~/ 60;
          alertPaceSec = targetPace % 60;
        } else {
          alertPaceMin = 5;
          alertPaceSec = 0;
        }
      }

      final rawSegmentDistance = (alertsJson['segmentDistanceM'] as num?)?.toInt();
      final rawTimeSec = (alertsJson['timeSec'] as num?)?.toDouble() ?? 0;
      alerts = SegmentAlerts(
        enabled: true,
        mode: mode,
        timeMin: (alertsJson['timeMin'] as num?)?.toInt() ?? 0,
        timeSec: rawTimeSec < 0 ? 0 : rawTimeSec,
        paceMin: alertPaceMin,
        paceSec: alertPaceSec,
        segmentDistanceM: (rawSegmentDistance != null && rawSegmentDistance > 0)
            ? rawSegmentDistance
            : 400,
      );
    }

    return WorkoutSegment(
      type: type,
      durationSec: durationSec ?? (distanceM == null ? 600 : null),
      distanceM: distanceM,
      recoveryType: recoveryType,
      target: target,
      alerts: alerts,
    );
  }

  TargetConfig? _parseTarget(Map<String, dynamic> map) {
    if (map.isEmpty) return null;
    // Paces por debajo de 2:00/km (120 s) son irreales — se descartan.
    var paceMin = (map['paceMinSecPerKm'] as num?)?.toInt();
    if (paceMin != null && paceMin < 120) paceMin = null;
    var paceMax = (map['paceMaxSecPerKm'] as num?)?.toInt();
    if (paceMax != null && paceMax < 120) paceMax = null;
    if (paceMin != null && paceMax != null && paceMin > paceMax) {
      final tmp = paceMin;
      paceMin = paceMax;
      paceMax = tmp;
    }
    final rpe = (map['rpe'] as num?)?.toInt();
    final fcMaxPercent = (map['fcMaxPercent'] as num?)?.toInt();
    if (paceMin == null && paceMax == null && rpe == null && fcMaxPercent == null) {
      return null;
    }
    return TargetConfig(
      paceMinSecPerKm: paceMin,
      paceMaxSecPerKm: paceMax,
      rpe: rpe?.clamp(1, 10),
      fcMaxPercent: fcMaxPercent?.clamp(1, 100),
    );
  }

  // ⚠️ Los structured outputs de Anthropic (via OpenRouter) no soportan
  // restricciones numéricas (minimum/maximum) ni minItems — la petición
  // entera falla con 400. Los rangos se indican en el system prompt y se
  // aplican con clamps en _parseBlock/_parseSegment/_parseTarget.
  static const Map<String, dynamic> _sessionSchema = {
    'type': 'object',
    'additionalProperties': false,
    'required': ['title', 'type', 'blocks'],
    'properties': {
      'title': {'type': 'string'},
      'description': {'type': 'string'},
      'type': {
        'type': 'string',
        'enum': ['continuous', 'intervals', 'fartlek', 'hills', 'competition', 'free'],
      },
      'blocks': {
        'type': 'array',
        'items': {
          'type': 'object',
          'additionalProperties': false,
          'required': ['role', 'repetitions', 'segments'],
          'properties': {
            'role': {
              'type': 'string',
              'enum': ['warmup', 'main', 'cooldown'],
            },
            'repetitions': {'type': 'integer'},
            'label': {'type': 'string'},
            'segments': {
              'type': 'array',
              'items': {
                'type': 'object',
                'additionalProperties': false,
                'required': ['type'],
                'properties': {
                  'type': {
                    'type': 'string',
                    'enum': ['interval', 'recovery'],
                  },
                  'durationSec': {'type': 'integer'},
                  'distanceM': {'type': 'integer'},
                  'recoveryType': {
                    'type': 'string',
                    'enum': ['active', 'passive'],
                  },
                  'target': {
                    'type': 'object',
                    'additionalProperties': false,
                    'properties': {
                      'paceMinSecPerKm': {'type': 'integer'},
                      'paceMaxSecPerKm': {'type': 'integer'},
                      'rpe': {'type': 'integer'},
                      'fcMaxPercent': {'type': 'integer'},
                    },
                  },
                  'alerts': {
                    'type': 'object',
                    'additionalProperties': false,
                    'properties': {
                      'enabled': {'type': 'boolean'},
                      'mode': {'type': 'string', 'enum': ['time', 'pace']},
                      'timeSec': {'type': 'number'},
                      'segmentDistanceM': {'type': 'integer'},
                    },
                  },
                },
              },
            },
          },
        },
      },
    },
  };
}
