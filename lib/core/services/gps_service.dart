import 'dart:async';
import 'dart:math' as math;
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
  final double altitude; // New: Altitude support
  final DateTime timestamp; // New: Timestamp for analysis

  GpsPoint({
    required this.latitude,
    required this.longitude,
    this.altitude = 0.0,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      'latitude': latitude,
      'longitude': longitude,
      'altitude': altitude,
      'timestamp': timestamp.toIso8601String(),
    };
  }
  
  factory GpsPoint.fromMap(Map<String, dynamic> map) {
    return GpsPoint(
      latitude: map['latitude'] as double,
      longitude: map['longitude'] as double,
      altitude: (map['altitude'] as num?)?.toDouble() ?? 0.0,
      timestamp: DateTime.tryParse(map['timestamp'] ?? '') ?? DateTime.now(),
    );
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

  // New: Average pace of the entire session
  final ValueNotifier<String> averagePace =
      ValueNotifier("--:-- /km");

  final List<GpsPoint> points = [];

  /* ================= INTERNAL ================= */

  final SensorService _sensorService = SensorService();
  // Kalman filters for lat/lon. 
  // Process noise (Q): 1e-8 (~1.1m error per step)
  // Measurement noise (R) base: 1e-7 (~3.5m error base)
  final KalmanFilter _kalmanLat = KalmanFilter(processNoise: 1e-8, measurementNoise: 1e-7);
  final KalmanFilter _kalmanLon = KalmanFilter(processNoise: 1e-8, measurementNoise: 1e-7);

  final ValueNotifier<TrackingState> _trackingState =
      ValueNotifier(createInitialTrackingState());

  StreamSubscription<Position>? _positionSubscription;

  int _gpsStableSeconds = 0;
  
  DateTime? _sessionStartTime;
  int _pausedDurationMs = 0;
  DateTime? _pauseStartTime;

  /* ================= LIFECYCLE ================= */

  GPSService();

  Future<bool> initialize() async {
    final ok = await _sensorService.initialize();
    if (!ok) {
      status.value = GpsStatus.permissionDenied;
      return false;
    }

    LocationPermission perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    
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
    points.clear();
    _gpsStableSeconds = 0;
    _sessionStartTime = DateTime.now();
    _pausedDurationMs = 0;
    _pauseStartTime = null;

    _positionSubscription?.cancel();
    
    // Configuración del stream: Alta frecuencia
    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.bestForNavigation,
      distanceFilter: 0, // Capturar TODO el movimiento
    );

    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen((Position position) {
      _handlePosition(position);
    });
  }

  void pause() {
    if (status.value == GpsStatus.running) {
      status.value = GpsStatus.paused;
      _positionSubscription?.pause();
      _pauseStartTime = DateTime.now();
    }
  }

  void resume() {
    if (status.value == GpsStatus.paused) {
      status.value = GpsStatus.running;
      _positionSubscription?.resume();
      if (_pauseStartTime != null) {
        _pausedDurationMs += DateTime.now().difference(_pauseStartTime!).inMilliseconds;
        _pauseStartTime = null;
      }
    }
  }

  void dispose() {
    _positionSubscription?.cancel();
    status.dispose();
    totalDistanceMeters.dispose();
    currentPace.dispose();
    averagePace.dispose();
    cadence.dispose();
  }

  /* ================= HANDLERS ================= */
  
  void _handlePosition(Position position) {
    if (status.value != GpsStatus.running) return;

    final now = DateTime.now();

    final frame = SensorFrame(
      latitude: position.latitude,
      longitude: position.longitude,
      altitude: position.altitude, // Capture altitude
      gpsAccuracy: position.accuracy,
      gpsSpeed: position.speed,
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

    // Simplified: No longer calculating instantaneous pace.
    // currentPace will be updated together with averagePace below.

    // 2. Calculate Average Pace (Session total)
    if (_sessionStartTime != null) {
       final sessionDurationMs = now.difference(_sessionStartTime!).inMilliseconds - _pausedDurationMs;
       if (sessionDurationMs > 3000 && newState.distanceTotal > 5) { // Valid data > 3s and > 5m
          final double totalSeconds = sessionDurationMs / 1000.0;
          final double avgVel = newState.distanceTotal / totalSeconds;
          if (avgVel > 0.1) {
             final paceStr = _formatPace(1000 / avgVel);
             averagePace.value = paceStr;
             currentPace.value = paceStr; // Both now use the session average
          }
       }
    }

    if (newState.latitude != null &&
        newState.longitude != null) {
      points.add(
        GpsPoint(
          latitude: newState.latitude!, 
          longitude: newState.longitude!,
          altitude: frame.altitude ?? 0.0, // Store altitude
          timestamp: now,
        ),
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
        frame.gpsAccuracy! <= 30 && // Relax accuracy slightly more
        frame.gpsSpeed != null &&
        frame.gpsSpeed! >= 0.1 && // Capture almost any movement
        frame.gpsSpeed! <= 10.0; // Physically possible human speed limit

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

    if (velocity > 10.0) velocity = 10.0;
    if (velocity < 0) velocity = 0;

    // Posición filtrada (Declarar ANTES de usar en Haversine)
    double? lat = state.latitude;
    double? lon = state.longitude;

    if (gpsStable &&
        frame.latitude != null &&
        frame.longitude != null) {
      // Convert meter accuracy to degree accuracy approximation (1m ≈ 0.000009 deg)
      final double accDeg = (frame.gpsAccuracy ?? 5.0) * 0.000009;
      lat = _kalmanLat.filter(frame.latitude!, accuracy: accDeg);
      lon = _kalmanLon.filter(frame.longitude!, accuracy: accDeg);
    }

    // Distancia: Haversine entre puntos filtrados (Usar lat/lon ya declarados)
    double distance = 0.0;
    if (lat != null && lon != null && state.latitude != null && state.longitude != null) {
      distance = _calculateHaversine(
        state.latitude!,
        state.longitude!,
        lat,
        lon,
      );
      
      // Filtro de "salto imposible": > 10m en un tick (usualmente 1s)
      if (distance > 10.0) distance = 0.0;
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

  double _calculateHaversine(double lat1, double lon1, double lat2, double lon2) {
    const double r = 6371000; // Radio de la Tierra en metros
    final double dLat = (lat2 - lat1) * (math.pi / 180.0);
    final double dLon = (lon2 - lon1) * (math.pi / 180.0);
    
    final double sinLat = math.sin(dLat / 2);
    final double sinLon = math.sin(dLon / 2);
    
    final double a = sinLat * sinLat + 
                    math.cos(lat1 * (math.pi / 180.0)) * 
                    math.cos(lat2 * (math.pi / 180.0)) * 
                    sinLon * sinLon;
    
    final double c = 2 * math.asin(math.sqrt(a));
    return r * c;
  }

  String _formatPace(double secPerKm) {
    final m = (secPerKm / 60).floor();
    final s = (secPerKm % 60).round();
    return "${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')} /km";
  }
}
