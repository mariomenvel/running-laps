import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:running_laps/core/theme/app_colors.dart';
import 'package:running_laps/core/theme/app_theme.dart';
import 'package:running_laps/core/utils/app_transitions.dart';
import 'package:running_laps/core/widgets/main_shell.dart';
import 'package:running_laps/core/widgets/shell_embedding_scope.dart';
import 'package:running_laps/core/services/heart_rate_service.dart';
import 'package:running_laps/core/services/user_service.dart';
import 'package:running_laps/core/services/test_data_service.dart';
import 'package:running_laps/core/widgets/modern_snackbar.dart';
import 'package:running_laps/features/auth/viewmodels/auth_controller.dart';
import 'package:running_laps/features/auth/views/auth_page.dart';
import 'package:running_laps/features/onboarding/views/athlete_tutorial_view.dart';
import 'package:running_laps/features/training/views/manual_training_view.dart';
import 'package:running_laps/features/admin/views/admin_panel_screen.dart';
import 'package:running_laps/features/ai_coach/data/ai_coach_repository.dart';
import 'package:running_laps/features/ai_coach/data/ai_coach_models.dart';
import 'package:running_laps/features/ai_coach/views/ai_coach_settings_view.dart';
import 'package:running_laps/features/history/views/history_screen.dart';
import 'package:running_laps/features/profile/views/zones_config_screen.dart';
import 'package:running_laps/features/profile/views/heart_rate_monitor_view.dart';
import 'package:running_laps/features/profile/views/settings_view.dart';
import 'package:running_laps/features/avatar/views/avatar_customizer_view.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:running_laps/features/avatar/models/avatar_config.dart';
import 'package:running_laps/features/avatar/services/avatar_generator.dart';

class ProfileView extends StatefulWidget {
  const ProfileView({super.key});

  @override
  State<ProfileView> createState() => _ProfileViewState();
}

class _ProfileViewState extends State<ProfileView> {
  late final AuthController _authCtrl;

