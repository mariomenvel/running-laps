import 'package:flutter_test/flutter_test.dart';
import 'package:running_laps/core/services/gps_service.dart';
import 'package:running_laps/core/utils/rdp_smoother.dart';

void main() {
  GpsPoint p(double lat, double lon, int sec) => GpsPoint(
        latitude: lat,
        longitude: lon,
        timestamp: DateTime(2026, 7, 1, 10).add(Duration(seconds: sec)),
      );

  group('RDPSmoother.simplify', () {
    test('menos de 3 puntos devuelve la lista original', () {
      final points = [p(40.0, -3.7, 0), p(40.001, -3.7, 30)];
      final result = RDPSmoother.simplify(points);
      expect(result, same(points));
    });

    test('línea recta colapsa a los dos extremos', () {
      final points = List.generate(
        10,
        (i) => p(40.0 + i * 0.0009, -3.7, i * 30),
      );
      final result = RDPSmoother.simplify(points, epsilon: 2.5);

      expect(result.length, 2);
      expect(result.first.latitude, points.first.latitude);
      expect(result.last.latitude, points.last.latitude);
    });

    test('conserva un punto que se desvía más de epsilon', () {
      // Traza recta con un desvío lateral de ~44 m en el punto medio
      final points = List.generate(
        11,
        (i) => p(40.0 + i * 0.0009, -3.7, i * 30),
      );
      final deviated = GpsPoint(
        latitude: points[5].latitude,
        longitude: -3.7005, // ~43 m al oeste
        timestamp: points[5].timestamp,
      );
      points[5] = deviated;

      final result = RDPSmoother.simplify(points, epsilon: 2.5);

      expect(result.length, greaterThan(2));
      expect(
        result.any((pt) => pt.longitude == deviated.longitude),
        isTrue,
        reason: 'el punto desviado debe sobrevivir a la simplificación',
      );
    });

    test('siempre conserva primer y último punto', () {
      final points = List.generate(
        20,
        (i) => p(40.0 + i * 0.0009, -3.7 + (i % 3) * 0.0002, i * 30),
      );
      final result = RDPSmoother.simplify(points, epsilon: 2.0);

      expect(result.first.timestamp, points.first.timestamp);
      expect(result.last.timestamp, points.last.timestamp);
    });
  });
}
