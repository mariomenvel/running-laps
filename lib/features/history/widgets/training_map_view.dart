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
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    final List<LatLng> polylinePoints = points
        .map((p) => LatLng(p.latitude, p.longitude))
        .toList();

    // Calculate bounds for auto-framing
    final bounds = LatLngBounds.fromPoints(polylinePoints);

    return FlutterMap(
      options: MapOptions(
        initialCameraFit: CameraFit.bounds(
          bounds: bounds,
          padding: const EdgeInsets.all(40.0),
        ),
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.runninglaps.app',
        ),
        PolylineLayer(
          polylines: [
            Polyline(
              points: polylinePoints,
              strokeWidth: 4.0,
              color: Tema.brandPurple,
            ),
          ],
        ),
      ],
    );
  }
}
