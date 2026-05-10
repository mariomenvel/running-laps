import 'package:flutter/material.dart';
import 'package:running_laps/core/theme/app_colors.dart';
import 'package:running_laps/core/theme/app_theme.dart';
import 'package:running_laps/features/templates/data/saved_block.dart';
import 'package:running_laps/features/templates/data/saved_blocks_repository.dart';
import 'package:running_laps/features/templates/data/workout_block.dart';
import 'package:running_laps/features/templates/data/workout_segment.dart';
import 'package:running_laps/features/templates/data/workout_session.dart';
import 'package:running_laps/features/templates/views/widgets/segment_bottom_sheet.dart';
import 'package:uuid/uuid.dart';

// ── BlocksListSection ────────────────────────────────────────────────────────

class BlocksListSection extends StatefulWidget {
  const BlocksListSection({
    super.key,
    required this.blocks,
    required this.workoutType,
    required this.onBlocksChanged,
  });

  final List<WorkoutBlock> blocks;
  final WorkoutType workoutType;
  final void Function(List<WorkoutBlock>) onBlocksChanged;

  @override
  State<BlocksListSection> createState() => _BlocksListSectionState();
}

class _BlocksListSectionState extends State<BlocksListSection> {
  bool get _hasWarmup =>
      widget.blocks.any((b) => b.role == BlockRole.warmup);
  bool get _hasCooldown =>
      widget.blocks.any((b) => b.role == BlockRole.cooldown);
  bool get _showWarmupCooldownButtons =>
      widget.workoutType != WorkoutType.free &&
      widget.workoutType != WorkoutType.continuous;
  bool get _showAddBlock =>
      widget.workoutType == WorkoutType.intervals ||
      widget.workoutType == WorkoutType.fartlek ||
      widget.workoutType == WorkoutType.hills;

  List<WorkoutBlock> get _ordered {
    final warmup = widget.blocks.where((b) => b.role == BlockRole.warmup);
    final mains = widget.blocks.where(
        (b) => b.role == BlockRole.main || b.role == BlockRole.custom);
    final cooldown = widget.blocks.where((b) => b.role == BlockRole.cooldown);
    return [...warmup, ...mains, ...cooldown];
  }

  void _addWarmup() {
    final updated = List<WorkoutBlock>.of(widget.blocks)
      ..insert(
          0,
          WorkoutBlock(
            role: BlockRole.warmup,
            repetitions: 1,
            segments: [],
          ));
    widget.onBlocksChanged(updated);
  }

  void _addCooldown() {
    final updated = List<WorkoutBlock>.of(widget.blocks)
      ..add(WorkoutBlock(
        role: BlockRole.cooldown,
        repetitions: 1,
        segments: [],
      ));
    widget.onBlocksChanged(updated);
  }

  void _addMainBlock() {
    final updated = List<WorkoutBlock>.of(widget.blocks)
      ..add(WorkoutBlock(
        role: BlockRole.custom,
        repetitions: 1,
        segments: [],
      ));
    widget.onBlocksChanged(updated);
  }

  void _updateBlock(WorkoutBlock updated) {
    final list = widget.blocks.map((b) => b.id == updated.id ? updated : b).toList();
    widget.onBlocksChanged(list);
  }

  void _deleteBlock(WorkoutBlock block) {
    widget.onBlocksChanged(
        widget.blocks.where((b) => b.id != block.id).toList());
  }

  Future<void> _addSegment(WorkoutBlock block) async {
    final segment = await showSegmentBottomSheet(
      context: context,
      workoutType: widget.workoutType,
      forceRecoveryType: widget.workoutType == WorkoutType.hills,
    );
    if (!mounted || segment == null) return;
    final updated = List<WorkoutSegment>.from(block.segments)..add(segment);
    _updateBlock(block.copyWith(segments: updated));
  }

  Future<void> _editSegment(WorkoutBlock block, WorkoutSegment seg) async {
    final updated = await showSegmentBottomSheet(
      context: context,
      workoutType: widget.workoutType,
      initialSegment: seg,
      forceRecoveryType: widget.workoutType == WorkoutType.hills,
    );
    if (!mounted || updated == null) return;
    final segments = block.segments
        .map((s) => s.id == seg.id ? updated : s)
        .toList();
    _updateBlock(block.copyWith(segments: segments));
  }

