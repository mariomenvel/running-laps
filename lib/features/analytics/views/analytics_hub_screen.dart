import 'package:flutter/material.dart';
import 'package:running_laps/core/utils/app_transitions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:running_laps/features/analytics/viewmodels/analytics_hub_controller.dart';
import 'package:running_laps/features/analytics/widgets/analytics_range_selector.dart';
import 'package:running_laps/features/training/data/entrenamiento.dart';
import 'package:running_laps/config/app_theme.dart';

import 'package:running_laps/features/analytics/views/tabs/overview_tab.dart';
import 'package:running_laps/features/analytics/views/tabs/patterns_tab.dart';

import '../../../../core/widgets/app_header.dart';
import '../../../../core/widgets/empty_state_widget.dart';
import '../../../../core/widgets/gradient_banner.dart';
import '../../profile/views/profile_menu_screen.dart';

class AnalyticsHubScreen extends StatefulWidget {
  final List<Entrenamiento>? preFilteredData;
  const AnalyticsHubScreen({super.key, this.preFilteredData});

  @override
  State<AnalyticsHubScreen> createState() => _AnalyticsHubScreenState();
}

class _AnalyticsHubScreenState extends State<AnalyticsHubScreen> with SingleTickerProviderStateMixin {
  late final AnalyticsHubController _controller;
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    final userId = FirebaseAuth.instance.currentUser?.uid ?? '';
    _controller = AnalyticsHubController(userId: userId);
    _controller.initialize(initialData: widget.preFilteredData);
    
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _controller.dispose();
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
            // 1. Header
            AppHeader(
              onTapLeft: () => Navigator.pop(context),
              onTapRight: () {
                Navigator.push(
                  context,
                  AppRoute(page: const ProfileMenuView()),
                );
              },
              showBottomDivider: false,
            ),

            // 2. Banner
            GradientBanner(
              title: widget.preFilteredData != null ? 'Resultados Filtrados' : 'Analytics Hub',
              subtitle: "Tu rendimiento en detalle",
              icon: Icons.analytics_rounded,
              gradientColors: const [Color(0xFF6A1B9A), Color(0xFF8E24AA)], // Purple gradient
              height: 85,
              trailing: SizedBox(
                width: 140, // Limit width for the selector
                child: AnalyticsRangeSelector(controller: _controller),
              ),
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
                  color: Tema.brandPurple,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Tema.brandPurple.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                labelColor: Colors.white,
                unselectedLabelColor: Colors.grey.shade600,
                dividerColor: Colors.transparent,
                indicatorSize: TabBarIndicatorSize.tab,
                splashBorderRadius: BorderRadius.circular(16),
                tabs: const [
                  Tab(text: 'Resumen'),
                  Tab(text: 'Patrones'),
                ],
              ),
            ),

            // 4. Content
            Expanded(
              child: ValueListenableBuilder<bool>(
                valueListenable: _controller.isLoading,
                builder: (context, isLoading, _) {
                  if (isLoading) {
                    return const Center(child: CircularProgressIndicator(color: Tema.brandPurple));
                  }

                  return ValueListenableBuilder<List<Entrenamiento>>(
                    valueListenable: _controller.filteredData,
                    builder: (context, data, _) {
                      if (data.isEmpty) {
                        return const EmptyStateWidget(
                          icon: Icons.bar_chart_rounded,
                          title: 'Sin datos todavía',
                          description:
                              'Completa algunos entrenamientos para ver tus estadísticas y tendencias',
                        );
                      }

                      return TabBarView(
                        controller: _tabController,
                        children: [
                          OverviewTab(controller: _controller),
                          PatternsTab(controller: _controller),
                        ],
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholderTab(String title, IconData icon) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 60, color: Colors.grey.withOpacity(0.5)),
          const SizedBox(height: 16),
          Text(
            title,
            style: TextStyle(fontSize: 18, color: Colors.grey, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            "Se implementará en la siguiente fase",
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }
}

