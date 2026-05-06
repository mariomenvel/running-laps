import 'dart:math';
import '../services/rate_limit_service.dart';

Future<T> withExponentialBackoff<T>(
  Future<T> Function() fn, {
  int maxRetries = 3,
}) async {
  int attempt = 0;
  final random = Random();

  while (true) {
    try {
      return await fn();
    } on RateLimitExceededException catch (e) {
      attempt++;
      if (attempt >= maxRetries) rethrow;

      final baseMs = e.duration.inMilliseconds;
      final jitter = (baseMs * 0.1 * (random.nextDouble() * 2 - 1)).round();
      final waitMs = baseMs + jitter;

      await Future.delayed(Duration(milliseconds: waitMs.clamp(0, waitMs + 500)));
    } catch (e) {
      rethrow;
    }
  }
}
