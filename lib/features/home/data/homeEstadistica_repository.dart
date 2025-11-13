// Archivo: lib/features/home/data/homeEstadistica_repository.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

// ===================================
// DEFINICIÓN DE TIPOS (NECESARIO)
// ===================================

enum HomeMetric {
  ritmoMedio,
  distanciaTotal,
  tiempoTotal,
  rpePromedio,
}

enum TimeRange {
  oneWeek,
  oneMonth,
  threeMonths,
  sixMonths,
  oneYear,
  max,
}

class DailyMetric {
  final DateTime date;
  final double value;

  DailyMetric({
    required this.date,
    required this.value,
  });
}

// ===================================
// CLASE REPOSITORIO
// ===================================

class HomeEstadisticaRepository {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<List<Map<String, dynamic>>> _getFilteredTrainingsData({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final User? user = _auth.currentUser;
    if (user == null) return [];

    try {
      final CollectionReference trainingsRef =
          _db.collection('users').doc(user.uid).collection('trainings');

      // Convertimos las fechas a String ISO 8601 para que coincidan con el formato de Firestore
      final String startString = startDate.toIso8601String().substring(0, 19);
      final String endString = endDate.toIso8601String().substring(0, 19);

      final QuerySnapshot snapshot = await trainingsRef
          .where('fecha', isGreaterThanOrEqualTo: startString)
          .where('fecha', isLessThanOrEqualTo: endString)
          .orderBy('fecha', descending: false)
          .get();

      return snapshot.docs
          .map((doc) => doc.data()! as Map<String, dynamic>)
          .toList();

    } on FirebaseException catch (e) {
      debugPrint('Error de Firebase al filtrar entrenamientos: ${e.message}');
      throw Exception('Error al cargar datos: ${e.message}');
    }
  }

  Future<List<DailyMetric>> getMetricsForGraph({
    required TimeRange range,
    required HomeMetric metric,
  }) async {
    final now = DateTime.now();
    DateTime startDate;

    switch (range) {
      case TimeRange.oneWeek: startDate = now.subtract(const Duration(days: 6)); break;
      case TimeRange.oneMonth: startDate = now.subtract(const Duration(days: 30)); break;
      case TimeRange.threeMonths: startDate = now.subtract(const Duration(days: 90)); break;
      case TimeRange.sixMonths: startDate = now.subtract(const Duration(days: 180)); break;
      case TimeRange.oneYear: startDate = now.subtract(const Duration(days: 365)); break;
      case TimeRange.max: startDate = DateTime(2020, 1, 1); break;
    }
    
    final endDate = DateTime(now.year, now.month, now.day, 23, 59, 59);
    startDate = DateTime(startDate.year, startDate.month, startDate.day, 0, 0, 0);

    final List<Map<String, dynamic>> trainingsData = await _getFilteredTrainingsData(
      startDate: startDate,
      endDate: endDate,
    );
    
    final Map<DateTime, List<Map<String, dynamic>>> trainingsByDate = {};
    for (var data in trainingsData) {
      final DateTime fullDate = DateTime.parse(data['fecha'] as String);
      final dateOnly = DateTime(fullDate.year, fullDate.month, fullDate.day);
      trainingsByDate.putIfAbsent(dateOnly, () => []).add(data);
    }

    final List<DailyMetric> results = [];
    trainingsByDate.forEach((date, dailyData) {
      double calculatedValue = 0.0;
      
      switch (metric) {
        case HomeMetric.ritmoMedio:
          final recentTraining = dailyData.last;
          final int? ritmoSec = recentTraining['ritmoMedioSecKm'] as int?;
          calculatedValue = (ritmoSec ?? 0).toDouble(); 
          break;
          
        case HomeMetric.distanciaTotal:
          final totalM = dailyData.fold(0, (sum, data) => sum + (data['distanciaTotalM'] as int? ?? 0));
          calculatedValue = totalM / 1000.0;
          break;
          
        case HomeMetric.tiempoTotal:
          final totalSec = dailyData.fold(0.0, (sum, data) => sum + (data['tiempoTotalSec'] as double? ?? 0.0));
          calculatedValue = totalSec / 60.0;
          break;
          
        case HomeMetric.rpePromedio:
          final totalRPE = dailyData.fold(0.0, (sum, data) => sum + (data['rpePromedio'] as double? ?? 0.0));
          calculatedValue = totalRPE / dailyData.length;
          break;
      }

      results.add(DailyMetric(
        date: date,
        value: calculatedValue,
      ));
    });

    results.sort((a, b) => a.date.compareTo(b.date));
    return results;
  }
}