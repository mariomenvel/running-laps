import 'package:flutter/foundation.dart';
import 'package:running_laps/features/analytics/viewmodels/analytics_hub_controller.dart';
import 'package:running_laps/features/training/data/entrenamiento.dart';

// ─── Modelos de datos ─────────────────────────────────────────────────────────

class PersonalRecord {
  final int distanceM;
  final double paceSecKm;
  final double totalTimeSec;
  final DateTime date;
  final double? previousPaceSecKm;
  final double? previousTotalTimeSec;

  PersonalRecord({
    required this.distanceM,
    required this.paceSecKm,
    required this.totalTimeSec,
    required this.date,
    this.previousPaceSecKm,
    this.previousTotalTimeSec,
  });

  bool get isRecent => DateTime.now().difference(date).inDays <= 14;
  // delta en segundos de tiempo total (positivo = mejora)
  double? get deltaSec =>
      previousTotalTimeSec != null ? previousTotalTimeSec! - totalTimeSec : null;
}

class PaceDataPoint {
  final DateTime weekStart;
  final double paceSecKm;
  PaceDataPoint({required this.weekStart, required this.paceSecKm});
}

class AnalyticsWeeklyVolume {
  final DateTime weekStart;
  final double km;
  AnalyticsWeeklyVolume({required this.weekStart, required this.km});
}

// ─── ViewModel ────────────────────────────────────────────────────────────────

class AnalyticsViewModel {
  // Tab Rendimiento
  final personalRecords         = ValueNotifier<Map<int, PersonalRecord>>({});
  final paceProgressionByDist   = ValueNotifier<Map<int, List<PaceDataPoint>>>({});
  final avgPaceCurrent          = ValueNotifier<double>(0);
  final avgPacePrevious         = ValueNotifier<double>(0);

  // Tab Entrenamiento
  final weeklyVolumes           = ValueNotifier<List<AnalyticsWeeklyVolume>>([]);
  final intensityEasyPct        = ValueNotifier<double>(0);
  final intensityHardPct        = ValueNotifier<double>(0);
  final consistencyWeeks        = ValueNotifier<int>(0);
  final consistencyTotal        = ValueNotifier<int>(0);
  final currentStreak           = ValueNotifier<int>(0);
  final avgSessionsPerWeek      = ValueNotifier<double>(0);
  final activityDots            = ValueNotifier<List<bool>>([]);
  final sessionsByType          = ValueNotifier<Map<String, int>>({});

  // Tab Forma
  final acuteLoad               = ValueNotifier<double>(0);
  final chronicLoad             = ValueNotifier<double>(0);
  final acwrRatio               = ValueNotifier<double>(0);
  final weeklyRpeAvg            = ValueNotifier<List<double>>([]);
  final weeklyLoads             = ValueNotifier<List<double>>([]);
  final aerobicEfficiency       = ValueNotifier<List<double>?>(null);

  // CTL / ATL / TSB
  final ctlValues               = ValueNotifier<List<double>>([]);
  final atlValues               = ValueNotifier<List<double>>([]);
  final tsbValues               = ValueNotifier<List<double>>([]);
  final currentCTL              = ValueNotifier<double>(0);
  final currentATL              = ValueNotifier<double>(0);
  final currentTSB              = ValueNotifier<double>(0);
  final tsbInsight              = ValueNotifier<String>('');

  // ── API pública ────────────────────────────────────────────────────────────

  void compute(
    List<Entrenamiento> filtered,
    List<Entrenamiento> allWorkouts,
    AnalyticsTimeRange range,
  ) {
    _computeRecords(allWorkouts);
    _computePaceProgression(allWorkouts);
    _computeAvgPace(filtered, allWorkouts, range);
    _computeVolume(filtered);
    _computeIntensity(filtered);
    _computeConsistency(allWorkouts, filtered, range);
    _computeLoad(allWorkouts);
    _computeTrainingStress(allWorkouts);
    _computeEfficiency(filtered);
  }

  // ── Rendimiento ────────────────────────────────────────────────────────────

  static const _standardDistances = [400, 1000, 5000, 10000];
  static const _gpsTol = 0.05;

