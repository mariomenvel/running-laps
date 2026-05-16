import 'dart:math' show max, min;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:running_laps/core/services/zones_service.dart';
import 'package:running_laps/core/theme/app_colors.dart';
import 'package:running_laps/core/theme/app_theme.dart';
import 'package:running_laps/core/widgets/main_shell.dart';
import 'package:running_laps/features/profile/data/zones_repository.dart';
import 'package:running_laps/features/training/data/entrenamiento.dart';
import 'package:running_laps/features/training/widgets/tag_chip.dart';
import 'package:running_laps/features/templates/data/template_models.dart';

import '../widgets/training_map_view.dart';
import 'widgets/temporal_chart.dart';
import 'package:running_laps/features/training/data/temporal_data_extractor.dart';

class TrainingDetailView extends StatefulWidget {
  final Entrenamiento training;

  const TrainingDetailView({super.key, required this.training});

  @override
  State<TrainingDetailView> createState() => _TrainingDetailViewState();
}

class _TrainingDetailViewState extends State<TrainingDetailView> {
  Entrenamiento get training => widget.training;

  late final Future<int?> _fcMaxFuture;
  final _editingNotes = ValueNotifier<bool>(false);
  late final TextEditingController _notasController;

  @override
  void initState() {
    super.initState();
    _fcMaxFuture = _loadFcMax();
    _notasController = TextEditingController(text: training.notas ?? '');
  }

  @override
  void dispose() {
    _editingNotes.dispose();
    _notasController.dispose();
    super.dispose();
  }

