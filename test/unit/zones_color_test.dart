import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:running_laps/core/services/zones_service.dart';
import 'package:running_laps/core/theme/app_colors.dart';

/// Color de zona de FC — fuente única.
///
/// Había seis implementaciones de "zona → color" repartidas por la app y no
/// coincidían: en el editor de bloques Z1 salía verde y Z2 azul, al revés que
/// en el resto, así que el atleta elegía "Z2" viendo azul y luego, corriendo,
/// esa misma Z2 se pintaba verde. Estos tests fijan la tabla y vigilan que no
/// vuelvan a aparecer copias.
void main() {
  group('ZonesService.colorForZone', () {
    test('la tabla canónica es la escala de esfuerzo', () {
      expect(ZonesService.colorForZone(1), AppColors.rest);
      expect(ZonesService.colorForZone(2), AppColors.rpeLow);
      expect(ZonesService.colorForZone(3), AppColors.rpeMid);
      expect(ZonesService.colorForZone(4), AppColors.effort);
      expect(ZonesService.colorForZone(5), AppColors.rpeMax);
    });

    test('Z1 es azul y Z2 verde, no al revés', () {
      // El fallo concreto que se arregló: estaban intercambiadas en el editor.
      expect(ZonesService.colorForZone(1), AppColors.rest);
      expect(ZonesService.colorForZone(2), isNot(AppColors.rest));
    });

    test('coincide con el color que reparte zonesFor', () {
      // FcZoneBars pinta desde zonesFor; el resto desde colorForZone. Si se
      // separan, el mismo entreno se ve de dos colores.
      final zonas = ZonesService().zonesFor(190);
      for (var i = 0; i < 5; i++) {
        expect(zonas[i].color, ZonesService.colorForZone(i + 1),
            reason: 'Z${i + 1} no coincide con zonesFor');
      }
    });

    test('fuera de rango se clampea en vez de reventar', () {
      expect(ZonesService.colorForZone(0), AppColors.rest);
      expect(ZonesService.colorForZone(9), AppColors.rpeMax);
    });
  });

  group('ZonesService.zoneForPercent', () {
    test('respeta los límites de zonesFor (60/70/80/90)', () {
      expect(ZonesService.zoneForPercent(50), 1);
      expect(ZonesService.zoneForPercent(59), 1);
      expect(ZonesService.zoneForPercent(60), 2);
      expect(ZonesService.zoneForPercent(69), 2);
      expect(ZonesService.zoneForPercent(70), 3);
      expect(ZonesService.zoneForPercent(79), 3);
      expect(ZonesService.zoneForPercent(80), 4);
      expect(ZonesService.zoneForPercent(89), 4);
      expect(ZonesService.zoneForPercent(90), 5);
      expect(ZonesService.zoneForPercent(100), 5);
    });

    test('al 90% o más el color es el de Z5, no el de Z4', () {
      // El chip de FC% iba desplazado una zona entera: al máximo esfuerzo
      // pintaba coral (Z4) en vez de rojo.
      expect(ZonesService.colorForPercent(95), AppColors.rpeMax);
      expect(ZonesService.colorForPercent(85), AppColors.effort);
    });

    test('coincide con zoneFor sobre pulsaciones absolutas', () {
      const fcMax = 200;
      for (final pct in [50, 65, 75, 85, 95]) {
        final bpm = (fcMax * pct / 100).round();
        expect(ZonesService.zoneForPercent(pct),
            ZonesService().zoneFor(bpm, fcMax),
            reason: 'discrepancia al $pct% de FCmáx');
      }
    });
  });

  test('nadie se define su propia tabla de colores de zona', () {
    // Cualquier sitio que pinte una zona debe salir de ZonesService. Este test
    // busca los hex de las paletas paralelas que se eliminaron.
    const huerfanos = [
      '0xFF639922', // verde que el editor usaba para Z1
      '0xFF7FB069', // verde de la paleta propia de la sesión activa
      '0xFFE9C46A', // amarillo íd.
      '0xFFE76F51', // naranja íd. (y del fartlek por tipo)
      '0xFFD62828', // rojo íd.
      '0xFF5A9E9E', // teal de Z1 en training_session_view
    ];
    final offenders = <String>[];
    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final src = entity.readAsStringSync();
      for (final hex in huerfanos) {
        if (src.contains(hex)) offenders.add('${entity.path} → $hex');
      }
    }
    expect(offenders, isEmpty, reason: offenders.join('\n'));
  });
}
