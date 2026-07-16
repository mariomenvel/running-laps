import 'package:flutter/material.dart';
import 'package:running_laps/core/services/rate_limit_service.dart';
import 'package:running_laps/features/training/data/entrenamiento.dart';
import 'package:running_laps/features/training/data/training_repository.dart';

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

  bool _disposed = false;

  // Cache de los datos cargados para no recargar constantemente.
  // Acotado por fecha: por defecto los últimos 12 meses (el rango máximo del
  // selector); un rango custom más antiguo dispara una recarga desde su inicio.
  List<Entrenamiento> _allData = [];
  DateTime? _loadedSince;

  List<Entrenamiento> get allData => List.unmodifiable(_allData);

  AnalyticsHubController({
    required this.userId,
    TrainingRepository? repository,
  }) : _repository = repository ?? TrainingRepository();

  static DateTime get _defaultSince =>
      DateTime.now().subtract(const Duration(days: 365));

  Future<void> initialize({List<Entrenamiento>? initialData}) async {
    if (_disposed) return;
    if (initialData != null) {
      _allData = List.from(initialData);
      // Ordenar por fecha desc por si acaso
      _allData.sort((a, b) => b.fecha.compareTo(a.fecha));
      isLoading.value = false;
      _applyFilters();
      return;
    }

    await _loadData(_defaultSince);
    _applyFilters();
  }

  Future<void> _loadData(DateTime since) async {
    if (_disposed) return;
    isLoading.value = true;
    try {
      _allData = await _repository.getTrainingsSince(since, uid: userId);
      _loadedSince = since;
      if (_disposed) return;
      _allData.sort((a, b) => b.fecha.compareTo(a.fecha));
    } on RateLimitExceededException catch (e) {
      debugPrint('[AnalyticsHubController] rate limited: $e');
    } catch (e) {
      // Error
    }
    if (!_disposed) isLoading.value = false;
  }

  void setRange(AnalyticsTimeRange range, {DateTimeRange? custom}) {
    if (_disposed) return;
    selectedRange.value = range;
    if (range == AnalyticsTimeRange.custom) {
      customDateRange.value = custom;
    } else {
      customDateRange.value = null;
    }

    // Rango custom anterior a lo cargado → ampliar la ventana y re-filtrar.
    final customStart = customDateRange.value?.start;
    if (customStart != null &&
        _loadedSince != null &&
        customStart.isBefore(_loadedSince!)) {
      _loadData(customStart).then((_) {
        if (!_disposed) _applyFilters();
      });
      return;
    }

    _applyFilters();
  }

  void _applyFilters() {
    if (_disposed) return;
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

  // Duración total en segundos
  double get totalDurationSeconds {
    return filteredData.value.fold(0.0, (sum, e) => sum + e.tiempoTotalSec());
  }

  // Formato duración formateada (ej: 5h 30m)
  String get formattedTotalDuration {
    final totalSeconds = totalDurationSeconds;
    if (totalSeconds == 0) return '0h';
    
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    } else {
      return '${minutes}m';
    }
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
    _disposed = true;
    selectedRange.dispose();
    customDateRange.dispose();
    filteredData.dispose();
    isLoading.dispose();
  }
}

