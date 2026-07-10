import 'package:flutter_test/flutter_test.dart';
import 'package:running_laps/core/services/training_load_service.dart';
import 'package:running_laps/features/athlete/data/athlete_session_model.dart';

void main() {
  const service = TrainingLoadService.instance;

  AthleteSession makeSession({
    required String date,
    String? category,
  }) {
    return AthleteSession(
      id: 'id-$date',
      uid: 'u1',
      date: date,
      category: category,
      status: AthleteSessionStatus.planned,
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    );
  }

  group('TrainingLoadService.calculateLoad', () {
    test('con datos de FC usa TRIMP (Banister)', () {
      final load = service.calculateLoad(
        distanceKm: 10,
        durationMinutes: 60,
        fcAvgBpm: 150,
        fcMax: 190,
        fcRest: 50,
      );
      // TRIMP = 60 × 0.714 × 0.64 × e^(1.92×0.714) ≈ 108
      expect(load, closeTo(108, 3));
    });

    test('sin FC usa proxy distancia × intensidad de categoría', () {
      expect(
        service.calculateLoad(
          distanceKm: 10,
          durationMinutes: 60,
          category: 'rodaje_base',
        ),
        closeTo(10.0, 0.001),
      );
      expect(
        service.calculateLoad(
          distanceKm: 10,
          durationMinutes: 45,
          category: 'series_cortas',
        ),
        closeTo(20.0, 0.001),
      );
    });

    test('el RPE ajusta la intensidad del proxy', () {
      final base = service.calculateLoad(
        distanceKm: 10,
        durationMinutes: 60,
        category: 'tempo',
      );
      final harder = service.calculateLoad(
        distanceKm: 10,
        durationMinutes: 60,
        category: 'tempo',
        rpeAverage: 8,
      );
      expect(harder, greaterThan(base));
    });

    test('FC media por debajo de la de reposo cae al proxy', () {
      final load = service.calculateLoad(
        distanceKm: 5,
        durationMinutes: 30,
        category: 'rodaje_base',
        fcAvgBpm: 45,
        fcMax: 190,
        fcRest: 50,
      );
      expect(load, closeTo(5.0, 0.001));
    });
  });

  group('TrainingLoadService.nextRace', () {
    test('devuelve la próxima competición ordenada por fecha', () {
      final sessions = [
        makeSession(date: '2026-08-01', category: 'competicion'),
        makeSession(date: '2026-07-20', category: 'competicion'),
        makeSession(date: '2026-07-15', category: 'rodaje_base'),
      ];
      final race = service.nextRace(sessions, DateTime(2026, 7, 10));
      expect(race?.date, '2026-07-20');
    });

    test('ignora competiciones pasadas', () {
      final sessions = [
        makeSession(date: '2026-06-01', category: 'competicion'),
      ];
      expect(service.nextRace(sessions, DateTime(2026, 7, 10)), isNull);
    });

    test('una fecha malformada no rompe el filtro (regresión)', () {
      final sessions = [
        makeSession(date: 'fecha-corrupta', category: 'competicion'),
        makeSession(date: '2026-07-20', category: 'competicion'),
      ];
      final race = service.nextRace(sessions, DateTime(2026, 7, 10));
      expect(race?.date, '2026-07-20');
    });
  });

  group('TrainingLoadService.isRaceWeek / daysUntil', () {
    test('true dentro de los 7 días previos', () {
      final sessions = [
        makeSession(date: '2026-07-15', category: 'competicion'),
      ];
      expect(service.isRaceWeek(DateTime(2026, 7, 10), sessions), isTrue);
      expect(service.isRaceWeek(DateTime(2026, 7, 1), sessions), isFalse);
    });

    test('daysUntil cuenta días naturales', () {
      final session = makeSession(date: '2026-07-15');
      expect(service.daysUntil(session, DateTime(2026, 7, 10, 23, 59)), 5);
      expect(service.daysUntil(session, DateTime(2026, 7, 15, 8)), 0);
    });
  });
}
