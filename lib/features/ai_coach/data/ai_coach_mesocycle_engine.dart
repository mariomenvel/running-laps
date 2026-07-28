import 'dart:math' as math;

import 'package:running_laps/features/ai_coach/data/ai_coach_models.dart';

/// Motor de periodizacion del Coach IA.
///
/// Logica pura y determinista: no toca Firebase ni el LLM. El principio del
/// diseno (docs/AI_COACH_MESOCYCLE.md) es que **el LLM escribe el lenguaje y el
/// codigo decide los numeros** — este fichero es la mitad de los numeros.
///
/// El bloque fija un TECHO de carga por semana. La fatiga real solo puede
/// recortar por debajo, nunca superarlo.
class AiCoachMesocycleEngine {
  const AiCoachMesocycleEngine();

  /// Tope duro de progresion semanal. Con esto, la "regla del 10%" deja de ser
  /// una frase en un prompt y pasa a ser aritmeticamente imposible de violar.
  static const double maxWeeklyStepPct = 0.10;

  // ---------------------------------------------------------------------------
  // Volumen
  // ---------------------------------------------------------------------------

  /// Volumen objetivo (km) de la semana [weekIndex] del bloque.
  ///
  /// Las semanas de descarga se calculan sobre el pico alcanzado, no sobre el
  /// baseline: si no, la descarga de un bloque avanzado seria mas dura que la
  /// carga de su primera semana.
  double targetVolumeForWeek(AiCoachMesocycle block, int weekIndex) {
    if (block.baselineVolumeKm <= 0) return 0;
    final index = weekIndex.clamp(0, math.max(0, block.lengthWeeks - 1));
    final type = block.weekTypeAt(index);

    if (type == AiCoachWeekType.absorb ||
        type == AiCoachWeekType.recovery) {
      // El pico es la ultima semana de carga anterior a esta.
      final peak = _progressedVolume(block, math.max(0, index - 1));
      return peak * block.deloadVolumePct;
    }
    if (type == AiCoachWeekType.taper) {
      // Taper: volumen decreciente hacia la carrera, intensidad se mantiene
      // fuera de este calculo (la fija el generador de sesiones).
      return _progressedVolume(block, index) * 0.65;
    }
    if (type == AiCoachWeekType.race) {
      return _progressedVolume(block, index) * 0.40;
    }
    if (type == AiCoachWeekType.restart) {
      // Volver de un paron: se entra por debajo del baseline, no por encima.
      return block.baselineVolumeKm * 0.70;
    }
    return _progressedVolume(block, index);
  }

  /// Progresion con desaceleracion: el paso es proporcional al margen que queda
  /// hasta el techo, asi la curva es logistica y no exponencial.
  ///
  /// Un `baseline * (1+step)^n` encadenado entre bloques daria ~19x de volumen
  /// en un ano. El volumen real asintota hacia un limite que marcan nivel,
  /// objetivo y disponibilidad.
  double _progressedVolume(AiCoachMesocycle block, int weekIndex) {
    final ceiling = block.volumeCeilingKm;
    var volume = block.baselineVolumeKm;
    if (ceiling <= 0) return volume;

    final step = block.volumeStepPct.clamp(0.0, maxWeeklyStepPct);
    for (var week = 0; week < weekIndex; week++) {
      final headroom = ((ceiling - volume) / ceiling).clamp(0.0, 1.0);
      volume += volume * step * headroom;
    }
    return math.min(volume, ceiling);
  }

  /// Techo de volumen sostenible del atleta.
  ///
  /// Dos limites: lo que pide el objetivo (ajustado por nivel) y lo que permite
  /// su disponibilidad real. Manda el menor — de nada sirve un techo de maraton
  /// si solo puede correr 3 dias.
  ///
  /// Son defaults de practica de entrenamiento, no constantes derivadas.
  double volumeCeilingFor(AiCoachProfile? profile) {
    if (profile == null) return 40;

    final goalCeiling = switch (profile.goal) {
      AiCoachGoalType.returnToRunning => 30.0,
      AiCoachGoalType.race5k => 50.0,
      AiCoachGoalType.improvePace => 50.0,
      AiCoachGoalType.race10k => 60.0,
      AiCoachGoalType.improveEndurance => 60.0,
      AiCoachGoalType.raceHalfMarathon => 70.0,
      AiCoachGoalType.raceMarathon => 85.0,
    };

    final levelFactor = switch (profile.level) {
      AiCoachAthleteLevel.beginner => 0.5,
      AiCoachAthleteLevel.intermediate => 0.75,
      AiCoachAthleteLevel.advanced => 1.0,
    };

    final kmPerSession = switch (profile.level) {
      AiCoachAthleteLevel.beginner => 9.0,
      AiCoachAthleteLevel.intermediate => 15.0,
      AiCoachAthleteLevel.advanced => 22.0,
    };

    final sessions = profile.preferredWeeklySessions > 0
        ? profile.preferredWeeklySessions
        : 3;
    final availabilityCeiling = sessions * kmPerSession;

    return math.min(goalCeiling * levelFactor, availabilityCeiling);
  }