  Future<void> _onSaveBlock(
    BuildContext context,
    WorkoutBlock block,
    void Function(WorkoutBlock) onChanged,
  ) async {
    final name = await showDialog<String>(
      context: context,
      builder: (_) => _SaveBlockDialog(
        defaultName: _defaultBlockName(block),
      ),
    );
    if (name == null || name.trim().isEmpty) return;

    try {
      final count = await SavedBlocksRepository().getCount();
      if (count >= SavedBlocksRepository.freeLimit) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(
              'Límite de ${SavedBlocksRepository.freeLimit} bloques guardados alcanzado',
            )),
          );
        }
        return;
      }

      final saved = SavedBlock(
        id: const Uuid().v4(),
        name: name.trim(),
        role: block.role,
        block: block,
        createdAt: DateTime.now(),
      );
      await SavedBlocksRepository().saveBlock(saved);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bloque guardado')),
        );
      }
    } catch (e) {
      debugPrint('[BlocksList] saveBlock error: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al guardar: $e')),
        );
      }
    }
  }

  String _defaultBlockName(WorkoutBlock block) {
    switch (block.role) {
      case BlockRole.warmup:
        return 'Calentamiento';
      case BlockRole.cooldown:
        return 'Vuelta a la calma';
      case BlockRole.main:
      case BlockRole.custom:
        final seg = block.segments
            .where((s) => s.type == SegmentType.interval)
            .firstOrNull;
        if (seg == null) return 'Bloque';
        final reps = block.repetitions;
        if (seg.distanceM != null) {
          return reps > 1 ? '$reps×${seg.distanceM}m' : '${seg.distanceM}m';
        }
        if (seg.durationSec != null) {
          final min = seg.durationSec! ~/ 60;
          return reps > 1 ? '$reps×$min min' : '$min min';
        }
        return 'Bloque';
    }
  }

  Future<void> _onLoadSavedBlock(BuildContext context) async {
    final saved = await showModalBottomSheet<SavedBlock>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceOf(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _SavedBlocksSheet(
        workoutType: widget.workoutType,
      ),
    );
    if (saved == null) return;

    final current = List<WorkoutBlock>.from(widget.blocks);
    final cooldownIdx = current.indexWhere((b) => b.role == BlockRole.cooldown);
    final newBlock = WorkoutBlock(
      role: saved.block.role,
      repetitions: saved.block.repetitions,
      segments: saved.block.segments,
      label: saved.block.label,
    );

    if (cooldownIdx >= 0) {
      current.insert(cooldownIdx, newBlock);
    } else {
      current.add(newBlock);
    }

    SavedBlocksRepository().incrementUsage(saved.id);

    widget.onBlocksChanged(current);
  }

  @override
  Widget build(BuildContext context) {
    final ordered = _ordered;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Botón añadir calentamiento
        if (!_hasWarmup && _showWarmupCooldownButtons)
          _GhostButton(
            label: 'Añadir calentamiento',
            onTap: _addWarmup,
            context: context,
          ),

        // 2. Lista de bloques reordenable
        ReorderableListView(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          buildDefaultDragHandles: false,
          proxyDecorator: (child, index, animation) {
            return AnimatedBuilder(
              animation: animation,
              builder: (context, child) {
                return Material(
                  elevation: 4,
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(16),
                  child: child,
                );
              },
              child: child,
            );
          },
          onReorder: (oldIndex, newIndex) {
            final updated = List<WorkoutBlock>.from(_ordered);
            if (newIndex > oldIndex) newIndex--;
            final item = updated.removeAt(oldIndex);
            updated.insert(newIndex, item);
            widget.onBlocksChanged(updated);
          },
          children: [
            for (int i = 0; i < ordered.length; i++)
              Padding(
                key: ValueKey(ordered[i].id),
                padding: const EdgeInsets.only(bottom: AppSpacing.s),
                child: _WorkoutBlockCard(
                  index: i,
                  block: ordered[i],
                  workoutType: widget.workoutType,
                  onChanged: _updateBlock,
                  onDelete: () => _deleteBlock(ordered[i]),
                  onAddSegment: () => _addSegment(ordered[i]),
                  onEditSegment: (seg) => _editSegment(ordered[i], seg),
                  onSave: () => _onSaveBlock(context, ordered[i], _updateBlock),
                ),
              ),
          ],
        ),

        // 3. Botón cargar bloque guardado
        TextButton.icon(
          icon: const Icon(Icons.bookmark_border, size: 18),
          label: const Text('Cargar bloque guardado'),
          style: TextButton.styleFrom(
            foregroundColor: AppColors.brand,
          ),
          onPressed: () => _onLoadSavedBlock(context),
        ),

        // 4. Botón añadir bloque
        if (_showAddBlock)
          _GhostButton(
            label: 'Añadir bloque',
            onTap: _addMainBlock,
            context: context,
            color: AppColors.brand,
          ),

        // 5. Botón añadir vuelta a la calma
        if (!_hasCooldown && _showWarmupCooldownButtons)
          _GhostButton(
            label: 'Añadir vuelta a la calma',
            onTap: _addCooldown,
            context: context,
          ),
      ],
    );
  }
}

