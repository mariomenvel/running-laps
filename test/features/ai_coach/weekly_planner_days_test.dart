import 'package:flutter_test/flutter_test.dart';
import 'package:running_laps/features/ai_coach/data/ai_coach_models.dart';
import 'package:running_laps/features/ai_coach/data/ai_coach_weekly_planner_service.dart';
import 'package:running_laps/features/athlete/data/athlete_session_model.dart';

/// Reparto del plan semanal por días.
///
/// Es la promesa más concreta que le hace el Coach al atleta: "solo te
/// planifico los días que me has dicho". Si falla, el usuario abre el
/// calendario y ve entrenos en días en los que no puede entrenar — y encima el
/// LLM no tiene forma de garantizarlo, lo garantiza este código.
void main() {
  late AiCoachWeeklyPlannerService planner;

  // Lunes 20 de julio de 2026.
  final weekStart = DateTime(2026, 7, 20);

  setUp(() {
    planner = AiCoachWeeklyPlannerService();
  });

  AiCoachProfile profileWith(List<int> days) {
    return AiCoachProfile(
      uid: 'uid-1',
      goal: AiCoachGoalType.improveEndurance,
      goalDescription: 'Mejorar la base aeróbica',
      level: AiCoachAthleteLevel.intermediate,
      availableWeekdays: days,
      preferredWeeklySessions: days.isEmpty ? 3 : days.length,
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    );
  }

  AthleteSession sessionOn(String date) => AthleteSession(
        id: 'sesion-$date',
        uid: 'uid-1',
        date: date,
        status: AthleteSessionStatus.planned,
        createdAt: DateTime(2026, 7, 19),
        updatedAt: DateTime(2026, 7, 19),
      );

  group('normalizeAvailableWeekdays', () {
    test('deja pasar el criterio de Dart (1 = lunes … 7 = domingo)', () {
      expect(planner.normalizeAvailableWeekdays([1, 3, 6]), [1, 3, 6]);
    });

    test('traduce el formato antiguo con 0 = domingo', () {
      // Perfiles guardados antes del cambio de criterio: si el 0 no se
      // convierte en 7, el domingo se pierde y el plan se corre de día.
      expect(planner.normalizeAvailableWeekdays([0]), [7]);
    });

    test('quita duplicados y ordena', () {
      expect(planner.normalizeAvailableWeekdays([6, 1, 6, 3]), [1, 3, 6]);
    });

    test('descarta valores imposibles', () {
      expect(planner.normalizeAvailableWeekdays([9, -2, 3]), [3]);
      expect(planner.normalizeAvailableWeekdays([]), isEmpty);
    });
  });

  group('resolveFeasibleWeekdays', () {
    test('usa los días del perfil y descarta los que ya pasaron', () {
      final feasible = planner.resolveFeasibleWeekdays(
        profile: profileWith([1, 3, 6]), // lunes, miércoles, sábado
        weekStart: weekStart,
        minDate: DateTime(2026, 7, 22), // ya es miércoles
        fallbackTargetSessions: 3,
      );

      expect(feasible, [3, 6], reason: 'el lunes ya pasó');
    });

    test('sin días en el perfil reparte por defecto según el nº de sesiones',
        () {
      expect(
        planner.resolveFeasibleWeekdays(
          profile: profileWith(const []),
          weekStart: weekStart,
          minDate: weekStart,
          fallbackTargetSessions: 3,
        ),
        [1, 3, 6],
        reason: 'tres sesiones se reparten lunes / miércoles / sábado',
      );
    });

    test('si la semana ya terminó no queda ningún día', () {
      expect(
        planner.resolveFeasibleWeekdays(
          profile: profileWith([1, 2]),
          weekStart: weekStart,
          minDate: DateTime(2026, 7, 27), // lunes siguiente
          fallbackTargetSessions: 2,
        ),
        isEmpty,
      );
    });
  });

  group('enforceAvailableWeekdays', () {
    test('una sesión en un día no disponible se mueve al primero libre', () {
      final result = planner.enforceAvailableWeekdays(
        sessions: [sessionOn('2026-07-21')], // martes
        profile: profileWith([1, 3, 6]),
        weekStart: weekStart,
        minDate: weekStart,
        occupiedWeekdays: const {},
      );

      expect(result.single.date, '2026-07-20', reason: 'lunes, el primero libre');
    });

    test('una sesión que ya cae en día disponible no se toca', () {
      final result = planner.enforceAvailableWeekdays(
        sessions: [sessionOn('2026-07-22')], // miércoles
        profile: profileWith([1, 3, 6]),
        weekStart: weekStart,
        minDate: weekStart,
        occupiedWeekdays: const {},
      );

      expect(result.single.date, '2026-07-22');
    });

    test('no pone dos sesiones el mismo día', () {
      final result = planner.enforceAvailableWeekdays(
        sessions: [sessionOn('2026-07-21'), sessionOn('2026-07-21')],
        profile: profileWith([1, 3, 6]),
        weekStart: weekStart,
        minDate: weekStart,
        occupiedWeekdays: const {},
      );

      expect(result.map((s) => s.date), ['2026-07-20', '2026-07-22']);
    });

    test('respeta los días ya ocupados por sesiones existentes', () {
      final result = planner.enforceAvailableWeekdays(
        sessions: [sessionOn('2026-07-21')], // martes, no disponible
        profile: profileWith([1, 3, 6]),
        weekStart: weekStart,
        minDate: weekStart,
        occupiedWeekdays: const {1}, // el lunes ya tiene algo
      );

      expect(result.single.date, '2026-07-22',
          reason: 'salta al miércoles porque el lunes está ocupado');
    });

    test('si no quedan días libres, se descarta la sesión sobrante', () {
      final result = planner.enforceAvailableWeekdays(
        sessions: [
          sessionOn('2026-07-21'),
          sessionOn('2026-07-21'),
          sessionOn('2026-07-21'),
        ],
        profile: profileWith([1, 3]), // solo dos días disponibles
        weekStart: weekStart,
        minDate: weekStart,
        occupiedWeekdays: const {},
      );

      expect(result, hasLength(2),
          reason: 'mejor menos sesiones que dos el mismo día o una '
              'en un día imposible');
    });
  });
}
