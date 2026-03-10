import 'package:flutter/material.dart';
import 'package:running_laps/config/app_theme.dart';

// Auth
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:running_laps/features/auth/viewmodels/auth_controller.dart';
import 'package:running_laps/features/auth/views/auth_page.dart';
import 'package:running_laps/features/home/views/home_view.dart';

// Vistas de perfil / entrenos
// Vistas de perfil / entrenos
import 'package:running_laps/features/history/views/history_screen.dart';
import '../../templates/views/templates_list_view.dart';
import 'avatar_editor_wraper_view.dart';
import 'package:running_laps/features/training/views/training_start_view.dart';
import '../../groups/views/groups_list_screen.dart';
import '../../groups/views/participant_profile_screen.dart';
import 'package:running_laps/features/analytics/views/analytics_hub_screen.dart';
import '../../admin/views/admin_panel_screen.dart';
import 'account_settings_view.dart';

import 'package:running_laps/core/services/settings_service.dart';

// Widgets comunes
import 'package:running_laps/core/widgets/app_header.dart';
import 'package:running_laps/core/widgets/app_footer.dart';
import 'package:running_laps/core/widgets/modern_snackbar.dart';

class ProfileMenuView extends StatefulWidget {
  const ProfileMenuView({Key? key}) : super(key: key);

  @override
  _ProfileMenuViewState createState() {
    return _ProfileMenuViewState();
  }
}

class _ProfileMenuViewState extends State<ProfileMenuView> {
  late final AuthController _authCtrl;
  final SettingsService _settingsService = SettingsService();

  String _nombreUsuario = "";
  bool _isAdmin = false;
  bool _useWhiteCards = true;

  @override
  void initState() {
    super.initState();
    _authCtrl = AuthController();
    _cargarNombre();
    _settingsService.getCardStyle().then((v) {
      if (mounted) setState(() => _useWhiteCards = v);
    });
  }

