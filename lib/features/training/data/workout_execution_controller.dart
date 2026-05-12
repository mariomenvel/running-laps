import 'package:flutter/foundation.dart';

import '../../templates/data/workout_block.dart';
import '../../templates/data/workout_segment.dart';
import '../../templates/data/workout_session.dart';
import 'serie.dart';
import 'workout_execution_state.dart';

class WorkoutExecutionController
    extends ValueNotifier<WorkoutExecutionState> {
  WorkoutExecutionController(WorkoutSession session)
      : super(WorkoutExecutionState.fromSession(session));

  void recordSerie(Serie serie) {
    final current = value.currentBlock;
    final updatedBlock = current.copyWith(
      completedReps: current.completedReps + 1,
      series: [...current.series, serie],
    );
    final updatedBlocks = List<BlockExecutionState>.from(value.blocks);
    updatedBlocks[value.currentBlockIndex] = updatedBlock;

    if (updatedBlock.isComplete) {
      if (value.isLastBlock) {
        value = value.copyWith(
          blocks: updatedBlocks,
          phase: ExecutionPhase.done,
          finishedAt: DateTime.now(),
        );
      } else {
        value = value.copyWith(
          blocks: updatedBlocks,
          phase: ExecutionPhase.transition,
        );
      }
    } else {
      value = value.copyWith(blocks: updatedBlocks);
    }
  }

  void advanceToNextBlock() {
    final nextIndex = value.currentBlockIndex + 1;
    final nextBlock = value.blocks[nextIndex];
    value = value.copyWith(
      currentBlockIndex: nextIndex,
      phase: _phaseForRole(nextBlock.block.role),
    );
  }

  void finishEarly() {
    value = value.copyWith(
      phase: ExecutionPhase.done,
      finishedAt: DateTime.now(),
    );
  }

  Map<String, dynamic> paramsForCurrentRep() {
    final block = value.currentBlock.block;
    final seg = block.segments
        .where((s) => s.type == SegmentType.interval)
        .firstOrNull;
    final recovery = block.segments
        .where((s) => s.type == SegmentType.recovery)
        .firstOrNull;

    return {
      'distancia': seg?.distanceM?.toString() ?? 'Libre',
      'descanso': recovery?.durationSec?.toString() ?? '0',
      'targetPaceMinutes': seg?.target?.paceMinSecPerKm != null
          ? seg!.target!.paceMinSecPerKm! ~/ 60
          : null,
      'targetPaceSeconds': seg?.target?.paceMinSecPerKm != null
          ? seg!.target!.paceMinSecPerKm! % 60
          : null,
      'targetPaceMaxMinutes': seg?.target?.paceMaxSecPerKm != null
          ? seg!.target!.paceMaxSecPerKm! ~/ 60
          : null,
      'targetPaceMaxSeconds': seg?.target?.paceMaxSecPerKm != null
          ? seg!.target!.paceMaxSecPerKm! % 60
          : null,
      'targetRpe': seg?.target?.rpe,
      'targetZone': seg?.target?.zone?.index != null
          ? seg!.target!.zone!.index + 1
          : null,
      'currentSeries': value.currentBlock.completedReps + 1,
      'totalSeries': value.currentBlock.totalReps,
    };
  }

  ExecutionPhase _phaseForRole(BlockRole role) {
    switch (role) {
      case BlockRole.warmup:
        return ExecutionPhase.warmup;
      case BlockRole.main:
        return ExecutionPhase.main;
      case BlockRole.cooldown:
        return ExecutionPhase.cooldown;
      case BlockRole.custom:
        return ExecutionPhase.main;
    }
  }
}
