import 'package:flutter/material.dart';

// 1. IMPORTA LA PÁGINA A LA QUE QUIERES NAVEGAR
// (Importación de 'TrainingStartView' eliminada, ya no es necesaria)

// 2. TU NUEVA PÁGINA (SIN FOOTER)
class ProfileView extends StatefulWidget {
  const ProfileView({Key? key}) : super(key: key);

  @override
  _ProfileViewState createState() => _ProfileViewState();
}

class _ProfileViewState extends State<ProfileView> {
  // --- Colores ---
  static const Color _brandPurple = Color(0xFF8E24AA);
  static const Color _bgGradientColor = Color(0xFFF9F5FB);

  // --- Lógica del Botón Eliminada ---
  // (La función _onPlayButtonTap ha sido eliminada)

  // ===================================================================
  // Widgets de la UI
  // ===================================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(children: [
          // 1. HEADER
          _buildHeader(),

          // 2. BODY
          Expanded(child: _buildNewBody()),

          // 3. FOOTER (Eliminado)
          // La llamada a _buildFooter() ha sido borrada de aquí
        ]),
      ),
    );
  }

  // ===================================================================
  // 1. HEADER (Idéntico al original PERO CON IMAGEN)
  // ===================================================================
  Widget _buildHeader() {
    return Container(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: Alignment.topCenter,
          radius: 1.2,
          colors: [_bgGradientColor, Colors.white],
          stops: [0.0, 1.0],
        ),
        
        // --- MODIFICACIÓN AQUÍ ---
        image: DecorationImage(
          image: AssetImage('assets/images/fondo.png'), // Ruta de tu imagen
          fit: BoxFit.cover, // Ajusta la imagen para cubrir
        ),
        // --- FIN DE LA MODIFICACIÓN ---

      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 20.0,
              vertical: 16.0,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                GestureDetector(
                  onTap: () {
                    print("Botón de Logo presionado");
                  },
                  child: const CircleAvatar(
                    radius: 24.0,
                    backgroundColor: _brandPurple,
                    child: Icon(
                      Icons.directions_run,
                      color: Colors.white,
                      size: 28.0,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    print("Botón de Perfil presionado");
                  },
                  child: CircleAvatar(
                    radius: 24.0,
                    backgroundImage: AssetImage(
                      'assets/images/icono_defecto.jpg',
                    ),
                  ),
                ),
              ],
            ),
          ),
          Container(height: 1.0, color: Colors.grey.shade200),
        ],
      ),
    );
  }

  // ===================================================================
  // 2. BODY (¡Aquí pones tu nuevo contenido!)
  // ===================================================================
  Widget _buildNewBody() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 40.0),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.layers_outlined, size: 80, color: Colors.grey),
            SizedBox(height: 20),
            Text(
              'Cuerpo en Blanco',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 10),
            Text(
              'Añade aquí los widgets para tu ProfileView.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.black54),
            ),
          ],
        ),
      ),
    );
  }

  // ===================================================================
  // 3. FOOTER (Eliminado)
  // ===================================================================
  
  // (La función _buildFooter() ha sido eliminada)

  // (La función _buildCircularButton() ha sido eliminada)
}