import 'dart:math' show max, min;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:running_laps/config/app_theme.dart';
import 'package:running_laps/core/services/zones_service.dart';
import 'package:running_laps/core/theme/app_colors.dart';
import 'package:running_laps/core/widgets/rpe_badge.dart';
import 'package:running_laps/features/profile/data/zones_repository.dart';
import 'package:running_laps/features/training/data/entrenamiento.dart';
import 'package:running_laps/core/widgets/gradient_banner.dart';
import 'package:running_laps/core/widgets/app_header.dart';
import 'package:running_laps/core/widgets/app_page_scaffold.dart';
import 'package:running_laps/features/templates/data/template_models.dart';

// ignore: unused_element
class TrainingNoGpsDetailViewLegacy extends StatefulWidget {
  final Entrenamiento training;

  const TrainingNoGpsDetailViewLegacy({Key? key, required this.training}) : super(key: key);

  @override
  State<TrainingNoGpsDetailViewLegacy> createState() => _TrainingNoGpsDetailViewLegacyState();
}

class _TrainingNoGpsDetailViewLegacyState extends State<TrainingNoGpsDetailViewLegacy>
    with SingleTickerProviderStateMixin {
  Entrenamiento get training => widget.training;

  // ── Entrance animation ──────────────────────────────────────────
  late final AnimationController _entranceCtrl;
  late final Animation<double> _aBanner;      // 0ms   – fade + slide left
  late final Animation<double> _aStats;       // 100ms – scale in
  late final Animation<double> _aSeries;      // 200ms – fade + slide bottom
  late final Animation<double> _aComparison;  // 350ms – fade + slide bottom
  // ────────────────────────────────────────────────────────────────

  late final Future<int?> _fcMaxFuture;

  @override
  void initState() {
    super.initState();
    _entranceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _aBanner     = CurvedAnimation(parent: _entranceCtrl, curve: const Interval(0.000, 0.517, curve: Curves.easeOutQuart));
    _aStats      = CurvedAnimation(parent: _entranceCtrl, curve: const Interval(0.083, 0.600, curve: Curves.easeOutQuart));
    _aSeries     = CurvedAnimation(parent: _entranceCtrl, curve: const Interval(0.167, 0.683, curve: Curves.easeOutQuart));
    _aComparison = CurvedAnimation(parent: _entranceCtrl, curve: const Interval(0.292, 0.808, curve: Curves.easeOutQuart));
    _entranceCtrl.forward();
    _fcMaxFuture = _loadFcMax();
  }

  Future<int?> _loadFcMax() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return null;
      final profile = await ZonesRepository().getUserProfile(uid);
      return profile?.fcMax;
    } catch (e) {
      debugPrint('[TrainingNoGpsDetailView] error cargando fcMax: $e');
      return null;
    }
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
              subtitle: "Análisis del Entrenamiento",
              icon: Icons.analytics_rounded,
              accentColor: AppColors.brandSurface,
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
                    if (_hasFcData()) ...[
                      const SizedBox(height: 32),
                      _slideFromBottom(_aSeries, _buildFcChart()),
                    ],
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

  Widget _buildStatsGrid() {
    final double distKm = training.distanciaTotalM() / 1000.0;
    final String timeStr = _formatDuration(training.tiempoTotalSec().round());
    final String paceStr = training.ritmoMedioTexto();
    final double rpe = training.rpePromedio();

    return Column(
      children: [
        Row(
          children: [
            Expanded(child: _buildStatCard("Distancia", "${distKm.toStringAsFixed(2)} km", Icons.straighten, AppColors.rest)),
            const SizedBox(width: 16),
            Expanded(child: _buildStatCard("Tiempo", timeStr, Icons.timer, AppColors.rpeMid)),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(child: _buildStatCard("Ritmo Medio", paceStr, Icons.speed, AppColors.rpeLow)),
            const SizedBox(width: 16),
            Expanded(child: _buildStatCard("RPE Promedio", rpe.toStringAsFixed(1), Icons.bolt, AppColors.rpeMax)),
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
                color: AppColors.brand.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.notes_rounded,
                  color: isDark ? AppColors.brandLight : AppColors.brand,
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
                : Colors.black.withValues(alpha: 0.04),
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
              color: color.withValues(alpha: 0.1),
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
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
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
                color: AppColors.brand.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.list_alt_rounded, color: Theme.of(context).brightness == Brightness.dark ? AppColors.brandLight : AppColors.brand, size: 20),
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
                      : Colors.black.withValues(alpha: 0.03),
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
                    color: AppColors.brand.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    "${index + 1}",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).brightness == Brightness.dark ? AppColors.brandLight : AppColors.brand,
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
                            style: TextStyle(fontSize: 13, color: AppColors.rpeLow, fontWeight: FontWeight.w600),
                          ),
                          if (serie.rpe > 0)
                            RpeBadge(rpe: serie.rpe.toDouble()),
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
            color: AppColors.rpeMid.withValues(alpha: 0.15),
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
            color: isDark ? Colors.transparent : Colors.black.withValues(alpha: 0.04),
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
            Text(SessionCategoryX.fromValue(category).label,
                style: const TextStyle(fontSize: 13, color: AppColors.brandLight)),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              const SizedBox(width: 64,
                  child: Text('Serie', style: TextStyle(fontSize: 11, color: Color(0xFF8E8E93)))),
              const Expanded(child: Text('Planificado',
                  style: TextStyle(fontSize: 11, color: Color(0xFF8E8E93)),
                  textAlign: TextAlign.center)),
              const Expanded(child: Text('Ejecutado',
                  style: TextStyle(fontSize: 11, color: Color(0xFF8E8E93)),
                  textAlign: TextAlign.center)),
              const SizedBox(width: 52,
                  child: Text('Delta',
                      style: TextStyle(fontSize: 11, color: Color(0xFF8E8E93)),
                      textAlign: TextAlign.right)),
            ],
          ),
          const Divider(color: Color(0xFF3A3A3C), height: 20),
          ...blocks.map((b) {
            final planned = b['planned'] as Map?;
            final executed = b['executed'] as Map?;
            final order = (b['order'] as num?)?.toInt() ?? 0;
            final targetPaceSec = (planned?['targetPaceSec'] as num?)?.toDouble();
            final execPaceSec = (executed?['paceSec'] as num?)?.toDouble();
            final targetPaceStr = targetPaceSec != null ? _formatPace(targetPaceSec) : '—';
            final execPaceStr = execPaceSec != null ? _formatPace(execPaceSec) : '—';
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
                      SizedBox(width: 64,
                          child: Text('Serie ${order + 1}',
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: onSurface))),
                      Expanded(
                        child: Column(children: [
                          Text(targetPaceStr,
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600,
                                  color: targetPaceSec != null ? onSurface : const Color(0xFF8E8E93)),
                              textAlign: TextAlign.center),
                          if ((planned?['targetRpe'] as num?) != null) ...[
                            const SizedBox(height: 2),
                            RpeBadge(
                                rpe: (planned!['targetRpe'] as num).toDouble(),
                                size: RpeBadgeSize.text),
                          ],
                        ]),
                      ),
                      Expanded(
                        child: Column(children: [
                          if (executed == null)
                            const Text('No ejecutada',
                                style: TextStyle(fontSize: 12, color: Color(0xFF8E8E93)),
                                textAlign: TextAlign.center)
                          else ...[
                            Text(execPaceStr,
                                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600,
                                    color: delta != null ? _deltaColor(delta) : onSurface),
                                textAlign: TextAlign.center),
                            if ((executed['rpe'] as num?) != null) ...[
                              const SizedBox(height: 2),
                              RpeBadge(
                                  rpe: (executed['rpe'] as num).toDouble(),
                                  size: RpeBadgeSize.text),
                            ],
                          ],
                        ]),
                      ),
                      SizedBox(width: 52,
                          child: delta != null
                              ? Text(
                                  delta >= 0 ? '+${_formatPaceDelta(delta)}' : '-${_formatPaceDelta(delta.abs())}',
                                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                                      color: _deltaColor(delta)),
                                  textAlign: TextAlign.right)
                              : const SizedBox.shrink()),
                    ],
                  ),
                ),
                Divider(color: const Color(0xFF3A3A3C).withValues(alpha: 0.5), height: 1),
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
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
      child: Row(children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(width: 8),
        Expanded(child: Text(text,
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: color))),
      ]),
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

  bool _hasFcData() => training.series.any(
      (s) => s.fcReadings != null && s.fcReadings!.isNotEmpty);

  Widget _buildFcChart() {
    final allReadings = training.series
        .where((s) => s.fcReadings != null && s.fcReadings!.isNotEmpty)
        .expand((s) => s.fcReadings!.map((r) => r.bpm))
        .toList();
    if (allReadings.isEmpty) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final maxBpm = allReadings.reduce(max).toDouble();
    final minBpm = allReadings.reduce(min).toDouble();
    final avgBpm = (allReadings.reduce((a, b) => a + b) / allReadings.length).round();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text('FRECUENCIA CARDÍACA',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.8,
                  color: isDark ? const Color(0xFF8E8E93) : const Color(0xFF6C6C70))),
        ),
        const SizedBox(height: 8),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1C1C1E) : const Color(0xFFF2F2F7),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _FcStat('Máx', '${maxBpm.round()} ppm', AppColors.rpeMax),
                  _FcStat('Media', '$avgBpm ppm', AppColors.brand),
                  _FcStat('Mín', '${minBpm.round()} ppm', AppColors.rpeLow),
                ],
              ),
              FutureBuilder<int?>(
                future: _fcMaxFuture,
                builder: (context, snap) {
                  final fcMax = snap.data;
                  if (fcMax == null) return const SizedBox.shrink();
                  return _buildZoneDistribution(allReadings, fcMax);
                },
              ),
              const SizedBox(height: 12),
              if (allReadings.length > 1)
                SizedBox(
                  height: 80,
                  child: CustomPaint(
                    painter: _FcChartPainter(
                      readings: allReadings,
                      maxBpm: maxBpm,
                      minBpm: minBpm,
                      seriesBoundaries: _getSeriesBoundaries(training.series),
                    ),
                    size: Size.infinite,
                  ),
                )
              else
                Text('${allReadings.first} ppm',
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              const Text('Líneas verticales = cambio de serie',
                  style: TextStyle(fontSize: 11, color: Color(0xFF8E8E93))),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildZoneDistribution(List<int> readings, int fcMax) {
    final zones = ZonesService().zonesFor(fcMax);
    final zoneCounts = List<int>.filled(5, 0);
    for (final bpm in readings) {
      final z = ZonesService().zoneFor(bpm, fcMax);
      zoneCounts[(z ?? 1) - 1]++;
    }
    final total = readings.length;
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        children: List.generate(5, (i) {
          if (zoneCounts[i] == 0) return const SizedBox.shrink();
          final color = zones[i].color;
          final pct = zoneCounts[i] / total;
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                SizedBox(
                  width: 28,
                  child: Text('Z${i + 1}',
                      style: TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w600, color: color)),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Stack(
                    children: [
                      Container(
                          height: 8,
                          decoration: BoxDecoration(
                              color: AppColors.borderOf(context).withValues(alpha: 0.3),
                              borderRadius: BorderRadius.circular(4))),
                      FractionallySizedBox(
                        widthFactor: pct,
                        child: Container(
                            height: 8,
                            decoration: BoxDecoration(
                                color: color,
                                borderRadius: BorderRadius.circular(4))),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 36,
                  child: Text('${(pct * 100).round()}%',
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                          fontSize: 12, color: Color(0xFF8E8E93))),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }

  List<int> _getSeriesBoundaries(List<dynamic> series) {
    final boundaries = <int>[];
    int idx = 0;
    for (int i = 0; i < series.length - 1; i++) {
      idx += (series[i].fcReadings?.length ?? 0) as int;
      if (idx > 0) boundaries.add(idx);
    }
    return boundaries;
  }
}

class _FcStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _FcStat(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label,
            style: const TextStyle(fontSize: 11, color: Color(0xFF8E8E93))),
        const SizedBox(height: 2),
        Text(value,
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: color)),
      ],
    );
  }
}

