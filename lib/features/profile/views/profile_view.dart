import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:running_laps/core/theme/app_colors.dart';
import 'package:running_laps/core/theme/app_theme.dart';
import 'package:running_laps/core/utils/app_transitions.dart';
import 'package:running_laps/core/theme/theme_service.dart';
import 'package:running_laps/core/services/heart_rate_service.dart';
import 'package:running_laps/core/widgets/modern_snackbar.dart';
import 'package:running_laps/features/auth/viewmodels/auth_controller.dart';
import 'package:running_laps/features/auth/views/auth_page.dart';
import 'package:running_laps/features/history/views/history_screen.dart';
import 'package:running_laps/features/templates/views/templates_list_view.dart';
import 'package:running_laps/features/groups/views/groups_list_screen.dart';
import 'package:running_laps/features/groups/views/participant_profile_screen.dart';
import 'package:running_laps/features/training/views/manual_training_view.dart';
import 'package:running_laps/features/admin/views/admin_panel_screen.dart';
import 'package:running_laps/features/profile/views/avatar_editor_wraper_view.dart';
import 'package:running_laps/features/profile/views/account_settings_view.dart';
import 'package:running_laps/features/profile/views/zones_config_screen.dart';
import 'package:running_laps/features/profile/views/heart_rate_monitor_view.dart';

class ProfileView extends StatefulWidget {
  const ProfileView({super.key});

  @override
  State<ProfileView> createState() => _ProfileViewState();
}

class _ProfileViewState extends State<ProfileView> {
  late final AuthController _authCtrl;

  String _userName = '';
  String? _photoUrl;
  bool _isAdmin = false;
  bool _isAthleteMode = false;

  @override
  void initState() {
    super.initState();
    _authCtrl = AuthController();
    _loadUserData();
  }

  @override
  void dispose() {
    _authCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
    if (!mounted) return;
    final data = doc.data() ?? {};
    setState(() {
      _userName     = data['nombre'] ?? 'Usuario';
      _photoUrl     = data['profileImageUrl'];
      _isAdmin      = data['isAdmin'] ?? false;
      _isAthleteMode = data['isAthleteMode'] ?? false;
    });
  }

