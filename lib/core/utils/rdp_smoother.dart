import 'dart:math' as math;

import 'package:running_laps/core/services/gps_service.dart';

/// Ramer-Douglas-Peucker algorithm for GPS trace simplification.
/// Reduces number of points while preserving shape (curves kept, straight lines simplified).
class RDPSmoother {
  /// Simplify a list of GPS points.
  ///
  /// [epsilon] = max distance in meters a point can deviate from the simplified
  /// line before being kept. Recommended: 2.0–3.0 meters for running traces.
  ///
  /// Returns the original list unchanged if it has fewer than 3 points.
  static List<GpsPoint> simplify(List<GpsPoint> points, {double epsilon = 2.5}) {
    if (points.length < 3) return points;

    final result = _rdp(points, 0, points.length - 1, epsilon);

    // Always include first and last point
    final indices = {0, points.length - 1, ...result}..toList()..sort();
    final sorted = indices.toList()..sort();
    return sorted.map((i) => points[i]).toList();
  }

  /// Recursive RDP — returns indices of points to keep (excluding first/last).
  static Set<int> _rdp(
    List<GpsPoint> points,
    int start,
    int end,
    double epsilon,
  ) {
    if (end <= start + 1) return {};

    double maxDist = 0.0;
    int maxIndex = start;

    for (int i = start + 1; i < end; i++) {
      final d = _perpendicularDistance(points[i], points[start], points[end]);
      if (d > maxDist) {
        maxDist = d;
        maxIndex = i;
      }
    }

    if (maxDist > epsilon) {
      final left  = _rdp(points, start, maxIndex, epsilon);
      final right = _rdp(points, maxIndex, end, epsilon);
      return {maxIndex, ...left, ...right};
    }

    return {};
  }

  /// Perpendicular distance from [point] to the line defined by [lineStart]→[lineEnd],
  /// in meters using Haversine for all distance calculations.
  ///
  /// Uses the cross-track distance formula:
  ///   d_xt = asin(sin(d_13/R) * sin(θ_13 - θ_12)) * R
  /// where d_13 is distance from start to point and θ are bearings.
  static double _perpendicularDistance(
    GpsPoint point,
    GpsPoint lineStart,
    GpsPoint lineEnd,
  ) {
    // Degenerate segment: start == end
    if (lineStart.latitude == lineEnd.latitude &&
        lineStart.longitude == lineEnd.longitude) {
      return _haversine(
        point.latitude, point.longitude,
        lineStart.latitude, lineStart.longitude,
      );
    }

    const r = 6371000.0; // Earth radius in metres

    final lat1 = lineStart.latitude  * math.pi / 180.0;
    final lon1 = lineStart.longitude * math.pi / 180.0;
    final lat2 = lineEnd.latitude    * math.pi / 180.0;
    final lon2 = lineEnd.longitude   * math.pi / 180.0;
    final lat3 = point.latitude      * math.pi / 180.0;
    final lon3 = point.longitude     * math.pi / 180.0;

    // Angular distance from start to point (d13)
    final d13 = _haversine(
      lineStart.latitude, lineStart.longitude,
      point.latitude, point.longitude,
    ) / r;

    // Bearing from start to end (θ12)
    final theta12 = math.atan2(
      math.sin(lon2 - lon1) * math.cos(lat2),
      math.cos(lat1) * math.sin(lat2) -
          math.sin(lat1) * math.cos(lat2) * math.cos(lon2 - lon1),
    );

    // Bearing from start to point (θ13)
    final theta13 = math.atan2(
      math.sin(lon3 - lon1) * math.cos(lat3),
      math.cos(lat1) * math.sin(lat3) -
          math.sin(lat1) * math.cos(lat3) * math.cos(lon3 - lon1),
    );

    // Cross-track distance (signed, we take absolute value)
    final sinXt = math.sin(d13) * math.sin(theta13 - theta12);
    return (math.asin(sinXt.clamp(-1.0, 1.0)) * r).abs();
  }

  /// Haversine distance between two lat/lon points in metres.
  static double _haversine(
    double lat1, double lon1,
    double lat2, double lon2,
  ) {
    const r = 6371000.0;
    final dLat = (lat2 - lat1) * math.pi / 180.0;
    final dLon = (lon2 - lon1) * math.pi / 180.0;
    final sinLat = math.sin(dLat / 2);
    final sinLon = math.sin(dLon / 2);
    final a = sinLat * sinLat +
        math.cos(lat1 * math.pi / 180.0) *
        math.cos(lat2 * math.pi / 180.0) *
        sinLon * sinLon;
    return r * 2 * math.asin(math.sqrt(a.clamp(0.0, 1.0)));
  }
}
