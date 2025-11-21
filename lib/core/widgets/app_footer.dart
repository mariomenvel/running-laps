import 'package:flutter/material.dart';
import 'package:running_laps/app/tema.dart';

class AppFooter extends StatelessWidget {
  final VoidCallback onTap; // solo pasas la acción
  final bool isLoading; // opcional: spinner si estás cargando

  const AppFooter({Key? key, required this.onTap, this.isLoading = false})
    : super(key: key);

  static const Color _bgGradientColor = Color(0xFFF9F5FB);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment.bottomCenter,
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
          Container(height: 0.3, color: Colors.grey),
          Padding(
            padding: const EdgeInsets.symmetric(
              vertical: 20.0,
              horizontal: 40.0,
            ),
            child: _buildButton(),
          ),
        ],
      ),
    );
  }

  Widget _buildButton() {
    return GestureDetector(
      onTap: isLoading ? null : onTap,
      child: Container(
        padding: const EdgeInsets.all(20.0),
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: Colors.black.withOpacity(0.12),
              blurRadius: 15.0,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: isLoading
            ? const SizedBox(
                width: 40,
                height: 40,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  valueColor: AlwaysStoppedAnimation<Color>(Tema.brandPurple),
                ),
              )
            : const Icon(Icons.play_arrow, color: Tema.brandPurple, size: 40.0),
      ),
    );
  }
}
