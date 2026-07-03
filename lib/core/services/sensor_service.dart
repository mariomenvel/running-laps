import 'dart:async';
import 'dart:math' show sqrt;
import 'package:flutter/foundation.dart';
import 'package:pedometer/pedometer.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:sensors_plus/sensors_plus.dart';

import 'package:running_laps/core/tracking/sensor_frame.dart';

enum SensorStatus {
  unknown,
  stopped,
  walking,
  running,
}

class SensorService {
  // Streams provided by the pedometer package
  Stream<StepCount>? _stepCountStream;
  Stream<PedestrianStatus>? _pedestrianStatusStream;

  // Internal subscriptions
  StreamSubscription<StepCount>? _stepCountSubscription;
  StreamSubscription<PedestrianStatus>? _statusSubscription;
  StreamSubscription<AccelerometerEvent>? _accSub;
  StreamSubscription<GyroscopeEvent>? _gyroSub;

  // Reactive state (USED BY UI)
  final ValueNotifier<int> totalSteps = ValueNotifier(0);
  final ValueNotifier<int> sessionSteps = ValueNotifier(0);
  final ValueNotifier<int> cadence = ValueNotifier(0); // Steps per minute
  final ValueNotifier<SensorStatus> status =
      ValueNotifier(SensorStatus.unknown);

  // Cadence calculation
  final List<DateTime> _recentSteps = [];

  bool _isInitialized = false;
  int _initialStepsOffset = 0;

  // Step delta tracking for GPS system
  int _lastSessionStepCount = 0;

  // Accelerometer state (m/s²) — initial Z = gravity
  double _accX = 0.0;
  double _accY = 0.0;
  double _accZ = 9.81;

  // Gyroscope state (rad/s)
  double _gyroZ = 0.0;

  /* =========================
     INITIALIZATION
     ========================= */

  Future<bool> initialize() async {
    if (_isInitialized) return true;

    if (!kIsWeb) {
      var permissionStatus = await Permission.activityRecognition.status;
      if (permissionStatus.isDenied) {
        permissionStatus = await Permission.activityRecognition.request();
      }

      if (permissionStatus.isGranted) {
        _initStreams();
      }
    }

    _initImuStreams();

    _isInitialized = true;
    return true;
  }

  void _initStreams() {
    _stepCountStream = Pedometer.stepCountStream;
    _pedestrianStatusStream = Pedometer.pedestrianStatusStream;

    _stepCountSubscription = _stepCountStream?.listen(
      _onStepCount,
      onError: (error) {},
    );

    _statusSubscription = _pedestrianStatusStream?.listen(
      _onPedestrianStatusChanged,
      onError: (error) {
        status.value = SensorStatus.unknown;
      },
    );
  }

  void _initImuStreams() {
    _accSub = accelerometerEventStream(
      samplingPeriod: SensorInterval.gameInterval,
    ).listen(
      (event) {
        _accX = event.x;
        _accY = event.y;
        _accZ = event.z;
      },
      onError: (e) => debugPrint('[SensorService] acc error: $e'),
    );

    _gyroSub = gyroscopeEventStream(
      samplingPeriod: SensorInterval.gameInterval,
    ).listen(
      (event) {
        _gyroZ = event.z;
      },
      onError: (e) => debugPrint('[SensorService] gyro error: $e'),
    );
  }

  /* =========================
     STEP HANDLING
     ========================= */

  void _onStepCount(StepCount event) {
    if (_initialStepsOffset == 0) {
      _initialStepsOffset = event.steps;
    }

    sessionSteps.value = event.steps - _initialStepsOffset;
    totalSteps.value = event.steps;

    _updateCadence(event.timeStamp);
  }

  void _updateCadence(DateTime now) {
    _recentSteps.add(now);

    final threshold = now.subtract(const Duration(seconds: 15));
    _recentSteps.removeWhere((stepTime) => stepTime.isBefore(threshold));

    if (_recentSteps.length < 3) {
      cadence.value = 0;
      return;
    }

    final durationSeconds =
        now.difference(_recentSteps.first).inSeconds;

    if (durationSeconds > 0) {
      cadence.value =
          ((_recentSteps.length / durationSeconds) * 60).round();
    }
  }

  void _onPedestrianStatusChanged(PedestrianStatus event) {
    switch (event.status) {
      case 'stopped':
        status.value = SensorStatus.stopped;
        cadence.value = 0;
        break;
      case 'walking':
        status.value = SensorStatus.walking;
        break;
      default:
        status.value = SensorStatus.unknown;
        break;
    }
  }

  /* =========================
     GPS SYSTEM INTEGRATION
     ========================= */

  int consumeStepsDelta() {
    final int delta = sessionSteps.value - _lastSessionStepCount;
    _lastSessionStepCount = sessionSteps.value;
    return delta < 0 ? 0 : delta;
  }

  // Aceleración lateral (componente horizontal sin gravedad)
  // Útil para detectar cambios de dirección y velocidad
  double get lateralAcceleration {
    final horizontal = sqrt(_accX * _accX + _accY * _accY);
    return horizontal;
  }

  SensorFrame buildSensorFrame({
    required DateTime timestamp,
  }) {
    final mag = sqrt(_accX * _accX + _accY * _accY + _accZ * _accZ);
    return SensorFrame(
      latitude:              null,
      longitude:             null,
      gpsAccuracy:           null,
      gpsSpeed:              null,
      stepsDelta:            consumeStepsDelta(),
      accelerationX:         _accX,
      accelerationY:         _accY,
      accelerationZ:         _accZ,
      accelerationMagnitude: mag,
      gyroscopeZ:            _gyroZ,
      timestamp:             timestamp,
    );
  }

  /* =========================
     SESSION MANAGEMENT
     ========================= */

  void resetSession() {
    _initialStepsOffset = totalSteps.value;
    sessionSteps.value = 0;
    _lastSessionStepCount = 0;
    cadence.value = 0;
    _recentSteps.clear();
  }

  void dispose() {
    _stepCountSubscription?.cancel();
    _statusSubscription?.cancel();
    _accSub?.cancel();
    _gyroSub?.cancel();
    totalSteps.dispose();
    sessionSteps.dispose();
    cadence.dispose();
    status.dispose();
  }
}
