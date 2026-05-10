import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:running_laps/config/app_theme.dart';
import 'package:running_laps/core/widgets/shell_embedding_scope.dart';
import 'package:running_laps/features/avatar/models/avatar_config.dart';
import 'package:running_laps/features/avatar/services/avatar_generator.dart';
import 'package:running_laps/features/avatar/views/avatar_customizer_view.dart';
import 'package:running_laps/features/calendar/views/calendar_view.dart';
import 'package:running_laps/features/home/views/home_view.dart';
import 'package:running_laps/features/analytics/views/analytics_hub_screen.dart';
import 'package:running_laps/features/profile/views/profile_view.dart';
import 'package:running_laps/features/profile/views/account_settings_view.dart';
import 'package:running_laps/features/profile/views/zones_config_screen.dart';
import 'package:running_laps/features/profile/views/heart_rate_monitor_view.dart';
import 'package:running_laps/features/training/views/training_start_view.dart';
import 'package:running_laps/features/history/views/history_screen.dart';
import 'package:running_laps/features/history/views/training_detail_view.dart';
import 'package:running_laps/features/training/data/entrenamiento.dart';
import 'package:running_laps/features/groups/views/groups_list_screen.dart';
import 'package:running_laps/features/groups/views/group_screen.dart';
import 'package:running_laps/features/templates/views/templates_list_view.dart';
import 'package:running_laps/features/templates/views/template_editor_view.dart';
import 'package:running_laps/features/templates/data/template_models.dart';
import 'package:running_laps/features/athlete/data/athlete_session_model.dart';
import 'package:running_laps/features/templates/views/workout_editor_screen.dart';

// ─── Params para tabs con parámetros ─────────────────────────────────────────

class TemplateEditorShellParams {
  final TrainingTemplate? template;
  final bool isWarmupCooldown;
  const TemplateEditorShellParams({this.template, this.isWarmupCooldown = false});
}

class AthleteSessionShellParams {
  final String date;
  final AthleteSession? session;
  const AthleteSessionShellParams({required this.date, this.session});
}

