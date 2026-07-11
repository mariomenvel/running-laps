import 'package:flutter/cupertino.dart';

/// Standard push route: native Cupertino slide-from-right.
/// Enables iOS swipe-back gesture automatically.
/// Use for all regular screen pushes.
class AppRoute<T> extends CupertinoPageRoute<T> {
  AppRoute({required Widget page, super.settings})
      : super(builder: (_) => page);
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
