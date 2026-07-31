import 'package:flutter/material.dart';
import 'package:running_laps/core/theme/app_colors.dart';

/// Fila "etiqueta — valor tocable — limpiar" que comparten los campos que se
/// rellenan con una rueda ([DurationPickerField], [DistancePickerField]).
///
/// El valor es nullable a propósito: en casi todos estos campos el vacío
/// significa algo distinto de cero ("no tengo esa marca", "sin límite de
/// distancia"). Como una rueda no puede devolver "nada", el botón de limpiar
/// es la única vía de vuelta a ese estado — por eso está aquí y no es opcional.
class WheelValueField extends StatelessWidget {
  const WheelValueField({
    super.key,
    required this.label,
    required this.display,
    required this.hasValue,
    required this.onTap,
    required this.onClear,
    this.labelWidth = 110,
    this.valueWidth = 92,
  });

  final String label;

  /// Texto ya formateado del valor (o del placeholder si [hasValue] es false).
  final String display;

  final bool hasValue;
  final VoidCallback onTap;
  final VoidCallback onClear;
  final double labelWidth;
  final double valueWidth;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: labelWidth,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: AppColors.textPrimary(context),
            ),
          ),
        ),
        const Spacer(),
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: valueWidth,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.surface2Of(context),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              display,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: hasValue ? FontWeight.w600 : FontWeight.normal,
                color: hasValue
                    ? AppColors.textPrimary(context)
                    : AppColors.textSecondary(context),
              ),
            ),
          ),
        ),
        SizedBox(
          width: 40,
          child: hasValue
              ? IconButton(
                  icon: const Icon(Icons.backspace_outlined, size: 18),
                  tooltip: 'Quitar $label',
                  color: AppColors.textSecondary(context),
                  onPressed: onClear,
                )
              : null,
        ),
      ],
    );
  }
}
