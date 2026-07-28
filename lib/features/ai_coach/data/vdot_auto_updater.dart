import 'package:running_laps/features/ai_coach/data/ai_coach_models.dart';
import 'package:running_laps/features/ai_coach/data/vdot_calculator.dart';

/// De dónde salió la estimación de VDOT vigente.
enum VdotSource {
  /// Sembrado desde las marcas del perfil.
  profilePb,

  /// Ajustado por cómo ejecutó el atleta sus sesiones de calidad.
  trainingEvidence,

  /// Un esfuerzo máximo sostenido que vale como test.
  timeTrial,
}

extension VdotSourceX on VdotSource {
  String get toValue {
    switch (this) {
      case VdotSource.profilePb:
        return 'profile_pb';
      case VdotSource.trainingEvidence:
        return 'training_evidence';
      case VdotSource.timeTrial:
        return 'time_trial';
    }
  }

  static VdotSource fromValue(String value) {
    switch (value) {
      case 'training_evidence':
        return VdotSource.trainingEvidence;
      case 'time_trial':
        return VdotSource.timeTrial;
      default:
        return VdotSource.profilePb;
    }
  }
}

/// Resultado de revisar el VDOT con la evidencia reciente.
class VdotUpdate {
  final double vdot;
  final double previousVdot;
  final VdotSource source;

  /// Sesiones con evidencia utilizable que sostienen la decisión.
  final int evidenceCount;

  /// Motivo legible: se le enseña al atleta cuando sus ritmos cambian.
  final String reason;

  const VdotUpdate({
    required this.vdot,
    required this.previousVdot,
    required this.source,
    required this.evidenceCount,
    required this.reason,
  });

  bool get changed => (vdot - previousVdot).abs() >= 0.01;
  bool get improved => vdot > previousVdot;
}

/// Mantiene el VDOT del atleta al día a partir de cómo entrena, en vez de
/// esperar a que meta una marca nueva a mano.
///
/// El problema que resuelve: hoy los ritmos objetivo solo cambian si el atleta
/// introduce un PB. Alguien que mejora durante tres meses sigue entrenando con
/// los ritmos del día que se registró — y no ve ningún progreso.
///
/// Dos vías, ambas deterministas:
///
/// 1. **Evidencia de ejecución.** Si clava o supera los ritmos prescritos sin
///    pasarse del RPE previsto, su VDOT está infraestimado. Si se queda corto
///    apretando de más, está sobreestimado. Es la misma autorregulación que
///    gobierna el volumen, aplicada a la intensidad.
/// 2. **Test encubierto.** Un esfuerzo continuo a tope (RPE >= 9) sobre una
///    distancia decente es una marca de facto: se le aplica Daniels directo.
///
/// Asimetría deliberada: bajar exige menos evidencia que subir. Unos ritmos
/// demasiado fáciles cuestan una semana de estímulo; unos demasiado duros
/// cuestan una lesión.
class VdotAutoUpdater {
  const VdotAutoUpdater();

  static const Set<String> _qualityCategories = {
    'tempo',
    'series_cortas',
    'series_largas',
    'series_mixtas',
    'series_cuestas',
  };

  /// Categorías de esfuerzo continuo: en las de series, el tiempo total
  /// incluye los descansos y aplicar Daniels daría un VDOT absurdamente bajo.
  static const Set<String> _continuousCategories = {'rodaje_base', 'tempo'};

  /// Paso por revisión. Un punto de VDOT son ~5-6 s/km en umbral, así que
  /// medio punto (~3 s/km) se nota en semanas sin dar bandazos.
  static const double _step = 0.5;

  /// Tope de subida por un test encubierto: un GPS con un mal día no puede
  /// disparar el VDOT.
  static const double _maxTimeTrialJump = 2.0;

  static const int _minSessionsToRaise = 3;
  static const int _minSessionsToLower = 2;

  /// Semilla desde las marcas del perfil. Solo se usa cuando no hay estimación
  /// previa: a partir de ahí manda la evidencia.
  double? seedFromProfile(AiCoachProfile profile) =>
      VdotCalculator.bestVdotFromProfile(profile);

  VdotUpdate? review({
    required double? currentVdot,
    required AiCoachProfile? profile,
    required List<AiCoachTrainingSummary> recentSessions,
  }) {
    final baseline = currentVdot ??
        (profile == null ? null : seedFromProfile(profile));
    if (baseline == null) return null;

    // 1. Test encubierto: manda sobre cualquier ajuste incremental.
    final trial = _bestTimeTrialVdot(recentSessions);
    if (trial != null && trial > baseline) {
      final capped = trial > baseline + _maxTimeTrialJump
          ? baseline + _maxTimeTrialJump
          : trial;
      return VdotUpdate(
        vdot: _clamp(capped),
        previousVdot: baseline,
        source: VdotSource.timeTrial,
        evidenceCount: 1,
        reason: 'Hiciste un esfuerzo a tope que vale como test: '
            'tus ritmos suben.',
      );
    }

    // 2. Ajuste por cómo ejecutó las sesiones de calidad.
    var beats = 0;
    var misses = 0;
    for (final session in recentSessions) {
      if (!_qualityCategories.contains(session.category)) continue;
      final compliance = session.paceCompliancePercent;
      if (compliance == null) continue;

      final harder = session.wasHarderThanExpected == true;
      final easier = session.wasEasierThanExpected == true;

      // Superó el ritmo prescrito sin pagarlo en esfuerzo.
      if (compliance >= 102 && !harder) {
        beats++;
      } else if (compliance <= 95 && harder) {
        misses++;
      } else if (compliance <= 90) {
        // Quedarse muy corto cuenta aunque no marcara RPE alto.
        misses++;
      } else if (compliance >= 100 && easier) {
        beats++;
      }
    }

    if (misses >= _minSessionsToLower && misses > beats) {
      return VdotUpdate(
        vdot: _clamp(baseline - _step),
        previousVdot: baseline,
        source: VdotSource.trainingEvidence,
        evidenceCount: misses,
        reason: 'Te estás quedando corto en los ritmos: los ajusto un poco '
            'para que vuelvas a darlos.',
      );
    }

    if (beats >= _minSessionsToRaise && beats > misses) {
      return VdotUpdate(
        vdot: _clamp(baseline + _step),
        previousVdot: baseline,
        source: VdotSource.trainingEvidence,
        evidenceCount: beats,
        reason: 'Vas por delante de tus ritmos objetivo: has mejorado, '
            'así que los aprieto.',
      );
    }

    return null;
  }

  /// Un esfuerzo continuo a tope equivale a una marca. Se descartan las
  /// sesiones de series porque su tiempo total incluye descansos.
  double? _bestTimeTrialVdot(List<AiCoachTrainingSummary> sessions) {
    double? best;
    for (final session in sessions) {
      if (!_continuousCategories.contains(session.category)) continue;
      final rpe = session.rpe;
      if (rpe == null || rpe < 9) continue;
      if (session.distanceKm < 3 || session.durationMinutes <= 0) continue;

      final vdot = VdotCalculator.estimateVdot(
        distanceM: (session.distanceKm * 1000).round(),
        timeSeconds: (session.durationMinutes * 60).round(),
      );
      if (vdot == null) continue;
      if (best == null || vdot > best) best = vdot;
    }
    return best;
  }

  double _clamp(double value) => value.clamp(30.0, 85.0);
}
