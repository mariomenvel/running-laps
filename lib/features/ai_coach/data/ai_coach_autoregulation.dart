import 'dart:math' as math;

import 'package:running_laps/features/ai_coach/data/ai_coach_models.dart';

/// Veredicto de autorregulacion para la semana siguiente.
///
/// Equivalente a la progresion por RPE/RIR de la sala de fuerza: si el atleta
/// completo el trabajo dentro del esfuerzo previsto, se sube; si lo saco
/// apretando, se mantiene; si no lo saco, se baja. La progresion se **gana**,
/// no se calendariza.
enum AiCoachReadinessVerdict {
  /// Ejecuto bien y con margen → se puede subir.
  progress,

  /// Lo saco, pero justo → repetir carga, consolidar.
  hold,

  /// No dio los ritmos o acumulo mas fatiga de la prevista → bajar.
  regress,

  /// Paron o desconexion → reentrar por debajo, sin castigo.
  reset,
}

extension AiCoachReadinessVerdictX on AiCoachReadinessVerdict {
  String get toValue {
    switch (this) {
      case AiCoachReadinessVerdict.progress:
        return 'progress';
      case AiCoachReadinessVerdict.hold:
        return 'hold';
      case AiCoachReadinessVerdict.regress:
        return 'regress';
      case AiCoachReadinessVerdict.reset:
        return 'reset';
    }
  }

  static AiCoachReadinessVerdict fromValue(String value) {
    switch (value) {
      case 'progress':
        return AiCoachReadinessVerdict.progress;
      case 'regress':
        return AiCoachReadinessVerdict.regress;
      case 'reset':
        return AiCoachReadinessVerdict.reset;
      default:
        return AiCoachReadinessVerdict.hold;
    }
  }
}

/// Resultado de leer como fue la semana. Es la senal estructurada que hoy no
/// existe: la evidencia de ejecucion ya se calcula, pero solo se le pasaba al
/// LLM como texto para que la interpretase por su cuenta.
class AiCoachAutoregulationSignal {
  final AiCoachReadinessVerdict verdict;

  /// Multiplicador a aplicar sobre el volumen REALMENTE corrido.
  final double volumeFactor;

  /// Media de cumplimiento de ritmo en sesiones de calidad (100 = clavado).
  final double? qualityPaceCompliance;

  /// Sesiones con evidencia utilizable.
  final int sessionsAnalyzed;

  final double adherence;

  /// Repetidamente mas duro de lo previsto → fatiga por encima de la buscada.
  final bool fatigueFlag;

  /// Rodajes suaves corridos muy por encima del ritmo prescrito. Es el error
  /// mas comun del amateur y roba la recuperacion que sostiene la calidad.
  final bool easyDaysTooHard;

  /// Motivo legible: se le muestra al atleta y se le pasa al LLM para que su
  /// narrativa no contradiga la decision.
  final String reason;

  const AiCoachAutoregulationSignal({
    required this.verdict,
    required this.volumeFactor,
    required this.sessionsAnalyzed,
    required this.adherence,
    required this.reason,
    this.qualityPaceCompliance,
    this.fatigueFlag = false,
    this.easyDaysTooHard = false,
  });

  Map<String, dynamic> toMap() => {
        'verdict': verdict.toValue,
        'volumeFactor': volumeFactor,
        if (qualityPaceCompliance != null)
          'qualityPaceCompliance': qualityPaceCompliance!.round(),
        'sessionsAnalyzed': sessionsAnalyzed,
        'adherence': adherence,
        'fatigueFlag': fatigueFlag,
        'easyDaysTooHard': easyDaysTooHard,
        'reason': reason,
      };
}

/// Lee la ejecucion real de la semana y decide si la siguiente sube, se
/// mantiene o baja.
///
/// Logica pura: no toca Firebase ni el LLM. Ver docs/AI_COACH_MESOCYCLE.md.
class AiCoachAutoregulation {
  const AiCoachAutoregulation();

  static const Set<String> _qualityCategories = {
    'tempo',
    'fartlek',
    'series_cortas',
    'series_largas',
    'series_mixtas',
    'series_cuestas',
  };

  /// Umbrales de cumplimiento de ritmo en sesiones de calidad.
  static const double _paceGood = 92;
  static const double _paceMarginal = 85;

  /// Por encima de esto en un rodaje suave, el atleta esta corriendo el facil
  /// demasiado rapido (compliance = objetivo/real, >100 = mas rapido).
  static const double _easyTooFast = 110;

