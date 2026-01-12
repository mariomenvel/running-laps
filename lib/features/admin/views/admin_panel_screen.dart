import 'package:flutter/material.dart';
import '../viewmodels/admin_controller.dart';
import 'admin_dashboard_tab.dart';
import 'admin_challenges_tab.dart';
import '../../../../config/app_theme.dart';

import '../../../../core/widgets/app_header.dart';
import '../../../../core/widgets/gradient_banner.dart';

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
      backgroundColor: const Color(0xFFF4F6F8),
      body: SafeArea(
        child: Column(
          children: [
             // 1. Header Fijo
            AppHeader(
              showBottomDivider: false,
              onTapRight: () {}, // Opcional
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
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.03),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: TabBar(
                controller: _tabController,
                indicator: BoxDecoration(
                  color: Colors.black87,
                  borderRadius: BorderRadius.circular(16),
                ),
                labelColor: Colors.white,
                unselectedLabelColor: Colors.grey.shade600,
                dividerColor: Colors.transparent,
                splashBorderRadius: BorderRadius.circular(16),
                tabs: const [
                  Tab(text: "Dashboard"),
                  Tab(text: "Retos Globales"),
                ],
              ),
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
