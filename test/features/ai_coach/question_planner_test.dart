import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:running_laps/features/ai_coach/data/ai_coach_adaptive_question.dart';
import 'package:running_laps/features/ai_coach/data/ai_coach_autoregulation.dart';
import 'package:running_laps/features/ai_coach/data/ai_coach_question_planner.dart';
import 'package:running_laps/features/ai_coach/data/ai_coach_models.dart';

/// Cuestionario semanal individualizado.
///
/// La regla que gobierna el planificador es "no preguntes lo que no va a
/// cambiar el plan", así que buena parte de los tests comprueban que en las
/// semanas normales NO se pregunta nada extra.
void main() {
  const planner = AiCoachQuestionPlanner();
  const auto = AiCoachAutoregulation();

  AiCoachWeeklyFeedback feedbackWith({String? molestias}) =>
      AiCoachWeeklyFeedback(
        uid: 'u1',
        weekStart: '2026-07-20',
        sensaciones: 3,
        sueno: 'bien',
        molestias: molestias,
        createdAt: DateTime(2026, 7, 26),
      );

  AiCoachAutoregulationSignal signalOf(
    AiCoachReadinessVerdict verdict, {
    double adherence = 1.0,
    bool easyDaysTooHard = false,
    bool fatigueFlag = false,
  }) =>
      AiCoachAutoregulationSignal(
        verdict: verdict,
        volumeFactor: 1.0,
        sessionsAnalyzed: 3,
        adherence: adherence,
        easyDaysTooHard: easyDaysTooHard,
        fatigueFlag: fatigueFlag,
        reason: 'test',
      );

  AiCoachAdaptiveAnswer answerOf(
    AiCoachQuestionSignal signal, {
    required String value,
    required int severity,
    String questionText = 'pregunta',
  }) =>
      AiCoachAdaptiveAnswer(
        questionId: 'q1',
        questionText: questionText,
        signal: signal,
        value: value,
        label: 'label',
        severity: severity,
      );

  group('no preguntar de más', () {
    test('una semana buena no genera preguntas extra', () {
      final questions = planner.plan(
        lastFeedback: feedbackWith(),
        signal: signalOf(AiCoachReadinessVerdict.progress),
      );
      expect(questions, isEmpty);
    });

    test('nunca se pasan de dos preguntas', () {
      final questions = planner.plan(
        lastFeedback: feedbackWith(molestias: 'Rodilla derecha'),
        signal: signalOf(
          AiCoachReadinessVerdict.regress,
          adherence: 0.3,
          easyDaysTooHard: true,
        ),
      );
      expect(questions.length, lessThanOrEqualTo(AiCoachQuestionPlanner.maxQuestions));
    });
  });

  group('seguimiento de molestias', () {
    test('si la semana pasada reportó molestia, se pregunta por ella', () {
      final questions = planner.plan(
        lastFeedback: feedbackWith(molestias: 'Me molesta el sóleo izquierdo'),
        signal: signalOf(AiCoachReadinessVerdict.progress),
      );
      expect(questions, hasLength(1));
      expect(questions.first.signal, AiCoachQuestionSignal.injuryStatus);
      expect(questions.first.rationale, contains('sóleo'));
    });

    test('el seguimiento continúa mientras la molestia siga abierta', () {
      final questions = planner.plan(
        lastFeedback: feedbackWith(),
        lastAnswers: [
          answerOf(AiCoachQuestionSignal.injuryStatus,
              value: 'same', severity: 2, questionText: '¿Cómo va esa molestia?'),
        ],
        signal: signalOf(AiCoachReadinessVerdict.hold),
      );
      expect(questions, hasLength(1));
      expect(questions.first.signal, AiCoachQuestionSignal.injuryStatus);
    });

    test('deja de preguntarse cuando el atleta dice que ya no duele', () {
      final questions = planner.plan(
        lastFeedback: feedbackWith(molestias: 'Rodilla'),
        lastAnswers: [
          answerOf(AiCoachQuestionSignal.injuryStatus,
              value: 'gone', severity: 0),
        ],
        signal: signalOf(AiCoachReadinessVerdict.progress),
      );
      expect(questions, isEmpty);
    });
  });

  group('causa de una semana floja', () {
    test('un regress pregunta por el motivo', () {
      final questions = planner.plan(
        lastFeedback: feedbackWith(),
        signal: signalOf(AiCoachReadinessVerdict.regress),
      );
      expect(questions, hasLength(1));
      expect(questions.first.signal, AiCoachQuestionSignal.fatigueCause);
    });

    test('con molestia abierta manda el seguimiento, no la causa', () {
      final questions = planner.plan(
        lastFeedback: feedbackWith(molestias: 'Gemelo'),
        signal: signalOf(AiCoachReadinessVerdict.regress),
      );
      expect(questions.first.signal, AiCoachQuestionSignal.injuryStatus);
    });
  });

  group('rodajes suaves demasiado rápidos', () {
    test('se pregunta si le cuesta contenerse', () {
      final questions = planner.plan(
        lastFeedback: feedbackWith(),
        signal: signalOf(AiCoachReadinessVerdict.hold, easyDaysTooHard: true),
      );
      expect(
        questions.map((q) => q.signal),
        contains(AiCoachQuestionSignal.easyPaceControl),
      );
    });
  });

  group('las respuestas mueven el plan', () {
    test('molestia a peor fuerza reinicio aunque los ritmos fueran buenos', () {
      final signal = auto.evaluate(
        lastWeekSessions: [
          AiCoachTrainingSummary(
            trainingId: 't1',
            date: DateTime(2026, 7, 21),
            title: 'Tempo',
            category: 'tempo',
            distanceKm: 10,
            durationMinutes: 50,
            paceCompliancePercent: 98,
          ),
        ],
        answers: [
          answerOf(AiCoachQuestionSignal.injuryStatus,
              value: 'worse', severity: 3),
        ],
      );
      expect(signal.verdict, AiCoachReadinessVerdict.reset);
      expect(signal.volumeFactor, lessThan(0.7));
      expect(signal.reason, contains('peor'));
    });

    test('molestia que mejora bloquea la subida pero no castiga', () {
      final signal = auto.evaluate(
        lastWeekSessions: [
          AiCoachTrainingSummary(
            trainingId: 't1',
            date: DateTime(2026, 7, 21),
            title: 'Tempo',
            category: 'tempo',
            distanceKm: 10,
            durationMinutes: 50,
            paceCompliancePercent: 98,
            wasEasierThanExpected: true,
          ),
        ],
        answers: [
          answerOf(AiCoachQuestionSignal.injuryStatus,
              value: 'better', severity: 1),
        ],
      );
      expect(signal.verdict, AiCoachReadinessVerdict.hold);
      expect(signal.volumeFactor, 1.0);
    });

    test('faltar por trabajo NO se trata como fatiga', () {
      // Sin la respuesta, la baja adherencia produce regress y recorta carga.
      final sinRespuesta = auto.evaluate(
        lastWeekSessions: [_baseRun()],
        weeklyState: _stateWith(adherence: 0.4),
      );
      expect(sinRespuesta.verdict, AiCoachReadinessVerdict.regress);

      // Con la respuesta, el coach sabe que el atleta llega fresco.
      final conRespuesta = auto.evaluate(
        lastWeekSessions: [_baseRun()],
        weeklyState: _stateWith(adherence: 0.4),
        answers: [
          answerOf(AiCoachQuestionSignal.fatigueCause,
              value: 'life', severity: 0),
        ],
      );
      expect(conRespuesta.verdict, AiCoachReadinessVerdict.hold);
      expect(conRespuesta.volumeFactor, 1.0);
      expect(conRespuesta.reason, contains('agenda'));
    });

    test('pero si además hay fatiga real, no se indulta', () {
      final signal = auto.evaluate(
        lastWeekSessions: [_baseRun()],
        weeklyState: _stateWith(adherence: 0.4, tsb: -25),
        answers: [
          answerOf(AiCoachQuestionSignal.fatigueCause,
              value: 'life', severity: 0),
        ],
      );
      expect(signal.verdict, AiCoachReadinessVerdict.regress);
    });

    test('haber estado malo fuerza reentrada suave', () {
      final signal = auto.evaluate(
        lastWeekSessions: const [],
        weeklyState: _stateWith(adherence: 0.5),
        answers: [
          answerOf(AiCoachQuestionSignal.fatigueCause,
              value: 'illness', severity: 3),
        ],
      );
      expect(signal.verdict, AiCoachReadinessVerdict.reset);
      expect(signal.reason, contains('malo'));
    });
  });

  group('serialización', () {
    test('las respuestas sobreviven al round-trip del feedback', () {
      final feedback = AiCoachWeeklyFeedback(
        uid: 'u1',
        weekStart: '2026-07-20',
        sensaciones: 4,
        sueno: 'bien',
        createdAt: DateTime(2026, 7, 26),
        adaptiveAnswers: [
          answerOf(AiCoachQuestionSignal.injuryStatus,
              value: 'better',
              severity: 1,
              questionText: '¿Cómo va esa molestia?'),
        ],
      );
      final map = feedback.toMap();
      map['createdAt'] = Timestamp.fromDate(feedback.createdAt);
      final restored = AiCoachWeeklyFeedback.fromMap(map);
      expect(restored.adaptiveAnswers, hasLength(1));
      expect(restored.adaptiveAnswers.first.value, 'better');
      expect(restored.adaptiveAnswers.first.questionText,
          '¿Cómo va esa molestia?');
      expect(restored.adaptiveAnswers.first.signal,
          AiCoachQuestionSignal.injuryStatus);
    });

    test('un feedback antiguo sin respuestas se lee sin romperse', () {
      final restored = AiCoachWeeklyFeedback.fromMap({
        'uid': 'u1',
        'weekStart': '2026-07-13',
        'sensaciones': 3,
        'sueno': 'bien',
        'createdAt': Timestamp.fromDate(DateTime(2026, 7, 19)),
      });
      expect(restored.adaptiveAnswers, isEmpty);
    });
  });
}

AiCoachTrainingSummary _baseRun() => AiCoachTrainingSummary(
      trainingId: 't-base',
      date: DateTime(2026, 7, 21),
      title: 'Rodaje',
      category: 'rodaje_base',
      distanceKm: 8,
      durationMinutes: 45,
      paceCompliancePercent: 100,
    );

AiCoachWeeklyState _stateWith({double adherence = 1.0, double tsb = 0}) =>
    AiCoachWeeklyState(
      weekStart: DateTime(2026, 7, 20),
      plannedSessions: 4,
      completedSessions: 2,
      skippedSessions: 2,
      adherenceRatio: adherence,
      weeklyKm: 15,
      weeklyLoad: 150,
      weeklyRpeAverage: 5,
      atl: 30,
      ctl: 30,
      tsb: tsb,
      daysSinceLastTraining: 2,
      consecutiveMissedWeeks: 0,
      raceInNext14Days: false,
      needsDeload: false,
      trend: 'stable',
    );
