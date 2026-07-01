// ✅ ACTIVO — pese al sufijo "_legacy" en el nombre
// de archivo, esta vista SÍ está en uso real.
// Ver auditoría del 2026-06-19 en CHANGELOG.md antes
// de asumir que es seguro modificar/eliminar.
import 'package:flutter/material.dart';
import 'package:running_laps/config/app_theme.dart';
import 'package:running_laps/core/theme/app_colors.dart';
import 'package:running_laps/core/utils/app_transitions.dart';
import 'package:running_laps/core/widgets/main_shell.dart';
import 'package:running_laps/features/onboarding/views/athlete_tutorial_view.dart';

// Auth
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:running_laps/features/auth/viewmodels/auth_controller.dart';
import 'package:running_laps/features/auth/views/auth_page.dart';
import 'package:running_laps/features/history/views/history_screen.dart';
import '../../templates/views/templates_list_view.dart';
import 'avatar_editor_wraper_view.dart';
import 'package:running_laps/features/training/views/training_start_view.dart';
import 'package:running_laps/features/training/views/manual_training_view.dart';
import '../../groups/views/groups_list_screen.dart';
import '../../groups/views/participant_profile_screen.dart';
import 'package:running_laps/features/analytics/views/analytics_hub_screen.dart';
import '../../admin/views/admin_panel_screen.dart';
import 'account_settings_view.dart';
import 'zones_config_screen.dart';
import 'package:running_laps/features/ai_coach/views/ai_coach_settings_view.dart';
import 'package:running_laps/features/profile/views/heart_rate_monitor_view.dart';
import 'package:running_laps/core/services/heart_rate_service.dart';

// Widgets comunes
import 'package:running_laps/core/widgets/app_header.dart';
import 'package:running_laps/core/widgets/modern_snackbar.dart';
import 'package:running_laps/core/widgets/app_confirm_dialog.dart';

class ProfileMenuView extends StatefulWidget {
  const ProfileMenuView({Key? key}) : super(key: key);

  @override
  _ProfileMenuViewState createState() {
    return _ProfileMenuViewState();
  }
}

class _ProfileMenuViewState extends State<ProfileMenuView> with SingleTickerProviderStateMixin {
  late final AuthController _authCtrl;

  String _nombreUsuario = "";
  bool _isAdmin = false;
  bool _isAthleteMode = false;

