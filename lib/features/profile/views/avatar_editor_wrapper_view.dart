import 'package:flutter/material.dart';
import 'package:flutter_avatar_maker/avatar_maker_screen.dart';
import 'package:get/get.dart';
import 'package:flutter_avatar_maker/avatar_maker_controller.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../app/tema.dart';

// Si tienes una clase Tema global, impórtala. Si no, definimos los colores localmente.
// import '../../../app/tema.dart';

class AvatarEditorWrapperView extends StatefulWidget {
  const AvatarEditorWrapperView({Key? key}) : super(key: key);

  @override
  State<AvatarEditorWrapperView> createState() =>
      _AvatarEditorWrapperViewState();
}

class _AvatarEditorWrapperViewState extends State<AvatarEditorWrapperView> {
  final AvatarMakerController controller = Get.put(AvatarMakerController());
  bool _isLoading = true;

  // --- Colores traídos del primer código para el diseño ---
  static const Color _bgGradientColor = Color(0xFFF9F5FB); 

  @override
  void initState() {
    super.initState();
    _loadAvatarConfig();
  }

  // --- LÓGICA DE CARGAR ---
  Future<void> _loadAvatarConfig() async {
    setState(() => _isLoading = true);
    try {
      final userId = FirebaseAuth.instance.currentUser!.uid;
      final doc =
          await FirebaseFirestore.instance.collection('users').doc(userId).get();

      if (doc.exists && doc.data()!['avatarConfig'] != null) {
        final configData = doc.data()!['avatarConfig'] as Map<String, dynamic>;
        controller.updateFromJson(configData);
      }
    } catch (e) {
      debugPrint("Error al cargar avatar: $e");
    }
    setState(() => _isLoading = false);
  }

  // --- LÓGICA DE GUARDAR ---
  Future<void> _saveAvatarToFirebase() async {
    if (_isLoading) return;
    
    setState(() => _isLoading = true);

    try {
      final Map<String, dynamic> avatarData = controller.toJson();
      final userId = FirebaseAuth.instance.currentUser!.uid;

      await FirebaseFirestore.instance.collection('users').doc(userId).set({
        'profilePicType': 'avatar',
        'avatarConfig': avatarData,
      }, SetOptions(merge: true));

      // --- CAMBIO AQUÍ ---
      // BORRAR ESTO: Get.back(); 
      // PONER ESTO:
      if (mounted) {
        Navigator.pop(context); 
      }
      // -------------------

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Avatar guardado')),
      );
    } catch (e) {
      debugPrint("Error al guardar avatar: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al guardar: $e')),
      );
    } finally {
       if (mounted) setState(() => _isLoading = false);
    }
  }

  // ===================================================================
  // HEADER (Adaptado del primer código)
  // ===================================================================
  Widget _buildHeader() {
    return Container(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment.topCenter,
          radius: 1.2,
          colors: [_bgGradientColor, Colors.white],
          stops: [0.0, 1.0],
        ),
        // Asegúrate de tener esta imagen en tus assets o quita esta línea si no la tienes en este módulo
        image: DecorationImage(
          image: AssetImage('assets/images/fondo.png'), 
          fit: BoxFit.cover,
        ),
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
                // --- BOTÓN IZQUIERDO: VOLVER (Icono Logo) ---
                GestureDetector(
                  onTap: () {
                    Navigator.pop(context);
                  },
                  child: const CircleAvatar(
                    radius: 24.0,
                    backgroundColor: Tema .brandPurple,
                    // Si tienes el logo, úsalo. Si no, un icono de flecha atrás servirá.
                    backgroundImage: AssetImage('assets/images/logo.png'), 
                    child: null, 
                  ),
                ),

                // Título Central (Opcional, para que sepa qué está haciendo)
                const Text(
                  "EDITOR DE AVATAR",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Color(0xFF333333),
                    letterSpacing: 1.2,
                  ),
                ),

                // --- BOTÓN DERECHO: GUARDAR (Reemplaza al Avatar del perfil) ---
                GestureDetector(
                  onTap: _saveAvatarToFirebase,
                  child: CircleAvatar(
                    radius: 24.0,
                    backgroundColor: Tema .brandPurple,
                    child: _isLoading
                        ? const Padding(
                            padding: EdgeInsets.all(12.0),
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Icon(
                            Icons.save,
                            color: Colors.white,
                          ),
                  ),
                ),
              ],
            ),
          ),
          // Línea divisoria
          Container(height: 1.0, color: Colors.grey.shade200),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      // Usamos SafeArea para evitar conflicto con la barra de estado
      body: SafeArea(
        child: Column(
          children: [
            // 1. Insertamos el Header personalizado
            _buildHeader(),

            // 2. El contenido del Avatar Maker ocupa el resto del espacio
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: Tema .brandPurple))
                  : const AvatarMakerScreen(),
            ),
          ],
        ),
      ),
    );
  }
}