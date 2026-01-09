import 'package:running_laps/features/analytics/data/series_pattern.dart';
import 'package:running_laps/features/analytics/data/workout_pattern.dart';
import 'package:running_laps/features/training/data/entrenamiento.dart';
import 'package:running_laps/features/analytics/data/pattern_detector.dart';

/// Cache for pattern detection to avoid recalculation
class PatternCache {
  static final PatternCache _instance = PatternCache._internal();
  factory PatternCache() => _instance;
  PatternCache._internal();

  // Cache storage
  List<SeriesPattern>? _cachedSeriesPatterns;
  List<WorkoutPattern>? _cachedWorkoutPatterns;
  List<Entrenamiento>? _cachedData;
  DateTime? _lastUpdate;

  // Cache duration (5 minutes)
  static const _cacheDuration = Duration(minutes: 5);

  /// Get series patterns (cached or fresh)
  List<SeriesPattern> getSeriesPatterns(List<Entrenamiento> data) {
    if (_isCacheValid(data)) {
      return _cachedSeriesPatterns!;
    }

    // Recalculate
    final detector = PatternDetector();
    final patterns = detector.detectSeriesPatterns(data);
    
    _updateCache(data, seriesPatterns: patterns);
    return patterns;
  }

  /// Get workout patterns (cached or fresh)
  List<WorkoutPattern> getWorkoutPatterns(List<Entrenamiento> data) {
    if (_isCacheValid(data)) {
      return _cachedWorkoutPatterns!;
    }

    // Recalculate
    final detector = PatternDetector();
    final patterns = detector.detectWorkoutPatterns(data);
    
    _updateCache(data, workoutPatterns: patterns);
    return patterns;
  }

  /// Check if cache is still valid
  bool _isCacheValid(List<Entrenamiento> data) {
    if (_cachedData == null || _lastUpdate == null) {
      return false;
    }

    // Check if cache expired
    if (DateTime.now().difference(_lastUpdate!) > _cacheDuration) {
      return false;
    }

    // Check if data changed (simple length check)
    if (_cachedData!.length != data.length) {
      return false;
    }

    return true;
  }

  /// Update cache
  void _updateCache(
    List<Entrenamiento> data, {
    List<SeriesPattern>? seriesPatterns,
    List<WorkoutPattern>? workoutPatterns,
  }) {
    _cachedData = data;
    _lastUpdate = DateTime.now();
    
    if (seriesPatterns != null) {
      _cachedSeriesPatterns = seriesPatterns;
    }
    if (workoutPatterns != null) {
      _cachedWorkoutPatterns = workoutPatterns;
    }
  }

  /// Invalidate cache (call when data changes)
  void invalidate() {
    _cachedData = null;
    _cachedSeriesPatterns = null;
    _cachedWorkoutPatterns = null;
    _lastUpdate = null;
  }

  /// Clear cache completely
  void clear() {
    invalidate();
  }
}

