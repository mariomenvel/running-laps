import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:running_laps/core/theme/app_colors.dart';
import 'package:running_laps/core/widgets/app_header.dart';
import 'package:running_laps/core/widgets/ios_picker.dart';
import 'package:running_laps/core/widgets/modern_snackbar.dart';
import 'package:running_laps/core/widgets/number_picker_field.dart';
import 'package:running_laps/features/ai_coach/data/ai_coach_session_analysis_service.dart';
import 'package:running_laps/features/athlete/data/athlete_session_model.dart';
import 'package:running_laps/features/athlete/data/athlete_session_repository.dart';
import 'package:running_laps/features/history/viewmodels/history_controller.dart';
import 'package:running_laps/features/home/viewmodels/home_view_model.dart';
import 'package:running_laps/features/templates/data/template_models.dart';
import 'package:running_laps/features/training/data/entrenamiento.dart';
import 'package:running_laps/features/training/data/serie.dart';
import 'package:running_laps/features/training/data/training_repository.dart';

/// Guard de fecha compartido: la entrada "Completar manualmente" solo debe
/// mostrarse para sesiones planificadas de hoy o de días anteriores.
/// Compara solo año/mes/día, ignorando la hora.
bool athleteSessionCanCompleteManually(AthleteSession session) {
  if (session.status != AthleteSessionStatus.planned) return false;
  final date = DateTime.tryParse(session.date);
  if (date == null) return false;
  final today = DateTime.now();
  final d = DateTime(date.year, date.month, date.day);
  final t = DateTime(today.year, today.month, today.day);
  return !d.isAfter(t);
}

class _SeriesRow {
  final String blockId;
  int distanceM;
  int minutes = 0;
  int seconds = 0;
  double? rpe;

  _SeriesRow({
    required this.blockId,
    required this.distanceM,
  });

  int get tiempoSec => minutes * 60 + seconds;
}

class CompleteSessionManuallyView extends StatefulWidget {
  final AthleteSession session;

  const CompleteSessionManuallyView({super.key, required this.session});

  @override
  State<CompleteSessionManuallyView> createState() =>
      _CompleteSessionManuallyViewState();
}

