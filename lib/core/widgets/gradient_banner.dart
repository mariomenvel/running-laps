import 'package:flutter/material.dart';
import 'package:running_laps/config/app_theme.dart';

/// Banner decorativo con gradiente para secciones del módulo de grupos.
/// Ofrece una estética premium con animaciones sutiles.
class GradientBanner extends StatefulWidget {
  final String title;
  final String? subtitle;
  final IconData? icon;
  final List<Color>? gradientColors;
  final double height;
  final EdgeInsets? padding;
  final Widget? trailing;
  final bool animate;

  const GradientBanner({
    Key? key,
    required this.title,
    this.subtitle,
    this.icon,
    this.gradientColors,
    this.height = 100,
    this.padding,
    this.trailing,
    this.animate = true,
  }) : super(key: key);

  @override
  State<GradientBanner> createState() => _GradientBannerState();
}

class _GradientBannerState extends State<GradientBanner>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -0.2),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    ));

    if (widget.animate) {
      _controller.forward();
    } else {
      _controller.value = 1.0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = widget.gradientColors ??
        [
          Tema.brandPurple,
          Tema.brandPurple.withOpacity(0.7),
        ];

    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: Container(
          constraints: BoxConstraints(minHeight: widget.height),
          margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          padding: widget.padding ?? const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: colors,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: colors.first.withOpacity(0.3),
                blurRadius: 20,
                offset: const Offset(0, 8),
                spreadRadius: -4,
              ),
            ],
          ),
          child: Row(
            children: [
              if (widget.icon != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    widget.icon,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      widget.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                    ),
                    if (widget.subtitle != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        widget.subtitle!,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.85),
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (widget.trailing != null) widget.trailing!,
            ],
          ),
        ),
      ),
    );
  }
}

/// Variante pequeña del banner para indicadores de estado
class GradientChip extends StatelessWidget {
  final String label;
  final IconData? icon;
  final List<Color>? gradientColors;
  final VoidCallback? onTap;

  const GradientChip({
    Key? key,
    required this.label,
    this.icon,
    this.gradientColors,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final colors = gradientColors ??
        [
          Tema.brandPurple,
          Tema.brandPurple.withOpacity(0.7),
        ];

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: colors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: colors.first.withOpacity(0.25),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, color: Colors.white, size: 16),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

