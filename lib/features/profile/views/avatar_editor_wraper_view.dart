import 'package:flutter/material.dart';
import 'package:running_laps/config/app_theme.dart';
import 'package:running_laps/core/theme/app_colors.dart';
import 'package:running_laps/core/widgets/modern_snackbar.dart';
import 'package:running_laps/features/avatar/views/avatar_maker_screen.dart';
import 'package:get/get.dart';
import 'package:running_laps/features/avatar/viewmodels/avatar_maker_controller.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// Si tienes una clase Tema global, impórtala. Si no, definimos los colores localmente.
// import '../../../app/tema.dart';

class AvatarEditorWrapperView extends StatefulWidget {
  const AvatarEditorWrapperView({super.key});

  @override
  State<AvatarEditorWrapperView> createState() =>
      _AvatarEditorWrapperViewState();
}

class _AvatarEditorWrapperViewState extends State<AvatarEditorWrapperView> {
  final AvatarMakerController controller = Get.put(AvatarMakerController());
  bool _isLoading = true;

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

      if (doc.exists && doc.data()!['generativeAvatarConfig'] != null) {
        final configData = doc.data()!['generativeAvatarConfig'] as Map<String, dynamic>;
        controller.updateFromJson(configData);
      }
    } catch (e) {

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
        'generativeAvatarConfig': avatarData,
      }, SetOptions(merge: true));

      if (!mounted) return;
      Navigator.pop(context);
      ModernSnackBar.showSuccess(context, 'Avatar actualizado correctamente');
    } catch (e) {
      if (!mounted) return;
      ModernSnackBar.showError(context, 'Error al actualizar avatar: $e');
    } finally {
       if (mounted) setState(() => _isLoading = false);
    }
  }

  // ===================================================================
  // HEADER (Adaptado del primer código)
  // ===================================================================
  Widget _buildHeader() {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(color: AppColors.surface2Of(context)),
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
                // --- BOTÓN IZQUIERDO: VOLVER ---
                GestureDetector(
                  onTap: () {
                    Navigator.pop(context);
                  },
                  child: const CircleAvatar(
                    radius: 24.0,
                    backgroundColor: AppColors.brand,
                    backgroundImage: AssetImage('assets/images/logo.png'),
                    child: null,
                  ),
                ),

                // Título Central
                Text(
                  "EDITOR DE AVATAR",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: cs.onSurface,
                    letterSpacing: 1.2,
                  ),
                ),

                // --- BOTÓN DERECHO: GUARDAR ---
                GestureDetector(
                  onTap: _saveAvatarToFirebase,
                  child: CircleAvatar(
                    radius: 24.0,
                    backgroundColor: AppColors.brand,
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
          Container(height: 1.0, color: cs.outline.withValues(alpha: 0.3)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // 1. Insertamos el Header personalizado
            _buildHeader(),

            // 2. El contenido del Avatar Maker ocupa el resto del espacio
            Expanded(
              child: _isLoading
                  ? Center(child: CircularProgressIndicator(color: AppColors.brand))
                  : const AvatarMakerScreen(),
            ),
          ],
        ),
      ),
    );
  }
}