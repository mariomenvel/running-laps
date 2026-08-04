import 'package:flutter/material.dart';
import 'package:running_laps/core/widgets/app_dialog.dart';

/// Diálogo de confirmación. Única forma permitida de preguntar
/// "¿seguro?" en la app.
///
/// Antes era un `CupertinoAlertDialog`; ahora se apoya en [AppDialog], que es
/// la misma cara en Android e iOS. La API no cambia — los 16 call sites siguen
/// funcionando igual.
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
}) {
  return showDialog<bool>(
    context: context,
    barrierDismissible: true,
    barrierColor: Colors.black.withValues(alpha: 0.45),
    builder: (ctx) => AppDialog(
      title: title,
      message: message,
      actions: [
        AppDialogSecondaryAction(
          label: cancelLabel,
          onPressed: () => Navigator.of(ctx).pop(false),
        ),
        AppDialogPrimaryAction(
          label: confirmLabel,
          isDestructive: isDestructive,
          onPressed: () => Navigator.of(ctx).pop(true),
        ),
      ],
    ),
  );
}