  Future<void> _openPublicProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator(color: AppColors.brand)),
    );

    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (mounted) Navigator.pop(context);
      if (!doc.exists || !mounted) return;
      final data = doc.data() as Map<String, dynamic>;
      Navigator.push(
        context,
        AppModalRoute(
          page: ParticipantProfileScreen(
            uid: user.uid,
            name: data['nombre'] ?? data['username'] ?? 'Usuario',
            photoUrl: data['profileImageUrl'],
            profilePicType: data['profilePicType'],
            avatarConfig: data['avatarConfig'],
          ),
        ),
      );
    } catch (e) {
      if (mounted) Navigator.pop(context);
      if (mounted) ModernSnackBar.showError(context, 'Error: $e');
    }
  }

  String _currentThemeLabel() {
    switch (ThemeService.themeMode.value) {
      case ThemeMode.dark:   return 'Oscuro';
      case ThemeMode.light:  return 'Claro';
      case ThemeMode.system: return 'Sistema';
    }
  }

  void _showThemePicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => ValueListenableBuilder<ThemeMode>(
        valueListenable: ThemeService.themeMode,
        builder: (ctx, current, __) => Padding(
          padding: const EdgeInsets.all(AppSpacing.l),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Apariencia', style: AppTypography.h3.copyWith(color: AppColors.textPrimary(context))),
              const SizedBox(height: AppSpacing.l),
              _ThemeOption('Oscuro',  ThemeMode.dark,   Icons.dark_mode_outlined,            current),
              _ThemeOption('Claro',   ThemeMode.light,  Icons.light_mode_outlined,           current),
              _ThemeOption('Sistema', ThemeMode.system, Icons.settings_brightness_outlined,  current),
              const SizedBox(height: AppSpacing.l),
            ],
          ),
        ),
      ),
    ).then((_) => setState(() {})); // refresca el subtitle tras cerrar
  }

  Future<void> _logout() async {
    try {
      await _authCtrl.signOut();
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        AppRoute(page: const AuthPage()),
        (_) => false,
      );
    } catch (e) {
      if (!mounted) return;
      ModernSnackBar.showError(context, e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: AppSpacing.xl),

          // ── Cabecera ──────────────────────────────────────────────
          Center(
            child: Column(
              children: [
                GestureDetector(
                  onTap: () => Navigator.push(
                    context,
                    AppModalRoute(page: const AvatarEditorWrapperView()),
                  ),
                  child: CircleAvatar(
                    radius: 40,
                    backgroundColor: AppColors.surfaceOf(context),
                    backgroundImage: _photoUrl != null ? NetworkImage(_photoUrl!) : null,
                    child: _photoUrl == null
                        ? Icon(Icons.person, color: AppColors.iconMutedOf(context), size: 40)
                        : null,
                  ),
                ),
                const SizedBox(height: AppSpacing.m),
                Text(_userName, style: AppTypography.h2.copyWith(color: AppColors.textPrimary(context))),
                const SizedBox(height: AppSpacing.xs),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: _isAthleteMode
                        ? AppColors.brand.withOpacity(0.15)
                        : AppColors.surfaceOf(context),
                    border: Border.all(
                      color: _isAthleteMode ? AppColors.brand : AppColors.borderOf(context),
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _isAthleteMode ? 'Modo Atleta' : 'Modo Libre',
                    style: AppTypography.small.copyWith(
                      color: _isAthleteMode ? AppColors.brand : AppColors.iconMuted,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: AppSpacing.xxl),

          // ── Entrenamiento ─────────────────────────────────────────
          const _SectionTitle('ENTRENAMIENTO'),
          const SizedBox(height: AppSpacing.s),
          _MenuCard(children: [
            _MenuItem(
              icon: Icons.fitness_center_outlined,
              label: 'Mis plantillas',
              onTap: () => Navigator.push(context, AppRoute(page: const TemplatesListView())),
            ),
            const _MenuDivider(),
            _MenuItem(
              icon: Icons.favorite_outline,
              label: 'Zonas de entrenamiento',
              subtitle: 'FC máx, zonas personalizadas',
              onTap: () => Navigator.push(context, AppRoute(page: ZonesConfigScreen(uid: uid))),
            ),
            const _MenuDivider(),
            _MenuItem(
              icon: Icons.history_outlined,
              label: 'Historial completo',
              onTap: () => Navigator.push(context, AppRoute(page: const HistoryScreen())),
            ),
            const _MenuDivider(),
            _MenuItem(
              icon: Icons.edit_note_outlined,
              label: 'Registrar entrenamiento',
              subtitle: 'Sesión pasada sin móvil',
              onTap: () => Navigator.push(context, AppRoute(page: const ManualTrainingView())),
            ),
          ]),

          const SizedBox(height: AppSpacing.xl),

          // ── Social ────────────────────────────────────────────────
          const _SectionTitle('SOCIAL'),
          const SizedBox(height: AppSpacing.s),
          _MenuCard(children: [
            _MenuItem(
              icon: Icons.group_outlined,
              label: 'Mis grupos',
              onTap: () => Navigator.push(context, AppRoute(page: const GroupsListScreen())),
            ),
            const _MenuDivider(),
            _MenuItem(
              icon: Icons.person_outline,
              label: 'Mi perfil público',
              onTap: _openPublicProfile,
            ),
          ]),

          const SizedBox(height: AppSpacing.xl),

          // ── Configuración ─────────────────────────────────────────
          const _SectionTitle('CONFIGURACIÓN'),
          const SizedBox(height: AppSpacing.s),
          _MenuCard(children: [
            _MenuItem(
              icon: Icons.brightness_6_outlined,
              label: 'Apariencia',
              subtitle: _currentThemeLabel(),
              onTap: _showThemePicker,
            ),
            const _MenuDivider(),
            ListenableBuilder(
              listenable: Listenable.merge([
                HeartRateService().connectionState,
                HeartRateService().connectedDeviceName,
              ]),
              builder: (context, _) {
                final isConnected = HeartRateService().connectionState.value
                    == HrConnectionState.connected;
                final name = HeartRateService().connectedDeviceName.value;
                return _MenuItem(
                  icon: Icons.bluetooth_outlined,
                  label: 'Pulsómetro BLE',
                  subtitle: isConnected
                      ? 'Conectado${name != null ? ' · $name' : ''}'
                      : 'Sin conectar',
                  subtitleColor: isConnected ? AppColors.rpeLow : null,
                  onTap: () => Navigator.push(
                    context,
                    AppRoute(page: const HeartRateMonitorView()),
                  ),
                );
              },
            ),
            const _MenuDivider(),
            _MenuItem(
              icon: Icons.settings_outlined,
              label: 'Cuenta y ajustes',
              onTap: () => Navigator.push(
                context,
                AppRoute(
                  page: AccountSettingsView(
                    currentName: _userName,
                    onNameUpdated: _loadUserData,
                  ),
                ),
              ),
            ),
            const _MenuDivider(),
            _MenuItem(
              icon: Icons.brush_outlined,
              label: 'Editar avatar',
              onTap: () => Navigator.push(
                context,
                AppModalRoute(page: const AvatarEditorWrapperView()),
              ),
            ),
          ]),

          // ── Admin (condicional) ───────────────────────────────────
          if (_isAdmin) ...[
            const SizedBox(height: AppSpacing.xl),
            const _SectionTitle('ADMINISTRACIÓN'),
            const SizedBox(height: AppSpacing.s),
            _MenuCard(children: [
              _MenuItem(
                icon: Icons.admin_panel_settings_outlined,
                label: 'Panel de administrador',
                onTap: () => Navigator.push(context, AppRoute(page: const AdminPanelScreen())),
              ),
            ]),
          ],

          const SizedBox(height: AppSpacing.xxl),

          // ── Cerrar sesión ─────────────────────────────────────────
          Center(
            child: ValueListenableBuilder<bool>(
              valueListenable: _authCtrl.isLoading,
              builder: (context, isLoading, _) => TextButton.icon(
                icon: const Icon(Icons.logout_rounded, size: 18),
                label: Text(isLoading ? 'Cerrando sesión...' : 'Cerrar sesión'),
                style: TextButton.styleFrom(foregroundColor: AppColors.rpeMax),
                onPressed: isLoading ? null : _logout,
              ),
            ),
          ),

          const SizedBox(height: 100),
        ],
      ),
    );
  }
}

