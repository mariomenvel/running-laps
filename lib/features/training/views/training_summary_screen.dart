import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../data/entrenamiento.dart';
import '../data/training_repository.dart';
import '../data/tag_manager.dart';
import '../data/tag_model.dart';
import '../../history/viewmodels/history_controller.dart';
import '../../../../core/utils/app_transitions.dart';
import 'package:running_laps/core/widgets/main_shell.dart';
import 'package:running_laps/core/theme/app_colors.dart';
import 'package:running_laps/core/constants/training_tags.dart';
import 'package:running_laps/core/widgets/modern_snackbar.dart';

class TrainingSummaryScreen extends StatefulWidget {
  final Entrenamiento entrenamiento;

  const TrainingSummaryScreen({
    Key? key,
    required this.entrenamiento,
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

  bool get _showRpe =>
      widget.entrenamiento.series.length == 1 ||
      widget.entrenamiento.isManual;

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
    _checkScale = CurvedAnimation(parent: _checkCtrl, curve: Curves.elasticOut);
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

      if (_showRpe) {
        // Update RPE on the single serie
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

      debugPrint('[Summary] saving training id=${widget.entrenamiento.id}');
      debugPrint('[Summary] uid=$uid');
      debugPrint('[Summary] fullData keys=${fullData.keys.toList()}');

      await docRef.set(fullData);

      debugPrint('[Summary] set() completed OK');

      if (!mounted) return;

      HistoryController.needsReload.value++;

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
            fontWeight: FontWeight.w700,
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
              style: TextStyle(color: AppColors.rpeMax, fontWeight: FontWeight.w700),
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
    Navigator.pushAndRemoveUntil(
      context,
      AppRoute(page: const MainShell()),
      (route) => false,
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background(context),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildTop(),
            _divider(),
            _buildStats(),
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
            const SizedBox(height: 32),
            _buildActions(),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  // ── _buildTop ─────────────────────────────────────────────────────────────

  Widget _buildTop() {
    return Column(
      children: [
        const SizedBox(height: 32),
        ScaleTransition(
          scale: _checkScale,
          child: const Icon(
            Icons.check_circle_rounded,
            color: AppColors.rpeLow,
            size: 72,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          '¡Completado!',
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
      ],
    );
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
                  color: textColor.withOpacity(0.7),
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
        Slider(
          value: _rpe,
          min: 1,
          max: 10,
          divisions: 18,
          activeColor: _rpeColor(_rpe),
          inactiveColor: AppColors.borderOf(context),
          onChanged: (v) => setState(() => _rpe = v),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Muy fácil',
              style: TextStyle(
                color: AppColors.textSecondary(context),
                fontSize: 11,
              ),
            ),
            Text(
              _rpe.toStringAsFixed(1),
              style: TextStyle(
                color: _rpeColor(_rpe),
                fontSize: 22,
                fontWeight: FontWeight.w900,
              ),
            ),
            Text(
              'Máximo esfuerzo',
              style: TextStyle(
                color: AppColors.textSecondary(context),
                fontSize: 11,
              ),
            ),
          ],
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
    final series = widget.entrenamiento.series;
    // planned is a map with per-serie data; render a simple table
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
        // Header row
        Row(
          children: [
            SizedBox(
              width: 40,
              child: Text('Serie',
                  style: TextStyle(
                      color: AppColors.textSecondary(context), fontSize: 11)),
            ),
            Expanded(
              child: Text('Planificado',
                  style: TextStyle(
                      color: AppColors.textSecondary(context), fontSize: 11)),
            ),
            Expanded(
              child: Text('Real',
                  style: TextStyle(
                      color: AppColors.textSecondary(context), fontSize: 11)),
            ),
            SizedBox(
              width: 56,
              child: Text('Delta',
                  textAlign: TextAlign.end,
                  style: TextStyle(
                      color: AppColors.textSecondary(context), fontSize: 11)),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ...List.generate(series.length, (i) {
          final s = series[i];
          if (s.distanciaM == 0) return const SizedBox.shrink();
          final realPace =
              (s.tiempoSec / (s.distanciaM / 1000.0)).round();
          // Try to get planned pace from plannedComparison map
          final planEntry = planned['series'] is List
              ? (planned['series'] as List).elementAtOrNull(i)
              : null;
          final planPaceSec = planEntry != null
              ? (planEntry['paceSecKm'] as num?)?.toInt()
              : null;
          final delta =
              planPaceSec != null ? realPace - planPaceSec : null;
          final deltaColor = delta == null
              ? AppColors.textSecondary(context)
              : (delta <= 0 ? AppColors.rpeLow : AppColors.rpeMax);

          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                SizedBox(
                  width: 40,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.brandSurface,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'S${i + 1}',
                      style: const TextStyle(
                          color: AppColors.brandLight,
                          fontSize: 11,
                          fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    planPaceSec != null
                        ? '${_formatPace(planPaceSec)}/km'
                        : '—',
                    style: TextStyle(
                        color: AppColors.textSecondary(context), fontSize: 13),
                  ),
                ),
                Expanded(
                  child: Text(
                    '${_formatPace(realPace)}/km',
                    style: TextStyle(
                        color: AppColors.textPrimary(context),
                        fontSize: 13,
                        fontWeight: FontWeight.w600),
                  ),
                ),
                SizedBox(
                  width: 56,
                  child: Text(
                    delta == null
                        ? '—'
                        : '${delta <= 0 ? '−' : '+'}${_formatPace(delta.abs())}',
                    textAlign: TextAlign.end,
                    style: TextStyle(
                        color: deltaColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w700),
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
                        fontWeight: FontWeight.w700),
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
                        fontWeight: FontWeight.w700),
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

  Widget _buildTagChip(String name, {required bool isPredefined}) {
    final isSelected = _selectedTags.contains(name);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final activeText = isDark ? AppColors.brandLight : AppColors.brand;
    return GestureDetector(
      onTap: () => setState(() {
        if (isSelected) {
          _selectedTags.remove(name);
        } else {
          if (_selectedTags.length >= 5) {
            ModernSnackBar.showWarning(
                context, 'Máximo 5 etiquetas por entrenamiento');
            return;
          }
          _selectedTags.add(name);
        }
      }),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.brand.withOpacity(0.15)
              : isPredefined
                  ? AppColors.brand.withOpacity(0.05)
                  : AppColors.surface2Of(context),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color:
                isSelected ? AppColors.brand : AppColors.borderOf(context),
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
                color: isSelected
                    ? activeText
                    : AppColors.textSecondary(context),
                fontWeight:
                    isSelected ? FontWeight.w700 : FontWeight.w500,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTags() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final createColor = isDark ? AppColors.brandLight : AppColors.brand;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'ETIQUETAS',
          style: TextStyle(
            color: AppColors.textSecondary(context),
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: TrainingTags.predefined
              .map((tag) => _buildTagChip(tag, isPredefined: true))
              .toList(),
        ),
        if (_customTags.isNotEmpty) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _customTags
                .map((t) => _buildTagChip(t.name, isPredefined: false))
                .toList(),
          ),
        ],
        const SizedBox(height: 12),
        GestureDetector(
          onTap: _showCreateTagSheet,
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.brand.withOpacity(0.1),
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

  Future<void> _showCreateTagSheet() async {
    final controller = TextEditingController();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
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
                    fontWeight: FontWeight.w700,
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
                      } catch (_) {
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
    controller.dispose();
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

  Widget _buildActions() {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _isSaving ? null : _saveTraining,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.brand,
              foregroundColor: Colors.white,
              disabledBackgroundColor: AppColors.brand.withOpacity(0.5),
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
