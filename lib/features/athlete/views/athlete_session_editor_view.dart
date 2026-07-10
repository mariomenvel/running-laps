// ⚠️ HUÉRFANO — sin referencias activas detectadas
// por auditoría del 2026-06-19. NO USAR como base para
// nuevo desarrollo. Pendiente de confirmar con testing
// manual antes de eliminar. Ver CHANGELOG.md.
// LEGACY — AthleteSessionEditorView no está
// conectada al flujo principal del usuario.
// No modificar hasta decidir si se elimina
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:running_laps/core/theme/app_colors.dart';
import 'package:running_laps/core/widgets/number_picker_field.dart';
import 'package:running_laps/core/widgets/app_header.dart';
import 'package:running_laps/core/widgets/modern_snackbar.dart';
import 'package:running_laps/core/widgets/main_shell.dart';
import 'package:running_laps/core/widgets/shell_embedding_scope.dart';
import 'package:running_laps/features/athlete/data/athlete_session_model.dart';
import 'package:running_laps/features/athlete/viewmodels/athlete_session_editor_viewmodel.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Category constants
// ─────────────────────────────────────────────────────────────────────────────

const List<Map<String, dynamic>> _kCategories = [
  {'value': 'regenerativo',    'label': 'Regenerativo'},
  {'value': 'rodaje_base',     'label': 'Rodaje base (Z2)'},
  {'value': 'tempo',           'label': 'Tempo (Z3)'},
  {'value': 'fartlek',         'label': 'Fartlek'},
  {'value': 'series_largas',   'label': 'Series largas'},
  {'value': 'series_cortas',   'label': 'Series cortas'},
  {'value': 'series_cuestas',  'label': 'Series en cuestas'},
  {'value': 'series_mixtas',   'label': 'Series mixtas'},
  {'value': 'competicion',     'label': 'Competición'},
  {'value': 'test',            'label': 'Test'},
  {'value': 'gimnasio_fuerza', 'label': 'Gimnasio / fuerza'},
];

String _categoryLabel(String? value) {
  if (value == null) return 'Sin categoría';
  return _kCategories
      .firstWhere((c) => c['value'] == value,
          orElse: () => {'label': value})['label'] as String;
}

// ─────────────────────────────────────────────────────────────────────────────
// AthleteSessionEditorView
// ─────────────────────────────────────────────────────────────────────────────

class AthleteSessionEditorView extends StatefulWidget {
  final String uid;
  final String initialDate;
  final AthleteSession? existingSession;

  const AthleteSessionEditorView({
    super.key,
    required this.uid,
    required this.initialDate,
    this.existingSession,
  });

  @override
  State<AthleteSessionEditorView> createState() =>
      _AthleteSessionEditorViewState();
}

class _AthleteSessionEditorViewState extends State<AthleteSessionEditorView> {
  late final SessionEditorViewModel _vm;

  @override
  void initState() {
    super.initState();
    _vm = SessionEditorViewModel(
      uid:             widget.uid,
      initialDate:     widget.initialDate,
      existingSession: widget.existingSession,
    );
  }

  @override
  void dispose() {
    _vm.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final ok = await _vm.save();
    if (!mounted) return;
    if (ok) {
      if (ShellEmbeddingScope.isEmbedded(context)) {
        MainShell.shellKey.currentState?.navigateBack();
      } else {
        Navigator.pop(context, true); // signal refresh
      }
    } else {
      ModernSnackBar.showError(
          context, _vm.state.value.error ?? 'Error al guardar');
    }
  }

  Future<void> _pickDate() async {
    final current = DateTime.tryParse(_vm.state.value.date) ?? DateTime.now();
    final picked = await showDatePicker(
      context:     context,
      initialDate: current,
      firstDate:   DateTime.now().subtract(const Duration(days: 365)),
      lastDate:    DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      _vm.updateDate(
          '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}');
    }
  }

