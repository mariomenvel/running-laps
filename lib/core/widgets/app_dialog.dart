import 'package:flutter/material.dart';
import 'package:running_laps/core/theme/app_colors.dart';
import 'package:running_laps/core/theme/app_theme.dart';

/// Diálogo modal de Running Laps — **uno solo para Android e iOS**.
///
/// Antes esto era un `CupertinoAlertDialog`. Se veía viejo porque *es* viejo:
/// el `CupertinoAlertDialog` de Flutter sigue siendo el lenguaje de iOS 13
/// (bordes duros, botones apilados a todo el ancho, texto apretado), y encima
/// en Android desentonaba con el resto de la app.
///
/// ¿Por qué no uno nativo por plataforma? Porque los diálogos no son una isla:
/// por convención del proyecto **ningún número se teclea** (ruedas `IosPicker`),
/// las fechas van en `CupertinoDatePicker` y los sheets llevan handle. Poner
/// diálogos Material en Android los dejaría chocando con todo lo demás; para
/// que "nativo en cada plataforma" tuviera sentido habría que adaptar el
/// sistema de diseño entero. Y el *liquid glass* de iOS 26 Flutter no lo trae:
/// habría que implementarlo a mano, solo para una plataforma que hoy ni
/// siquiera se puede compilar.
///
/// Así que una cara propia, construida con los tokens de la app. Es lo que
/// hacen las apps con identidad fuerte: no se lee como "está mal", se lee como
/// "está diseñado".
class AppDialog extends StatelessWidget {
  const AppDialog({
    super.key,
    required this.title,
    this.message,
    this.content,
    required this.actions,
  });

  final String title;

  /// Texto explicativo bajo el título. Opcional.
  final String? message;

  /// Contenido propio (un campo de texto, por ejemplo) bajo el mensaje.
  final Widget? content;

  /// Botones. Se colocan en fila; si no caben, se apilan.
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xl,
        vertical: AppSpacing.xl,
      ),
      child: ConstrainedBox(
        // En tablet y web un diálogo a todo el ancho se lee fatal.
        constraints: const BoxConstraints(maxWidth: 400),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.xl),
          decoration: BoxDecoration(
            color: AppColors.surfaceOf(context),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.18),
                blurRadius: 32,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: AppTypography.h3.copyWith(
                  color: AppColors.textPrimary(context),
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (message != null) ...[
                const SizedBox(height: AppSpacing.s),
                Text(
                  message!,
                  style: AppTypography.body.copyWith(
                    color: AppColors.textSecondary(context),
                  ),
                ),
              ],
              if (content != null) ...[
                const SizedBox(height: AppSpacing.l),
                content!,
              ],
              const SizedBox(height: AppSpacing.xl),
              _Actions(actions: actions),
            ],
          ),
        ),
      ),
    );
  }
}

/// Fila de botones que se apila cuando las etiquetas no caben.
///
/// La primera versión decidía por el ancho disponible ("si hay más de 260 px,
/// caben"). No servía: con "No, preguntar siempre" al lado de "Borrar y
/// generar" el diálogo desbordaba aunque hubiera 352 px. Ahora se **mide** el
/// texto con un `TextPainter` y se apila si de verdad no entra.
class _Actions extends StatelessWidget {
  const _Actions({required this.actions});

  final List<Widget> actions;

  /// Ancho que necesita una etiqueta en una sola línea, más el padding
  /// horizontal del botón.
  static double _anchoNecesario(String label, TextStyle style, double escala) {
    final painter = TextPainter(
      text: TextSpan(text: label, style: style),
      textDirection: TextDirection.ltr,
      textScaler: TextScaler.linear(escala),
    )..layout();
    return painter.width + AppSpacing.xl; // 12 de padding a cada lado
  }

  static String? _labelDe(Widget w) {
    if (w is AppDialogPrimaryAction) return w.label;
    if (w is AppDialogSecondaryAction) return w.label;
    return null;
  }

  @override
  Widget build(BuildContext context) {
    if (actions.length < 2) {
      return Row(children: [for (final a in actions) Expanded(child: a)]);
    }

    final estilo = AppTypography.body.copyWith(fontWeight: FontWeight.w600);
    // Respeta el tamaño de fuente del sistema: con accesibilidad al máximo,
    // etiquetas que caben en un móvil normal dejan de caber.
    final escala = MediaQuery.textScalerOf(context).scale(1.0);

    return LayoutBuilder(
      builder: (context, constraints) {
        final labels = actions.map(_labelDe).toList();
        final medibles = labels.every((l) => l != null);

        var cabenEnFila = false;
        if (medibles) {
          final huecos = AppSpacing.m * (actions.length - 1);
          final necesario = labels.fold<double>(
                0,
                (acc, l) => acc + _anchoNecesario(l!, estilo, escala),
              ) +
              huecos;
          cabenEnFila = necesario <= constraints.maxWidth;
        }

        if (cabenEnFila) {
          return Row(
            children: [
              for (var i = 0; i < actions.length; i++) ...[
                if (i > 0) const SizedBox(width: AppSpacing.m),
                Expanded(child: actions[i]),
              ],
            ],
          );
        }

        // Apilados: la acción principal arriba, que es la que se busca.
        final ordenados = actions.reversed.toList();
        return Column(
          children: [
            for (var i = 0; i < ordenados.length; i++) ...[
              if (i > 0) const SizedBox(height: AppSpacing.s),
              SizedBox(width: double.infinity, child: ordenados[i]),
            ],
          ],
        );
      },
    );
  }
}

/// Botón secundario de un [AppDialog] — el que **no** ejecuta la acción.
class AppDialogSecondaryAction extends StatelessWidget {
  const AppDialogSecondaryAction({
    super.key,
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.l),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: AppColors.borderOf(context)),
        ),
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: AppTypography.body.copyWith(
          fontWeight: FontWeight.w600,
          color: AppColors.textSecondary(context),
        ),
      ),
    );
  }
}

/// Botón principal de un [AppDialog] — el que ejecuta la acción.
///
/// [isDestructive] lo pinta en rojo. Nunca mezclar rojo y morado en el mismo
/// diálogo: el color dice si lo que va a pasar se puede deshacer.
class AppDialogPrimaryAction extends StatelessWidget {
  const AppDialogPrimaryAction({
    super.key,
    required this.label,
    required this.onPressed,
    this.isDestructive = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool isDestructive;

  @override
  Widget build(BuildContext context) {
    final habilitado = onPressed != null;
    final fondo = isDestructive ? AppColors.rpeMax : AppColors.brand;

    return FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: habilitado ? fondo : fondo.withValues(alpha: 0.35),
        disabledBackgroundColor: fondo.withValues(alpha: 0.35),
        foregroundColor: Colors.white,
        disabledForegroundColor: Colors.white.withValues(alpha: 0.7),
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.l),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: AppTypography.body.copyWith(fontWeight: FontWeight.w600),
      ),
    );
  }
}
