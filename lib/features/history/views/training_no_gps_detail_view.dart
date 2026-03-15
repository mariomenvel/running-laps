import 'package:flutter/material.dart';
import 'package:running_laps/config/app_theme.dart';
import 'package:running_laps/features/training/data/entrenamiento.dart';
import 'package:running_laps/core/widgets/gradient_banner.dart';
import 'package:running_laps/core/widgets/app_header.dart';

class TrainingNoGpsDetailView extends StatefulWidget {
  final Entrenamiento training;

  const TrainingNoGpsDetailView({Key? key, required this.training}) : super(key: key);

  @override
  State<TrainingNoGpsDetailView> createState() => _TrainingNoGpsDetailViewState();
}

class _TrainingNoGpsDetailViewState extends State<TrainingNoGpsDetailView>
    with SingleTickerProviderStateMixin {
  Entrenamiento get training => widget.training;

  // ── Entrance animation ──────────────────────────────────────────
  late final AnimationController _entranceCtrl;
  late final Animation<double> _aBanner;  // 0ms   – fade + slide left
  late final Animation<double> _aStats;   // 100ms – scale in
  late final Animation<double> _aSeries;  // 200ms – fade + slide bottom
  // ────────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _entranceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _aBanner = CurvedAnimation(parent: _entranceCtrl, curve: const Interval(0.000, 0.517, curve: Curves.easeOutQuart));
    _aStats  = CurvedAnimation(parent: _entranceCtrl, curve: const Interval(0.083, 0.600, curve: Curves.easeOutQuart));
    _aSeries = CurvedAnimation(parent: _entranceCtrl, curve: const Interval(0.167, 0.683, curve: Curves.easeOutQuart));
    _entranceCtrl.forward();
  }

  @override
  void dispose() {
    _entranceCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F8),
      body: SafeArea(
        child: Column(
          children: [
            AppHeader(
              showBottomDivider: false,
              onTapLeft: () => Navigator.pop(context),
            ),
            _slideFromLeft(_aBanner, GradientBanner(
              title: training.titulo,
              subtitle: "Análisis del Entrenamiento",
              icon: Icons.analytics_rounded,
              gradientColors: const [Tema.brandPurple, Color(0xFF8E44AD)],
              height: 100,
            )),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                children: [
                  _AnimatedBackButton(onTap: () => Navigator.pop(context)),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _scaleIn(_aStats, _buildStatsGrid()),
                    const SizedBox(height: 32),
                    _slideFromBottom(_aSeries, _buildSeriesSection()),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
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

  Widget _scaleIn(Animation<double> anim, Widget child) {
    return AnimatedBuilder(
      animation: anim,
      builder: (_, __) => Opacity(
        opacity: anim.value,
        child: Transform.scale(
          scale: 0.85 + 0.15 * anim.value,
          child: child,
        ),
      ),
    );
  }
  // ─────────────────────────────────────────────────────────────────

  Widget _buildStatsGrid() {
    final double distKm = training.distanciaTotalM() / 1000.0;
    final String timeStr = _formatDuration(training.tiempoTotalSec().round());
    final String paceStr = training.ritmoMedioTexto();
    final double rpe = training.rpePromedio();

    return Column(
      children: [
        Row(
          children: [
            Expanded(child: _buildStatCard("Distancia", "${distKm.toStringAsFixed(2)} km", Icons.straighten, Colors.blue)),
            const SizedBox(width: 16),
            Expanded(child: _buildStatCard("Tiempo", timeStr, Icons.timer, Colors.orange)),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(child: _buildStatCard("Ritmo Medio", paceStr, Icons.speed, Colors.green)),
            const SizedBox(width: 16),
            Expanded(child: _buildStatCard("RPE Promedio", rpe.toStringAsFixed(1), Icons.bolt, Colors.red)),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            offset: const Offset(0, 6),
            blurRadius: 16,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(height: 16),
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade500,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSeriesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Tema.brandPurple.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.list_alt_rounded, color: Tema.brandPurple, size: 20),
            ),
            const SizedBox(width: 12),
            const Text(
              "Desglose de Series",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
            ),
          ],
        ),
        const SizedBox(height: 16),
        ...training.series.asMap().entries.map((entry) {
          final index = entry.key;
          final serie = entry.value;
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4)),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Tema.brandPurple.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    "${index + 1}",
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Tema.brandPurple,
                      fontSize: 13,
                    ),
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "${serie.distanciaM}m",
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            _formatDuration(serie.tiempoSec.round()),
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            serie.ritmoTexto(),
                            style: TextStyle(fontSize: 13, color: Colors.green.shade600, fontWeight: FontWeight.w600),
                          ),
                          if (serie.rpe > 0)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.red.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                "RPE ${serie.rpe}",
                                style: const TextStyle(fontSize: 11, color: Colors.red, fontWeight: FontWeight.bold),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ],
    );
  }

  String _formatDuration(int totalSeconds) {
    if (totalSeconds < 60) return "${totalSeconds}s";
    final int minutes = totalSeconds ~/ 60;
    final int seconds = totalSeconds % 60;
    if (minutes > 60) {
      final int hours = minutes ~/ 60;
      final int mins = minutes % 60;
      return "${hours}h ${mins}m";
    }
    return "${minutes}m ${seconds.toString().padLeft(2, '0')}s";
  }
}

class _AnimatedBackButton extends StatefulWidget {
  final VoidCallback onTap;
  const _AnimatedBackButton({required this.onTap});

  @override
  State<_AnimatedBackButton> createState() => _AnimatedBackButtonState();
}

class _AnimatedBackButtonState extends State<_AnimatedBackButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) {
        setState(() => _isPressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: _isPressed ? Colors.grey.shade100 : Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(_isPressed ? 0.03 : 0.06),
              blurRadius: _isPressed ? 4 : 12,
              offset: Offset(0, _isPressed ? 2 : 4),
            ),
          ],
          border: Border.all(color: Tema.brandPurple.withOpacity(0.1)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.arrow_back_ios_new_rounded,
              size: 16,
              color: Tema.brandPurple,
            ),
            const SizedBox(width: 6),
            const Text(
              "Volver",
              style: TextStyle(
                color: Tema.brandPurple,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
