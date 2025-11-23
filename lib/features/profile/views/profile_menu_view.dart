import 'package:flutter/material.dart';
import 'package:running_laps/app/tema.dart';

// Auth
import 'package:running_laps/features/auth/viewmodels/auth_controller.dart';
import 'package:running_laps/features/auth/views/auth_page.dart';
import 'package:running_laps/features/home/views/home_view.dart';

// Vistas de perfil / entrenos
import 'package:running_laps/features/profile/views/profile_view.dart';
import 'package:running_laps/features/profile/views/avatar_editor_wrapper_view.dart';
import 'package:running_laps/features/training/views/training_start_view.dart';

// Widgets comunes
import 'package:running_laps/core/widgets/app_header.dart';
import 'package:running_laps/core/widgets/app_footer.dart';

class ProfileMenuView extends StatefulWidget {
  const ProfileMenuView({Key? key}) : super(key: key);

  @override
  _ProfileMenuViewState createState() {
    return _ProfileMenuViewState();
  }
}

class _ProfileMenuViewState extends State<ProfileMenuView> {
  late final AuthController _authCtrl;

  @override
  void initState() {
    super.initState();
    _authCtrl = AuthController();
  }

  @override
  void dispose() {
    _authCtrl.dispose();
    super.dispose();
  }

  // =====================================================
  // Navegación
  // =====================================================

  void _openHistory() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (BuildContext context) {
          // Tu antigua vista de historial
          return const ProfileView();
        },
      ),
    );
  }

  void _openAvatarEditor() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (BuildContext context) {
          return const AvatarEditorWrapperView();
        },
      ),
    );
  }

  Future<void> _logout() async {
    try {
      await _authCtrl.signOut();

      if (!mounted) {
        return;
      }

      // Volver a la pantalla de Auth limpiando el stack
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (BuildContext context) {
            return const AuthPage();
          },
        ),
        (Route<dynamic> route) {
          return false;
        },
      );
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString()),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // =====================================================
  // Widgets auxiliares
  // =====================================================

  Widget _buildMenuButton({
    required String text,
    required VoidCallback? onPressed,
    Color? textColor,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 44,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          backgroundColor: Colors.white,
          side: BorderSide(
            color: Colors.grey.shade300,
            width: 1,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          textStyle: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.0,
          ),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: textColor ?? Colors.black,
          ),
        ),
      ),
    );
  }

  // =====================================================
  // Build
  // =====================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: <Widget>[
            // HEADER igual que en ProfileView
            AppHeader(
              onTapLeft: () {
                Navigator.push(
          context,
          MaterialPageRoute(
            builder: (BuildContext context) {
              return const HomeView();
            },
          ),
        );
      },
              onTapRight: () {
              },
            ),

            // Contenido central
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32.0),
                child: Column(
                  children: <Widget>[
                    const SizedBox(height: 32),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Perfil',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    _buildMenuButton(
                      text: 'HISTORIAL DE ENTRENAMIENTOS',
                      onPressed: _openHistory,
                    ),
                    const SizedBox(height: 12),
                    _buildMenuButton(
                      text: 'EDITAR AVATAR',
                      onPressed: _openAvatarEditor,
                    ),
                    const SizedBox(height: 12),

                    // Botón de Cerrar sesión escuchando isLoading
                    ValueListenableBuilder<bool>(
                      valueListenable: _authCtrl.isLoading,
                      builder: (
                        BuildContext context,
                        bool isLoading,
                        Widget? child,
                      ) {
                        return _buildMenuButton(
                          text: isLoading ? 'CERRANDO SESIÓN...' : 'CERRAR SESION',
                          onPressed: isLoading ? null : _logout,
                          textColor: Colors.red,
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),

            // FOOTER igual que en ProfileView
            AppFooter(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (BuildContext context) {
                      return const TrainingStartView();
                    },
                  ),
                );
              },
              isLoading: false,
            ),
          ],
        ),
      ),
    );
  }
}
