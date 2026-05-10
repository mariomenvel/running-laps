import 'package:flutter/material.dart' show TimeOfDay;
import 'package:uuid/uuid.dart';

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

// ═════════════════════════════════════════════════════════════════════════════
// Mapeador inverso: WorkoutSession → AthleteSession
// ═════════════════════════════════════════════════════════════════════════════

/// Convierte un [WorkoutSession] del editor al modelo [AthleteSession]
/// que persiste el calendario. Requiere el [uid] del usuario autenticado.
AthleteSession mapWorkoutSessionToAthlete(
  WorkoutSession session, {
  required String uid,
}) {
  final now = DateTime.now();

  return AthleteSession(
    id:            session.id,
    uid:           uid,
    date:          _formatDate(session.scheduledDate ?? now),
    time:          _formatTime(session.scheduledTime),
    category:      _workoutTypeToCategory(session.type),
    status:        AthleteSessionStatus.planned,
    warmup:        _extractWarmupCooldown(session.blocks, BlockRole.warmup),
    blocks:        _extractSessionBlocks(session.blocks),
    cooldown:      _extractWarmupCooldown(session.blocks, BlockRole.cooldown),
    planningNotes: session.notes,
    createdAt:     now,
    updatedAt:     now,
  );
}

// ── WorkoutType → category ────────────────────────────────────────────────────

String _workoutTypeToCategory(WorkoutType type) {
  switch (type) {
    case WorkoutType.continuous:  return 'rodaje_base';
    case WorkoutType.intervals:   return 'series_largas';
    case WorkoutType.fartlek:     return 'fartlek';
    case WorkoutType.hills:       return 'series_cuestas';
    case WorkoutType.competition: return 'competicion';
    case WorkoutType.free:        return 'rodaje_base';
  }
}

// ── Fecha y hora ──────────────────────────────────────────────────────────────

String _formatDate(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

String? _formatTime(TimeOfDay? t) {
  if (t == null) return null;
  return '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
}

// ── Warmup / Cooldown ─────────────────────────────────────────────────────────

SessionWarmupCooldown? _extractWarmupCooldown(
  List<WorkoutBlock> blocks,
  BlockRole role,
) {
  final block = blocks.where((b) => b.role == role).firstOrNull;
  if (block == null) return null;

  final intervalSeg =
      block.segments.where((s) => s.type == SegmentType.interval).firstOrNull;
  if (intervalSeg == null) return null;

  final durationMin = intervalSeg.durationSec != null
      ? intervalSeg.durationSec! ~/ 60
      : null;

  if (durationMin == null || durationMin <= 0) return null;

  return SessionWarmupCooldown(durationMinutes: durationMin);
}

// ── Bloques principales → SessionBlock ───────────────────────────────────────

List<SessionBlock> _extractSessionBlocks(List<WorkoutBlock> blocks) {
  final mainBlocks =
      blocks.where((b) => b.role == BlockRole.main || b.role == BlockRole.custom);

  return mainBlocks.toList().asMap().entries.map((entry) {
    final i = entry.key;
    final block = entry.value;
    return _workoutBlockToSessionBlock(block, order: i);
  }).toList();
}

SessionBlock _workoutBlockToSessionBlock(WorkoutBlock block, {required int order}) {
  final intervalSeg =
      block.segments.where((s) => s.type == SegmentType.interval).firstOrNull;
  final recoverySeg =
      block.segments.where((s) => s.type == SegmentType.recovery).firstOrNull;

  final distanceM = intervalSeg?.distanceM;
  final durationMin = intervalSeg?.durationSec != null
      ? intervalSeg!.durationSec! ~/ 60
      : null;

  final blockType = _inferBlockType(block.repetitions, distanceM, durationMin);

  final target = intervalSeg?.target;
  final (paceMinMin, paceMinSec) = _secToParts(target?.paceMinSecPerKm);
  final (paceMaxMin, paceMaxSec) = _secToParts(target?.paceMaxSecPerKm);

  return SessionBlock(
    id:               const Uuid().v4(),
    order:            order,
    type:             blockType,
    reps:             block.repetitions > 1 ? block.repetitions : null,
    distanceM:        distanceM,
    durationMinutes:  durationMin,
    restSeconds:      recoverySeg?.durationSec,
    targetPaceMinMin: paceMinMin,
    targetPaceMinSec: paceMinSec,
    targetPaceMaxMin: paceMaxMin,
    targetPaceMaxSec: paceMaxSec,
    targetZone:       _zoneToInt(target?.zone),
    targetRpe:        target?.rpe?.toDouble(),
  );
}

SessionBlockType _inferBlockType(int reps, int? distanceM, int? durationMin) {
  if (distanceM != null && reps > 1) return SessionBlockType.series;
  if (distanceM != null)             return SessionBlockType.continuousDistance;
  return SessionBlockType.continuousTime;
}

// ── Helpers ───────────────────────────────────────────────────────────────────

/// Descompone segundos/km en (minutos, segundos).
(int?, int?) _secToParts(int? totalSec) {
  if (totalSec == null) return (null, null);
  return (totalSec ~/ 60, totalSec % 60);
}

int? _zoneToInt(HeartRateZone? zone) {
  if (zone == null) return null;
  return zone.index + 1; // z1=0 → 1, z2=1 → 2, …, z5=4 → 5
}
