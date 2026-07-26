import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:running_laps/features/ai_coach/data/ai_coach_context_builder.dart';
import 'package:running_laps/features/athlete/data/athlete_session_model.dart';
import 'package:running_laps/features/training/data/entrenamiento.dart';
import 'package:running_laps/features/training/data/serie.dart';

/// `buildWeeklyState` es lo que el Coach IA ve de tu semana: adherencia,
/// volumen, carga aguda (ATL) y crónica (CTL), y frescura (TSB = CTL − ATL).
/// Si esto miente, el plan que genera está mal razonado aunque el prompt sea
/// perfecto — y no hay forma de notarlo mirando la app.
void main() {
  late AiCoachContextBuilder builder;

  // Semana de referencia: lunes 20 a domingo 26 de julio de 2026.
  final weekStart = DateTime(2026, 7, 20);
  final weekEnd = DateTime(2026, 7, 26);
  final now = DateTime(2026, 7, 26, 12);

  setUp(() {
    // El builder solo usa sus repos en buildWeeklyContext(); aquí se prueba la
    // parte pura, pero hay que construirlo sin tocar Firebase.
    builder = AiCoachContextBuilder(firestore: FakeFirebaseFirestore());
  });

  Entrenamiento training({
    required DateTime fecha,
    int distanciaM = 10000,
    double tiempoSec = 3000,
    double rpe = 6,
    double? loadScore,
  }) {
    return Entrenamiento(
      titulo: 'Rodaje',
      fecha: fecha,
      gps: true,
      loadScore: loadScore,
      series: [
        Serie(
          tiempoSec: tiempoSec,
          distanciaM: distanciaM,
          descansoSec: 0,
          rpe: rpe,
        ),
      ],
    );
  }

  AthleteSession session(String date, AthleteSessionStatus status) {
    return AthleteSession(
      id: 'sesion-$date-${status.name}',
      uid: 'uid-1',
      date: date,
      status: status,
      createdAt: DateTime(2026, 7, 19),
      updatedAt: DateTime(2026, 7, 19),
    );
  }

  group('volumen y adherencia', () {
    test('solo cuentan los entrenos y sesiones dentro de la semana', () {
      final state = builder.buildWeeklyState(
        now: now,
        weekStart: weekStart,
        weekEnd: weekEnd,
        trainings: [
          training(fecha: DateTime(2026, 7, 21), distanciaM: 10000),
          training(fecha: DateTime(2026, 7, 24), distanciaM: 5000),
          // Semana anterior: no debe sumar al volumen semanal.
          training(fecha: DateTime(2026, 7, 19), distanciaM: 20000),
        ],
        sessions: [
          session('2026-07-21', AthleteSessionStatus.completed),
          session('2026-07-23', AthleteSessionStatus.skipped),
          session('2026-07-25', AthleteSessionStatus.planned),
          session('2026-07-13', AthleteSessionStatus.completed), // otra semana
        ],
      );

      expect(state.weeklyKm, 15.0);
      expect(state.plannedSessions, 3);
      expect(state.completedSessions, 1);
      expect(state.skippedSessions, 1);
    });

    test('sin sesiones planificadas la adherencia es 1, no una división por 0',
        () {
      final state = builder.buildWeeklyState(
        now: now,
        weekStart: weekStart,
        weekEnd: weekEnd,
        trainings: const [],
        sessions: const [],
      );

      expect(state.adherenceRatio, 1.0);
      expect(state.weeklyKm, 0);
    });

    test('la adherencia es completadas / planificadas', () {
      final state = builder.buildWeeklyState(
        now: now,
        weekStart: weekStart,
        weekEnd: weekEnd,
        trainings: const [],
        sessions: [
          session('2026-07-20', AthleteSessionStatus.completed),
          session('2026-07-22', AthleteSessionStatus.completed),
          session('2026-07-24', AthleteSessionStatus.planned),
          session('2026-07-26', AthleteSessionStatus.skipped),
        ],
      );

      expect(state.adherenceRatio, 0.5);
    });

    test('los límites de la semana son inclusivos por ambos lados', () {
      final state = builder.buildWeeklyState(
        now: now,
        weekStart: weekStart,
        weekEnd: weekEnd,
        trainings: [
          training(fecha: DateTime(2026, 7, 20, 6), distanciaM: 1000),
          training(fecha: DateTime(2026, 7, 26, 22), distanciaM: 1000),
        ],
        sessions: const [],
      );

      expect(state.weeklyKm, 2.0, reason: 'lunes y domingo cuentan');
    });
  });

  group('carga y frescura', () {
    test('una semana dura deja el TSB negativo (fatiga acumulada)', () {
      // Carga alta y reciente: la aguda (7 días) sube más rápido que la
      // crónica (42 días), así que TSB = CTL - ATL sale negativo.
      final trainings = [
        for (int i = 0; i < 6; i++)
          training(
            fecha: now.subtract(Duration(days: i)),
            loadScore: 300,
          ),
      ];

      final state = builder.buildWeeklyState(
        now: now,
        weekStart: weekStart,
        weekEnd: weekEnd,
        trainings: trainings,
        sessions: const [],
      );

      expect(state.atl, greaterThan(state.ctl));
      expect(state.tsb, lessThan(0));
      expect(state.tsb, closeTo(state.ctl - state.atl, 0.0001));
    });

    test('sin entrenos, carga a cero y el "días desde el último" es 999', () {
      final state = builder.buildWeeklyState(
        now: now,
        weekStart: weekStart,
        weekEnd: weekEnd,
        trainings: const [],
        sessions: const [],
      );

      expect(state.atl, 0);
      expect(state.ctl, 0);
      expect(state.tsb, 0);
      expect(state.daysSinceLastTraining, 999,
          reason: 'centinela para "nunca ha entrenado", no 0 días');
    });

    test('los días desde el último entreno se cuentan por día natural', () {
      final state = builder.buildWeeklyState(
        now: now, // domingo 26 a las 12:00
        weekStart: weekStart,
        weekEnd: weekEnd,
        // El primero de la lista es el más reciente (orden del repositorio).
        trainings: [
          training(fecha: DateTime(2026, 7, 23, 21)),
          training(fecha: DateTime(2026, 7, 20, 7)),
        ],
        sessions: const [],
      );

      expect(state.daysSinceLastTraining, 3,
          reason: 'del 23 al 26, sin importar la hora');
    });

    test('el RPE medio ignora los entrenos sin series', () {
      final state = builder.buildWeeklyState(
        now: now,
        weekStart: weekStart,
        weekEnd: weekEnd,
        trainings: [
          training(fecha: DateTime(2026, 7, 21), rpe: 4),
          training(fecha: DateTime(2026, 7, 22), rpe: 8),
          Entrenamiento(
            titulo: 'Sin series',
            fecha: DateTime(2026, 7, 23),
            gps: false,
            series: const [],
          ),
        ],
        sessions: const [],
      );

      expect(state.weeklyRpeAverage, 6.0,
          reason: 'media de 4 y 8; el entreno vacío no arrastra a 0');
    });
  });
}
