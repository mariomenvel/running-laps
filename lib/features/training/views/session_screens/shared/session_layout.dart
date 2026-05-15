import 'package:flutter/material.dart';
import 'session_theme.dart';

/// Scaffold base para todas las pantallas de sesión.
/// Aplica el SessionTheme: gradient de fondo, decoración,
/// header con contexto del bloque, área de contenido scrollable
/// y botón de acción inferior.
class SessionLayout extends StatelessWidget {
  final SessionTheme theme;
  final Widget header;
  final Widget body;
  final Widget? footerButton;
  final bool safeArea;

  const SessionLayout({
    super.key,
    required this.theme,
    required this.header,
    required this.body,
    this.footerButton,
    this.safeArea = true,
  });

  @override
  Widget build(BuildContext context) {
    Widget content = Column(
      children: [
        header,
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: body,
          ),
        ),
        if (footerButton != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            child: footerButton!,
          ),
      ],
    );

    if (safeArea) content = SafeArea(child: content);

    final deco = theme.backgroundDecoration(context);
    final gradient = theme.backgroundGradient(context);

    return Scaffold(
      backgroundColor: theme.background(context),
      body: Stack(
        children: [
          if (gradient != null)
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(gradient: gradient),
              ),
            ),
          if (deco != null)
            Positioned.fill(child: IgnorePointer(child: deco)),
          content,
        ],
      ),
    );
  }
}
