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
  bool _serieInProgress = false;
  bool _isLaunched = false;

  @override
  void initState() {
    super.initState();
    _controller = WorkoutExecutionController(widget.session);
    // Lanzar la primera serie tras el primer frame
    WidgetsBinding.instance.addPostFrameCallback((_) => _launchCurrentSerie());
  }

  @override
  void dispose() {
    _isLaunched = false;
    _controller.dispose();
    super.dispose();
  }

  // ──────────────────────────────────────────────────────────────
  // Lanzar TrainingSessionView para la rep actual
  // ──────────────────────────────────────────────────────────────

  Future<void> _launchCurrentSerie() async {
    if (!mounted || _serieInProgress) return;
    final state = _controller.value;
    if (state.phase == ExecutionPhase.transition ||
        state.phase == ExecutionPhase.done) {
      return;
    }

    _serieInProgress = true;
    final params = _controller.paramsForCurrentRep();

    final result = await Navigator.push<Serie>(
      context,
      AppRoute(
        page: TrainingSessionView(
          distancia: params['distancia'] as String,
          descanso: params['descanso'] as String,
          gpsActivo: widget.gpsActivo,
          currentSeries: params['currentSeries'] as int,
          totalSeries: params['totalSeries'] as int,
          targetPaceMinutes: params['targetPaceMinutes'] as int?,
          targetPaceSeconds: params['targetPaceSeconds'] as int?,
          targetPaceMaxMinutes: params['targetPaceMaxMinutes'] as int?,
          targetPaceMaxSeconds: params['targetPaceMaxSeconds'] as int?,
          targetRpe: (params['targetRpe'] as int?)?.toDouble(),
          targetZone: params['targetZone'] as int?,
          fcMax: widget.fcMax?.round(),
        ),
      ),
    );

    _serieInProgress = false;
    if (!mounted) return;

    if (result != null) {
      _controller.recordSerie(result);
      final nextPhase = _controller.value.phase;
      if (nextPhase != ExecutionPhase.transition &&
          nextPhase != ExecutionPhase.done) {
        _launchCurrentSerie();
      }
    } else {
      _controller.finishEarly();
    }
  }

  void _onSerieComplete(Serie serie) {
    _controller.recordSerie(serie);
    final nextPhase = _controller.value.phase;
    if (nextPhase != ExecutionPhase.transition &&
        nextPhase != ExecutionPhase.done) {
      _isLaunched = false;
      _launchCurrentSerie();
    }
  }

  // ──────────────────────────────────────────────────────────────
  // Build
  // ──────────────────────────────────────────────────────────────

  Widget _buildExecutingPhase(
      BuildContext context, WorkoutExecutionState state) {
    final params = _controller.paramsForCurrentRep();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_isLaunched) {
        _isLaunched = true;
        Navigator.of(context).push(
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
            ),
          ),
        ).then((result) {
          if (result is Serie && mounted) {
            _onSerieComplete(result);
          }
        });
      }
    });

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
                _isLaunched = false;
                _controller.advanceToNextBlock();
                WidgetsBinding.instance
                    .addPostFrameCallback((_) => _launchCurrentSerie());
              },
              onFinishEarly: () => _controller.finishEarly(),
            );

          case ExecutionPhase.done:
            return _DoneLoader(
              state: state,
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
  final AthleteSession? athleteSession;
  final VoidCallback? onCompleted;

  const _DoneLoader({
    required this.state,
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

  Entrenamiento _buildEntrenamiento(WorkoutExecutionState state) {
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
