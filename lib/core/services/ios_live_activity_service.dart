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
  });

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
    await _methodChannel.invokeMethod<void>('start', payload.toMap());
  }

  Future<void> update(IOSLiveActivityPayload payload) async {
    if (!isSupported) return;
    await _methodChannel.invokeMethod<void>('update', payload.toMap());
  }

  Future<void> stop() async {
    if (!isSupported) return;
    await _methodChannel.invokeMethod<void>('stop');
  }
}
