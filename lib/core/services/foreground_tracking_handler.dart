import 'package:running_laps/core/theme/app_colors.dart';
import 'dart:ui' show Color;

import 'package:flutter_foreground_task/flutter_foreground_task.dart';

/// Entry point called by the Android foreground service in a background isolate.
@pragma('vm:entry-point')
void trackingServiceCallback() {
  FlutterForegroundTask.setTaskHandler(ForegroundTrackingHandler());
}

/// Thin [TaskHandler] that manages the persistent Strava-style notification.
///
/// All GPS computation stays in the main isolate ([GPSService]). Every ~1 s
/// the main isolate pushes formatted metrics here via
/// [FlutterForegroundTask.sendDataToTask]; this handler calls
/// [FlutterForegroundTask.updateService] to refresh the notification.
///
/// When the user taps the action button, [onNotificationButtonPressed] fires
/// and sends `{'event': buttonId}` back to the main isolate via
/// [FlutterForegroundTask.sendDataToMain]. The main isolate exposes it through
/// [GPSService.notificationAction].
///
/// Data shape pushed from GPSService._sendNotificationUpdate:
/// ```dart
/// {
///   'distance': '2.40 km',      // or '240 m'
///   'elapsed':  '18:32',
///   'pace':     '04:45 /km',    // or '--:-- /km'
///   'mode':     'continuous' | 'intervals',
///   'serie':    3,              // current serie index (intervals only)
/// }
/// ```
class ForegroundTrackingHandler extends TaskHandler {
  // ── State ──────────────────────────────────────────────────────────────────
  String _distance = '0.00 km';
  String _elapsed = '00:00';
  String _pace = '--:-- /km';
  String _mode = 'continuous'; // 'continuous' | 'intervals'
  int _serie = 1;
  bool _hasGps = true; // false → only elapsed is shown in notification body

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    _updateNotification();
  }

  @override
  Future<void> onRepeatEvent(DateTime timestamp) async {
    // Notification refreshes come from onReceiveData; nothing needed here.
  }

  @override
  Future<void> onDestroy(DateTime timestamp) async {}

  // ── Button press → send event to main isolate ─────────────────────────────

  @override
  void onNotificationButtonPressed(String id) {
    // Bringing the app to the foreground is handled natively by
    // ButtonLaunchReceiver (Kotlin), which also receives this same broadcast.
    // We only need to forward the button id so GPSService can fire the
    // notificationAction ValueNotifier.
    FlutterForegroundTask.sendDataToMain({'event': id});
  }

  // ── Data from main isolate ─────────────────────────────────────────────────

  @override
  void onReceiveData(Object data) {
    if (data is! Map<dynamic, dynamic>) return;
    final m = Map<String, dynamic>.from(data);
    _distance = (m['distance'] as String?) ?? _distance;
    _elapsed = (m['elapsed'] as String?) ?? _elapsed;
    _pace = (m['pace'] as String?) ?? _pace;
    _mode = (m['mode'] as String?) ?? _mode;
    _serie = (m['serie'] as int?) ?? _serie;
    _hasGps = (m['gps'] as bool?) ?? _hasGps;
    _updateNotification();
  }

  // ── Notification rendering ─────────────────────────────────────────────────

  void _updateNotification() {
    final title = _mode == 'continuous'
        ? 'Running Laps · En carrera'
        : 'Running Laps · Serie $_serie';

    // One action button: label and id depend on mode.
    final buttonId = _mode == 'continuous' ? 'finish_run' : 'end_serie';
    final buttonLabel = _mode == 'continuous' ? 'Terminar' : 'Fin de serie';

    // When there is no GPS only show elapsed time; otherwise show all metrics.
    final body = _hasGps
        ? '$_distance  ·  $_elapsed  ·  $_pace'
        : _elapsed;

    FlutterForegroundTask.updateService(
      notificationTitle: title,
      notificationText: body,
      notificationButtons: [
        NotificationButton(
          id: buttonId,
          text: buttonLabel,
          // Brand purple text on the (white) Android notification button.
          textColor: AppColors.brand,
        ),
      ],
    );
  }
}