// ── GhostButton ──────────────────────────────────────────────────────────────

class _GhostButton extends StatelessWidget {
  const _GhostButton({
    required this.label,
    required this.onTap,
    required this.context,
    this.color,
  });

  final String label;
  final VoidCallback onTap;
  final BuildContext context;
  final Color? color;

  @override
  Widget build(BuildContext outerContext) {
    final c = color ?? AppColors.textSecondary(outerContext);
    return TextButton.icon(
      onPressed: onTap,
      icon: Icon(Icons.add, size: 16, color: c),
      label: Text(
        label,
        style: TextStyle(fontSize: 13, color: c),
      ),
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.s, vertical: AppSpacing.xs),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }
}

// ── _WorkoutBlockCard ────────────────────────────────────────────────────────

class _WorkoutBlockCard extends StatelessWidget {
  const _WorkoutBlockCard({
    required this.index,
    required this.block,
    required this.workoutType,
    required this.onChanged,
    required this.onDelete,
    required this.onAddSegment,
    required this.onEditSegment,
    required this.onSave,
  });

  final int index;
  final WorkoutBlock block;
  final WorkoutType workoutType;
  final void Function(WorkoutBlock) onChanged;
  final VoidCallback onDelete;
  final VoidCallback onAddSegment;
  final void Function(WorkoutSegment) onEditSegment;
  final VoidCallback onSave;

  bool get _showRepetitions =>
      (block.role == BlockRole.main || block.role == BlockRole.custom) &&
      workoutType != WorkoutType.continuous &&
      workoutType != WorkoutType.free;

