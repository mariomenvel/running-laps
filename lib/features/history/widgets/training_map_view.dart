import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:running_laps/config/app_theme.dart';
import 'package:running_laps/core/services/gps_service.dart';

class TrainingMapView extends StatelessWidget {
  final List<GpsPoint> points;

  const TrainingMapView({
    super.key,
    required this.points,
  });

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) {
      return const Center(
        child: Text(
          "No hay datos de GPS disponibles",
          style: TextStyle(color: AppColors.iconMuted),
        ),
      );
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    final List<LatLng> polylinePoints = points
        .map((p) => LatLng(p.latitude, p.longitude))
        .toList();

    // Calculate bounds for auto-framing
    final bounds = LatLngBounds.fromPoints(polylinePoints);

    final tileUrl = isDark
        ? 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png'
        : 'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png';

    final borderColor = isDark
        ? Colors.black.withOpacity(0.5)
        : Colors.white.withOpacity(0.5);

    return Stack(
      children: [
        FlutterMap(
          options: MapOptions(
            initialCameraFit: CameraFit.bounds(
              bounds: bounds,
              padding: const EdgeInsets.all(40.0),
            ),
          ),
          children: [
            TileLayer(
              urlTemplate: tileUrl,
              subdomains: const ['a', 'b', 'c', 'd'],
              userAgentPackageName: 'com.runninglaps.app',
            ),
            PolylineLayer(
              polylines: [
                // Border polyline (underneath)
                Polyline(
                  points: polylinePoints,
                  strokeWidth: 6.0,
                  color: borderColor,
                ),
                // Route polyline (on top)
                Polyline(
                  points: polylinePoints,
                  strokeWidth: 4.0,
                  color: AppColors.brand,
                ),
              ],
            ),
          ],
        ),
        // CartoDB attribution
        Positioned(
          bottom: 4,
          right: 6,
          child: Text(
            '© CartoDB © OpenStreetMap contributors',
            style: TextStyle(
              fontSize: 9,
              color: isDark
                  ? Colors.white.withOpacity(0.5)
                  : Colors.black.withOpacity(0.45),
            ),
          ),
        ),
      ],
    );
  }
}
