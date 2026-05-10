import 'package:flutter/material.dart';
import 'package:running_laps/core/theme/app_colors.dart';
import 'package:running_laps/features/auth/views/auth_wrapper.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  // 0–600ms (0.0–0.30): logo fades in + scales up
  late Animation<double> _logoOpacity;
  late Animation<double> _logoScaleIn;

  // 900–1400ms (0.45–0.70): logo scales down + moves up
  late Animation<double> _logoScaleOut;
  late Animation<double> _logoOffsetY;

  // 1400–1800ms (0.70–0.90): text fades in
  late Animation<double> _textOpacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );

    _logoOpacity = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.30, curve: Curves.fastOutSlowIn),
      ),
    );
    _logoScaleIn = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.30, curve: Curves.fastOutSlowIn),
      ),
    );
    _logoScaleOut = Tween<double>(begin: 1.0, end: 0.5).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.45, 0.70, curve: Curves.fastOutSlowIn),
      ),
    );
    _logoOffsetY = Tween<double>(begin: 0, end: -80).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.45, 0.70, curve: Curves.fastOutSlowIn),
      ),
    );
    _textOpacity = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.70, 0.90, curve: Curves.easeOut),
      ),
    );

    _controller.forward().then((_) {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const AuthWrapper()),
      );
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      body: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          // Blend between scale-in and scale-out phases
          final scale = _controller.value < 0.45
              ? _logoScaleIn.value
              : _logoScaleOut.value;

          return Stack(
            fit: StackFit.expand,
            children: [
              // Radial purple glow
              Center(
                child: SizedBox(
                  width: 300,
                  height: 300,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.brandLight.withOpacity(0.15),
                    ),
                  ),
                ),
              ),

              // Logo — centered, animates upward
              Center(
                child: Transform.translate(
                  offset: Offset(0, _logoOffsetY.value),
                  child: Opacity(
                    opacity: _logoOpacity.value,
                    child: Transform.scale(
                      scale: scale,
                      child: Image.asset(
                        'assets/images/Icon.png',
                        width: 360,
                        height: 360,
                      ),
                    ),
                  ),
                ),
              ),

              // Text — fades in below center after logo has moved up
              Align(
                alignment: const Alignment(0, 0.3),
                child: Opacity(
                  opacity: _textOpacity.value,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Running Laps',
                        style: TextStyle(
                          color: AppColors.brandLight,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Entrena con propósito',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.6),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
