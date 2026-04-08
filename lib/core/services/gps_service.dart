import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show Color;

import 'package:flutter/foundation.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:geolocator/geolocator.dart';

import 'package:running_laps/core/services/foreground_tracking_handler.dart';
import 'package:running_laps/core/services/ios_live_activity_service.dart';
import 'package:running_laps/core/services/sensor_service.dart';
import 'package:running_laps/core/services/settings_service.dart';
import 'package:running_laps/core/tracking/sensor_frame.dart';
import 'package:running_laps/core/tracking/tracking_state.dart';
import 'package:running_laps/core/tracking/tracking_types.dart';
import 'package:running_laps/core/utils/ekf2d.dart';

enum GpsStatus { unknown, disabled, permissionDenied, running, paused }

enum TrackingMode { continuous, intervals }

class GpsPoint {
  final double latitude;
  final double longitude;
  final double altitude;
  final DateTime timestamp;

  GpsPoint({
    required this.latitude,
    required this.longitude,
    this.altitude = 0.0,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() => {
    'latitude': latitude,
    'longitude': longitude,
    'altitude': altitude,
    'timestamp': timestamp.toIso8601String(),
  };

  factory GpsPoint.fromMap(Map<String, dynamic> map) => GpsPoint(
    latitude: map['latitude'] as double,
    longitude: map['longitude'] as double,
    altitude: (map['altitude'] as num?)?.toDouble() ?? 0.0,
    timestamp: DateTime.tryParse(map['timestamp'] ?? '') ?? DateTime.now(),
  );
}

class GPSService {
  final ValueNotifier<GpsStatus> status = ValueNotifier(GpsStatus.unknown);
  final ValueNotifier<int> totalDistanceMeters = ValueNotifier(0);
  final ValueNotifier<String> currentPace = ValueNotifier('--:-- /km');
  final ValueNotifier<int> cadence = ValueNotifier(0);
  final ValueNotifier<String> averagePace = ValueNotifier('--:-- /km');
  final ValueNotifier<String?> notificationAction = ValueNotifier(null);

  final List<GpsPoint> points = [];

  final SensorService _sensorService = SensorService();
  final EKF2D _ekf = EKF2D();
  final ValueNotifier<TrackingState> _trackingState = ValueNotifier(
    createInitialTrackingState(),
  );

  StreamSubscription<Position>? _positionSubscription;
  StreamSubscription<String>? _iosActionSubscription;
  Timer? _notificationTimer;

  int _gpsStableSeconds = 0;
  int _noGpsSeconds = 0;
  int _stoppedSeconds = 0;
  DateTime? _sessionStartTime;
  int _pausedDurationMs = 0;
  DateTime? _pauseStartTime;

  TrackingMode _mode = TrackingMode.continuous;
  int _serieNumber = 1;
  bool _gpsEnabled = false;
  String? _externalElapsed;
  String? _userId;

  GPSService() {
    _initForegroundTask();
    _initIOSLiveActivityActions();
  }

  Future<bool> initialize() async {
    await _sensorService.initialize();

    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      status.value = GpsStatus.disabled;
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

  Future<void> startTracking({
    TrackingMode mode = TrackingMode.continuous,
    int serieNumber = 1,
  }) async {
    _mode = mode;
    _serieNumber = serieNumber;
    _gpsEnabled = true;
    status.value = GpsStatus.running;

    _trackingState.value = createInitialTrackingState();
    _ekf.reset();
    _sensorService.resetSession();
    points.clear();
    _gpsStableSeconds = 0;
    _noGpsSeconds = 0;
    _stoppedSeconds = 0;
    _sessionStartTime = DateTime.now();
    _pausedDurationMs = 0;
    _pauseStartTime = null;

    await _startForegroundService();

    _positionSubscription?.cancel();

    final locationSettings =
        !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS
            ? const LocationSettings(
                accuracy: LocationAccuracy.bestForNavigation,
                distanceFilter: 2,
              )
            : const LocationSettings(
                accuracy: LocationAccuracy.bestForNavigation,
                distanceFilter: 0,
              );

    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen(_handlePosition);
  }

  void pause() {
    if (status.value == GpsStatus.running) {
      status.value = GpsStatus.paused;
      _positionSubscription?.pause();
      if (!_useIOSLiveActivity) _notificationTimer?.cancel();
      _pauseStartTime = DateTime.now();
    }
  }

  void resume() {
    if (status.value == GpsStatus.paused) {
      status.value = GpsStatus.running;
      _positionSubscription?.resume();
      if (_pauseStartTime != null) {
        _pausedDurationMs +=
            DateTime.now().difference(_pauseStartTime!).inMilliseconds;
        _pauseStartTime = null;
      }
      if (!_useIOSLiveActivity) {
        _notificationTimer?.cancel();
        _notificationTimer = Timer.periodic(
          const Duration(seconds: 1),
          (_) => _sendNotificationUpdate(),
        );
      }
    }
  }

  void updateSerie(int n) {
    _serieNumber = n;
    _sendNotificationUpdate();
  }

  Future<void> startNotificationOnly({
    TrackingMode mode = TrackingMode.continuous,
    int serieNumber = 1,
  }) async {
    _mode = mode;
    _serieNumber = serieNumber;
    _gpsEnabled = false;
    _ekf.reset();
    status.value = GpsStatus.paused;
    await _startForegroundService();
  }

  void setExternalElapsed(String elapsed) {
    _externalElapsed = elapsed;
  }

  /// Loads the last persisted stride length for [uid] and applies it to the
  /// current tracking state. Call before startTracking() when GPS is enabled.
  Future<void> loadStrideLength(String uid) async {
    _userId = uid;
    final saved = await SettingsService().getStrideLength(uid);
    if (saved != null && saved > 0.3 && saved < 2.0) {
      _trackingState.value = TrackingState(
        latitude: _trackingState.value.latitude,
        longitude: _trackingState.value.longitude,
        velocity: _trackingState.value.velocity,
        heading: _trackingState.value.heading,
        distanceTotal: _trackingState.value.distanceTotal,
        strideLength: saved,
        lastTimestamp: _trackingState.value.lastTimestamp,
        userState: _trackingState.value.userState,
      );
    }
  }

  Future<void> stopTracking() async {
    if (status.value != GpsStatus.running &&
        status.value != GpsStatus.paused) {
      return;
    }

    _positionSubscription?.cancel();
    _positionSubscription = null;
    _notificationTimer?.cancel();
    _notificationTimer = null;
    _ekf.reset();

    // Persist learned stride length if GPS was active long enough to calibrate
    if (_userId != null && _gpsEnabled && _gpsStableSeconds >= 30) {
      unawaited(SettingsService().saveStrideLength(
        _userId!,
        _trackingState.value.strideLength,
      ));
    }

    status.value = GpsStatus.paused;

    if (_useIOSLiveActivity) {
      await IOSLiveActivityService.instance.stop();
    } else {
      await FlutterForegroundTask.stopService();
    }
  }

  Future<void> reset() async {
    await stopTracking();
    points.clear();
    totalDistanceMeters.value = 0;
    currentPace.value = '--:-- /km';
    averagePace.value = '--:-- /km';
    cadence.value = 0;
    _trackingState.value = createInitialTrackingState();
    _ekf.reset();
    _sessionStartTime = null;
    _pausedDurationMs = 0;
    _pauseStartTime = null;
    _gpsStableSeconds = 0;
  }

  void dispose() {
    if (!_useIOSLiveActivity) {
      FlutterForegroundTask.removeTaskDataCallback(_onDataFromTask);
    }
    _positionSubscription?.cancel();
    _notificationTimer?.cancel();
    _iosActionSubscription?.cancel();

    if (_useIOSLiveActivity) {
      unawaited(IOSLiveActivityService.instance.stop());
    } else {
      FlutterForegroundTask.stopService();
    }
    _ekf.reset();

    status.dispose();
    totalDistanceMeters.dispose();
    currentPace.dispose();
    averagePace.dispose();
    cadence.dispose();
    notificationAction.dispose();
  }

  void _initForegroundTask() {
    if (_useIOSLiveActivity) return;

    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'running_laps_tracking',
        channelName: 'Seguimiento de carrera',
        channelDescription: 'GPS activo durante el entrenamiento',
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
        visibility: NotificationVisibility.VISIBILITY_PUBLIC,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: true,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.nothing(),
        autoRunOnBoot: false,
      ),
    );

    FlutterForegroundTask.initCommunicationPort();
    FlutterForegroundTask.addTaskDataCallback(_onDataFromTask);
  }

  void _initIOSLiveActivityActions() {
    if (!_useIOSLiveActivity) return;

    _iosActionSubscription = IOSLiveActivityService.instance.actions.listen((
      String action,
    ) {
      notificationAction.value = action;
      notificationAction.value = null;
    });
  }

  Future<void> _startForegroundService() async {
    final title = _notificationTitle();
    final buttonId =
        _mode == TrackingMode.continuous ? 'finish_run' : 'end_serie';
    final buttonLabel =
        _mode == TrackingMode.continuous ? 'Terminar' : 'Fin de serie';

    if (_useIOSLiveActivity) {
      await IOSLiveActivityService.instance.start(
        _currentIOSPayload(
          title: title,
          actionId: buttonId,
          actionLabel: buttonLabel,
        ),
      );
      // iOS: updates are driven by GPS position events in _handlePosition(),
      // not by a timer — location background mode keeps delivering positions
      // even when the app is backgrounded, unlike Timer which may be suspended.
      return;
    }

    await FlutterForegroundTask.startService(
      serviceId: 500,
      notificationTitle: title,
      notificationText: '0.00 km  ·  00:00  ·  --:-- /km',
      notificationIcon: const NotificationIcon(
        metaDataName: 'com.runninglaps.foreground_icon',
        backgroundColor: Color(0xFF8E24AA),
      ),
      notificationButtons: [
        NotificationButton(
          id: buttonId,
          text: buttonLabel,
          textColor: const Color(0xFF8E24AA),
        ),
      ],
      callback: trackingServiceCallback,
    );

    _notificationTimer?.cancel();
    _notificationTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => _sendNotificationUpdate(),
    );
  }

