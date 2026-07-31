import 'package:flutter_test/flutter_test.dart';
import 'package:running_laps/features/training/data/fc_analytics.dart';
import 'package:running_laps/features/training/data/fc_reading.dart';
import 'package:running_laps/features/training/data/serie.dart';

Serie _serie({
  required double tiempoSec,
  required int distanciaM,
  List<int>? bpms,
}) {
  return Serie(
    tiempoSec:   tiempoSec,
    distanciaM:  distanciaM,
    descansoSec: 0,
    rpe:         5,
    fcReadings: bpms
        ?.map((b) => FcReading(bpm: b, timestamp: DateTime(2026, 7, 29)))
        .toList(),
  );
}

void main() {
  // FCmáx 200 → Z1 <120, Z2 120-139, Z3 140-159, Z4 160-179, Z5 ≥180
  const fcMax = 200;

  group('zoneMinutes / zonePercentages', () {
    test('null sin lecturas o sin fcMax', () {
      expect(FcAnalytics.zoneMinutes([_serie(tiempoSec: 600, distanciaM: 2000)], fcMax), isNull);
      expect(
        FcAnalytics.zoneMinutes(
            [_serie(tiempoSec: 600, distanciaM: 2000, bpms: [150])], null),
        isNull,
      );
      expect(
        FcAnalytics.zoneMinutes(
            [_serie(tiempoSec: 600, distanciaM: 2000, bpms: [150])], 0),
        isNull,
      );
    });

    test('reparte los minutos de la serie entre sus lecturas', () {
      // 10 min, 4 lecturas → 2,5 min cada una. Dos en Z2 y dos en Z4.
      final minutes = FcAnalytics.zoneMinutes(
        [_serie(tiempoSec: 600, distanciaM: 2000, bpms: [125, 130, 165, 170])],
        fcMax,
      )!;

      expect(minutes[1], closeTo(5.0, 0.001)); // Z2
      expect(minutes[3], closeTo(5.0, 0.001)); // Z4
      expect(minutes[0], 0);
      expect(minutes[2], 0);
      expect(minutes[4], 0);
    });

    test('pesa por tiempo, no por número de lecturas', () {
      // El sesgo que evita: la serie corta se muestrea 4x más densa que el
      // rodaje. Contando lecturas saldría 50/50; por tiempo es 1 min vs 20.
      final minutes = FcAnalytics.zoneMinutes(
        [
          _serie(tiempoSec: 60, distanciaM: 300, bpms: List.filled(20, 185)),
          _serie(tiempoSec: 1200, distanciaM: 4000, bpms: List.filled(5, 125)),
        ],
        fcMax,
      )!;

      expect(minutes[4], closeTo(1.0, 0.001));  // Z5 — 1 min
      expect(minutes[1], closeTo(20.0, 0.001)); // Z2 — 20 min
    });

    test('los porcentajes suman 100', () {
      final pct = FcAnalytics.zonePercentages(
        [
          _serie(tiempoSec: 60, distanciaM: 300, bpms: List.filled(20, 185)),
          _serie(tiempoSec: 1200, distanciaM: 4000, bpms: List.filled(5, 125)),
        ],
        fcMax,
      )!;

      expect(pct.fold<double>(0, (a, b) => a + b), closeTo(100.0, 0.001));
      expect(pct[1], closeTo(100 * 20 / 21, 0.01));
    });
  });

  group('efficiencyIndex', () {
    test('metros por minuto entre pulsaciones', () {
      // 3000 m en 15 min = 200 m/min; a 150 bpm → 1,333 m/min/bpm
      final ei = FcAnalytics.efficiencyIndex(
        [_serie(tiempoSec: 900, distanciaM: 3000, bpms: [150, 150])],
      )!;
      expect(ei, closeTo(200 / 150, 0.001));
    });

    test('null sin distancia o sin FC', () {
      expect(
        FcAnalytics.efficiencyIndex(
            [_serie(tiempoSec: 900, distanciaM: 0, bpms: [150])]),
        isNull,
      );
      expect(
        FcAnalytics.efficiencyIndex([_serie(tiempoSec: 900, distanciaM: 3000)]),
        isNull,
      );
    });

    test('a igual ritmo, menos pulsaciones es más eficiente', () {
      final antes = FcAnalytics.efficiencyIndex(
          [_serie(tiempoSec: 900, distanciaM: 3000, bpms: [160])])!;
      final despues = FcAnalytics.efficiencyIndex(
          [_serie(tiempoSec: 900, distanciaM: 3000, bpms: [145])])!;
      expect(despues, greaterThan(antes));
    });
  });

  group('hrDriftBpm', () {
    test('null con menos de 4 lecturas', () {
      expect(
        FcAnalytics.hrDriftBpm(
            [_serie(tiempoSec: 600, distanciaM: 2000, bpms: [140, 150, 160])]),
        isNull,
      );
    });

    test('positivo cuando la FC sube en la segunda mitad', () {
      final drift = FcAnalytics.hrDriftBpm([
        _serie(tiempoSec: 1200, distanciaM: 4000, bpms: [140, 140, 150, 150]),
      ])!;
      expect(drift, closeTo(10.0, 0.001));
    });

    test('negativo cuando baja', () {
      final drift = FcAnalytics.hrDriftBpm([
        _serie(tiempoSec: 1200, distanciaM: 4000, bpms: [160, 160, 150, 150]),
      ])!;
      expect(drift, closeTo(-10.0, 0.001));
    });
  });

  group('decouplingPercent', () {
    test('null con menos de 2 series utilizables', () {
      expect(
        FcAnalytics.decouplingPercent(
            [_serie(tiempoSec: 1200, distanciaM: 4000, bpms: [140, 150])]),
        isNull,
      );
    });

    test('cero cuando la eficiencia se mantiene', () {
      final d = FcAnalytics.decouplingPercent([
        _serie(tiempoSec: 600, distanciaM: 2000, bpms: [150]),
        _serie(tiempoSec: 600, distanciaM: 2000, bpms: [150]),
      ])!;
      expect(d, closeTo(0.0, 0.001));
    });

    test('positivo cuando sube la FC al mismo ritmo', () {
      // Mismo ritmo las dos mitades, pero la segunda a 165 en vez de 150:
      // la eficiencia cae y el desacople es (1 - 150/165) ≈ 9,1 %.
      final d = FcAnalytics.decouplingPercent([
        _serie(tiempoSec: 600, distanciaM: 2000, bpms: [150]),
        _serie(tiempoSec: 600, distanciaM: 2000, bpms: [165]),
      ])!;
      expect(d, closeTo((1 - 150 / 165) * 100, 0.01));
    });

    test('no se dispara si el atleta acelera y la FC sube en proporción', () {
      // Segunda mitad más rápida (2400 m en el mismo tiempo) con la FC
      // subiendo lo justo: la eficiencia se mantiene → desacople ~0.
      final d = FcAnalytics.decouplingPercent([
        _serie(tiempoSec: 600, distanciaM: 2000, bpms: [150]),
        _serie(tiempoSec: 600, distanciaM: 2400, bpms: [180]),
      ])!;
      expect(d, closeTo(0.0, 0.001));
    });
  });
}