class _FcChartPainter extends CustomPainter {
  final List<int> readings;
  final double maxBpm;
  final double minBpm;
  final List<int> seriesBoundaries;

  const _FcChartPainter({
    required this.readings,
    required this.maxBpm,
    required this.minBpm,
    required this.seriesBoundaries,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (readings.length < 2) return;

    final range = (maxBpm - minBpm) + 1;
    final points = List.generate(readings.length, (i) {
      final x = i / (readings.length - 1) * size.width;
      final y = (1 - (readings[i] - minBpm) / range) * size.height;
      return Offset(x, y);
    });

    final dividerPaint = Paint()
      ..color = const Color(0xFF3A3A3C)
      ..strokeWidth = 1.0;
    for (final b in seriesBoundaries) {
      final x = b / readings.length * size.width;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), dividerPaint);
    }

    final linePaint = Paint()
      ..color = AppColors.rpeMax
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final path = Path()..moveTo(points[0].dx, points[0].dy);
    for (int i = 1; i < points.length; i++) {
      final midX = (points[i - 1].dx + points[i].dx) / 2;
      path.cubicTo(
          midX, points[i - 1].dy, midX, points[i].dy, points[i].dx, points[i].dy);
    }
    canvas.drawPath(path, linePaint);
  }

  @override
  bool shouldRepaint(_FcChartPainter old) =>
      old.readings != readings || old.maxBpm != maxBpm || old.minBpm != minBpm;
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
              ? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.08)
              : Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.transparent
                  : Colors.black.withValues(alpha: _isPressed ? 0.03 : 0.06),
              blurRadius: _isPressed ? 4 : 12,
              offset: Offset(0, _isPressed ? 2 : 4),
            ),
          ],
          border: Border.all(color: AppColors.brand.withValues(alpha: 0.1)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.arrow_back_ios_new_rounded,
              size: 16,
              color: Theme.of(context).brightness == Brightness.dark
                  ? AppColors.brandLight
                  : AppColors.brand,
            ),
            const SizedBox(width: 6),
            Text(
              "Volver",
              style: TextStyle(
                color: Theme.of(context).brightness == Brightness.dark
                    ? AppColors.brandLight
                    : AppColors.brand,
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