  void _sendNotificationUpdate() {
    if (_useIOSLiveActivity) {
      IOSLiveActivityService.instance.update(
        _currentIOSPayload(
          title: _notificationTitle(),
          actionId: _mode == TrackingMode.continuous
              ? 'finish_run'
              : 'end_serie',
          actionLabel: _mode == TrackingMode.continuous
              ? 'Terminar'
              : 'Fin de serie',
        ),
      );
      return;
    }

    FlutterForegroundTask.sendDataToTask({
      'distance': _formatDistance(totalDistanceMeters.value),
      'elapsed': _getElapsedText(),
      'pace': currentPace.value,
      'mode': _mode == TrackingMode.continuous ? 'continuous' : 'intervals',
      'serie': _serieNumber,
      'gps': _gpsEnabled,
    });
  }

  void _onDataFromTask(Object data) {
    if (data is! Map<dynamic, dynamic>) return;
    final m = Map<String, dynamic>.from(data);
    final event = m['event'] as String?;
    if (event != null) {
      notificationAction.value = event;
      notificationAction.value = null;
    }
  }

  String _notificationTitle() => _mode == TrackingMode.continuous
      ? 'Running Laps · En carrera'
      : 'Running Laps · Serie $_serieNumber';

  String _formatDistance(int meters) {
    if (meters < 1000) return '$meters m';
    return '${(meters / 1000).toStringAsFixed(2)} km';
  }