  void _computeRecords(List<Entrenamiento> all) {
    final sorted = [...all]..sort((a, b) => a.fecha.compareTo(b.fecha));
    final records = <int, PersonalRecord>{};

    for (final dist in _standardDistances) {
      double? best;
      double? bestTime;
      DateTime? bestDate;
      double? prevBest;
      double? prevBestTime;

      for (final w in sorted) {
        for (final s in w.series) {
          if (s.distanciaM <= 0 || s.tiempoSec <= 0) continue;
          if ((s.distanciaM - dist).abs() / dist > _gpsTol) continue;
          final pace = s.tiempoSec / (s.distanciaM / 1000.0);
          if (pace < 120 || pace > 900) continue; // fuera de rango humano
          if (best == null || pace < best) {
            prevBest     = best;
            prevBestTime = bestTime;
            best         = pace;
            bestTime     = s.tiempoSec;
            bestDate     = w.fecha;
          }
        }
      }

      if (best != null && bestTime != null && bestDate != null) {
        records[dist] = PersonalRecord(
          distanceM:            dist,
          paceSecKm:            best,
          totalTimeSec:         bestTime,
          date:                 bestDate,
          previousPaceSecKm:    prevBest,
          previousTotalTimeSec: prevBestTime,
        );
      }
    }

    personalRecords.value = records;
  }

  void _computePaceProgression(List<Entrenamiento> all) {
    final cutoff = DateTime.now().subtract(const Duration(days: 56));
    final byDist = <int, List<(DateTime, double)>>{};

    for (final w in all) {
      if (w.fecha.isBefore(cutoff)) continue;
      for (final s in w.series) {
        if (s.distanciaM <= 0 || s.tiempoSec <= 0) continue;
        for (final d in _standardDistances) {
          if ((s.distanciaM - d).abs() / d <= _gpsTol) {
            final pace = s.tiempoSec / (s.distanciaM / 1000.0);
            if (pace < 120 || pace > 600) continue; // fuera de rango para series
            byDist.putIfAbsent(d, () => []).add((w.fecha, pace));
          }
        }
      }
    }

    final result = <int, List<PaceDataPoint>>{};
    for (final entry in byDist.entries) {
      if (entry.value.length < 3) continue;
      final weekMap = <DateTime, List<double>>{};
      for (final (date, pace) in entry.value) {
        weekMap.putIfAbsent(_mondayOf(date), () => []).add(pace);
      }
      final points = weekMap.entries
          .map((e) => PaceDataPoint(
                weekStart: e.key,
                paceSecKm: e.value.reduce((a, b) => a + b) / e.value.length,
              ))
          .toList()
        ..sort((a, b) => a.weekStart.compareTo(b.weekStart));
      if (points.length >= 2) result[entry.key] = points;
    }

    paceProgressionByDist.value = result;
  }

  void _computeAvgPace(
    List<Entrenamiento> filtered,
    List<Entrenamiento> all,
    AnalyticsTimeRange range,
  ) {
    avgPaceCurrent.value = _avgPace(filtered);
    final now = DateTime.now();
    final days = _rangeDays(range);
    final prevStart = now.subtract(Duration(days: days * 2));
    final prevEnd   = now.subtract(Duration(days: days));
    final prev = all
        .where((w) => w.fecha.isAfter(prevStart) && w.fecha.isBefore(prevEnd))
        .toList();
    avgPacePrevious.value = _avgPace(prev);
  }

  double _avgPace(List<Entrenamiento> list) {
    double totalM = 0, totalS = 0;
    for (final w in list) {
      try {
        final m = w.distanciaTotalM();
        final s = w.tiempoTotalSec();
        if (m <= 100 || s <= 30) continue;
        final pace = s / (m / 1000.0);
        if (pace < 120 || pace > 720) continue; // 2:00-12:00/km para sesiones
        totalM += m;
        totalS += s;
      } catch (_) {
        continue;
      }
    }
    return totalM <= 0 ? 0 : totalS / (totalM / 1000.0);
  }

  // ── Entrenamiento ──────────────────────────────────────────────────────────

  void _computeVolume(List<Entrenamiento> filtered) {
    final now = DateTime.now();
    final weeks = <DateTime, double>{};
    for (int i = 7; i >= 0; i--) {
      weeks[_mondayOf(now.subtract(Duration(days: i * 7)))] = 0;
    }
    for (final w in filtered) {
      final key = _mondayOf(w.fecha);
      if (weeks.containsKey(key)) {
        weeks[key] = weeks[key]! + w.distanciaTotalM() / 1000.0;
      }
    }
    final sorted = weeks.entries.toList()..sort((a, b) => a.key.compareTo(b.key));
    weeklyVolumes.value =
        sorted.map((e) => AnalyticsWeeklyVolume(weekStart: e.key, km: e.value)).toList();
  }

  void _computeIntensity(List<Entrenamiento> filtered) {
    if (filtered.isEmpty) {
      intensityEasyPct.value = 0;
      intensityHardPct.value = 0;
      return;
    }
    int easy = 0, hard = 0;
    for (final w in filtered) {
      if (w.rpePromedio() <= 5) {
        easy++;
      } else {
        hard++;
      }
    }
    final total = easy + hard;
    intensityEasyPct.value = total > 0 ? easy / total * 100 : 0;
    intensityHardPct.value = total > 0 ? hard / total * 100 : 0;
  }