  Future<int?> _loadFcMax() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return null;
      final profile = await ZonesRepository().getUserProfile(uid);
      return profile?.fcMax;
    } catch (e) {
      debugPrint('[TrainingDetailView] error cargando fcMax: $e');
      return null;
    }
  }

  void _saveNotas() {
    _editingNotes.value = false;
  }

  @override
  Widget build(BuildContext context) {
    final sections = <Widget>[
      _buildHero(),
      _buildDivider(),
      _buildStatsRow(),
      _buildDivider(),
      if (training.gps) ...[
        _buildMap(),
        _buildDivider(),
      ],
      _buildSessionTemporalCharts(),
      _buildSeriesSection(),
      if (_hasFcData()) ...[
        _buildDivider(),
        _buildFcSection(),
      ],
      if (training.notas != null && training.notas!.isNotEmpty) ...[
        _buildDivider(),
        _buildNotasSection(),
      ],
      const SizedBox(height: 40),
    ];

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverList(
          delegate: SliverChildListDelegate(sections),
        ),
      ],
    );
  }

  // ── Divider ───────────────────────────────────────────────────────

  Widget _buildDivider() => Padding(
        padding: const EdgeInsets.symmetric(
            vertical: AppSpacing.l, horizontal: AppSpacing.l),
        child: Divider(
          color: AppColors.borderOf(context),
          thickness: 0.5,
          height: 0,
        ),
      );

  // ── Sección 1 — Hero ──────────────────────────────────────────────

  Widget _buildHero() {
    final dateStr = DateFormat('d MMM yyyy', 'es').format(training.fecha);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.l, AppSpacing.l, AppSpacing.l, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Back button
          GestureDetector(
            onTap: () => MainShell.shellKey.currentState?.navigateBack(),
            child: Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.l),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.chevron_left, color: AppColors.brand, size: 22),
                  Text(
                    'Historial',
                    style: TextStyle(
                        fontSize: 15,
                        color: AppColors.brand,
                        fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
          ),
          // Título + badge GPS/Manual
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  training.titulo,
                  style: AppTypography.h1.copyWith(
                    color: AppColors.textPrimary(context),
                    fontWeight: FontWeight.w600,
                    height: 1.1,
                    fontSize: 26,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.s),
              _buildGpsBadge(),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            dateStr,
            style: AppTypography.body.copyWith(
                color: AppColors.textSecondary(context)),
          ),
          if (training.tags != null && training.tags!.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.s),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: training.tags!
                  .map((t) => TagChip(tagName: t, small: true))
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildGpsBadge() {
    if (training.gps) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.brand.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          'GPS',
          style: TextStyle(
              fontSize: 12,
              color: AppColors.brand,
              fontWeight: FontWeight.w400),
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.surface2Of(context),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.borderOf(context)),
      ),
      child: Text(
        'Manual',
        style: TextStyle(
            fontSize: 12,
            color: AppColors.textSecondary(context),
            fontWeight: FontWeight.w400),
      ),
    );
  }

  // ── Sección 2 — Stats row ─────────────────────────────────────────

  Widget _buildStatsRow() {
    final distKm = training.distanciaTotalM() / 1000.0;
    final timeStr = _formatDuration(training.tiempoTotalSec().round());
    final paceStr = training.ritmoMedioTexto();
    final rpe = training.rpePromedio();
    final isSingle = training.series.length == 1;

    final stats = <_StatItem>[];

    if (isSingle) {
      stats.add(_StatItem(timeStr, 'Tiempo'));
    } else {
      stats.add(_StatItem('${training.series.length}', 'Series'));
    }
    stats.add(_StatItem('${distKm.toStringAsFixed(2)} km', 'Distancia'));
    stats.add(_StatItem(paceStr, 'Pace medio', color: AppColors.brand));
    stats.add(_StatItem(
      rpe.toStringAsFixed(1),
      'RPE medio',
      color: AppColors.effortColor(rpe),
    ));
    if (training.fcMediaSesion != null) {
      stats.add(_StatItem(
        '${training.fcMediaSesion!.round()}',
        'FC media',
        color: AppColors.rpeMax,
      ));
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.l),
      child: Wrap(
        alignment: WrapAlignment.spaceAround,
        spacing: AppSpacing.l,
        runSpacing: AppSpacing.s,
        children: stats
            .map((s) => _buildStatCell(s.value, s.label, s.color))
            .toList(),
      ),
    );
  }

  Widget _buildStatCell(String value, String label, [Color? color]) {
    return Column(
      children: [
        Text(
          value,
          style: AppTypography.h2.copyWith(
            fontSize: 20,
            fontWeight: FontWeight.w500,
            color: color ?? AppColors.textPrimary(context),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: AppTypography.small.copyWith(
              color: AppColors.textSecondary(context)),
        ),
      ],
    );
  }

  // ── Sección 3 — Mapa ──────────────────────────────────────────────

  Widget _buildMap() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.l),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'MAPA DE RUTA',
            style: AppTypography.small.copyWith(
              color: AppColors.textSecondary(context),
              letterSpacing: 1.5,
              fontWeight: FontWeight.w400,
            ),
          ),
          const SizedBox(height: AppSpacing.m),
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: SizedBox(
              height: 220,
              child: training.trackPoints.isEmpty
                  ? Container(
                      color: AppColors.surface2Of(context),
                      child: Center(
                        child: Text(
                          'Sin datos de mapa',
                          style: TextStyle(
                              color: AppColors.iconMutedOf(context)),
                        ),
                      ),
                    )
                  : Stack(
                      children: [
                        TrainingMapView(points: training.trackPoints),
                        Positioned(
                          bottom: 8,
                          right: 8,
                          child: GestureDetector(
                            onTap: () {
                              // TODO: expand map
                            },
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceOf(context)
                                    .withOpacity(0.85),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                Icons.fullscreen,
                                color: AppColors.textPrimary(context),
                                size: 20,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Sección 3b — Gráficas temporales de sesión ───────────────────

  Widget _buildSessionTemporalCharts() {
    final paceData = TemporalDataExtractor.sessionPace(training);
    final fcData = TemporalDataExtractor.sessionFc(training);

    debugPrint('[Charts] series.length=${training.series.length}');
    for (var i = 0; i < training.series.length; i++) {
      final s = training.series[i];
      debugPrint('[Charts] serie $i: gpsPoints=${s.gpsPoints?.length ?? 0}, fcReadings=${s.fcReadings?.length ?? 0}');
    }
    debugPrint('[Charts] paceData.points.length=${paceData.points.length}');
    debugPrint('[Charts] fcData.points.length=${fcData.points.length}');

    if (paceData.isEmpty && fcData.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'EVOLUCIÓN DURANTE LA SESIÓN',
            style: TextStyle(
              fontSize: 11,
              letterSpacing: 1.5,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary(context),
            ),
          ),
          const SizedBox(height: 12),

          // Gráfica de pace
          if (!paceData.isEmpty) ...[
            Row(children: [
              Icon(Icons.speed_rounded, size: 14, color: AppColors.brand),
              const SizedBox(width: 6),
              Text(
                'Ritmo',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary(context),
                ),
              ),
            ]),
            const SizedBox(height: 8),
            TemporalChart(
              points: paceData.points,
              markers: paceData.markers,
              lineColor: AppColors.brand,
              unitLabel: 'min/km',
              height: 180,
              invertYAxis: true,
              formatY: (v) {
                final m = (v / 60).floor();
                final s = (v % 60).round();
                return '$m:${s.toString().padLeft(2, '0')}';
              },
            ),
            const SizedBox(height: 20),
          ],

          // Gráfica de FC
          if (!fcData.isEmpty) ...[
            Row(children: [
              Icon(Icons.favorite_outline_rounded,
                  size: 14, color: Colors.red[400]),
              const SizedBox(width: 6),
              Text(
                'Frecuencia cardíaca',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary(context),
                ),
              ),
            ]),
            const SizedBox(height: 8),
            TemporalChart(
              points: fcData.points,
              markers: fcData.markers,
              lineColor: Colors.red[400]!,
              unitLabel: 'bpm',
              height: 180,
              formatY: (v) => v.toInt().toString(),
            ),
          ],
        ],
      ),
    );
  }

  // ── Sección 4 — Series ────────────────────────────────────────────

  Widget _buildSeriesSection() {
    // Build a flat list of planned targets (one per serie, same order as series list)
    final plannedTargets = _extractPlannedTargets();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.l),
          child: Text(
            'SERIES',
            style: AppTypography.small.copyWith(
              color: AppColors.textSecondary(context),
              letterSpacing: 1.5,
              fontWeight: FontWeight.w400,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.s),
        ...training.series.asMap().entries.map((entry) {
          final i = entry.key;
          final serie = entry.value;
          return _SerieExpansionTile(
            index: i,
            serie: serie,
            context: context,
            plannedTarget: i < plannedTargets.length ? plannedTargets[i] : null,
          );
        }),
      ],
    );
  }

  /// Returns one target map per serie index, extracted from plannedComparison blocks.
  List<Map<String, dynamic>?> _extractPlannedTargets() {
    final comp = training.plannedComparison;
    if (comp == null) return [];
    final allBlocks = (comp['blocks'] as List<dynamic>? ?? []);
    final mainBlocks = allBlocks.where((b) => (b['role'] as String?) == 'main').toList();

    final targets = <Map<String, dynamic>?>[];
    for (final block in mainBlocks) {
      final reps = (block['plannedReps'] as num?)?.toInt() ?? 1;
      final segments = (block['segments'] as List<dynamic>? ?? []);
      for (int rep = 0; rep < reps; rep++) {
        for (final seg in segments) {
          final target = (seg as Map<dynamic, dynamic>?)?['target'];
          targets.add(target != null ? Map<String, dynamic>.from(target as Map) : null);
        }
      }
    }
    return targets;
  }

  // ── Sección 5 — FC ────────────────────────────────────────────────

  Widget _buildFcSection() {
    final allReadings = training.series
        .where((s) => s.fcReadings != null && s.fcReadings!.isNotEmpty)
        .expand((s) => s.fcReadings!.map((r) => r.bpm))
        .toList();
    if (allReadings.isEmpty) return const SizedBox.shrink();

    final maxBpm = allReadings.reduce(max).toDouble();
    final minBpm = allReadings.reduce(min).toDouble();
    final avgBpm =
        (allReadings.reduce((a, b) => a + b) / allReadings.length).round();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.l),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'FRECUENCIA CARDÍACA',
            style: AppTypography.small.copyWith(
              color: AppColors.textSecondary(context),
              letterSpacing: 1.5,
              fontWeight: FontWeight.w400,
            ),
          ),
          const SizedBox(height: AppSpacing.l),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _FcBigStat('Mín', '${minBpm.round()}', AppColors.rpeLow),
              _FcBigStat('Media', '$avgBpm', AppColors.brand),
              _FcBigStat('Máx', '${maxBpm.round()}', AppColors.rpeMax),
            ],
          ),
          const SizedBox(height: AppSpacing.l),
          if (allReadings.length > 1) ...[
            SizedBox(
              height: 72,
              child: CustomPaint(
                painter: _FcChartPainter(
                  readings: allReadings,
                  maxBpm: maxBpm,
                  minBpm: minBpm,
                  seriesBoundaries: _getSeriesBoundaries(training.series),
                ),
                size: Size.infinite,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Líneas verticales = cambio de serie',
              style: TextStyle(
                  fontSize: 11, color: AppColors.iconMutedOf(context)),
            ),
          ],
          FutureBuilder<int?>(
            future: _fcMaxFuture,
            builder: (context, snap) {
              final fcMax = snap.data;
              if (fcMax == null) return const SizedBox.shrink();
              return _buildZoneDistribution(allReadings, fcMax);
            },
          ),
        ],
      ),
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
      padding: const EdgeInsets.only(top: AppSpacing.l),
      child: Column(
        children: List.generate(5, (i) {
          if (zoneCounts[i] == 0) return const SizedBox.shrink();
          final color = zones[i].color;
          final pct = zoneCounts[i] / total;
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Row(
              children: [
                SizedBox(
                  width: 24,
                  child: Text('Z${i + 1}',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
                          color: color)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Stack(
                    children: [
                      Container(
                        height: 6,
                        decoration: BoxDecoration(
                          color: AppColors.borderOf(context),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                      FractionallySizedBox(
                        widthFactor: pct,
                        child: Container(
                          height: 6,
                          decoration: BoxDecoration(
                            color: color,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  width: 36,
                  child: Text(
                    '${(pct * 100).round()}%',
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary(context),
                    ),
                  ),
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

  // ── Sección 6 — Notas ────────────────────────────────────────────

  Widget _buildNotasSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.l),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'NOTAS',
            style: AppTypography.small.copyWith(
              color: AppColors.textSecondary(context),
              letterSpacing: 1.5,
              fontWeight: FontWeight.w400,
            ),
          ),
          const SizedBox(height: AppSpacing.s),
          ValueListenableBuilder<bool>(
            valueListenable: _editingNotes,
            builder: (context, editing, _) {
              if (editing) {
                return TextField(
                  controller: _notasController,
                  style: AppTypography.body
                      .copyWith(color: AppColors.textPrimary(context)),
                  maxLines: null,
                  autofocus: true,
                  decoration: const InputDecoration(border: InputBorder.none),
                  onEditingComplete: _saveNotas,
                  onTapOutside: (_) => _saveNotas(),
                );
              }
              return GestureDetector(
                onTap: () => _editingNotes.value = true,
                child: Text(
                  training.notas!,
                  style: AppTypography.body.copyWith(
                    color: AppColors.textSecondary(context),
                    height: 1.6,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────

  String _formatDuration(int totalSeconds) {
    if (totalSeconds < 60) return '${totalSeconds}s';
    final int minutes = totalSeconds ~/ 60;
    final int seconds = totalSeconds % 60;
    if (minutes >= 60) {
      final int hours = minutes ~/ 60;
      final int mins = minutes % 60;
      return '${hours}h ${mins}m';
    }
    return '${minutes}m ${seconds.toString().padLeft(2, '0')}s';
  }

  String _formatPace(double secPerKm) {
    final m = secPerKm ~/ 60;
    final s = (secPerKm % 60).round();
    return '$m:${s.toString().padLeft(2, '0')} /km';
  }

  bool _hasFcData() =>
      training.series.any((s) => s.fcReadings != null && s.fcReadings!.isNotEmpty);
}

// ── Helper data class ─────────────────────────────────────────────

class _StatItem {
  final String value;
  final String label;
  final Color? color;
  const _StatItem(this.value, this.label, {this.color});
}

// ── Serie ExpansionTile con gráfica fl_chart ──────────────────────

class _SerieExpansionTile extends StatefulWidget {
  final int index;
  final dynamic serie;
  final BuildContext context;
  final Map<String, dynamic>? plannedTarget;

  const _SerieExpansionTile({
    required this.index,
    required this.serie,
    required this.context,
    this.plannedTarget,
  });

  @override
  State<_SerieExpansionTile> createState() => _SerieExpansionTileState();
}

class _SerieExpansionTileState extends State<_SerieExpansionTile> {
  bool _showFc = false;

  String _formatDuration(int s) {
    if (s < 60) return '${s}s';
    final m = s ~/ 60;
    final sec = s % 60;
    return '${m}m ${sec.toString().padLeft(2, '0')}s';
  }

  String _formatPace(double secPerKm) {
    final m = secPerKm ~/ 60;
    final s = (secPerKm % 60).round();
    return '$m:${s.toString().padLeft(2, '0')} /km';
  }

  Widget _buildPlannedTargetRow(BuildContext ctx, Map<String, dynamic> target, dynamic serie) {
    debugPrint('[PlannedTarget] rendering target=$target');
    final paceMin = (target['paceMinSecPerKm'] as num?)?.toDouble();
    final paceMax = (target['paceMaxSecPerKm'] as num?)?.toDouble();
    final targetRpe = (target['rpe'] as num?)?.toDouble();
    final targetZone = (target['zone'] as num?)?.toInt();

    final hasPace = paceMin != null || paceMax != null;
    if (!hasPace && targetRpe == null && targetZone == null) {
      return const SizedBox.shrink();
    }

    // Ejecutado
    final distM = (serie.distanciaM as num).toInt();
    final tiempoSec = (serie.tiempoSec as num).toDouble();
    final execPaceSec = tiempoSec > 0 && distM > 0
        ? tiempoSec * 1000.0 / distM
        : null;
    final execRpe = (serie.rpe as num).toDouble();

    final secondary = AppColors.textSecondary(ctx);
    final primary = AppColors.textPrimary(ctx);

    final labelStyle = AppTypography.small.copyWith(color: secondary, fontSize: 12);
    final valueStyle = AppTypography.small.copyWith(
        color: primary, fontSize: 13, fontWeight: FontWeight.w500);

    Widget arrowIcon() => Icon(Icons.arrow_forward,
        size: 14, color: AppColors.iconMutedOf(ctx));

    Widget row(String label, Widget planWidget, Widget execWidget) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          children: [
            SizedBox(width: 44, child: Text(label, style: labelStyle)),
            const SizedBox(width: 8),
            Expanded(child: planWidget),
            const SizedBox(width: 6),
            arrowIcon(),
            const SizedBox(width: 6),
            Expanded(child: execWidget),
          ],
        ),
      );
    }

    Color _paceColor(double? execSec) {
      if (execSec == null || paceMin == null) return primary;
      final ref = paceMax ?? paceMin;
      final delta = execSec - ref;
      if (delta.abs() <= 15) return AppColors.rpeLow;
      if (delta.abs() <= 30) return AppColors.rpeMid;
      return AppColors.rpeMax;
    }

    final rows = <Widget>[];

    if (hasPace) {
      final planStr = (paceMin != null && paceMax != null)
          ? '${_formatPace(paceMin)} – ${_formatPace(paceMax)}'
          : _formatPace((paceMin ?? paceMax)!);
      final execStr = execPaceSec != null ? _formatPace(execPaceSec) : '—';
      final execColor = _paceColor(execPaceSec);
      rows.add(row(
        'Pace',
        Text(planStr, style: valueStyle),
        Text(execStr, style: valueStyle.copyWith(color: execColor)),
      ));
    }

    if (targetRpe != null) {
      rows.add(row(
        'RPE',
        Text(targetRpe.toStringAsFixed(0),
            style: valueStyle.copyWith(color: AppColors.effortColor(targetRpe))),
        Text(execRpe > 0 ? execRpe.toStringAsFixed(0) : '—',
            style: valueStyle.copyWith(
                color: execRpe > 0 ? AppColors.effortColor(execRpe) : secondary)),
      ));
    }

    if (targetZone != null) {
      rows.add(row(
        'Zona',
        Text('Z$targetZone', style: valueStyle),
        Text('—', style: valueStyle.copyWith(color: secondary)),
      ));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(0, AppSpacing.s, 0, AppSpacing.s),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'OBJETIVO VS EJECUTADO',
                      style: AppTypography.small.copyWith(
                        color: secondary,
                        letterSpacing: 1.2,
                        fontWeight: FontWeight.w400,
                        fontSize: 10,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.s),
              ...rows,
            ],
          ),
        ),
        Divider(color: AppColors.borderOf(ctx), height: 1, thickness: 0.5),
        const SizedBox(height: AppSpacing.s),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final serie = widget.serie;
    final i = widget.index;
    debugPrint('[SerieExpansionTile] serieIndex=$i, plannedTarget=${widget.plannedTarget}');
    final rpeColor = AppColors.effortColor(serie.rpe.toDouble());
    final hasFc = serie.fcReadings != null &&
        (serie.fcReadings as List).isNotEmpty; // List<FcReading>

    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.l, vertical: 0),
        childrenPadding: EdgeInsets.zero,
        title: Row(
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: const BoxDecoration(
                color: AppColors.brand,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Text(
                '${i + 1}',
                style: const TextStyle(
                    fontSize: 11,
                    color: Colors.white,
                    fontWeight: FontWeight.w400),
              ),
            ),
            const SizedBox(width: AppSpacing.m),
            Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${serie.distanciaM} m',
                    style: AppTypography.body.copyWith(
                        color: AppColors.textPrimary(context),
                        fontWeight: FontWeight.w500),
                  ),
                  Text(
                    _formatDuration(serie.tiempoSec.round()),
                    style: AppTypography.body.copyWith(
                        color: AppColors.textPrimary(context)),
                  ),
                  Text(
                    serie.ritmoTexto(),
                    style: AppTypography.body.copyWith(
                        color: AppColors.brand,
                        fontWeight: FontWeight.w400),
                  ),
                  if (serie.rpe > 0)
                    Text(
                      'RPE ${serie.rpe}',
                      style: AppTypography.body
                          .copyWith(color: rpeColor, fontWeight: FontWeight.w400),
                    ),
                ],
              ),
            ),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.l, 0, AppSpacing.l, AppSpacing.m),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (widget.plannedTarget != null)
                  _buildPlannedTargetRow(context, widget.plannedTarget!, widget.serie),
                _buildSerieChart(context, serie, hasFc),
                if (serie.descansoSec > 0) ...[
                  const SizedBox(height: AppSpacing.m),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.pause_circle_outline,
                          color: AppColors.iconMutedOf(context), size: 14),
                      const SizedBox(width: 4),
                      Text(
                        'Descanso ${_formatDuration(serie.descansoSec.round())}',
                        style: AppTypography.small.copyWith(
                            color: AppColors.textSecondary(context)),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSerieChart(BuildContext context, dynamic serie, bool hasFc) {
    final fcBpms = hasFc
        ? (serie.fcReadings as List).map((r) => (r.bpm as int)).toList()
        : <int>[];

    // Build pace points from GPS points if available, otherwise skip pace chart
    final gpsPoints = serie.gpsPoints as List?;
    final pacePoints = <FlSpot>[];

    if (gpsPoints != null && gpsPoints.length >= 3) {
      for (int j = 0; j < gpsPoints.length; j++) {
        final pt = gpsPoints[j];
        final speed = (pt.speed as num?)?.toDouble() ?? 0.0;
        if (speed > 0.3) {
          final pace = 1000 / speed / 60; // min/km
          pacePoints.add(FlSpot(j.toDouble(), pace.clamp(2.0, 10.0)));
        }
      }
    }

    final fcPoints = <FlSpot>[];
    if (fcBpms.length >= 3) {
      for (int j = 0; j < fcBpms.length; j++) {
        fcPoints.add(FlSpot(j.toDouble(), fcBpms[j].toDouble()));
      }
    }

    final hasChart = pacePoints.length >= 3 || fcPoints.length >= 3;
    if (!hasChart) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.m),
        child: Text(
          'Sin datos de gráfica',
          style: AppTypography.small
              .copyWith(color: AppColors.textSecondary(context)),
        ),
      );
    }

    // Toggle FC/Pace when both available
    final showFcToggle = pacePoints.length >= 3 && fcPoints.length >= 3;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showFcToggle) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              _ChartToggle(
                labels: const ['Pace', 'FC'],
                selected: _showFc ? 1 : 0,
                onChanged: (v) => setState(() => _showFc = v == 1),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s),
        ],
        SizedBox(
          height: 120,
          child: LineChart(
            LineChartData(
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                getDrawingHorizontalLine: (_) => FlLine(
                  color: AppColors.borderOf(context),
                  strokeWidth: 0.5,
                ),
              ),
              borderData: FlBorderData(show: false),
              titlesData: FlTitlesData(
                leftTitles:
                    const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles:
                    const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                topTitles:
                    const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                bottomTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false)),
              ),
              lineTouchData: LineTouchData(
                touchTooltipData: LineTouchTooltipData(
                  getTooltipItems: (spots) => spots.map((s) {
                    final val = _showFc && fcPoints.isNotEmpty
                        ? '${s.y.round()} bpm'
                        : () {
                            final totalSec = (s.y * 60).round();
                            final m = totalSec ~/ 60;
                            final sec = totalSec % 60;
                            return '$m:${sec.toString().padLeft(2, '0')} /km';
                          }();
                    return LineTooltipItem(
                      val,
                      TextStyle(
                          color: AppColors.textPrimary(context), fontSize: 11),
                    );
                  }).toList(),
                ),
              ),
              lineBarsData: [
                if (!_showFc && pacePoints.length >= 3)
                  LineChartBarData(
                    spots: pacePoints,
                    isCurved: true,
                    color: AppColors.brand,
                    barWidth: 2,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      color: AppColors.brand.withOpacity(0.08),
                    ),
                  ),
                if (_showFc && fcPoints.length >= 3)
                  LineChartBarData(
                    spots: fcPoints,
                    isCurved: true,
                    color: AppColors.rpeMax,
                    barWidth: 2,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      color: AppColors.rpeMax.withOpacity(0.08),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ── Target chip ───────────────────────────────────────────────────

class _TargetChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final BuildContext ctx;

  const _TargetChip({
    required this.icon,
    required this.label,
    required this.color,
    required this.ctx,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Chart toggle widget ───────────────────────────────────────────

class _ChartToggle extends StatelessWidget {
  final List<String> labels;
  final int selected;
  final ValueChanged<int> onChanged;

  const _ChartToggle({
    required this.labels,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface2Of(context),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.borderOf(context)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: labels.asMap().entries.map((e) {
          final active = e.key == selected;
          return GestureDetector(
            onTap: () => onChanged(e.key),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: active ? AppColors.brand : Colors.transparent,
                borderRadius: BorderRadius.circular(7),
              ),
              child: Text(
                e.value,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w400,
                  color: active
                      ? Colors.white
                      : AppColors.textSecondary(context),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ── FC big stat ───────────────────────────────────────────────────

class _FcBigStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _FcBigStat(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
              fontSize: 28, fontWeight: FontWeight.w500, color: color),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
              fontSize: 11, color: AppColors.textSecondary(context)),
        ),
      ],
    );
  }
}

// ── FC chart painter ──────────────────────────────────────────────

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
      ..color = AppColors.border
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
