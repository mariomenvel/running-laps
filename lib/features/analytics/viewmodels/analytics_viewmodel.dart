import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:running_laps/features/training/data/entrenamiento.dart';
import 'package:running_laps/features/training/data/training_repository.dart';
import 'package:running_laps/features/analytics/data/pattern_detector.dart';
import 'package:running_laps/features/analytics/data/series_pattern.dart';
import 'package:running_laps/features/analytics/data/workout_pattern.dart';

class AnalyticsViewModel extends ChangeNotifier {
  final TrainingRepository _repository;
  final String _userId;

  List<Entrenamiento> _allEntrenamientos = [];
  bool _isLoading = true;
  String? _error;

  AnalyticsViewModel({TrainingRepository? repository}) 
      : _repository = repository ?? TrainingRepository(),
        _userId = FirebaseAuth.instance.currentUser?.uid ?? '';

  bool get isLoading => _isLoading;
  String? get error => _error;
  List<Entrenamiento> get entrenamientos => _allEntrenamientos;

  Future<void> loadData() async {
    if (_userId.isEmpty) return;
    
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final data = await _repository.getAllEntrenamientos(_userId);
      // Ordenar por fecha desc
      data.sort((a, b) => b.fecha.compareTo(a.fecha));
      _allEntrenamientos = data;
    } catch (e) {
      _error = 'Error loading analytics data: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // --- KPI CALCULATIONS ---

  double get totalDistanceKm {
    return _allEntrenamientos.fold(0.0, (sum, e) => sum + (e.distanciaTotalM() / 1000.0));
  }

  int get totalWorkouts => _allEntrenamientos.length;

  double get avgPaceSecKm {
    if (_allEntrenamientos.isEmpty) return 0;
    
    double totalMeters = 0;
    double totalSeconds = 0;
    
    for (var e in _allEntrenamientos) {
      totalMeters += e.distanciaTotalM();
      totalSeconds += e.tiempoTotalSec();
    }
    
    if (totalMeters == 0) return 0;
    return (totalSeconds / (totalMeters / 1000.0));
  }

  // Formato ritmo min:seg
  String get formattedAvgPace {
    final secPerKm = avgPaceSecKm;
    if (secPerKm == 0) return '-';
    final m = secPerKm ~/ 60;
    final s = (secPerKm % 60).toInt();
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  // --- LAST 30 DAYS METRICS ---

  List<Entrenamiento> get last30DaysWorkouts {
    final now = DateTime.now();
    final cutoff = now.subtract(const Duration(days: 30));
    return _allEntrenamientos.where((e) => e.fecha.isAfter(cutoff)).toList();
  }

  double get distanceLast30Days {
    return last30DaysWorkouts.fold(0.0, (sum, e) => sum + (e.distanciaTotalM() / 1000.0));
  }

  // --- DISTRIBUTIONS ---

  Map<int, int> get rpeDistribution {
    final Map<int, int> dist = {};
    for (var e in _allEntrenamientos) {
      final rpe = e.rpePromedio().round();
      if (rpe > 0) {
        dist[rpe] = (dist[rpe] ?? 0) + 1;
      }
    }
    return dist;
  }

  Map<String, int> get tagDistribution {
    final Map<String, int> dist = {};
    for (var e in _allEntrenamientos) {
      if (e.tags != null && e.tags!.isNotEmpty) {
        for (var tag in e.tags!) {
           dist[tag] = (dist[tag] ?? 0) + 1;
        }
      } else {
        // Opcional: contar "Sin etiqueta"
        // dist['Sin etiqueta'] = (dist['Sin etiqueta'] ?? 0) + 1;
      }
    }
    return dist;
  }

  // --- PATTERNS ---
  
  List<SeriesPattern> get frequentSeriesPatterns {
    if (_allEntrenamientos.isEmpty) return [];
    
    final detector = PatternDetector();
    // Use correct method detectSeriesPatterns
    final patterns = detector.detectSeriesPatterns(_allEntrenamientos);
    
    // Filter frequent
    final frequent = patterns.where((p) => p.count >= 3).toList();
    // Sort by count
    frequent.sort((a, b) => b.count.compareTo(a.count));
    
    return frequent;
  }

  List<WorkoutPattern> get frequentWorkoutPatterns {
    if (_allEntrenamientos.isEmpty) return [];
     
    final detector = PatternDetector();
    // Use correct method detectWorkoutPatterns
    final patterns = detector.detectWorkoutPatterns(_allEntrenamientos);
    
    final frequent = patterns.where((p) => p.count >= 2).toList();
    frequent.sort((a, b) => b.count.compareTo(a.count));
    
    return frequent;
  }
}
