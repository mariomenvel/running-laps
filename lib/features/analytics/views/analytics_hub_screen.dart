import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:running_laps/features/analytics/viewmodels/analytics_hub_controller.dart';
import 'package:running_laps/features/analytics/widgets/analytics_range_selector.dart';
import 'package:running_laps/features/training/data/entrenamiento.dart';
import 'package:running_laps/app/tema.dart';

import 'package:running_laps/features/analytics/views/tabs/overview_tab.dart';
import 'package:running_laps/features/analytics/views/tabs/trends_tab.dart';
import 'package:running_laps/features/analytics/views/tabs/distribution_tab.dart';
import 'package:running_laps/features/analytics/views/tabs/patterns_tab.dart';

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
        title: Text(
          widget.preFilteredData != null ? 'Resultados Filtrados' : 'Analytics Hub',
          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        iconTheme: const IconThemeData(color: Colors.black87),
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
          isScrollable: true,
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
              OverviewTab(controller: _controller),
              TrendsTab(controller: _controller),
              DistributionTab(controller: _controller),
              PatternsTab(controller: _controller),
            ],
          );
        },
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
