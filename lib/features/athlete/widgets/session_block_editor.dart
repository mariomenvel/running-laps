import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:running_laps/core/theme/app_colors.dart';
import 'package:running_laps/core/widgets/number_picker_field.dart';
import 'package:running_laps/features/athlete/data/athlete_session_model.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────────────────────

Color _zoneColor(int zone) {
  switch (zone) {
    case 1:  return AppColors.rest;
    case 2:  return AppColors.rpeLow;
    case 3:  return AppColors.rpeMid;
    case 4:  return AppColors.effort;
    case 5:  return AppColors.rpeMax;
    default: return AppColors.brand;
  }
}

Color _rpeColor(double rpe) {
  if (rpe <= 3.0) return AppColors.rpeLow;
  if (rpe <= 5.0) return AppColors.rpeMid;
  if (rpe <= 7.5) return AppColors.effort;
  return AppColors.rpeMax;
}

String _fmtPaceFragment(int? min, int? sec) {
  if (min == null && sec == null) return '';
  final m = min ?? 0;
  final s = sec ?? 0;
  return "$m:${s.toString().padLeft(2, '0')}";
}

String _blockTitle(SessionBlock b) {
  switch (b.type) {
    case SessionBlockType.series:
      return '${b.reps ?? 1} × ${b.distanceM ?? 0} m';
    case SessionBlockType.continuousTime:
      return '${b.durationMinutes ?? 0} min';
    case SessionBlockType.continuousDistance:
      return '${b.distanceM ?? 0} m';
  }
}

