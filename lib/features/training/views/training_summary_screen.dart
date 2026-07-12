import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:running_laps/core/widgets/main_shell.dart';
import 'package:running_laps/core/widgets/rpe_slider.dart';
import 'package:running_laps/core/theme/app_theme.dart' show AppMotion;

import '../data/entrenamiento.dart';
import '../data/serie.dart';
import '../data/training_repository.dart';
import '../data/tag_manager.dart';
import '../data/tag_model.dart';
import '../../athlete/data/athlete_session_model.dart';
import '../../athlete/data/athlete_session_repository.dart';
import '../../ai_coach/data/ai_coach_session_analysis_service.dart';
import '../../history/viewmodels/history_controller.dart';
import '../../home/viewmodels/home_view_model.dart';
import '../../templates/data/workout_session.dart';
import 'package:running_laps/core/theme/app_colors.dart';
import 'package:running_laps/core/constants/training_tags.dart';
import 'package:running_laps/core/widgets/modern_snackbar.dart';
import 'session_screens/shared/session_theme.dart';
import '../data/summary_stats_calculator.dart';
import 'session_screens/summary_cards/interval_stats_card.dart';
import 'session_screens/summary_cards/continuous_stats_card.dart';
import 'session_screens/summary_cards/fartlek_stats_card.dart';
import 'session_screens/summary_cards/hills_stats_card.dart';
import 'session_screens/summary_cards/competition_stats_card.dart';
import 'session_screens/summary_cards/free_stats_card.dart';

class TrainingSummaryScreen extends StatefulWidget {
  final Entrenamiento entrenamiento;
  final AthleteSession? athleteSession;

  const TrainingSummaryScreen({
    Key? key,
    required this.entrenamiento,
    this.athleteSession,
  }) : super(key: key);

  @override
  State<TrainingSummaryScreen> createState() => _TrainingSummaryScreenState();
}

