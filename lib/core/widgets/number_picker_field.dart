import 'package:flutter/material.dart';
import 'package:running_laps/core/widgets/picker_sheet_header.dart';
import 'package:running_laps/core/theme/app_colors.dart';
import 'package:running_laps/core/theme/app_theme.dart';
import 'package:running_laps/core/widgets/ios_picker.dart';

class NumberPickerField extends StatelessWidget {
  final String label;
  final int value;
  final int min;
  final int max;
  final int step;
  final String unit;
  final ValueChanged<int> onChanged;

  /// Texto a mostrar en vez del número. Para campos que aún no tienen valor:
  /// sin esto, un `value` de relleno (`_algo ?? 5`) se ve idéntico a un valor
  /// elegido por el usuario, y el campo miente.
  final String? displayOverride;

  const NumberPickerField({
    super.key,
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.step,
    required this.unit,
    required this.onChanged,
    this.displayOverride,
  });

  void _showPicker(BuildContext context) {
    int tempValue = value.clamp(min, max);
    final itemCount = (max - min) ~/ step + 1;
    final initialItem = ((tempValue - min) ~/ step).clamp(0, itemCount - 1);

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      sheetAnimationStyle: AnimationStyle(
        duration: AppMotion.slow,
        reverseDuration: AppMotion.slow,
      ),
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
              PickerSheetHeader(
                title: label,
                onCancel: () => Navigator.of(ctx).pop(),
                onConfirm: () {
                  Navigator.of(ctx).pop();
                  onChanged(tempValue);
                },
              ),
              Divider(
                height: 0.5,
                thickness: 0.5,
                color: AppColors.borderOf(context),
              ),
              // Picker
              Expanded(
                child: Center(
                  child: IosPicker(
                    itemCount: itemCount,
                    initialItem: initialItem,
                    itemExtent: 40,
                    width: 160,
                    textBuilder: (i) {
                      final v = min + (i * step);
                      return unit.isEmpty ? '$v' : '$v $unit';
                    },
                    onChanged: (i) {
                      tempValue = min + (i * step);
                    },
                  ),
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
                  displayOverride ??
                      (unit.isEmpty ? '$value' : '$value $unit'),
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
