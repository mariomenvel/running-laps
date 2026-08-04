import 'package:flutter/material.dart';
import 'package:running_laps/core/theme/app_colors.dart';
import 'package:running_laps/core/theme/app_theme.dart';

/// Cabecera común de los sheets de selección: cancelar · título · confirmar.
///
/// Los tres selectores de la app tenían tres patrones distintos, y hasta
/// palabras distintas para lo mismo:
/// - `number_picker_field` — cabecera "Cancelar" / **"Hecho"**
/// - `app_date_picker` — cabecera "Cancelar" / **"Confirmar"**
/// - `wheel_sheets` — un botón relleno **abajo**, y sin cancelar
///
/// Un usuario que elige una distancia, una fecha y un número en la misma
/// sesión se encontraba tres formas de decir lo mismo. Ahora es una.
///
/// Se queda "Confirmar" y no "Hecho": describe lo que va a pasar, no un estado.
class PickerSheetHeader extends StatelessWidget {
  const PickerSheetHeader({
    super.key,
    required this.title,
    required this.onCancel,
    required this.onConfirm,
    this.confirmLabel = 'Confirmar',
  });

  final String title;
  final VoidCallback onCancel;

  /// null deja el botón deshabilitado — para cuando lo elegido no es válido
  /// (una distancia de 0, por ejemplo).
  final VoidCallback? onConfirm;

  final String confirmLabel;

  @override
  Widget build(BuildContext context) {
    final habilitado = onConfirm != null;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.s,
        vertical: AppSpacing.s,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          TextButton(
            onPressed: onCancel,
            child: Text(
              'Cancelar',
              style: AppTypography.body.copyWith(
                color: AppColors.textSecondary(context),
              ),
            ),
          ),
          Flexible(
            child: Text(
              title,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: AppTypography.body.copyWith(
                color: AppColors.textPrimary(context),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          TextButton(
            onPressed: onConfirm,
            child: Text(
              confirmLabel,
              style: AppTypography.body.copyWith(
                color: habilitado
                    ? AppColors.brand
                    : AppColors.textSecondary(context).withValues(alpha: 0.5),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
