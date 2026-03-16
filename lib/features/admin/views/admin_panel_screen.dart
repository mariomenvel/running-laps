import 'package:flutter/material.dart';
import 'package:running_laps/core/utils/app_transitions.dart';
import '../viewmodels/admin_controller.dart';
import 'admin_dashboard_tab.dart';
import 'admin_challenges_tab.dart';
import '../../../../config/app_theme.dart';

import 'package:running_laps/core/widgets/app_header.dart';
import 'package:running_laps/core/widgets/gradient_banner.dart';
import 'package:running_laps/features/profile/views/profile_menu_screen.dart';

class AdminPanelScreen extends StatefulWidget {
  const AdminPanelScreen({super.key});

  @override
  State<AdminPanelScreen> createState() => _AdminPanelScreenState();
}

class _AdminPanelScreenState extends State<AdminPanelScreen> with SingleTickerProviderStateMixin {
  late AdminController _controller;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _controller = AdminController();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
             // 1. Header Fijo
            AppHeader(
              showBottomDivider: false,
              onTapRight: () => Navigator.push(
                context,
                AppRoute(page: const ProfileMenuView()),
              ),
            ),

            // 2. Banner con gradiente
            const GradientBanner(
              title: "Panel de Control",
              subtitle: "Gestiona retos globales y visualiza estadísticas",
              icon: Icons.admin_panel_settings_rounded,
              gradientColors: [Colors.black87, Colors.black54], // Toque más serio/admin
              height: 85,
            ),
            
            // 3. Tabs
            Builder(
              builder: (context) {
                final isDark = Theme.of(context).brightness == Brightness.dark;
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: isDark ? Colors.transparent : Colors.black.withOpacity(0.03),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: TabBar(
                    controller: _tabController,
                    indicator: BoxDecoration(
                      color: Theme.of(context).colorScheme.onSurface,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    labelColor: Theme.of(context).colorScheme.surface,
                    unselectedLabelColor: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                    dividerColor: Colors.transparent,
                    indicatorSize: TabBarIndicatorSize.tab,
                    splashBorderRadius: BorderRadius.circular(16),
                    tabs: const [
                      Tab(text: "Dashboard"),
                      Tab(text: "Retos Globales"),
                    ],
                  ),
                );
              },
            ),
            
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  AdminDashboardTab(controller: _controller),
                  AdminChallengesTab(controller: _controller),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
