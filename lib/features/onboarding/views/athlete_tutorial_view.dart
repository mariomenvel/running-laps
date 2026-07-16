import 'package:flutter/material.dart';
import 'package:running_laps/core/theme/app_colors.dart';

class AthleteTutorialView extends StatefulWidget {
  /// Si es true, muestra botón de cierre (acceso desde Perfil).
  /// Si es false, es obligatorio (post-onboarding).
  final bool dismissible;
  final VoidCallback? onFinished;

  const AthleteTutorialView({
    super.key,
    this.dismissible = false,
    this.onFinished,
  });

  @override
  State<AthleteTutorialView> createState() => _AthleteTutorialViewState();
}

class _AthleteTutorialViewState extends State<AthleteTutorialView> {
  final _controller = PageController();
  int _currentPage = 0;

  static const _slides = [
    _TutorialSlide(
      icon: Icons.track_changes_rounded,
      title: 'Para los que\nvan en serio',
      subtitle:
          'Running Laps es tu entrenador personal con IA. No un simple '
          'registro de carreras — un plan adaptado a ti cada semana.',
    ),
    _TutorialSlide(
      icon: Icons.calendar_month_rounded,
      title: 'Tu plan,\ncada semana',
      subtitle:
          'En el Calendario encontrarás tus sesiones planificadas. Tu '
          'coach las genera cada lunes según tu progreso, fatiga y objetivo.',
    ),
    _TutorialSlide(
      icon: Icons.chat_bubble_rounded,
      title: 'Habla con\ntu coach',
      subtitle:
          'Tienes mensajes semanales para pedir cambios, ajustes o '
          'contar cómo te sientes. El coach adapta el plan en tiempo real.',
    ),
    _TutorialSlide(
      icon: Icons.bar_chart_rounded,
      title: 'Entiende\ntu progreso',
      subtitle:
          'En Analytics verás tu carga, fatiga y forma física. Saber '
          'cuándo apretar y cuándo recuperar marca la diferencia.',
    ),
  ];

  void _next() {
    if (_currentPage < _slides.length - 1) {
      _controller.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _finish();
    }
  }

  void _finish() {
    widget.onFinished?.call();
    if (mounted && Navigator.canPop(context)) {
      Navigator.of(context).pop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isLast = _currentPage == _slides.length - 1;

    return Scaffold(
      backgroundColor: AppColors.background(context),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: List.generate(
                      _slides.length,
                      (i) => AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.only(right: 6),
                        width: i == _currentPage ? 20 : 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: i == _currentPage
                              ? AppColors.brand
                              : AppColors.brand.withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),
                  ),
                  if (!isLast)
                    TextButton(
                      onPressed: _finish,
                      child: Text(
                        widget.dismissible ? 'Cerrar' : 'Saltar',
                        style: TextStyle(color: AppColors.textSecondary(context)),
                      ),
                    )
                  else
                    const SizedBox(width: 64),
                ],
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _controller,
                onPageChanged: (i) => setState(() => _currentPage = i),
                itemCount: _slides.length,
                itemBuilder: (_, i) => _SlideWidget(slide: _slides[i]),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  onPressed: _next,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.brand,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(
                    isLast ? '¡Empezar a entrenar!' : 'Siguiente →',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TutorialSlide {
  final IconData icon;
  final String title;
  final String subtitle;

  const _TutorialSlide({
    required this.icon,
    required this.title,
    required this.subtitle,
  });
}

class _SlideWidget extends StatelessWidget {
  final _TutorialSlide slide;

  const _SlideWidget({required this.slide});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(slide.icon, size: 72, color: AppColors.brand),
          const SizedBox(height: 32),
          Text(
            slide.title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary(context),
              height: 1.1,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            slide.subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              color: AppColors.textSecondary(context),
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
