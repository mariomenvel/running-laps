import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:running_laps/config/app_theme.dart';
import 'package:running_laps/core/utils/app_transitions.dart';
import 'package:running_laps/features/avatar/models/avatar_config.dart';
import 'package:running_laps/features/avatar/services/avatar_generator.dart';
import 'package:running_laps/features/calendar/views/calendar_view.dart';
import 'package:running_laps/features/home/views/home_view.dart';
import 'package:running_laps/features/analytics/views/analytics_hub_screen.dart';
import 'package:running_laps/features/profile/views/profile_view.dart';
import 'package:running_laps/features/training/views/training_start_view.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  // Tab activo: 0=Home 1=Calendario 2=Analytics 3=Perfil
  int _tabIndex = 0;

  // IndexedStack: 4 slots reales (sin el FAB)
  // índices: 0=Home 1=Calendario 2=Analytics 3=Perfil
  late final List<Widget> _screens = [
    const HomeView(),                   // 0 → Home
    const CalendarView(),               // 1 → Calendario
    const AnalyticsHubScreen(),         // 2 → Analytics
    const ProfileView(),                 // 3 → Perfil
  ];

  void _onTabTapped(int navIndex) {
    // navIndex 2 es el FAB — lo interceptamos arriba en onTap del item
    if (navIndex == _tabIndex) return; // ya estamos aquí
    setState(() => _tabIndex = navIndex);
  }

  void _launchTraining() {
    Navigator.push(
      context,
      AppRoute(page: const TrainingStartView()),
    );
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
            child: IndexedStack(
              index: _tabIndex,
              children: _screens,
            ),
          ),
        ],
      ),
      bottomNavigationBar: _NavBar(
        currentIndex: _tabIndex,
        onTabTapped: _onTabTapped,
        onFabTapped: _launchTraining,
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
  });

  final int currentIndex;
  final ValueChanged<int> onTabTapped;
  final VoidCallback onFabTapped;

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
              // FAB central — no cambia tab
              _FabItem(onTap: onFabTapped),
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
  const _FabItem({required this.onTap});

  final VoidCallback onTap;

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
            decoration: const BoxDecoration(
              color: AppColors.brand,
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