  bool get _reorderable =>
      (block.role == BlockRole.main || block.role == BlockRole.custom) &&
      workoutType != WorkoutType.continuous;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceOf(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: AppColors.borderOf(context), width: 0.5),
      ),
      padding: const EdgeInsets.all(AppSpacing.l),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              ReorderableDragStartListener(
                index: index,
                child: Padding(
                  padding: const EdgeInsets.only(right: AppSpacing.s),
                  child: Icon(
                    Icons.drag_handle,
                    size: 20,
                    color: AppColors.iconMutedOf(context),
                  ),
                ),
              ),
              Icon(_roleIcon, color: _roleColor, size: 20),
              const SizedBox(width: AppSpacing.s),
              Text(
                _roleLabel,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 1.2,
                  color: AppColors.textSecondary(context),
                ),
              ),
              const Spacer(),
              IconButton(
                icon: Icon(Icons.bookmark_outline,
                    size: 20, color: AppColors.iconMutedOf(context)),
                tooltip: 'Guardar bloque',
                onPressed: onSave,
                constraints: const BoxConstraints(),
                padding: const EdgeInsets.only(right: AppSpacing.s),
              ),
              if (block.role != BlockRole.warmup &&
                  block.role != BlockRole.cooldown)
                IconButton(
                  icon: Icon(Icons.delete_outline,
                      size: 20,
                      color: AppColors.textSecondary(context)),
                  onPressed: onDelete,
                  constraints: const BoxConstraints(),
                  padding: EdgeInsets.zero,
                ),
            ],
          ),

          // Repetitions selector
          if (_showRepetitions) ...[
            const SizedBox(height: AppSpacing.m),
            Row(
              children: [
                Text(
                  'Repeticiones',
                  style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary(context)),
                ),
                const Spacer(),
                IconButton(
                  icon: Icon(Icons.remove,
                      color: block.repetitions > 1
                          ? AppColors.brand
                          : AppColors.iconMutedOf(context)),
                  onPressed: block.repetitions > 1
                      ? () => onChanged(
                          block.copyWith(repetitions: block.repetitions - 1))
                      : null,
                  constraints: const BoxConstraints(),
                  padding: EdgeInsets.zero,
                ),
                SizedBox(
                  width: 32,
                  child: Text(
                    '${block.repetitions}',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textPrimary(context),
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.add,
                      color: block.repetitions < 99
                          ? AppColors.brand
                          : AppColors.iconMutedOf(context)),
                  onPressed: block.repetitions < 99
                      ? () => onChanged(
                          block.copyWith(repetitions: block.repetitions + 1))
                      : null,
                  constraints: const BoxConstraints(),
                  padding: EdgeInsets.zero,
                ),
              ],
            ),
          ],

          const SizedBox(height: AppSpacing.m),

          // Segments list
          if (block.segments.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Center(
                child: Text(
                  'Sin segmentos — toca + para añadir',
                  style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary(context)),
                ),
              ),
            )
          else if (_reorderable)
            ReorderableListView(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              buildDefaultDragHandles: false,
              proxyDecorator: (child, index, animation) {
                return AnimatedBuilder(
                  animation: animation,
                  builder: (context, child) {
                    return Material(
                      elevation: 4,
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(16),
                      child: child,
                    );
                  },
                  child: child,
                );
              },
              onReorder: (oldIndex, newIndex) {
                final segments = List<WorkoutSegment>.of(block.segments);
                if (newIndex > oldIndex) newIndex--;
                final seg = segments.removeAt(oldIndex);
                segments.insert(newIndex, seg);
                onChanged(block.copyWith(segments: segments));
              },
              children: [
                for (int i = 0; i < block.segments.length; i++)
                  _SegmentChip(
                    key: ValueKey(block.segments[i].id),
                    index: i,
                    segment: block.segments[i],
                    onEdit: () => onEditSegment(block.segments[i]),
                    onDelete: () {
                      final segs = block.segments
                          .where((s) => s.id != block.segments[i].id)
                          .toList();
                      onChanged(block.copyWith(segments: segs));
                    },
                  ),
              ],
            )
          else
            Column(
              children: [
                for (int i = 0; i < block.segments.length; i++)
                  _SegmentChip(
                    index: i,
                    segment: block.segments[i],
                    onEdit: () => onEditSegment(block.segments[i]),
                    onDelete: () {
                      final segs = block.segments
                          .where((s) => s.id != block.segments[i].id)
                          .toList();
                      onChanged(block.copyWith(segments: segs));
                    },
                  ),
              ],
            ),

          // Add segment button
          TextButton.icon(
            onPressed: onAddSegment,
            icon: Icon(Icons.add, size: 14, color: AppColors.brand),
            label: Text(
              'Añadir segmento',
              style: TextStyle(fontSize: 13, color: AppColors.brand),
            ),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.xs, vertical: AppSpacing.xs),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
        ],
      ),
    );
  }

  IconData get _roleIcon {
    switch (block.role) {
      case BlockRole.warmup:
        return Icons.waves;
      case BlockRole.main:
        return Icons.bolt;
      case BlockRole.cooldown:
        return Icons.waves;
      case BlockRole.custom:
        return Icons.add_circle_outline;
    }
  }

  Color get _roleColor {
    switch (block.role) {
      case BlockRole.warmup:
      case BlockRole.cooldown:
        return AppColors.rest;
      case BlockRole.main:
        return AppColors.effort;
      case BlockRole.custom:
        return AppColors.brand;
    }
  }

  String get _roleLabel {
    switch (block.role) {
      case BlockRole.warmup:
        return 'CALENTAMIENTO';
      case BlockRole.main:
        return 'BLOQUE PRINCIPAL';
      case BlockRole.cooldown:
        return 'VUELTA A LA CALMA';
      case BlockRole.custom:
        return 'BLOQUE ADICIONAL';
    }
  }
}

// ── _SaveBlockDialog ──────────────────────────────────────────────────────────

class _SaveBlockDialog extends StatefulWidget {
  const _SaveBlockDialog({required this.defaultName});

  final String defaultName;

  @override
  State<_SaveBlockDialog> createState() => _SaveBlockDialogState();
}

class _SaveBlockDialogState extends State<_SaveBlockDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.defaultName);
    _controller.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final canSave = _controller.text.trim().isNotEmpty;
    return AlertDialog(
      title: const Text('Guardar bloque'),
      content: TextField(
        autofocus: true,
        controller: _controller,
        maxLength: 50,
        decoration: const InputDecoration(hintText: 'Nombre del bloque'),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, null),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: canSave ? () => Navigator.pop(context, _controller.text) : null,
          child: const Text('Guardar'),
        ),
      ],
    );
  }
}

// ── _SavedBlocksSheet ─────────────────────────────────────────────────────────

