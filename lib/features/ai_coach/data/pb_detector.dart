import 'package:running_laps/features/ai_coach/data/ai_coach_models.dart';

/// Detecta si un entreno completado contiene una nueva marca personal
/// en distancias estándar (5K, 10K, media maratón, maratón) y la
/// compara con el PB actual del perfil.
class PbDetector {
  const PbDetector._();

  static const _standardDistances = {
    5000: 'pb5k',
    10000: 'pb10k',
    21097: 'pbHalfMarathon',
    42195: 'pbMarathon',
  };

  // ±3% de tolerancia para considerar que el entreno "cubre" la distancia
  static const _tolerancePct = 0.03;

  /// Dada una distancia y tiempo total de un entreno, detecta si coincide
  /// con una distancia estándar y mejora el PB actual del perfil.
  /// Devuelve el campo actualizado y el nuevo tiempo en segundos, o null.
  static ({String field, int seconds})? detect({
    required int distanceM,
    required int timeSeconds,
    required AiCoachProfile profile,
  }) {
    if (distanceM < 1000 || timeSeconds <= 0) return null;

    for (final entry in _standardDistances.entries) {
      final targetM = entry.key;
      final field = entry.value;

      final lower = (targetM * (1 - _tolerancePct)).round();
      final upper = (targetM * (1 + _tolerancePct)).round();

      if (distanceM < lower || distanceM > upper) continue;

      // Interpola el tiempo a la distancia exacta si hay diferencia de metros
      final adjustedTime = distanceM != targetM
          ? (timeSeconds * targetM / distanceM).round()
          : timeSeconds;

      final currentPb = _currentPbFor(field, profile);
      if (currentPb == null || adjustedTime < currentPb) {
        return (field: field, seconds: adjustedTime);
      }
      return null; // distancia correcta pero sin mejora
    }
    return null; // ninguna distancia estándar
  }

  /// Aplica la mejora al perfil via copyWith y devuelve el perfil actualizado.
  static AiCoachProfile applyPb({
    required AiCoachProfile profile,
    required String field,
    required int seconds,
  }) {
    switch (field) {
      case 'pb5k':
        return profile.copyWith(pb5kSeconds: seconds);
      case 'pb10k':
        return profile.copyWith(pb10kSeconds: seconds);
      case 'pbHalfMarathon':
        return profile.copyWith(pbHalfMarathonSeconds: seconds);
      case 'pbMarathon':
        return profile.copyWith(pbMarathonSeconds: seconds);
      default:
        return profile;
    }
  }

  /// Etiqueta legible para mostrar al usuario.
  static String labelFor(String field) {
    switch (field) {
      case 'pb5k':
        return '5K';
      case 'pb10k':
        return '10K';
      case 'pbHalfMarathon':
        return 'Media Maratón';
      case 'pbMarathon':
        return 'Maratón';
      default:
        return field;
    }
  }

  /// Formatea segundos como "H:MM:SS" (si hay horas) o "M:SS".
  static String format(int seconds) {
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    final s = seconds % 60;
    if (h > 0) {
      return '$h:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  static int? _currentPbFor(String field, AiCoachProfile p) {
    switch (field) {
      case 'pb5k':
        return p.pb5kSeconds;
      case 'pb10k':
        return p.pb10kSeconds;
      case 'pbHalfMarathon':
        return p.pbHalfMarathonSeconds;
      case 'pbMarathon':
        return p.pbMarathonSeconds;
      default:
        return null;
    }
  }
}
