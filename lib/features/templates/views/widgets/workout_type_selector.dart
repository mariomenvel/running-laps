import 'package:flutter/material.dart';
import 'package:running_laps/core/theme/app_colors.dart';
import 'package:running_laps/core/theme/app_theme.dart';
import 'package:running_laps/features/templates/data/workout_session.dart';

class WorkoutTypeSelector extends StatelessWidget {
  const WorkoutTypeSelector({
    super.key,
    required this.selected,
    required this.onSelected,
  });

  final WorkoutType? selected;
  final void Function(WorkoutType) onSelected;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: AppSpacing.s,
      crossAxisSpacing: AppSpacing.s,
      childAspectRatio: 1,
      children: WorkoutType.values
          .map((type) => _WorkoutTypeCard(
                type: type,
                isSelected: type == selected,
                onTap: () => onSelected(type),
              ))
          .toList(),
    );
  }
}

class _WorkoutTypeCard extends StatelessWidget {
  const _WorkoutTypeCard({
    required this.type,
    required this.isSelected,
    required this.onTap,
  });

  final WorkoutType type;
  final bool isSelected;
  final VoidCallback onTap;

  static const _radius = BorderRadius.all(Radius.circular(16));

  @override
  Widget build(BuildContext context) {
    final bgColor = isSelected
        ? AppColors.brand.withValues(alpha: 0.08)
        : AppColors.surfaceOf(context);
    final borderColor = isSelected
        ? AppColors.brand
        : AppColors.borderOf(context);
    final borderWidth = isSelected ? 1.5 : 0.5;
    final iconColor = isSelected
        ? AppColors.brand
        : AppColors.iconMutedOf(context);
    final labelColor = isSelected
        ? AppColors.textPrimary(context)
        : AppColors.textSecondary(context);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(AppSpacing.l),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: _radius,
          border: Border.all(color: borderColor, width: borderWidth),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(_iconFor(type), color: iconColor, size: 28),
            const SizedBox(height: AppSpacing.s),
            Text(
              _labelFor(type),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                letterSpacing: -0.3,
                color: labelColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _iconFor(WorkoutType type) {
    switch (type) {
      case WorkoutType.continuous:
        return Icons.linear_scale;
      case WorkoutType.intervals:
        return Icons.repeat;
      case WorkoutType.fartlek:
        return Icons.shuffle;
      case WorkoutType.hills:
        return Icons.landscape;
      case WorkoutType.competition:
        return Icons.emoji_events;
      case WorkoutType.free:
        return Icons.play_circle_outline;
    }
  }

  String _labelFor(WorkoutType type) {
    switch (type) {
      case WorkoutType.continuous:
        return 'Continuo';
      case WorkoutType.intervals:
        return 'Series';
      case WorkoutType.fartlek:
        return 'Fartlek';
      case WorkoutType.hills:
        return 'Cuestas';
      case WorkoutType.competition:
        return 'Competición';
      case WorkoutType.free:
        return 'Libre';
    }
  }
}
