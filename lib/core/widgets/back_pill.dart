import 'package:flutter/material.dart';
import 'package:running_laps/core/theme/app_colors.dart';

/// Pill "Volver" estándar para vistas pusheadas: única affordance visible de
/// volver atrás (el header global no lleva flecha — la navegación es por
/// gesto: swipe en iOS, botón/gesto del sistema en Android).
///
/// Va al principio del contenido, bajo el [AppHeader]:
/// ```dart
/// Row(children: [BackPill(onTap: () => Navigator.pop(context))])
/// ```
class BackPill extends StatefulWidget {
  final VoidCallback onTap;
  final String label;

  /// Acento opcional (icono, texto y borde). Por defecto,
  /// `AppColors.brandOf(context)`.
  final Color? color;

  const BackPill({
    super.key,
    required this.onTap,
    this.label = 'Volver',
    this.color,
  });

  @override
  State<BackPill> createState() => _BackPillState();
}

class _BackPillState extends State<BackPill> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) {
        setState(() => _isPressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: _isPressed
              ? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.08)
              : Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.transparent
                  : Colors.black.withValues(alpha: _isPressed ? 0.03 : 0.06),
              blurRadius: _isPressed ? 4 : 12,
              offset: Offset(0, _isPressed ? 2 : 4),
            ),
          ],
          border: Border.all(
            color: (widget.color ?? AppColors.brand).withValues(alpha: 0.1),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.arrow_back_ios_new_rounded,
              size: 16,
              color: widget.color ?? AppColors.brandOf(context),
            ),
            const SizedBox(width: 6),
            Text(
              widget.label,
              style: TextStyle(
                color: widget.color ?? AppColors.brandOf(context),
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
