import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:running_laps/core/theme/app_colors.dart';
import 'package:running_laps/core/widgets/modern_snackbar.dart';
import 'package:running_laps/features/athlete/data/athlete_session_model.dart';
import 'package:running_laps/features/templates/data/template_models.dart';
import 'package:running_laps/features/templates/data/templates_repository.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Public entry point
// ─────────────────────────────────────────────────────────────────────────────

Future<void> showSaveAsTemplateSheet({
  required BuildContext context,
  required String uid,
  required AthleteSession session,
}) {
  return showModalBottomSheet<void>(
    context:            context,
    isScrollControlled: true,
    useSafeArea:        true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => _SaveAsTemplateSheet(uid: uid, session: session),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// _SaveOption
// ─────────────────────────────────────────────────────────────────────────────

enum _SaveOption {
  warmup,
  cooldown,
  singleBlock,
  mainPart,
  fullSession,
}

// ─────────────────────────────────────────────────────────────────────────────
// _SaveAsTemplateSheet
// ─────────────────────────────────────────────────────────────────────────────

class _SaveAsTemplateSheet extends StatefulWidget {
  final String uid;
  final AthleteSession session;

  const _SaveAsTemplateSheet({
    required this.uid,
    required this.session,
  });

  @override
  State<_SaveAsTemplateSheet> createState() => _SaveAsTemplateSheetState();
}

class _SaveAsTemplateSheetState extends State<_SaveAsTemplateSheet> {
  bool _isSaving = false;

  // Shown only when a block option is selected
  int? _selectedBlockIndex;
  bool? _withObjectives; // null = no sub-option chosen yet

  // Which top-level option is the user working through
  _SaveOption? _pendingOption;

  final _repo = TrainingTemplatesRepository();

  // ── Helpers ───────────────────────────────────────────────────────────────

  String _dateStamp() => DateFormat('dd/MM').format(DateTime.now());

  String _defaultName(_SaveOption opt, {int? blockIndex}) {
    switch (opt) {
      case _SaveOption.warmup:
        return 'Calentamiento ${_dateStamp()}';
      case _SaveOption.cooldown:
        return 'Vuelta a la calma ${_dateStamp()}';
      case _SaveOption.singleBlock:
        if (blockIndex != null) {
          final b = widget.session.blocks[blockIndex];
          return _blockLabel(b);
        }
        return 'Bloque ${_dateStamp()}';
      case _SaveOption.mainPart:
        return 'Series ${_dateStamp()}';
      case _SaveOption.fullSession:
        final cat = widget.session.category;
        if (cat != null) {
          try {
            return SessionCategoryX.fromValue(cat).label;
          } catch (_) {}
        }
        return 'Sesión ${_dateStamp()}';
    }
  }

  String _blockLabel(SessionBlock b) {
    switch (b.type) {
      case SessionBlockType.series:
        return '${b.reps ?? 1} × ${b.distanceM ?? 0} m';
      case SessionBlockType.continuousTime:
        return '${b.durationMinutes ?? 0} min continuo';
      case SessionBlockType.continuousDistance:
        return '${b.distanceM ?? 0} m continuo';
    }
  }

  // ── Conversion helpers ────────────────────────────────────────────────────

  TemplateBlock _toTemplateBlock(SessionBlock b,
      {required bool withObjectives}) {
    final type = b.type == SessionBlockType.continuousTime
        ? TemplateBlockType.time
        : TemplateBlockType.distance;
    final value = b.type == SessionBlockType.continuousTime
        ? (b.durationMinutes ?? 0) * 60
        : (b.distanceM ?? 0);

    return TemplateBlock(
      id:          b.id,
      order:       b.order,
      type:        type,
      value:       value,
      restSeconds: b.restSeconds ?? 0,
      alerts:      TemplateAlerts(enabled: false),
      targetPaceMin: withObjectives ? b.targetPaceMinMin : null,
      targetPaceSec: withObjectives ? b.targetPaceMinSec : null,
      targetRpe:     withObjectives ? b.targetRpe        : null,
      targetZone:    withObjectives ? b.targetZone       : null,
    );
  }

  // ── Save actions ──────────────────────────────────────────────────────────

  Future<void> _askNameAndSave({
    required _SaveOption option,
    required List<TemplateBlock> blocks,
    required bool isWarmupCooldown,
    int? blockIndex,
    String? categoryValue,
  }) async {
    final suggested = _defaultName(option, blockIndex: blockIndex);
    final confirmed = await _showNameDialog(suggested);
    if (confirmed == null || !mounted) return;

    setState(() => _isSaving = true);
    try {
      final now = DateTime.now();
      final template = TrainingTemplate(
        id:              '',
        name:            confirmed,
        blocks:          blocks,
        createdAt:       now,
        updatedAt:       now,
        isWarmupCooldown: isWarmupCooldown,
        category:         categoryValue,
      );
      await _repo.createTemplate(template);
      if (!mounted) return;
      Navigator.pop(context);
      ModernSnackBar.showSuccess(context, 'Plantilla guardada');
    } catch (e) {
      debugPrint('[SaveAsTemplateSheet] save error: $e');
      if (!mounted) return;
      setState(() => _isSaving = false);
      ModernSnackBar.showError(context, 'Error al guardar la plantilla');
    }
  }

  Future<String?> _showNameDialog(String initialValue) async {
    final ctrl = TextEditingController(text: initialValue);
    ctrl.selection = TextSelection(
        baseOffset: 0, extentOffset: initialValue.length);

    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nombre de la plantilla'),
        content: TextField(
          controller:  ctrl,
          autofocus:   true,
          decoration:  const InputDecoration(
            hintText: 'Nombre',
            border:   OutlineInputBorder(),
          ),
          onSubmitted: (_) => Navigator.pop(ctx, ctrl.text.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            style: TextButton.styleFrom(
                foregroundColor: AppColors.brand),
            child: const Text('Guardar',
                style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    ctrl.dispose();
    return (result?.isEmpty ?? true) ? null : result;
  }

  // ── Option handlers ───────────────────────────────────────────────────────

  void _handleWarmup() {
    final w = widget.session.warmup!;
    final name = w.description ?? 'Calentamiento';
    _askNameAndSave(
      option:          _SaveOption.warmup,
      blocks:          [],
      isWarmupCooldown: true,
    );
    // name dialog uses _defaultName; description is encoded in the
    // template name that the user can edit in the dialog.
  }

  void _handleCooldown() {
    _askNameAndSave(
      option:          _SaveOption.cooldown,
      blocks:          [],
      isWarmupCooldown: true,
    );
  }

  void _handleSingleBlockWithObjectives(int blockIndex, bool withObjectives) {
    final block = widget.session.blocks[blockIndex];
    _askNameAndSave(
      option:          _SaveOption.singleBlock,
      blockIndex:      blockIndex,
      blocks:          [_toTemplateBlock(block, withObjectives: withObjectives)],
      isWarmupCooldown: false,
    );
  }

  void _handleMainPart(bool withObjectives) {
    final blocks = widget.session.blocks
        .map((b) => _toTemplateBlock(b, withObjectives: withObjectives))
        .toList();
    _askNameAndSave(
      option:          _SaveOption.mainPart,
      blocks:          blocks,
      isWarmupCooldown: false,
      categoryValue:   widget.session.category,
    );
  }

  void _handleFullSession() {
    final blocks = widget.session.blocks
        .map((b) => _toTemplateBlock(b, withObjectives: true))
        .toList();
    _askNameAndSave(
      option:          _SaveOption.fullSession,
      blocks:          blocks,
      isWarmupCooldown: false,
      categoryValue:   widget.session.category,
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final s = widget.session;
    final hasWarmup   = s.warmup != null;
    final hasCooldown = s.cooldown != null;
    final hasBlocks   = s.blocks.isNotEmpty;

    return Padding(
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom),
      child: DraggableScrollableSheet(
        expand:           false,
        initialChildSize: 0.6,
        minChildSize:     0.35,
        maxChildSize:     0.92,
        builder: (_, scrollCtrl) => Column(
          children: [
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
            const SizedBox(height: 16),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Guardar como plantilla',
                  style: TextStyle(
                      fontSize: 17, fontWeight: FontWeight.w700),
                ),
              ),
            ),
            const SizedBox(height: 4),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Elige qué parte quieres guardar',
                  style: TextStyle(
                      fontSize: 13, color: Color(0xFFAAAAAA)),
                ),
              ),
            ),
            const SizedBox(height: 12),

            if (_isSaving)
              const Expanded(
                child: Center(
                  child: CircularProgressIndicator(
                      color: AppColors.brand),
                ),
              )
            else
              Expanded(
                child: ListView(
                  controller: scrollCtrl,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 4),
                  children: [
                    // ── Warmup ───────────────────────────────────────────
                    if (hasWarmup) ...[
                      _OptionTile(
                        icon:    Icons.sunny,
                        title:   'Guardar calentamiento',
                        subtitle: s.warmup!.description ??
                            '${s.warmup!.durationMinutes ?? '?'} min',
                        onTap:   _handleWarmup,
                      ),
                      const SizedBox(height: 8),
                    ],

                    // ── Cooldown ─────────────────────────────────────────
                    if (hasCooldown) ...[
                      _OptionTile(
                        icon:    Icons.self_improvement_rounded,
                        title:   'Guardar vuelta a la calma',
                        subtitle: s.cooldown!.description ??
                            '${s.cooldown!.durationMinutes ?? '?'} min',
                        onTap:   _handleCooldown,
                      ),
                      const SizedBox(height: 8),
                    ],

                    // ── Single block ─────────────────────────────────────
                    if (hasBlocks) ...[
                      _OptionTile(
                        icon:    Icons.looks_one_outlined,
                        title:   'Guardar bloque individual',
                        subtitle: '${s.blocks.length} bloque${s.blocks.length != 1 ? 's' : ''} disponibles',
                        onTap: () => setState(() {
                          _pendingOption = _SaveOption.singleBlock;
                          _selectedBlockIndex = null;
                          _withObjectives = null;
                        }),
                        isExpanded: _pendingOption == _SaveOption.singleBlock,
                      ),

                      // ── Block selector ─────────────────────────────────
                      if (_pendingOption == _SaveOption.singleBlock) ...[
                        const SizedBox(height: 8),
                        Container(
                          decoration: BoxDecoration(
                            border:       Border.all(
                                color: AppColors.brand
                                    .withValues(alpha: 0.3)),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(children: [
                            for (int i = 0; i < s.blocks.length; i++)
                              _BlockPickerTile(
                                block:    s.blocks[i],
                                index:    i,
                                selected: _selectedBlockIndex == i,
                                onTap:    () => setState(
                                    () => _selectedBlockIndex = i),
                              ),

                            if (_selectedBlockIndex != null) ...[
                              const Divider(height: 1),
                              Padding(
                                padding: const EdgeInsets.all(12),
                                child: Row(children: [
                                  Expanded(
                                    child: OutlinedButton(
                                      onPressed: () =>
                                          _handleSingleBlockWithObjectives(
                                              _selectedBlockIndex!, false),
                                      style: _subOptionStyle(),
                                      child: const Text('Sin objetivos',
                                          style: TextStyle(fontSize: 13)),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: FilledButton(
                                      onPressed: () =>
                                          _handleSingleBlockWithObjectives(
                                              _selectedBlockIndex!, true),
                                      style: FilledButton.styleFrom(
                                        backgroundColor:
                                            AppColors.brand,
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 10),
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                      ),
                                      child: const Text('Con objetivos',
                                          style: TextStyle(fontSize: 13)),
                                    ),
                                  ),
                                ]),
                              ),
                            ],
                          ]),
                        ),
                        const SizedBox(height: 8),
                      ] else
                        const SizedBox(height: 8),

                      // ── Main part ──────────────────────────────────────
                      _OptionTile(
                        icon:    Icons.format_list_bulleted_rounded,
                        title:   'Guardar parte principal',
                        subtitle: '${s.blocks.length} bloque${s.blocks.length != 1 ? 's' : ''}',
                        onTap: () => setState(() {
                          _pendingOption = _SaveOption.mainPart;
                          _selectedBlockIndex = null;
                        }),
                        isExpanded: _pendingOption == _SaveOption.mainPart,
                      ),

                      if (_pendingOption == _SaveOption.mainPart) ...[
                        const SizedBox(height: 8),
                        _SubOptionRow(
                          onWithout: () => _handleMainPart(false),
                          onWith:    () => _handleMainPart(true),
                        ),
                        const SizedBox(height: 8),
                      ] else
                        const SizedBox(height: 8),

                      // ── Full session ───────────────────────────────────
                      _OptionTile(
                        icon:    Icons.layers_rounded,
                        title:   'Guardar sesión completa',
                        subtitle: [
                          if (hasWarmup)   'calentamiento',
                          'parte principal',
                          if (hasCooldown) 'vuelta a la calma',
                        ].join(' + '),
                        onTap:   _handleFullSession,
                      ),
                      const SizedBox(height: 8),
                    ],

                    const SizedBox(height: 16),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  ButtonStyle _subOptionStyle() => OutlinedButton.styleFrom(
        foregroundColor: AppColors.brand,
        side:            const BorderSide(color: AppColors.brand),
        padding:         const EdgeInsets.symmetric(vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// _OptionTile
// ─────────────────────────────────────────────────────────────────────────────

class _OptionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool isExpanded;

  const _OptionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.isExpanded = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isExpanded
                ? AppColors.brand
                : (isDark ? AppColors.borderDark : AppColors.borderLight),
          ),
        ),
        child: Row(children: [
          Container(
            padding:     const EdgeInsets.all(8),
            decoration:  BoxDecoration(
              color:        AppColors.brand.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 18, color: AppColors.brand),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w600)),
                Text(subtitle,
                    style: const TextStyle(
                        fontSize: 12, color: Color(0xFFAAAAAA))),
              ],
            ),
          ),
          Icon(
            isExpanded
                ? Icons.expand_less_rounded
                : Icons.chevron_right_rounded,
            size:  20,
            color: const Color(0xFFAAAAAA),
          ),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _BlockPickerTile
// ─────────────────────────────────────────────────────────────────────────────

class _BlockPickerTile extends StatelessWidget {
  final SessionBlock block;
  final int index;
  final bool selected;
  final VoidCallback onTap;

  const _BlockPickerTile({
    required this.block,
    required this.index,
    required this.selected,
    required this.onTap,
  });

  String get _title {
    switch (block.type) {
      case SessionBlockType.series:
        return '${block.reps ?? 1} × ${block.distanceM ?? 0} m';
      case SessionBlockType.continuousTime:
        return '${block.durationMinutes ?? 0} min continuo';
      case SessionBlockType.continuousDistance:
        return '${block.distanceM ?? 0} m continuo';
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense:    true,
      leading:  Text(
        '${index + 1}',
        style: TextStyle(
          fontSize:   13,
          fontWeight: FontWeight.w700,
          color:      selected ? AppColors.brand : const Color(0xFFAAAAAA),
        ),
      ),
      title: Text(_title,
          style: TextStyle(
            fontSize:   14,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
          )),
      trailing: selected
          ? const Icon(Icons.check_circle,
              color: AppColors.brand, size: 18)
          : null,
      onTap: onTap,
      shape: const RoundedRectangleBorder(),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _SubOptionRow
// ─────────────────────────────────────────────────────────────────────────────

class _SubOptionRow extends StatelessWidget {
  final VoidCallback onWithout;
  final VoidCallback onWith;

  const _SubOptionRow({required this.onWithout, required this.onWith});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Expanded(
        child: OutlinedButton(
          onPressed: onWithout,
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.brand,
            side:            const BorderSide(color: AppColors.brand),
            padding:         const EdgeInsets.symmetric(vertical: 10),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8)),
          ),
          child: const Text('Sin objetivos',
              style: TextStyle(fontSize: 13)),
        ),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: FilledButton(
          onPressed: onWith,
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.brand,
            padding:         const EdgeInsets.symmetric(vertical: 10),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8)),
          ),
          child: const Text('Con objetivos',
              style: TextStyle(fontSize: 13)),
        ),
      ),
    ]);
  }
}
