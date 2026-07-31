import 'package:flutter/cupertino.dart';
import '../theme/app_colors.dart';

/// Diálogo de entrada de **texto** estilo iOS — la contraparte de
/// [showAppConfirmDialog] para cuando hace falta pedir un nombre.
/// Reemplaza showDialog() + AlertDialog + TextField de Material.
///
/// Solo para texto libre: cualquier campo **numérico** debe usar
/// `NumberPickerField` / `IosPicker`, nunca un teclado (ver CLAUDE.md).
///
/// Parámetros:
/// - [title] — título del diálogo
/// - [hintText] — placeholder del campo
/// - [initialValue] — texto precargado (queda preseleccionado)
/// - [maxLength] — límite de caracteres
/// - [confirmLabel] / [cancelLabel] — textos de los botones
///
/// Devuelve el texto recortado si confirma, o null si cancela (también al
/// tocar fuera). Nunca devuelve una cadena vacía: el botón de confirmar
/// permanece deshabilitado mientras el campo esté en blanco.
Future<String?> showAppPromptDialog({
  required BuildContext context,
  required String title,
  String? hintText,
  String? initialValue,
  int? maxLength,
  String confirmLabel = 'Guardar',
  String cancelLabel = 'Cancelar',
}) async {
  final controller = TextEditingController(text: initialValue ?? '');
  controller.selection = TextSelection(
    baseOffset: 0,
    extentOffset: controller.text.length,
  );

  try {
    return await showCupertinoDialog<String>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => _PromptDialog(
        controller: controller,
        title: title,
        hintText: hintText,
        maxLength: maxLength,
        confirmLabel: confirmLabel,
        cancelLabel: cancelLabel,
      ),
    );
  } finally {
    controller.dispose();
  }
}

class _PromptDialog extends StatefulWidget {
  const _PromptDialog({
    required this.controller,
    required this.title,
    required this.hintText,
    required this.maxLength,
    required this.confirmLabel,
    required this.cancelLabel,
  });

  final TextEditingController controller;
  final String title;
  final String? hintText;
  final int? maxLength;
  final String confirmLabel;
  final String cancelLabel;

  @override
  State<_PromptDialog> createState() => _PromptDialogState();
}

class _PromptDialogState extends State<_PromptDialog> {
  @override
  Widget build(BuildContext context) {
    // El botón se habilita/deshabilita en vivo, igual que hacía el
    // FilledButton del AlertDialog al que sustituye.
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: widget.controller,
      builder: (ctx, value, _) {
        final text = value.text.trim();
        final canConfirm = text.isNotEmpty;
        return CupertinoAlertDialog(
          title: Text(widget.title),
          content: Padding(
            padding: const EdgeInsets.only(top: 12),
            child: CupertinoTextField(
              controller: widget.controller,
              autofocus: true,
              maxLength: widget.maxLength,
              placeholder: widget.hintText,
              textCapitalization: TextCapitalization.sentences,
              onSubmitted: (_) {
                if (canConfirm) Navigator.of(ctx).pop(text);
              },
            ),
          ),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(
                widget.cancelLabel,
                style: TextStyle(color: AppColors.textSecondary(context)),
              ),
            ),
            CupertinoDialogAction(
              onPressed: canConfirm ? () => Navigator.of(ctx).pop(text) : null,
              child: Text(
                widget.confirmLabel,
                style: TextStyle(
                  color: canConfirm
                      ? AppColors.brand
                      : AppColors.textSecondary(context),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