  // ---------------------------------------------------------------------------
  // Construccion del bloque
  // ---------------------------------------------------------------------------

  /// Crea el bloque que arranca en [weekStart].
  ///
  /// [previous] permite encadenar: el baseline del bloque nuevo sale del pico
  /// del anterior, nunca de su semana de descarga (produciria una caida
  /// escalonada del volumen bloque a bloque).
  AiCoachMesocycle buildBlock({
    required DateTime weekStart,
    required AiCoachProfile? profile,
    AiCoachWeeklyState? weeklyState,
    AiCoachMesocycle? previous,
    DateTime? now,
    String sourceModel = '',
  }) {
    final createdAt = now ?? DateTime.now();
    final level = profile?.level ?? AiCoachAthleteLevel.beginner;
    final ceiling = volumeCeilingFor(profile);
    final isRestart = _needsRestart(weeklyState);
    final weeksToRace = _weeksToRace(profile, weekStart);
    final phase = _phaseFor(
      weeksToRace: weeksToRace,
      sequenceIndex: previous == null ? 0 : previous.sequenceIndex + 1,
    );

    final pattern = _patternFor(
      phase: phase,
      level: level,
      isRestart: isRestart,
      weeksToRace: weeksToRace,
    );

    final baseline = resolveBaseline(
      profile: profile,
      weeklyState: weeklyState,
      previous: previous,
      ceiling: ceiling,
    );

    return AiCoachMesocycle(
      id: 'meso_${createdAt.millisecondsSinceEpoch}',
      startWeek: DateTime(weekStart.year, weekStart.month, weekStart.day),
      lengthWeeks: pattern.length,
      phase: phase,
      weekPattern: pattern,
      baselineVolumeKm: baseline,
      volumeCeilingKm: ceiling,
      volumeStepPct: _stepFor(level: level, isRestart: isRestart),
      deloadVolumePct: _deloadPctFor(level),
      focus: _defaultFocusFor(phase: phase, isRestart: isRestart),
      createdAt: createdAt,
      sequenceIndex: previous == null ? 0 : previous.sequenceIndex + 1,
      sourceModel: sourceModel,
    );
  }

  /// Baseline del bloque nuevo, por orden de preferencia:
  /// 1. pico del bloque anterior (encadena sin escalon),
  /// 2. volumen real de la ultima semana,
  /// 3. CTL * 7 como proxy,
  /// 4. default conservador por nivel para atletas sin historial.
  double resolveBaseline({
    required AiCoachProfile? profile,
    required AiCoachWeeklyState? weeklyState,
    required AiCoachMesocycle? previous,
    required double ceiling,
  }) {
    double? candidate;

    if (previous != null && previous.baselineVolumeKm > 0) {
      // Pico del bloque anterior: su ultima semana de carga.
      final peakIndex = _lastBuildIndex(previous);
      candidate = _progressedVolume(previous, peakIndex);
    } else if (weeklyState != null && weeklyState.weeklyKm > 0) {
      candidate = weeklyState.weeklyKm;
    } else if (weeklyState != null && weeklyState.ctl > 0) {
      candidate = weeklyState.ctl * 7;
    }

    final double resolved = candidate ??
        switch (profile?.level ?? AiCoachAthleteLevel.beginner) {
          AiCoachAthleteLevel.beginner => 12.0,
          AiCoachAthleteLevel.intermediate => 25.0,
          AiCoachAthleteLevel.advanced => 45.0,
        };

    return math.min(resolved, ceiling);
  }

