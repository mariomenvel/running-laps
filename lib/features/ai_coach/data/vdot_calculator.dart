import 'dart:math' as math;

import 'package:running_laps/features/ai_coach/data/ai_coach_models.dart';

/// Calculador de VDOT basado en las tablas de Jack Daniels.
/// Convierte marcas personales en paces objetivo por zona.
///
/// Fórmulas de Daniels & Gilbert (1979):
///   VDOT se estima a partir del % de VO2max sostenible en cada distancia.
///   Los paces de entrenamiento se derivan del VDOT estimado.
class VdotCalculator {
  const VdotCalculator._();

  /// Estima el VDOT a partir de una marca personal.
  /// [distanceM] distancia en metros (5000, 10000, 21097, 42195)
  /// [timeSeconds] tiempo total en segundos
  /// Devuelve null si los parámetros son inválidos.
  static double? estimateVdot({
    required int distanceM,
    required int timeSeconds,
  }) {
    if (timeSeconds <= 0 || distanceM <= 0) return null;

    final velocity = distanceM / (timeSeconds / 60.0); // m/min
    final durationMin = timeSeconds / 60.0;

    // % VO2max sostenible según duración (Daniels & Gilbert 1979)
    final pctVo2max = 0.8 +
        0.1894393 * math.exp(-0.012778 * durationMin) +
        0.2989558 * math.exp(-0.1932605 * durationMin);

    // VO2 a esa velocidad (ml/kg/min)
    final vo2 = -4.60 + 0.182258 * velocity + 0.000104 * velocity * velocity;

    final vdot = vo2 / pctVo2max;
    return vdot.clamp(30.0, 85.0);
  }

  /// Estima el VDOT más fiable a partir de las marcas disponibles en el perfil.
  /// Usa la media aritmética de los VDOT de cada distancia disponible.
  static double? bestVdotFromProfile(AiCoachProfile profile) {
    final candidates = <double>[];

    void tryAdd(int? seconds, int distanceM) {
      if (seconds == null) return;
      final v = estimateVdot(distanceM: distanceM, timeSeconds: seconds);
      if (v != null) candidates.add(v);
    }

    tryAdd(profile.pb5kSeconds, 5000);
    tryAdd(profile.pb10kSeconds, 10000);
    tryAdd(profile.pbHalfMarathonSeconds, 21097);
    tryAdd(profile.pbMarathonSeconds, 42195);

    if (candidates.isEmpty) return null;
    return candidates.reduce((a, b) => a + b) / candidates.length;
  }

  /// Paces objetivo en seg/km para cada zona de entrenamiento, basados en VDOT.
  /// Zonas de Daniels (% de vVO2max):
  ///   Z1: ~55-65% · Z2: 65-75% · Z3: 82-88% · Z4: 95-100% · Z5: 105-110%
  static TrainingPaces? pacesFromVdot(double vdot) {
    final vvo2max = _vvo2maxFromVdot(vdot); // m/min

    int toPace(double pct) {
      final velocity = vvo2max * pct;
      if (velocity <= 0) return 600;
      return (1000.0 / velocity * 60.0).round();
    }

    return TrainingPaces(
      z1MinSecPerKm: toPace(0.65),
      z1MaxSecPerKm: toPace(0.55),
      z2MinSecPerKm: toPace(0.75),
      z2MaxSecPerKm: toPace(0.65),
      z3MinSecPerKm: toPace(0.88),
      z3MaxSecPerKm: toPace(0.82),
      z4MinSecPerKm: toPace(1.00),
      z4MaxSecPerKm: toPace(0.95),
      z5MinSecPerKm: toPace(1.10),
      z5MaxSecPerKm: toPace(1.05),
    );
  }

  /// Estima vVO2max (m/min) a partir del VDOT usando Newton-Raphson
  /// sobre la ecuación cuadrática de Daniels: VO2 = -4.60 + 0.182258v + 0.000104v²
  static double _vvo2maxFromVdot(double vdot) {
    double v = (vdot + 4.60) / 0.182258; // estimación inicial
    for (int i = 0; i < 5; i++) {
      final vo2 = -4.60 + 0.182258 * v + 0.000104 * v * v;
      final dvo2dv = 0.182258 + 2 * 0.000104 * v;
      v = v - (vo2 - vdot) / dvo2dv;
    }
    return v.clamp(150.0, 400.0);
  }
}

/// Paces de entrenamiento personalizados en segundos/km.
/// Min = pace más rápido (límite inferior del rango).
/// Max = pace más lento (límite superior del rango).
class TrainingPaces {
  final int z1MinSecPerKm;
  final int z1MaxSecPerKm;
  final int z2MinSecPerKm;
  final int z2MaxSecPerKm;
  final int z3MinSecPerKm;
  final int z3MaxSecPerKm;
  final int z4MinSecPerKm;
  final int z4MaxSecPerKm;
  final int z5MinSecPerKm;
  final int z5MaxSecPerKm;

  const TrainingPaces({
    required this.z1MinSecPerKm,
    required this.z1MaxSecPerKm,
    required this.z2MinSecPerKm,
    required this.z2MaxSecPerKm,
    required this.z3MinSecPerKm,
    required this.z3MaxSecPerKm,
    required this.z4MinSecPerKm,
    required this.z4MaxSecPerKm,
    required this.z5MinSecPerKm,
    required this.z5MaxSecPerKm,
  });
}
