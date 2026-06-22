import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../../core/services/heart_rate_service.dart';
import '../../../core/services/ios_live_activity_service.dart';
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
import 'session_screens/rest/rest_screen.dart';
import 'training_session_view.dart';
import 'training_summary_screen.dart';

class WorkoutExecutionScreen extends StatefulWidget {
  final WorkoutSession session;
  final WorkoutSession? originalSession;
  final AthleteSession? athleteSession;
  final VoidCallback? onCompleted;
  final bool gpsActivo;
  final double? fcMax;

  const WorkoutExecutionScreen({
    super.key,
    required this.session,
    this.originalSession,
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
  bool _launchInFlight = false;

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
    if (_launchInFlight) return;
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
    if (_launchInFlight) return;
    if (!mounted) return;
    _launchInFlight = true;
    try {
    final params = _controller.paramsForCurrentRep();

    final block = _controller.value.currentBlock.block;
    final currentSegment = block.segments
        .where((s) => s.type == SegmentType.interval)
        .firstOrNull;
    final restSegment = block.segments
        .where((s) => s.type == SegmentType.recovery)
        .firstOrNull;
    final hasRest = restSegment?.durationSec != null &&
                    restSegment!.durationSec! > 0;

    final completedReps = _controller.value.currentBlock.completedReps;
    final totalReps = _controller.value.currentBlock.totalReps;
    final isLastRep = completedReps + 1 >= totalReps;

    final alarmIntervalMs = currentSegment?.alerts?.enabled == true
        ? currentSegment!.alerts!.toAlarmIntervalMs()
        : null;

    debugPrint('[Launch] targetPaceMinutes=${params['targetPaceMinutes']}');
    debugPrint('[Launch] targetPaceSeconds=${params['targetPaceSeconds']}');
    debugPrint('[Launch] targetPaceMaxMinutes=${params['targetPaceMaxMinutes']}');
    debugPrint('[Launch] targetRpe=${params['targetRpe']}');
    debugPrint('[Launch] targetZone=${params['targetZone']}');
    debugPrint('[Rest] restSegment=$restSegment');
    debugPrint('[Rest] durationSec=${restSegment?.durationSec}');
    debugPrint('[Rest] hasRest=$hasRest');
    debugPrint('[Rest] completedReps=$completedReps totalReps=$totalReps');
    debugPrint('[Rest] isLastRep=$isLastRep');

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
          session: widget.session,
          currentBlock: _controller.value.currentBlock.block,
          currentSegment: currentSegment,
        ),
      ),
    );
    if (result != null && mounted) {
      _onSerieComplete(result);
      debugPrint('[Rest] tras recordSerie, intentando rest');
      debugPrint('[Rest] mounted=$mounted hasRest=$hasRest isLastRep=$isLastRep');

      if (!isLastRep && hasRest && mounted) {
        await _launchRestScreen(
          restDurationSec: restSegment!.durationSec!,
          nextRepNumber: _controller.value.currentBlock.completedReps + 1,
          totalReps: totalReps,
          completedSerie: result,
          targetPaceMinSec: currentSegment?.target?.paceMinSecPerKm,
          targetPaceMaxSec: currentSegment?.target?.paceMaxSecPerKm,
        );

        if (mounted) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _launchCurrentRep();
          });
        }
      }
    }
    } finally {
      _launchInFlight = false;
    }
  }

  Future<void> _launchRestScreen({
    required int restDurationSec,
    required int nextRepNumber,
    required int totalReps,
    Serie? completedSerie,
    int? targetPaceMinSec,
    int? targetPaceMaxSec,
  }) async {
    debugPrint('[RestLaunch] METHOD ENTERED dur=$restDurationSec next=$nextRepNumber/$totalReps');

    final elapsedNotifier = ValueNotifier<Duration>(Duration.zero);
    final stopwatch = Stopwatch()..start();
    Timer? timer;
    Timer? liveActivityTimer;

    timer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      elapsedNotifier.value = stopwatch.elapsed;
      debugPrint('[RestLaunch] tick: elapsed=${stopwatch.elapsed.inSeconds}s, target=${restDurationSec}s');
      if (stopwatch.elapsed.inSeconds >= restDurationSec) {
        debugPrint('[RestLaunch] auto-cerrando por tiempo');
        timer?.cancel();
        liveActivityTimer?.cancel();
        stopwatch.stop();
        if (mounted) Navigator.of(context).pop();
      }
    });

    // La Live Activity de iOS se apagó al disponer la TrainingSessionView de
    // la serie recién terminada (ver GPSService.dispose()); durante el
    // descanso la realimentamos aquí con el mismo payload .rest() que ya usa
    // el flujo legacy (training_start_view.dart), para no dejarla congelada.
    final useIOSLiveActivity =
        !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;
    if (useIOSLiveActivity) {
      liveActivityTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        final remaining = (restDurationSec - stopwatch.elapsed.inSeconds)
            .clamp(0, restDurationSec);
        IOSLiveActivityService.instance.update(
          IOSLiveActivityPayload.rest(
            restCountdown: remaining,
            serie: nextRepNumber,
          ),
        );
      });
    }

    final fcStartedAt = HeartRateService().heartRate.value;

    final nextSeg = _controller.value.currentBlock.block.segments
        .where((s) => s.type == SegmentType.interval)
        .firstOrNull;
    String? nextInfo;
    if (nextSeg != null) {
      final dist = nextSeg.distanceM != null ? '${nextSeg.distanceM}m' : '';
      final pace = nextSeg.target?.paceMinSecPerKm != null
          ? ' @ ${nextSeg.target!.paceMinSecPerKm! ~/ 60}:${(nextSeg.target!.paceMinSecPerKm! % 60).toString().padLeft(2, '0')}'
          : '';
      nextInfo = '$dist$pace'.trim().isEmpty ? null : '$dist$pace'.trim();
    }

    debugPrint('[RestLaunch] session=${widget.session.title}');
    debugPrint('[RestLaunch] nextInfo=$nextInfo');
    debugPrint('[RestLaunch] fcStartedAt=$fcStartedAt');

    try {
      debugPrint('[RestLaunch] about to push');
      await Navigator.of(context).push(
        AppRoute(
          page: RestScreen(
            session: widget.session,
            restDurationSec: restDurationSec,
            nextRepNumber: nextRepNumber,
            totalReps: totalReps,
            nextRepInfo: nextInfo,
            fcStartedAt: fcStartedAt,
            onSkip: () => Navigator.of(context).pop(),
            elapsedNotifier: elapsedNotifier,
            fcNotifier: HeartRateService().heartRate,
            fcZoneNotifier: ValueNotifier<int?>(null),
            completedSerie: completedSerie,
            targetPaceMinSec: targetPaceMinSec,
            targetPaceMaxSec: targetPaceMaxSec,
          ),
        ),
      );
      debugPrint('[RestLaunch] push returned');
    } catch (e, st) {
      debugPrint('[RestLaunch] ERROR: $e');
      debugPrint('[RestLaunch] stack: $st');
    }

    timer?.cancel();
    liveActivityTimer?.cancel();
    stopwatch.stop();
    elapsedNotifier.dispose();
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
              sessionType: widget.session.type,
            );

          case ExecutionPhase.done:
            return _DoneLoader(
              state: state,
              session: widget.session,
              originalSession: widget.originalSession,
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
  final WorkoutSession? originalSession;
  final AthleteSession? athleteSession;
  final VoidCallback? onCompleted;

  const _DoneLoader({
    required this.state,
    required this.session,
    this.originalSession,
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
      'type': session.type.name,
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
      'executedBlocks': widget.session.blocks.map((block) => {
        'role': block.role.name,
        'reps': block.repetitions,
        'segmentsCount': block.segments
            .where((s) => s.type == SegmentType.interval)
            .length,
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
      plannedComparison: _buildPlannedComparison(widget.originalSession ?? widget.session),
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