class _TrainingSummaryScreenState extends State<TrainingSummaryScreen>
    with SingleTickerProviderStateMixin {
  // ── Editable state ────────────────────────────────────────────────────────
  late double _rpe;
  late Set<String> _selectedTags;
  late final TextEditingController _notasController;
  bool _isSaving = false;
  List<TrainingTag> _customTags = [];

  // ── Comparison ─────────────────────────────────────────────────────────────
  Future<Entrenamiento?>? _similarFuture;

  // ── Animation ─────────────────────────────────────────────────────────────
  late final AnimationController _checkCtrl;
  late final Animation<double> _checkScale;

  // ── Derived ───────────────────────────────────────────────────────────────
  late final int _distanciaM;
  late final double _tiempoTotalSec;
  late final int? _ritmoSecKm;
  late final double? _fcMedia;

  bool get _showRpe {
    // Solo mostrar si el entreno no tiene series con RPE
    // ya capturado individualmente (en ese caso el RPE
    // del resumen sería redundante)
    final series = widget.entrenamiento.series;
    if (series.isEmpty) return true;
    // Si alguna serie tiene RPE registrado, no mostrar
    // el slider global (ya se capturó por serie)
    final tieneRpePorSerie = series.any((s) => s.rpe > 0);
    return !tieneRpePorSerie;
  }

  WorkoutType _getSessionType() {
    final planned = widget.entrenamiento.plannedComparison;
    if (planned != null) {
      final typeStr = planned['type'] as String?;
      if (typeStr != null) {
        try {
          return WorkoutType.values.byName(typeStr);
        } catch (_) {}
      }
    }
    return WorkoutType.free;
  }

  String _completionMessage() {
    switch (_getSessionType()) {
      case WorkoutType.intervals:   return '¡SERIES COMPLETADAS!';
      case WorkoutType.continuous:  return '¡RODAJE COMPLETADO!';
      case WorkoutType.fartlek:     return '¡FARTLEK COMPLETADO!';
      case WorkoutType.hills:       return '¡CUESTAS CONQUISTADAS!';
      case WorkoutType.competition: return '¡META!';
      case WorkoutType.free:        return '¡COMPLETADO!';
    }
  }

  @override
  void initState() {
    super.initState();

    final e = widget.entrenamiento;
    _rpe = e.rpePromedio().clamp(1.0, 10.0);
    if (_rpe == 0.0) _rpe = 5.0;
    _selectedTags = Set.from(e.tags ?? []);
    _notasController = TextEditingController(text: e.notas ?? '');

    _distanciaM = e.distanciaTotalM();
    _tiempoTotalSec = e.tiempoTotalSec();
    _ritmoSecKm = _distanciaM > 0
        ? (_tiempoTotalSec / (_distanciaM / 1000.0)).round()
        : null;
    _fcMedia = e.fcMediaSesion;

    _checkCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _checkScale = CurvedAnimation(parent: _checkCtrl, curve: AppMotion.easeEnter);
    _checkCtrl.forward();

    _similarFuture = _fetchSimilar();
    _loadCustomTags();
  }

  @override
  void dispose() {
    _checkCtrl.dispose();
    _notasController.dispose();
    super.dispose();
  }

  // ── Comparison fetch ──────────────────────────────────────────────────────

  Future<Entrenamiento?> _fetchSimilar() async {
    try {
      final all =
          (await TrainingRepository().getTrainings(pageSize: 500)).trainings;
      for (final t in all) {
        if (t.id != null && t.id == widget.entrenamiento.id) continue;
        if (_isSimilar(t)) return t;
      }
    } catch (_) {}
    return null;
  }

  Future<void> _loadCustomTags() async {
    try {
      final all = await TagManager().getUserTags();
      if (!mounted) return;
      setState(() {
        _customTags = all
            .where((t) => !TrainingTags.isPredefined(t.name))
            .toList();
      });
    } catch (_) {}
  }

  bool _isSimilar(Entrenamiento candidate) {
    final curr = widget.entrenamiento;
    if (curr.series.isEmpty) return false;
    if (curr.series.length != candidate.series.length) return false;
    final cd = curr.series.map((s) => s.distanciaM).toList()..sort();
    final pd = candidate.series.map((s) => s.distanciaM).toList()..sort();
    for (int i = 0; i < cd.length; i++) {
      if (pd[i] == 0) return false;
      final r = cd[i] / pd[i];
      if (r < 0.80 || r > 1.25) return false;
    }
    return true;
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  String _formatPace(int secKm) {
    final m = secKm ~/ 60;
    final s = secKm % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  String _formatPaceSec(int? secPerKm) {
    if (secPerKm == null) return '—';
    return '${secPerKm ~/ 60}:${(secPerKm % 60).toString().padLeft(2, '0')}';
  }

  String _formatPaceRange(int? min, int? max) {
    if (min == null && max == null) return '—';
    if (min == null) return '${_formatPaceSec(max)} /km';
    if (max == null) return '${_formatPaceSec(min)} /km';
    return '${_formatPaceSec(min)} – ${_formatPaceSec(max)} /km';
  }

  Color _deltaColor(BuildContext context, double delta) {
    if (delta.abs() <= 5) return AppColors.rpeLow;
    if (delta.abs() <= 20) return AppColors.rpeMid;
    return AppColors.rpeMax;
  }

  List<Map<String, dynamic>?> _extractPlannedTargetsPerSeries() {
    final pc = widget.entrenamiento.plannedComparison;
    if (pc == null) return [];
    final blocks = pc['blocks'] as List? ?? [];
    final result = <Map<String, dynamic>?>[];
    for (final block in blocks) {
      final role = block['role'] as String?;
      if (role != 'main') continue;
      final reps = (block['plannedReps'] as num?)?.toInt() ?? 1;
      final segments = block['segments'] as List? ?? [];
      for (var r = 0; r < reps; r++) {
        for (final seg in segments) {
          result.add({
            'distanceM': seg['plannedDistanceM'],
            'durationSec': seg['plannedDurationSec'],
            'target': seg['target'],
          });
        }
      }
    }
    return result;
  }

  int _totalPlannedMainReps() {
    final pc = widget.entrenamiento.plannedComparison;
    if (pc == null) return 0;
    int total = 0;
    for (final block in pc['blocks'] as List? ?? []) {
      if (block['role'] == 'main') {
        total += (block['plannedReps'] as num?)?.toInt() ?? 0;
      }
    }
    return total;
  }

  List<Serie> _mainSeriesForComparison() {
    final pc = widget.entrenamiento.plannedComparison;
    if (pc == null) return widget.entrenamiento.series;

    final executedBlocks = pc['executedBlocks'] as List?;
    final blocks = executedBlocks ?? (pc['blocks'] as List? ?? []);

    int currentIndex = 0;
    for (final block in blocks) {
      final role = block['role'] as String?;
      final reps = (block['reps'] as num?)?.toInt()
                ?? (block['plannedReps'] as num?)?.toInt()
                ?? 1;
      final segments = (block['segmentsCount'] as num?)?.toInt()
                    ?? (block['segments'] as List?)?.length
                    ?? 1;
      final totalForBlock = reps * segments;
      if (role == 'main') {
        return widget.entrenamiento.series
            .skip(currentIndex)
            .take(totalForBlock)
            .toList();
      }
      currentIndex += totalForBlock;
    }
    return widget.entrenamiento.series;
  }

  String _formatDuration(double totalSec) {
    final t = totalSec.round();
    final h = t ~/ 3600;
    final m = (t % 3600) ~/ 60;
    final s = t % 60;
    if (h > 0) {
      return '$h:${m.toString().padLeft(2, '0')} h';
    }
    return '$m:${s.toString().padLeft(2, '0')} min';
  }

  String _formatDateShort(DateTime d) {
    const months = [
      'ene', 'feb', 'mar', 'abr', 'may', 'jun',
      'jul', 'ago', 'sep', 'oct', 'nov', 'dic',
    ];
    return '${d.day} ${months[d.month - 1]}';
  }

  Color _rpeColor(double rpe) => AppColors.effortColor(rpe);

  Widget _divider() => Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Divider(
          color: AppColors.borderOf(context),
          thickness: 0.5,
        ),
      );

  // ── Save / Discard ────────────────────────────────────────────────────────

  Future<void> _saveTraining() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);

    try {
      final id = widget.entrenamiento.id;
      if (id == null) throw Exception('Training ID missing');

      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) throw Exception('No user');

      final updates = <String, dynamic>{
        'tags': _selectedTags.toList(),
        'notas': _notasController.text.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (_showRpe && widget.entrenamiento.series.length == 1) {
        final serie = widget.entrenamiento.series.first;
        final updatedSerie = serie.copyWith(rpe: _rpe);
        updates['series'] = [updatedSerie.toMap()];
        updates['rpePromedio'] = _rpe;
      }

      final docRef = FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('trainings')
          .doc(id);

      final fullData = {
        ...widget.entrenamiento.toMap(),
        ...updates,
      };

      debugPrint('[Summary] series para guardar:');
      for (final s in fullData['series'] as List) {
        debugPrint('  - distanciaM=${s['distanciaM']}, tiempoSec=${s['tiempoSec']}, rpe=${s['rpe']}');
      }

      await docRef.set(fullData);

      if (!mounted) return;

      if (widget.athleteSession != null) {
        try {
          await AthleteSessionRepository().markAsCompleted(
            uid: uid,
            sessionId: widget.athleteSession!.id,
            trainingId: id,
          );
        } catch (e) {
          debugPrint('[Summary] markAsCompleted error: $e');
        }

        // Fire-and-forget: no await, no bloquea el flujo de guardado
        AiCoachSessionAnalysisService().generateAnalysis(
          uid: uid,
          entrenamiento: widget.entrenamiento,
          plannedSession: widget.athleteSession!,
        );
      }
      HomeViewModel.needsReload.value++;
      HistoryController.needsReload.value++;

      if (!mounted) return;
      // Pop to root (MainShell from AuthWrapper) then switch to History tab
      Navigator.popUntil(context, (route) => route.isFirst);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        MainShell.shellKey.currentState?.navigateTo(4);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ModernSnackBar.showError(context, 'Error al guardar: $e');
    }
  }

  Future<void> _confirmDiscard() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          '¿Descartar entrenamiento?',
          style: TextStyle(
            color: AppColors.textPrimary(ctx),
            fontSize: 17,
            fontWeight: FontWeight.w600,
          ),
        ),
        content: Text(
          'Esta acción no se puede deshacer.',
          style: TextStyle(
            color: AppColors.textSecondary(ctx),
            fontSize: 14,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Cancelar',
              style: TextStyle(color: AppColors.textSecondary(ctx)),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Descartar',
              style: TextStyle(color: AppColors.rpeMax, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    // Delete from Firestore if saved
    final id = widget.entrenamiento.id;
    if (id != null) {
      try {
        final uid = FirebaseAuth.instance.currentUser?.uid;
        if (uid != null) {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(uid)
              .collection('trainings')
              .doc(id)
              .delete();
        }
      } catch (_) {}
    }

    if (!mounted) return;
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = SessionTheme.forType(_getSessionType());
    final gradient = theme.backgroundGradient(context);

    return Scaffold(
      backgroundColor: AppColors.background(context),
      body: gradient != null
          ? Stack(
              fit: StackFit.expand,
              children: [
                Container(decoration: BoxDecoration(gradient: gradient)),
                _buildContent(theme),
              ],
            )
          : _buildContent(theme),
    );
  }

  Widget _buildContent(SessionTheme theme) {
    return SafeArea(
      child: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildTop(theme),
                  _divider(),
                  _buildTypeSpecificStats(context, theme),
                  _divider(),
                  if (_showRpe) ...[
                    _buildRpeSlider(),
                    _divider(),
                  ],
                  _buildComparison(),
                  _divider(),
                  _buildTags(),
                  _divider(),
                  _buildNotas(),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              border: Border(
                top: BorderSide(
                  color: AppColors.borderOf(context).withValues(alpha: 0.3),
                ),
              ),
            ),
            child: _buildActions(theme),
          ),
        ],
      ),
    );
  }

  // ── _buildTop ─────────────────────────────────────────────────────────────

  Widget _buildTop(SessionTheme theme) {
    return SizedBox(
      width: double.infinity,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
        const SizedBox(height: 32),
        ScaleTransition(
          scale: _checkScale,
          child: Icon(
            Icons.check_circle_rounded,
            color: theme.primary(context),
            size: 72,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          _completionMessage(),
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppColors.textPrimary(context),
            fontSize: 28,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 8),
        if (widget.entrenamiento.titulo.isNotEmpty)
          Text(
            widget.entrenamiento.titulo,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.textSecondary(context),
              fontSize: 15,
            ),
          ),
        Text(
          _formatDuration(_tiempoTotalSec),
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppColors.textSecondary(context),
            fontSize: 13,
          ),
        ),
        // TODO: detectar marca personal en competition
        // Buscar entrenos previos del mismo tipo y distancia
        // Si el tiempo actual es menor → mostrar "¡NUEVA MARCA PERSONAL!"
      ],
    ),
    );
  }

  // ── _buildTypeSpecificStats ───────────────────────────────────────────────

  Widget _buildTypeSpecificStats(BuildContext context, SessionTheme theme) {
    final calculator = SummaryStatsCalculator(
      entrenamiento: widget.entrenamiento,
      type: _getSessionType(),
    );
    final color = theme.primary(context);

    switch (_getSessionType()) {
      case WorkoutType.intervals:
        return IntervalStatsCard(stats: calculator.intervalStats(), accentColor: color);
      case WorkoutType.continuous:
        return ContinuousStatsCard(stats: calculator.continuousStats(), accentColor: color);
      case WorkoutType.fartlek:
        return FartlekStatsCard(stats: calculator.fartlekStats(), accentColor: color);
      case WorkoutType.hills:
        return HillsStatsCard(stats: calculator.hillsStats(), accentColor: color);
      case WorkoutType.competition:
        return CompetitionStatsCard(stats: calculator.competitionStats(), accentColor: color);
      case WorkoutType.free:
        return FreeStatsCard(stats: calculator.freeStats(), accentColor: color);
    }
  }

  // ── _buildStats ───────────────────────────────────────────────────────────

  Widget _buildStats() {
    final distText = _distanciaM >= 1000
        ? (_distanciaM / 1000).toStringAsFixed(2)
        : '$_distanciaM';
    final distUnit = _distanciaM >= 1000 ? 'km' : 'm';
    final timeH = _tiempoTotalSec.round() ~/ 3600;
    final timeM = (_tiempoTotalSec.round() % 3600) ~/ 60;
    final timeS = _tiempoTotalSec.round() % 60;
    final timeText = timeH > 0
        ? '$timeH:${timeM.toString().padLeft(2, '0')}'
        : '$timeM:${timeS.toString().padLeft(2, '0')}';
    final rpeAvg = widget.entrenamiento.rpePromedio();

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _statItem(distText, distUnit, 'Distancia'),
        _statItem(timeText, '', 'Tiempo'),
        if (_ritmoSecKm != null)
          _statItem(_formatPace(_ritmoSecKm), '/km', 'Pace'),
        _statItem(
          rpeAvg.toStringAsFixed(1),
          '',
          'RPE',
          valueColor: _rpeColor(rpeAvg),
        ),
        if (_fcMedia != null)
          _statItem(_fcMedia.round().toString(), 'bpm', 'FC media'),
      ],
    );
  }

  Widget _statItem(String value, String unit, String label,
      {Color? valueColor}) {
    final textColor = valueColor ?? AppColors.textPrimary(context);
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              value,
              style: TextStyle(
                color: textColor,
                fontSize: 22,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.5,
              ),
            ),
            if (unit.isNotEmpty) ...[
              const SizedBox(width: 2),
              Text(
                unit,
                style: TextStyle(
                  color: textColor.withValues(alpha: 0.7),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: AppColors.textSecondary(context),
            fontSize: 11,
          ),
        ),
      ],
    );
  }

  // ── _buildRpeSlider ───────────────────────────────────────────────────────

  Widget _buildRpeSlider() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '¿CÓMO TE HAS SENTIDO?',
          style: TextStyle(
            color: AppColors.textSecondary(context),
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 20),
        RpeSlider(
          value: _rpe,
          onChanged: (v) => setState(() => _rpe = v),
        ),
      ],
    );
  }

  // ── _buildComparison ──────────────────────────────────────────────────────

  Widget _buildComparison() {
    // Check planned comparison first
    final planned = widget.entrenamiento.plannedComparison;
    if (planned != null) {
      return _buildPlannedComparison(planned);
    }

    return FutureBuilder<Entrenamiento?>(
      future: _similarFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting ||
            snapshot.data == null) {
          return const SizedBox.shrink();
        }
        return _buildSimilarComparison(snapshot.data!);
      },
    );
  }

  Widget _buildPlannedComparison(Map<String, dynamic> planned) {
    debugPrint('[Comp] pc=${widget.entrenamiento.plannedComparison}');
    debugPrint('[Comp] mainSeries.length=${_mainSeriesForComparison().length}');
    debugPrint('[Comp] plannedTargets=${_extractPlannedTargetsPerSeries()}');
    final theme = SessionTheme.forType(_getSessionType());
    final accentColor = theme.primary(context);
    final mainSeries = _mainSeriesForComparison();
    final targets = _extractPlannedTargetsPerSeries();

    if (mainSeries.isEmpty) return const SizedBox.shrink();

    final executedCount = mainSeries.length;
    final plannedCount = _totalPlannedMainReps();
    final incomplete = plannedCount > 0 && executedCount < plannedCount;

    debugPrint('[CompHdr] entrenamiento.series.length=${widget.entrenamiento.series.length}');
    debugPrint('[CompHdr] mainSeries=${_mainSeriesForComparison().length}');
    debugPrint('[CompHdr] totalPlannedMainReps=${_totalPlannedMainReps()}');
    debugPrint('[CompHdr] pc.blocks=${widget.entrenamiento.plannedComparison?['blocks']}');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'COMPARATIVA',
              style: TextStyle(
                color: accentColor,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.5,
              ),
            ),
            if (plannedCount > 0) ...[
              const SizedBox(width: 8),
              Text(
                '· $executedCount / $plannedCount series',
                style: TextStyle(
                  color: incomplete ? AppColors.rpeMid : AppColors.textSecondary(context),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
        if (incomplete) ...[
          const SizedBox(height: 4),
          Text(
            'Interrumpiste el plan',
            style: TextStyle(
              color: AppColors.rpeMid,
              fontSize: 11,
            ),
          ),
        ],
        const SizedBox(height: 16),
        // Header row
        Row(
          children: [
            const SizedBox(width: 36),
            Expanded(
              child: Text(
                'Planificado',
                style: TextStyle(
                    color: AppColors.textSecondary(context), fontSize: 11),
              ),
            ),
            Expanded(
              child: Text(
                'Real',
                style: TextStyle(
                    color: AppColors.textSecondary(context), fontSize: 11),
              ),
            ),
            SizedBox(
              width: 60,
              child: Text(
                'Delta',
                textAlign: TextAlign.end,
                style: TextStyle(
                    color: AppColors.textSecondary(context), fontSize: 11),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ...List.generate(mainSeries.length, (i) {
          final s = mainSeries[i];
          if (s.distanciaM == 0) return const SizedBox.shrink();

          final realPaceSec = (s.tiempoSec / (s.distanciaM / 1000.0)).round();
          final targetEntry = i < targets.length ? targets[i] : null;
          final target = targetEntry?['target'] as Map?;
          final planMin = (target?['paceMinSecPerKm'] as num?)?.toInt();
          final planMax = (target?['paceMaxSecPerKm'] as num?)?.toInt();
          final planLabel = (planMin != null || planMax != null)
              ? _formatPaceRange(planMin, planMax)
              : '—';

          // Delta vs midpoint of range, or whichever value is available
          double? delta;
          if (planMin != null && planMax != null) {
            delta = realPaceSec - (planMin + planMax) / 2;
          } else if (planMin != null) {
            delta = realPaceSec - planMin.toDouble();
          } else if (planMax != null) {
            delta = realPaceSec - planMax.toDouble();
          }

          final deltaColor = delta == null
              ? AppColors.textSecondary(context)
              : _deltaColor(context, delta);

          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 28,
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'S${i + 1}',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: accentColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    planLabel,
                    style: TextStyle(
                        color: AppColors.textSecondary(context), fontSize: 12),
                  ),
                ),
                Expanded(
                  child: Text(
                    '${_formatPaceSec(realPaceSec)} /km',
                    style: TextStyle(
                        color: AppColors.textPrimary(context),
                        fontSize: 13,
                        fontWeight: FontWeight.w600),
                  ),
                ),
                SizedBox(
                  width: 60,
                  child: Text(
                    delta == null
                        ? '—'
                        : '${delta <= 0 ? '−' : '+'}${_formatPaceSec(delta.abs().round())}',
                    textAlign: TextAlign.end,
                    style: TextStyle(
                        color: deltaColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildSimilarComparison(Entrenamiento similar) {
    final currPace = _ritmoSecKm;
    int? prevPace;
    final prevDist = similar.distanciaTotalM();
    final prevTime = similar.tiempoTotalSec();
    if (prevDist > 0) prevPace = (prevTime / (prevDist / 1000.0)).round();

    if (currPace == null || prevPace == null) return const SizedBox.shrink();

    final diff = currPace - prevPace;
    final improved = diff <= 0;
    final diffColor = improved ? AppColors.rpeLow : AppColors.rpeMax;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'COMPARATIVA',
          style: TextStyle(
            color: AppColors.textSecondary(context),
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Entrenamiento anterior',
                    style: TextStyle(
                        color: AppColors.textSecondary(context), fontSize: 11),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatDateShort(similar.fecha),
                    style: TextStyle(
                        color: AppColors.textSecondary(context), fontSize: 12),
                  ),
                  Text(
                    '${_formatPace(prevPace)}/km',
                    style: TextStyle(
                        color: AppColors.textPrimary(context),
                        fontSize: 18,
                        fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
            Icon(
              improved
                  ? Icons.arrow_forward_rounded
                  : Icons.arrow_forward_rounded,
              color: diffColor,
              size: 28,
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'Este entreno',
                    style: TextStyle(
                        color: AppColors.textSecondary(context), fontSize: 11),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'hoy',
                    style: TextStyle(
                        color: AppColors.textSecondary(context), fontSize: 12),
                  ),
                  Text(
                    '${_formatPace(currPace)}/km',
                    style: TextStyle(
                        color: diffColor,
                        fontSize: 18,
                        fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ── _buildTags ────────────────────────────────────────────────────────────

  Widget _buildTagChip(String name, {required bool isPredefined, StateSetter? setSheetState}) {
    final isSelected = _selectedTags.contains(name);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final activeText = isDark ? AppColors.brandLight : AppColors.brand;
    return GestureDetector(
      onTap: () {
        if (isSelected) {
          setState(() => _selectedTags.remove(name));
          setSheetState?.call(() {});
        } else {
          if (_selectedTags.length >= 5) {
            ModernSnackBar.showWarning(
                context, 'Máximo 5 etiquetas por entrenamiento');
            return;
          }
          setState(() => _selectedTags.add(name));
          setSheetState?.call(() {});
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.brand.withValues(alpha: 0.15)
              : isPredefined
                  ? AppColors.brand.withValues(alpha: 0.05)
                  : AppColors.surface2Of(context),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.brand : AppColors.borderOf(context),
            width: isSelected ? 1.5 : 0.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isSelected) ...[
              Icon(Icons.check_circle_rounded, size: 14, color: activeText),
              const SizedBox(width: 5),
            ],
            Text(
              name,
              style: TextStyle(
                color: isSelected ? activeText : AppColors.textSecondary(context),
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTagsContent(StateSetter setSheetState) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final createColor = isDark ? AppColors.brandLight : AppColors.brand;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: TrainingTags.predefined
              .map((tag) => _buildTagChip(tag, isPredefined: true, setSheetState: setSheetState))
              .toList(),
        ),
        if (_customTags.isNotEmpty) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _customTags
                .map((t) => _buildTagChip(t.name, isPredefined: false, setSheetState: setSheetState))
                .toList(),
          ),
        ],
        const SizedBox(height: 12),
        GestureDetector(
          onTap: () async {
            await _showCreateTagSheet();
            setSheetState(() {});
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.brand.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.brand, width: 1),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.add_circle_outline, size: 16, color: createColor),
                const SizedBox(width: 6),
                Text(
                  '+ Crear etiqueta',
                  style: TextStyle(
                    color: createColor,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTags() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        onTap: () => _showTagsSheet(context),
        borderRadius: BorderRadius.circular(16),
        child: Row(
          children: [
            Icon(Icons.local_offer_outlined,
                size: 18, color: AppColors.textSecondary(context)),
            const SizedBox(width: 10),
            Expanded(
              child: _selectedTags.isEmpty
                  ? Text(
                      'Añadir etiquetas',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary(context),
                      ),
                    )
                  : Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: _selectedTags.take(3).map((tag) =>
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.brand.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            tag,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.brand,
                            ),
                          ),
                        ),
                      ).toList(),
                    ),
            ),
            if (_selectedTags.length > 3) ...[
              Text(
                '+${_selectedTags.length - 3}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary(context),
                ),
              ),
              const SizedBox(width: 8),
            ],
            Icon(Icons.chevron_right_rounded,
                color: AppColors.textSecondary(context)),
          ],
        ),
      ),
    );
  }

  Future<void> _showTagsSheet(BuildContext context) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => StatefulBuilder(
        builder: (sheetCtx, setSheetState) => Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(sheetCtx).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.borderOf(context),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'ETIQUETAS',
                style: TextStyle(
                  fontSize: 11,
                  letterSpacing: 1.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary(context),
                ),
              ),
              const SizedBox(height: 16),
              Flexible(
                child: SingleChildScrollView(
                  child: _buildTagsContent(setSheetState),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(sheetCtx),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.brand,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  child: const Text('Listo',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showCreateTagSheet() async {
    final controller = TextEditingController();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      useRootNavigator: true,
      isDismissible: true,
      builder: (ctx) {
        return Padding(
          padding:
              EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.surfaceOf(ctx),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Nueva etiqueta',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary(ctx),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: controller,
                  autofocus: true,
                  textCapitalization: TextCapitalization.none,
                  style: TextStyle(
                      fontSize: 14, color: AppColors.textPrimary(ctx)),
                  decoration: InputDecoration(
                    hintText: 'Nombre de etiqueta',
                    hintStyle:
                        TextStyle(color: AppColors.textSecondary(ctx)),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(
                          color: AppColors.borderOf(ctx), width: 0.5),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(
                          color: AppColors.borderOf(ctx), width: 0.5),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(
                          color: AppColors.brand, width: 1.5),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      final name =
                          controller.text.trim().toLowerCase();
                      if (name.isEmpty) return;
                      if (name.length > 20) {
                        ModernSnackBar.showWarning(
                            ctx, 'Máximo 20 caracteres');
                        return;
                      }
                      try {
                        await TagManager().createTag(
                          TrainingTag(name: name, colorValue: 0xFF9E9E9E),
                        );
                        if (ctx.mounted) Navigator.pop(ctx);
                      } catch (e, st) {
                        debugPrint('[CreateTag] error: $e');
                        debugPrint('[CreateTag] stack: $st');
                        if (ctx.mounted) {
                          ModernSnackBar.showError(
                              ctx, 'Error al crear etiqueta');
                        }
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.brand,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    child: const Text('Crear',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      controller.dispose();
    });
    if (mounted) _loadCustomTags();
  }

  // ── _buildNotas ───────────────────────────────────────────────────────────

  Widget _buildNotas() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'NOTAS',
          style: TextStyle(
            color: AppColors.textSecondary(context),
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _notasController,
          maxLines: 4,
          style: TextStyle(
            color: AppColors.textPrimary(context),
            fontSize: 15,
          ),
          decoration: InputDecoration(
            hintText: '¿Algo que destacar de este entrenamiento?',
            hintStyle: TextStyle(
              color: AppColors.textSecondary(context),
              fontSize: 15,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:
                  BorderSide(color: AppColors.borderOf(context), width: 0.5),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:
                  BorderSide(color: AppColors.borderOf(context), width: 0.5),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:
                  const BorderSide(color: AppColors.brand, width: 1),
            ),
            contentPadding: const EdgeInsets.all(16),
          ),
        ),
      ],
    );
  }

  // ── _buildActions ─────────────────────────────────────────────────────────

  Widget _buildActions(SessionTheme theme) {
    final saveColor = theme.primary(context);
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _isSaving ? null : _saveTraining,
            style: ElevatedButton.styleFrom(
              backgroundColor: saveColor,
              foregroundColor: Colors.white,
              disabledBackgroundColor: saveColor.withValues(alpha: 0.5),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
            child: _isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Text(
                    'Guardar entrenamiento',
                    style:
                        TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                  ),
          ),
        ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: _isSaving ? null : _confirmDiscard,
          style: TextButton.styleFrom(
              foregroundColor: AppColors.rpeMax),
          child: const Text('Descartar entrenamiento'),
        ),
      ],
    );
  }
}
