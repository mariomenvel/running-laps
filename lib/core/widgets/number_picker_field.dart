import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:running_laps/core/theme/app_colors.dart';
import 'package:running_laps/core/theme/app_theme.dart';

class NumberPickerField extends StatelessWidget {
  final String label;
  final int value;
  final int min;
  final int max;
  final int step;
  final String unit;
  final ValueChanged<int> onChanged;

  const NumberPickerField({
    super.key,
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.step,
    required this.unit,
    required this.onChanged,
  });

  void _showPicker(BuildContext context) {
    int tempValue = value.clamp(min, max);
    final itemCount = (max - min) ~/ step + 1;
    final initialItem = ((tempValue - min) ~/ step).clamp(0, itemCount - 1);

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          height: 300,
          decoration: BoxDecoration(
            color: AppColors.surfaceOf(context),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: Column(
            children: [
              // Handle bar
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.borderOf(context),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              // Header
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.m, vertical: AppSpacing.s),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      child: Text(
                        'Cancelar',
                        style: AppTypography.body.copyWith(
                          color: AppColors.textSecondary(context),
                        ),
                      ),
                    ),
                    Text(
                      label,
                      style: AppTypography.body.copyWith(
                        color: AppColors.textPrimary(context),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.of(ctx).pop();
                        onChanged(tempValue);
                      },
                      child: Text(
                        'Hecho',
                        style: AppTypography.body.copyWith(
                          color: AppColors.brand,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Divider(
                height: 0.5,
                thickness: 0.5,
                color: AppColors.borderOf(context),
              ),
              // Picker
              Expanded(
                child: CupertinoPicker(
                  itemExtent: 40,
                  scrollController: FixedExtentScrollController(
                      initialItem: initialItem),
                  onSelectedItemChanged: (i) {
                    tempValue = min + (i * step);
                  },
                  children: List.generate(itemCount, (i) {
                    final v = min + (i * step);
                    return Center(
                      child: Text(
                        unit.isEmpty ? '$v' : '$v $unit',
                        style: AppTypography.body.copyWith(
                          color: AppColors.textPrimary(context),
                        ),
                      ),
                    );
                  }),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showPicker(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.surfaceOf(context),
          border: Border.all(color: AppColors.borderOf(context), width: 0.5),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: AppTypography.small.copyWith(
                color: AppColors.textSecondary(context),
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  unit.isEmpty ? '$value' : '$value $unit',
                  style: AppTypography.body.copyWith(
                    color: AppColors.textPrimary(context),
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  Icons.expand_more,
                  color: AppColors.iconMutedOf(context),
                  size: 16,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
