import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show Color;
import 'package:flutter/foundation.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:geolocator/geolocator.dart';

import 'package:running_laps/core/services/foreground_tracking_handler.dart';
import 'package:running_laps/core/services/sensor_service.dart';
import 'package:running_laps/core/tracking/tracking_state.dart';
import 'package:running_laps/core/tracking/sensor_frame.dart';
import 'package:running_laps/core/utils/kalman_filter.dart';

// ── Public enums ─────────────────────────────────────────────────────────────

enum GpsStatus { unknown, disabled, permissionDenied, running, paused }

/// Controls the notification title and the action-button label.
///
/// - [continuous]: title "En carrera", button "Terminar" (id: `finish_run`)
/// - [intervals]:  title "Serie N",    button "Fin de serie" (id: `end_serie`)
enum TrackingMode { continuous, intervals }

// ── GpsPoint ──────────────────────────────────────────────────────────────────

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
        timestamp:
            DateTime.tryParse(map['timestamp'] ?? '') ?? DateTime.now(),
      );
}

// ── GPSService ────────────────────────────────────────────────────────────────

class GPSService {
  /* ═══════════════════════ PUBLIC API ═══════════════════════ */

  final ValueNotifier<GpsStatus> status = ValueNotifier(GpsStatus.unknown);
  final ValueNotifier<int> totalDistanceMeters = ValueNotifier(0);
  final ValueNotifier<String> currentPace = ValueNotifier('--:-- /km');
  final ValueNotifier<int> cadence = ValueNotifier(0);

  /// Average pace of the entire session.
  final ValueNotifier<String> averagePace = ValueNotifier('--:-- /km');

  /// Fired when the user taps the notification action button.
  ///
  /// Value is the button id (`'finish_run'` or `'end_serie'`), then
  /// immediately reset to `null`. Listen with [ValueNotifier.addListener]
  /// and check for a non-null value.
  final ValueNotifier<String?> notificationAction = ValueNotifier(null);

  /// All GPS points collected in the current session.
  final List<GpsPoint> points = [];

  /* ═══════════════════════ INTERNAL ═════════════════════════ */

  final SensorService _sensorService = SensorService();
  final KalmanFilter _kalmanLat =
      KalmanFilter(processNoise: 1e-8, measurementNoise: 1e-7);
  final KalmanFilter _kalmanLon =
      KalmanFilter(processNoise: 1e-8, measurementNoise: 1e-7);
  final ValueNotifier<TrackingState> _trackingState =
      ValueNotifier(createInitialTrackingState());

  StreamSubscription<Position>? _positionSubscription;
  Timer? _notificationTimer;

  int _gpsStableSeconds = 0;
  DateTime? _sessionStartTime;
  int _pausedDurationMs = 0;
  DateTime? _pauseStartTime;

  // ── Notification state ──────────────────────────────────────────────────────
  TrackingMode _mode = TrackingMode.continuous;
  int _serieNumber = 1;
  bool _gpsEnabled = false; // false → notification-only mode (no GPS stream)
  String? _externalElapsed; // override for elapsed text when GPS is off

  /* ═══════════════════════ LIFECYCLE ════════════════════════ */

  GPSService() {
    _initForegroundTask();
  }

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

  /// Starts a GPS tracking session.
  ///
  /// [mode] controls the notification title and the action button label.
  /// [serieNumber] is shown in the title when [mode] is [TrackingMode.intervals].
  Future<void> startTracking({
    TrackingMode mode = TrackingMode.continuous,
    int serieNumber = 1,
  }) async {
    _mode = mode;
    _serieNumber = serieNumber;
    _gpsEnabled = true;
    status.value = GpsStatus.running;

    _trackingState.value = createInitialTrackingState();
    _sensorService.resetSession();
    points.clear();
    _gpsStableSeconds = 0;
    _sessionStartTime = DateTime.now();
    _pausedDurationMs = 0;
    _pauseStartTime = null;

    await _startForegroundService();

    _positionSubscription?.cancel();

    const locationSettings = LocationSettings(
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
    }
  }

  /// Updates the serie counter shown in the notification title (intervals mode).
  ///
  /// Call this every time the user advances to the next serie.
  void updateSerie(int n) {
    _serieNumber = n;
    _sendNotificationUpdate();
  }

  /// Starts the foreground notification **without** enabling GPS.
  ///
  /// Use this when the user is training without GPS tracking. The notification
  /// will show the elapsed time supplied via [setExternalElapsed] rather than
  /// computing it internally.
  Future<void> startNotificationOnly({
    TrackingMode mode = TrackingMode.continuous,
    int serieNumber = 1,
  }) async {
    _mode = mode;
    _serieNumber = serieNumber;
    _gpsEnabled = false;
    status.value = GpsStatus.paused; // marks service as active (not unknown)
    await _startForegroundService();
  }

