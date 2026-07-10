import 'dart:math' as math;
import 'package:running_laps/features/history/views/widgets/temporal_chart.dart';
import 'entrenamiento.dart';
import 'serie.dart';

class TemporalDataExtractor {
  /// Extrae puntos de pace por SERIE.
  /// Eje X = segundos desde inicio de serie.
  /// Eje Y = pace en segundos/km.
  ///
  /// Usa gpsPoints: calcula distancia entre puntos consecutivos
  /// (Haversine) y pace por intervalo.
  static List<TemporalPoint> paceFromSerie(Serie serie) {
    final pts = serie.gpsPoints;
    if (pts == null || pts.length < 2) return [];

    final result = <TemporalPoint>[];
    final startTs = pts.first['timestamp'];
    if (startTs == null) return [];
    final startTime = DateTime.parse(startTs as String);

    for (var i = 1; i < pts.length; i++) {
      final prev = pts[i - 1];
      final curr = pts[i];

      final lat1 = (prev['latitude'] as num).toDouble();
      final lon1 = (prev['longitude'] as num).toDouble();
      final lat2 = (curr['latitude'] as num).toDouble();
      final lon2 = (curr['longitude'] as num).toDouble();

      final distM = _haversineM(lat1, lon1, lat2, lon2);
      if (distM < 1.0) continue; // ignorar movimientos minúsculos

      final tsPrev = DateTime.parse(prev['timestamp'] as String);
      final tsCurr = DateTime.parse(curr['timestamp'] as String);
      final deltaSec = tsCurr.difference(tsPrev).inMilliseconds / 1000;
      if (deltaSec <= 0) continue;

      final paceSecPerKm = (deltaSec / distM) * 1000;

      // Filtrar paces irreales (< 2 min/km o > 15 min/km)
      if (paceSecPerKm < 120 || paceSecPerKm > 900) continue;

      final tFromStart = tsCurr.difference(startTime).inMilliseconds / 1000;
      result.add(TemporalPoint(tSec: tFromStart, value: paceSecPerKm));
    }

    return result;
  }

  /// Extrae puntos de FC por serie usando los timestamps reales.
  /// Eje X = segundos desde inicio de serie.
  /// Eje Y = bpm.
  static List<TemporalPoint> fcFromSerie(Serie serie) {
    final readings = serie.fcReadings;
    if (readings == null || readings.isEmpty) return [];

    final startTime = readings.first.timestamp;
    return readings.map((r) => TemporalPoint(
          tSec: r.timestamp.difference(startTime).inMilliseconds / 1000,
          value: r.bpm.toDouble(),
        )).toList();
  }

  /// Pace a nivel de SESIÓN COMPLETA.
  /// Concatena las series con su tiempo acumulado.
  /// Devuelve también los marcadores (inicio de cada serie).
  static SessionTemporalData sessionPace(Entrenamiento e) {
    final allPoints = <TemporalPoint>[];
    final markers = <TemporalMarker>[];
    double tOffset = 0.0;

    for (var i = 0; i < e.series.length; i++) {
      final serie = e.series[i];
      final seriePoints = paceFromSerie(serie);

      if (seriePoints.isNotEmpty) {
        markers.add(TemporalMarker(
          tSec: tOffset,
          label: 'S${i + 1}',
        ));
        for (final p in seriePoints) {
          allPoints.add(TemporalPoint(
            tSec: tOffset + p.tSec,
            value: p.value,
          ));
        }
      }

      tOffset += serie.tiempoSec;
    }

    return SessionTemporalData(points: allPoints, markers: markers);
  }

  /// FC a nivel de SESIÓN COMPLETA.
  static SessionTemporalData sessionFc(Entrenamiento e) {
    final allPoints = <TemporalPoint>[];
    final markers = <TemporalMarker>[];
    double tOffset = 0.0;

    for (var i = 0; i < e.series.length; i++) {
      final serie = e.series[i];
      final seriePoints = fcFromSerie(serie);

      if (seriePoints.isNotEmpty) {
        markers.add(TemporalMarker(
          tSec: tOffset,
          label: 'S${i + 1}',
        ));
        for (final p in seriePoints) {
          allPoints.add(TemporalPoint(
            tSec: tOffset + p.tSec,
            value: p.value,
          ));
        }
      }

      tOffset += serie.tiempoSec;
    }

    return SessionTemporalData(points: allPoints, markers: markers);
  }

  /// Pace agrupado por km (split). Devuelve un punto por km.
  static List<TemporalPoint> sessionPacePerKm(Entrenamiento e) {
    final result = <TemporalPoint>[];
    double accumulatedDistM = 0;
    double accumulatedTimeSec = 0;
    int currentKm = 1;
    double kmStartTime = 0;

    for (final serie in e.series) {
      final pts = serie.gpsPoints;
      if (pts == null || pts.length < 2) {
        accumulatedDistM += serie.distanciaM.toDouble();
        accumulatedTimeSec += serie.tiempoSec;
        continue;
      }

      final startTs = DateTime.parse(pts.first['timestamp'] as String);

      for (var i = 1; i < pts.length; i++) {
        final prev = pts[i - 1];
        final curr = pts[i];
        final distM = _haversineM(
          (prev['latitude'] as num).toDouble(),
          (prev['longitude'] as num).toDouble(),
          (curr['latitude'] as num).toDouble(),
          (curr['longitude'] as num).toDouble(),
        );
        final tsCurr = DateTime.parse(curr['timestamp'] as String);
        final relTime = tsCurr.difference(startTs).inMilliseconds / 1000;

        accumulatedDistM += distM;
        // accumulatedTimeSec solo incluye las series anteriores en este punto
        // (se incrementa al final del bucle), así que basta sumar relTime.
        final currentTotalTime = accumulatedTimeSec + relTime;

        // Cruzamos un km
        while (accumulatedDistM >= currentKm * 1000) {
          final paceForKm = currentTotalTime - kmStartTime;
          result.add(TemporalPoint(
            tSec: currentKm.toDouble(), // X = nº de km
            value: paceForKm,           // Y = pace en seg de ese km
          ));
          kmStartTime = currentTotalTime;
          currentKm++;
        }
      }

      accumulatedTimeSec += serie.tiempoSec;
    }

    return result;
  }

  static double _haversineM(double lat1, double lon1, double lat2, double lon2) {
    const r = 6371000.0;
    final dLat = _toRad(lat2 - lat1);
    final dLon = _toRad(lon2 - lon1);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRad(lat1)) *
            math.cos(_toRad(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return r * c;
  }

  static double _toRad(double deg) => deg * math.pi / 180;
}

class SessionTemporalData {
  final List<TemporalPoint> points;
  final List<TemporalMarker> markers;

  const SessionTemporalData({
    required this.points,
    required this.markers,
  });

  bool get isEmpty => points.isEmpty;
}
