import 'dart:math' show exp;
import 'package:running_laps/features/athlete/data/athlete_session_model.dart';

/// Calcula carga de entrenamiento (proxy o TRIMP) y utilidades
/// relacionadas con competiciones.
///
/// Sin estado mutable, sin dependencias de Firebase.
class TrainingLoadService {
  const TrainingLoadService._();
  static const TrainingLoadService instance = TrainingLoadService._();

  // ── Carga de entrenamiento ────────────────────────────────────────────────

  /// Devuelve la carga estimada de un entrenamiento.
  ///
  /// Si se proporciona [fcAvgBpm], [fcMax] y [fcRest] calcula TRIMP
  /// (Banister). En caso contrario usa un proxy basado en categoría
  /// y RPE.
  double calculateLoad({
    required double distanceKm,
    required double durationMinutes,
    String? category,
    double? rpeAverage,
    double? fcAvgBpm,
    double? fcMax,
    double? fcRest,
  }) {
    if (fcAvgBpm != null && fcMax != null && fcRest != null) {
      return _trimp(
        durationMinutes: durationMinutes,
        fcAvg:           fcAvgBpm,
        fcMax:           fcMax,
        fcRest:          fcRest,
      );
    }
    return _proxyLoad(
      distanceKm: distanceKm,
      category:   category,
      rpeAverage: rpeAverage,
    );
  }

  double _trimp({
    required double durationMinutes,
    required double fcAvg,
    required double fcMax,
    required double fcRest,
  }) {
    final range = fcMax - fcRest;
    if (range <= 0) return 0;
    final ratio = (fcAvg - fcRest) / range;
    return durationMinutes * ratio * 0.64 * exp(1.92 * ratio);
  }

  double _proxyLoad({
    required double distanceKm,
    String? category,
    double? rpeAverage,
  }) {
    var intensity = _intensityForCategory(category);
    if (rpeAverage != null) {
      intensity += (rpeAverage - 5) * 0.1;
    }
    intensity = intensity.clamp(0.5, 3.0);
    return distanceKm * intensity;
  }

  double _intensityForCategory(String? category) {
    switch (category) {
      case 'regenerativo':
      case 'rodaje_base':
        return 1.0;
      case 'tempo':
      case 'fartlek':
        return 1.5;
      case 'series_largas':
      case 'series_cortas':
      case 'series_cuestas':
      case 'series_mixtas':
        return 2.0;
      case 'competicion':
      case 'test':
        return 2.5;
      default:
        return 1.0;
    }
  }

  // ── Competición ───────────────────────────────────────────────────────────

  /// True si [date] está en los 7 días previos a la próxima competición.
  bool isRaceWeek(DateTime date, List<AthleteSession> upcomingSessions) {
    final race = nextRace(upcomingSessions, date);
    if (race == null) return false;
    final days = daysUntil(race, date);
    return days >= 0 && days <= 7;
  }

  /// Primera sesión con categoría 'competicion' en o después de [from].
  AthleteSession? nextRace(
    List<AthleteSession> sessions,
    DateTime from,
  ) {
    final fromDate =
        DateTime(from.year, from.month, from.day);
    final races = sessions
        .where((s) =>
            s.category == 'competicion' &&
            !DateTime.tryParse(s.date)!
                .isBefore(fromDate))
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    return races.isEmpty ? null : races.first;
  }

  /// Días naturales entre [from] (truncado a fecha) y la fecha de [session].
  int daysUntil(AthleteSession session, DateTime from) {
    final sessionDate = DateTime.parse(session.date);
    return sessionDate
        .difference(DateTime(from.year, from.month, from.day))
        .inDays;
  }
}
