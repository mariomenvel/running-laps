import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:pedometer/pedometer.dart';
import 'package:permission_handler/permission_handler.dart';

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

  // 🔑 NEW: step delta tracking for GPS system
  int _lastSessionStepCount = 0;

  /* =========================
     INITIALIZATION
     ========================= */

  Future<bool> initialize() async {
    if (_isInitialized) return true;

    var permissionStatus = await Permission.activityRecognition.status;
    if (permissionStatus.isDenied) {
      permissionStatus = await Permission.activityRecognition.request();
    }

    if (permissionStatus.isPermanentlyDenied) {

      return false;
    }

    if (permissionStatus.isGranted) {
      _initStreams();
      _isInitialized = true;
      return true;
    }

    return false;
  }

  void _initStreams() {
    _stepCountStream = Pedometer.stepCountStream;
    _pedestrianStatusStream = Pedometer.pedestrianStatusStream;

    _stepCountSubscription = _stepCountStream?.listen(
      _onStepCount,
      onError: (error) {

      },
    );

    _statusSubscription = _pedestrianStatusStream?.listen(
      _onPedestrianStatusChanged,
      onError: (error) {

        status.value = SensorStatus.unknown;
      },
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

  SensorFrame buildSensorFrame({
    required DateTime timestamp,
  }) {
    return SensorFrame(
      latitude: null,
      longitude: null,
      gpsAccuracy: null,
      gpsSpeed: null,
      stepsDelta: consumeStepsDelta(),
      acceleration: 0.0, // placeholder (future-proof)
      timestamp: timestamp,
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
    totalSteps.dispose();
    sessionSteps.dispose();
    cadence.dispose();
    status.dispose();
  }
}
