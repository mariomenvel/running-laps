import 'package:running_laps/features/ai_coach/data/ai_coach_adaptive_question.dart';
import 'package:running_laps/features/ai_coach/data/ai_coach_autoregulation.dart';
import 'package:running_laps/features/ai_coach/data/ai_coach_models.dart';

/// Decide qué le falta saber al coach esta semana.
///
/// El cuestionario semanal era siempre el mismo, preguntara o no algo que
/// importase. Este planificador lo individualiza: el núcleo fijo (sensaciones
/// y sueño) se mantiene para conservar la serie temporal comparable, y encima
/// se añaden como mucho dos preguntas que dependen del contexto.
///
/// Regla que gobierna todo: **no preguntes lo que no va a cambiar el plan.**
/// Si la semana fue bien y no hay nada abierto, no se pregunta nada extra.
///
/// Es lógica pura y determinista a propósito. El caso de más valor — acordarse
/// de una molestia que el atleta contó la semana pasada — no puede depender de
/// que el LLM responda ni de que acierte.
class AiCoachQuestionPlanner {
  const AiCoachQuestionPlanner();

  /// Tope duro. Un cuestionario largo no se rellena, y un cuestionario sin
  /// rellenar no vale nada.
  static const int maxQuestions = 2;

  List<AiCoachAdaptiveQuestion> plan({
    AiCoachWeeklyFeedback? lastFeedback,
    List<AiCoachAdaptiveAnswer> lastAnswers = const [],
    AiCoachAutoregulationSignal? signal,
  }) {
    final questions = <AiCoachAdaptiveQuestion>[];

    // 1. Seguimiento de molestia. Máxima prioridad: es lo que convierte el
    //    cuestionario en una conversación en vez de un formulario.
    final openInjury = _openInjury(lastFeedback, lastAnswers);
    if (openInjury != null) {
      questions.add(_injuryFollowUp(openInjury));
    }

    // 2. Causa de una semana floja. Distinguir "vine fundido de entrenar" de
    //    "no pude por trabajo" cambia por completo qué hacer después.
    final verdict = signal?.verdict;
    if (questions.length < maxQuestions &&
        openInjury == null &&
        (verdict == AiCoachReadinessVerdict.regress ||
            verdict == AiCoachReadinessVerdict.reset)) {
      questions.add(_fatigueCauseQuestion());
    }

    // 3. Rodajes suaves demasiado rápidos.
    if (questions.length < maxQuestions && (signal?.easyDaysTooHard ?? false)) {
      questions.add(_easyPaceQuestion());
    }

    // 4. Disponibilidad, solo si se cayeron sesiones sin que haya molestia.
    if (questions.length < maxQuestions &&
        openInjury == null &&
        signal != null &&
        signal.adherence < 0.6 &&
        signal.verdict != AiCoachReadinessVerdict.reset) {
      questions.add(_availabilityQuestion());
    }

    return questions.take(maxQuestions).toList();
  }

  /// Devuelve la descripción de la molestia que sigue abierta, o null.
  ///
  /// Una molestia se considera cerrada solo si el atleta respondió
  /// explícitamente que ya no le duele.
  String? _openInjury(
    AiCoachWeeklyFeedback? lastFeedback,
    List<AiCoachAdaptiveAnswer> lastAnswers,
  ) {
    final resolved = lastAnswers.any((a) =>
        a.signal == AiCoachQuestionSignal.injuryStatus && a.severity == 0);
    if (resolved) return null;

    final carriedOver = lastAnswers.firstWhere(
      (a) =>
          a.signal == AiCoachQuestionSignal.injuryStatus && a.severity > 0,
      orElse: () => const AiCoachAdaptiveAnswer(
        questionId: '',
        questionText: '',
        signal: AiCoachQuestionSignal.injuryStatus,
        value: '',
        label: '',
        severity: 0,
      ),
    );
    if (carriedOver.questionId.isNotEmpty) return carriedOver.questionText;

    final molestias = lastFeedback?.molestias?.trim();
    if (molestias != null && molestias.isNotEmpty) return molestias;
    return null;
  }

  AiCoachAdaptiveQuestion _injuryFollowUp(String injury) {
    final shortened =
        injury.length > 60 ? '${injury.substring(0, 57)}...' : injury;
    return AiCoachAdaptiveQuestion(
      id: 'injury_follow_up',
      question: '¿Cómo va esa molestia?',
      signal: AiCoachQuestionSignal.injuryStatus,
      rationale: 'La semana pasada me contaste: "$shortened"',
      options: const [
        AiCoachQuestionOption(
          value: 'gone',
          label: 'Ya no me duele',
          severity: 0,
        ),
        AiCoachQuestionOption(
          value: 'better',
          label: 'Mejor, pero sigue ahí',
          severity: 1,
        ),
        AiCoachQuestionOption(value: 'same', label: 'Igual', severity: 2),
        AiCoachQuestionOption(value: 'worse', label: 'A peor', severity: 3),
      ],
    );
  }

  AiCoachAdaptiveQuestion _fatigueCauseQuestion() {
    return const AiCoachAdaptiveQuestion(
      id: 'fatigue_cause',
      question: '¿A qué se debió la semana floja?',
      signal: AiCoachQuestionSignal.fatigueCause,
      rationale: 'Para saber si toca bajar carga o solo reorganizar la semana',
      options: [
        AiCoachQuestionOption(
          value: 'training',
          label: 'Venía cansado de entrenar',
          severity: 2,
        ),
        AiCoachQuestionOption(
          value: 'life',
          label: 'Trabajo o vida personal',
          severity: 0,
        ),
        AiCoachQuestionOption(
          value: 'illness',
          label: 'Estuve malo',
          severity: 3,
        ),
        AiCoachQuestionOption(
          value: 'motivation',
          label: 'Sin ganas',
          severity: 1,
        ),
      ],
    );
  }

  AiCoachAdaptiveQuestion _easyPaceQuestion() {
    return const AiCoachAdaptiveQuestion(
      id: 'easy_pace_control',
      question: 'En los rodajes suaves, ¿vas cómodo al ritmo que te marco?',
      signal: AiCoachQuestionSignal.easyPaceControl,
      rationale: 'Te vi ir más rápido de lo previsto en los días fáciles',
      options: [
        AiCoachQuestionOption(
          value: 'comfortable',
          label: 'Sí, voy cómodo',
          severity: 0,
        ),
        AiCoachQuestionOption(
          value: 'too_slow',
          label: 'Se me hace muy lento',
          severity: 1,
        ),
        AiCoachQuestionOption(
          value: 'hard_to_hold',
          label: 'Me cuesta frenarme',
          severity: 1,
        ),
      ],
    );
  }

  AiCoachAdaptiveQuestion _availabilityQuestion() {
    return const AiCoachAdaptiveQuestion(
      id: 'availability',
      question: '¿Han cambiado tus días disponibles?',
      signal: AiCoachQuestionSignal.availability,
      rationale: 'Se quedaron sesiones sin hacer',
      options: [
        AiCoachQuestionOption(
          value: 'same',
          label: 'No, sigo igual',
          severity: 0,
        ),
        AiCoachQuestionOption(
          value: 'fewer_days',
          label: 'Puedo menos días',
          severity: 1,
        ),
        AiCoachQuestionOption(
          value: 'temporary',
          label: 'Fue algo puntual',
          severity: 0,
        ),
      ],
    );
  }
}