  // ── Entrance animation ──────────────────────────────────────────
  late final AnimationController _entranceCtrl;
  bool _entrancePlayed = false;
  late final Animation<double> _aName;       // 0ms   – fade + slide left
  late final Animation<double> _aSocial;     // 200ms – fade + slide bottom
  late final Animation<double> _aPersonal;   // 260ms – fade + slide bottom
  late final Animation<double> _aAdmin;      // 320ms – fade + slide bottom
  late final Animation<double> _aCuenta;     // 440ms – fade + slide bottom
  late final Animation<double> _aAyuda;      // 470ms – fade + slide bottom
  late final Animation<double> _aSesion;     // 500ms – fade + slide bottom
  // ────────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _authCtrl = AuthController();
    _cargarNombre();
    _entranceCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200));
    _aName       = CurvedAnimation(parent: _entranceCtrl, curve: const Interval(0.000, 0.517, curve: Curves.easeOutQuart));
    _aSocial     = CurvedAnimation(parent: _entranceCtrl, curve: const Interval(0.167, 0.683, curve: Curves.easeOutQuart));
    _aPersonal   = CurvedAnimation(parent: _entranceCtrl, curve: const Interval(0.217, 0.733, curve: Curves.easeOutQuart));
    _aAdmin      = CurvedAnimation(parent: _entranceCtrl, curve: const Interval(0.267, 0.783, curve: Curves.easeOutQuart));
    _aCuenta     = CurvedAnimation(parent: _entranceCtrl, curve: const Interval(0.367, 0.883, curve: Curves.easeOutQuart));
    _aAyuda      = CurvedAnimation(parent: _entranceCtrl, curve: const Interval(0.392, 0.908, curve: Curves.easeOutQuart));
    _aSesion     = CurvedAnimation(parent: _entranceCtrl, curve: const Interval(0.417, 0.933, curve: Curves.easeOutQuart));
    if (!_entrancePlayed) {
      _entrancePlayed = true;
      _entranceCtrl.forward();
    }
  }

  // Cargar nombre desde Firebase
  void _cargarNombre() async {
    String? nombre = await _authCtrl.getUserName();
    bool admin = await _authCtrl.isUserAdmin();

    final uid = FirebaseAuth.instance.currentUser?.uid;
    bool athleteMode = false;
    if (uid != null) {
      final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      athleteMode = doc.data()?['isAthleteMode'] as bool? ?? false;
    }

    if (mounted) {
      setState(() {
        if (nombre != null) {
          _nombreUsuario = nombre;
        } else {
          _nombreUsuario = "";
        }
        _isAdmin = admin;
        _isAthleteMode = athleteMode;
      });
    }
  }

  Future<void> _desactivarModoAtleta() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .update({'isAthleteMode': false});
    if (mounted) setState(() => _isAthleteMode = false);
  }

  @override
  void dispose() {
    _entranceCtrl.dispose();
    _authCtrl.dispose();
    super.dispose();
  }

  // =====================================================
  // Navegación
  // =====================================================

  void _openHistory() {
    Navigator.push(
      context,
      AppRoute(page: const HistoryScreen()),
    );
  }

  void _openAvatarEditor() {
    Navigator.push(
      context,
      AppModalRoute(page: const AvatarEditorWrapperView()),
    );
  }

  // --- NUEVA FUNCIÓN PARA GRUPOS ---
  void _openGroups() {
    Navigator.push(
      context,
      AppRoute(page: const GroupsListScreen()),
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
       builder: (c) => const Center(child: CircularProgressIndicator(color: AppColors.brand)),
     );
     
     try {
       final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
       if (mounted) Navigator.pop(context); // cerrar loading
       
       if (doc.exists && mounted) {
         final data = doc.data() as Map<String, dynamic>;
         
         Navigator.push(
           context,
           AppModalRoute(page: ParticipantProfileScreen(
             uid: user.uid,
             name: data['nombre'] ?? data['username'] ?? "Usuario", // Fallback a nombre, luego username
             photoUrl: data['profileImageUrl'],
             profilePicType: data['profilePicType'],
             avatarConfig: data['generativeAvatarConfig'],
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
        AppRoute(page: const AuthPage()),
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

  // ── Entrance animation helpers ────────────────────────────────────
  Widget _slideFromLeft(Animation<double> anim, Widget child) {
    return AnimatedBuilder(
      animation: anim,
      builder: (_, __) => Opacity(
        opacity: anim.value,
        child: Transform.translate(
          offset: Offset(-24 * (1 - anim.value), 0),
          child: child,
        ),
      ),
    );
  }

  Widget _slideFromBottom(Animation<double> anim, Widget child) {
    return AnimatedBuilder(
      animation: anim,
      builder: (_, __) => Opacity(
        opacity: anim.value,
        child: Transform.translate(
          offset: Offset(0, 24 * (1 - anim.value)),
          child: child,
        ),
      ),
    );
  }
  // ─────────────────────────────────────────────────────────────────

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8, top: 16),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
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
    String? subtitle,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.transparent : Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: Theme.of(context).colorScheme.outline.withOpacity(0.5)),
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
                // Title + optional subtitle
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: isDestructive ? AppColors.rpeMax : Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                // Arrow
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 16,
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
                ),
              ],
            ),
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
      body: SafeArea(
        top: false,
        bottom: false,
        child: Column(
          children: <Widget>[
            // HEADER
            AppHeader(
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
                    _slideFromLeft(_aName, Center(
                      child: Column(
                        children: [
                           Text(
                            _nombreUsuario == ""
                                ? "Perfil"
                                : _nombreUsuario,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onSurface,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                           ),
                           const SizedBox(height: 4),
                           Text(
                             "Gestiona tu cuenta y actividad",
                             style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5), fontSize: 13),
                           )
                        ],
                      ),
                    )),

                    const SizedBox(height: 30),

                    // SECTION 1: SOCIAL
                    _slideFromBottom(_aSocial, Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSectionHeader("Social"),
                        _buildMenuTile(
                          title: "Mis grupos",
                          icon: Icons.groups_rounded,
                          color: AppColors.rest,
                          onTap: _openGroups,
                        ),
                        _buildMenuTile(
                          title: "Mi perfil público",
                          icon: Icons.person_pin_rounded,
                          color: Theme.of(context).brightness == Brightness.dark ? AppColors.brandLight : AppColors.brand,
                          onTap: _openPublicProfile,
                        ),
                      ],
                    )),

                    // SECTION 2: PERSONAL
                    _slideFromBottom(_aPersonal, Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSectionHeader("Personal"),
                        _buildMenuTile(
                          title: "Analytics hub",
                          icon: Icons.analytics_rounded,
                          color: AppColors.brand,
                          onTap: () {
                            Navigator.push(
                              context,
                              AppRoute(page: const AnalyticsHubScreen()),
                            );
                          },
                        ),
                        _buildMenuTile(
                          title: "Mis plantillas",
                          icon: Icons.list_alt_rounded,
                          color: AppColors.brand,
                          onTap: () {
                            Navigator.push(
                              context,
                              AppRoute(page: const TemplatesListView()),
                            );
                          },
                        ),
                        _buildMenuTile(
                          title: "Historial de entrenamientos",
                          icon: Icons.history_rounded,
                          color: AppColors.effort,
                          onTap: _openHistory,
                        ),
                        _buildMenuTile(
                          title: "Registrar entrenamiento",
                          icon: Icons.edit_note_rounded,
                          color: const Color(0xFF8E8E93),
                          subtitle: "Apunta lo que ya has hecho",
                          onTap: () {
                            final user = FirebaseAuth.instance.currentUser;
                            if (user == null) return;
                            Navigator.push(
                              context,
                              AppRoute(page: const ManualTrainingView()),
                            );
                          },
                        ),
                        _buildMenuTile(
                          title: "Editar avatar",
                          icon: Icons.face_rounded,
                          color: AppColors.rpeLow,
                          onTap: _openAvatarEditor,
                        ),
                        _buildMenuTile(
                          title: "Zonas de entrenamiento",
                          icon: Icons.favorite_outline_rounded,
                          color: AppColors.effort,
                          onTap: () {
                            final user = FirebaseAuth.instance.currentUser;
                            if (user == null) return;
                            Navigator.push(
                              context,
                              AppRoute(
                                page: ZonesConfigScreen(uid: user.uid),
                              ),
                            );
                          },
                        ),
                        _buildMenuTile(
                          title: "Entrenador IA",
                          icon: Icons.auto_awesome_rounded,
                          color: const Color(0xFFB084F5),
                          subtitle: "Plan semanal con sugerencias",
                          onTap: () => MainShell.shellKey.currentState?.navigateTo(16),
                        ),
                      ],
                    )),

                    if (_isAdmin)
                      _slideFromBottom(_aAdmin, Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildSectionHeader("Administración"),
                          _buildMenuTile(
                            title: "Panel de administrador",
                            icon: Icons.admin_panel_settings,
                            color: Colors.black87,
                            onTap: () {
                              Navigator.push(
                                context,
                                AppRoute(page: const AdminPanelScreen()),
                              );
                            },
                          ),
                        ],
                      )),

                    // SECTION 4: CUENTA
                    _slideFromBottom(_aCuenta, Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSectionHeader("Cuenta"),
                        _buildMenuTile(
                          title: "Configuración de cuenta",
                          icon: Icons.manage_accounts_rounded,
                          color: AppColors.iconMuted,
                          onTap: () {
                            Navigator.push(
                              context,
                              AppRoute(page: AccountSettingsView(
                                  currentName: _nombreUsuario,
                                  onNameUpdated: _cargarNombre,
                                )),
                            );
                          },
                        ),
                        if (_isAthleteMode)
                          _buildMenuTile(
                            icon: Icons.person_outline_rounded,
                            title: 'Volver a modo recreativo',
                            subtitle: 'Desactivarás el plan y el coach IA',
                            color: AppColors.rpeMax,
                            isDestructive: true,
                            onTap: () async {
                              final confirm = await showAppConfirmDialog(
                                context: context,
                                title: '¿Volver a modo recreativo?',
                                message: 'Perderás acceso a tu plan semanal y al coach IA. Tus entrenamientos no se borrarán.',
                                confirmLabel: 'Sí, desactivar',
                                cancelLabel: 'Cancelar',
                                isDestructive: true,
                              );
                              if (confirm != true) return;
                              await _desactivarModoAtleta();
                            },
                          ),
                        ListenableBuilder(
                          listenable: Listenable.merge([
                            HeartRateService().connectionState,
                            HeartRateService().connectedDeviceName,
                          ]),
                          builder: (context, _) {
                            final isConnected = HeartRateService().connectionState.value
                                == HrConnectionState.connected;
                            final name = HeartRateService().connectedDeviceName.value;
                            final subtitle = isConnected
                                ? 'Conectado${name != null ? ' · $name' : ''}'
                                : 'Sin conectar';
                            return _buildMenuTile(
                              title: "Pulsómetro BLE",
                              icon: Icons.favorite_rounded,
                              color: AppColors.rpeMax,
                              subtitle: subtitle,
                              onTap: () {
                                Navigator.push(
                                  context,
                                  AppRoute(page: const HeartRateMonitorView()),
                                );
                              },
                            );
                          },
                        ),
                      ],
                    )),

                    // SECTION 4.5: AYUDA
                    _slideFromBottom(_aAyuda, Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSectionHeader("Ayuda"),
                        _buildMenuTile(
                          title: "Cómo funciona Running Laps",
                          icon: Icons.school_rounded,
                          color: AppColors.brand,
                          subtitle: "Tutorial del modo atleta",
                          onTap: () {
                            Navigator.push(
                              context,
                              AppRoute(
                                page: const AthleteTutorialView(dismissible: true),
                              ),
                            );
                          },
                        ),
                      ],
                    )),

                    // SECTION 5: SESIÓN
                    _slideFromBottom(_aSesion, Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSectionHeader("Sesión"),
                        ValueListenableBuilder<bool>(
                          valueListenable: _authCtrl.isLoading,
                          builder: (context, isLoading, _) {
                            return _buildMenuTile(
                              title: isLoading ? "Cerrando sesión..." : "Cerrar sesión",
                              icon: Icons.logout_rounded,
                              color: AppColors.rpeMax,
                              isDestructive: true,
                              onTap: isLoading ? () {} : () => _logout(),
                            );
                          },
                        ),
                        const SizedBox(height: 40),
                      ],
                    )),
                  ],
                ),
              ),
            ),

          ],
        ),
      ),
    );
  }
}
