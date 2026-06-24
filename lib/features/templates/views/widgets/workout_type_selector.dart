import 'package:flutter/material.dart';
import 'package:running_laps/core/theme/app_colors.dart';
import 'package:running_laps/features/templates/data/workout_session.dart';

class WorkoutTypeSelector extends StatelessWidget {
  final WorkoutType? selected;
  final ValueChanged<WorkoutType> onSelected;

  const WorkoutTypeSelector({
    super.key,
    required this.selected,
    required this.onSelected,
  });

  static const _types = [
    (WorkoutType.continuous,  'Continuo',    Icons.directions_run_outlined),
    (WorkoutType.intervals,   'Series',      Icons.repeat_outlined),
    (WorkoutType.hills,       'Cuestas',     Icons.landscape_outlined),
    (WorkoutType.competition, 'Competición', Icons.emoji_events_outlined),
    (WorkoutType.fartlek,     'Fartlek',     Icons.shuffle_outlined),
  ];

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _types.map((t) {
        final (type, label, icon) = t;
        final isSelected = selected == type;
        return GestureDetector(
          onTap: () => onSelected(type),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppColors.brand.withValues(alpha: 0.10)
                  : AppColors.surface2Of(context),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isSelected
                    ? AppColors.brand
                    : AppColors.borderOf(context),
                width: isSelected ? 1.5 : 0.5,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: 15,
                  color: isSelected
                      ? AppColors.brand
                      : AppColors.iconMutedOf(context),
                ),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight:
                        isSelected ? FontWeight.w600 : FontWeight.w400,
                    color: isSelected
                        ? AppColors.brand
                        : AppColors.textSecondary(context),
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}
