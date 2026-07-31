import 'serie.dart';

/// Estadísticas de frecuencia cardíaca de una sesión completa.
///
/// ⚠️ La media **no** es el promedio de las `fcMedia` de cada serie: eso pesa
/// igual una serie de 30 s que un rodaje de 20 min, y sesgaba la FC media de
/// la sesión hacia las series cortas (que suelen ser las más intensas). Se
/// calcula sobre todas las lecturas reales del pulsómetro; solo cuando no hay
/// lecturas —entreno manual con FC introducida a mano— se cae a las medias por
/// serie, y entonces ponderadas por duración.
///
/// Lógica pura, sin Firebase ni Flutter: cubierta por
/// `test/unit/fc_session_stats_test.dart`.
class FcSessionStats {
  /// Media de la sesión en bpm.
  final double avgBpm;

  /// Mínimo y pico de la sesión en bpm.
  final int minBpm;
  final int maxBpm;

  /// Número de lecturas reales usadas. 0 = derivado de las medias por serie
  /// (sin lecturas punto a punto), así que `minBpm`/`maxBpm` son el mínimo y
  /// el máximo de esas medias, no picos instantáneos reales.
  final int sampleCount;

  const FcSessionStats({
    required this.avgBpm,
    required this.minBpm,
    required this.maxBpm,
    required this.sampleCount,
  });

  bool get isFromRawReadings => sampleCount > 0;

  /// `null` si la sesión no tiene ni una lectura ni una media por serie.
  static FcSessionStats? from(List<Serie> series) {
    final readings = <int>[
      for (final s in series) ...?s.fcReadings?.map((r) => r.bpm),
    ]..removeWhere((bpm) => bpm <= 0);

    if (readings.isNotEmpty) {
      var min = readings.first;
      var max = readings.first;
      var sum = 0;
      for (final bpm in readings) {
        if (bpm < min) min = bpm;
        if (bpm > max) max = bpm;
        sum += bpm;
      }
      return FcSessionStats(
        avgBpm:      sum / readings.length,
        minBpm:      min,
        maxBpm:      max,
        sampleCount: readings.length,
      );
    }

    // Sin lecturas punto a punto: media ponderada por duración.
    var weightedSum = 0.0;
    var totalWeight = 0.0;
    double? minAvg;
    double? maxAvg;
    for (final s in series) {
      final fc = s.fcMedia;
      if (fc == null || fc <= 0) continue;
      // Una serie con tiempo 0 no puede anular el peso: cuenta como 1 s.
      final weight = s.tiempoSec > 0 ? s.tiempoSec : 1.0;
      weightedSum += fc * weight;
      totalWeight += weight;
      if (minAvg == null || fc < minAvg) minAvg = fc;
      if (maxAvg == null || fc > maxAvg) maxAvg = fc;
    }
    if (totalWeight == 0 || minAvg == null || maxAvg == null) return null;

    return FcSessionStats(
      avgBpm:      weightedSum / totalWeight,
      minBpm:      minAvg.round(),
      maxBpm:      maxAvg.round(),
      sampleCount: 0,
    );
  }
}
