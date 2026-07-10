import 'package:flutter_test/flutter_test.dart';
import 'package:running_laps/core/services/zones_service.dart';

void main() {
  final zones = ZonesService();

  group('ZonesService.fcMaxEffective', () {
    test('usa el valor manual si existe', () {
      expect(zones.fcMaxEffective(192, '1990-05-15'), 192);
    });

    test('calcula 220 - edad desde birthDate', () {
      final birth = DateTime(1990, 5, 15);
      final today = DateTime.now();
      var age = today.year - birth.year;
      if (today.month < birth.month ||
          (today.month == birth.month && today.day < birth.day)) {
        age--;
      }
      expect(zones.fcMaxEffective(null, '1990-05-15'), 220 - age);
    });

    test('sin datos suficientes devuelve null', () {
      expect(zones.fcMaxEffective(null, null), isNull);
      expect(zones.fcMaxEffective(null, 'no-es-fecha'), isNull);
    });

    test('fecha de nacimiento futura devuelve null', () {
      final future = DateTime.now().add(const Duration(days: 365));
      expect(
        zones.fcMaxEffective(null, future.toIso8601String()),
        isNull,
      );
    });
  });

  group('ZonesService.zonesFor', () {
    test('genera 5 zonas con límites contiguos para fcMax 200', () {
      final result = zones.zonesFor(200);

      expect(result, hasLength(5));
      expect(result[0].minBpm, 0);
      expect(result[0].maxBpm, 120); // 60%
      expect(result[1].minBpm, 120);
      expect(result[1].maxBpm, 140); // 70%
      expect(result[2].minBpm, 140);
      expect(result[2].maxBpm, 160); // 80%
      expect(result[3].minBpm, 160);
      expect(result[3].maxBpm, 180); // 90%
      expect(result[4].minBpm, 180);
      expect(result[4].maxBpm, 999); // Z5 sin techo

      // Contiguidad: el max de cada zona es el min de la siguiente
      for (var i = 0; i < 4; i++) {
        expect(result[i].maxBpm, result[i + 1].minBpm);
      }
    });
  });

  group('ZonesService.zoneFor', () {
    test('clasifica FC en su zona', () {
      expect(zones.zoneFor(100, 200), 1);
      expect(zones.zoneFor(130, 200), 2);
      expect(zones.zoneFor(150, 200), 3);
      expect(zones.zoneFor(170, 200), 4);
      expect(zones.zoneFor(185, 200), 5);
    });

    test('límite exacto pertenece a la zona superior', () {
      expect(zones.zoneFor(120, 200), 2);
      expect(zones.zoneFor(180, 200), 5);
    });
  });
}
