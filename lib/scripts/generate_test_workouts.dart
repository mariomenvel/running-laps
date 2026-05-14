import 'package:flutter/foundation.dart';
import 'package:running_laps/features/templates/data/target_config.dart';
import 'package:running_laps/features/templates/data/workout_block.dart';
import 'package:running_laps/features/templates/data/workout_segment.dart';
import 'package:running_laps/features/templates/data/workout_session.dart';
import 'package:running_laps/features/templates/data/templates_repository.dart';

/// Genera 6 plantillas de prueba (una por WorkoutType) y las guarda en
/// users/{uid}/templates/. Devuelve la lista de IDs creados.
///
/// Uso temporal — llamar desde un botón en HomeScreen o desde main.dart:
///   await generateTestWorkouts(FirebaseAuth.instance.currentUser!.uid);
Future<List<String>> generateTestWorkouts(String uid) async {
  final repo = TrainingTemplatesRepository();
  final sessions = _buildSessions();
  final ids = <String>[];

  for (final session in sessions) {
    await repo.saveWorkoutSession(session);
    ids.add(session.id);
    debugPrint('[generateTestWorkouts] saved: ${session.title} → ${session.id}');
  }

  debugPrint('[generateTestWorkouts] done — ${ids.length} plantillas creadas: $ids');
  return ids;
}

List<WorkoutSession> _buildSessions() {
  return [
    _buildEasyRun(),
    _buildIntervals(),
    _buildTempo(),
    _buildLongRun(),
    _buildFartlek(),
    _buildFree(),
  ];
}

// ── 1. Rodaje fácil — continuous, 10 km en Z2 ────────────────────

WorkoutSession _buildEasyRun() {
  return WorkoutSession(
    title: 'Rodaje fácil 10 km',
    description: 'Rodaje base a ritmo cómodo en Z2',
    type: WorkoutType.continuous,
    isTemplate: true,
    blocks: [
      WorkoutBlock(
        role: BlockRole.main,
        repetitions: 1,
        segments: [
          WorkoutSegment(
            type: SegmentType.interval,
            distanceM: 10000,
            target: const TargetConfig(
              zone: HeartRateZone.z2,
              paceMinSecPerKm: 300, // 5:00 /km
              paceMaxSecPerKm: 330, // 5:30 /km
            ),
          ),
        ],
      ),
    ],
  );
}

// ── 2. Series 5×1000 m — intervals ───────────────────────────────

WorkoutSession _buildIntervals() {
  return WorkoutSession(
    title: 'Series 5×1000 m',
    description: '5 repeticiones de 1000 m a ritmo de 5K con 90 s de recuperación activa',
    type: WorkoutType.intervals,
    isTemplate: true,
    blocks: [
      WorkoutBlock(
        role: BlockRole.warmup,
        repetitions: 1,
        segments: [
          WorkoutSegment(
            type: SegmentType.interval,
            durationSec: 900, // 15 min
            target: const TargetConfig(zone: HeartRateZone.z1),
          ),
        ],
      ),
      WorkoutBlock(
        role: BlockRole.main,
        repetitions: 5,
        segments: [
          WorkoutSegment(
            type: SegmentType.interval,
            distanceM: 1000,
            target: const TargetConfig(
              paceMinSecPerKm: 240, // 4:00 /km
              paceMaxSecPerKm: 255, // 4:15 /km
              zone: HeartRateZone.z4,
              rpe: 8,
            ),
          ),
          WorkoutSegment(
            type: SegmentType.recovery,
            durationSec: 90,
            recoveryType: RecoveryType.active,
            target: const TargetConfig(zone: HeartRateZone.z1),
          ),
        ],
      ),
      WorkoutBlock(
        role: BlockRole.cooldown,
        repetitions: 1,
        segments: [
          WorkoutSegment(
            type: SegmentType.interval,
            durationSec: 600, // 10 min
            target: const TargetConfig(zone: HeartRateZone.z1),
          ),
        ],
      ),
    ],
  );
}

// ── 3. Tempo 5 km — continuous a ritmo de umbral ─────────────────

