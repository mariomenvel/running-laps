import 'package:flutter_test/flutter_test.dart';
import 'package:running_laps/features/templates/data/template_models.dart';

/// Vocabulario de categorías de sesión — fuente única.
///
/// Había dos mapas sueltos de "slug → nombre bonito" (`home_view` y
/// `notification_service`) que no cubrían lo mismo, y el enum no conocía dos
/// categorías que el Coach **sí** genera. El atleta veía "series_medias" tal
/// cual en su pantalla de inicio, y `fromValue` convertía esas sesiones en
/// rodaje base sin avisar.
void main() {
  group('SessionCategory cubre lo que el Coach genera', () {
    // Las que produce `_normalizeCategory` en ai_coach_session_generator.dart.
    const generadasPorElCoach = [
      'rodaje_base',
      'rodaje_largo',
      'regenerativo',
      'tempo',
      'fartlek',
      'series_cortas',
      'series_medias',
      'series_largas',
      'series_cuestas',
      'series_mixtas',
      'gimnasio_fuerza',
    ];

    test('el round-trip slug -> enum -> slug no pierde ninguna', () {
      for (final slug in generadasPorElCoach) {
        final cat = SessionCategoryX.fromValue(slug);
        expect(cat.toValue, slug,
            reason: '"$slug" no sobrevive el round-trip: se convierte en '
                '"${cat.toValue}". fromValue cae a rodajeBase por defecto, así '
                'que una categoría que falte se degrada en silencio.');
      }
    });

    test('ninguna se queda sin nombre legible', () {
      for (final slug in generadasPorElCoach) {
        final label = SessionCategoryX.labelForValue(slug);
        expect(label, isNot(contains('_')),
            reason: '"$slug" muestra el identificador crudo en pantalla');
        expect(label, isNot(slug));
      }
    });

    test('las dos que faltaban están', () {
      expect(SessionCategoryX.labelForValue('series_medias'), 'Series medias');
      expect(SessionCategoryX.labelForValue('rodaje_largo'), 'Rodaje largo');
    });

    test('un slug desconocido no revienta ni enseña el slug', () {
      // Si el LLM inventa una categoría, mejor un genérico que un crudo.
      expect(SessionCategoryX.labelForValue('lo_que_sea'), isNot(contains('_')));
    });

    test('vacío o null caen en un genérico', () {
      expect(SessionCategoryX.labelForValue(null), 'Entrenamiento');
      expect(SessionCategoryX.labelForValue('  '), 'Entrenamiento');
    });
  });
}