class _SavedBlocksSheet extends StatefulWidget {
  const _SavedBlocksSheet({required this.workoutType});

  final WorkoutType workoutType;

  @override
  State<_SavedBlocksSheet> createState() => _SavedBlocksSheetState();
}

class _SavedBlocksSheetState extends State<_SavedBlocksSheet> {
  List<SavedBlock> _blocks = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final blocks = await SavedBlocksRepository().getSavedBlocks();
      if (!mounted) return;
      setState(() {
        _blocks = blocks;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _delete(SavedBlock block) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Eliminar bloque'),
        content: Text('¿Eliminar "${block.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await SavedBlocksRepository().deleteBlock(block.id);
    if (!mounted) return;
    setState(() => _blocks.removeWhere((b) => b.id == block.id));
  }

  String _blockDescription(SavedBlock saved) {
    final block = saved.block;
    final seg = block.segments
        .where((s) => s.type == SegmentType.interval)
        .firstOrNull;
    if (seg == null) return '${block.repetitions}× —';
    if (seg.distanceM != null) {
      return '${block.repetitions}× ${seg.distanceM}m';
    }
    if (seg.durationSec != null) {
      final min = seg.durationSec! ~/ 60;
      final sec = seg.durationSec! % 60;
      final dur = sec == 0 ? '$min min' : '$min min $sec seg';
      return '${block.repetitions}× $dur';
    }
    return '${block.repetitions}× —';
  }

  IconData _roleIcon(BlockRole role) {
    switch (role) {
      case BlockRole.warmup:
        return Icons.waves;
      case BlockRole.main:
        return Icons.bolt;
      case BlockRole.cooldown:
        return Icons.waves;
      case BlockRole.custom:
        return Icons.add_circle_outline;
    }
  }

  Color _roleColor(BlockRole role) {
    switch (role) {
      case BlockRole.warmup:
      case BlockRole.cooldown:
        return AppColors.rest;
      case BlockRole.main:
        return AppColors.effort;
      case BlockRole.custom:
        return AppColors.brand;
    }
  }

  List<SavedBlock> _blocksForRole(BlockRole role) =>
      _blocks.where((b) => b.role == role).toList();

  Widget _sectionHeader(BuildContext context, String label, Color color) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.l, AppSpacing.s, AppSpacing.l, AppSpacing.xs),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          letterSpacing: 1.2,
          color: color,
        ),
      ),
    );
  }

  List<Widget> _roleSection(
    BuildContext context,
    BlockRole role,
    String label,
  ) {
    final blocks = _blocksForRole(role);
    if (blocks.isEmpty) return [];
    return [
      _sectionHeader(context, label, _roleColor(role)),
      for (final saved in blocks)
        _SavedBlockTile(
          saved: saved,
          description: _blockDescription(saved),
          icon: _roleIcon(saved.role),
          iconColor: _roleColor(saved.role),
          onTap: () => Navigator.pop(context, saved),
          onDelete: () => _delete(saved),
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final sections = _loading || _error != null || _blocks.isEmpty
        ? <Widget>[]
        : [
            ..._roleSection(context, BlockRole.warmup, 'CALENTAMIENTOS'),
            ..._roleSection(context, BlockRole.main, 'BLOQUES PRINCIPALES'),
            ..._roleSection(context, BlockRole.custom, 'BLOQUES ADICIONALES'),
            ..._roleSection(context, BlockRole.cooldown, 'VUELTA A LA CALMA'),
          ];

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          margin: const EdgeInsets.only(top: 12),
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: AppColors.borderOf(context),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.l, AppSpacing.l, AppSpacing.l, AppSpacing.s),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Mis bloques guardados',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary(context),
              ),
            ),
          ),
        ),
        if (_loading)
          const Padding(
            padding: EdgeInsets.all(AppSpacing.xl),
            child: CircularProgressIndicator(),
          )
        else if (_error != null)
          Padding(
            padding: const EdgeInsets.all(AppSpacing.l),
            child: Text(
              'Error al cargar: $_error',
              style: TextStyle(color: AppColors.textSecondary(context)),
            ),
          )
        else if (_blocks.isEmpty)
          Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              children: [
                Icon(Icons.bookmark_border,
                    size: 48, color: AppColors.iconMutedOf(context)),
                const SizedBox(height: AppSpacing.m),
                Text(
                  'No tienes bloques guardados',
                  style: TextStyle(
                      fontSize: 14, color: AppColors.textSecondary(context)),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Guarda un bloque desde el editor',
                  style: TextStyle(
                      fontSize: 12, color: AppColors.textSecondary(context)),
                ),
              ],
            ),
          )
        else
          Flexible(
            child: ListView(
              shrinkWrap: true,
              children: sections,
            ),
          ),
        const SizedBox(height: AppSpacing.l),
      ],
    );
  }
}

