import 'package:running_laps/features/athlete/data/athlete_session_model.dart';
import 'package:running_laps/features/templates/data/target_config.dart';
import 'package:running_laps/features/templates/data/workout_block.dart';
import 'package:running_laps/features/templates/data/workout_segment.dart';
import 'package:running_laps/features/templates/data/workout_session.dart';

/// Convierte un [AthleteSession] al modelo [WorkoutSession] del editor.
/// Devuelve null si [session] es null.
WorkoutSession? mapAthleteSessionToWorkout(AthleteSession? session) {
  if (session == null) return null;

  final mappedBlocks = _mapBlocks(
    session.warmup,
    session.blocks,
    session.cooldown,
  );

  // WorkoutSession requiere al menos un bloque main — garantizamos el invariante.
  if (!mappedBlocks.any((b) => b.role == BlockRole.main)) {
    mappedBlocks.add(WorkoutBlock(
      role: BlockRole.main,
      repetitions: 1,
      segments: [
        WorkoutSegment(type: SegmentType.interval, durationSec: 60),
      ],
    ));
  }

  return WorkoutSession(
    id:            session.id,
    title:         _titleFromCategory(session.category),
    type:          _mapCategory(session.category),
    blocks:        mappedBlocks,
    scheduledDate: DateTime.tryParse(session.date),
    notes:         session.planningNotes,
    isTemplate:    false,
  );
}

// ── Categoría → WorkoutType ──────────────────────────────────────────────────

WorkoutType _mapCategory(String? category) {
  switch (category) {
    case 'regenerativo':
    case 'rodaje_base':
    case 'tempo':
      return WorkoutType.continuous;
    case 'fartlek':
      return WorkoutType.fartlek;
    case 'series_largas':
    case 'series_cortas':
    case 'series_mixtas':
      return WorkoutType.intervals;
    case 'series_cuestas':
      return WorkoutType.hills;
    case 'competicion':
    case 'test':
      return WorkoutType.competition;
    case 'gimnasio_fuerza':
      return WorkoutType.free;
    default:
      return WorkoutType.intervals;
  }
}

String _titleFromCategory(String? category) {
  switch (category) {
    case 'regenerativo':    return 'Regenerativo';
    case 'rodaje_base':     return 'Rodaje base';
    case 'tempo':           return 'Tempo';
    case 'fartlek':         return 'Fartlek';
    case 'series_largas':   return 'Series largas';
    case 'series_cortas':   return 'Series cortas';
    case 'series_cuestas':  return 'Series en cuestas';
    case 'series_mixtas':   return 'Series mixtas';
    case 'competicion':     return 'Competición';
    case 'test':            return 'Test';
    case 'gimnasio_fuerza': return 'Gimnasio / fuerza';
    default:                return 'Sesión planificada';
  }
}

// ── Bloques ──────────────────────────────────────────────────────────────────

List<WorkoutBlock> _mapBlocks(
  SessionWarmupCooldown? warmup,
  List<SessionBlock> blocks,
  SessionWarmupCooldown? cooldown,
) {
  final result = <WorkoutBlock>[];

  final warmupBlock = _mapWarmupCooldown(warmup, BlockRole.warmup);
  if (warmupBlock != null) result.add(warmupBlock);

  for (final block in blocks) {
    final wb = _mapSessionBlock(block);
    if (wb != null) result.add(wb);
  }

  final cooldownBlock = _mapWarmupCooldown(cooldown, BlockRole.cooldown);
  if (cooldownBlock != null) result.add(cooldownBlock);

  return result;
}

WorkoutBlock? _mapWarmupCooldown(SessionWarmupCooldown? wc, BlockRole role) {
  if (wc == null) return null;
  final durationSec = (wc.durationMinutes ?? 0) * 60;
  if (durationSec <= 0) return null;

  return WorkoutBlock(
    role: role,
    repetitions: 1,
    segments: [
      WorkoutSegment(
        type: SegmentType.interval,
        durationSec: durationSec,
        target: const TargetConfig(zone: HeartRateZone.z1),
      ),
    ],
  );
}

WorkoutBlock? _mapSessionBlock(SessionBlock block) {
  final segments = _mapSegments(block);
  if (segments.isEmpty) return null;

  return WorkoutBlock(
    role: BlockRole.main,
    repetitions: block.reps ?? 1,
    segments: segments,
  );
}

// ── Segmentos ────────────────────────────────────────────────────────────────

List<WorkoutSegment> _mapSegments(SessionBlock block) {
  final segments = <WorkoutSegment>[];

  // Segmento de esfuerzo — necesita durationSec o distanceM.
  final durationSec = block.durationMinutes != null
      ? block.durationMinutes! * 60
      : null;
  final distanceM = (block.distanceM != null && block.distanceM! > 0)
      ? block.distanceM
      : null;

  if (durationSec == null && distanceM == null) {
    // Sin métrica de distancia ni tiempo — no se puede crear un segmento válido.
    return segments;
  }

  final target = _buildTarget(block);

  segments.add(WorkoutSegment(
    type: SegmentType.interval,
    durationSec: durationSec,
    distanceM: distanceM,
    target: target,
  ));

  // Segmento de descanso (solo en bloques tipo series).
  if (block.restSeconds != null && block.restSeconds! > 0) {
    segments.add(WorkoutSegment(
      type: SegmentType.recovery,
      durationSec: block.restSeconds,
      recoveryType: RecoveryType.active,
    ));
  }

  return segments;
}

TargetConfig? _buildTarget(SessionBlock block) {
  // Pace: SessionBlock guarda los rangos como 4 ints separados (min/seg para mín y máx).
  // TargetConfig.paceMin = ritmo más rápido (menor seg/km); paceMax = más lento (mayor).
  final paceMin = _paceToSec(block.targetPaceMinMin, block.targetPaceMinSec);
  final paceMax = _paceToSec(block.targetPaceMaxMin, block.targetPaceMaxSec);

  // Garantizar invariante paceMin <= paceMax si ambos existen.
  final (safeMin, safeMax) = _safePaceRange(paceMin, paceMax);

  final zone = _mapZone(block.targetZone);
  final rpe  = _safeRpe(block.targetRpe);

  if (safeMin == null && safeMax == null && zone == null && rpe == null) {
    return null;
  }

  return TargetConfig(
    paceMinSecPerKm: safeMin,
    paceMaxSecPerKm: safeMax,
    zone: zone,
    rpe: rpe,
  );
}

// ── Helpers ──────────────────────────────────────────────────────────────────

int? _paceToSec(int? minutes, int? seconds) {
  if (minutes == null) return null;
  return minutes * 60 + (seconds ?? 0);
}

(int?, int?) _safePaceRange(int? paceMin, int? paceMax) {
  if (paceMin == null || paceMax == null) return (paceMin, paceMax);
  if (paceMin <= paceMax) return (paceMin, paceMax);
  // Invertidos — los intercambiamos en lugar de descartarlos.
  return (paceMax, paceMin);
}

HeartRateZone? _mapZone(int? zone) {
  switch (zone) {
    case 1: return HeartRateZone.z1;
    case 2: return HeartRateZone.z2;
    case 3: return HeartRateZone.z3;
    case 4: return HeartRateZone.z4;
    case 5: return HeartRateZone.z5;
    default: return null;
  }
}

// TargetConfig.rpe es int y debe estar en 1–10.
int? _safeRpe(double? rpe) {
  if (rpe == null) return null;
  final rounded = rpe.round();
  return (rounded >= 1 && rounded <= 10) ? rounded : null;
}
