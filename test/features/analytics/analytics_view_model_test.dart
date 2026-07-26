import 'package:flutter_test/flutter_test.dart';
import 'package:running_laps/features/analytics/viewmodels/analytics_hub_controller.dart'
    show AnalyticsTimeRange;
import 'package:running_laps/features/analytics/viewmodels/analytics_view_model.dart';
import 'package:running_laps/features/training/data/entrenamiento.dart';
import 'package:running_laps/features/training/data/serie.dart';

/// Números de la pantalla de Analytics.
///
/// Son cifras que el usuario lee y se cree — récords, ritmo medio, reparto de
/// intensidad, racha, ACWR. Un error aquí no rompe nada: simplemente le cuenta
/// otra historia sobre su entrenamiento. `compute()` es función pura de sus
/// argumentos, así que se puede fijar entera.
void main() {
  late AnalyticsViewModel vm;

  setUp(() => vm = AnalyticsViewModel());

  Entrenamiento t({
    required DateTime fecha,
    int distanciaM = 1000,
    double tiempoSec = 300,
    double rpe = 5,
    double? loadScore,
    String titulo = 'Entreno',
  }) {
    return Entrenamiento(
      titulo: titulo,
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

  group('reparto de intensidad', () {
    test('el corte está en RPE 7: menos es suave, 7 o más es fuerte', () {
      final workouts = [
        t(fecha: DateTime(2026, 7, 20), rpe: 6.9),
        t(fecha: DateTime(2026, 7, 21), rpe: 7.0),
        t(fecha: DateTime(2026, 7, 22), rpe: 4),
        t(fecha: DateTime(2026, 7, 23), rpe: 9),
      ];

      vm.compute(workouts, workouts, AnalyticsTimeRange.month);

      expect(vm.intensityEasyPct.value, 50);
      expect(vm.intensityHardPct.value, 50);
    });

    test('sin entrenos el reparto es 0/0, no una división por cero', () {
      vm.compute(const [], const [], AnalyticsTimeRange.month);

      expect(vm.intensityEasyPct.value, 0);
      expect(vm.intensityHardPct.value, 0);
    });
  });

  group('récords personales', () {
    test('se queda con el mejor ritmo de cada distancia estándar', () {
      final workouts = [
        // 1000 m a 5:00/km
        t(fecha: DateTime(2026, 5, 1), distanciaM: 1000, tiempoSec: 300),
        // 1000 m a 4:20/km — mejor
        t(fecha: DateTime(2026, 6, 1), distanciaM: 1000, tiempoSec: 260),
        // 1000 m a 5:30/km — peor, no debe pisar al anterior
        t(fecha: DateTime(2026, 7, 1), distanciaM: 1000, tiempoSec: 330),
      ];

      vm.compute(workouts, workouts, AnalyticsTimeRange.year);

      final record = vm.personalRecords.value[1000];
      expect(record, isNotNull);
      expect(record!.totalTimeSec, 260);
      expect(record.date, DateTime(2026, 6, 1));
    });

    test('una distancia sin datos no aparece en los récords', () {
      final workouts = [
        t(fecha: DateTime(2026, 6, 1), distanciaM: 1000, tiempoSec: 300),
      ];

      vm.compute(workouts, workouts, AnalyticsTimeRange.year);

      expect(vm.personalRecords.value.containsKey(10000), isFalse);
    });
  });

  group('consistencia', () {
    test('cuenta semanas distintas con actividad, no entrenos', () {
      final workouts = [
        // Dos el mismo lunes y otro el miércoles: una sola semana activa.
        t(fecha: DateTime(2026, 7, 20)),
        t(fecha: DateTime(2026, 7, 20)),
        t(fecha: DateTime(2026, 7, 22)),
        // Semana anterior.
        t(fecha: DateTime(2026, 7, 15)),
      ];

      vm.compute(workouts, workouts, AnalyticsTimeRange.month);

      expect(vm.consistencyWeeks.value, 2);
    });

    test('la media de sesiones por semana usa las semanas del rango', () {
      final workouts = [
        t(fecha: DateTime(2026, 7, 20)),
        t(fecha: DateTime(2026, 7, 21)),
        t(fecha: DateTime(2026, 7, 22)),
        t(fecha: DateTime(2026, 7, 23)),
      ];

      vm.compute(workouts, workouts, AnalyticsTimeRange.month);

      // 30 días → 5 semanas (redondeo hacia arriba): 4 sesiones / 5 semanas.
      expect(vm.avgSessionsPerWeek.value, closeTo(0.8, 0.001));
    });
  });

  group('carga aguda y crónica (ACWR)', () {
    test('sin carga crónica el ratio es 0, no infinito', () {
      final now = DateTime.now();
      final workouts = [
        t(fecha: now.subtract(const Duration(days: 1)), loadScore: 200),
      ];

      vm.compute(workouts, workouts, AnalyticsTimeRange.month);

      expect(vm.acuteLoad.value, 200);
      // La crónica promedia 4 semanas: con una sola sesión reciente el ratio
      // no puede dispararse a infinito.
      expect(vm.acwrRatio.value.isFinite, isTrue);
    });

    test('la carga aguda solo cuenta los últimos 7 días', () {
      final now = DateTime.now();
      final workouts = [
        t(fecha: now.subtract(const Duration(days: 2)), loadScore: 100),
        t(fecha: now.subtract(const Duration(days: 20)), loadScore: 900),
      ];

      vm.compute(workouts, workouts, AnalyticsTimeRange.month);

      expect(vm.acuteLoad.value, 100,
          reason: 'la sesión de hace 20 días no es carga aguda');
    });
  });

  group('ritmo medio', () {
    test('pondera por distancia, no hace la media de los ritmos', () {
      // 1 km a 6:00 y 9 km a 4:00 → el ritmo medio real es 4:12, no 5:00.
      final workouts = [
        t(fecha: DateTime(2026, 7, 20), distanciaM: 1000, tiempoSec: 360),
        t(fecha: DateTime(2026, 7, 21), distanciaM: 9000, tiempoSec: 2160),
      ];

      vm.compute(workouts, workouts, AnalyticsTimeRange.month);

      expect(vm.avgPaceCurrent.value, closeTo(252, 0.5)); // 4:12/km
    });
  });
}