  String _getElapsedText() {
    if (_externalElapsed != null) return _externalElapsed!;
    if (_sessionStartTime == null) return '00:00';

    final currentPauseMs = _pauseStartTime != null
        ? DateTime.now().difference(_pauseStartTime!).inMilliseconds
        : 0;
    final netMs = DateTime.now()
            .difference(_sessionStartTime!)
            .inMilliseconds -
        _pausedDurationMs -
        currentPauseMs;
    if (netMs < 0) return '00:00';

    final totalSec = netMs ~/ 1000;
    final m = totalSec ~/ 60;
    final s = totalSec % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  int _getElapsedSeconds() {
    final elapsed = _getElapsedText().split(':');
    if (elapsed.length != 2) return 0;
    final minutes = int.tryParse(elapsed[0]) ?? 0;
    final seconds = int.tryParse(elapsed[1]) ?? 0;
    return minutes * 60 + seconds;
  }

  IOSLiveActivityPayload _currentIOSPayload({
    required String title,
    required String actionId,
    required String actionLabel,
  }) {
    return IOSLiveActivityPayload(
      title: title,
      distance: _formatDistance(totalDistanceMeters.value),
      elapsed: _getElapsedText(),
      elapsedSeconds: _getElapsedSeconds(),
      pace: currentPace.value,
      mode: _mode == TrackingMode.continuous ? 'continuous' : 'intervals',
      serie: _serieNumber,
      hasGps: _gpsEnabled,
      isPaused: status.value != GpsStatus.running,
      actionLabel: actionLabel,
      actionId: actionId,
      phase: _mode == TrackingMode.continuous ? 'continuous' : 'running',
      restCountdown: 0,
    );
  }

  bool get _useIOSLiveActivity =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  void _handlePosition(Position position) {
    if (status.value != GpsStatus.running) return;

    final now = DateTime.now();
    final frame = SensorFrame(
      latitude: position.latitude,
      longitude: position.longitude,
      altitude: position.altitude,
      gpsAccuracy: position.accuracy,
      gpsSpeed: position.speed,
      stepsDelta: _sensorService.consumeStepsDelta(),
      acceleration: 0.0,
      timestamp: now,
    );

    final newState = _processTick(_trackingState.value, frame);
    if (newState == _trackingState.value) {
      cadence.value = _sensorService.cadence.value;
      return;
    }

    _trackingState.value = newState;
    totalDistanceMeters.value = newState.distanceTotal.round();

    if (newState.velocity > 0.4) {
      currentPace.value = _formatPace(1000 / newState.velocity);
    } else if (newState.distanceTotal < 15) {
      currentPace.value = '--:-- /km';
    }

    if (_sessionStartTime != null) {
      final sessionDurationMs =
          now.difference(_sessionStartTime!).inMilliseconds -
          _pausedDurationMs;
      if (sessionDurationMs > 3000 && newState.distanceTotal > 15) {
        final totalSeconds = sessionDurationMs / 1000.0;
        final avgVel = newState.distanceTotal / totalSeconds;
        if (avgVel > 0.1) {
          averagePace.value = _formatPace(1000 / avgVel);
        }
      }
    }

    if (newState.latitude != null && newState.longitude != null) {
      final last = points.isNotEmpty ? points.last : null;
      final isNewPoint = last == null ||
          last.latitude != newState.latitude ||
          last.longitude != newState.longitude;
      if (isNewPoint) {
        points.add(
          GpsPoint(
            latitude: newState.latitude!,
            longitude: newState.longitude!,
            altitude: frame.altitude ?? 0.0,
            timestamp: now,
          ),
        );
      }
    }

    // On iOS the Live Activity is updated on every GPS event rather than on a
    // timer — the location background mode keeps delivering positions while
    // backgrounded, whereas Timer.periodic may be throttled or suspended.
    if (_useIOSLiveActivity) {
      _sendNotificationUpdate();
    }

    cadence.value = _sensorService.cadence.value;
  }

  TrackingState _processTick(TrackingState state, SensorFrame frame) {
    final dt =
        frame.timestamp.difference(state.lastTimestamp).inMilliseconds /
        1000.0;
    if (dt <= 0) return state;

    final deltaTime = dt.clamp(0.2, 2.0);
    final gpsAccuracy = frame.gpsAccuracy ?? double.infinity;
    final hasCoordinates =
        frame.latitude != null && frame.longitude != null;
    final hasUsableGps = hasCoordinates && gpsAccuracy <= 50;
    final hasReliableGps = hasCoordinates && gpsAccuracy <= 20;
    final hasGpsSpeed =
        frame.gpsSpeed != null &&
        frame.gpsSpeed!.isFinite &&
        frame.gpsSpeed! >= 0.0 &&
        frame.gpsSpeed! <= 12.0;
    final gpsStable = hasReliableGps && hasGpsSpeed;

    if (gpsStable) {
      _gpsStableSeconds++;
    } else {
      _gpsStableSeconds = 0;
    }

    // UserTrackingState machine
    UserTrackingState newUserState = state.userState;

    if (hasUsableGps && (frame.stepsDelta > 0)) {
      _noGpsSeconds = 0;
      _stoppedSeconds = 0;
      newUserState = UserTrackingState.movingGps;
    } else if (!hasUsableGps && frame.stepsDelta > 0) {
      _noGpsSeconds++;
      _stoppedSeconds = 0;
      if (_noGpsSeconds > 5) newUserState = UserTrackingState.movingNoGps;
    } else if (frame.stepsDelta == 0 && state.velocity < 0.3) {
      _stoppedSeconds++;
      if (_stoppedSeconds > 3) newUserState = UserTrackingState.stopped;
    } else {
      newUserState = UserTrackingState.uncertain;
    }

    if (!hasUsableGps && frame.stepsDelta == 0 && state.velocity < 0.35) {
      return TrackingState(
        latitude: state.latitude,
        longitude: state.longitude,
        velocity: state.velocity * 0.85,
        heading: state.heading,
        distanceTotal: state.distanceTotal,
        strideLength: state.strideLength,
        lastTimestamp: frame.timestamp,
        userState: newUserState,
      );
    }

    // EKF2D integration
    double? lat = state.latitude;
    double? lon = state.longitude;

    if (hasUsableGps && frame.latitude != null && frame.longitude != null) {
      if (!_ekf.isInitialized) {
        _ekf.initialize(
          frame.latitude!,
          frame.longitude!,
          hasGpsSpeed ? frame.gpsSpeed! : 0.0,
          state.heading,
        );
        lat = frame.latitude;
        lon = frame.longitude;
      } else {
        // Adaptive noise
        final velocityDelta = hasGpsSpeed
            ? (frame.gpsSpeed! - state.velocity).abs()
            : 0.0;
        _ekf.setAdaptiveNoise(gpsAccuracy, velocityDelta);

        // Predict + update
        _ekf.predict(dt);
        final corrected = _ekf.updateGPS(
          frame.latitude!,
          frame.longitude!,
          gpsAccuracy,
        );
        lat = corrected[0];
        lon = corrected[1];

        // Update heading from GPS speed direction when moving
        if (hasGpsSpeed && frame.gpsSpeed! > 0.5) {
          if (state.latitude != null && state.longitude != null) {
            final dlat = lat! - state.latitude!;
            final dlon = lon! - state.longitude!;
            if (dlat.abs() > 1e-8 || dlon.abs() > 1e-8) {
              final hdg = math.atan2(dlon, dlat);
              _ekf.updateHeading(hdg);
            }
          }
        }
      }
    }

    double distance = 0.0;
    var acceptedGpsSegment = false;
    if (lat != null &&
        lon != null &&
        state.latitude != null &&
        state.longitude != null) {
      final rawDistance = _calculateHaversine(
        state.latitude!,
        state.longitude!,
        lat,
        lon,
      );
      final inferredSpeed = rawDistance / dt;
      final referenceSpeed = hasGpsSpeed ? frame.gpsSpeed! : state.velocity;
      final maxAllowedSpeed = _maxAllowedSpeed(
        accuracy: gpsAccuracy,
        referenceSpeed: referenceSpeed,
      );
      final jumpAllowance = math.max(10.0, gpsAccuracy * 1.5);
      final plausibleByDistance =
          rawDistance <= maxAllowedSpeed * dt + jumpAllowance;
      final plausibleByGpsSpeed =
          !hasGpsSpeed || (frame.gpsSpeed! - inferredSpeed).abs() <= 4.0;

      if (hasUsableGps && plausibleByDistance && plausibleByGpsSpeed) {
        distance = rawDistance;
        if (!kIsWeb &&
            defaultTargetPlatform == TargetPlatform.iOS &&
            distance < 1.0 &&
            frame.stepsDelta == 0) {
          distance = 0.0;
        }
        acceptedGpsSegment = true;
      }
    }

    // Dead reckoning: when movingNoGps use pedometer exclusively
    if (!acceptedGpsSegment && frame.stepsDelta > 0) {
      final pedometerDistance = frame.stepsDelta * state.strideLength;
      if (newUserState == UserTrackingState.movingNoGps) {
        // GPS lost — trust pedometer fully
        if (pedometerDistance <= 4.0 * deltaTime) {
          distance = pedometerDistance;
        }
      } else if (!hasUsableGps) {
        // GPS marginal — use pedometer as fallback with cap
        if (pedometerDistance <= 4.0 * deltaTime) {
          distance = pedometerDistance;
        }
      }
    }

    late final double velocity;
    if (acceptedGpsSegment && hasGpsSpeed) {
      velocity = _blendSpeed(state.velocity, frame.gpsSpeed!, 0.45);
    } else if (acceptedGpsSegment) {
      velocity = _blendSpeed(state.velocity, distance / dt, 0.30);
    } else if (!hasUsableGps && frame.stepsDelta > 0) {
      velocity = _blendSpeed(
        state.velocity,
        (frame.stepsDelta * state.strideLength) / deltaTime,
        0.18,
      );
    } else {
      velocity = _blendSpeed(state.velocity, 0.0, 0.10);
    }

    var stride = state.strideLength;
    if (_gpsStableSeconds >= 8 &&
        frame.stepsDelta > 0 &&
        acceptedGpsSegment &&
        distance > 0.0) {
      final gpsStride = distance / frame.stepsDelta;
      final maxChange = stride * 0.05;
      final diff = gpsStride - stride;
      final clamped = diff.clamp(-maxChange, maxChange);
      stride = stride + clamped * 0.1;
    }

    return TrackingState(
      latitude: lat,
      longitude: lon,
      velocity: velocity.clamp(0.0, 10.0),
      heading: state.heading,
      distanceTotal: state.distanceTotal + distance,
      strideLength: stride,
      lastTimestamp: frame.timestamp,
      userState: newUserState,
    );
  }

  double _maxAllowedSpeed({
    required double accuracy,
    required double referenceSpeed,
  }) {
    final normalizedAccuracy = accuracy.isFinite
        ? accuracy.clamp(0.0, 50.0)
        : 50.0;
    final accuracyPenalty = normalizedAccuracy / 25.0;
    final baseline = math.max(referenceSpeed + 2.5, 6.5);
    return math.min(10.0, baseline + accuracyPenalty);
  }

  double _blendSpeed(double previous, double current, double weight) {
    final w = weight.clamp(0.0, 1.0);
    return previous + ((current - previous) * w);
  }

  double _calculateHaversine(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const r = 6371000.0;
    final dLat = (lat2 - lat1) * (math.pi / 180.0);
    final dLon = (lon2 - lon1) * (math.pi / 180.0);
    final sinLat = math.sin(dLat / 2);
    final sinLon = math.sin(dLon / 2);
    final a = sinLat * sinLat +
        math.cos(lat1 * (math.pi / 180.0)) *
            math.cos(lat2 * (math.pi / 180.0)) *
            sinLon *
            sinLon;
    return r * 2 * math.asin(math.sqrt(a));
  }

  String _formatPace(double secPerKm) {
    if (secPerKm > 3600 || secPerKm < 60) {
      if (secPerKm > 3600) return '--:-- /km';
    }
    final m = (secPerKm / 60).floor();
    final s = (secPerKm % 60).round();
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')} /km';
  }
}
