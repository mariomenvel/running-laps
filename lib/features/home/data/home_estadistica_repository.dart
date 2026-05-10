// Archivo: lib/features/home/data/home_estadistica_repository.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:running_laps/core/services/rate_limit_service.dart';

// ===================================
// TIPOS
// ===================================

enum HomeMetric { ritmoMedio, distanciaTotal, tiempoTotal, rpePromedio }

enum TimeRange { oneWeek, oneMonth, sixMonths, oneYear, max }

class DailyMetric {
  final DateTime date;
  final double value;

  DailyMetric({required this.date, required this.value});
}

// ===================================
// REPOSITORIO
// ===================================

class HomeEstadisticaRepository {
  static final HomeEstadisticaRepository _instance =
      HomeEstadisticaRepository._internal();
  factory HomeEstadisticaRepository() => _instance;

  HomeEstadisticaRepository._internal() {
    _rateLimitService.registerLimit('analytics:overview', const Duration(seconds: 3));
    _rateLimitService.registerLimit('analytics:trends', const Duration(seconds: 4));
    _rateLimitService.registerLimit('analytics:patterns', const Duration(seconds: 5));
  }

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final RateLimitService _rateLimitService = RateLimitService();

  // --- Cache ---
  final Map<String, List<DailyMetric>> _cache = {};
  final Map<String, DateTime> _cacheTimestamps = {};
  static const _cacheDuration = Duration(minutes: 5);

  String _cacheKey(TimeRange range, HomeMetric metric) =>
      '${range.name}_${metric.name}';

  bool _isCacheValid(String key) {
    final ts = _cacheTimestamps[key];
    if (ts == null) return false;
    return DateTime.now().difference(ts) < _cacheDuration;
  }

  void clearCache() {
    _cache.clear();
    _cacheTimestamps.clear();
  }

