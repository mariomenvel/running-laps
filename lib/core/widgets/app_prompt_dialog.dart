import 'package:flutter/material.dart';
import 'package:running_laps/core/theme/app_colors.dart';
import 'package:running_laps/core/theme/app_theme.dart';
import 'package:running_laps/core/widgets/app_dialog.dart';

/// Diálogo de entrada de **texto** — la contraparte de [showAppConfirmDialog]
/// para cuando hace falta pedir un nombre.
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
}) {
  // El controller lo crea y libera el propio diálogo. Antes se creaba aquí y
  // se liberaba en un `finally` nada más volver de showDialog — pero la
  // animación de cierre sigue viva en ese momento y el TextField todavía lo
  // referencia, lo que reventaba el scope de foco (`_dependents.isEmpty`).
  return showDialog<String>(
    context: context,
    barrierDismissible: true,
    barrierColor: Colors.black.withValues(alpha: 0.45),
    builder: (ctx) => _PromptDialog(
      initialValue: initialValue,
      title: title,
      hintText: hintText,
      maxLength: maxLength,
      confirmLabel: confirmLabel,
      cancelLabel: cancelLabel,
    ),
  );
}

class _PromptDialog extends StatefulWidget {
  const _PromptDialog({
    required this.initialValue,
    required this.title,
    required this.hintText,
    required this.maxLength,
    required this.confirmLabel,
    required this.cancelLabel,
  });

  final String? initialValue;
  final String title;
  final String? hintText;
  final int? maxLength;
  final String confirmLabel;
  final String cancelLabel;

  @override
  State<_PromptDialog> createState() => _PromptDialogState();
}

class _PromptDialogState extends State<_PromptDialog> {
  late final TextEditingController controller;

  @override
  void initState() {
    super.initState();
    controller = TextEditingController(text: widget.initialValue ?? '');
    // Preseleccionado: escribir encima reemplaza el nombre por defecto en vez
    // de concatenarse a él.
    controller.selection = TextSelection(
      baseOffset: 0,
      extentOffset: controller.text.length,
    );
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  void _confirmar(BuildContext ctx) {
    final text = controller.text.trim();
    if (text.isNotEmpty) Navigator.of(ctx).pop(text);
  }

  @override
  Widget build(BuildContext context) {
    // ⚠️ El TextField se construye UNA vez, fuera del ValueListenableBuilder.
    // Envolver el diálogo entero en el listener lo reconstruía en cada tecla y,
    // con `autofocus: true`, eso revienta el scope de foco de Flutter
    // (`_dependents.isEmpty`). Solo el botón depende de lo que hay escrito.
    final campo = TextField(
      controller: controller,
      autofocus: true,
      maxLength: widget.maxLength,
      textCapitalization: TextCapitalization.sentences,
      style: AppTypography.body.copyWith(
        color: AppColors.textPrimary(context),
        fontSize: 16,
      ),
      decoration: InputDecoration(
        hintText: widget.hintText,
        hintStyle: AppTypography.body.copyWith(
          color: AppColors.textSecondary(context),
          fontSize: 16,
        ),
        counterText: '',
        filled: true,
        fillColor: AppColors.surface2Of(context),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.l,
          vertical: AppSpacing.m,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: AppColors.borderOf(context)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.brand, width: 1.5),
        ),
      ),
      onSubmitted: (_) => _confirmar(context),
    );

    return AppDialog(
      title: widget.title,
      content: campo,
      actions: [
        AppDialogSecondaryAction(
          label: widget.cancelLabel,
          onPressed: () => Navigator.of(context).pop(),
        ),
        // Solo esto se repinta al escribir.
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: controller,
          builder: (ctx, value, _) => AppDialogPrimaryAction(
            label: widget.confirmLabel,
            onPressed: value.text.trim().isEmpty
                ? null
                : () => _confirmar(context),
          ),
        ),
      ],
    );
  }
}
