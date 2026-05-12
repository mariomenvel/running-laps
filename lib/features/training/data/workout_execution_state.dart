import 'package:flutter/foundation.dart';

import '../../templates/data/workout_block.dart';
import '../../templates/data/workout_session.dart';
import 'serie.dart';

enum ExecutionPhase {
  warmup,
  main,
  cooldown,
  transition,
  done,
}

@immutable
class BlockExecutionState {
  final WorkoutBlock block;
  final int totalReps;
  final int completedReps;
  final List<Serie> series;

  const BlockExecutionState({
    required this.block,
    required this.totalReps,
    required this.completedReps,
    this.series = const [],
  });

  bool get isComplete => completedReps >= totalReps;
  double get progress => totalReps > 0 ? completedReps / totalReps : 0;

  BlockExecutionState copyWith({
    int? completedReps,
    List<Serie>? series,
  }) {
    return BlockExecutionState(
      block: block,
      totalReps: totalReps,
      completedReps: completedReps ?? this.completedReps,
      series: series ?? this.series,
    );
  }
}

@immutable
class WorkoutExecutionState {
  final WorkoutSession session;
  final List<BlockExecutionState> blocks;
  final int currentBlockIndex;
  final ExecutionPhase phase;
  final DateTime startedAt;
  final DateTime? finishedAt;

  const WorkoutExecutionState({
    required this.session,
    required this.blocks,
    required this.currentBlockIndex,
    required this.phase,
    required this.startedAt,
    this.finishedAt,
  });

  BlockExecutionState get currentBlock => blocks[currentBlockIndex];

  bool get isLastBlock => currentBlockIndex >= blocks.length - 1;

  BlockExecutionState? get nextBlock =>
      !isLastBlock ? blocks[currentBlockIndex + 1] : null;

  List<Serie> get allSeries => blocks.expand((b) => b.series).toList();

  int get totalCompletedReps =>
      blocks.fold(0, (sum, b) => sum + b.completedReps);

  WorkoutExecutionState copyWith({
    List<BlockExecutionState>? blocks,
    int? currentBlockIndex,
    ExecutionPhase? phase,
    DateTime? finishedAt,
  }) {
    return WorkoutExecutionState(
      session: session,
      blocks: blocks ?? this.blocks,
      currentBlockIndex: currentBlockIndex ?? this.currentBlockIndex,
      phase: phase ?? this.phase,
      startedAt: startedAt,
      finishedAt: finishedAt ?? this.finishedAt,
    );
  }

  factory WorkoutExecutionState.fromSession(WorkoutSession session) {
    return WorkoutExecutionState(
      session: session,
      blocks: session.blocks
          .map((b) => BlockExecutionState(
                block: b,
                totalReps: b.repetitions,
                completedReps: 0,
              ))
          .toList(),
      currentBlockIndex: 0,
      phase: _initialPhase(session.blocks.first.role),
      startedAt: DateTime.now(),
    );
  }

  static ExecutionPhase _initialPhase(BlockRole role) {
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