  int _lastBuildIndex(AiCoachMesocycle block) {
    for (var i = block.weekPattern.length - 1; i >= 0; i--) {
      if (block.weekPattern[i] == AiCoachWeekType.build) return i;
    }
    return 0;
  }

  bool _needsRestart(AiCoachWeeklyState? state) {
    if (state == null) return false;
    return state.consecutiveMissedWeeks >= 2;
  }

  int? _weeksToRace(AiCoachProfile? profile, DateTime weekStart) {
    final target = profile?.targetDate;
    if (target == null) return null;
    final days = target.difference(weekStart).inDays;
    if (days < 0) return null;
    return days ~/ 7;
  }

  /// Con carrera, la fase sale de las semanas que faltan (mismo criterio que
  /// `_phaseForWeeksRemaining` del prompt builder).
  ///
  /// Sin carrera, los bloques rotan el enfasis. Este es el hueco que cierra el
  /// mesociclo: antes, sin `targetDate` el Coach no tenia fase ninguna.
  AiCoachBlockPhase _phaseFor({
    required int? weeksToRace,
    required int sequenceIndex,
  }) {
    if (weeksToRace != null) {
      if (weeksToRace <= 1) return AiCoachBlockPhase.race;
      if (weeksToRace <= 3) return AiCoachBlockPhase.taper;
      if (weeksToRace <= 8) return AiCoachBlockPhase.specific;
      return AiCoachBlockPhase.base;
    }
    // Rotacion sin carrera: base, base, especifico, base...
    return switch (sequenceIndex % 4) {
      2 => AiCoachBlockPhase.specific,
      _ => AiCoachBlockPhase.base,
    };
  }

  List<AiCoachWeekType> _patternFor({
    required AiCoachBlockPhase phase,
    required AiCoachAthleteLevel level,
    required bool isRestart,
    required int? weeksToRace,
  }) {
    if (phase == AiCoachBlockPhase.race) {
      return const [AiCoachWeekType.race];
    }
    if (phase == AiCoachBlockPhase.taper) {
      final weeks = (weeksToRace ?? 2).clamp(1, 3);
      return [
        for (var i = 0; i < weeks; i++) AiCoachWeekType.taper,
        AiCoachWeekType.race,
      ];
    }
    if (isRestart) {
      return const [
        AiCoachWeekType.restart,
        AiCoachWeekType.build,
        AiCoachWeekType.build,
        AiCoachWeekType.absorb,
      ];
    }
    if (level == AiCoachAthleteLevel.beginner) {
      // Bloque corto: el novato acumula dano por tiempo sostenido en carga,
      // no por fatiga aguda. Ver docs/AI_COACH_MESOCYCLE.md §4.2.
      return const [
        AiCoachWeekType.build,
        AiCoachWeekType.build,
        AiCoachWeekType.absorb,
      ];
    }
    return const [
      AiCoachWeekType.build,
      AiCoachWeekType.build,
      AiCoachWeekType.build,
      AiCoachWeekType.absorb,
    ];
  }

  /// Paso de progresion. El novato lleva paso reducido ademas de bloque corto:
  /// el bloque corto limita el tiempo en carga, el paso limita la velocidad de
  /// incremento — son dos causas distintas de lesion por sobrecarga.
  double _stepFor({
    required AiCoachAthleteLevel level,
    required bool isRestart,
  }) {
    if (isRestart) return 0.05;
    return switch (level) {
      AiCoachAthleteLevel.beginner => 0.05,
      AiCoachAthleteLevel.intermediate => 0.08,
      AiCoachAthleteLevel.advanced => 0.08,
    };
  }

  /// A volumenes bajos una descarga profunda no aporta recuperacion relevante
  /// y si rompe el ritmo, por eso el novato descarga menos.
  double _deloadPctFor(AiCoachAthleteLevel level) {
    return level == AiCoachAthleteLevel.beginner ? 0.70 : 0.60;
  }

  String _defaultFocusFor({
    required AiCoachBlockPhase phase,
    required bool isRestart,
  }) {
    if (isRestart) return 'Volver a la rutina sin prisa';
    return switch (phase) {
      AiCoachBlockPhase.base => 'Construyendo base aerobica',
      AiCoachBlockPhase.specific => 'Trabajo de umbral',
      AiCoachBlockPhase.taper => 'Afinando para la carrera',
      AiCoachBlockPhase.race => 'Semana de competicion',
    };
  }
}
