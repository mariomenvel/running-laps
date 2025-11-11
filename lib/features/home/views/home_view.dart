import 'package:flutter/material.dart';

// 1. IMPORTA LA PÁGINA A LA QUE QUIERES NAVEGAR
import 'package:running_laps/features/training/views/training_start_view.dart'; // Asegúrate que la ruta es correcta
import 'package:running_laps/features/profile/views/profile_view.dart';

// 2. TU NUEVA PÁGINA (CON HEADER Y FOOTER)
class HomeView extends StatefulWidget {
  const HomeView({Key? key}) : super(key: key);

  @override
  _HomeViewState createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> {
  // --- Colores ---
  static const Color _brandPurple = Color(0xFF8E24AA);
  static const Color _bgGradientColor = Color(0xFFF9F5FB);

  // --- Lógica del Botón ---
  void _onPlayButtonTap() {
    print("Botón Play presionado. Navegando a TrainingStartView...");

    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const TrainingStartView()),
    );
  }

  // ===================================================================
  // Widgets de la UI
  // ===================================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(children: [
          // 1. HEADER (Copiado 1:1 de tu código)
          _buildHeader(),

          // 2. BODY (Reemplazado por un placeholder)
          Expanded(child: _buildNewBody()),

          // 3. FOOTER (Simplificado para mostrar 1 solo botón)
          _buildFooter()
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
                    Navigator.push(context, MaterialPageRoute(
                      builder: (context) => const ProfileView(),
                    ));
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
              'Añade aquí los widgets para tu HomeView.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.black54),
            ),
          ],
        ),
      ),
    );
  }

  // ===================================================================
  // 3. FOOTER (Simplificado Y CON IMAGEN)
  // ===================================================================
  Widget _buildFooter() {
    return Container(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: Alignment.bottomCenter,
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
          Container(height: 1.0, color: Colors.grey.shade200),
          Padding(
            padding:
                const EdgeInsets.symmetric(vertical: 20.0, horizontal: 40.0),
            
            child: _buildCircularButton(
              icon: Icons.play_arrow,
              onTap: _onPlayButtonTap, // <--- Tu nueva función simple
            ),
          ),
        ],
      ),
    );
  }

  /// Helper para botón circular (Copiado 1:1 de tu código)
  Widget _buildCircularButton({
    required IconData icon,
    required VoidCallback onTap,
    Color? color,
    bool isLoading = false,
  }) {
    return GestureDetector(
      onTap: isLoading ? null : onTap,
      child: Container(
        padding: const EdgeInsets.all(20.0),
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.12),
              blurRadius: 15.0,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: isLoading
            ? SizedBox(
                width: 40.0,
                height: 40.0,
                child: CircularProgressIndicator(
                  strokeWidth: 3.0,
                  valueColor:
                      AlwaysStoppedAnimation<Color>(color ?? _brandPurple),
                ),
              )
            : Icon(
                icon,
                color: color ?? _brandPurple,
                size: 40.0,
              ),
      ),
    );
  }
}