  Future<List<Map<String, dynamic>>> _getRawData({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final User? user = _auth.currentUser;
    if (user == null) return [];

    try {
      final CollectionReference trainingsRef = _db
          .collection('users')
          .doc(user.uid)
          .collection('trainings');

      final String startString = startDate.toIso8601String().substring(0, 19);
      final String endString = endDate.toIso8601String().substring(0, 19);

      final QuerySnapshot snapshot = await trainingsRef
          .where('fecha', isGreaterThanOrEqualTo: startString)
          .where('fecha', isLessThanOrEqualTo: endString)
          .orderBy('fecha', descending: false)
          .limit(500)
          .get();

      return snapshot.docs
          .map((doc) => doc.data()! as Map<String, dynamic>)
          .toList();
    } on FirebaseException catch (e) {
      return [];
    }
  }

  Future<List<DailyMetric>> getMetricsForGraph({
    required TimeRange range,
    required HomeMetric metric,
  }) async {
    final key = _cacheKey(range, metric);
    if (_isCacheValid(key)) {
      return _cache[key]!;
    }

    try {
      _rateLimitService.checkLimit('analytics:overview');
    } on RateLimitExceededException {
      // Return stale cache if available, otherwise rethrow
      if (_cache.containsKey(key)) return _cache[key]!;
      rethrow;
    }

    final now = DateTime.now();
    // Aseguramos el final del día actual
    final endDate = DateTime(now.year, now.month, now.day, 23, 59, 59);
    DateTime startDate;

    // 1. Configuración de fechas
    switch (range) {
      case TimeRange.oneWeek:
        startDate = now.subtract(const Duration(days: 6));
        break;
      case TimeRange.oneMonth:
        startDate = now.subtract(const Duration(days: 29));
        break;
      case TimeRange.sixMonths:
        startDate = now.subtract(const Duration(days: 182));
        break;
      case TimeRange.oneYear:
        startDate = DateTime(now.year - 1, now.month, 1);
        break;
      case TimeRange.max:
        startDate = DateTime(2020, 1, 1);
        break;
    }

    // Normalizamos startDate al inicio del día (00:00:00)
    startDate = DateTime(
      startDate.year,
      startDate.month,
      startDate.day,
      0,
      0,
      0,
    );

    final rawData = await _getRawData(startDate: startDate, endDate: endDate);

    // 2. Procesamiento
    List<DailyMetric> result;
    if (range == TimeRange.max) {
      result = _processMaxDataNoGaps(rawData, metric);
    } else if (range == TimeRange.oneWeek || range == TimeRange.oneMonth) {
      result = _processDailyData(rawData, startDate, endDate, metric);
    } else if (range == TimeRange.sixMonths) {
      result = _processWeeklyData(rawData, startDate, endDate, metric);
    } else {
      result = _processMonthlyData(rawData, startDate, endDate, metric);
    }

    _cache[key] = result;
    _cacheTimestamps[key] = DateTime.now();
    return result;
  }

  // --- PROCESADORES ---

  List<DailyMetric> _processMaxDataNoGaps(
    List<Map<String, dynamic>> rawData,
    HomeMetric metric,
  ) {
    if (rawData.isEmpty) return [];

    final Map<String, List<Map<String, dynamic>>> groups = {};

    for (var data in rawData) {
      final dt = DateTime.parse(data['fecha']);
      final key = "${dt.year}-${dt.month.toString().padLeft(2, '0')}";
      groups.putIfAbsent(key, () => []).add(data);
    }

    final sortedKeys = groups.keys.toList()..sort();

    List<DailyMetric> results = [];
    for (var key in sortedKeys) {
      final parts = key.split('-');
      final date = DateTime(int.parse(parts[0]), int.parse(parts[1]), 1);

      results.add(
        DailyMetric(date: date, value: _calculateValue(groups[key]!, metric)),
      );
    }
    return results;
  }

  List<DailyMetric> _processDailyData(
    List<Map<String, dynamic>> rawData,
    DateTime start,
    DateTime end,
    HomeMetric metric,
  ) {
    final Map<DateTime, List<Map<String, dynamic>>> grouped = {};

    // Agrupar datos normalizando la fecha a las 00:00:00
    for (var data in rawData) {
      final dt = DateTime.parse(data['fecha']);
      final dateKey = DateTime(dt.year, dt.month, dt.day);
      grouped.putIfAbsent(dateKey, () => []).add(data);
    }

    List<DailyMetric> results = [];

    // CORRECCIÓN IMPORTANTE:
    // Calculamos la diferencia en días, pero iteramos reconstruyendo el DateTime.
    // Usar start.add(Duration(days: i)) es peligroso por cambios de horario (DST).
    // Ejemplo: Si hay cambio de hora, Duration(days: 1) puede caer a las 23:00 del día anterior,
    // haciendo que la key del mapa no coincida.

    int daysDiff = end.difference(start).inDays;
    // Ajuste de seguridad por si difference da un día menos debido a horas de diferencia
    if (start.add(Duration(days: daysDiff)).day != end.day) {
      daysDiff++;
    }

    for (int i = 0; i <= daysDiff; i++) {
      // Construimos la fecha matemáticamente para asegurar que sean las 00:00:00
      final currentDay = DateTime(start.year, start.month, start.day + i);

      // Salimos si nos pasamos de la fecha final
      if (currentDay.isAfter(end)) break;

      final dayData = grouped[currentDay] ?? [];
      results.add(
        DailyMetric(date: currentDay, value: _calculateValue(dayData, metric)),
      );
    }
    return results;
  }

  List<DailyMetric> _processWeeklyData(
    List<Map<String, dynamic>> rawData,
    DateTime start,
    DateTime end,
    HomeMetric metric,
  ) {
    List<DailyMetric> results = [];
    DateTime currentWeekStart = start;

    while (currentWeekStart.isBefore(end)) {
      DateTime currentWeekEnd = currentWeekStart.add(const Duration(days: 6));
      // Ajustar al final del día
      currentWeekEnd = DateTime(
        currentWeekEnd.year,
        currentWeekEnd.month,
        currentWeekEnd.day,
        23,
        59,
        59,
      );

      if (currentWeekEnd.isAfter(end)) currentWeekEnd = end;

      final weekData = rawData.where((d) {
        final dt = DateTime.parse(d['fecha']);
        return dt.isAfter(
              currentWeekStart.subtract(const Duration(seconds: 1)),
            ) &&
            dt.isBefore(currentWeekEnd.add(const Duration(seconds: 1)));
      }).toList();

      results.add(
        DailyMetric(
          date: currentWeekStart,
          value: _calculateValue(weekData, metric),
        ),
      );

      // Avanzar 7 días
      currentWeekStart = currentWeekStart.add(const Duration(days: 7));
    }
    return results;
  }

  List<DailyMetric> _processMonthlyData(
    List<Map<String, dynamic>> rawData,
    DateTime start,
    DateTime end,
    HomeMetric metric,
  ) {
    List<DailyMetric> results = [];
    DateTime currentMonth = DateTime(start.year, start.month, 1);

    while (currentMonth.isBefore(end) ||
        (currentMonth.month == end.month && currentMonth.year == end.year)) {
      final monthData = rawData.where((d) {
        final dt = DateTime.parse(d['fecha']);
        return dt.month == currentMonth.month && dt.year == currentMonth.year;
      }).toList();

      results.add(
        DailyMetric(
          date: currentMonth,
          value: _calculateValue(monthData, metric),
        ),
      );

      if (currentMonth.month == 12) {
        currentMonth = DateTime(currentMonth.year + 1, 1, 1);
      } else {
        currentMonth = DateTime(currentMonth.year, currentMonth.month + 1, 1);
      }
    }
    return results;
  }

  double _calculateValue(
    List<Map<String, dynamic>> dataList,
    HomeMetric metric,
  ) {
    if (dataList.isEmpty) return 0.0;

    switch (metric) {
      case HomeMetric.ritmoMedio:
        double totalPace = 0;
        int count = 0;
        for (var d in dataList) {
          final val = d['ritmoMedioSecKm'] as int?;
          if (val != null && val > 0) {
            totalPace += val;
            count++;
          }
        }
        return count == 0 ? 0.0 : totalPace / count;
      case HomeMetric.distanciaTotal:
        int totalM = 0;
        for (var d in dataList) {
          totalM += (d['distanciaTotalM'] as int? ?? 0);
        }
        return totalM / 1000.0;
      case HomeMetric.tiempoTotal:
        double totalSec = 0;
        for (var d in dataList) {
          totalSec += (d['tiempoTotalSec'] as double? ?? 0.0);
        }
        return totalSec / 60.0;
      case HomeMetric.rpePromedio:
        double totalRpe = 0;
        int count = 0;
        for (var d in dataList) {
          final val = d['rpePromedio'] as double?;
          if (val != null && val > 0) {
            totalRpe += val;
            count++;
          }
        }
        return count == 0 ? 0.0 : totalRpe / count;
    }
  }
}
