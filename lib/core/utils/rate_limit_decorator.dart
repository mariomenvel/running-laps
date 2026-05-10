import '../services/rate_limit_service.dart';

class RateLimited {
  final String key;
  final Duration duration;
  const RateLimited(this.key, this.duration);
}

Future<T> rateLimitedCall<T>(
  String key,
  Future<T> Function() fn, {
  Duration duration = const Duration(seconds: 2),
}) {
  return RateLimitService().call(key, fn, duration: duration);
}

void rateLimitCheck(String key, Duration duration) {
  RateLimitService().registerLimit(key, duration);
  RateLimitService().checkLimit(key);
}