WorkoutSession _buildTempo() {
  return WorkoutSession(
    title: 'Tempo 5 km',
    description: '5 km continuos a ritmo de umbral anaeróbico (Z3–Z4)',
    type: WorkoutType.continuous,
    isTemplate: true,
    blocks: [
      WorkoutBlock(
        role: BlockRole.warmup,
        repetitions: 1,
        segments: [
          WorkoutSegment(
            type: SegmentType.interval,
            durationSec: 600,
            target: const TargetConfig(zone: HeartRateZone.z1),
          ),
        ],
      ),
      WorkoutBlock(
        role: BlockRole.main,
        repetitions: 1,
        segments: [
          WorkoutSegment(
            type: SegmentType.interval,
            distanceM: 5000,
            target: const TargetConfig(
              paceMinSecPerKm: 255, // 4:15 /km
              paceMaxSecPerKm: 270, // 4:30 /km
              zone: HeartRateZone.z4,
              rpe: 7,
            ),
          ),
        ],
      ),
      WorkoutBlock(
        role: BlockRole.cooldown,
        repetitions: 1,
        segments: [
          WorkoutSegment(
            type: SegmentType.interval,
            durationSec: 600,
            target: const TargetConfig(zone: HeartRateZone.z1),
          ),
        ],
      ),
    ],
  );
}

// ── 4. Largo 15 km — continuous en Z2 ────────────────────────────

WorkoutSession _buildLongRun() {
  return WorkoutSession(
    title: 'Largo 15 km',
    description: 'Tirada larga de base aeróbica en Z2 a ritmo cómodo',
    type: WorkoutType.continuous,
    isTemplate: true,
    blocks: [
      WorkoutBlock(
        role: BlockRole.main,
        repetitions: 1,
        segments: [
          WorkoutSegment(
            type: SegmentType.interval,
            distanceM: 15000,
            target: const TargetConfig(
              zone: HeartRateZone.z2,
              paceMinSecPerKm: 315, // 5:15 /km
              paceMaxSecPerKm: 345, // 5:45 /km
            ),
          ),
        ],
      ),
    ],
  );
}

// ── 5. Fartlek piramidal — fartlek, 8 segmentos alternados ────────

WorkoutSession _buildFartlek() {
  // Pirámide: 4'-3'-2'-1' rápido, con recuperaciones decrecientes
  final effortDurations = [240, 180, 120, 60, 120, 180, 240, 300];
  final recoveryDurations = [120, 90, 60, 60, 60, 90, 120, 0];

  final segments = <WorkoutSegment>[];
  for (int i = 0; i < effortDurations.length; i++) {
    segments.add(WorkoutSegment(
      type: SegmentType.interval,
      durationSec: effortDurations[i],
      target: TargetConfig(
        rpe: i < 4 ? 7 + i ~/ 2 : 9 - (i - 4) ~/ 2,
        zone: HeartRateZone.z4,
      ),
    ));
    if (recoveryDurations[i] > 0) {
      segments.add(WorkoutSegment(
        type: SegmentType.recovery,
        durationSec: recoveryDurations[i],
        recoveryType: RecoveryType.active,
        target: const TargetConfig(zone: HeartRateZone.z1),
      ));
    }
  }

  return WorkoutSession(
    title: 'Fartlek piramidal',
    description: 'Pirámide de esfuerzos 4-3-2-1-2-3-4-5 min con recuperación activa',
    type: WorkoutType.fartlek,
    isTemplate: true,
    blocks: [
      WorkoutBlock(
        role: BlockRole.warmup,
        repetitions: 1,
        segments: [
          WorkoutSegment(
            type: SegmentType.interval,
            durationSec: 600,
            target: const TargetConfig(zone: HeartRateZone.z1),
          ),
        ],
      ),
      WorkoutBlock(
        role: BlockRole.main,
        repetitions: 1,
        segments: segments,
      ),
      WorkoutBlock(
        role: BlockRole.cooldown,
        repetitions: 1,
        segments: [
          WorkoutSegment(
            type: SegmentType.interval,
            durationSec: 600,
            target: const TargetConfig(zone: HeartRateZone.z1),
          ),
        ],
      ),
    ],
  );
}

// ── 6. Libre — free, sin targets ─────────────────────────────────

WorkoutSession _buildFree() {
  return WorkoutSession(
    title: 'Carrera libre',
    description: 'Sin estructura — corre por sensaciones. Solo GPS + RPE al acabar',
    type: WorkoutType.free,
    isTemplate: true,
    blocks: [
      WorkoutBlock(
        role: BlockRole.main,
        repetitions: 1,
        segments: [
          WorkoutSegment(
            type: SegmentType.interval,
            durationSec: 3600, // 1 h como máximo, el usuario para cuando quiera
          ),
        ],
      ),
    ],
  );
}
