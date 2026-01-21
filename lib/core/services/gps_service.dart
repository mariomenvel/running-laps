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

  // New: Average pace of the entire session
  final ValueNotifier<String> averagePace =
      ValueNotifier("--:-- /km");

  final List<GpsPoint> points = [];

  /* ================= INTERNAL ================= */

  final SensorService _sensorService = SensorService();
  final KalmanFilter _kalmanLat = KalmanFilter();
  final KalmanFilter _kalmanLon = KalmanFilter();

  final ValueNotifier<TrackingState> _trackingState =
      ValueNotifier(createInitialTrackingState());

  StreamSubscription<Position>? _positionSubscription;

  int _gpsStableSeconds = 0;
  
  // Buffer for smoothing instantaneous velocity (moving average)
  final List<double> _velocityBuffer = [];
  static const int _velocityBufferSize = 5; // ~5-10 seconds depending on update rate
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
    _velocityBuffer.clear();
    _sessionStartTime = DateTime.now();
    _pausedDurationMs = 0;
    _pauseStartTime = null;

    _positionSubscription?.cancel();
    
    // Configuración del stream
    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.bestForNavigation,
      distanceFilter: 2, // Mínimo 2 metros para disparar evento
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

    // 1. Calculate Smoothed Instantaneous Pace
    // Push to buffer
    if (newState.velocity > 0.5) { // Only add significant movement to buffer
       _velocityBuffer.add(newState.velocity);
       if (_velocityBuffer.length > _velocityBufferSize) {
         _velocityBuffer.removeAt(0);
       }
    } else {
       // If stopped, clear buffer faster or push zeros? 
       // Pushing zero helps decelerate smoothly
       _velocityBuffer.add(0.0);
       if (_velocityBuffer.length > _velocityBufferSize) {
         _velocityBuffer.removeAt(0);
       }
    }

    // Compute average velocity from buffer
    double smoothedVelocity = 0.0;
    if (_velocityBuffer.isNotEmpty) {
      smoothedVelocity = _velocityBuffer.reduce((a, b) => a + b) / _velocityBuffer.length;
    }

    if (smoothedVelocity > 0.5) { // Threshold to show pace (< 0.5m/s is stationary)
      currentPace.value = _formatPace(1000 / smoothedVelocity);
    } else {
      currentPace.value = "--:-- /km";
    }

    // 2. Calculate Average Pace (Session total)
    if (_sessionStartTime != null) {
       final sessionDurationMs = now.difference(_sessionStartTime!).inMilliseconds - _pausedDurationMs;
       if (sessionDurationMs > 5000 && newState.distanceTotal > 10) { // Valid data > 5s and > 10m
          final double totalSeconds = sessionDurationMs / 1000.0;
          final double avgVel = newState.distanceTotal / totalSeconds;
          if (avgVel > 0.1) {
             averagePace.value = _formatPace(1000 / avgVel);
          }
       }
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
