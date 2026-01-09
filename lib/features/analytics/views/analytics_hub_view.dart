import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:running_laps/features/analytics/viewmodels/analytics_hub_controller.dart';
import 'package:running_laps/features/analytics/widgets/analytics_range_selector.dart';
import 'package:running_laps/config/app_theme.dart';

// Placeholder imports for tabs (Phase 4)
// import 'package:running_laps/features/analytics/views/tabs/overview_tab.dart';
// import 'package:running_laps/features/analytics/views/tabs/trends_tab.dart';
// import 'package:running_laps/features/analytics/views/tabs/distribution_tab.dart';
// import 'package:running_laps/features/analytics/views/tabs/patterns_library_tab.dart';

class AnalyticsHubView extends StatefulWidget {
  const AnalyticsHubView({super.key});

  @override
  State<AnalyticsHubView> createState() => _AnalyticsHubViewState();
}

class _AnalyticsHubViewState extends State<AnalyticsHubView> with SingleTickerProviderStateMixin {
  late final AnalyticsHubController _controller;
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    final userId = FirebaseAuth.instance.currentUser?.uid ?? '';
    _controller = AnalyticsHubController(userId: userId);
    _controller.initialize();
    
    _tabController = TabController(length: 4, vsync: this);
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
      appBar: AppBar(
        title: const Text('Analytics Hub', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: AnalyticsRangeSelector(controller: _controller),
            ),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true, // Allow scrolling if needed on small screens
          labelColor: Tema.brandPurple,
          unselectedLabelColor: Colors.grey,
          indicatorColor: Tema.brandPurple,
          indicatorWeight: 3,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold),
          tabs: const [
            Tab(text: 'Resumen'),
            Tab(text: 'Tendencias'),
            Tab(text: 'Distribución'),
            Tab(text: 'Patrones'),
          ],
        ),
      ),
      body: ValueListenableBuilder<bool>(
        valueListenable: _controller.isLoading,
        builder: (context, isLoading, child) {
          if (isLoading) {
            return const Center(child: CircularProgressIndicator(color: Tema.brandPurple));
          }
          
          return TabBarView(
            controller: _tabController,
            children: [
              _buildPlaceholderTab("Resumen (Phase 4)"),
              _buildPlaceholderTab("Tendencias (Phase 4)"),
              _buildPlaceholderTab("Distribución (Phase 4)"),
              _buildPlaceholderTab("Patrones (Phase 4)"),
            ],
          );
        },
      ),
    );
  }

  Widget _buildPlaceholderTab(String title) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.bar_chart, size: 48, color: Colors.grey),
          const SizedBox(height: 16),
          Text(
            title,
            style: const TextStyle(fontSize: 18, color: Colors.grey, fontWeight: FontWeight.bold),
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

