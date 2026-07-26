import 'package:flutter_test/flutter_test.dart';
import 'package:running_laps/features/history/viewmodels/history_controller.dart';
import 'package:running_laps/features/training/data/entrenamiento.dart';
import 'package:running_laps/features/training/data/serie.dart';

/// Filtros del historial. Son la única forma que tiene el usuario de encontrar
/// un entreno concreto entre cientos, y fallan en silencio: si un filtro se
/// come un entrenamiento, parece que no existe.
void main() {
  late HistoryController controller;

  setUp(() {
    controller = HistoryController();
  });

  tearDown(() => controller.dispose());

  Entrenamiento t({
    required String titulo,
    required DateTime fecha,
    int distanciaM = 5000,
    double rpe = 6,
    List<String>? tags,
  }) {
    return Entrenamiento(
      titulo: titulo,
      fecha: fecha,
      gps: true,
      tags: tags,
      series: [
        Serie(tiempoSec: 1500, distanciaM: distanciaM, descansoSec: 0, rpe: rpe),
      ],
    );
  }

  List<String> titulos() =>
      controller.trainings.value.map((e) => e.titulo).toList();

  group('filtros predefinidos', () {
    test('"últimos 7 días" deja fuera lo más antiguo', () {
      final now = DateTime.now();
      controller.debugSeedTrainings([
        t(titulo: 'ayer', fecha: now.subtract(const Duration(days: 1))),
        t(titulo: 'hace 3 días', fecha: now.subtract(const Duration(days: 3))),
        t(titulo: 'hace 20 días', fecha: now.subtract(const Duration(days: 20))),
      ]);

      controller.setFilter(TrainingFilter.last7Days);

      expect(titulos(), ['ayer', 'hace 3 días']);
    });

    test('"tiradas largas" es más de 10 km', () {
      controller.debugSeedTrainings([
        t(titulo: 'corta', fecha: DateTime(2026, 7, 20), distanciaM: 8000),
        t(titulo: 'justa', fecha: DateTime(2026, 7, 21), distanciaM: 10000),
        t(titulo: 'larga', fecha: DateTime(2026, 7, 22), distanciaM: 15000),
      ]);

      controller.setFilter(TrainingFilter.longRuns);

      expect(titulos(), ['larga'],
          reason: '10 km exactos no cuenta: el criterio es > 10 km');
    });

    test('"alta intensidad" es RPE medio por encima de 7', () {
      controller.debugSeedTrainings([
        t(titulo: 'suave', fecha: DateTime(2026, 7, 20), rpe: 5),
        t(titulo: 'fuerte', fecha: DateTime(2026, 7, 21), rpe: 8.5),
      ]);

      controller.setFilter(TrainingFilter.highIntensity);

      expect(titulos(), ['fuerte']);
    });

    test('"todos" no filtra nada', () {
      controller.debugSeedTrainings([
        t(titulo: 'a', fecha: DateTime(2020, 1, 1)),
        t(titulo: 'b', fecha: DateTime(2026, 7, 21)),
      ]);

      controller.setFilter(TrainingFilter.all);

      expect(titulos(), hasLength(2));
    });
  });

  group('rango de fechas personalizado', () {
    test('incluye los días de los extremos completos', () {
      controller.debugSeedTrainings([
        t(titulo: 'antes', fecha: DateTime(2026, 7, 19, 23, 59)),
        t(titulo: 'primer día', fecha: DateTime(2026, 7, 20, 0, 1)),
        t(titulo: 'último día', fecha: DateTime(2026, 7, 26, 23, 58)),
        t(titulo: 'después', fecha: DateTime(2026, 7, 27, 0, 1)),
      ]);

      controller.filterStartDate.value = DateTime(2026, 7, 20);
      controller.filterEndDate.value = DateTime(2026, 7, 26);
      controller.applyFilters();

      expect(titulos(), ['primer día', 'último día'],
          reason: 'el rango va de las 00:00 del primer día a las 23:59 del último');
    });

    test('el rango personalizado manda sobre el filtro predefinido', () {
      final now = DateTime.now();
      controller.debugSeedTrainings([
        t(titulo: 'viejo', fecha: DateTime(2020, 3, 1)),
        t(titulo: 'reciente', fecha: now.subtract(const Duration(days: 2))),
      ]);

      controller.setFilter(TrainingFilter.last7Days);
      controller.filterStartDate.value = DateTime(2020, 1, 1);
      controller.filterEndDate.value = DateTime(2020, 12, 31);
      controller.applyFilters();

      expect(titulos(), ['viejo']);
    });
  });

  group('búsqueda y etiquetas', () {
    test('la búsqueda por título no distingue mayúsculas', () {
      controller.debugSeedTrainings([
        t(titulo: 'Series en Cuestas', fecha: DateTime(2026, 7, 20)),
        t(titulo: 'Rodaje suave', fecha: DateTime(2026, 7, 21)),
      ]);

      controller.searchQuery.value = 'cuestas';
      controller.applyFilters();

      expect(titulos(), ['Series en Cuestas']);
    });

    test('las etiquetas suman: basta con tener una de las seleccionadas', () {
      controller.debugSeedTrainings([
        t(titulo: 'con tempo', fecha: DateTime(2026, 7, 20), tags: ['tempo']),
        t(titulo: 'con series', fecha: DateTime(2026, 7, 21), tags: ['series']),
        t(titulo: 'sin etiquetas', fecha: DateTime(2026, 7, 22)),
      ]);

      controller.selectedTags.value = {'tempo', 'series'};
      controller.applyFilters();

      expect(titulos(), ['con tempo', 'con series']);
    });

    test('los filtros se combinan entre sí', () {
      controller.debugSeedTrainings([
        t(titulo: 'largo con tag', fecha: DateTime(2026, 7, 20),
            distanciaM: 15000, tags: ['largo']),
        t(titulo: 'largo sin tag', fecha: DateTime(2026, 7, 21),
            distanciaM: 15000),
        t(titulo: 'corto con tag', fecha: DateTime(2026, 7, 22),
            distanciaM: 4000, tags: ['largo']),
      ]);

      controller.setFilter(TrainingFilter.longRuns);
      controller.selectedTags.value = {'largo'};
      controller.applyFilters();

      expect(titulos(), ['largo con tag']);
    });
  });
}