  AiCoachAutoregulationSignal evaluate({
    required List<AiCoachTrainingSummary> lastWeekSessions,
    AiCoachWeeklyState? weeklyState,
  }) {
    final adherence = weeklyState?.adherenceRatio ?? 1.0;
    final missedWeeks = weeklyState?.consecutiveMissedWeeks ?? 0;
    final tsb = weeklyState?.tsb ?? 0;

    // 1. Desconexion: reentrar por debajo. No es un castigo, es un reinicio.
    if (missedWeeks >= 2 || (lastWeekSessions.isEmpty && adherence < 0.35)) {
      return AiCoachAutoregulationSignal(
        verdict: AiCoachReadinessVerdict.reset,
        volumeFactor: 0.70,
        sessionsAnalyzed: lastWeekSessions.length,
        adherence: adherence,
        reason: missedWeeks >= 2
            ? 'Vuelves despues de un paron: se reentra por debajo.'
            : 'Semana sin apenas actividad: se reentra suave.',
      );
    }

    // Sin evidencia no se inventa progresion: se mantiene.
    if (lastWeekSessions.isEmpty) {
      return AiCoachAutoregulationSignal(
        verdict: AiCoachReadinessVerdict.hold,
        volumeFactor: 1.0,
        sessionsAnalyzed: 0,
        adherence: adherence,
        reason: 'Sin sesiones registradas: se mantiene la carga.',
      );
    }

    final quality = lastWeekSessions
        .where((s) => _qualityCategories.contains(s.category))
        .toList();
    final easy = lastWeekSessions
        .where((s) => !_qualityCategories.contains(s.category))
        .toList();

    final qualityCompliance = _averageCompliance(quality);
    final harderCount = lastWeekSessions
        .where((s) => s.wasHarderThanExpected == true)
        .length;
    final easierCount = lastWeekSessions
        .where((s) => s.wasEasierThanExpected == true)
        .length;

    final easyCompliance = _averageCompliance(easy);
    final easyDaysTooHard =
        easyCompliance != null && easyCompliance > _easyTooFast;

    // Fatiga por encima de la buscada: dos o mas sesiones mas duras de lo
    // previsto, o un TSB claramente negativo.
    final fatigueFlag = harderCount >= 2 || tsb < -20;

    // 2. Retroceso. El rendimiento es ciclico: bajar es un estado normal del
    // sistema, no una excepcion.
    if (fatigueFlag ||
        adherence < 0.5 ||
        (qualityCompliance != null && qualityCompliance < _paceMarginal)) {
      return AiCoachAutoregulationSignal(
        verdict: AiCoachReadinessVerdict.regress,
        volumeFactor: 0.85,
        qualityPaceCompliance: qualityCompliance,
        sessionsAnalyzed: lastWeekSessions.length,
        adherence: adherence,
        fatigueFlag: fatigueFlag,
        easyDaysTooHard: easyDaysTooHard,
        reason: _regressReason(
          fatigueFlag: fatigueFlag,
          adherence: adherence,
          compliance: qualityCompliance,
        ),
      );
    }

    // 3. Progresion: solo si dio los ritmos Y le sobro margen Y aparecio.
    final hitPaces =
        qualityCompliance == null || qualityCompliance >= _paceGood;
    final hasMargin = harderCount == 0;
    final showedUp = adherence >= 0.8;

    if (hitPaces && hasMargin && showedUp && !easyDaysTooHard) {
      // Margen extra explicito (sesiones mas faciles de lo previsto) permite el
      // paso completo; si no, se sube a medio paso.
      final factor = easierCount >= 1 ? 1.08 : 1.05;
      return AiCoachAutoregulationSignal(
        verdict: AiCoachReadinessVerdict.progress,
        volumeFactor: factor,
        qualityPaceCompliance: qualityCompliance,
        sessionsAnalyzed: lastWeekSessions.length,
        adherence: adherence,
        easyDaysTooHard: false,
        reason: easierCount >= 1
            ? 'Diste los ritmos con margen: subimos.'
            : 'Semana completada en objetivo: subimos poco a poco.',
      );
    }

    // 4. Consolidar. Ni castigo ni premio: repetir carga hasta asentarla.
    return AiCoachAutoregulationSignal(
      verdict: AiCoachReadinessVerdict.hold,
      volumeFactor: 1.0,
      qualityPaceCompliance: qualityCompliance,
      sessionsAnalyzed: lastWeekSessions.length,
      adherence: adherence,
      easyDaysTooHard: easyDaysTooHard,
      reason: easyDaysTooHard
          ? 'Los rodajes suaves van demasiado rapido: consolidamos y bajamos el facil.'
          : 'Semana sacada justa: consolidamos antes de subir.',
    );
  }

  double? _averageCompliance(List<AiCoachTrainingSummary> sessions) {
    final values = sessions
        .map((s) => s.paceCompliancePercent)
        .whereType<double>()
        .toList();
    if (values.isEmpty) return null;
    return values.reduce((a, b) => a + b) / values.length;
  }

  String _regressReason({
    required bool fatigueFlag,
    required double adherence,
    required double? compliance,
  }) {
    if (fatigueFlag) {
      return 'Acumulaste mas fatiga de la buscada: bajamos para absorberla.';
    }
    if (adherence < 0.5) {
      return 'Se quedaron sesiones sin hacer: ajustamos a lo que da la semana.';
    }
    return 'Te quedaste corto en los ritmos: bajamos para volver a darlos.';
  }

  /// Volumen objetivo de la semana siguiente.
  ///
  /// El bloque marca el TECHO (estructura y seguridad); la autorregulacion
  /// marca la POSICION bajo ese techo (realidad del atleta). La progresion se
  /// gana: sin evidencia de que la semana anterior se absorbio, no se sube.
  double resolveTargetVolume({
    required AiCoachAutoregulationSignal signal,
    required double actualLastWeekKm,
    required double blockCeilingKm,
    required double baselineFallbackKm,
  }) {
    final anchor = actualLastWeekKm > 0 ? actualLastWeekKm : baselineFallbackKm;
    final autoregulated = anchor * signal.volumeFactor;
    return math.min(autoregulated, blockCeilingKm);
  }
}
