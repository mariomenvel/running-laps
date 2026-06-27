import 'package:flutter/cupertino.dart';
import '../theme/app_colors.dart';

/// Diálogo de confirmación estilo iOS.
/// Reemplaza showDialog() + AlertDialog de Material.
///
/// Parámetros:
/// - [title] — título del diálogo
/// - [message] — mensaje explicativo (opcional)
/// - [confirmLabel] — texto del botón de confirmar (por defecto: 'Confirmar')
/// - [cancelLabel] — texto del botón de cancelar (por defecto: 'Cancelar')
/// - [isDestructive] — si true, el botón confirmar aparece en rojo;
///   si false, en AppColors.brand. NUNCA mezclar rojo y morado.
///
/// Devuelve true si confirma, false/null si cancela.
Future<bool?> showAppConfirmDialog({
  required BuildContext context,
  required String title,
  String? message,
  String confirmLabel = 'Confirmar',
  String cancelLabel = 'Cancelar',
  bool isDestructive = false,
}) async {
  return await showCupertinoDialog<bool>(
    context: context,
    barrierDismissible: true,
    builder: (ctx) => CupertinoAlertDialog(
      title: Text(title),
      content: message != null
          ? Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(message),
            )
          : null,
      actions: [
        CupertinoDialogAction(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: Text(
            cancelLabel,
            style: TextStyle(color: AppColors.textSecondary(context)),
          ),
        ),
        CupertinoDialogAction(
          isDestructiveAction: isDestructive,
          onPressed: () => Navigator.of(ctx).pop(true),
          child: Text(
            confirmLabel,
            style: isDestructive
                ? null
                : const TextStyle(
                    color: AppColors.brand,
                    fontWeight: FontWeight.w600,
                  ),
          ),
        ),
      ],
    ),
  );
}