  /// Provides the elapsed time shown in the notification when GPS is off.
  ///
  /// Call this regularly (e.g. from the UI stopwatch timer) with a "MM:SS"
  /// formatted string. The next notification refresh will pick it up.
  void setExternalElapsed(String elapsed) {
    _externalElapsed = elapsed;
  }

  /// Stops GPS and removes the persistent notification.
  ///
  /// Does NOT dispose the [ValueNotifier]s — the service can be reused.
  Future<void> stopTracking() async {
    if (status.value != GpsStatus.running &&
        status.value != GpsStatus.paused) {
      return;
    }
    _positionSubscription?.cancel();
    _positionSubscription = null;
    _notificationTimer?.cancel();
    _notificationTimer = null;
    status.value = GpsStatus.paused;
    await FlutterForegroundTask.stopService();
  }

  /// Stops tracking and clears all accumulated data (distance, points, pace).
  Future<void> reset() async {
    await stopTracking();
    points.clear();
    totalDistanceMeters.value = 0;
    currentPace.value = '--:-- /km';
    averagePace.value = '--:-- /km';
    cadence.value = 0;
    _trackingState.value = createInitialTrackingState();
    _sessionStartTime = null;
    _pausedDurationMs = 0;
    _pauseStartTime = null;
    _gpsStableSeconds = 0;
  }

  void dispose() {
    FlutterForegroundTask.removeTaskDataCallback(_onDataFromTask);
    _positionSubscription?.cancel();
    _notificationTimer?.cancel();
    FlutterForegroundTask.stopService();
    status.dispose();
    totalDistanceMeters.dispose();
    currentPace.dispose();
    averagePace.dispose();
    cadence.dispose();
    notificationAction.dispose();
  }

  /* ═══════════════════════ FOREGROUND TASK ══════════════════ */

  /// One-time setup: init options + communication port + data callback.
  void _initForegroundTask() {
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'running_laps_tracking',
        channelName: 'Seguimiento de carrera',
        channelDescription: 'GPS activo durante el entrenamiento',
        // LOW importance = no sound/vibration, but persistent on screen.
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
        // Show always on lock screen.
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

    // Set up the IsolateNameServer port so sendDataToMain() can reach us.
    FlutterForegroundTask.initCommunicationPort();

    // Register our callback for data coming from the TaskHandler.
    FlutterForegroundTask.addTaskDataCallback(_onDataFromTask);
  }