class _CompleteSessionManuallyViewState
    extends State<CompleteSessionManuallyView> {
  final _notasCtrl = TextEditingController();
  final _repo = TrainingRepository();

  late List<SessionBlock> _sortedBlocks;
  late Map<String, List<_SeriesRow>> _rowsByBlock;

  bool _warmupOn = true;
  bool _cooldownOn = true;
  int? _globalRpe;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _sortedBlocks = [...widget.session.blocks]
      ..sort((a, b) => a.order.compareTo(b.order));
    _rowsByBlock = {
      for (final block in _sortedBlocks) block.id: _buildRowsForBlock(block),
    };
  }

  @override
  void dispose() {
    _notasCtrl.dispose();
    super.dispose();
  }

  List<_SeriesRow> _buildRowsForBlock(SessionBlock block) {
    if (block.type == SessionBlockType.series) {
      final reps = (block.reps ?? 1).clamp(1, 50);
      return List.generate(
        reps,
        (_) => _SeriesRow(blockId: block.id, distanceM: block.distanceM ?? 0),
      );
    }
    // continuousTime / continuousDistance: una única fila.
    return [_SeriesRow(blockId: block.id, distanceM: block.distanceM ?? 0)];
  }

  // ── Recalcular RPE global cuando cambia algún RPE de fila ──────────────────

  List<double> get _enteredRowRpes => _rowsByBlock.values
      .expand((rows) => rows)
      .map((r) => r.rpe)
      .whereType<double>()
      .toList();

  void _recomputeGlobalRpeFromRows() {
    final entered = _enteredRowRpes;
    if (entered.isEmpty) return;
    final mean = entered.reduce((a, b) => a + b) / entered.length;
    setState(() => _globalRpe = mean.round().clamp(1, 10));
  }

  bool get _showGlobalRpeAsRequired => _enteredRowRpes.isEmpty;

  // ── Mapeo local categoría → tag predefinida ────────────────────────────────
  // No existe una función compartida categoría→tag en el flujo GPS (allí el
  // usuario elige las etiquetas manualmente via chips) — este es un
  // best-effort local para no dejar el entrenamiento sin etiquetar.
  String? _tagForCategory(String? category) {
    switch (category) {
      case 'rodaje_base':
      case 'regenerativo':
        return 'rodaje';
      case 'tempo':
        return 'tempo';
      case 'fartlek':
        return 'fartlek';
      case 'series_largas':
      case 'series_cortas':
      case 'series_cuestas':
      case 'series_mixtas':
        return 'series';
      case 'competicion':
        return 'competición';
      default:
        return null;
    }
  }

  String _sessionTitle() {
    if (widget.session.title?.isNotEmpty == true) return widget.session.title!;
    final category = widget.session.category;
    if (category != null) {
      try {
        return SessionCategoryX.fromValue(category).label;
      } catch (_) {}
    }
    return 'Entrenamiento manual';
  }

  // ── Guardado ────────────────────────────────────────────────────────────

  Future<void> _save() async {
    if (_saving) return;

    final countedRows = _rowsByBlock.values
        .expand((rows) => rows)
        .where((r) => r.tiempoSec > 0)
        .toList();

    if (countedRows.isEmpty) {
      ModernSnackBar.showWarning(
        context,
        'Introduce al menos el tiempo de una serie o tramo para guardar.',
      );
      return;
    }

    if (_showGlobalRpeAsRequired && _globalRpe == null) {
      ModernSnackBar.showWarning(
        context,
        'Indica el RPE global de la sesión.',
      );
      return;
    }

    final entered = _enteredRowRpes;
    final fallbackRpe = (_globalRpe?.toDouble()) ??
        (entered.isNotEmpty
            ? entered.reduce((a, b) => a + b) / entered.length
            : 5.0);

    final restSecondsByBlock = {
      for (final block in _sortedBlocks) block.id: block.restSeconds ?? 0,
    };

    setState(() => _saving = true);

    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) throw Exception('No hay usuario autenticado');

      final series = <Serie>[];

      final warmup = widget.session.warmup;
      if (_warmupOn && warmup != null &&
          ((warmup.durationMinutes ?? 0) > 0 || (warmup.distanceM ?? 0) > 0)) {
        series.add(Serie(
          tiempoSec: ((warmup.durationMinutes ?? 0) * 60).toDouble(),
          distanciaM: warmup.distanceM ?? 0,
          descansoSec: 0,
          rpe: 3.0,
        ));
      }

      for (final row in countedRows) {
        series.add(Serie(
          tiempoSec: row.tiempoSec.toDouble(),
          distanciaM: row.distanceM,
          descansoSec: restSecondsByBlock[row.blockId] ?? 0,
          rpe: row.rpe ?? fallbackRpe,
        ));
      }

      final cooldown = widget.session.cooldown;
      if (_cooldownOn && cooldown != null &&
          ((cooldown.durationMinutes ?? 0) > 0 || (cooldown.distanceM ?? 0) > 0)) {
        series.add(Serie(
          tiempoSec: ((cooldown.durationMinutes ?? 0) * 60).toDouble(),
          distanciaM: cooldown.distanceM ?? 0,
          descansoSec: 0,
          rpe: 3.0,
        ));
      }

      final sessionDate = DateTime.tryParse(widget.session.date) ?? DateTime.now();
      final tag = _tagForCategory(widget.session.category);

      final entrenamiento = Entrenamiento(
        titulo: _sessionTitle(),
        fecha: sessionDate,
        gps: false,
        series: series,
        tags: tag != null ? [tag] : null,
        isManual: true,
        notas: _notasCtrl.text.trim().isEmpty ? null : _notasCtrl.text.trim(),
        // plannedComparison: se calcula hoy dentro de TrainingSummaryScreen
        // a partir de datos que aporta el flujo GPS (workout_execution_screen).
        // Este formulario no pasa por esa pantalla, así que se omite — el
        // training queda igualmente vinculado a la AthleteSession (markAsCompleted)
        // y el coach recibe el contexto planificado vs ejecutado en su propio análisis.
      );

      final newTrainingId = await _repo.createTraining(entrenamiento);
      final savedEntrenamiento = entrenamiento.copyWith(id: newTrainingId);

      try {
        await AthleteSessionRepository().markAsCompleted(
          uid: uid,
          sessionId: widget.session.id,
          trainingId: newTrainingId,
        );
      } catch (e) {
        debugPrint('[CompleteSessionManually] markAsCompleted error: $e');
      }

      HomeViewModel.needsReload.value++;
      HistoryController.needsReload.value++;

      // Fire-and-forget: no await, no bloquea la navegación.
      AiCoachSessionAnalysisService().generateAnalysis(
        uid: uid,
        entrenamiento: savedEntrenamiento,
        plannedSession: widget.session,
      );

      if (!mounted) return;
      ModernSnackBar.showSuccess(context, 'Sesión completada y guardada');
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ModernSnackBar.showError(context, 'Error al guardar: $e');
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final session = widget.session;
    final categoryLabel = session.category != null
        ? (() {
            try {
              return SessionCategoryX.fromValue(session.category!).label;
            } catch (_) {
              return session.category!;
            }
          })()
        : null;

    return Scaffold(
      backgroundColor: AppColors.background(context),
      body: SafeArea(
        top: false,
        bottom: false,
        child: Column(
          children: [
            AppHeader(
              title: Text(
                'Completar manualmente',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary(context),
                ),
              ),
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_ios_rounded),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _sessionTitle(),
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary(context),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      [
                        if (categoryLabel != null) categoryLabel,
                        session.date,
                      ].join(' · '),
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary(context),
                      ),
                    ),
                    const SizedBox(height: 24),
                    if (session.warmup != null)
                      _buildWarmupCooldownToggle(
                        title: 'Calentamiento',
                        block: session.warmup!,
                        value: _warmupOn,
                        onChanged: (v) => setState(() => _warmupOn = v),
                      ),
                    if (session.warmup != null) const SizedBox(height: 16),
                    ..._sortedBlocks.expand((block) => [
                          _buildBlockSection(block),
                          const SizedBox(height: 20),
                        ]),
                    if (session.cooldown != null)
                      _buildWarmupCooldownToggle(
                        title: 'Vuelta a la calma',
                        block: session.cooldown!,
                        value: _cooldownOn,
                        onChanged: (v) => setState(() => _cooldownOn = v),
                      ),
                    if (session.cooldown != null) const SizedBox(height: 24),
                    _buildGlobalRpeSection(),
                    const SizedBox(height: 20),
                    _buildNotasSection(),
                    const SizedBox(height: 100),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomSheet: Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          border: Border(
            top: BorderSide(color: AppColors.borderOf(context).withValues(alpha: 0.3)),
          ),
        ),
        child: SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: _saving ? null : _save,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.brand,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: _saving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Text(
                    'GUARDAR SESIÓN',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildWarmupCooldownToggle({
    required String title,
    required SessionWarmupCooldown block,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    final durationLabel = block.durationMinutes != null
        ? '${block.durationMinutes} min'
        : block.distanceM != null
            ? '${block.distanceM} m'
            : null;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceOf(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderOf(context), width: 0.5),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              durationLabel != null ? '$title — $durationLabel' : title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppColors.textPrimary(context),
              ),
            ),
          ),
          CupertinoSwitch(
            value: value,
            activeTrackColor: AppColors.brand,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  String _blockHeaderLabel(SessionBlock block, int rowCount) {
    if (block.notes?.isNotEmpty == true) return block.notes!;
    switch (block.type) {
      case SessionBlockType.series:
        final dist = block.distanceM;
        return dist != null ? 'Series — $rowCount × ${dist}m' : 'Series ($rowCount)';
      case SessionBlockType.continuousTime:
        return 'Bloque continuo';
      case SessionBlockType.continuousDistance:
        return 'Bloque continuo';
    }
  }

  Widget _buildBlockSection(SessionBlock block) {
    final rows = _rowsByBlock[block.id] ?? const <_SeriesRow>[];
    if (rows.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _blockHeaderLabel(block, rows.length),
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary(context),
          ),
        ),
        const SizedBox(height: 10),
        ...List.generate(rows.length, (i) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _buildRow(
                index: i,
                row: rows[i],
                showIndex: block.type == SessionBlockType.series,
              ),
            )),
      ],
    );
  }

  Widget _buildRow({
    required int index,
    required _SeriesRow row,
    required bool showIndex,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceOf(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderOf(context), width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showIndex) ...[
            Text(
              'S${index + 1}',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.brand,
              ),
            ),
            const SizedBox(height: 8),
          ],
          Row(
            children: [
              Expanded(
                child: NumberPickerField(
                  label: 'Distancia',
                  value: row.distanceM,
                  min: 0,
                  max: 42000,
                  step: 50,
                  unit: 'm',
                  onChanged: (v) => setState(() => row.distanceM = v),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: NumberPickerField(
                  label: 'Min',
                  value: row.minutes,
                  min: 0,
                  max: 180,
                  step: 1,
                  unit: 'min',
                  onChanged: (v) => setState(() => row.minutes = v),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: NumberPickerField(
                  label: 'Seg',
                  value: row.seconds,
                  min: 0,
                  max: 55,
                  step: 5,
                  unit: 's',
                  onChanged: (v) => setState(() => row.seconds = v),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _buildRowRpeField(row),
        ],
      ),
    );
  }

  Widget _buildRowRpeField(_SeriesRow row) {
    return GestureDetector(
      onTap: () => _showRpePickerSheet(
        initial: row.rpe,
        onSelected: (v) {
          setState(() => row.rpe = v);
          _recomputeGlobalRpeFromRows();
        },
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.background(context),
          border: Border.all(color: AppColors.borderOf(context), width: 0.5),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'RPE (opcional)',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary(context)),
            ),
            Text(
              row.rpe == null ? '—' : row.rpe!.toStringAsFixed(0),
              style: TextStyle(fontSize: 14, color: AppColors.textPrimary(context)),
            ),
          ],
        ),
      ),
    );
  }

  void _showRpePickerSheet({
    required double? initial,
    required ValueChanged<double?> onSelected,
  }) {
    final initialItem = initial == null ? 0 : initial.round().clamp(1, 10);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        height: 260,
        decoration: BoxDecoration(
          color: AppColors.surfaceOf(context),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Text('RPE', style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimary(context))),
            Expanded(
              child: Center(
                child: IosPicker(
                  itemCount: 11,
                  initialItem: initialItem,
                  itemExtent: 36,
                  width: 100,
                  textBuilder: (i) => i == 0 ? 'Sin RPE' : '$i',
                  onChanged: (i) => onSelected(i == 0 ? null : i.toDouble()),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: AppColors.brand),
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Hecho'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGlobalRpeSection() {
    final required = _showGlobalRpeAsRequired;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          required ? 'RPE GLOBAL' : 'RPE GLOBAL (calculado)',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.2,
            color: AppColors.textSecondary(context),
          ),
        ),
        const SizedBox(height: 8),
        NumberPickerField(
          label: '¿Cómo te has sentido?',
          value: _globalRpe ?? 5,
          min: 1,
          max: 10,
          step: 1,
          unit: '',
          onChanged: (v) => setState(() => _globalRpe = v),
        ),
      ],
    );
  }

  Widget _buildNotasSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'NOTAS',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.2,
            color: AppColors.textSecondary(context),
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _notasCtrl,
          minLines: 3,
          maxLines: 5,
          style: TextStyle(color: AppColors.textPrimary(context)),
          decoration: InputDecoration(
            hintText: '¿Algo que destacar de esta sesión?',
            hintStyle: TextStyle(color: AppColors.textSecondary(context)),
            filled: true,
            fillColor: AppColors.surfaceOf(context),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.all(16),
          ),
        ),
      ],
    );
  }
}
