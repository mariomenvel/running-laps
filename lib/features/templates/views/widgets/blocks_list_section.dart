import 'package:flutter/material.dart';
import 'package:running_laps/core/theme/app_colors.dart';
import 'package:running_laps/core/theme/app_theme.dart';
import 'package:running_laps/features/templates/data/workout_block.dart';
import 'package:running_laps/features/templates/data/workout_segment.dart';
import 'package:running_laps/features/templates/data/workout_session.dart';
import 'package:running_laps/features/templates/views/widgets/segment_bottom_sheet.dart';

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

        // 2. Lista de bloques
        ...ordered.map((block) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.s),
              child: _WorkoutBlockCard(
                block: block,
                workoutType: widget.workoutType,
                onChanged: _updateBlock,
                onDelete: () => _deleteBlock(block),
                onAddSegment: () => _addSegment(block),
                onEditSegment: (seg) => _editSegment(block, seg),
              ),
            )),

        // 3. Botón añadir bloque
        if (_showAddBlock)
          _GhostButton(
            label: 'Añadir bloque',
            onTap: _addMainBlock,
            context: context,
            color: AppColors.brand,
          ),

        // 4. Botón añadir vuelta a la calma
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
    required this.block,
    required this.workoutType,
    required this.onChanged,
    required this.onDelete,
    required this.onAddSegment,
    required this.onEditSegment,
  });

  final WorkoutBlock block;
  final WorkoutType workoutType;
  final void Function(WorkoutBlock) onChanged;
  final VoidCallback onDelete;
  final VoidCallback onAddSegment;
  final void Function(WorkoutSegment) onEditSegment;

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
              onReorder: (oldIndex, newIndex) {
                final segments = List<WorkoutSegment>.of(block.segments);
                if (newIndex > oldIndex) newIndex--;
                final seg = segments.removeAt(oldIndex);
                segments.insert(newIndex, seg);
                onChanged(block.copyWith(segments: segments));
              },
              children: [
                for (final seg in block.segments)
                  _SegmentChip(
                    key: ValueKey(seg.id),
                    segment: seg,
                    onEdit: () => onEditSegment(seg),
                    onDelete: () {
                      final segs = block.segments
                          .where((s) => s.id != seg.id)
                          .toList();
                      onChanged(block.copyWith(segments: segs));
                    },
                  ),
              ],
            )
          else
            Column(
              children: block.segments
                  .map((seg) => _SegmentChip(
                        segment: seg,
                        onEdit: () => onEditSegment(seg),
                        onDelete: () {
                          final segs = block.segments
                              .where((s) => s.id != seg.id)
                              .toList();
                          onChanged(block.copyWith(segments: segs));
                        },
                      ))
                  .toList(),
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

// ── _SegmentChip ─────────────────────────────────────────────────────────────

class _SegmentChip extends StatelessWidget {
  const _SegmentChip({
    super.key,
    required this.segment,
    required this.onEdit,
    required this.onDelete,
  });

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
    // Prioridad: pace > zone > rpe
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
