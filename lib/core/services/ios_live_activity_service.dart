import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class IOSLiveActivityPayload {
  const IOSLiveActivityPayload({
    required this.title,
    required this.distance,
    required this.elapsed,
    required this.elapsedSeconds,
    required this.pace,
    required this.mode,
    required this.serie,
    required this.hasGps,
    required this.isPaused,
    required this.actionLabel,
    required this.actionId,
    this.phase = 'running',
    this.restCountdown = 0,
  });

  factory IOSLiveActivityPayload.rest({
    required int restCountdown,
    required int serie,
  }) {
    return IOSLiveActivityPayload(
      title: 'Running Laps · Descansando',
      distance: '0 m',
      elapsed: '00:00',
      elapsedSeconds: 0,
      pace: '--:-- /km',
      mode: 'intervals',
      serie: serie,
      hasGps: false,
      isPaused: true,
      actionLabel: 'Saltar',
      actionId: 'skip_rest',
      phase: 'rest',
      restCountdown: restCountdown,
    );
  }

  final String title;
  final String distance;
  final String elapsed;
  final int elapsedSeconds;
  final String pace;
  final String mode;
  final int serie;
  final bool hasGps;
  final bool isPaused;
  final String actionLabel;
  final String actionId;
  final String phase;
  final int restCountdown;

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'title': title,
      'distance': distance,
      'elapsed': elapsed,
      'elapsedSeconds': elapsedSeconds,
      'pace': pace,
      'mode': mode,
      'serie': serie,
      'hasGps': hasGps,
      'isPaused': isPaused,
      'actionLabel': actionLabel,
      'actionId': actionId,
      'phase': phase,
      'restCountdown': restCountdown,
    };
  }
}

class IOSLiveActivityService {
  IOSLiveActivityService._();

  static final IOSLiveActivityService instance = IOSLiveActivityService._();

  static const MethodChannel _methodChannel = MethodChannel(
    'running_laps/live_activity',
  );
  static const EventChannel _eventChannel = EventChannel(
    'running_laps/live_activity_actions',
  );

  Stream<String>? _actions;

  bool get isSupported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  Stream<String> get actions {
    _actions ??= _eventChannel
        .receiveBroadcastStream()
        .where((dynamic event) => event is String && event.isNotEmpty)
        .cast<String>();
    return _actions!;
  }

  Future<void> start(IOSLiveActivityPayload payload) async {
    if (!isSupported) return;
    try {
      await _methodChannel.invokeMethod<void>('start', payload.toMap());
    } catch (e) {
      debugPrint('[LiveActivity] start failed: $e');
    }
  }

  Future<void> update(IOSLiveActivityPayload payload) async {
    if (!isSupported) return;
    try {
      await _methodChannel.invokeMethod<void>('update', payload.toMap());
    } catch (e) {
      debugPrint('[LiveActivity] update failed: $e');
    }
  }

  Future<void> stop() async {
    if (!isSupported) return;
    try {
      await _methodChannel.invokeMethod<void>('stop');
    } catch (e) {
      debugPrint('[LiveActivity] stop failed: $e');
    }
  }
}
