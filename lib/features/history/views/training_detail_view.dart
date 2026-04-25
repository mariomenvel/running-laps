import 'package:flutter/material.dart';
// fl_chart was here
import 'package:running_laps/config/app_theme.dart';
import 'package:running_laps/core/theme/app_colors.dart';
import 'package:running_laps/features/training/data/entrenamiento.dart';
import 'package:running_laps/core/widgets/gradient_banner.dart';
import 'package:running_laps/core/widgets/app_header.dart';
import 'package:running_laps/core/widgets/app_page_scaffold.dart';
import 'package:running_laps/features/templates/data/template_models.dart';

import '../widgets/training_map_view.dart';

class TrainingDetailView extends StatefulWidget {
  final Entrenamiento training;

  const TrainingDetailView({super.key, required this.training});

  @override
  State<TrainingDetailView> createState() => _TrainingDetailViewState();
}

class _TrainingDetailViewState extends State<TrainingDetailView>
    with SingleTickerProviderStateMixin {
  Entrenamiento get training => widget.training;

  // ── Entrance animation ──────────────────────────────────────────
  late final AnimationController _entranceCtrl;
  late final Animation<double> _aBanner;      // 0ms   – fade + slide left
  late final Animation<double> _aStats;       // 100ms – scale in
  late final Animation<double> _aMap;         // 200ms – fade + slide bottom
  late final Animation<double> _aSeries;      // 350ms – fade + slide bottom
  late final Animation<double> _aComparison;  // 500ms – fade + slide bottom
  // ────────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _entranceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _aBanner     = CurvedAnimation(parent: _entranceCtrl, curve: const Interval(0.000, 0.517, curve: Curves.easeOutQuart));
    _aStats      = CurvedAnimation(parent: _entranceCtrl, curve: const Interval(0.083, 0.600, curve: Curves.easeOutQuart));
    _aMap        = CurvedAnimation(parent: _entranceCtrl, curve: const Interval(0.167, 0.683, curve: Curves.easeOutQuart));
    _aSeries     = CurvedAnimation(parent: _entranceCtrl, curve: const Interval(0.292, 0.808, curve: Curves.easeOutQuart));
    _aComparison = CurvedAnimation(parent: _entranceCtrl, curve: const Interval(0.417, 0.933, curve: Curves.easeOutQuart));
    _entranceCtrl.forward();
  }

  @override
  void dispose() {
    _entranceCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppPageScaffold(
      header: const AppHeader(
        showBottomDivider: false,
      ),
      body: Column(
        children: [
            _slideFromLeft(_aBanner, GradientBanner(
              title: training.titulo,
              subtitle: "Análisis con Mapa GPS",
              icon: Icons.map_rounded,
              gradientColors: const [Tema.brandPurple, Color(0xFF6A1B9A)],
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
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _scaleIn(_aStats, _buildStatsGrid()),
                    const SizedBox(height: 24),
                    _slideFromBottom(_aMap, _buildMapCard()),
                    const SizedBox(height: 32),
                    _slideFromBottom(_aSeries, _buildSeriesSection()),
                    if (training.notas != null && training.notas!.isNotEmpty) ...[
                      const SizedBox(height: 32),
                      _slideFromBottom(_aSeries, _buildNotasSection()),
                    ],
                    if (training.plannedComparison != null) ...[
                      const SizedBox(height: 32),
                      _slideFromBottom(_aComparison, _buildComparisonSection()),
                      const SizedBox(height: 32),
                    ],
                  ],
                ),
              ),
            ),
          ],
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

  Widget _buildMapCard() {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.transparent
                : Colors.black.withOpacity(0.04),
            offset: const Offset(0, 6),
            blurRadius: 16,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.purple.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.route_rounded, color: Theme.of(context).brightness == Brightness.dark ? AppColors.brandPurpleLight : Tema.brandPurple, size: 18),
                ),
                const SizedBox(width: 12),
                Text(
                  "Mapa de Ruta",
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface),
                ),
              ],
            ),
          ),
          ClipRRect(
            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
            child: SizedBox(
              height: 300, // Slightly taller for better map view
              child: _buildRouteMap(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRouteMap() {
    if (training.trackPoints.isEmpty) {
      return Container(
        color: const Color(0xFFE5E3DF),
        child: const Center(
          child: Text(
            "Sin datos de mapa",
            style: TextStyle(color: Colors.black54, fontWeight: FontWeight.bold),
          ),
        ),
      );
    }

    return TrainingMapView(points: training.trackPoints);
  }

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
        if (training.fcMediaSesion != null) ...[
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  "FC media",
                  "${training.fcMediaSesion!.round()} ppm",
                  Icons.favorite_rounded,
                  AppColors.rpeMax,
                ),
              ),
              const Expanded(child: SizedBox()),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildNotasSection() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.brandPurple.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.notes_rounded,
                  color: isDark ? AppColors.brandPurpleLight : AppColors.brandPurple,
                  size: 20),
            ),
            const SizedBox(width: 12),
            Text(
              'NOTAS',
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1C1C1E) : const Color(0xFFF2F2F7),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDark ? const Color(0xFF38383A) : const Color(0xFFE5E7EB),
            ),
          ),
          child: Text(
            training.notas!,
            style: TextStyle(
              fontSize: 15,
              height: 1.5,
              color: isDark ? const Color(0xFFEBEBF5) : const Color(0xFF3A3A3C),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.transparent
                : Colors.black.withOpacity(0.04),
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
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface,
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
              child: Icon(Icons.list_alt_rounded, color: Theme.of(context).brightness == Brightness.dark ? AppColors.brandPurpleLight : Tema.brandPurple, size: 20),
            ),
            const SizedBox(width: 12),
            Text(
              "Desglose de Series",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface),
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
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.transparent
                      : Colors.black.withOpacity(0.03),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
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
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).brightness == Brightness.dark ? AppColors.brandPurpleLight : Tema.brandPurple,
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

  // ── Comparativa planificado vs ejecutado ─────────────────────────

  Widget _buildComparisonSection() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final comp = training.plannedComparison!;
    final blocks = (comp['blocks'] as List<dynamic>? ?? []);

    Widget header = Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.rpeMid.withOpacity(0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.compare_arrows_rounded,
              color: AppColors.rpeMid, size: 18),
        ),
        const SizedBox(width: 12),
        Text(
          'PLANIFICADO VS EJECUTADO',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ],
    );

    final category = comp['sessionCategory'] as String?;

    if (blocks.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            header,
            const SizedBox(height: 16),
            const Text('Sin datos de comparativa',
                style: TextStyle(fontSize: 13, color: Color(0xFF8E8E93))),
          ],
        ),
      );
    }

    final deltas = <double>[];
    for (final b in blocks) {
      final planned = b['planned'] as Map?;
      final executed = b['executed'] as Map?;
      final tps = (planned?['targetPaceSec'] as num?)?.toDouble();
      final eps = (executed?['paceSec'] as num?)?.toDouble();
      if (tps != null && eps != null) deltas.add(eps - tps);
    }
    final avgDelta =
        deltas.isEmpty ? null : deltas.reduce((a, b) => a + b) / deltas.length;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.transparent
                : Colors.black.withOpacity(0.04),
            offset: const Offset(0, 6),
            blurRadius: 16,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          header,
          if (category != null) ...[
            const SizedBox(height: 8),
            Text(
              SessionCategoryX.fromValue(category).label,
              style: const TextStyle(
                  fontSize: 13, color: AppColors.brandPurpleLight),
            ),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              const SizedBox(
                width: 64,
                child: Text('Serie',
                    style: TextStyle(fontSize: 11, color: Color(0xFF8E8E93))),
              ),
              const Expanded(
                child: Text('Planificado',
                    style: TextStyle(fontSize: 11, color: Color(0xFF8E8E93)),
                    textAlign: TextAlign.center),
              ),
              const Expanded(
                child: Text('Ejecutado',
                    style: TextStyle(fontSize: 11, color: Color(0xFF8E8E93)),
                    textAlign: TextAlign.center),
              ),
              const SizedBox(
                width: 52,
                child: Text('Delta',
                    style: TextStyle(fontSize: 11, color: Color(0xFF8E8E93)),
                    textAlign: TextAlign.right),
              ),
            ],
          ),
          const Divider(color: Color(0xFF3A3A3C), height: 20),
          ...blocks.map((b) {
            final planned = b['planned'] as Map?;
            final executed = b['executed'] as Map?;
            final order = (b['order'] as num?)?.toInt() ?? 0;

            final targetPaceSec =
                (planned?['targetPaceSec'] as num?)?.toDouble();
            final execPaceSec =
                (executed?['paceSec'] as num?)?.toDouble();

            final targetPaceStr =
                targetPaceSec != null ? _formatPace(targetPaceSec) : '—';
            final execPaceStr =
                execPaceSec != null ? _formatPace(execPaceSec) : '—';

            double? delta;
            if (targetPaceSec != null && execPaceSec != null) {
              delta = execPaceSec - targetPaceSec;
            }

            final onSurface = Theme.of(context).colorScheme.onSurface;

            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 64,
                        child: Text(
                          'Serie ${order + 1}',
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: onSurface),
                        ),
                      ),
                      Expanded(
                        child: Column(
                          children: [
                            Text(
                              targetPaceStr,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: targetPaceSec != null
                                    ? onSurface
                                    : const Color(0xFF8E8E93),
                              ),
                              textAlign: TextAlign.center,
                            ),
                            if ((planned?['targetRpe'] as num?) != null) ...[
                              const SizedBox(height: 2),
                              Text(
                                'RPE ${(planned!['targetRpe'] as num).toStringAsFixed(1)}',
                                style: TextStyle(
                                    fontSize: 11,
                                    color: _rpeColor((planned['targetRpe']
                                            as num)
                                        .toDouble())),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ],
                        ),
                      ),
                      Expanded(
                        child: Column(
                          children: [
                            if (executed == null)
                              const Text(
                                'No ejecutada',
                                style: TextStyle(
                                    fontSize: 12, color: Color(0xFF8E8E93)),
                                textAlign: TextAlign.center,
                              )
                            else ...[
                              Text(
                                execPaceStr,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: delta != null
                                      ? _deltaColor(delta)
                                      : onSurface,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              if ((executed['rpe'] as num?) != null) ...[
                                const SizedBox(height: 2),
                                Text(
                                  'RPE ${(executed['rpe'] as num).toStringAsFixed(1)}',
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: _rpeColor(
                                          (executed['rpe'] as num)
                                              .toDouble())),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ],
                          ],
                        ),
                      ),
                      SizedBox(
                        width: 52,
                        child: delta != null
                            ? Text(
                                delta >= 0
                                    ? '+${_formatPaceDelta(delta)}'
                                    : '-${_formatPaceDelta(delta.abs())}',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: _deltaColor(delta),
                                ),
                                textAlign: TextAlign.right,
                              )
                            : const SizedBox.shrink(),
                      ),
                    ],
                  ),
                ),
                Divider(
                    color: const Color(0xFF3A3A3C).withOpacity(0.5),
                    height: 1),
              ],
            );
          }),
          if (avgDelta != null) ...[
            const SizedBox(height: 12),
            _buildComparisonSummary(avgDelta),
          ],
        ],
      ),
    );
  }

  Widget _buildComparisonSummary(double avgDelta) {
    String text;
    IconData icon;
    Color color;

    if (avgDelta < -15) {
      text = 'Fuiste más rápido de lo planeado 🔥';
      icon = Icons.bolt_rounded;
      color = AppColors.rpeLow;
    } else if (avgDelta < 15) {
      text = 'Muy ajustado al plan ✓';
      icon = Icons.check_circle_outline_rounded;
      color = AppColors.rpeLow;
    } else if (avgDelta < 30) {
      text = 'Algo por encima del objetivo';
      icon = Icons.warning_amber_rounded;
      color = AppColors.rpeMid;
    } else {
      text = 'Bastante por encima del objetivo';
      icon = Icons.error_outline_rounded;
      color = AppColors.rpeMax;
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text,
                style: TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w500, color: color)),
          ),
        ],
      ),
    );
  }

  String _formatPace(double secPerKm) {
    final min = secPerKm ~/ 60;
    final sec = (secPerKm % 60).round();
    return '$min:${sec.toString().padLeft(2, '0')} /km';
  }

  String _formatPaceDelta(double sec) {
    if (sec < 60) return '${sec.round()}s';
    return '${(sec / 60).toStringAsFixed(1)}min';
  }

  Color _deltaColor(double delta) {
    if (delta.abs() <= 15) return AppColors.rpeLow;
    if (delta.abs() <= 30) return AppColors.rpeMid;
    return AppColors.rpeMax;
  }

  Color _rpeColor(double rpe) {
    if (rpe <= 4) return AppColors.rpeLow;
    if (rpe <= 7) return AppColors.rpeMid;
    return AppColors.rpeMax;
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
          color: _isPressed
              ? Theme.of(context).colorScheme.onSurface.withOpacity(0.08)
              : Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.transparent
                  : Colors.black.withOpacity(_isPressed ? 0.03 : 0.06),
              blurRadius: _isPressed ? 4 : 12,
              offset: Offset(0, _isPressed ? 2 : 4),
            ),
          ],
          border: Border.all(color: Tema.brandPurple.withOpacity(0.1)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.arrow_back_ios_new_rounded,
              size: 16,
              color: Theme.of(context).brightness == Brightness.dark
                  ? AppColors.brandPurpleLight
                  : Tema.brandPurple,
            ),
            const SizedBox(width: 6),
            Text(
              "Volver",
              style: TextStyle(
                color: Theme.of(context).brightness == Brightness.dark
                    ? AppColors.brandPurpleLight
                    : Tema.brandPurple,
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
