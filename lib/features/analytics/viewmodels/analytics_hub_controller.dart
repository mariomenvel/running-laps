import 'package:flutter/material.dart';
import 'package:running_laps/features/training/data/entrenamiento.dart';
import 'package:running_laps/features/training/data/training_repository.dart';
import 'package:running_laps/features/home/views/home_view.dart';
// Note: We reuse TimeRange from HomeView for consistency, or we could move it to a shared model file.

enum AnalyticsTimeRange {
  week,
  month,
  threeMonths,
  year,
  custom,
}

class AnalyticsHubController {
  final TrainingRepository _repository;
  final String userId;

  // Estado
  final ValueNotifier<AnalyticsTimeRange> selectedRange = ValueNotifier(AnalyticsTimeRange.month);
  final ValueNotifier<DateTimeRange?> customDateRange = ValueNotifier(null);
  
  // Datos filtrados compartidos por los tabs
  final ValueNotifier<List<Entrenamiento>> filteredData = ValueNotifier([]);
  final ValueNotifier<bool> isLoading = ValueNotifier(true);

  // Cache de todos los datos para no recargar constantemente
  List<Entrenamiento> _allData = [];

  AnalyticsHubController({
    required this.userId,
    TrainingRepository? repository,
  }) : _repository = repository ?? TrainingRepository();

  Future<void> initialize() async {
    await _loadAllData();
    _applyFilters();
  }

  Future<void> _loadAllData() async {
    isLoading.value = true;
    try {
      // Cargar todo el historial (o un límite razonable, ej: 1 año)
      _allData = await _repository.getAllEntrenamientos(userId);
      // Ordenar por fecha desc
      _allData.sort((a, b) => b.fecha.compareTo(a.fecha));
    } catch (e) {
      debugPrint("Error loading analytics data: $e");
    } finally {
      isLoading.value = false;
    }
  }

  void setRange(AnalyticsTimeRange range, {DateTimeRange? custom}) {
    selectedRange.value = range;
    if (range == AnalyticsTimeRange.custom) {
      customDateRange.value = custom;
    } else {
      customDateRange.value = null;
    }
    _applyFilters();
  }

  void _applyFilters() {
    if (_allData.isEmpty) {
      filteredData.value = [];
      return;
    }

    final now = DateTime.now();
    DateTime start;
    DateTime end = now;

    switch (selectedRange.value) {
      case AnalyticsTimeRange.week:
        start = now.subtract(const Duration(days: 7));
        break;
      case AnalyticsTimeRange.month:
        start = now.subtract(const Duration(days: 30));
        break;
      case AnalyticsTimeRange.threeMonths:
        start = now.subtract(const Duration(days: 90));
        break;
      case AnalyticsTimeRange.year:
        start = now.subtract(const Duration(days: 365));
        break;
      case AnalyticsTimeRange.custom:
        if (customDateRange.value != null) {
          start = customDateRange.value!.start;
          end = customDateRange.value!.end;
        } else {
          start = now.subtract(const Duration(days: 30)); // fallback
        }
        break;
    }

    // Filtrar
    final filtered = _allData.where((e) {
      return e.fecha.isAfter(start.subtract(const Duration(seconds: 1))) && 
             e.fecha.isBefore(end.add(const Duration(days: 1))); // Inclusive end day
    }).toList();

    filteredData.value = filtered;
  }

  // --- KPI CALCULATIONS (Based on filteredData) ---

  double get totalDistanceKm {
    return filteredData.value.fold(0.0, (sum, e) => sum + (e.distanciaTotalM() / 1000.0));
  }

  int get totalWorkouts => filteredData.value.length;

  double get avgPaceSecKm {
    if (filteredData.value.isEmpty) return 0;
    
    double totalMeters = 0;
    double totalSeconds = 0;
    
    for (var e in filteredData.value) {
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
  
  double get distanceLast30Days {
     // Calculate based on _allData for independent metric
     final now = DateTime.now();
     final cutoff = now.subtract(const Duration(days: 30));
     return _allData
        .where((e) => e.fecha.isAfter(cutoff))
        .fold(0.0, (sum, e) => sum + (e.distanciaTotalM() / 1000.0));
  }

  void dispose() {
    selectedRange.dispose();
    customDateRange.dispose();
    filteredData.dispose();
    isLoading.dispose();
  }
}
