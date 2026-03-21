import 'dart:math' show pi;
import 'package:flutter/material.dart';
import 'package:running_laps/config/app_theme.dart';
import 'package:running_laps/core/theme/app_colors.dart';

/// Reusable empty-state component consistent with the app's light+purple style.
///
/// Usage:
/// ```dart
/// EmptyStateWidget(
///   icon: Icons.directions_run_rounded,
///   title: 'Aún no has entrenado',
///   description: 'Empieza tu primer entrenamiento...',
///   ctaLabel: 'Entrenar ahora',
///   onCta: () { ... },
/// )
/// ```
class EmptyStateWidget extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;

  /// Optional CTA button label. Requires [onCta] to be non-null.
  final String? ctaLabel;

  /// Optional CTA callback. Requires [ctaLabel] to be non-null.
  final VoidCallback? onCta;

  const EmptyStateWidget({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    this.ctaLabel,
    this.onCta,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40.0, vertical: 24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _EmptyIllustration(icon: icon),
            const SizedBox(height: 28),
            Text(
              title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
                letterSpacing: -0.3,
                height: 1.2,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              description,
              style: TextStyle(
                fontSize: 14,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            if (ctaLabel != null && onCta != null) ...[
              const SizedBox(height: 28),
              SizedBox(
                height: 48,
                child: ElevatedButton(
                  onPressed: onCta,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Tema.brandPurple,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 28),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                  ),
                  child: Text(
                    ctaLabel!,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Private illustration: geometric rings (CustomPaint) + icon
// ---------------------------------------------------------------------------

class _EmptyIllustration extends StatelessWidget {
  final IconData icon;
  const _EmptyIllustration({required this.icon});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _RingsPainter(),
      child: SizedBox(
        width: 120,
        height: 120,
        child: Center(
          child: Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  Tema.brandPurple.withOpacity(0.14),
                  Tema.brandPurple.withOpacity(0.05),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Icon(
              icon,
              size: 34,
              color: (Theme.of(context).brightness == Brightness.dark ? AppColors.brandPurpleLight : Tema.brandPurple).withOpacity(0.75),
            ),
          ),
        ),
      ),
    );
  }
}

/// Draws two subtle concentric arc-ring segments around the icon
/// to give the illustration a lightweight geometric character.
class _RingsPainter extends CustomPainter {
  const _RingsPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // Outer dashed-arc ring
    paint
      ..strokeWidth = 1.5
      ..color = Tema.brandPurple.withOpacity(0.10);
    canvas.drawCircle(center, size.width / 2 - 2, paint);

    // Inner decorative arc (270° sweep, starting top-right)
    paint
      ..strokeWidth = 2.5
      ..color = Tema.brandPurple.withOpacity(0.16);
    final rect = Rect.fromCircle(center: center, radius: size.width / 2 - 10);
    canvas.drawArc(rect, -pi / 4, 3 * pi / 2, false, paint);
  }

  @override
  bool shouldRepaint(_RingsPainter old) => false;
}
