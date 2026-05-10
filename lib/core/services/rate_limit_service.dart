import 'package:flutter/foundation.dart';

class RateLimitExceededException implements Exception {
  final String key;
  final Duration duration;
  final DateTime nextAvailable;

  const RateLimitExceededException({
    required this.key,
    required this.duration,
    required this.nextAvailable,
  });

  @override
  String toString() =>
      'RateLimitExceededException: key=$key, wait ${duration.inSeconds}s, next=$nextAvailable';
}

class RateLimitService {
  static final RateLimitService _instance = RateLimitService._internal();
  factory RateLimitService() => _instance;
  RateLimitService._internal();

  final Map<String, DateTime> _lastCallTimes = {};
  final Map<String, Duration> _durations = {};

  void registerLimit(String key, Duration duration) {
    _durations[key] = duration;
    debugPrint('[RateLimitService] registered: $key (${duration.inSeconds}s)');
  }

  void checkLimit(String key) {
    final duration = _durations[key];
    if (duration == null) return;

    final last = _lastCallTimes[key];
    if (last != null) {
      final elapsed = DateTime.now().difference(last);
      if (elapsed < duration) {
        final remaining = duration - elapsed;
        final nextAvailable = last.add(duration);
        throw RateLimitExceededException(
          key: key,
          duration: remaining,
          nextAvailable: nextAvailable,
        );
      }
    }
    _lastCallTimes[key] = DateTime.now();
  }

  Future<T> call<T>(
    String key,
    Future<T> Function() fn, {
    Duration? duration,
  }) async {
    if (duration != null) {
      _durations[key] = duration;
    }
    checkLimit(key);
    return fn();
  }

  void clearKey(String key) {
    _lastCallTimes.remove(key);
    debugPrint('[RateLimitService] cleared key: $key');
  }

  void clearAll() {
    _lastCallTimes.clear();
    debugPrint('[RateLimitService] cleared all keys');
  }

  Map<String, dynamic> getState() {
    return {
      'lastCallTimes': _lastCallTimes.map((k, v) => MapEntry(k, v.toIso8601String())),
      'durations': _durations.map((k, v) => MapEntry(k, v.inMilliseconds)),
    };
  }
}