String _blockSubtitle(SessionBlock b) {
  switch (b.type) {
    case SessionBlockType.series:
      return 'Desc ${b.restSeconds ?? 0} s';
    case SessionBlockType.continuousTime:
    case SessionBlockType.continuousDistance:
      return 'Carrera continua';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SessionBlockEditor  (public widget)
// ─────────────────────────────────────────────────────────────────────────────

class SessionBlockEditor extends StatefulWidget {
  final List<SessionBlock> initialBlocks;
  final bool hasFcConfig;
  final void Function(List<SessionBlock>) onBlocksChanged;

  const SessionBlockEditor({
    super.key,
    required this.initialBlocks,
    required this.hasFcConfig,
    required this.onBlocksChanged,
  });

  @override
  State<SessionBlockEditor> createState() => _SessionBlockEditorState();
}

class _SessionBlockEditorState extends State<SessionBlockEditor> {
  late List<SessionBlock> _blocks;

  @override
  void initState() {
    super.initState();
    _blocks = List.of(widget.initialBlocks);
  }

  // ── Mutations ──────────────────────────────────────────────────────────────

  void _addBlock(SessionBlockType type) {
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    final block = SessionBlock(
      id:    id,
      order: _blocks.length,
      type:  type,
      reps:  type == SessionBlockType.series ? 1 : null,
    );
    setState(() => _blocks = [..._blocks, block]);
    widget.onBlocksChanged(List.of(_blocks));
  }

  void _updateBlock(SessionBlock updated) {
    setState(() {
      _blocks = _blocks.map((b) => b.id == updated.id ? updated : b).toList();
    });
    widget.onBlocksChanged(List.of(_blocks));
  }

  void _removeBlock(String id) {
    setState(() {
      final raw = _blocks.where((b) => b.id != id).toList();
      _blocks = [
        for (int i = 0; i < raw.length; i++) raw[i].copyWith(order: i),
      ];
    });
    widget.onBlocksChanged(List.of(_blocks));
  }

  void _reorder(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) newIndex--;
      final item = _blocks.removeAt(oldIndex);
      _blocks.insert(newIndex, item);
      _blocks = [
        for (int i = 0; i < _blocks.length; i++) _blocks[i].copyWith(order: i),
      ];
    });
    widget.onBlocksChanged(List.of(_blocks));
  }

  Future<void> _openEditor(SessionBlock block) async {
    await showModalBottomSheet<void>(
      context:            context,
      isScrollControlled: true,
      useSafeArea:        true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _BlockEditorSheet(
        block:       block,
        hasFcConfig: widget.hasFcConfig,
        onSave:      (updated) {
          Navigator.pop(ctx);
          _updateBlock(updated);
        },
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_blocks.isNotEmpty)
          ReorderableListView.builder(
            shrinkWrap: true,
            physics:    const NeverScrollableScrollPhysics(),
            itemCount:  _blocks.length,
            onReorder:  _reorder,
            proxyDecorator: (child, _, __) => Material(
              elevation:    4,
              color:        Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              child:        child,
            ),
            itemBuilder: (ctx, i) {
              final block = _blocks[i];
              return Dismissible(
                key:       ValueKey(block.id),
                direction: DismissDirection.endToStart,
                confirmDismiss: (_) => showDialog<bool>(
                  context: ctx,
                  builder: (d) => AlertDialog(
                    content: const Text('¿Eliminar este bloque?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(d, false),
                        child: const Text('Cancelar'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(d, true),
                        style: TextButton.styleFrom(foregroundColor: AppColors.rpeMax),
                        child: const Text('Eliminar'),
                      ),
                    ],
                  ),
                ),
                onDismissed: (_) => _removeBlock(block.id),
                background: Container(
                  alignment:   Alignment.centerRight,
                  padding:     const EdgeInsets.only(right: 20),
                  margin:      const EdgeInsets.only(bottom: 10),
                  decoration:  BoxDecoration(
                    color:        AppColors.rpeMax,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.delete_outline, color: Colors.white),
                ),
                child: Row(
                  children: [
                    ReorderableDragStartListener(
                      index: i,
                      child: const Padding(
                        padding: EdgeInsets.symmetric(
                            horizontal: 4, vertical: 16),
                        child: Icon(Icons.drag_handle,
                            color: Color(0xFF555555), size: 22),
                      ),
                    ),
                    Expanded(
                      child: _BlockCard(
                        block: block,
                        index: i,
                        onTap: () => _openEditor(block),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),

        const SizedBox(height: 10),

        // ── Add buttons ────────────────────────────────────────────────────
        LayoutBuilder(builder: (_, constraints) {
          final isNarrow = constraints.maxWidth < 380;
          final buttons = <Widget>[
            _AddBlockButton(
              label: 'Serie',
              onTap: () => _addBlock(SessionBlockType.series),
            ),
            _AddBlockButton(
              label: 'Continua/tiempo',
              onTap: () => _addBlock(SessionBlockType.continuousTime),
            ),
            _AddBlockButton(
              label: 'Continua/dist',
              onTap: () => _addBlock(SessionBlockType.continuousDistance),
            ),
          ];
          if (isNarrow) {
            return Wrap(spacing: 8, runSpacing: 8, children: buttons);
          }
          return Row(
            children: [
              for (int i = 0; i < buttons.length; i++) ...[
                if (i > 0) const SizedBox(width: 8),
                buttons[i],
              ],
            ],
          );
        }),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _AddBlockButton
// ─────────────────────────────────────────────────────────────────────────────

class _AddBlockButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _AddBlockButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.brand,
        side:            const BorderSide(color: AppColors.brand),
        padding:         const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        visualDensity:   VisualDensity.compact,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      child: Text(label, style: const TextStyle(fontSize: 13)),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _BlockCard
// ─────────────────────────────────────────────────────────────────────────────

class _BlockCard extends StatelessWidget {
  final SessionBlock block;
  final int index;
  final VoidCallback onTap;

  const _BlockCard({
    required this.block,
    required this.index,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final brandChipBg = AppColors.brand.withValues(alpha: 0.12);
    final brandChipText =
        isDark ? AppColors.brandLight : AppColors.brand;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.surfaceOf(context),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppColors.borderOf(context),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _blockTitle(block),
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _blockSubtitle(block),
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark
                            ? AppColors.textSecondaryDark
                            : AppColors.textSecondaryLight,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.edit_outlined,
                  size: 16,
                  color: isDark
                      ? AppColors.textSecondaryDark
                      : AppColors.textSecondaryLight),
            ]),

            // Objective chips
            if (_hasObjectives) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing:    6,
                runSpacing: 4,
                children: [
                  if (_paceLabel.isNotEmpty)
                    _ObjectiveChip(
                        label: _paceLabel,
                        bg: brandChipBg,
                        fg: brandChipText),
                  if (block.targetRpe != null)
                    _ObjectiveChip(
                        label: 'RPE ${block.targetRpe!.toStringAsFixed(1)}',
                        bg: _rpeColor(block.targetRpe!).withValues(alpha: 0.15),
                        fg: _rpeColor(block.targetRpe!)),
                  if (block.targetZone != null)
                    _ObjectiveChip(
                        label: 'Z${block.targetZone}',
                        bg: _zoneColor(block.targetZone!).withValues(alpha: 0.15),
                        fg: _zoneColor(block.targetZone!)),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  bool get _hasObjectives =>
      block.targetPaceMinMin != null ||
      block.targetPaceMaxMin != null ||
      block.targetRpe != null ||
      block.targetZone != null;

  String get _paceLabel {
    final hasMin = block.targetPaceMinMin != null;
    final hasMax = block.targetPaceMaxMin != null;
    if (!hasMin && !hasMax) return '';
    if (hasMin && hasMax) {
      return '${_fmtPaceFragment(block.targetPaceMinMin, block.targetPaceMinSec)}'
          '–${_fmtPaceFragment(block.targetPaceMaxMin, block.targetPaceMaxSec)}';
    }
    if (hasMax) return _fmtPaceFragment(block.targetPaceMaxMin, block.targetPaceMaxSec);
    return _fmtPaceFragment(block.targetPaceMinMin, block.targetPaceMinSec);
  }
}

class _ObjectiveChip extends StatelessWidget {
  final String label;
  final Color bg;
  final Color fg;

  const _ObjectiveChip({
    required this.label,
    required this.bg,
    required this.fg,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color:        bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
            fontSize: 11, fontWeight: FontWeight.w600, color: fg),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _BlockEditorSheet
// ─────────────────────────────────────────────────────────────────────────────

class _BlockEditorSheet extends StatefulWidget {
  final SessionBlock block;
  final bool hasFcConfig;
  final ValueChanged<SessionBlock> onSave;

  const _BlockEditorSheet({
    required this.block,
    required this.hasFcConfig,
    required this.onSave,
  });

  @override
  State<_BlockEditorSheet> createState() => _BlockEditorSheetState();
}

class _BlockEditorSheetState extends State<_BlockEditorSheet> {
  late SessionBlockType _type;

  // Type-specific controllers
  late TextEditingController _repsCtrl;
  late TextEditingController _distCtrl;    // series + continuousDistance
  late TextEditingController _restCtrl;
  late TextEditingController _durCtrl;

  // Shared
  late TextEditingController _notesCtrl;

  // Objectives
  bool _showObjectives = false;
  late TextEditingController _paceMinMinCtrl;
  late TextEditingController _paceMinSecCtrl;
  late TextEditingController _paceMaxMinCtrl;
  late TextEditingController _paceMaxSecCtrl;
  double? _targetRpe;
  int? _targetZone;

  @override
  void initState() {
    super.initState();
    final b = widget.block;
    _type = b.type;

    _repsCtrl       = TextEditingController(text: b.reps?.toString() ?? '');
    _distCtrl       = TextEditingController(text: b.distanceM?.toString() ?? '');
    _restCtrl       = TextEditingController(text: b.restSeconds?.toString() ?? '');
    _durCtrl        = TextEditingController(
        text: b.durationMinutes?.toString() ?? '');
    _notesCtrl      = TextEditingController(text: b.notes ?? '');

    _paceMinMinCtrl = TextEditingController(
        text: b.targetPaceMinMin?.toString() ?? '');
    _paceMinSecCtrl = TextEditingController(
        text: b.targetPaceMinSec?.toString() ?? '');
    _paceMaxMinCtrl = TextEditingController(
        text: b.targetPaceMaxMin?.toString() ?? '');
    _paceMaxSecCtrl = TextEditingController(
        text: b.targetPaceMaxSec?.toString() ?? '');

    _targetRpe  = b.targetRpe;
    _targetZone = b.targetZone;

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
    _notesCtrl.dispose();
    _paceMinMinCtrl.dispose();
    _paceMinSecCtrl.dispose();
    _paceMaxMinCtrl.dispose();
    _paceMaxSecCtrl.dispose();
    super.dispose();
  }

  // ── Change type ────────────────────────────────────────────────────────────

  void _changeType(SessionBlockType t) {
    if (t == _type) return;
    setState(() {
      _type = t;
      // Clear type-specific fields only
      switch (t) {
        case SessionBlockType.series:
          _durCtrl.clear();
          if (_repsCtrl.text.isEmpty) _repsCtrl.text = '1';
        case SessionBlockType.continuousTime:
          _repsCtrl.clear();
          _restCtrl.clear();
          // keep _distCtrl if switching from continuousDistance
          if (_type != SessionBlockType.continuousDistance) _distCtrl.clear();
        case SessionBlockType.continuousDistance:
          _repsCtrl.clear();
          _restCtrl.clear();
          _durCtrl.clear();
      }
    });
  }

  // ── Validate & save ────────────────────────────────────────────────────────

  void _trySave() {
    // Validate
    String? error;
    switch (_type) {
      case SessionBlockType.series:
        final reps = int.tryParse(_repsCtrl.text) ?? 0;
        final dist = int.tryParse(_distCtrl.text) ?? 0;
        if (reps < 1) error = 'El número de repeticiones debe ser al menos 1';
        else if (dist <= 0) error = 'La distancia debe ser mayor que 0';
      case SessionBlockType.continuousTime:
        final dur = int.tryParse(_durCtrl.text) ?? 0;
        if (dur <= 0) error = 'La duración debe ser mayor que 0';
      case SessionBlockType.continuousDistance:
        final dist = int.tryParse(_distCtrl.text) ?? 0;
        if (dist <= 0) error = 'La distancia debe ser mayor que 0';
    }

    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error), behavior: SnackBarBehavior.floating),
      );
      return;
    }

    // Pace validation: if both bounds set, min <= max
    final paceMinTotal = (_paceMinSec);
    final paceMaxTotal = (_paceMaxSec);
    if (paceMinTotal != null &&
        paceMaxTotal != null &&
        paceMinTotal > paceMaxTotal) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('El pace mínimo debe ser menor que el máximo'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final updated = widget.block.copyWith(
      type:             _type,
      reps:             _type == SessionBlockType.series
          ? (int.tryParse(_repsCtrl.text))
          : null,
      distanceM:        (_type == SessionBlockType.series ||
              _type == SessionBlockType.continuousDistance)
          ? int.tryParse(_distCtrl.text)
          : null,
      restSeconds:      _type == SessionBlockType.series
          ? int.tryParse(_restCtrl.text)
          : null,
      durationMinutes:  _type == SessionBlockType.continuousTime
          ? int.tryParse(_durCtrl.text)
          : null,
      notes:            _notesCtrl.text.trim().isEmpty
          ? null
          : _notesCtrl.text.trim(),
      targetPaceMinMin: int.tryParse(_paceMinMinCtrl.text),
      targetPaceMinSec: int.tryParse(_paceMinSecCtrl.text),
      targetPaceMaxMin: int.tryParse(_paceMaxMinCtrl.text),
      targetPaceMaxSec: int.tryParse(_paceMaxSecCtrl.text),
      targetRpe:        _targetRpe,
      targetZone:       _targetZone,
    );

    widget.onSave(updated);
  }

  int? get _paceMinSec {
    final min = int.tryParse(_paceMinMinCtrl.text);
    final sec = int.tryParse(_paceMinSecCtrl.text) ?? 0;
    if (min == null) return null;
    return min * 60 + sec;
  }

  int? get _paceMaxSec {
    final min = int.tryParse(_paceMaxMinCtrl.text);
    final sec = int.tryParse(_paceMaxSecCtrl.text) ?? 0;
    if (min == null) return null;
    return min * 60 + sec;
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: DraggableScrollableSheet(
        expand:           false,
        initialChildSize: 0.75,
        minChildSize:     0.5,
        maxChildSize:     0.95,
        builder: (_, scrollCtrl) => Column(
          children: [
            // Handle
            const SizedBox(height: 12),
            Center(
              child: Container(
                width:  40,
                height: 4,
                decoration: BoxDecoration(
                  color:        const Color(0xFFAAAAAA),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Scrollable content
            Expanded(
              child: ListView(
                controller:  scrollCtrl,
                padding:     const EdgeInsets.fromLTRB(20, 0, 20, 24),
                children:    [
                  // ── Type selector ─────────────────────────────────────────
                  SegmentedButton<SessionBlockType>(
                    segments: const [
                      ButtonSegment(
                          value: SessionBlockType.series,
                          label: Text('Serie',
                              style: TextStyle(fontSize: 13))),
                      ButtonSegment(
                          value: SessionBlockType.continuousTime,
                          label: Text('Tiempo',
                              style: TextStyle(fontSize: 13))),
                      ButtonSegment(
                          value: SessionBlockType.continuousDistance,
                          label: Text('Distancia',
                              style: TextStyle(fontSize: 13))),
                    ],
                    selected:           {_type},
                    onSelectionChanged: (s) => _changeType(s.first),
                    style: const ButtonStyle(
                      visualDensity: VisualDensity.compact,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ── Type-specific fields ──────────────────────────────────
                  _buildTypeFields(),

                  const SizedBox(height: 20),

                  // ── Notes ─────────────────────────────────────────────────
                  _SheetTextField(
                    ctrl:  _notesCtrl,
                    label: 'Nota sobre este bloque',
                    hint:  'Nota sobre este bloque',
                  ),

                  const SizedBox(height: 20),

                  // ── Objectives toggle ─────────────────────────────────────
                  GestureDetector(
                    onTap: () =>
                        setState(() => _showObjectives = !_showObjectives),
                    child: Row(children: [
                      Text(
                        'OBJETIVOS',
                        style: TextStyle(
                          fontSize:      11,
                          fontWeight:    FontWeight.w700,
                          letterSpacing: 0.8,
                          color: _showObjectives
                              ? AppColors.brand
                              : const Color(0xFFAAAAAA),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        _showObjectives
                            ? Icons.expand_less_rounded
                            : Icons.expand_more_rounded,
                        size: 18,
                        color: _showObjectives
                            ? AppColors.brand
                            : const Color(0xFFAAAAAA),
                      ),
                    ]),
                  ),

                  if (_showObjectives) ...[
                    const SizedBox(height: 14),
                    _buildObjectives(),
                  ],

                  const SizedBox(height: 28),

                  // ── Save button ───────────────────────────────────────────
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _trySave,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.brand,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Guardar bloque',
                        style: TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Type-specific fields ───────────────────────────────────────────────────

  Widget _buildTypeFields() {
    switch (_type) {
      case SessionBlockType.series:
        return Wrap(spacing: 12, runSpacing: 12, children: [
          _SheetNumField(ctrl: _repsCtrl, label: 'Reps', hint: '5', width: 80),
          _SheetNumField(
              ctrl: _distCtrl, label: 'Distancia (m)', hint: '1000', width: 120),
          _SheetNumField(
              ctrl: _restCtrl, label: 'Descanso (s)', hint: '90', width: 110),
        ]);
      case SessionBlockType.continuousTime:
        return _SheetNumField(
            ctrl: _durCtrl, label: 'Duración (min)', hint: '30', width: 140);
      case SessionBlockType.continuousDistance:
        return _SheetNumField(
            ctrl: _distCtrl,
            label: 'Distancia (m)',
            hint: '5000',
            width: 140);
    }
  }

  // ── Objectives ─────────────────────────────────────────────────────────────

  Widget _buildObjectives() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Pace
        const _ObjectiveLabel('Pace mínimo (/km)'),
        const SizedBox(height: 6),
        Row(children: [
          _PaceField(ctrl: _paceMinMinCtrl, hint: 'min'),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 4),
            child: Text("'", style: TextStyle(fontSize: 16)),
          ),
          _PaceField(ctrl: _paceMinSecCtrl, hint: 'seg'),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 4),
            child: Text('"', style: TextStyle(fontSize: 16)),
          ),
        ]),
        const SizedBox(height: 12),
        const _ObjectiveLabel('Pace máximo (/km)'),
        const SizedBox(height: 6),
        Row(children: [
          _PaceField(ctrl: _paceMaxMinCtrl, hint: 'min'),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 4),
            child: Text("'", style: TextStyle(fontSize: 16)),
          ),
          _PaceField(ctrl: _paceMaxSecCtrl, hint: 'seg'),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 4),
            child: Text('"', style: TextStyle(fontSize: 16)),
          ),
        ]),

        const SizedBox(height: 20),

        // RPE slider
        Row(children: [
          const _ObjectiveLabel('RPE objetivo'),
          const Spacer(),
          if (_targetRpe != null)
            TextButton(
              onPressed:     () => setState(() => _targetRpe = null),
              style:         TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                foregroundColor: const Color(0xFFAAAAAA),
              ),
              child: const Text('Sin RPE', style: TextStyle(fontSize: 12)),
            ),
        ]),
        const SizedBox(height: 6),
        if (_targetRpe == null)
          TextButton.icon(
            onPressed: () => setState(() => _targetRpe = 5.0),
            icon:  const Icon(Icons.add, size: 16),
            label: const Text('Añadir RPE objetivo',
                style: TextStyle(fontSize: 13)),
            style: TextButton.styleFrom(
                foregroundColor: AppColors.brand,
                visualDensity:   VisualDensity.compact),
          )
        else ...[
          Text(
            'RPE objetivo: ${_targetRpe!.toStringAsFixed(1)}',
            style: TextStyle(
              fontSize:   13,
              fontWeight: FontWeight.w600,
              color:      _rpeColor(_targetRpe!),
            ),
          ),
          Slider(
            value:       _targetRpe!,
            min:         1.0,
            max:         10.0,
            divisions:   18,
            activeColor: _rpeColor(_targetRpe!),
            onChanged:   (v) => setState(() => _targetRpe = v),
          ),
        ],

        // Zone (only if hasFcConfig)
        if (widget.hasFcConfig) ...[
          const SizedBox(height: 16),
          const _ObjectiveLabel('Zona FC objetivo'),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              for (int z = 1; z <= 5; z++)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () =>
                        setState(() => _targetZone = _targetZone == z ? null : z),
                    child: Container(
                      width:  44,
                      height: 36,
                      decoration: BoxDecoration(
                        color:        _targetZone == z
                            ? _zoneColor(z)
                            : _zoneColor(z).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                        border:       Border.all(
                          color: _zoneColor(z).withValues(
                              alpha: _targetZone == z ? 1.0 : 0.4),
                        ),
                      ),
                      child: Center(
                        child: Text(
                          'Z$z',
                          style: TextStyle(
                            fontSize:   13,
                            fontWeight: FontWeight.w700,
                            color:      _targetZone == z
                                ? Colors.white
                                : _zoneColor(z),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Small helper widgets for the sheet
// ─────────────────────────────────────────────────────────────────────────────

class _ObjectiveLabel extends StatelessWidget {
  final String text;
  const _ObjectiveLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
          fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFFAAAAAA)),
    );
  }
}

class _SheetTextField extends StatelessWidget {
  final TextEditingController ctrl;
  final String label;
  final String hint;

  const _SheetTextField({
    required this.ctrl,
    required this.label,
    required this.hint,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller:  ctrl,
      maxLines:    1,
      decoration:  InputDecoration(
        labelText:      label,
        hintText:       hint,
        isDense:        true,
        border:         OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        enabledBorder:  OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide:   BorderSide(
              color: Theme.of(context)
                  .colorScheme
                  .outline
                  .withValues(alpha: 0.5),
            )),
        focusedBorder:  OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide:   const BorderSide(color: AppColors.brand)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
    );
  }
}

class _SheetNumField extends StatefulWidget {
  final TextEditingController ctrl;
  final String label;
  final String hint;
  final double width;

  const _SheetNumField({
    required this.ctrl,
    required this.label,
    required this.hint,
    this.width = 110,
  });

  @override
  State<_SheetNumField> createState() => _SheetNumFieldState();
}

class _SheetNumFieldState extends State<_SheetNumField> {
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
        max:       5000,
        step:      1,
        unit:      '',
        onChanged: (v) {
          setState(() => _value = v);
          widget.ctrl.text = v.toString();
        },
      ),
    );
  }
}

class _PaceField extends StatefulWidget {
  final TextEditingController ctrl;
  final String hint;

  const _PaceField({required this.ctrl, required this.hint});

  @override
  State<_PaceField> createState() => _PaceFieldState();
}

class _PaceFieldState extends State<_PaceField> {
  late int _value;

  @override
  void initState() {
    super.initState();
    _value = int.tryParse(widget.ctrl.text) ?? 0;
    widget.ctrl.addListener(_syncFromCtrl);
  }

  void _syncFromCtrl() {
    final v = int.tryParse(widget.ctrl.text) ?? 0;
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
      width: 80,
      child: NumberPickerField(
        label:     widget.hint,
        value:     _value,
        min:       0,
        max:       59,
        step:      1,
        unit:      '',
        onChanged: (v) {
          setState(() => _value = v);
          widget.ctrl.text = v.toString();
        },
      ),
    );
  }
}