  // Cargar nombre desde Firebase
  void _cargarNombre() async {
    String? nombre = await _authCtrl.getUserName();
    bool admin = await _authCtrl.isUserAdmin();

    if (mounted) {
      setState(() {
        if (nombre != null) {
          _nombreUsuario = nombre;
        } else {
          _nombreUsuario = "";
        }
        _isAdmin = admin;
      });
    }
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
          return const HistoryScreen();
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

  // --- NUEVA FUNCIÓN PARA GRUPOS ---
  void _openGroups() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const GroupsListScreen()),
    );
  }

  // --- NUEVA FUNCIÓN PARA PERFIL PÚBLICO ---
  Future<void> _openPublicProfile() async {
     final user = FirebaseAuth.instance.currentUser;
     if (user == null) return;
     
     // Mostrar loading rápido
     showDialog(
       context: context, 
       barrierDismissible: false,
       builder: (c) => const Center(child: CircularProgressIndicator(color: Tema.brandPurple)),
     );
     
     try {
       final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
       if (mounted) Navigator.pop(context); // cerrar loading
       
       if (doc.exists && mounted) {
         final data = doc.data() as Map<String, dynamic>;
         
         Navigator.push(
           context,
           MaterialPageRoute(builder: (context) => ParticipantProfileScreen(
             uid: user.uid,
             name: data['nombre'] ?? data['username'] ?? "Usuario", // Fallback a nombre, luego username
             photoUrl: data['profileImageUrl'],
             profilePicType: data['profilePicType'],
             avatarConfig: data['avatarConfig'],
           )),
         );
       }
     } catch (e) {
       if (mounted) Navigator.pop(context); // cerrar loading en error
       if (mounted) ModernSnackBar.showError(context, "Error: $e");
     }
  }

  Future<void> _logout() async {
    try {
      await _authCtrl.signOut();

      if (!mounted) {
        return;
      }

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
      ModernSnackBar.showError(context, e.toString());
    }
  }

  // =====================================================
  // Widgets auxiliares
  // =====================================================

  // =====================================================
  // Widgets auxiliares (REDESIGN)
  // =====================================================

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8, top: 16),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          color: Colors.grey.shade500,
          fontSize: 12,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildMenuTile({
    required String title,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                // Icon Container
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color, size: 22),
                ),
                const SizedBox(width: 16),
                // Title
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: isDestructive ? Colors.red : Colors.black87,
                    ),
                  ),
                ),
                // Arrow
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 16,
                  color: Colors.grey.shade400,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCardStyleSetting() {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Tema.brandPurple.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.style_rounded, color: Tema.brandPurple, size: 22),
            ),
            const SizedBox(width: 16),
            const Expanded(
              child: Text(
                'Estilo de tarjetas',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
            ),
            // Segmented control
            Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  _buildStyleOption('Clásico', !_useWhiteCards),
                  _buildStyleOption('Moderno', _useWhiteCards),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStyleOption(String label, bool isSelected) {
    return GestureDetector(
      onTap: () async {
        final newValue = label == 'Moderno';
        await _settingsService.setCardStyle(newValue);
        if (mounted) setState(() => _useWhiteCards = newValue);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? Tema.brandPurple : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isSelected ? Colors.white : Colors.grey.shade600,
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
      backgroundColor: const Color(0xFFF9FAFB), // Fondo ligeramente gris
      body: SafeArea(
        child: Column(
          children: <Widget>[
            // HEADER
            AppHeader(
              onTapLeft: () {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (c) => const HomeView()),
                  (route) => false,
                );
              },
              onTapRight: () {},
            ),

            // Contenido central
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const SizedBox(height: 30),

                    // NOMBRE DE USUARIO
                    Center(
                      child: Column(
                        children: [
                           Text(
                            _nombreUsuario == ""
                                ? "Perfil"
                                : _nombreUsuario, // Mostramos tal cual viene (ya hicimos fallback)
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.black87,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                           ),
                           const SizedBox(height: 4),
                           Text(
                             "Gestiona tu cuenta y actividad",
                             style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
                           )
                        ],
                      ),
                    ),

                    const SizedBox(height: 30),

                    // SECTION 1: SOCIAL
                    _buildSectionHeader("Social"),
                    _buildMenuTile(
                      title: "Mis grupos",
                      icon: Icons.groups_rounded,
                      color: Colors.blueAccent,
                      onTap: _openGroups,
                    ),
                    _buildMenuTile(
                      title: "Mi perfil público",
                      icon: Icons.person_pin_rounded,
                      color: Tema.brandPurple,
                      onTap: _openPublicProfile,
                    ),

                    // SECTION 2: PERSONAL
                    _buildSectionHeader("Personal"),
                    _buildMenuTile(
                      title: "Analytics hub",
                      icon: Icons.analytics_rounded,
                      color: Colors.purpleAccent,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const AnalyticsHubScreen(),
                          ),
                        );
                      },
                    ),
                    _buildMenuTile(
                      title: "Mis plantillas",
                      icon: Icons.list_alt_rounded,
                      color: Colors.teal,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const TemplatesListView(),
                          ),
                        );
                      },
                    ),
                    _buildMenuTile(
                      title: "Historial de entrenamientos",
                      icon: Icons.history_rounded,
                      color: Colors.orangeAccent,
                      onTap: _openHistory,
                    ),
                    _buildMenuTile(
                      title: "Editar avatar",
                      icon: Icons.face_rounded,
                      color: Colors.green,
                      onTap: _openAvatarEditor,
                    ),

                    if (_isAdmin) ...[
                      _buildSectionHeader("Administración"),
                      _buildMenuTile(
                        title: "Panel de administrador",
                        icon: Icons.admin_panel_settings,
                        color: Colors.black87,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (c) => const AdminPanelScreen()),
                          );
                        },
                      ),
                    ],
                    // SECTION: APARIENCIA
                    _buildSectionHeader("Apariencia"),
                    _buildCardStyleSetting(),

                    // SECTION 4: CUENTA
                    _buildSectionHeader("Cuenta"),
                    _buildMenuTile(
                      title: "Configuración de cuenta",
                      icon: Icons.manage_accounts_rounded,
                      color: Colors.blueGrey,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => AccountSettingsView(
                              currentName: _nombreUsuario,
                              onNameUpdated: _cargarNombre,
                            ),
                          ),
                        );
                      },
                    ),

                    // SECTION 5: SESIÓN
                    _buildSectionHeader("Sesión"),
                    ValueListenableBuilder<bool>(
                      valueListenable: _authCtrl.isLoading,
                      builder: (context, isLoading, _) {
                        return _buildMenuTile(
                          title: isLoading ? "Cerrando sesión..." : "Cerrar sesión",
                          icon: Icons.logout_rounded,
                          color: Colors.redAccent,
                          isDestructive: true,
                          onTap: isLoading ? () {} : () => _logout(),
                        );
                      },
                    ),
                    
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),

            // FOOTER
            AppFooter(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const TrainingStartView()),
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