// ─── MainShell ───────────────────────────────────────────────────────────────

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  static final GlobalKey<_MainShellState> shellKey = GlobalKey<_MainShellState>();

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _tabIndex = 0;
  int _previousTabIndex = 0;

  // Notifiers para tabs con parámetros
  final _detailNotifier          = ValueNotifier<Entrenamiento?>(null);
  final _groupIdNotifier         = ValueNotifier<String?>(null);
  final _accountParamsNotifier   = ValueNotifier<Map<String, dynamic>?>(null);
  final _templateEditorNotifier  = ValueNotifier<TemplateEditorShellParams?>(null);
  final _athleteSessionNotifier  = ValueNotifier<AthleteSessionShellParams?>(null);
  final _avatarConfigNotifier    = ValueNotifier<AvatarConfig?>(null);

  late final List<Widget> _screens = [
    // ── Tabs visibles en NavBar ──────────────────────────────────────────────
    const HomeView(),           // 0 → Inicio
    const CalendarView(),       // 1 → Calendario
    const AnalyticsHubScreen(), // 2 → Analytics
    const ProfileView(),        // 3 → Perfil

    // ── Tabs ocultos en NavBar ───────────────────────────────────────────────
    const HistoryScreen(),      // 4 → Historial

    // 5 → Detalle entrenamiento
    ValueListenableBuilder<Entrenamiento?>(
      valueListenable: _detailNotifier,
      builder: (_, training, __) => training != null
          ? TrainingDetailView(
              key: ValueKey(training.id ?? training.fecha.toIso8601String()),
              training: training,
            )
          : const SizedBox.shrink(),
    ),

    const GroupsListScreen(),   // 6 → Lista de grupos

    // 7 → Detalle de grupo
    ValueListenableBuilder<String?>(
      valueListenable: _groupIdNotifier,
      builder: (_, gid, __) => gid != null
          ? GroupScreen(key: ValueKey(gid), groupId: gid)
          : const SizedBox.shrink(),
    ),

    // 8 → Cuenta y ajustes
    ValueListenableBuilder<Map<String, dynamic>?>(
      valueListenable: _accountParamsNotifier,
      builder: (_, params, __) => AccountSettingsView(
        key: ValueKey(params?['name'] ?? ''),
        currentName: params?['name'] as String? ?? '',
        onNameUpdated: (params?['onUpdated'] as VoidCallback?) ?? () {},
      ),
    ),

    // 9 → Zonas de entrenamiento
    ZonesConfigScreen(
      uid: FirebaseAuth.instance.currentUser?.uid ?? '',
    ),

    const HeartRateMonitorView(), // 10 → Pulsómetro BLE

    const TemplatesListView(),    // 11 → Mis plantillas

    // 12 → Editor de plantilla
    ValueListenableBuilder<TemplateEditorShellParams?>(
      valueListenable: _templateEditorNotifier,
      builder: (_, p, __) => TemplateEditorView(
        key: ValueKey(p?.template?.id ?? 'new-${p.hashCode}'),
        template: p?.template,
        isWarmupCooldown: p?.isWarmupCooldown ?? false,
      ),
    ),

    // 13 → Editor sesión (WorkoutEditorScreen)
    ValueListenableBuilder<AthleteSessionShellParams?>(
      valueListenable: _athleteSessionNotifier,
      builder: (_, p, __) => p != null
          ? WorkoutEditorScreen(
              key: ValueKey('${p.date}-${p.session?.id}-${DateTime.now().millisecondsSinceEpoch}'),
              shellParams: p,
            )
          : const SizedBox.shrink(),
    ),

    // 14 → Avatar customizer
    ValueListenableBuilder<AvatarConfig?>(
      valueListenable: _avatarConfigNotifier,
      builder: (_, config, __) => AvatarCustomizerView(
        key: ValueKey(config?.hashCode),
        initialConfig: config,
      ),
    ),

    const TrainingStartView(), // 15 → Iniciar entrenamiento (FAB)
  ];

  @override
  void dispose() {
    _detailNotifier.dispose();
    _groupIdNotifier.dispose();
    _accountParamsNotifier.dispose();
    _templateEditorNotifier.dispose();
    _athleteSessionNotifier.dispose();
    _avatarConfigNotifier.dispose();
    super.dispose();
  }

  void _onTabTapped(int navIndex) {
    if (navIndex == _tabIndex) return;
    setState(() {
      _previousTabIndex = _tabIndex;
      _tabIndex = navIndex;
    });
  }

  void navigateTo(int index, {dynamic params}) {
    switch (index) {
      case 5:
        if (params is Entrenamiento) _detailNotifier.value = params;
      case 7:
        if (params is String) _groupIdNotifier.value = params;
      case 8:
        if (params is Map<String, dynamic>) _accountParamsNotifier.value = params;
      case 12:
        if (params is TemplateEditorShellParams) {
          _templateEditorNotifier.value = params;
        } else {
          _templateEditorNotifier.value = null;
        }
      case 13:
        if (params is AthleteSessionShellParams) {
          debugPrint('[Shell] navigateTo(13) date=${params.date} session=${params.session?.id}');
          _athleteSessionNotifier.value = params;
        }
      case 14:
        _avatarConfigNotifier.value = params is AvatarConfig ? params : null;
    }
    setState(() {
      _previousTabIndex = _tabIndex;
      _tabIndex = index;
    });
  }

  void navigateBack() {
    setState(() {
      final prev = _previousTabIndex;
      _previousTabIndex = _tabIndex;
      _tabIndex = prev;
    });
  }

  // Mantenido para compatibilidad con código existente
  void navigateToDetail(Entrenamiento training) {
    navigateTo(5, params: training);
  }

  void _launchTraining() {
    navigateTo(15);
  }

  Widget _buildGlobalHeader(BuildContext context) {
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          bottom: BorderSide(
            color: AppColors.borderOf(context),
            width: 0.5,
          ),
        ),
      ),
      child: Row(
        children: [
          const CircleAvatar(
            radius: 22,
            backgroundColor: AppColors.brand,
            backgroundImage: AssetImage('assets/images/logo.png'),
          ),
          const Spacer(),
          const _LiveAvatarBadge(radius: 20),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          SizedBox(height: MediaQuery.of(context).padding.top),
          _buildGlobalHeader(context),
          Expanded(
            child: ShellEmbeddingScope(
              child: IndexedStack(
                index: _tabIndex,
                children: _screens,
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _tabIndex == 15
          ? const SizedBox.shrink()
          : _NavBar(
              currentIndex: _tabIndex,
              onTabTapped: _onTabTapped,
              onFabTapped: _launchTraining,
              fabActive: _tabIndex == 15,
            ),
    );
  }
}

// ─── Bottom Nav Bar ──────────────────────────────────────────────────────────

class _NavBar extends StatelessWidget {
  const _NavBar({
    required this.currentIndex,
    required this.onTabTapped,
    required this.onFabTapped,
    required this.fabActive,
  });

  final int currentIndex;
  final ValueChanged<int> onTabTapped;
  final VoidCallback onFabTapped;
  final bool fabActive;

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).padding.bottom;

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          top: BorderSide(color: Theme.of(context).colorScheme.outline, width: 0.5),
        ),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 60,
          child: Row(
            children: [
              _NavItem(
                icon: Icons.home_outlined,
                activeIcon: Icons.home_rounded,
                label: 'Inicio',
                active: currentIndex == 0,
                onTap: () => onTabTapped(0),
              ),
              _NavItem(
                icon: Icons.calendar_today_outlined,
                activeIcon: Icons.calendar_today_rounded,
                label: 'Calendario',
                active: currentIndex == 1,
                onTap: () => onTabTapped(1),
              ),
              // FAB central
              _FabItem(onTap: onFabTapped, active: fabActive),
              _NavItem(
                icon: Icons.bar_chart_outlined,
                activeIcon: Icons.bar_chart_rounded,
                label: 'Analytics',
                active: currentIndex == 2,
                onTap: () => onTabTapped(2),
              ),
              _NavItem(
                icon: Icons.person_outlined,
                activeIcon: Icons.person_rounded,
                label: 'Perfil',
                active: currentIndex == 3,
                onTap: () => onTabTapped(3),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Tab item ─────────────────────────────────────────────────────────────────

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = active
        ? AppColors.brand
        : Theme.of(context).colorScheme.onSurface.withOpacity(0.5);

    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(active ? activeIcon : icon, color: color, size: 24),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 10,
                fontWeight: active ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Live avatar badge (Firestore stream) ────────────────────────────────────

class _LiveAvatarBadge extends StatelessWidget {
  const _LiveAvatarBadge({required this.radius});
  final double radius;

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return _placeholder(context);

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
      builder: (context, snap) {
        AvatarConfig config = AvatarConfig.defaults;
        if (snap.hasData && snap.data!.exists) {
          final data = snap.data!.data() as Map<String, dynamic>;
          final raw = data['generativeAvatarConfig'];
          if (raw is Map<String, dynamic>) {
            config = AvatarConfig.fromMap(raw);
          }
        }
        return ClipOval(
          child: SvgPicture.string(
            AvatarGenerator.generateSVG(config),
            width: radius * 2,
            height: radius * 2,
            fit: BoxFit.cover,
          ),
        );
      },
    );
  }

  Widget _placeholder(BuildContext context) => CircleAvatar(
        radius: radius,
        backgroundColor: AppColors.surfaceOf(context),
        child: Icon(Icons.person, color: AppColors.iconMutedOf(context), size: radius),
      );
}

// ─── FAB central ─────────────────────────────────────────────────────────────

class _FabItem extends StatelessWidget {
  const _FabItem({required this.onTap, required this.active});

  final VoidCallback onTap;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Center(
          child: Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: active ? AppColors.brandDark : AppColors.brand,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.play_arrow_rounded,
              color: Colors.white,
              size: 28,
            ),
          ),
        ),
      ),
    );
  }
}
