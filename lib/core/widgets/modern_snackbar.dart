import 'package:flutter/material.dart';

/// Helper para mostrar SnackBars modernos con estética iOS
class ModernSnackBar {
  /// Muestra un SnackBar de éxito (verde)
  static void showSuccess(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 3),
    SnackBarAction? action,
  }) {
    _show(
      context,
      message,
      backgroundColor: const Color(0xFF10B981), // Verde moderno
      icon: Icons.check_circle_rounded,
      duration: duration,
      action: action,
    );
  }

  /// Muestra un SnackBar de error (rojo)
  static void showError(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 4),
    SnackBarAction? action,
  }) {
    _show(
      context,
      message,
      backgroundColor: const Color(0xFFEF4444), // Rojo moderno
      icon: Icons.error_rounded,
      duration: duration,
      action: action,
    );
  }

  /// Muestra un SnackBar de advertencia (naranja/amarillo)
  static void showWarning(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 3),
    SnackBarAction? action,
  }) {
    _show(
      context,
      message,
      backgroundColor: const Color(0xFFF59E0B), // Naranja moderno
      icon: Icons.warning_rounded,
      duration: duration,
      action: action,
    );
  }

  /// Muestra un SnackBar informativo (azul)
  static void showInfo(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 3),
    SnackBarAction? action,
  }) {
    _show(
      context,
      message,
      backgroundColor: const Color(0xFF3B82F6), // Azul moderno
      icon: Icons.info_rounded,
      duration: duration,
      action: action,
    );
  }

  /// Muestra un SnackBar genérico (morado de la marca)
  static void show(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 3),
    Color? backgroundColor,
    IconData? icon,
  }) {
    _show(
      context,
      message,
      backgroundColor: backgroundColor ?? const Color(0xFF8E24AA),
      icon: icon,
      duration: duration,
    );
  }

  /// Método interno para mostrar el SnackBar
  static void _show(
    BuildContext context,
    String message, {
    required Color backgroundColor,
    IconData? icon,
    required Duration duration,
    SnackBarAction? action,
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            if (icon != null) ...[
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.25),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.15),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Icon(
                  icon,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
            ],
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.3,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: backgroundColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        duration: duration,
        elevation: 12,
        action: action,
      ),
    );
  }
}