  void _computeConsistency(
    List<Entrenamiento> all,
    List<Entrenamiento> filtered,
    AnalyticsTimeRange range,
  ) {
    final now  = DateTime.now();
    final days = _rangeDays(range);
    final weeks = (days / 7).ceil().clamp(1, 52);

    final activeWeeks = <DateTime>{};
    for (final w in filtered) {
      activeWeeks.add(_mondayOf(w.fecha));
    }
    consistencyWeeks.value = activeWeeks.length;
    consistencyTotal.value = weeks;
    avgSessionsPerWeek.value = weeks > 0 ? filtered.length / weeks : 0;

    // Racha (semanas consecutivas con al menos 1 entreno)
    int streak = 0;
    for (int i = 0; i < 52; i++) {
      final monday = _mondayOf(now.subtract(Duration(days: i * 7)));
      final hasWorkout = all.any((w) => _mondayOf(w.fecha) == monday);
      if (hasWorkout) {
        streak++;
      } else if (i > 0) {
        break;
      }
    }
    currentStreak.value = streak;

    // Dots: últimos 56 días
    final dots = <bool>[];
    for (int i = 55; i >= 0; i--) {
      final day = DateTime(now.year, now.month, now.day).subtract(Duration(days: i));
      dots.add(all.any((w) {
        final d = DateTime(w.fecha.year, w.fecha.month, w.fecha.day);
        return d == day;
      }));
    }
    activityDots.value = dots;

    // Sesiones por tipo (tags)
    final typeMap = <String, int>{};
    for (final w in filtered) {
      final tags = w.tags;
      if (tags == null || tags.isEmpty) {
        typeMap['Sin etiqueta'] = (typeMap['Sin etiqueta'] ?? 0) + 1;
      } else {
        for (final t in tags) {
          typeMap[t] = (typeMap[t] ?? 0) + 1;
        }
      }
    }
    // Ordenar por frecuencia desc, tomar top 5
    final sorted = typeMap.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    sessionsByType.value = Map.fromEntries(sorted.take(5));
  }

  // ── Helpers de carga ──────────────────────────────────────────────────────

  double _getLoadScore(Entrenamiento w) {
    if (w.loadScore != null && w.loadScore! > 0) return w.loadScore!;
    try {
      final distKm    = w.distanciaTotalM() / 1000.0;
      final durationMin = w.tiempoTotalSec() / 60.0;
      if (distKm <= 0 || durationMin <= 0) return 0;
      final rpe = w.rpePromedio();
      return distKm * (rpe > 0 ? rpe : 5.0);
    } catch (_) {
      return 0;
    }
  }

  // ── Forma ──────────────────────────────────────────────────────────────────

  void _computeLoad(List<Entrenamiento> all) {
    final now = DateTime.now();

    // Carga aguda: últimos 7 días
    acuteLoad.value = all
        .where((w) => w.fecha.isAfter(now.subtract(const Duration(days: 7))))
        .fold(0.0, (s, w) => s + _getLoadScore(w));

    // Carga crónica: media de las 4 semanas anteriores
    double weekSum = 0;
    for (int i = 0; i < 4; i++) {
      final wStart = now.subtract(Duration(days: (i + 1) * 7));
      final wEnd   = now.subtract(Duration(days: i * 7));
      weekSum += all
          .where((w) => w.fecha.isAfter(wStart) && w.fecha.isBefore(wEnd))
          .fold(0.0, (s, w) => s + _getLoadScore(w));
    }
    chronicLoad.value = weekSum / 4;
    acwrRatio.value   = chronicLoad.value > 0 ? acuteLoad.value / chronicLoad.value : 0;

    // RPE medio por semana (últimas 4 semanas)
    final rpeByWeek = <double>[];
    for (int i = 3; i >= 0; i--) {
      final wStart = now.subtract(Duration(days: (i + 1) * 7));
      final wEnd   = now.subtract(Duration(days: i * 7));
      final ws     = all.where((w) => w.fecha.isAfter(wStart) && w.fecha.isBefore(wEnd)).toList();
      rpeByWeek.add(ws.isEmpty ? 0 : ws.fold(0.0, (s, w) => s + w.rpePromedio()) / ws.length);
    }
    weeklyRpeAvg.value = rpeByWeek;

    // Carga por semana (últimas 8 semanas)
    final loadByWeek = <double>[];
    for (int i = 7; i >= 0; i--) {
      final wStart = now.subtract(Duration(days: (i + 1) * 7));
      final wEnd   = now.subtract(Duration(days: i * 7));
      loadByWeek.add(all
          .where((w) => w.fecha.isAfter(wStart) && w.fecha.isBefore(wEnd))
          .fold(0.0, (s, w) => s + _getLoadScore(w)));
    }
    weeklyLoads.value = loadByWeek;
  }

