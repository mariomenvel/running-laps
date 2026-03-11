import 'package:flutter/material.dart';

/// Standard push route: slide from right + fade.
/// Duration: 280ms, curve: easeInOut.
/// Use for all regular screen pushes.
class AppRoute<T> extends PageRouteBuilder<T> {
  final Widget page;

  AppRoute({required this.page, super.settings})
      : super(
          pageBuilder: (context, animation, secondaryAnimation) => page,
          transitionDuration: const Duration(milliseconds: 280),
          reverseTransitionDuration: const Duration(milliseconds: 280),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            final slideAnimation = animation.drive(
              Tween(begin: const Offset(1.0, 0.0), end: Offset.zero)
                  .chain(CurveTween(curve: Curves.easeInOut)),
            );
            return FadeTransition(
              opacity: animation,
              child: SlideTransition(position: slideAnimation, child: child),
            );
          },
        );
}

/// Modal push route: slide from bottom + fade.
/// Duration: 320ms, curve: easeOutCubic.
/// Use for detail screens, editors, and reward screens.
class AppModalRoute<T> extends PageRouteBuilder<T> {
  final Widget page;

  AppModalRoute({required this.page, super.settings})
      : super(
          pageBuilder: (context, animation, secondaryAnimation) => page,
          transitionDuration: const Duration(milliseconds: 320),
          reverseTransitionDuration: const Duration(milliseconds: 320),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            final slideAnimation = animation.drive(
              Tween(begin: const Offset(0.0, 1.0), end: Offset.zero)
                  .chain(CurveTween(curve: Curves.easeOutCubic)),
            );
            return FadeTransition(
              opacity: animation,
              child: SlideTransition(position: slideAnimation, child: child),
            );
          },
        );
}
