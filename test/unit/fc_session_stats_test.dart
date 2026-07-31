import 'package:flutter_test/flutter_test.dart';
import 'package:running_laps/features/training/data/fc_reading.dart';
import 'package:running_laps/features/training/data/fc_session_stats.dart';
import 'package:running_laps/features/training/data/serie.dart';

Serie _serie({
  required double tiempoSec,
  double? fcMedia,
  List<int>? bpms,
}) {
  return Serie(
    tiempoSec:   tiempoSec,
    distanciaM:  1000,
    descansoSec: 0,
    rpe:         5,
    fcMedia:     fcMedia,
    fcReadings: bpms
        ?.map((b) => FcReading(bpm: b, timestamp: DateTime(2026, 7, 29)))
        .toList(),
  );
}

void main() {
  group('FcSessionStats.from', () {
    test('sin FC devuelve null', () {
      expect(FcSessionStats.from([_serie(tiempoSec: 600)]), isNull);
      expect(FcSessionStats.from([]), isNull);
    });

    test('media, mínimo y pico sobre las lecturas reales', () {
      final stats = FcSessionStats.from([
        _serie(tiempoSec: 300, bpms: [120, 140, 160]),
        _serie(tiempoSec: 300, bpms: [180, 100]),
      ])!;

      expect(stats.avgBpm, closeTo(140.0, 0.001)); // (120+140+160+180+100)/5
      expect(stats.minBpm, 100);
      expect(stats.maxBpm, 180);
      expect(stats.sampleCount, 5);
      expect(stats.isFromRawReadings, isTrue);
    });

    test('la media pesa cada lectura igual, no cada serie', () {
      // El bug que corrige: 1 lectura a 180 en una serie corta y 9 lecturas a
      // 120 en un rodaje largo. Promediando por serie salen 150; la media real
      // de las lecturas es 126.
      final stats = FcSessionStats.from([
        _serie(tiempoSec: 30, bpms: [180]),
        _serie(tiempoSec: 1200, bpms: List.filled(9, 120)),
      ])!;

      expect(stats.avgBpm, closeTo(126.0, 0.001));
      expect(stats.sampleCount, 10);
    });

    test('ignora lecturas no válidas (bpm <= 0)', () {
      final stats = FcSessionStats.from([
        _serie(tiempoSec: 300, bpms: [0, 150, 0, 170]),
      ])!;

      expect(stats.avgBpm, closeTo(160.0, 0.001));
      expect(stats.minBpm, 150);
      expect(stats.maxBpm, 170);
      expect(stats.sampleCount, 2);
    });

    test('sin lecturas, pondera las medias por serie según duración', () {
      // 10 min a 130 y 1 min a 170: la media honesta es ~133,6, no 150.
      final stats = FcSessionStats.from([
        _serie(tiempoSec: 600, fcMedia: 130),
        _serie(tiempoSec: 60,  fcMedia: 170),
      ])!;

      expect(stats.avgBpm, closeTo((130 * 600 + 170 * 60) / 660, 0.001));
      expect(stats.sampleCount, 0);
      expect(stats.isFromRawReadings, isFalse);
      // Sin lecturas punto a punto no hay pico real: son las medias por serie.
      expect(stats.minBpm, 130);
      expect(stats.maxBpm, 170);
    });

    test('una serie de tiempo 0 con FC no anula el peso total', () {
      final stats = FcSessionStats.from([_serie(tiempoSec: 0, fcMedia: 150)])!;
      expect(stats.avgBpm, closeTo(150.0, 0.001));
    });

    test('las lecturas reales mandan sobre las medias por serie', () {
      // Serie con lecturas + serie solo con fcMedia: se usan las lecturas y la
      // fcMedia suelta se ignora (mezclarlas daría un peso arbitrario).
      final stats = FcSessionStats.from([
        _serie(tiempoSec: 300, bpms: [140, 160]),
        _serie(tiempoSec: 300, fcMedia: 100),
      ])!;

      expect(stats.avgBpm, closeTo(150.0, 0.001));
      expect(stats.sampleCount, 2);
    });
  });
}
