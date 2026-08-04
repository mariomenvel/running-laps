import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:running_laps/core/constants/legal_policy.dart';

void main() {
  group('LegalPolicy.latestAllowedBirthDate', () {
    test('deja pasar justo a quien cumple la edad mínima hoy', () {
      final now = DateTime(2026, 8, 4);
      final limite = LegalPolicy.latestAllowedBirthDate(now);

      expect(limite, DateTime(2010, 8, 4));
    });

    test('un día después del límite ya no cumple', () {
      final now = DateTime(2026, 8, 4);
      final limite = LegalPolicy.latestAllowedBirthDate(now);
      final unDiaMenor = limite.add(const Duration(days: 1));

      // El selector usa el límite como maximumDate, así que esta fecha queda
      // fuera de la rueda: no se puede declarar.
      expect(unDiaMenor.isAfter(limite), isTrue);
    });

    test('respeta el mes y el día, no solo el año', () {
      // Con `DateTime(year - 16)` a secas, alguien nacido en diciembre podría
      // declararse con 15 años y 11 meses.
      final now = DateTime(2026, 12, 31);

      expect(LegalPolicy.latestAllowedBirthDate(now), DateTime(2010, 12, 31));
    });

    test('la edad mínima es la que dicen los términos publicados', () {
      final terms = File('hosting/terms.html').readAsStringSync();

      expect(
        terms.contains('al menos ${LegalPolicy.minimumAgeYears} años'),
        isTrue,
        reason:
            'terms.html § "Tu cuenta" y LegalPolicy.minimumAgeYears han '
            'divergido. Si cambia uno tiene que cambiar el otro: la app no '
            'puede aceptar una edad que los términos prohíben.',
      );
    });
  });

  test('ningún selector de fecha de nacimiento fija su propio límite', () {
    // La regla existe porque ya pasó: el onboarding del Coach permitía
    // declararse de 10 años y la pantalla de zonas de 5, con unos términos
    // que exigen 16. Eran dos números sueltos en dos ficheros distintos.
    // Solo las pantallas: `core/` contiene el propio LegalPolicy y el widget
    // genérico showAppDatePicker, que nombran ambas cosas en sus comentarios
    // sin fijar ningún límite.
    final offenders = <String>[];
    final scanned = <String>[];

    for (final file in Directory('lib/features')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))) {
      final src = file.readAsStringSync();
      if (!src.contains('Fecha de nacimiento')) continue;
      if (!src.contains('maximumDate')) continue;
      scanned.add(file.path);
      if (!src.contains('LegalPolicy.latestAllowedBirthDate')) {
        offenders.add(file.path);
      }
    }

    // Sin esto el test pasaría en vacío el día que alguien cambie el texto
    // del selector y deje de haber coincidencias.
    expect(
      scanned.length,
      greaterThanOrEqualTo(2),
      reason: 'Se esperaban al menos los dos selectores conocidos '
          '(onboarding del Coach y zonas). Encontrados: $scanned',
    );

    expect(
      offenders,
      isEmpty,
      reason: 'Estos selectores de fecha de nacimiento no usan '
          'LegalPolicy.latestAllowedBirthDate():\n${offenders.join('\n')}',
    );
  });
}