  Future<void> _pickTime() async {
    final current = _vm.state.value.time;
    TimeOfDay initial = TimeOfDay.now();
    if (current != null) {
      final parts = current.split(':');
      if (parts.length == 2) {
        initial = TimeOfDay(
            hour:   int.tryParse(parts[0]) ?? 0,
            minute: int.tryParse(parts[1]) ?? 0);
      }
    }
    final picked = await showTimePicker(context: context, initialTime: initial);
    if (picked != null) {
      _vm.updateTime(
          '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isNew = widget.existingSession == null;
    return Scaffold(
      body: Column(
        children: [
          AppHeader(
            title: Text(
              isNew ? 'Nueva sesión' : 'Editar sesión',
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),
          ),
          Expanded(
            child: ValueListenableBuilder<SessionEditorState>(
              valueListenable: _vm.state,
              builder: (context, state, _) {
                return SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Date + Time ───────────────────────────────────────
                      _SectionLabel('Fecha y hora'),
                      const SizedBox(height: 8),
                      Row(children: [
                        Expanded(
                          child: _TappableField(
                            icon:  Icons.calendar_today_rounded,
                            label: state.date,
                            onTap: _pickDate,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _TappableField(
                            icon:  Icons.access_time_rounded,
                            label: state.time ?? 'Sin hora',
                            onTap: _pickTime,
                            trailing: state.time != null
                                ? IconButton(
                                    icon: const Icon(Icons.close, size: 18),
                                    onPressed: () => _vm.updateTime(null),
                                    visualDensity: VisualDensity.compact,
                                    padding: EdgeInsets.zero,
                                  )
                                : null,
                          ),
                        ),
                      ]),

                      const SizedBox(height: 24),

                      // ── Category ──────────────────────────────────────────
                      _SectionLabel('Tipo de sesión'),
                      const SizedBox(height: 10),
                      _CategoryPicker(
                        selected: state.category,
                        onChanged: _vm.updateCategory,
                      ),

                      const SizedBox(height: 24),

                      // ── Warmup ────────────────────────────────────────────
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: AppColors.surface2Of(context),
                          borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(12)),
                          border: Border.all(
                              color: AppColors.borderOf(context)),
                        ),
                        child: Row(children: [
                          const Icon(Icons.wb_sunny_outlined,
                              size: 16, color: Color(0xFFBA7517)),
                          const SizedBox(width: 8),
                          Text('Calentamiento',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textSecondary(context),
                                letterSpacing: 0.08,
                              )),
                        ]),
                      ),
                      _WarmupCooldownEditor(
                        value:     state.warmup,
                        onChanged: _vm.updateWarmup,
                        borderRadius: const BorderRadius.vertical(
                            bottom: Radius.circular(12)),
                      ),

                      const SizedBox(height: 24),

                      // ── Blocks ────────────────────────────────────────────
                      Row(
                        children: [
                          const Expanded(child: _SectionLabel('Bloques')),
                          TextButton.icon(
                            onPressed: _vm.addBlock,
                            icon:  const Icon(Icons.add, size: 18),
                            label: const Text('Añadir'),
                            style: TextButton.styleFrom(
                              foregroundColor: AppColors.brand,
                              visualDensity:   VisualDensity.compact,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (state.blocks.isEmpty)
                        _EmptyBlocksHint(onAdd: _vm.addBlock)
                      else
                        _BlocksList(
                          blocks:    state.blocks,
                          onUpdate:  _vm.updateBlock,
                          onRemove:  _vm.removeBlock,
                          onReorder: _vm.reorderBlocks,
                        ),

                      const SizedBox(height: 24),

                      // ── Cooldown ──────────────────────────────────────────
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: AppColors.surface2Of(context),
                          borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(12)),
                          border: Border.all(
                              color: AppColors.borderOf(context)),
                        ),
                        child: Row(children: [
                          const Icon(Icons.self_improvement_outlined,
                              size: 16, color: Color(0xFF639922)),
                          const SizedBox(width: 8),
                          Text('Vuelta a la calma',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textSecondary(context),
                                letterSpacing: 0.08,
                              )),
                        ]),
                      ),
                      _WarmupCooldownEditor(
                        value:     state.cooldown,
                        onChanged: _vm.updateCooldown,
                        borderRadius: const BorderRadius.vertical(
                            bottom: Radius.circular(12)),
                      ),

                      const SizedBox(height: 24),

                      // ── Planning notes ────────────────────────────────────
                      _SectionLabel('Notas de planificación'),
                      const SizedBox(height: 8),
                      _NotesField(
                        initial:   state.planningNotes,
                        hint:      'Objetivo del día, contexto del bloque…',
                        onChanged: _vm.updatePlanningNotes,
                      ),

                      const SizedBox(height: 32),

                      // ── Save ──────────────────────────────────────────────
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: state.isSaving ? null : _save,
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.brand,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: state.isSaving
                              ? const SizedBox(
                                  height: 20,
                                  width:  20,
                                  child:  CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : Text(
                                  isNew ? 'Guardar sesión' : 'Actualizar sesión',
                                  style: const TextStyle(
                                      fontSize: 15, fontWeight: FontWeight.w600),
                                ),
                        ),
                      ),

                      const SizedBox(height: 40),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _SectionLabel
// ─────────────────────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Text(
      text.toUpperCase(),
      style: TextStyle(
        fontSize:      11,
        fontWeight:    FontWeight.w700,
        letterSpacing: 0.8,
        color:         isDark
            ? AppColors.textSecondaryDark
            : AppColors.textSecondaryLight,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _TappableField
// ─────────────────────────────────────────────────────────────────────────────

class _TappableField extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Widget? trailing;

  const _TappableField({
    required this.icon,
    required this.label,
    required this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color:        AppColors.surfaceOf(context),
          borderRadius: BorderRadius.circular(12),
          border:       Border.all(
              color: AppColors.borderOf(context)),
        ),
        child: Row(children: [
          Icon(icon, size: 16, color: AppColors.brand),
          const SizedBox(width: 8),
          Expanded(
            child: Text(label,
                style: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w500)),
          ),
          if (trailing != null) trailing!,
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _CategoryPicker
// ─────────────────────────────────────────────────────────────────────────────

class _CategoryPicker extends StatelessWidget {
  final String? selected;
  final ValueChanged<String?> onChanged;

  const _CategoryPicker({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing:     8,
      runSpacing: 8,
      children: _kCategories.map((c) {
        final value   = c['value'] as String;
        final label   = c['label'] as String;
        final isSelected = selected == value;
        return ChoiceChip(
          label:            Text(label,
              style: TextStyle(
                fontSize:   13,
                fontWeight: FontWeight.w500,
                color:      isSelected ? Colors.white : null,
              )),
          selected:         isSelected,
          onSelected:       (_) => onChanged(isSelected ? null : value),
          selectedColor:    AppColors.brand,
          backgroundColor:  Theme.of(context).colorScheme.surface,
          side:             BorderSide(
              color: isSelected
                  ? AppColors.brand
                  : Theme.of(context).colorScheme.outline.withValues(alpha: 0.4)),
          padding:          const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          visualDensity:    VisualDensity.compact,
        );
      }).toList(),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _WarmupCooldownEditor
// ─────────────────────────────────────────────────────────────────────────────

class _WarmupCooldownEditor extends StatefulWidget {
  final SessionWarmupCooldown? value;
  final ValueChanged<SessionWarmupCooldown?> onChanged;
  final BorderRadius? borderRadius;

  const _WarmupCooldownEditor({
    required this.value,
    required this.onChanged,
    this.borderRadius,
  });

  @override
  State<_WarmupCooldownEditor> createState() => _WarmupCooldownEditorState();
}

class _WarmupCooldownEditorState extends State<_WarmupCooldownEditor> {
  late final TextEditingController _descCtrl;
  int? _durMin;

  @override
  void initState() {
    super.initState();
    _descCtrl = TextEditingController(text: widget.value?.description ?? '');
    _durMin   = widget.value?.durationMinutes;
  }

  @override
  void dispose() {
    _descCtrl.dispose();
    super.dispose();
  }

  void _notify() {
    final desc = _descCtrl.text.trim();
    if (desc.isEmpty && _durMin == null) {
      widget.onChanged(null);
    } else {
      widget.onChanged(SessionWarmupCooldown(
        description:     desc.isEmpty ? null : desc,
        durationMinutes: _durMin,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final radius = widget.borderRadius ?? BorderRadius.circular(12);
    return Container(
      padding:     const EdgeInsets.all(14),
      decoration:  BoxDecoration(
        color:        AppColors.surfaceOf(context),
        borderRadius: radius,
        border:       Border.all(
            color: AppColors.borderOf(context)),
      ),
      child: Column(children: [
        TextField(
          controller:  _descCtrl,
          onChanged:   (_) => _notify(),
          decoration:  const InputDecoration(
            hintText:      'Descripción (opcional)',
            border:        InputBorder.none,
            isDense:       true,
            contentPadding: EdgeInsets.zero,
          ),
          style:     const TextStyle(fontSize: 14),
          maxLines: null,
        ),
        const SizedBox(height: 8),
        NumberPickerField(
          label:     'Duración',
          value:     _durMin ?? 1,
          min:       1,
          max:       300,
          step:      1,
          unit:      'min',
          onChanged: (v) {
            setState(() => _durMin = v);
            _notify();
          },
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _NotesField
// ─────────────────────────────────────────────────────────────────────────────

class _NotesField extends StatefulWidget {
  final String? initial;
  final String hint;
  final ValueChanged<String?> onChanged;

  const _NotesField({
    required this.initial,
    required this.hint,
    required this.onChanged,
  });

  @override
  State<_NotesField> createState() => _NotesFieldState();
}

class _NotesFieldState extends State<_NotesField> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.initial ?? '');
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding:    const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color:        AppColors.surfaceOf(context),
        borderRadius: BorderRadius.circular(12),
        border:       Border.all(
            color: AppColors.borderOf(context)),
      ),
      child: TextField(
        controller:  _ctrl,
        onChanged:   (v) => widget.onChanged(v.trim().isEmpty ? null : v.trim()),
        maxLines:    null,
        decoration:  InputDecoration(
          hintText:       widget.hint,
          border:         InputBorder.none,
          isDense:        true,
          contentPadding: EdgeInsets.zero,
        ),
        style: const TextStyle(fontSize: 14),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _EmptyBlocksHint
// ─────────────────────────────────────────────────────────────────────────────

class _EmptyBlocksHint extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyBlocksHint({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final secondary =
        isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;
    return GestureDetector(
      onTap: onAdd,
      child: Container(
        width:  double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 28),
        decoration: BoxDecoration(
          color:        AppColors.surfaceOf(context),
          borderRadius: BorderRadius.circular(12),
          border:       Border.all(
              color: AppColors.borderOf(context),
              style: BorderStyle.solid),
        ),
        child: Column(children: [
          Icon(Icons.add_circle_outline,
              size: 32, color: AppColors.brand.withValues(alpha: 0.5)),
          const SizedBox(height: 8),
          Text('Añadir bloque',
              style: TextStyle(fontSize: 14, color: secondary)),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _BlocksList  (T5 — host for block editors)
// ─────────────────────────────────────────────────────────────────────────────

class _BlocksList extends StatelessWidget {
  final List<SessionBlock> blocks;
  final ValueChanged<SessionBlock> onUpdate;
  final ValueChanged<String> onRemove;
  final void Function(int, int) onReorder;

  const _BlocksList({
    required this.blocks,
    required this.onUpdate,
    required this.onRemove,
    required this.onReorder,
  });

  @override
  Widget build(BuildContext context) {
    return ReorderableListView.builder(
      shrinkWrap:          true,
      physics:             const NeverScrollableScrollPhysics(),
      itemCount:           blocks.length,
      onReorder:           onReorder,
      proxyDecorator:      (child, _, __) => Material(
        elevation: 4,
        borderRadius: BorderRadius.circular(14),
        child: child,
      ),
      itemBuilder: (context, i) {
        final block = blocks[i];
        return _SessionBlockEditor(
          key:      ValueKey(block.id),
          block:    block,
          index:    i,
          onUpdate: onUpdate,
          onRemove: () => onRemove(block.id),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _SessionBlockEditor  (T5)
// ─────────────────────────────────────────────────────────────────────────────

class _SessionBlockEditor extends StatefulWidget {
  final SessionBlock block;
  final int index;
  final ValueChanged<SessionBlock> onUpdate;
  final VoidCallback onRemove;

  const _SessionBlockEditor({
    super.key,
    required this.block,
    required this.index,
    required this.onUpdate,
    required this.onRemove,
  });

  @override
  State<_SessionBlockEditor> createState() => _SessionBlockEditorState();
}

class _SessionBlockEditorState extends State<_SessionBlockEditor> {
  // Text controllers
  late TextEditingController _repsCtrl;
  late TextEditingController _distCtrl;
  late TextEditingController _restCtrl;
  late TextEditingController _durCtrl;
  late TextEditingController _paceMinMinCtrl;
  late TextEditingController _paceMinSecCtrl;
  late TextEditingController _paceMaxMinCtrl;
  late TextEditingController _paceMaxSecCtrl;
  late TextEditingController _rpeCtrl;
  late TextEditingController _notesCtrl;

  bool _showObjectives = false;

  @override
  void initState() {
    super.initState();
    final b = widget.block;
    _repsCtrl       = TextEditingController(text: b.reps?.toString() ?? '');
    _distCtrl       = TextEditingController(text: b.distanceM?.toString() ?? '');
    _restCtrl       = TextEditingController(text: b.restSeconds?.toString() ?? '');
    _durCtrl        = TextEditingController(text: b.durationMinutes?.toString() ?? '');
    _paceMinMinCtrl = TextEditingController(text: b.targetPaceMinMin?.toString() ?? '');
    _paceMinSecCtrl = TextEditingController(text: b.targetPaceMinSec?.toString() ?? '');
    _paceMaxMinCtrl = TextEditingController(text: b.targetPaceMaxMin?.toString() ?? '');
    _paceMaxSecCtrl = TextEditingController(text: b.targetPaceMaxSec?.toString() ?? '');
    _rpeCtrl        = TextEditingController(text: b.targetRpe?.toString() ?? '');
    _notesCtrl      = TextEditingController(text: b.notes ?? '');

    _showObjectives = b.targetPaceMinMin != null ||
        b.targetPaceMaxMin != null ||
        b.targetRpe != null ||
        b.targetZone != null;
  }

  @override
  void dispose() {
    _repsCtrl.dispose();
    _distCtrl.dispose();
    _restCtrl.dispose();
    _durCtrl.dispose();
    _paceMinMinCtrl.dispose();
    _paceMinSecCtrl.dispose();
    _paceMaxMinCtrl.dispose();
    _paceMaxSecCtrl.dispose();
    _rpeCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  void _emit() {
    final b = widget.block;
    widget.onUpdate(b.copyWith(
      reps:             int.tryParse(_repsCtrl.text),
      distanceM:        int.tryParse(_distCtrl.text),
      restSeconds:      int.tryParse(_restCtrl.text),
      durationMinutes:  int.tryParse(_durCtrl.text),
      targetPaceMinMin: int.tryParse(_paceMinMinCtrl.text),
      targetPaceMinSec: int.tryParse(_paceMinSecCtrl.text),
      targetPaceMaxMin: int.tryParse(_paceMaxMinCtrl.text),
      targetPaceMaxSec: int.tryParse(_paceMaxSecCtrl.text),
      targetRpe:        double.tryParse(_rpeCtrl.text),
      notes:            _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
    ));
  }

  void _changeType(SessionBlockType t) {
    widget.onUpdate(widget.block.copyWith(type: t));
  }

  void _changeZone(int? zone) {
    widget.onUpdate(widget.block.copyWith(targetZone: zone));
    _emit();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final b      = widget.block;

    return Container(
      margin:     const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color:        AppColors.surfaceOf(context),
        borderRadius: BorderRadius.circular(14),
        border:       Border.all(
            color: AppColors.borderOf(context)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // ── Header row ───────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 4, 0),
          child: Row(children: [
            ReorderableDragStartListener(
              index: widget.index,
              child: Icon(Icons.drag_handle_rounded,
                  size: 20, color: AppColors.iconMutedOf(context)),
            ),
            const SizedBox(width: 8),
            Text(
              'Bloque ${widget.index + 1}',
              style: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w700),
            ),
            const Spacer(),
            IconButton(
              icon:           const Icon(Icons.delete_outline, size: 20),
              color:          AppColors.rpeMax,
              onPressed:      widget.onRemove,
              visualDensity:  VisualDensity.compact,
              padding:        EdgeInsets.zero,
            ),
          ]),
        ),

        // ── Type selector ─────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: SegmentedButton<SessionBlockType>(
            segments: const [
              ButtonSegment(
                  value: SessionBlockType.series,
                  label: Text('Series', style: TextStyle(fontSize: 12))),
              ButtonSegment(
                  value: SessionBlockType.continuousTime,
                  label: Text('Tiempo', style: TextStyle(fontSize: 12))),
              ButtonSegment(
                  value: SessionBlockType.continuousDistance,
                  label: Text('Distancia', style: TextStyle(fontSize: 12))),
            ],
            selected:          {b.type},
            onSelectionChanged: (s) => _changeType(s.first),
            style:             ButtonStyle(
              visualDensity: VisualDensity.compact,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
        ),

        // ── Type-specific fields ──────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: _buildTypeFields(b.type, isDark),
        ),

        const SizedBox(height: 10),

        // ── Objectives toggle ─────────────────────────────────────────────────
        GestureDetector(
          onTap: () => setState(() => _showObjectives = !_showObjectives),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            child: Row(children: [
              Icon(
                _showObjectives
                    ? Icons.expand_less_rounded
                    : Icons.expand_more_rounded,
                size: 18,
                color: AppColors.brand,
              ),
              const SizedBox(width: 4),
              const Text('Objetivos',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.brand)),
            ]),
          ),
        ),

        if (_showObjectives) _buildObjectivesSection(b, isDark),

        // ── Notes ─────────────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 4, 14, 14),
          child: TextField(
            controller: _notesCtrl,
            onChanged:  (_) => _emit(),
            maxLines:   null,
            decoration: const InputDecoration(
              hintText:      'Notas del bloque (opcional)',
              border:        InputBorder.none,
              isDense:       true,
              contentPadding: EdgeInsets.zero,
            ),
            style: const TextStyle(fontSize: 13),
          ),
        ),
      ]),
    );
  }

  Widget _buildTypeFields(SessionBlockType type, bool isDark) {
    switch (type) {
      case SessionBlockType.series:
        return Wrap(spacing: 12, runSpacing: 8, children: [
          _LabeledIntField(label: 'Reps',        ctrl: _repsCtrl, onChanged: _emit),
          _LabeledIntField(label: 'Distancia (m)', ctrl: _distCtrl, onChanged: _emit),
          _LabeledIntField(label: 'Descanso (s)', ctrl: _restCtrl, onChanged: _emit),
        ]);
      case SessionBlockType.continuousTime:
        return _LabeledIntField(
            label: 'Duración (min)', ctrl: _durCtrl, onChanged: _emit, width: 140);
      case SessionBlockType.continuousDistance:
        return _LabeledIntField(
            label: 'Distancia (m)', ctrl: _distCtrl, onChanged: _emit, width: 140);
    }
  }

  Widget _buildObjectivesSection(SessionBlock b, bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Pace range
        const Text('Ritmo objetivo (min/km)',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
        const SizedBox(height: 6),
        Row(children: [
          const Text('Mín ', style: TextStyle(fontSize: 12)),
          SizedBox(width: 40, child: _SmallIntField(ctrl: _paceMinMinCtrl, hint: 'mm', onChanged: _emit)),
          const Text("'", style: TextStyle(fontSize: 12)),
          SizedBox(width: 40, child: _SmallIntField(ctrl: _paceMinSecCtrl, hint: 'ss', onChanged: _emit)),
          const Text('"  Máx ', style: TextStyle(fontSize: 12)),
          SizedBox(width: 40, child: _SmallIntField(ctrl: _paceMaxMinCtrl, hint: 'mm', onChanged: _emit)),
          const Text("'", style: TextStyle(fontSize: 12)),
          SizedBox(width: 40, child: _SmallIntField(ctrl: _paceMaxSecCtrl, hint: 'ss', onChanged: _emit)),
          const Text('"', style: TextStyle(fontSize: 12)),
        ]),
        const SizedBox(height: 10),
        // RPE + Zone
        Row(children: [
          Expanded(
            child: _LabeledIntField(
                label: 'RPE (1-10)', ctrl: _rpeCtrl, onChanged: _emit),
          ),
          const SizedBox(width: 12),
          Expanded(child: _ZonePicker(selected: b.targetZone, onChanged: _changeZone)),
        ]),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Small helper widgets
// ─────────────────────────────────────────────────────────────────────────────

class _LabeledIntField extends StatefulWidget {
  final String label;
  final TextEditingController ctrl;
  final VoidCallback onChanged;
  final double width;

  const _LabeledIntField({
    required this.label,
    required this.ctrl,
    required this.onChanged,
    this.width = 110,
  });

  @override
  State<_LabeledIntField> createState() => _LabeledIntFieldState();
}

class _LabeledIntFieldState extends State<_LabeledIntField> {
  late int _value;

  @override
  void initState() {
    super.initState();
    _value = int.tryParse(widget.ctrl.text) ?? 1;
    widget.ctrl.addListener(_syncFromCtrl);
  }

  void _syncFromCtrl() {
    final v = int.tryParse(widget.ctrl.text) ?? 1;
    if (v != _value) setState(() => _value = v);
  }

  @override
  void dispose() {
    widget.ctrl.removeListener(_syncFromCtrl);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.width,
      child: NumberPickerField(
        label:     widget.label,
        value:     _value,
        min:       1,
        max:       300,
        step:      1,
        unit:      '',
        onChanged: (v) {
          setState(() => _value = v);
          widget.ctrl.text = v.toString();
          widget.onChanged();
        },
      ),
    );
  }
}

class _SmallIntField extends StatefulWidget {
  final TextEditingController ctrl;
  final String hint;
  final VoidCallback onChanged;

  const _SmallIntField({
    required this.ctrl,
    required this.hint,
    required this.onChanged,
  });

  @override
  State<_SmallIntField> createState() => _SmallIntFieldState();
}

class _SmallIntFieldState extends State<_SmallIntField> {
  late int _value;

  @override
  void initState() {
    super.initState();
    _value = int.tryParse(widget.ctrl.text) ?? 1;
    widget.ctrl.addListener(_syncFromCtrl);
  }

  void _syncFromCtrl() {
    final v = int.tryParse(widget.ctrl.text) ?? 1;
    if (v != _value) setState(() => _value = v);
  }

  @override
  void dispose() {
    widget.ctrl.removeListener(_syncFromCtrl);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return NumberPickerField(
      label:     widget.hint,
      value:     _value,
      min:       0,
      max:       59,
      step:      1,
      unit:      '',
      onChanged: (v) {
        setState(() => _value = v);
        widget.ctrl.text = v.toString();
        widget.onChanged();
      },
    );
  }
}

class _ZonePicker extends StatelessWidget {
  final int? selected;
  final ValueChanged<int?> onChanged;

  const _ZonePicker({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Zona',
          style: TextStyle(
              fontSize: 11,
              color: isDark
                  ? AppColors.textSecondaryDark
                  : AppColors.textSecondaryLight)),
      const SizedBox(height: 4),
      DropdownButtonFormField<int?>(
        initialValue:      selected,
        isDense:    true,
        decoration: InputDecoration(
          isDense:        true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          border:         OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                  color: AppColors.borderOf(context))),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                  color: AppColors.borderOf(context))),
        ),
        items: [
          const DropdownMenuItem(value: null, child: Text('—', style: TextStyle(fontSize: 14))),
          for (int z = 1; z <= 5; z++)
            DropdownMenuItem(
                value: z,
                child: Text('Z$z', style: const TextStyle(fontSize: 14))),
        ],
        onChanged: onChanged,
        style: const TextStyle(fontSize: 14),
      ),
    ]);
  }
}
