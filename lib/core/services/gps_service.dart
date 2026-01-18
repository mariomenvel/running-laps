import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import 'package:running_laps/core/services/sensor_service.dart';
import 'package:running_laps/core/tracking/tracking_state.dart';
import 'package:running_laps/core/tracking/sensor_frame.dart';
import 'package:running_laps/core/utils/kalman_filter.dart';

enum GpsStatus {
  unknown,
  disabled,
  permissionDenied,
  running,
  paused,
}

class GpsPoint {
  final double latitude;
  final double longitude;

  GpsPoint(this.latitude, this.longitude);

  Map<String, dynamic> toMap() {
    return {'latitude': latitude, 'longitude': longitude};
  }
}

class GPSService {
  /* ================= LEGACY API ================= */

  final ValueNotifier<GpsStatus> status =
      ValueNotifier(GpsStatus.unknown);

  final ValueNotifier<int> totalDistanceMeters =
      ValueNotifier(0);

  final ValueNotifier<String> currentPace =
      ValueNotifier("--:-- /km");

  final ValueNotifier<int> cadence =
      ValueNotifier(0);

  final List<GpsPoint> points = [];

  /* ================= INTERNAL ================= */

  final SensorService _sensorService = SensorService();
  final KalmanFilter _kalmanLat = KalmanFilter();
  final KalmanFilter _kalmanLon = KalmanFilter();

  final ValueNotifier<TrackingState> _trackingState =
      ValueNotifier(createInitialTrackingState());

  Timer? _timer;

  int _gpsStableSeconds = 0;

  /* ================= LIFECYCLE ================= */

  GPSService();

  Future<bool> initialize() async {
    final ok = await _sensorService.initialize();
    if (!ok) {
      status.value = GpsStatus.permissionDenied;
      return false;
    }

    final perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied ||
        perm == LocationPermission.deniedForever) {
      status.value = GpsStatus.permissionDenied;
      return false;
    }

    status.value = GpsStatus.paused;
    return true;
  }

  Future<void> startTracking() async {
    status.value = GpsStatus.running;

    _trackingState.value = createInitialTrackingState();
    _sensorService.resetSession();
    points.clear();
    _gpsStableSeconds = 0;

    _timer?.cancel();
    _timer = Timer.periodic(
      const Duration(seconds: 1),
      _onTick,
    );
  }

  void pause() {
    if (status.value == GpsStatus.running) {
      status.value = GpsStatus.paused;
    }
  }

  void resume() {
    if (status.value == GpsStatus.paused) {
      status.value = GpsStatus.running;
    }
  }

  void dispose() {
    _timer?.cancel();
    status.dispose();
    totalDistanceMeters.dispose();
    currentPace.dispose();
    cadence.dispose();
  }

  /* ================= TICK ================= */

  void _onTick(Timer timer) async {
    if (status.value != GpsStatus.running) return;

    final now = DateTime.now();
    Position? gps;

    try {
      gps = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.bestForNavigation,
      );
    } catch (_) {}

    final frame = SensorFrame(
      latitude: gps?.latitude,
      longitude: gps?.longitude,
      gpsAccuracy: gps?.accuracy,
      gpsSpeed: gps?.speed,
      stepsDelta: _sensorService.consumeStepsDelta(),
      acceleration: 0.0,
      timestamp: now,
    );

    final newState =
        _processTick(_trackingState.value, frame);

    _trackingState.value = newState;

    totalDistanceMeters.value =
        newState.distanceTotal.round();

    cadence.value = _sensorService.cadence.value;

    if (newState.velocity > 0) {
      currentPace.value =
          _formatPace(1000 / newState.velocity);
    } else {
      currentPace.value = "--:-- /km";
    }

    if (newState.latitude != null &&
        newState.longitude != null) {
      points.add(
        GpsPoint(newState.latitude!, newState.longitude!),
      );
    }
  }

  /* ================= CORE LOGIC ================= */

  TrackingState _processTick(
    TrackingState state,
    SensorFrame frame,
  ) {
    final dt =
        frame.timestamp.difference(state.lastTimestamp).inMilliseconds /
            1000.0;
    if (dt <= 0) return state;

    final deltaTime = dt > 2.0 ? 1.0 : dt;

    final bool gpsStable =
        frame.gpsAccuracy != null &&
        frame.gpsAccuracy! <= 12 &&
        frame.gpsSpeed != null &&
        frame.gpsSpeed! >= 0.8 &&
        frame.gpsSpeed! <= 6.0;

    if (gpsStable) {
      _gpsStableSeconds++;
    } else {
      _gpsStableSeconds = 0;
    }

    // 🛑 Anti-drift
    // 🛑 Anti-drift (parado real)
if (frame.stepsDelta == 0 && !gpsStable) {
  return TrackingState(
    latitude: state.latitude,
    longitude: state.longitude,
    velocity: 0.0,
    heading: state.heading,
    distanceTotal: state.distanceTotal,
    strideLength: state.strideLength,
    lastTimestamp: frame.timestamp,
  );
}


    // Velocidad
    double velocity;
    if (gpsStable) {
      velocity = frame.gpsSpeed!;
    } else if (frame.stepsDelta > 0) {
      velocity =
          (frame.stepsDelta * state.strideLength) / deltaTime;
    } else {
      velocity = 0.0;
    }

    if (velocity > 6.0) velocity = 6.0;
    if (velocity < 0) velocity = 0;

    // Distancia
    double distance = velocity * deltaTime;
    if (distance < 0.3) distance = 0;
    if (distance > 6.0) distance = 6.0;

    // Posición filtrada
    double? lat = state.latitude;
    double? lon = state.longitude;

    if (gpsStable &&
        frame.latitude != null &&
        frame.longitude != null) {
      lat = _kalmanLat.filter(frame.latitude!);
      lon = _kalmanLon.filter(frame.longitude!);
    }

    // Recalibración de zancada
    double stride = state.strideLength;
    if (_gpsStableSeconds >= 8 &&
        frame.stepsDelta > 0 &&
        gpsStable) {
      final gpsStride =
          (velocity * deltaTime) / frame.stepsDelta;
      final maxChange = stride * 0.05;
      final diff = gpsStride - stride;
      final clamped =
          diff.clamp(-maxChange, maxChange);
      stride = stride + clamped * 0.1;
    }

    return TrackingState(
      latitude: lat,
      longitude: lon,
      velocity: velocity,
      heading: state.heading,
      distanceTotal: state.distanceTotal + distance,
      strideLength: stride,
      lastTimestamp: frame.timestamp,
    );
  }

  /* ================= HELPERS ================= */

  String _formatPace(double secPerKm) {
    final m = (secPerKm / 60).floor();
    final s = (secPerKm % 60).round();
    return "${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')} /km";
  }
}
