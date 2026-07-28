/// Qué señal resuelve una pregunta del cuestionario semanal.
///
/// Es lo que permite que la respuesta **mueva el plan** en vez de quedarse en
/// texto. Una pregunta que no resuelve ninguna señal no debería hacerse.
enum AiCoachQuestionSignal {
  /// Seguimiento de una molestia reportada antes.
  injuryStatus,

  /// Por qué fue floja la semana: entrenamiento, vida, enfermedad, ánimo.
  fatigueCause,

  /// Si cuesta contener el ritmo en los rodajes suaves.
  easyPaceControl,

  /// Si la disponibilidad real ha cambiado.
  availability,

  /// Enganche con el plan.
  motivation,
}

extension AiCoachQuestionSignalX on AiCoachQuestionSignal {
  String get toValue {
    switch (this) {
      case AiCoachQuestionSignal.injuryStatus:
        return 'injury_status';
      case AiCoachQuestionSignal.fatigueCause:
        return 'fatigue_cause';
      case AiCoachQuestionSignal.easyPaceControl:
        return 'easy_pace_control';
      case AiCoachQuestionSignal.availability:
        return 'availability';
      case AiCoachQuestionSignal.motivation:
        return 'motivation';
    }
  }

  static AiCoachQuestionSignal fromValue(String value) {
    switch (value) {
      case 'injury_status':
        return AiCoachQuestionSignal.injuryStatus;
      case 'easy_pace_control':
        return AiCoachQuestionSignal.easyPaceControl;
      case 'availability':
        return AiCoachQuestionSignal.availability;
      case 'motivation':
        return AiCoachQuestionSignal.motivation;
      default:
        return AiCoachQuestionSignal.fatigueCause;
    }
  }
}

/// Opción de respuesta. La [severity] (0 = todo bien … 3 = alarma) es lo que
/// consume la autorregulacion — por eso las respuestas son tipadas y no texto
/// libre.
class AiCoachQuestionOption {
  final String value;
  final String label;
  final int severity;

  const AiCoachQuestionOption({
    required this.value,
    required this.label,
    this.severity = 0,
  });

  Map<String, dynamic> toMap() => {
        'value': value,
        'label': label,
        'severity': severity,
      };

  factory AiCoachQuestionOption.fromMap(Map<String, dynamic> map) =>
      AiCoachQuestionOption(
        value: map['value'] as String? ?? '',
        label: map['label'] as String? ?? '',
        severity: (map['severity'] as num?)?.toInt() ?? 0,
      );
}

/// Pregunta individualizada del cuestionario semanal.
class AiCoachAdaptiveQuestion {
  final String id;
  final String question;
  final AiCoachQuestionSignal signal;
  final List<AiCoachQuestionOption> options;

  /// Por qué el coach pregunta esto. Se muestra al atleta en pequeño: saber
  /// que la pregunta viene de algo que él contó genera más confianza que la
  /// pregunta en sí.
  final String? rationale;

  const AiCoachAdaptiveQuestion({
    required this.id,
    required this.question,
    required this.signal,
    required this.options,
    this.rationale,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'question': question,
        'signal': signal.toValue,
        'options': options.map((o) => o.toMap()).toList(),
        if (rationale != null) 'rationale': rationale,
      };

  factory AiCoachAdaptiveQuestion.fromMap(Map<String, dynamic> map) =>
      AiCoachAdaptiveQuestion(
        id: map['id'] as String? ?? '',
        question: map['question'] as String? ?? '',
        signal: AiCoachQuestionSignalX.fromValue(map['signal'] as String? ?? ''),
        options: (map['options'] as List? ?? const [])
            .map((o) =>
                AiCoachQuestionOption.fromMap(Map<String, dynamic>.from(o as Map)))
            .toList(),
        rationale: map['rationale'] as String?,
      );
}

/// Respuesta del atleta a una pregunta adaptativa.
///
/// Se guarda el enunciado además del valor: la semana que viene el coach tiene
/// que poder releer qué preguntó para encadenar el seguimiento.
class AiCoachAdaptiveAnswer {
  final String questionId;
  final String questionText;
  final AiCoachQuestionSignal signal;
  final String value;
  final String label;
  final int severity;

  const AiCoachAdaptiveAnswer({
    required this.questionId,
    required this.questionText,
    required this.signal,
    required this.value,
    required this.label,
    required this.severity,
  });

  Map<String, dynamic> toMap() => {
        'questionId': questionId,
        'questionText': questionText,
        'signal': signal.toValue,
        'value': value,
        'label': label,
        'severity': severity,
      };

  factory AiCoachAdaptiveAnswer.fromMap(Map<String, dynamic> map) =>
      AiCoachAdaptiveAnswer(
        questionId: map['questionId'] as String? ?? '',
        questionText: map['questionText'] as String? ?? '',
        signal: AiCoachQuestionSignalX.fromValue(map['signal'] as String? ?? ''),
        value: map['value'] as String? ?? '',
        label: map['label'] as String? ?? '',
        severity: (map['severity'] as num?)?.toInt() ?? 0,
      );
}
