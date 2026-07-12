import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../templates/data/workout_block.dart';
import '../../templates/data/target_config.dart';
import '../../templates/data/workout_segment.dart';
import '../../templates/data/workout_session.dart';
import '../data/workout_execution_state.dart';
import 'session_screens/shared/session_theme.dart';

class BlockTransitionScreen extends StatelessWidget {
  final BlockExecutionState completedBlock;
  final BlockExecutionState nextBlock;
  final VoidCallback onContinue;
  final VoidCallback onFinishEarly;
  final WorkoutType sessionType;

  const BlockTransitionScreen({
    super.key,
    required this.completedBlock,
    required this.nextBlock,
    required this.onContinue,
    required this.onFinishEarly,
    required this.sessionType,
  });

  SessionTheme _themeForNextBlock() {
    final nextRole = nextBlock.block.role;
    if (nextRole == BlockRole.warmup || nextRole == BlockRole.cooldown) {
      return SessionTheme.forType(WorkoutType.continuous);
    }
    return SessionTheme.forType(sessionType);
  }

  String? _motivationalMessage() {
    if (nextBlock.block.role != BlockRole.main) return null;
    switch (sessionType) {
      case WorkoutType.intervals:   return 'A POR LAS SERIES';
      case WorkoutType.fartlek:     return 'A CAMBIAR DE RITMO';
      case WorkoutType.hills:       return 'A POR LAS CUESTAS';
      case WorkoutType.competition: return 'A LA LÍNEA DE SALIDA';
      case WorkoutType.continuous:  return null;
      case WorkoutType.free:        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = _themeForNextBlock();
    final gradient = theme.backgroundGradient(context);

    Widget body = SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.l),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildCompletedSection(context),
            const SizedBox(height: AppSpacing.xl),
            _buildNextSection(context, theme),
            const Spacer(),
            _buildActions(context, theme),
          ],
        ),
      ),
    );

    if (gradient != null) {
      body = Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(decoration: BoxDecoration(gradient: gradient)),
          ),
          body,
        ],
      );
    }

    return Scaffold(
      backgroundColor: AppColors.surfaceOf(context),
      body: body,
    );
  }

  Widget _buildCompletedSection(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(AppSpacing.s),
          decoration: BoxDecoration(
            color: AppColors.rpeLow.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.check, color: AppColors.rpeLow, size: 20),
        ),
        const SizedBox(width: AppSpacing.m),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _labelForRole(completedBlock.block.role),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textSecondary(context),
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Completado',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary(context),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                _statsForBlock(completedBlock),
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary(context),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildNextSection(BuildContext context, SessionTheme theme) {
    final block = nextBlock.block;
    final seg = block.segments
        .where((s) => s.type == SegmentType.interval)
        .firstOrNull;
    final roleColor = theme.primary(context);
    final motivational = _motivationalMessage();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (motivational != null) ...[
          Text(
            motivational,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: theme.primary(context),
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: AppSpacing.s),
        ],
        Text(
          'A CONTINUACIÓN',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: AppColors.textSecondary(context),
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: AppSpacing.m),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpacing.l),
          decoration: BoxDecoration(
            color: AppColors.surface2Of(context),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: theme.primary(context).withValues(alpha: 0.3),
              width: 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    _iconForRole(block.role),
                    color: roleColor,
                    size: 20,
                  ),
                  const SizedBox(width: AppSpacing.s),
                  Text(
                    _labelForRole(block.role).toUpperCase(),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.2,
                      color: roleColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.s),
              Text(
                _describeBlock(block),
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary(context),
                ),
              ),
              if (seg?.target?.paceMinSecPerKm != null ||
                  seg?.target?.paceMaxSecPerKm != null) ...[
                const SizedBox(height: AppSpacing.xs),
                Text(
                  _formatPaceRange(
                    seg?.target?.paceMinSecPerKm,
                    seg?.target?.paceMaxSecPerKm,
                  ),
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary(context),
                  ),
                ),
              ],
              if (seg?.target?.zone != null || seg?.target?.rpe != null) ...[
                const SizedBox(height: AppSpacing.xs),
                Row(
                  children: [
                    if (seg?.target?.zone != null) ...[
                      _ZoneBadge(zone: seg!.target!.zone!),
                      const SizedBox(width: AppSpacing.s),
                    ],
                    if (seg?.target?.rpe != null)
                      _RpeBadge(rpe: seg!.target!.rpe!),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActions(BuildContext context, SessionTheme theme) {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: onContinue,
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.primary(context),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Empezar ${_labelForRole(nextBlock.block.role)}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: AppSpacing.s),
                const Icon(Icons.arrow_forward, size: 18),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.m),
        TextButton(
          onPressed: onFinishEarly,
          style: TextButton.styleFrom(
            foregroundColor: AppColors.textSecondary(context),
          ),
          child: const Text('Terminar entrenamiento aquí'),
        ),
      ],
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────

  String _labelForRole(BlockRole role) {
    switch (role) {
      case BlockRole.warmup:
        return 'Calentamiento';
      case BlockRole.main:
      case BlockRole.custom:
        return 'Bloque principal';
      case BlockRole.cooldown:
        return 'Vuelta a la calma';
    }
  }

  IconData _iconForRole(BlockRole role) {
    switch (role) {
      case BlockRole.warmup:
        return Icons.waves;
      case BlockRole.main:
      case BlockRole.custom:
        return Icons.bolt;
      case BlockRole.cooldown:
        return Icons.self_improvement;
    }
  }

  String _describeBlock(WorkoutBlock block) {
    final seg = block.segments
        .where((s) => s.type == SegmentType.interval)
        .firstOrNull;
    if (seg == null) return 'Bloque libre';
    final reps = block.repetitions;
    if (seg.distanceM != null) {
      final dist = seg.distanceM!;
      final label = dist >= 1000
          ? '${(dist / 1000).toStringAsFixed(dist % 1000 == 0 ? 0 : 1)}km'
          : '${dist}m';
      return reps > 1 ? '$reps × $label' : label;
    }
    if (seg.durationSec != null) {
      final min = seg.durationSec! ~/ 60;
      return reps > 1 ? '$reps × $min min' : '$min min';
    }
    return 'Bloque libre';
  }

  String _statsForBlock(BlockExecutionState state) {
    final totalDist = state.series.fold(0, (s, r) => s + r.distanciaM);
    final avgRpe = state.series.isEmpty
        ? null
        : state.series.map((s) => s.rpe).reduce((a, b) => a + b) /
            state.series.length;
    final parts = <String>[];
    if (state.completedReps > 0) parts.add('${state.completedReps} series');
    if (totalDist > 0) {
      parts.add(totalDist >= 1000
          ? '${(totalDist / 1000).toStringAsFixed(1)}km'
          : '${totalDist}m');
    }
    if (avgRpe != null) parts.add('RPE ${avgRpe.toStringAsFixed(1)}');
    return parts.join(' · ');
  }

  String _formatPace(int secPerKm) {
    final min = secPerKm ~/ 60;
    final sec = (secPerKm % 60).toString().padLeft(2, '0');
    return '$min:$sec/km';
  }

  String _formatPaceRange(int? paceMin, int? paceMax) {
    if (paceMin != null && paceMax != null) {
      return '@ ${_formatPace(paceMin)} – ${_formatPace(paceMax)}';
    }
    if (paceMin != null) return '@ ${_formatPace(paceMin)}';
    if (paceMax != null) return '@ hasta ${_formatPace(paceMax)}';
    return '';
  }
}

// ── Sub-widgets ─────────────────────────────────────────────────────

class _ZoneBadge extends StatelessWidget {
  final HeartRateZone zone;

  const _ZoneBadge({required this.zone});

  @override
  Widget build(BuildContext context) {
    final label = 'Z${zone.index + 1}';
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.s,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: AppColors.restSurface,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.restBorder, width: 0.5),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: AppColors.rest,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _RpeBadge extends StatelessWidget {
  final int rpe;

  const _RpeBadge({required this.rpe});

  @override
  Widget build(BuildContext context) {
    final color = AppColors.effortColor(rpe.toDouble());
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.s,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: AppColors.effortSurface(rpe.toDouble()),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: AppColors.effortBorderColor(rpe.toDouble()),
          width: 0.5,
        ),
      ),
      child: Text(
        'RPE $rpe',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: color,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