  String _userName = '';
  bool _isAdmin = false;
  bool _isAthleteMode = false;
  AvatarConfig? _avatarConfig;

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
    final data = await UserService().getUserData(uid);
    if (!mounted) return;
    AvatarConfig? parsed;
    final rawConfig = data['generativeAvatarConfig'];
    if (rawConfig is Map<String, dynamic>) {
      parsed = AvatarConfig.fromMap(rawConfig);
    }
    setState(() {
      _userName      = data['nombre'] ?? 'Usuario';
      _isAdmin       = data['isAdmin'] ?? false;
      _isAthleteMode = data['isAthleteMode'] ?? false;
      _avatarConfig  = parsed ?? AvatarConfig.defaults;
    });
  }

  void _showGenerateTestDataDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        title: Text('Generar datos de prueba',
            style: AppTypography.h3.copyWith(color: AppColors.textPrimary(context))),
        content: Text(
          'Esto borrará TODOS tus entrenamientos actuales y creará ~55 sesiones realistas distribuidas en los últimos 90 días.\n\n¿Continuar?',
          style: AppTypography.body.copyWith(color: AppColors.iconMutedOf(context)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _generateTestData();
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.rpeMax),
            child: const Text('Borrar y generar'),
          ),
        ],
      ),
    );
  }

  Future<void> _generateTestData() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    ModernSnackBar.showWarning(context, 'Generando datos de prueba...');

    try {
      final summary = await TestDataService().regenerate(uid);
      if (!mounted) return;
      ModernSnackBar.showSuccess(
        context,
        '${summary.trainings} entrenamientos + sesiones planificadas '
        'generadas · ${summary.totalKm.toStringAsFixed(0)} km',
      );
    } catch (e) {
      if (!mounted) return;
      ModernSnackBar.showError(context, 'Error: $e');
    }
  }

  /// Navega a una sub-pantalla del perfil. Cuando `ProfileView` es el tab
  /// activo del shell (uso normal, slot 3) cambia de tab con `navigateTo`;
  /// cuando se abre pusheada por encima de otra pantalla (Admin, Grupos,
  /// Plantillas — fuera del `IndexedStack` del shell) hace un `Navigator.push`
  /// directo a la misma pantalla, porque cambiar de tab por debajo de una
  /// ruta empujada no sería visible para el usuario.
  void _navigate(
    BuildContext context, {
    required int shellIndex,
    dynamic shellParams,
    required Widget Function() standalone,
  }) {
    if (ShellEmbeddingScope.isEmbedded(context)) {
      MainShell.shellKey.currentState?.navigateTo(shellIndex, params: shellParams);
    } else {
      Navigator.push(context, AppRoute(page: standalone()));
    }
  }

  void _openAvatarCustomizer() {
    _navigate(
      context,
      shellIndex: 14,
      shellParams: _avatarConfig,
      standalone: () => AvatarCustomizerView(initialConfig: _avatarConfig),
    );
  }

  /// Abre una página legal/soporte del dominio propio en el navegador.
  /// Google Play exige que Privacidad y Términos sean alcanzables *dentro* de
  /// la app, no solo desde la ficha de la tienda ni solo en el registro (donde
  /// un usuario ya logueado nunca vuelve).
  Future<void> _openWebPage(String path) async {
    final ok = await launchUrl(
      Uri.parse('https://runninglaps.com$path'),
      mode: LaunchMode.externalApplication,
    );
    if (!ok && mounted) {
      ModernSnackBar.showError(context, 'No se pudo abrir el navegador');
    }
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
                  onTap: _openAvatarCustomizer,
                  child: _avatarConfig != null
                      ? ClipOval(
                          child: SvgPicture.string(
                            AvatarGenerator.generateSVG(_avatarConfig!),
                            width: 80,
                            height: 80,
                            fit: BoxFit.cover,
                          ),
                        )
                      : CircleAvatar(
                          radius: 40,
                          backgroundColor: AppColors.surfaceOf(context),
                          child: Icon(Icons.person, color: AppColors.iconMutedOf(context), size: 40),
                        ),
                ),
                const SizedBox(height: AppSpacing.m),
                Text(_userName, style: AppTypography.h2.copyWith(color: AppColors.textPrimary(context))),
                const SizedBox(height: AppSpacing.xs),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: _isAthleteMode
                        ? AppColors.brand.withValues(alpha: 0.15)
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
              icon: Icons.favorite_outline,
              label: 'Zonas de entrenamiento',
              subtitle: 'FC máx, zonas personalizadas',
              onTap: () => _navigate(
                context,
                shellIndex: 9,
                standalone: () => ZonesConfigScreen(
                    uid: FirebaseAuth.instance.currentUser?.uid ?? ''),
              ),
            ),
            const _MenuDivider(),
            _MenuItem(
              icon: Icons.history_outlined,
              label: 'Historial completo',
              onTap: () => _navigate(
                context,
                shellIndex: 4,
                standalone: () => const HistoryScreen(),
              ),
            ),
            const _MenuDivider(),
            _MenuItem(
              icon: Icons.auto_awesome_outlined,
              label: 'Entrenador IA',
              subtitle: 'Sugerencias semanales',
              onTap: () => _navigate(
                context,
                shellIndex: 16,
                standalone: () => const AiCoachSettingsView(),
              ),
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

          // ── Configuración ─────────────────────────────────────────
          const _SectionTitle('CONFIGURACIÓN'),
          const SizedBox(height: AppSpacing.s),
          _MenuCard(children: [
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
                  onTap: () => _navigate(
                    context,
                    shellIndex: 10,
                    standalone: () => const HeartRateMonitorView(),
                  ),
                );
              },
            ),
            const _MenuDivider(),
            _MenuItem(
              icon: Icons.settings_outlined,
              label: 'Ajustes',
              onTap: () => _navigate(
                context,
                shellIndex: 8,
                shellParams: {'name': _userName, 'onUpdated': _loadUserData},
                standalone: () => SettingsView(
                  currentName: _userName,
                  onNameUpdated: _loadUserData,
                ),
              ),
            ),
            const _MenuDivider(),
            _MenuItem(
              icon: Icons.brush_outlined,
              label: 'Editar avatar',
              onTap: _openAvatarCustomizer,
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
              const _MenuDivider(),
              _MenuItem(
                icon: Icons.refresh_outlined,
                label: 'Generar datos de prueba',
                subtitle: 'Borrará todos tus entrenamientos y creará ~55 realistas',
                onTap: _showGenerateTestDataDialog,
              ),
              const _MenuDivider(),
              _MenuItem(
                icon: Icons.restart_alt_rounded,
                label: 'Reset cuotas IA',
                subtitle: 'Reinicia messagesUsed y previewsGenerated a 0',
                onTap: () async {
                  final uid = FirebaseAuth.instance.currentUser?.uid;
                  if (uid == null) return;
                  final now = DateTime.now();
                  final monday = now.subtract(Duration(days: now.weekday - 1));
                  final sunday = now.add(Duration(days: 7 - now.weekday));
                  await AiCoachRepository().saveUsage(
                    AiCoachUsage(
                      plan: 'athlete_chat_weekly',
                      messagesUsed: 0,
                      previewsGenerated: 0,
                      messagesLimit: 3,
                      periodStart: DateTime(monday.year, monday.month, monday.day),
                      periodEnd: DateTime(
                          sunday.year, sunday.month, sunday.day, 23, 59, 59),
                    ),
                    uid: uid,
                  );
                  if (context.mounted) {
                    ModernSnackBar.showSuccess(context, 'Cuotas reseteadas');
                  }
                },
              ),
              const _MenuDivider(),
              _MenuItem(
                icon: Icons.feedback_outlined,
                label: 'Reset feedback semanal',
                subtitle: 'Elimina el feedback de la semana actual',
                onTap: () async {
                  final uid = FirebaseAuth.instance.currentUser?.uid;
                  if (uid == null) return;

                  final now = DateTime.now();

                  final thisMonday = now.subtract(Duration(days: now.weekday - 1));
                  final thisWeekStart = '${thisMonday.year}-'
                      '${thisMonday.month.toString().padLeft(2, '0')}-'
                      '${thisMonday.day.toString().padLeft(2, '0')}';

                  final lastMonday = thisMonday.subtract(const Duration(days: 7));
                  final lastWeekStart = '${lastMonday.year}-'
                      '${lastMonday.month.toString().padLeft(2, '0')}-'
                      '${lastMonday.day.toString().padLeft(2, '0')}';

                  await AiCoachRepository().deleteWeeklyFeedback(
                    uid: uid,
                    weekStarts: [thisWeekStart, lastWeekStart],
                  );

                  if (context.mounted) {
                    ModernSnackBar.showSuccess(context, 'Feedback reseteado');
                  }
                },
              ),
            ]),
          ],

          const SizedBox(height: AppSpacing.xl),
          const _SectionTitle('AYUDA'),
          const SizedBox(height: AppSpacing.s),
          _MenuCard(children: [
            _MenuItem(
              icon: Icons.school_rounded,
              label: 'Cómo funciona Running Laps',
              subtitle: 'Tutorial del modo atleta',
              onTap: () => Navigator.push(
                context,
                AppRoute(
                  page: const AthleteTutorialView(
                    dismissible: true,
                  ),
                ),
              ),
            ),
            const _MenuDivider(),
            _MenuItem(
              icon: Icons.support_agent_outlined,
              label: 'Ayuda y contacto',
              subtitle: 'soporte@runninglaps.com',
              onTap: () => _openWebPage('/support'),
            ),
            const _MenuDivider(),
            _MenuItem(
              icon: Icons.privacy_tip_outlined,
              label: 'Política de privacidad',
              onTap: () => _openWebPage('/privacy'),
            ),
            const _MenuDivider(),
            _MenuItem(
              icon: Icons.description_outlined,
              label: 'Términos de uso',
              onTap: () => _openWebPage('/terms'),
            ),
          ]),

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