// ── _SavedBlockTile ───────────────────────────────────────────────────────────

class _SavedBlockTile extends StatelessWidget {
  const _SavedBlockTile({
    required this.saved,
    required this.description,
    required this.icon,
    required this.iconColor,
    required this.onTap,
    required this.onDelete,
  });

  final SavedBlock saved;
  final String description;
  final IconData icon;
  final Color iconColor;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: iconColor, size: 22),
      title: Text(
        saved.name,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: AppColors.textPrimary(context),
        ),
      ),
      subtitle: Text(
        description,
        style: TextStyle(
          fontSize: 12,
          color: AppColors.textSecondary(context),
        ),
      ),
      trailing: IconButton(
        icon: Icon(Icons.delete_outline,
            size: 20, color: AppColors.iconMutedOf(context)),
        onPressed: onDelete,
      ),
      onTap: onTap,
    );
  }
}

// ── _SegmentChip ─────────────────────────────────────────────────────────────

class _SegmentChip extends StatelessWidget {
  const _SegmentChip({
    super.key,
    required this.index,
    required this.segment,
    required this.onEdit,
    required this.onDelete,
  });

  final int index;
  final WorkoutSegment segment;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(
            segment.type == SegmentType.interval
                ? Icons.circle
                : Icons.more_horiz,
            size: segment.type == SegmentType.interval ? 10 : 16,
            color: segment.type == SegmentType.interval
                ? AppColors.effort
                : AppColors.rest,
          ),
          const SizedBox(width: AppSpacing.s),
          Expanded(
            child: Text(
              _buildLabel(),
              style: TextStyle(
                  fontSize: 13, color: AppColors.textPrimary(context)),
            ),
          ),
          IconButton(
            icon: Icon(Icons.edit_outlined,
                size: 18, color: AppColors.iconMutedOf(context)),
            onPressed: onEdit,
            constraints: const BoxConstraints(),
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
          ),
          IconButton(
            icon: Icon(Icons.close,
                size: 18, color: AppColors.iconMutedOf(context)),
            onPressed: onDelete,
            constraints: const BoxConstraints(),
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
          ),
          ReorderableDragStartListener(
            index: index,
            child: Padding(
              padding: const EdgeInsets.only(left: AppSpacing.xs),
              child: Icon(
                Icons.drag_handle,
                size: 18,
                color: AppColors.iconMutedOf(context),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _buildLabel() {
    final base = _baseLabel();
    final target = _targetLabel();
    return target.isEmpty ? base : '$base · $target';
  }

  String _baseLabel() {
    if (segment.type == SegmentType.interval) {
      if (segment.distanceM != null) {
        return '${segment.distanceM}m';
      }
      final sec = segment.durationSec!;
      return _formatDuration(sec);
    } else {
      final sec =
          segment.durationSec ?? (segment.distanceM != null ? null : null);
      if (sec != null) return '${_formatDuration(sec)} descanso';
      if (segment.distanceM != null) return '${segment.distanceM}m descanso';
      return 'Descanso';
    }
  }

  String _targetLabel() {
    final t = segment.target;
    if (t == null) return '';
    if (t.paceMinSecPerKm != null || t.paceMaxSecPerKm != null) {
      if (t.paceMinSecPerKm != null && t.paceMaxSecPerKm != null) {
        return '${_formatPace(t.paceMinSecPerKm!)}–${_formatPace(t.paceMaxSecPerKm!)}/km';
      }
      final pace = t.paceMinSecPerKm ?? t.paceMaxSecPerKm!;
      return '${_formatPace(pace)}/km';
    }
    if (t.zone != null) return t.zone!.name.toUpperCase();
    if (t.rpe != null) return 'RPE ${t.rpe}';
    return '';
  }

  String _formatPace(int secPerKm) {
    final min = secPerKm ~/ 60;
    final sec = secPerKm % 60;
    return '$min:${sec.toString().padLeft(2, '0')}';
  }

  String _formatDuration(int totalSec) {
    if (totalSec < 60) return '$totalSec seg';
    final min = totalSec ~/ 60;
    final sec = totalSec % 60;
    if (sec == 0) return '$min min';
    return '$min min $sec seg';
  }
}
