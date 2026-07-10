// ⚠️ HUÉRFANO — sin referencias activas detectadas
// por auditoría del 2026-06-19. NO USAR como base para
// nuevo desarrollo. Pendiente de confirmar con testing
// manual antes de eliminar. Ver CHANGELOG.md.
import 'package:flutter/material.dart';
import 'package:running_laps/core/utils/app_transitions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:running_laps/features/analytics/viewmodels/analytics_hub_controller.dart';
import 'package:running_laps/features/analytics/widgets/analytics_range_selector.dart';
import 'package:running_laps/features/training/data/entrenamiento.dart';
import 'package:running_laps/config/app_theme.dart';

import 'package:running_laps/features/analytics/views/tabs/overview_tab.dart';
import 'package:running_laps/features/analytics/views/tabs/patterns_tab.dart';
import 'package:running_laps/features/analytics/views/tabs/trends_tab.dart';
import 'package:running_laps/features/analytics/views/tabs/distribution_tab.dart';

import '../../../../core/widgets/app_header.dart';
import '../../../../core/widgets/empty_state_widget.dart';
import '../../../../core/widgets/gradient_banner.dart';
import '../../../../core/widgets/skeleton_shimmer.dart';
import '../../profile/views/profile_menu_screen_legacy.dart';

class AnalyticsHubScreenLegacy extends StatefulWidget {
  final List<Entrenamiento>? preFilteredData;
  const AnalyticsHubScreenLegacy({super.key, this.preFilteredData});

  @override
  State<AnalyticsHubScreenLegacy> createState() => _AnalyticsHubScreenState();
}

class _AnalyticsHubScreenState extends State<AnalyticsHubScreenLegacy> with TickerProviderStateMixin {
  late final AnalyticsHubController _controller;
  late final TabController _tabController;

  // ── Entrance animation ──────────────────────────────────────────
  late final AnimationController _entranceCtrl;
  bool _entrancePlayed = false;
  late final Animation<double> _aBanner;   // 0ms  – fade + slide left
  late final Animation<double> _aTabs;     // 80ms – fade + slide left
  late final Animation<double> _aContent;  // 400ms – fade + slide bottom
  // ────────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    final userId = FirebaseAuth.instance.currentUser?.uid ?? '';
    _controller = AnalyticsHubController(userId: userId);
    _controller.initialize(initialData: widget.preFilteredData);
    
    _tabController = TabController(length: 4, vsync: this);
    _entranceCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200));
    _aBanner  = CurvedAnimation(parent: _entranceCtrl, curve: const Interval(0.000, 0.517, curve: Curves.easeOutQuart));
    _aTabs    = CurvedAnimation(parent: _entranceCtrl, curve: const Interval(0.067, 0.583, curve: Curves.easeOutQuart));
    _aContent = CurvedAnimation(parent: _entranceCtrl, curve: const Interval(0.333, 0.850, curve: Curves.easeOutQuart));
    if (!_entrancePlayed) {
      _entrancePlayed = true;
      _entranceCtrl.forward();
    }
  }

  @override
  void dispose() {
    _entranceCtrl.dispose();
    _controller.dispose();
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        top: false,
        bottom: false,
        child: Column(
          children: [
            // 1. Header
            AppHeader(
              onTapRight: () {
                Navigator.push(
                  context,
                  AppRoute(page: const ProfileMenuView()),
                );
              },
              showBottomDivider: false,
            ),

            // 2. Banner
            _slideFromLeft(_aBanner, GradientBanner(
              title: widget.preFilteredData != null ? 'Resultados Filtrados' : 'Analytics Hub',
              subtitle: "Tu rendimiento en detalle",
              icon: Icons.analytics_rounded,
              accentColor: AppColors.brandSurface,
              height: 85,
              trailing: SizedBox(
                width: 140, // Limit width for the selector
                child: AnalyticsRangeSelector(controller: _controller),
              ),
            )),

            // 3. Tabs
            _slideFromLeft(_aTabs, Builder(
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
                        color: isDark ? Colors.transparent : Colors.black.withValues(alpha: 0.03),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: TabBar(
                    controller: _tabController,
                    indicator: BoxDecoration(
                      color: AppColors.brand,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.brand.withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    labelColor: Colors.white,
                    unselectedLabelColor: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                dividerColor: Colors.transparent,
                indicatorSize: TabBarIndicatorSize.tab,
                splashBorderRadius: BorderRadius.circular(16),
                    tabs: const [
                      Tab(text: 'Resumen'),
                      Tab(text: 'Patrones'),
                      Tab(text: 'Tendencias'),
                      Tab(text: 'Distribución'),
                    ],
                  ),
                );
              },
            )),

            // 4. Content
            Expanded(
              child: _slideFromBottom(_aContent, ValueListenableBuilder<bool>(
                valueListenable: _controller.isLoading,
                builder: (context, isLoading, _) {
                  if (isLoading) {
                    return AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      child: _buildAnalyticsLoadingSkeleton(),
                    );
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
                          TrendsTab(controller: _controller),
                          DistributionTab(controller: _controller),
                        ],
                      );
                    },
                  );
                },
              )),
            ),

          ],
        ),
      ),
    );
  }

  Widget _buildAnalyticsLoadingSkeleton() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SkeletonShimmer(
      key: const ValueKey('analytics_loading'),
      builder: (sv) => SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 3 KPI boxes row
            Row(
              children: List.generate(3, (i) => Expanded(
                child: Container(
                  margin: EdgeInsets.only(left: i == 0 ? 0 : 12),
                  height: 90,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: isDark ? Colors.transparent : Colors.black.withValues(alpha: 0.03),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SkeletonBox(width: 32, height: 32, borderRadius: 10, shimmerValue: sv),
                      const Spacer(),
                      SkeletonLine(shimmerValue: sv),
                    ],
                  ),
                ),
              )),
            ),
            const SizedBox(height: 24),
            // Chart area skeleton
            SkeletonBox(height: 220, shimmerValue: sv, borderRadius: 20),
            const SizedBox(height: 24),
            SkeletonBox(height: 160, shimmerValue: sv, borderRadius: 20),
          ],
        ),
      ),
    );
  }

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

  Widget _buildPlaceholderTab(String title, IconData icon) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 60, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5)),
          const SizedBox(height: 16),
          Text(
            title,
            style: TextStyle(fontSize: 18, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6), fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            "Se implementará en la siguiente fase",
            style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6)),
          ),
        ],
      ),
    );
  }
}