  /// Starts the Android foreground service / iOS background task.
  Future<void> _startForegroundService() async {
    final title = _notificationTitle();
    final buttonId =
        _mode == TrackingMode.continuous ? 'finish_run' : 'end_serie';
    final buttonLabel =
        _mode == TrackingMode.continuous ? 'Terminar' : 'Fin de serie';

    await FlutterForegroundTask.startService(
      serviceId: 500,
      notificationTitle: title,
      notificationText: '0.00 km  ·  00:00  ·  --:-- /km',
      // App icon with brand-purple background (Android only).
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

  /// Pushes current metrics to [ForegroundTrackingHandler] so it can refresh
  /// the notification text, title, and button.
  void _sendNotificationUpdate() {
    FlutterForegroundTask.sendDataToTask({
      'distance': _formatDistance(totalDistanceMeters.value),
      'elapsed': _getElapsedText(),
      'pace': currentPace.value,
      'mode': _mode == TrackingMode.continuous ? 'continuous' : 'intervals',
      'serie': _serieNumber,
      'gps': _gpsEnabled,
    });
  }

  /// Receives events sent by [ForegroundTrackingHandler.onNotificationButtonPressed].
  ///
  /// Bringing the app to the foreground is handled natively by
  /// [ButtonLaunchReceiver] (Kotlin). This method only needs to fire the
  /// [notificationAction] ValueNotifier so the UI can react.
  void _onDataFromTask(Object data) {
    if (data is! Map<dynamic, dynamic>) return;
    final m = Map<String, dynamic>.from(data);
    final event = m['event'] as String?;
    if (event != null) {
      // Fire listeners with the event, then reset to null so the same event
      // can be fired again on the next button press.
      notificationAction.value = event;
      notificationAction.value = null;
    }
  }

  // ── Helpers ─────────────────────────────────────────────────────────────────

  String _notificationTitle() => _mode == TrackingMode.continuous
      ? 'Running Laps · En carrera'
      : 'Running Laps · Serie $_serieNumber';

  /// "2.40 km" for ≥ 1 000 m; "240 m" below that.
  String _formatDistance(int meters) {
    if (meters < 1000) return '$meters m';
    return '${(meters / 1000).toStringAsFixed(2)} km';
  }

  /// "MM:SS" net running time.
  ///
  /// When running without GPS the caller provides the elapsed string via
  /// [setExternalElapsed]; otherwise it is computed from [_sessionStartTime].
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

  /* ═══════════════════════ GPS HANDLER ══════════════════════ */

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

    if (newState != _trackingState.value) {
      _trackingState.value = newState;
      totalDistanceMeters.value = newState.distanceTotal.round();

      // Average pace (session total)
      if (_sessionStartTime != null) {
        final sessionDurationMs =
            now.difference(_sessionStartTime!).inMilliseconds -
                _pausedDurationMs;
        if (sessionDurationMs > 3000 && newState.distanceTotal > 5) {
          final double totalSeconds = sessionDurationMs / 1000.0;
          final double avgVel = newState.distanceTotal / totalSeconds;
          if (avgVel > 0.1) {
            final paceStr = _formatPace(1000 / avgVel);
            averagePace.value = paceStr;
            currentPace.value = paceStr;
          }
        }
      }

      if (newState.latitude != null && newState.longitude != null) {
        bool isNewPoint = true;
        if (points.isNotEmpty) {
          final last = points.last;
          if (last.latitude == newState.latitude &&
              last.longitude == newState.longitude) {
            isNewPoint = false;
          }
        }
        if (isNewPoint) {
          points.add(GpsPoint(
            latitude: newState.latitude!,
            longitude: newState.longitude!,
            altitude: frame.altitude ?? 0.0,
            timestamp: now,
          ));
        }
      }
    }

    cadence.value = _sensorService.cadence.value;
  }

  /* ═══════════════════════ CORE LOGIC ═══════════════════════ */

  TrackingState _processTick(TrackingState state, SensorFrame frame) {
    final dt =
        frame.timestamp.difference(state.lastTimestamp).inMilliseconds /
            1000.0;
    if (dt <= 0) return state;

    final deltaTime = dt > 2.0 ? 1.0 : dt;

    final bool gpsStable = frame.gpsAccuracy != null &&
        frame.gpsAccuracy! <= 30 &&
        frame.gpsSpeed != null &&
        frame.gpsSpeed! >= 0.1 &&
        frame.gpsSpeed! <= 10.0;

    if (gpsStable) {
      _gpsStableSeconds++;
    } else {
      _gpsStableSeconds = 0;
    }

    // Anti-drift (parado real)
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
      velocity = (frame.stepsDelta * state.strideLength) / deltaTime;
    } else {
      velocity = 0.0;
    }
    if (velocity > 10.0) velocity = 10.0;
    if (velocity < 0) velocity = 0;

    // Posición filtrada
    double? lat = state.latitude;
    double? lon = state.longitude;

    if (gpsStable && frame.latitude != null && frame.longitude != null) {
      final double accDeg = (frame.gpsAccuracy ?? 5.0) * 0.000009;
      lat = _kalmanLat.filter(frame.latitude!, accuracy: accDeg);
      lon = _kalmanLon.filter(frame.longitude!, accuracy: accDeg);
    }

    // Distancia Haversine
    double distance = 0.0;
    if (lat != null &&
        lon != null &&
        state.latitude != null &&
        state.longitude != null) {
      distance = _calculateHaversine(
        state.latitude!,
        state.longitude!,
        lat,
        lon,
      );
      // Physical speed limit (10 m/s = 36 km/h)
      final double calculatedSpeed = distance / dt;
      if (calculatedSpeed > 10.0) {
        _gpsStableSeconds = 0;
        return state;
      }
    }

    // Recalibración de zancada
    double stride = state.strideLength;
    if (_gpsStableSeconds >= 8 && frame.stepsDelta > 0 && gpsStable) {
      final gpsStride = (velocity * deltaTime) / frame.stepsDelta;
      final maxChange = stride * 0.05;
      final diff = gpsStride - stride;
      final clamped = diff.clamp(-maxChange, maxChange);
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

  /* ═══════════════════════ HELPERS ══════════════════════════ */

  double _calculateHaversine(
      double lat1, double lon1, double lat2, double lon2) {
    const double r = 6371000;
    final double dLat = (lat2 - lat1) * (math.pi / 180.0);
    final double dLon = (lon2 - lon1) * (math.pi / 180.0);
    final double sinLat = math.sin(dLat / 2);
    final double sinLon = math.sin(dLon / 2);
    final double a = sinLat * sinLat +
        math.cos(lat1 * (math.pi / 180.0)) *
            math.cos(lat2 * (math.pi / 180.0)) *
            sinLon * sinLon;
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
