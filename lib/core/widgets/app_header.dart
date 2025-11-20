import 'package:flutter/material.dart';
import 'package:running_laps/app/tema.dart';

class AppHeader extends StatelessWidget {
  final VoidCallback? onTapLeft;
  final VoidCallback? onTapRight;
  final bool showBottomDivider;

  const AppHeader({
    Key? key,
    this.onTapLeft,
    this.onTapRight,
    this.showBottomDivider = true,
  }) : super(key: key);

  static const Color _bgGradientColor = Color(0xFFF9F5FB);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment.topCenter,
          radius: 1.2,
          colors: <Color>[_bgGradientColor, Colors.white],
          stops: <double>[0.0, 1.0],
        ),
        image: DecorationImage(
          image: AssetImage('assets/images/fondo.png'),
          fit: BoxFit.cover,
        ),
      ),
      child: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 20.0,
              vertical: 16.0,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                // --- LOGO FIJO ---
                GestureDetector(
                  onTap: onTapLeft,
                  child: const CircleAvatar(
                    radius: 24.0,
                    backgroundColor: Tema.brandPurple,
                    backgroundImage: AssetImage('assets/images/logo.png'),
                  ),
                ),

                // --- AVATAR FIJO ---
                GestureDetector(
                  onTap: onTapRight,
                  child: AvatarHelper.construirImagenPerfil(radius: 24.0),
                ),
              ],
            ),
          ),

          if (showBottomDivider)
            Container(height: 1.0, color: Colors.grey.shade300),
        ],
      ),
    );
  }
}
