import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../../core/utils/app_transitions.dart';
import '../../athlete/data/athlete_session_model.dart';
import '../../athlete/data/athlete_session_repository.dart';
import '../../templates/data/workout_block.dart';
import '../../templates/data/workout_segment.dart';
import '../../templates/data/workout_session.dart';
import '../data/entrenamiento.dart';
import '../data/serie.dart';
import '../data/workout_execution_controller.dart';
import '../data/workout_execution_state.dart';
import 'block_transition_screen.dart';
import 'training_session_view.dart';
import 'training_summary_screen.dart';

class WorkoutExecutionScreen extends StatefulWidget {
  final WorkoutSession session;
  final AthleteSession? athleteSession;
  final VoidCallback? onCompleted;
  final bool gpsActivo;
  final double? fcMax;

  const WorkoutExecutionScreen({
    super.key,
    required this.session,
    this.athleteSession,
    this.onCompleted,
    this.gpsActivo = true,
    this.fcMax,
  });

  @override
  State<WorkoutExecutionScreen> createState() =>
      _WorkoutExecutionScreenState();
}

class _WorkoutExecutionScreenState extends State<WorkoutExecutionScreen> {
  late WorkoutExecutionController _controller;

  @override
  void initState() {
    super.initState();
    _controller = WorkoutExecutionController(widget.session);
    // Lanzar la primera serie tras el primer frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _launchCurrentRep();
    });
    // Escucha cambios de fase para lanzar siguiente rep
    _controller.addListener(_onPhaseChanged);
  }

  @override
  void dispose() {
    _controller.removeListener(_onPhaseChanged);
    _controller.dispose();
    super.dispose();
  }

  void _onPhaseChanged() {
    final phase = _controller.value.phase;
    if (phase == ExecutionPhase.warmup ||
        phase == ExecutionPhase.main ||
        phase == ExecutionPhase.cooldown) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _launchCurrentRep();
      });
    }
  }

  Future<void> _launchCurrentRep() async {
    if (!mounted) return;
    final params = _controller.paramsForCurrentRep();

    final currentSegment = _controller.value.currentBlock?.block.segments
        .where((s) => s.type == SegmentType.interval)
        .firstOrNull;
    final alarmIntervalMs = currentSegment?.alerts?.enabled == true
        ? currentSegment!.alerts!.toAlarmIntervalMs()
        : null;

    final result = await Navigator.of(context).push<Serie>(
      AppRoute(
        page: TrainingSessionView(
          distancia: params['distancia'],
          descanso: params['descanso'],
          gpsActivo: widget.gpsActivo,
          currentSeries: params['currentSeries'],
          totalSeries: params['totalSeries'],
          targetPaceMinutes: params['targetPaceMinutes'],
          targetPaceSeconds: params['targetPaceSeconds'],
          targetPaceMaxMinutes: params['targetPaceMaxMinutes'],
          targetPaceMaxSeconds: params['targetPaceMaxSeconds'],
          targetRpe: params['targetRpe'],
          targetZone: params['targetZone'],
          fcMax: widget.fcMax?.round(),
          alarmIntervalMs: alarmIntervalMs,
        ),
      ),
    );
    if (result is Serie && mounted) {
      _onSerieComplete(result);
    }
  }


  void _onSerieComplete(Serie serie) {
    debugPrint('[Execution] recordSerie: distancia=${serie.distanciaM} rpe=${serie.rpe}');
    _controller.recordSerie(serie);
    debugPrint('[Execution] after record, totalCompletedReps=${_controller.value.totalCompletedReps}');
  }

  // ──────────────────────────────────────────────────────────────
  // Build
  // ──────────────────────────────────────────────────────────────

  Widget _buildExecutingPhase(
      BuildContext context, WorkoutExecutionState state) {
    return const Scaffold(
      body: Center(
        child: Text('Ejecutando entrenamiento...'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<WorkoutExecutionState>(
      valueListenable: _controller,
      builder: (context, state, _) {
        switch (state.phase) {
          case ExecutionPhase.warmup:
          case ExecutionPhase.main:
          case ExecutionPhase.cooldown:
            return _buildExecutingPhase(context, state);

          case ExecutionPhase.transition:
            return BlockTransitionScreen(
              completedBlock: state.currentBlock,
              nextBlock: state.nextBlock!,
              onContinue: () {
                _controller.advanceToNextBlock();
              },
              onFinishEarly: () => _controller.finishEarly(),
            );

          case ExecutionPhase.done:
            return _DoneLoader(
              state: state,
              session: widget.session,
              athleteSession: widget.athleteSession,
              onCompleted: widget.onCompleted,
            );
        }
      },
    );
  }
}

// ──────────────────────────────────────────────────────────────
// _DoneLoader: convierte el estado y navega al summary
// ──────────────────────────────────────────────────────────────

class _DoneLoader extends StatefulWidget {
  final WorkoutExecutionState state;
  final WorkoutSession session;
  final AthleteSession? athleteSession;
  final VoidCallback? onCompleted;

  const _DoneLoader({
    required this.state,
    required this.session,
    required this.athleteSession,
    required this.onCompleted,
  });

  @override
  State<_DoneLoader> createState() => _DoneLoaderState();
}

class _DoneLoaderState extends State<_DoneLoader> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _goToSummary());
  }

  Future<void> _goToSummary() async {
    if (!mounted) return;
    final entrenamiento = _buildEntrenamiento(widget.state);
    await Navigator.of(context).pushReplacement(
      AppRoute(
        page: TrainingSummaryScreen(entrenamiento: entrenamiento),
      ),
    );
    if (!mounted) return;
    await _markAthleteSessionCompleted(entrenamiento.id ?? '');
    widget.onCompleted?.call();
  }

  Future<void> _markAthleteSessionCompleted(String trainingId) async {
    final session = widget.athleteSession;
    if (session == null) return;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      await AthleteSessionRepository().markAsCompleted(
        uid: uid,
        sessionId: session.id,
        trainingId: trainingId,
      );
    } catch (e) {
      debugPrint('[WorkoutExecution] markAsCompleted error: $e');
    }
  }

  Map<String, dynamic> _buildPlannedComparison(WorkoutSession session) {
    return {
      'plannedTitle': session.title,
      'blocks': session.blocks.map((block) => {
        'role': block.role.name,
        'plannedReps': block.repetitions,
        'segments': block.segments
            .where((s) => s.type == SegmentType.interval)
            .map((seg) => {
              'plannedDistanceM': seg.distanceM,
              'plannedDurationSec': seg.durationSec,
              'target': {
                'paceMinSecPerKm': seg.target?.paceMinSecPerKm,
                'paceMaxSecPerKm': seg.target?.paceMaxSecPerKm,
                'rpe': seg.target?.rpe,
                'zone': seg.target?.zone?.index != null
                    ? seg.target!.zone!.index + 1
                    : null,
              },
            })
            .toList(),
      }).toList(),
    };
  }

  Entrenamiento _buildEntrenamiento(WorkoutExecutionState state) {
    debugPrint('[Execution] state.blocks.length=${state.blocks.length}');
    for (final b in state.blocks) {
      debugPrint('[Execution] block role=${b.block.role} completedReps=${b.completedReps} series.length=${b.series.length}');
    }
    debugPrint('[Execution] state.allSeries.length=${state.allSeries.length}');
    final allSeries = state.allSeries;
    final gpsUsed = allSeries.any((s) => s.usedGps == true);
    final fcMediaValues =
        allSeries.where((s) => s.fcMedia != null).map((s) => s.fcMedia!).toList();
    final fcMediaSesion = fcMediaValues.isEmpty
        ? null
        : fcMediaValues.reduce((a, b) => a + b) / fcMediaValues.length;

    return Entrenamiento(
      id: const Uuid().v4(),
      titulo: state.session.title,
      fecha: state.startedAt,
      gps: gpsUsed,
      series: allSeries,
      isManual: !gpsUsed,
      fcMediaSesion: fcMediaSesion,
      notas: '',
      tags: _tagsFromSession(state.session),
      plannedComparison: _buildPlannedComparison(widget.session),
    );
  }

  List<String> _tagsFromSession(WorkoutSession session) {
    final tags = <String>{};
    for (final block in session.blocks) {
      switch (block.role) {
        case BlockRole.warmup:
          tags.add('calentamiento');
        case BlockRole.cooldown:
          tags.add('vuelta');
        case BlockRole.main:
        case BlockRole.custom:
          final hasRecovery =
              block.segments.any((s) => s.type == SegmentType.recovery);
          tags.add(hasRecovery ? 'series' : 'rodaje');
      }
    }
    return tags.toList();
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}