// ─── Widgets privados ─────────────────────────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);
  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: AppTypography.small.copyWith(
        color: AppColors.iconMutedOf(context),
        letterSpacing: 1.2,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

class _MenuCard extends StatelessWidget {
  const _MenuCard({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceOf(context),
        border: Border.all(color: AppColors.borderOf(context)),
        borderRadius: BorderRadius.circular(AppDimens.cardRadius),
      ),
      child: Column(children: children),
    );
  }
}

class _MenuItem extends StatelessWidget {
  const _MenuItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.subtitle,
    this.subtitleColor,
  });

  final IconData icon;
  final String label;
  final String? subtitle;
  final Color? subtitleColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppDimens.cardRadius),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.l,
          vertical: AppSpacing.m,
        ),
        child: Row(
          children: [
            Icon(icon, color: AppColors.iconMutedOf(context), size: AppDimens.iconSizeSmall),
            const SizedBox(width: AppSpacing.m),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(label, style: AppTypography.body.copyWith(color: AppColors.textPrimary(context))),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style: AppTypography.small.copyWith(
                        color: subtitleColor ?? AppColors.iconMutedOf(context),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: AppColors.iconMutedOf(context), size: 18),
          ],
        ),
      ),
    );
  }
}

class _MenuDivider extends StatelessWidget {
  const _MenuDivider();

  @override
  Widget build(BuildContext context) {
    // indent = AppSpacing.l (16) + iconSizeSmall (20) + AppSpacing.m (12) = 48
    return Divider(color: AppColors.borderOf(context), height: 1, indent: 48);
  }
}

class _ThemeOption extends StatelessWidget {
  const _ThemeOption(this.label, this.mode, this.icon, this.current);

  final String label;
  final ThemeMode mode;
  final IconData icon;
  final ThemeMode current;

  @override
  Widget build(BuildContext context) {
    final selected = current == mode;
    return ListTile(
      leading: Icon(icon, color: selected ? AppColors.brand : AppColors.iconMutedOf(context)),
      title: Text(
        label,
        style: AppTypography.body.copyWith(
          color: selected ? AppColors.brand : AppColors.textPrimary(context),
          fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
      trailing: selected
          ? const Icon(Icons.check_rounded, color: AppColors.brand, size: 20)
          : null,
      onTap: () {
        ThemeService.setTheme(mode);
        Navigator.pop(context);
      },
    );
  }
}
