import '../../../core/services/zones_service.dart';
import 'serie.dart';

/// Analítica de frecuencia cardíaca de un entrenamiento: lo que un entrenador
/// mira de verdad cuando abre los datos del pulsómetro, más allá de la media.
///
/// Lógica pura (sin Flutter ni Firebase) para que la pueda usar tanto la UI
/// como el constructor de contexto del Coach IA.
/// Cubierta por `test/unit/fc_analytics_test.dart`.
class FcAnalytics {
  const FcAnalytics._();

  // ── Distribución por zonas ────────────────────────────────────────────────

  /// Minutos pasados en cada zona (índice 0 = Z1 … 4 = Z5).
  ///
  /// El tiempo se reparte por serie: cada lectura representa
  /// `serie.tiempoSec / nLecturas` segundos. Contar lecturas a secas sesgaría
  /// el resultado si una serie se muestrea más densa que otra.
  ///
  /// Devuelve `null` si no hay lecturas o [fcMax] no es válida.
  static List<double>? zoneMinutes(List<Serie> series, int? fcMax) {
    if (fcMax == null || fcMax <= 0) return null;

    final minutes = List<double>.filled(5, 0.0);
    var any = false;

    for (final serie in series) {
      final readings = serie.fcReadings;
      if (readings == null || readings.isEmpty) continue;

      final valid = readings.where((r) => r.bpm > 0).toList();
      if (valid.isEmpty) continue;

      final secondsPerReading = serie.tiempoSec / valid.length;
      for (final r in valid) {
        final zone = ZonesService().zoneFor(r.bpm, fcMax) ?? 1;
        minutes[zone - 1] += secondsPerReading / 60.0;
        any = true;
      }
    }

    return any ? minutes : null;
  }

  /// Reparto por zonas en porcentaje (suma 100). `null` si no hay datos.
  static List<double>? zonePercentages(List<Serie> series, int? fcMax) {
    final minutes = zoneMinutes(series, fcMax);
    if (minutes == null) return null;

    final total = minutes.fold<double>(0, (a, b) => a + b);
    if (total <= 0) return null;
    return minutes.map((m) => m / total * 100).toList();
  }

  // ── Eficiencia aeróbica ───────────────────────────────────────────────────

  /// Índice de eficiencia: metros por minuto y por pulsación (m/min/bpm).
  ///
  /// Es la forma estándar de comparar sesiones aeróbicas entre sí: a igual
  /// ritmo, menos pulsaciones = más eficiente. Sube con la forma física.
  ///
  /// Solo tiene sentido en esfuerzo continuo: en series el tiempo total
  /// incluye descansos y la cifra sale deprimida. Quien llame decide.
  /// `null` si falta distancia, tiempo o FC.
  static double? efficiencyIndex(List<Serie> series) {
    var meters = 0.0;
    var seconds = 0.0;
    for (final s in series) {
      meters += s.distanciaM;
      seconds += s.tiempoSec;
    }
    if (meters <= 0 || seconds <= 0) return null;

    final avgBpm = _avgBpm(_allReadings(series));
    if (avgBpm == null || avgBpm <= 0) return null;

    final metersPerMinute = meters / (seconds / 60.0);
    return metersPerMinute / avgBpm;
  }

  /// Deriva cardíaca: cuántas pulsaciones sube la FC media de la segunda mitad
  /// del entreno respecto a la primera.
  ///
  /// Positivo = la FC se fue arriba con el esfuerzo. Es una señal de fatiga,
  /// calor o deshidratación — pero **no** es desacople por sí sola: sin ritmo
  /// por mitades no se sabe si subió el pulso o si el atleta aceleró. Para eso
  /// está [decouplingPercent].
  ///
  /// `null` con menos de 4 lecturas (dos por mitad).
  static double? hrDriftBpm(List<Serie> series) {
    final readings = _allReadings(series);
    if (readings.length < 4) return null;

    final half = readings.length ~/ 2;
    final first = _avgBpm(readings.sublist(0, half));
    final second = _avgBpm(readings.sublist(half));
    if (first == null || second == null) return null;
    return second - first;
  }

  /// Desacople cardíaco en %: cuánto se degrada la eficiencia entre la primera
  /// y la segunda mitad del entreno.
  ///
  /// Es la deriva cardíaca corregida por ritmo — la métrica real. Por encima
  /// de ~5 % se lee como base aeróbica insuficiente para el ritmo del día.
  /// Positivo = peor eficiencia al final.
  ///
  /// Requiere al menos 2 series con distancia y FC, porque las mitades se
  /// parten por serie: dentro de una única serie continua no hay forma de
  /// saber el ritmo por mitades sin la traza GPS (que ya no viaja en el
  /// documento del entrenamiento). `null` si no se puede calcular.
  static double? decouplingPercent(List<Serie> series) {
    final usable = series
        .where((s) =>
            s.distanciaM > 0 &&
            s.tiempoSec > 0 &&
            (s.fcReadings?.any((r) => r.bpm > 0) ?? false))
        .toList();
    if (usable.length < 2) return null;

    // Partir por tiempo acumulado, no por número de series: 3 series de 1 km y
    // un rodaje de 10 km no se parten por la mitad de la lista.
    final totalSec = usable.fold<double>(0, (a, s) => a + s.tiempoSec);
    final firstHalf = <Serie>[];
    final secondHalf = <Serie>[];
    var acc = 0.0;
    for (final s in usable) {
      if (acc + s.tiempoSec / 2 <= totalSec / 2) {
        firstHalf.add(s);
      } else {
        secondHalf.add(s);
      }
      acc += s.tiempoSec;
    }
    if (firstHalf.isEmpty || secondHalf.isEmpty) return null;

    final ei1 = efficiencyIndex(firstHalf);
    final ei2 = efficiencyIndex(secondHalf);
    if (ei1 == null || ei2 == null || ei1 <= 0) return null;

    return (ei1 - ei2) / ei1 * 100;
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  static List<int> _allReadings(List<Serie> series) => [
        for (final s in series) ...?s.fcReadings?.map((r) => r.bpm),
      ]..removeWhere((bpm) => bpm <= 0);

  static double? _avgBpm(List<int> readings) {
    if (readings.isEmpty) return null;
    return readings.reduce((a, b) => a + b) / readings.length;
  }
}