  void _computeTrainingStress(List<Entrenamiento> all) {
    final now = DateTime.now();
    final dailyLoad = <DateTime, double>{};
    for (final w in all) {
      final day = DateTime(w.fecha.year, w.fecha.month, w.fecha.day);
      dailyLoad[day] = (dailyLoad[day] ?? 0) + _getLoadScore(w);
    }

    double ctl = 0, atl = 0;
    const ctlDecay = 1 - (2 / (42 + 1));
    const atlDecay = 1 - (2 / (7 + 1));

    final ctlH = <double>[];
    final atlH = <double>[];
    final tsbH = <double>[];

    for (int i = 179; i >= 0; i--) {
      final day  = DateTime(now.year, now.month, now.day).subtract(Duration(days: i));
      final load = dailyLoad[day] ?? 0;
      ctl = ctl * ctlDecay + load * (1 - ctlDecay);
      atl = atl * atlDecay + load * (1 - atlDecay);
      if (i % 14 == 0) {
        ctlH.add(ctl);
        atlH.add(atl);
        tsbH.add(ctl - atl);
      }
    }

    ctlValues.value   = ctlH;
    atlValues.value   = atlH;
    tsbValues.value   = tsbH;
    currentCTL.value  = ctl;
    currentATL.value  = atl;
    currentTSB.value  = ctl - atl;
    tsbInsight.value  = _tsbInsight(ctl - atl);
  }

  String _tsbInsight(double tsb) {
    final t = tsb.toStringAsFixed(0);
    if (tsb > 20)  return 'Muy fresco (TSB +$t). Momento ideal para competir o hacer test.';
    if (tsb > 5)   return 'Fresco (TSB +$t). Buen momento para sesiones intensas.';
    if (tsb > -10) return 'Cargando (TSB $t). Normal durante bloques de entrenamiento.';
    if (tsb > -20) return 'Fatiga acumulada (TSB $t). Considera reducir volumen esta semana.';
    return 'Muy fatigado (TSB $t). Descansa 2-3 días para evitar lesión.';
  }

  void _computeEfficiency(List<Entrenamiento> filtered) {
    final byWeek = <DateTime, List<double>>{};
    for (final w in filtered) {
      if (w.fcMediaSesion == null || w.fcMediaSesion! <= 0) continue;
      final dist = w.distanciaTotalM();
      final time = w.tiempoTotalSec();
      if (dist <= 0 || time <= 0) continue;
      final pace       = time / (dist / 1000.0);
      final efficiency = (1000 / pace) / w.fcMediaSesion! * 1000;
      byWeek.putIfAbsent(_mondayOf(w.fecha), () => []).add(efficiency);
    }

    if (byWeek.isEmpty) {
      aerobicEfficiency.value = null;
      return;
    }
    final sorted = byWeek.entries.toList()..sort((a, b) => a.key.compareTo(b.key));
    aerobicEfficiency.value =
        sorted.map((e) => e.value.reduce((a, b) => a + b) / e.value.length).toList();
  }

  // ── Utilidades ─────────────────────────────────────────────────────────────

  DateTime _mondayOf(DateTime d) =>
      DateTime(d.year, d.month, d.day).subtract(Duration(days: d.weekday - 1));

  int _rangeDays(AnalyticsTimeRange range) => switch (range) {
        AnalyticsTimeRange.week         => 7,
        AnalyticsTimeRange.month        => 30,
        AnalyticsTimeRange.threeMonths  => 90,
        AnalyticsTimeRange.year         => 365,
        AnalyticsTimeRange.custom       => 30,
      };

  void dispose() {
    personalRecords.dispose();
    paceProgressionByDist.dispose();
    avgPaceCurrent.dispose();
    avgPacePrevious.dispose();
    weeklyVolumes.dispose();
    intensityEasyPct.dispose();
    intensityHardPct.dispose();
    consistencyWeeks.dispose();
    consistencyTotal.dispose();
    currentStreak.dispose();
    avgSessionsPerWeek.dispose();
    activityDots.dispose();
    sessionsByType.dispose();
    acuteLoad.dispose();
    chronicLoad.dispose();
    acwrRatio.dispose();
    weeklyRpeAvg.dispose();
    weeklyLoads.dispose();
    aerobicEfficiency.dispose();
    ctlValues.dispose();
    atlValues.dispose();
    tsbValues.dispose();
    currentCTL.dispose();
    currentATL.dispose();
    currentTSB.dispose();
    tsbInsight.dispose();
  }
}
