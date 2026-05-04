import 'package:firebase_auth/firebase_auth.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:running_laps/core/theme/app_colors.dart';
import 'package:running_laps/core/theme/app_theme.dart';
import 'package:running_laps/features/analytics/viewmodels/analytics_hub_controller.dart';
import 'package:running_laps/features/analytics/viewmodels/analytics_view_model.dart';
import 'package:running_laps/features/training/data/entrenamiento.dart';

class AnalyticsHubScreen extends StatefulWidget {
  const AnalyticsHubScreen({super.key, this.preFilteredData});

  final List<Entrenamiento>? preFilteredData;

  @override
  State<AnalyticsHubScreen> createState() => _AnalyticsHubScreenState();
}

class _AnalyticsHubScreenState extends State<AnalyticsHubScreen>
    with SingleTickerProviderStateMixin {
  late final AnalyticsHubController _ctrl;
  late final AnalyticsViewModel _vm;
  late final TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    _ctrl = AnalyticsHubController(userId: uid);
    _vm   = AnalyticsViewModel();
    _tabCtrl = TabController(length: 3, vsync: this);

    _ctrl.isLoading.addListener(_onStateChanged);
    _ctrl.filteredData.addListener(_onFilteredChanged);
    _ctrl.initialize(initialData: widget.preFilteredData);
  }

  void _onStateChanged() { if (mounted) setState(() {}); }

  void _onFilteredChanged() {
    _vm.compute(_ctrl.filteredData.value, _ctrl.allData, _ctrl.selectedRange.value);
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _ctrl.isLoading.removeListener(_onStateChanged);
    _ctrl.filteredData.removeListener(_onFilteredChanged);
    _vm.dispose();
    _ctrl.dispose();
    _tabCtrl.dispose();
    super.dispose();
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Header
        SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.xl, AppSpacing.xl, AppSpacing.xl, AppSpacing.m),
            child: Row(
              children: [
                Text(
                  'Analytics',
                  style: AppTypography.h2
                      .copyWith(color: AppColors.textPrimary(context)),
                ),
                const Spacer(),
                _RangeChip(ctrl: _ctrl, onChanged: _onFilteredChanged),
              ],
            ),
          ),
        ),

        // Tab bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.l),
          child: TabBar(
            controller: _tabCtrl,
            labelColor: AppColors.brand,
            unselectedLabelColor: AppColors.iconMutedOf(context),
            indicatorColor: AppColors.brand,
            indicatorSize: TabBarIndicatorSize.label,
            dividerColor: Colors.transparent,
            labelStyle: AppTypography.small.copyWith(fontWeight: FontWeight.w600),
            unselectedLabelStyle: AppTypography.small,
            tabs: const [
              Tab(text: 'Rendimiento'),
              Tab(text: 'Entrenamiento'),
              Tab(text: 'Forma'),
            ],
          ),
        ),
        Divider(height: 1, color: AppColors.borderOf(context)),

        // Content
        Expanded(child: _buildContent()),
      ],
    );
  }

  Widget _buildContent() {
    if (_ctrl.isLoading.value) {
      return const Center(child: CircularProgressIndicator(color: AppColors.brand));
    }
    final data = _ctrl.filteredData.value;
    if (data.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.bar_chart_rounded,
                size: 56, color: AppColors.iconMutedOf(context)),
            const SizedBox(height: AppSpacing.m),
            Text('Sin datos',
                style:
                    AppTypography.h3.copyWith(color: AppColors.textPrimary(context))),
            const SizedBox(height: AppSpacing.s),
            Text('Completa algunos entrenamientos\npara ver tus estadísticas',
                textAlign: TextAlign.center,
                style: AppTypography.small
                    .copyWith(color: AppColors.iconMutedOf(context))),
          ],
        ),
      );
    }
    return TabBarView(
      controller: _tabCtrl,
      children: [
        _buildRendimientoTab(),
        _buildEntrenamientoTab(),
        _buildFormaTab(),
      ],
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // TAB 1: RENDIMIENTO
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildRendimientoTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildPersonalRecords(),
          const SizedBox(height: AppSpacing.xxl),
          _buildPaceProgression(),
          const SizedBox(height: AppSpacing.xxl),
          _buildAvgPaceComparison(),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _buildPersonalRecords() {
    final records = _vm.personalRecords.value;
    const distLabels = {400: '400m', 1000: '1 km', 5000: '5 km', 10000: '10 km'};

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader('RECORDS PERSONALES'),
        const SizedBox(height: AppSpacing.m),
        _Card(
          child: Column(
            children: distLabels.entries.map((entry) {
              final rec = records[entry.key];
              return _RecordRow(
                label: entry.value,
                record: rec,
                isLast: entry.key == 10000,
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildPaceProgression() {
    final prog = _vm.paceProgressionByDist.value;
    if (prog.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader('RITMO EN SERIES (8 semanas)'),
          const SizedBox(height: AppSpacing.m),
          _Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Center(
                child: Text(
                  'Necesitas ≥3 series de la misma distancia',
                  style: AppTypography.small
                      .copyWith(color: AppColors.iconMutedOf(context)),
                ),
              ),
            ),
          ),
        ],
      );
    }

    const distColors = {
      400: AppColors.brand,
      1000: AppColors.effort,
      5000: Color(0xFF5AB4D8),
      10000: AppColors.rpeLow,
    };
    const distLabels = {400: '400m', 1000: '1km', 5000: '5km', 10000: '10km'};

    final allSeries = <LineChartBarData>[];
    for (final entry in prog.entries) {
      final color = distColors[entry.key] ?? AppColors.brand;
      final spots = entry.value
          .asMap()
          .entries
          .map((e) => FlSpot(e.key.toDouble(), e.value.paceSecKm))
          .toList();
      allSeries.add(LineChartBarData(
        spots: spots,
        color: color,
        barWidth: 2,
        isCurved: true,
        curveSmoothness: 0.3,
        dotData: const FlDotData(show: false),
      ));
    }

    final allPaces = prog.values.expand((l) => l.map((p) => p.paceSecKm)).toList();
    final minY = (allPaces.reduce((a, b) => a < b ? a : b) - 30).clamp(0, double.infinity).toDouble();
    final maxY = allPaces.reduce((a, b) => a > b ? a : b) + 30;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader('RITMO EN SERIES (8 semanas)'),
        const SizedBox(height: AppSpacing.m),
        _Card(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.s, AppSpacing.l, AppSpacing.l, AppSpacing.m),
            child: Column(
              children: [
                SizedBox(
                  height: 180,
                  child: LineChart(LineChartData(
                    lineBarsData: allSeries,
                    minY: minY,
                    maxY: maxY,
                    titlesData: FlTitlesData(
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 44,
                          getTitlesWidget: (v, _) => Text(
                            _fmtPace(v.toInt()),
                            style: TextStyle(
                                fontSize: 10,
                                color: AppColors.iconMutedOf(context)),
                          ),
                        ),
                      ),
                      bottomTitles: AxisTitles(
                          sideTitles: SideTitles(showTitles: false)),
                      topTitles: AxisTitles(
                          sideTitles: SideTitles(showTitles: false)),
                      rightTitles: AxisTitles(
                          sideTitles: SideTitles(showTitles: false)),
                    ),
                    gridData: FlGridData(
                      drawVerticalLine: false,
                      horizontalInterval: 30,
                      getDrawingHorizontalLine: (_) => FlLine(
                          color: AppColors.borderOf(context), strokeWidth: 0.5),
                    ),
                    borderData: FlBorderData(show: false),
                    lineTouchData: LineTouchData(
                      touchTooltipData: LineTouchTooltipData(
                        getTooltipColor: (_) => AppColors.surfaceOf(context),
                        getTooltipItems: (spots) => spots
                            .map((s) => LineTooltipItem(
                                  _fmtPace(s.y.toInt()),
                                  TextStyle(
                                      color: AppColors.textPrimary(context),
                                      fontSize: 11),
                                ))
                            .toList(),
                      ),
                    ),
                  )),
                ),
                const SizedBox(height: AppSpacing.m),
                Wrap(
                  spacing: AppSpacing.l,
                  runSpacing: AppSpacing.xs,
                  children: prog.keys
                      .map((d) => _LegendLine(
                            label: distLabels[d] ?? '${d}m',
                            color: distColors[d] ?? AppColors.brand,
                          ))
                      .toList(),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAvgPaceComparison() {
    final cur  = _vm.avgPaceCurrent.value;
    final prev = _vm.avgPacePrevious.value;
    final delta = prev > 0 && cur > 0 ? prev - cur : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader('RITMO MEDIO (período seleccionado)'),
        const SizedBox(height: AppSpacing.m),
        _Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.l),
            child: Row(
              children: [
                Expanded(
                  child: _StatBlock(
                    label: 'Actual',
                    value: cur > 0 ? '${_fmtPace(cur.toInt())} /km' : '—',
                    valueColor: AppColors.textPrimary(context),
                  ),
                ),
                Expanded(
                  child: _StatBlock(
                    label: 'Período anterior',
                    value: prev > 0 ? '${_fmtPace(prev.toInt())} /km' : '—',
                    valueColor: AppColors.textPrimary(context),
                  ),
                ),
                if (delta != null)
                  Expanded(
                    child: _StatBlock(
                      label: 'Cambio',
                      value: delta >= 0
                          ? '-${delta.toStringAsFixed(0)}s/km ↑'
                          : '+${(-delta).toStringAsFixed(0)}s/km ↓',
                      valueColor:
                          delta >= 0 ? AppColors.rpeLow : AppColors.rpeMax,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // TAB 2: ENTRENAMIENTO
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildEntrenamientoTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildWeeklyVolume(),
          const SizedBox(height: AppSpacing.xxl),
          _buildIntensityDistribution(),
          const SizedBox(height: AppSpacing.xxl),
          _buildConsistency(),
          if (_vm.sessionsByType.value.length > 1 &&
              _ctrl.filteredData.value.length > 4) ...[
            const SizedBox(height: AppSpacing.xxl),
            _buildSessionsByType(),
          ],
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _buildWeeklyVolume() {
    final vols = _vm.weeklyVolumes.value;
    if (vols.isEmpty) return const SizedBox();

    final maxKm = vols.map((v) => v.km).reduce((a, b) => a > b ? a : b);
    final totalKm = vols.fold(0.0, (s, v) => s + v.km);
    final avgKm   = totalKm / vols.length;
    final lastKm  = vols.last.km;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader('VOLUMEN SEMANAL (8 semanas)'),
        const SizedBox(height: AppSpacing.m),
        _Card(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.s, AppSpacing.l, AppSpacing.l, AppSpacing.m),
            child: Column(
              children: [
                SizedBox(
                  height: 160,
                  child: BarChart(BarChartData(
                    maxY: maxKm <= 0 ? 10 : maxKm * 1.25,
                    barGroups: vols.asMap().entries.map((e) {
                      final isLast = e.key == vols.length - 1;
                      return BarChartGroupData(x: e.key, barRods: [
                        BarChartRodData(
                          toY: e.value.km,
                          color: isLast
                              ? AppColors.brand
                              : AppColors.brand.withOpacity(0.5),
                          width: 18,
                          borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(4)),
                        ),
                      ]);
                    }).toList(),
                    titlesData: FlTitlesData(
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          getTitlesWidget: (x, _) {
                            final i = x.toInt();
                            if (i < 0 || i >= vols.length) {
                              return const SizedBox();
                            }
                            final w = vols[i].weekStart;
                            return Text('${w.day}/${w.month}',
                                style: TextStyle(
                                    fontSize: 9,
                                    color: AppColors.iconMutedOf(context)));
                          },
                        ),
                      ),
                      leftTitles: AxisTitles(
                          sideTitles: SideTitles(showTitles: false)),
                      topTitles: AxisTitles(
                          sideTitles: SideTitles(showTitles: false)),
                      rightTitles: AxisTitles(
                          sideTitles: SideTitles(showTitles: false)),
                    ),
                    gridData: const FlGridData(show: false),
                    borderData: FlBorderData(show: false),
                    barTouchData: BarTouchData(
                      touchTooltipData: BarTouchTooltipData(
                        getTooltipColor: (_) => AppColors.surfaceOf(context),
                        getTooltipItem: (g, gi, rod, ri) => BarTooltipItem(
                          '${rod.toY.toStringAsFixed(1)} km',
                          TextStyle(
                              color: AppColors.textPrimary(context),
                              fontSize: 11),
                        ),
                      ),
                    ),
                  )),
                ),
                const SizedBox(height: AppSpacing.m),
                Row(
                  children: [
                    Expanded(
                        child: _StatBlock(
                            label: 'Esta semana',
                            value: '${lastKm.toStringAsFixed(1)} km')),
                    Expanded(
                        child: _StatBlock(
                            label: 'Media',
                            value: '${avgKm.toStringAsFixed(1)} km')),
                    Expanded(
                        child: _StatBlock(
                            label: 'Total',
                            value: '${totalKm.toStringAsFixed(0)} km')),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildIntensityDistribution() {
    final easy = _vm.intensityEasyPct.value;
    final hard = _vm.intensityHardPct.value;

    String feedback;
    Color feedbackColor;
    if (easy == 0 && hard == 0) {
      feedback = 'Sin datos suficientes';
      feedbackColor = AppColors.iconMutedOf(context);
    } else if (easy >= 75) {
      feedback = '✓ Bien equilibrado (regla 80/20)';
      feedbackColor = AppColors.rpeLow;
    } else if (easy < 50) {
      feedback = '⚠ Demasiado intenso. Añade más rodaje Z1-Z2';
      feedbackColor = AppColors.rpeMax;
    } else {
      feedback = '↑ Algo intenso. Intenta más volumen fácil';
      feedbackColor = AppColors.effort;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader('DISTRIBUCIÓN DE INTENSIDAD'),
        const SizedBox(height: AppSpacing.m),
        _Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.l),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _IntensityBar(label: 'Fácil (RPE 1-5)', pct: easy, color: AppColors.rpeLow),
                const SizedBox(height: AppSpacing.s),
                _IntensityBar(label: 'Duro (RPE 6-10)', pct: hard, color: AppColors.rpeMax),
                const SizedBox(height: AppSpacing.m),
                Row(
                  children: [
                    Text('Objetivo: 80% fácil / 20% duro',
                        style: AppTypography.small
                            .copyWith(color: AppColors.iconMutedOf(context))),
                  ],
                ),
                const SizedBox(height: AppSpacing.s),
                Text(feedback,
                    style: AppTypography.small
                        .copyWith(color: feedbackColor, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildConsistency() {
    final weeks   = _vm.consistencyWeeks.value;
    final total   = _vm.consistencyTotal.value;
    final streak  = _vm.currentStreak.value;
    final avg     = _vm.avgSessionsPerWeek.value;
    final dots    = _vm.activityDots.value;
    final pct     = total > 0 ? weeks / total * 100 : 0;

    String streakFeedback;
    if (streak >= 8) {
      streakFeedback = 'Excelente consistencia. ¡Sigue así!';
    } else if (streak >= 4) {
      streakFeedback = 'Buena racha. Mantén el ritmo.';
    } else if (streak >= 2) {
      streakFeedback = 'Vas bien. Intenta no saltarte semanas.';
    } else {
      streakFeedback = 'Intenta mantener al menos 1 sesión/semana.';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader('CONSISTENCIA'),
        const SizedBox(height: AppSpacing.m),
        _Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.l),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // KPIs
                Row(
                  children: [
                    Expanded(
                        child: _StatBlock(
                            label: 'Semanas activas',
                            value: '$weeks/$total (${pct.toStringAsFixed(0)}%)')),
                    Expanded(
                        child: _StatBlock(
                            label: 'Racha actual',
                            value: '$streak sem.')),
                    Expanded(
                        child: _StatBlock(
                            label: 'Media',
                            value: '${avg.toStringAsFixed(1)} ses/sem')),
                  ],
                ),
                const SizedBox(height: AppSpacing.l),
                // Dots (56 días = 8 filas de 7)
                if (dots.length == 56) ...[
                  for (int row = 0; row < 8; row++)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        children: [
                          for (int col = 0; col < 7; col++)
                            Container(
                              width: 10,
                              height: 10,
                              margin: const EdgeInsets.only(right: 3),
                              decoration: BoxDecoration(
                                color: dots[row * 7 + col]
                                    ? AppColors.rpeLow
                                    : AppColors.borderOf(context),
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                        ],
                      ),
                    ),
                  const SizedBox(height: AppSpacing.m),
                ],
                Text(streakFeedback,
                    style: AppTypography.small.copyWith(
                        color: streak >= 4 ? AppColors.rpeLow : AppColors.iconMutedOf(context),
                        fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSessionsByType() {
    final types = _vm.sessionsByType.value;
    final total = types.values.fold(0, (s, v) => s + v);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader('POR TIPO'),
        const SizedBox(height: AppSpacing.m),
        _Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.l),
            child: Column(
              children: types.entries.map((e) {
                final pct = total > 0 ? e.value / total : 0.0;
                return Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.m),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(e.key,
                                style: AppTypography.small.copyWith(
                                    color: AppColors.textPrimary(context))),
                          ),
                          Text('${e.value} (${(pct * 100).toStringAsFixed(0)}%)',
                              style: AppTypography.small
                                  .copyWith(color: AppColors.iconMutedOf(context))),
                        ],
                      ),
                      const SizedBox(height: 4),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(2),
                        child: LinearProgressIndicator(
                          value: pct.toDouble(),
                          backgroundColor: AppColors.borderOf(context),
                          color: AppColors.brand,
                          minHeight: 4,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // TAB 3: FORMA
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildFormaTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCtlAtlTsb(),
          const SizedBox(height: AppSpacing.xxl),
          _buildAcwr(),
          const SizedBox(height: AppSpacing.xxl),
          _buildRpeTrend(),
          const SizedBox(height: AppSpacing.xxl),
          _buildWeeklyLoads(),
          if (_vm.aerobicEfficiency.value != null) ...[
            const SizedBox(height: AppSpacing.xxl),
            _buildAerobicEfficiency(),
          ],
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _buildCtlAtlTsb() {
    final ctl    = _vm.ctlValues.value;
    final atl    = _vm.atlValues.value;
    final tsb    = _vm.tsbValues.value;
    final curCTL = _vm.currentCTL.value;
    final curATL = _vm.currentATL.value;
    final curTSB = _vm.currentTSB.value;

    if (ctl.isEmpty) return const SizedBox();

    final allVals = [...ctl, ...atl, ...tsb];
    final minY    = allVals.reduce((a, b) => a < b ? a : b) - 5;
    final maxY    = allVals.reduce((a, b) => a > b ? a : b) + 5;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _SectionHeader('ESTADO DE FORMA'),
            const SizedBox(width: AppSpacing.xs),
            GestureDetector(
              onTap: _showTSBHelp,
              child: Icon(Icons.help_outline,
                  size: 14, color: AppColors.iconMutedOf(context)),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.m),
        _Card(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.s, AppSpacing.l, AppSpacing.l, AppSpacing.m),
            child: Column(
              children: [
                SizedBox(
                  height: 180,
                  child: LineChart(LineChartData(
                    lineBarsData: [
                      // CTL
                      LineChartBarData(
                        spots: ctl.asMap().entries
                            .map((e) => FlSpot(e.key.toDouble(), e.value))
                            .toList(),
                        color: AppColors.brand,
                        barWidth: 2.5,
                        isCurved: true,
                        curveSmoothness: 0.3,
                        dotData: const FlDotData(show: false),
                      ),
                      // ATL
                      LineChartBarData(
                        spots: atl.asMap().entries
                            .map((e) => FlSpot(e.key.toDouble(), e.value))
                            .toList(),
                        color: AppColors.effort,
                        barWidth: 2,
                        isCurved: true,
                        curveSmoothness: 0.3,
                        dotData: const FlDotData(show: false),
                      ),
                      // TSB
                      LineChartBarData(
                        spots: tsb.asMap().entries
                            .map((e) => FlSpot(e.key.toDouble(), e.value))
                            .toList(),
                        color: curTSB >= 0 ? AppColors.rpeLow : AppColors.rpeMax,
                        barWidth: 1.5,
                        isCurved: true,
                        curveSmoothness: 0.3,
                        dotData: const FlDotData(show: false),
                        dashArray: [5, 3],
                      ),
                    ],
                    minY: minY,
                    maxY: maxY,
                    titlesData: FlTitlesData(
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          interval: 2,
                          getTitlesWidget: (x, _) => Text(
                            'S${x.toInt() + 1}',
                            style: TextStyle(
                                fontSize: 9,
                                color: AppColors.iconMutedOf(context)),
                          ),
                        ),
                      ),
                      leftTitles: AxisTitles(
                          sideTitles: SideTitles(showTitles: false)),
                      topTitles: AxisTitles(
                          sideTitles: SideTitles(showTitles: false)),
                      rightTitles: AxisTitles(
                          sideTitles: SideTitles(showTitles: false)),
                    ),
                    gridData: FlGridData(
                      drawVerticalLine: false,
                      horizontalInterval: 10,
                      getDrawingHorizontalLine: (_) => FlLine(
                          color: AppColors.borderOf(context), strokeWidth: 0.5),
                    ),
                    borderData: FlBorderData(show: false),
                    lineTouchData: LineTouchData(
                      touchTooltipData: LineTouchTooltipData(
                        getTooltipColor: (_) => AppColors.surfaceOf(context),
                        getTooltipItems: (spots) => spots
                            .map((s) => LineTooltipItem(
                                  s.y.toStringAsFixed(0),
                                  TextStyle(
                                      color: AppColors.textPrimary(context),
                                      fontSize: 11),
                                ))
                            .toList(),
                      ),
                    ),
                  )),
                ),
                const SizedBox(height: AppSpacing.m),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _LegendLine(label: 'CTL (forma)', color: AppColors.brand),
                    const SizedBox(width: AppSpacing.l),
                    _LegendLine(label: 'ATL (fatiga)', color: AppColors.effort),
                    const SizedBox(width: AppSpacing.l),
                    _LegendLine(
                        label: 'TSB (balance)',
                        color: curTSB >= 0 ? AppColors.rpeLow : AppColors.rpeMax),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.m),
        // Estado actual
        _Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.l),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _TSBStat(
                        label: 'CTL',
                        value: curCTL.toStringAsFixed(0),
                        subtitle: 'Forma',
                        color: AppColors.brand),
                    _TSBStat(
                        label: 'ATL',
                        value: curATL.toStringAsFixed(0),
                        subtitle: 'Fatiga',
                        color: AppColors.effort),
                    _TSBStat(
                        label: 'TSB',
                        value: (curTSB >= 0 ? '+' : '') +
                            curTSB.toStringAsFixed(0),
                        subtitle: _tsbZoneLabel(curTSB),
                        color: _tsbZoneColor(curTSB)),
                  ],
                ),
                const SizedBox(height: AppSpacing.m),
                Divider(color: AppColors.borderOf(context)),
                const SizedBox(height: AppSpacing.m),
                Row(
                  children: [
                    Icon(_tsbZoneIcon(curTSB),
                        color: _tsbZoneColor(curTSB), size: 20),
                    const SizedBox(width: AppSpacing.s),
                    Expanded(
                      child: Text(
                        _vm.tsbInsight.value,
                        style: AppTypography.small
                            .copyWith(color: AppColors.textPrimary(context)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAcwr() {
    final ratio  = _vm.acwrRatio.value;
    final acute  = _vm.acuteLoad.value;
    final chronic = _vm.chronicLoad.value;

    String status;
    Color statusColor;
    if (ratio == 0) {
      status = 'Sin datos suficientes';
      statusColor = AppColors.iconMutedOf(context);
    } else if (ratio < 0.8) {
      status = 'Carga baja — riesgo de desentrenamiento';
      statusColor = AppColors.iconMutedOf(context);
    } else if (ratio <= 1.3) {
      status = '✓ Zona óptima — puedes entrenar fuerte';
      statusColor = AppColors.rpeLow;
    } else if (ratio <= 1.5) {
      status = '⚠ Carga alta — monitorea la recuperación';
      statusColor = AppColors.effort;
    } else {
      status = '⚠ Peligro de lesión — descansa';
      statusColor = AppColors.rpeMax;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader('CARGA DE ENTRENAMIENTO (ACWR)'),
        const SizedBox(height: AppSpacing.m),
        _Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.l),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                        child: _StatBlock(
                            label: 'Carga aguda (7d)',
                            value: acute.toStringAsFixed(0))),
                    Expanded(
                        child: _StatBlock(
                            label: 'Carga crónica (28d)',
                            value: chronic.toStringAsFixed(0))),
                    Expanded(
                        child: _StatBlock(
                            label: 'Ratio ACWR',
                            value: ratio > 0 ? ratio.toStringAsFixed(2) : '—',
                            valueColor: ratio > 1.3
                                ? AppColors.rpeMax
                                : (ratio >= 0.8
                                    ? AppColors.rpeLow
                                    : AppColors.iconMutedOf(context)))),
                  ],
                ),
                const SizedBox(height: AppSpacing.m),
                // Barra visual de ratio
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: Stack(
                    children: [
                      Container(
                        height: 8,
                        color: AppColors.borderOf(context),
                      ),
                      FractionallySizedBox(
                        widthFactor: (ratio / 2.0).clamp(0.0, 1.0),
                        child: Container(
                          height: 8,
                          color: ratio <= 1.3 ? AppColors.rpeLow : AppColors.rpeMax,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('0.8', style: _labelStyle()),
                    Text('1.0 Óptimo', style: _labelStyle()),
                    Text('1.3', style: _labelStyle()),
                    Text('1.5+ Peligro', style: _labelStyle()),
                  ],
                ),
                const SizedBox(height: AppSpacing.m),
                Text(status,
                    style: AppTypography.small
                        .copyWith(color: statusColor, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRpeTrend() {
    final rpes = _vm.weeklyRpeAvg.value;
    if (rpes.isEmpty || rpes.every((r) => r == 0)) return const SizedBox();

    final rising = rpes.length >= 3 &&
        rpes.last > rpes.first * 1.15 &&
        rpes.last > 6.5;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader('RPE TENDENCIA (4 semanas)'),
        const SizedBox(height: AppSpacing.m),
        _Card(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.s, AppSpacing.l, AppSpacing.l, AppSpacing.m),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  height: 120,
                  child: LineChart(LineChartData(
                    lineBarsData: [
                      LineChartBarData(
                        spots: rpes.asMap().entries
                            .map((e) => FlSpot(e.key.toDouble(), e.value))
                            .toList(),
                        color: rising ? AppColors.effort : AppColors.brand,
                        barWidth: 2,
                        isCurved: true,
                        dotData: FlDotData(
                          show: true,
                          getDotPainter: (s, x, bar, i) => FlDotCirclePainter(
                            radius: 3,
                            color: bar.color ?? AppColors.brand,
                            strokeColor: Colors.transparent,
                          ),
                        ),
                      ),
                    ],
                    minY: 0,
                    maxY: 10,
                    titlesData: FlTitlesData(
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          getTitlesWidget: (x, _) {
                            final labels = ['S1', 'S2', 'S3', 'S4'];
                            final i = x.toInt();
                            if (i < 0 || i >= labels.length) {
                              return const SizedBox();
                            }
                            return Text(labels[i],
                                style: TextStyle(
                                    fontSize: 10,
                                    color: AppColors.iconMutedOf(context)));
                          },
                        ),
                      ),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 24,
                          interval: 5,
                          getTitlesWidget: (v, _) => Text(
                            v.toInt().toString(),
                            style: TextStyle(
                                fontSize: 10,
                                color: AppColors.iconMutedOf(context)),
                          ),
                        ),
                      ),
                      topTitles: AxisTitles(
                          sideTitles: SideTitles(showTitles: false)),
                      rightTitles: AxisTitles(
                          sideTitles: SideTitles(showTitles: false)),
                    ),
                    gridData: FlGridData(
                      drawVerticalLine: false,
                      horizontalInterval: 5,
                      getDrawingHorizontalLine: (_) => FlLine(
                          color: AppColors.borderOf(context), strokeWidth: 0.5),
                    ),
                    borderData: FlBorderData(show: false),
                  )),
                ),
                if (rising) ...[
                  const SizedBox(height: AppSpacing.m),
                  Text(
                    '⚠ El esfuerzo percibido sube. Si no es intencional, considera descansar.',
                    style: AppTypography.small.copyWith(
                        color: AppColors.effort, fontWeight: FontWeight.w500),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildWeeklyLoads() {
    final loads = _vm.weeklyLoads.value;
    if (loads.isEmpty) return const SizedBox();

    final maxLoad = loads.reduce((a, b) => a > b ? a : b);
    final hasHighStreak = () {
      int streak = 0;
      for (int i = loads.length - 1; i >= 0; i--) {
        if (loads[i] >= 300) {
          streak++;
        } else {
          break;
        }
      }
      return streak >= 3;
    }();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader('CARGA POR SEMANA (8 semanas)'),
        const SizedBox(height: AppSpacing.m),
        _Card(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.s, AppSpacing.l, AppSpacing.l, AppSpacing.m),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  height: 140,
                  child: BarChart(BarChartData(
                    maxY: maxLoad <= 0 ? 100 : maxLoad * 1.2,
                    barGroups: loads.asMap().entries.map((e) {
                      return BarChartGroupData(x: e.key, barRods: [
                        BarChartRodData(
                          toY: e.value,
                          color: _loadColor(e.value),
                          width: 18,
                          borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(4)),
                        ),
                      ]);
                    }).toList(),
                    titlesData: FlTitlesData(
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          getTitlesWidget: (x, _) {
                            final i = x.toInt();
                            return Text('S${i + 1}',
                                style: TextStyle(
                                    fontSize: 9,
                                    color: AppColors.iconMutedOf(context)));
                          },
                        ),
                      ),
                      leftTitles: AxisTitles(
                          sideTitles: SideTitles(showTitles: false)),
                      topTitles: AxisTitles(
                          sideTitles: SideTitles(showTitles: false)),
                      rightTitles: AxisTitles(
                          sideTitles: SideTitles(showTitles: false)),
                    ),
                    gridData: const FlGridData(show: false),
                    borderData: FlBorderData(show: false),
                  )),
                ),
                if (hasHighStreak) ...[
                  const SizedBox(height: AppSpacing.m),
                  Text(
                    '⚠ 3+ semanas seguidas de carga alta. Programa una semana de descarga.',
                    style: AppTypography.small.copyWith(
                        color: AppColors.rpeMax, fontWeight: FontWeight.w500),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAerobicEfficiency() {
    final vals = _vm.aerobicEfficiency.value!;
    if (vals.length < 2) return const SizedBox();

    final improvement = (vals.last - vals.first) / vals.first * 100;
    final isImproving = improvement > 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader('EFICIENCIA AERÓBICA'),
        const SizedBox(height: AppSpacing.m),
        _Card(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.s, AppSpacing.l, AppSpacing.l, AppSpacing.m),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  height: 120,
                  child: LineChart(LineChartData(
                    lineBarsData: [
                      LineChartBarData(
                        spots: vals.asMap().entries
                            .map((e) => FlSpot(e.key.toDouble(), e.value))
                            .toList(),
                        color: isImproving ? AppColors.rpeLow : AppColors.effort,
                        barWidth: 2,
                        isCurved: true,
                        dotData: const FlDotData(show: false),
                      ),
                    ],
                    titlesData: FlTitlesData(
                      bottomTitles: AxisTitles(
                          sideTitles: SideTitles(showTitles: false)),
                      leftTitles: AxisTitles(
                          sideTitles: SideTitles(showTitles: false)),
                      topTitles: AxisTitles(
                          sideTitles: SideTitles(showTitles: false)),
                      rightTitles: AxisTitles(
                          sideTitles: SideTitles(showTitles: false)),
                    ),
                    gridData: const FlGridData(show: false),
                    borderData: FlBorderData(show: false),
                  )),
                ),
                const SizedBox(height: AppSpacing.m),
                Text(
                  isImproving
                      ? '↑ +${improvement.toStringAsFixed(1)}% — Corres más rápido con menos esfuerzo cardiaco'
                      : '↓ ${improvement.toStringAsFixed(1)}% — La eficiencia ha bajado en el período',
                  style: AppTypography.small.copyWith(
                      color: isImproving ? AppColors.rpeLow : AppColors.effort,
                      fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ── Bottom sheet de ayuda TSB ──────────────────────────────────────────────

  void _showTSBHelp() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(AppSpacing.l),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Estado de Forma',
                style: AppTypography.h3
                    .copyWith(color: AppColors.textPrimary(context))),
            const SizedBox(height: AppSpacing.l),
            _HelpItem('CTL (Chronic Training Load)',
                'Tu forma física acumulada. Sube con entrenamiento consistente (media de 42 días).',
                AppColors.brand),
            _HelpItem('ATL (Acute Training Load)',
                'Tu fatiga reciente. Sube con entrenos duros y baja con descanso (media de 7 días).',
                AppColors.effort),
            _HelpItem('TSB (Training Stress Balance)',
                'CTL menos ATL. Positivo = fresco, negativo = cansado.',
                AppColors.rpeLow),
            const SizedBox(height: AppSpacing.l),
            Text('Cómo interpretarlo',
                style: AppTypography.body.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary(context))),
            const SizedBox(height: AppSpacing.s),
            _ZoneExplain('TSB > +20', 'Muy fresco — ideal para competir', AppColors.rpeLow),
            _ZoneExplain('TSB +5 a +20', 'Fresco — meter intensidad', AppColors.rpeLow),
            _ZoneExplain('TSB -10 a +5', 'Cargando — normal en bloque', AppColors.brand),
            _ZoneExplain('TSB < -10', 'Fatigado — reducir volumen', AppColors.rpeMax),
            const SizedBox(height: AppSpacing.xl),
          ],
        ),
      ),
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  Color _tsbZoneColor(double tsb) {
    if (tsb > 5) return AppColors.rpeLow;
    if (tsb > -10) return AppColors.brand;
    if (tsb > -20) return AppColors.effort;
    return AppColors.rpeMax;
  }

  String _tsbZoneLabel(double tsb) {
    if (tsb > 20) return 'Muy fresco';
    if (tsb > 5) return 'Fresco';
    if (tsb > -10) return 'Cargando';
    if (tsb > -20) return 'Fatigado';
    return 'Peligro';
  }

  IconData _tsbZoneIcon(double tsb) {
    if (tsb > 5) return Icons.check_circle_outline;
    if (tsb > -10) return Icons.info_outline;
    return Icons.warning_amber_rounded;
  }

  Color _loadColor(double load) {
    if (load < 150) return AppColors.rpeLow;
    if (load < 300) return AppColors.brand;
    if (load < 500) return AppColors.effort;
    return AppColors.rpeMax;
  }

  static String _fmtPace(int secKm) {
    final m = secKm ~/ 60;
    final s = secKm % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  TextStyle _labelStyle() =>
      AppTypography.small.copyWith(fontSize: 9, color: AppColors.iconMutedOf(context));

  // ── Widgets auxiliares de sección ─────────────────────────────────────────

  Widget _HelpItem(String title, String desc, Color color) => Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.m),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(width: 8, height: 8, margin: const EdgeInsets.only(top: 5), decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4))),
            const SizedBox(width: AppSpacing.m),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppTypography.body.copyWith(fontWeight: FontWeight.w600, color: AppColors.textPrimary(context))),
                  Text(desc, style: AppTypography.small.copyWith(color: AppColors.iconMutedOf(context))),
                ],
              ),
            ),
          ],
        ),
      );

  Widget _ZoneExplain(String range, String label, Color color) => Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.xs),
        child: Row(
          children: [
            Container(width: 8, height: 8, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
            const SizedBox(width: AppSpacing.s),
            Text(range, style: AppTypography.small.copyWith(color: AppColors.textPrimary(context), fontWeight: FontWeight.w500)),
            const SizedBox(width: AppSpacing.s),
            Expanded(child: Text(label, style: AppTypography.small.copyWith(color: AppColors.iconMutedOf(context)))),
          ],
        ),
      );
}

// ── Widgets privados del archivo ──────────────────────────────────────────────

class _RangeChip extends StatefulWidget {
  const _RangeChip({required this.ctrl, required this.onChanged});
  final AnalyticsHubController ctrl;
  final VoidCallback onChanged;

  @override
  State<_RangeChip> createState() => _RangeChipState();
}

class _RangeChipState extends State<_RangeChip> {
  static const _labels = {
    AnalyticsTimeRange.week:        '7 días',
    AnalyticsTimeRange.month:       '30 días',
    AnalyticsTimeRange.threeMonths: '3 meses',
    AnalyticsTimeRange.year:        '1 año',
  };

  @override
  Widget build(BuildContext context) {
    final label = _labels[widget.ctrl.selectedRange.value] ?? '30 días';
    return GestureDetector(
      onTap: _showPicker,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.surfaceOf(context),
          border: Border.all(color: AppColors.borderOf(context)),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label,
                style: AppTypography.small
                    .copyWith(color: AppColors.textPrimary(context))),
            const SizedBox(width: 4),
            Icon(Icons.expand_more,
                size: 14, color: AppColors.iconMutedOf(context)),
          ],
        ),
      ),
    );
  }

  void _showPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(AppSpacing.l),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Período',
                style: AppTypography.h3
                    .copyWith(color: AppColors.textPrimary(context))),
            const SizedBox(height: AppSpacing.l),
            ..._labels.entries.map((e) => ListTile(
                  title: Text(e.value,
                      style: AppTypography.body
                          .copyWith(color: AppColors.textPrimary(context))),
                  trailing: widget.ctrl.selectedRange.value == e.key
                      ? const Icon(Icons.check_rounded,
                          color: AppColors.brand, size: 20)
                      : null,
                  onTap: () {
                    widget.ctrl.setRange(e.key);
                    widget.onChanged();
                    Navigator.pop(context);
                    if (mounted) setState(() {});
                  },
                )),
            const SizedBox(height: AppSpacing.l),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);
  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: AppTypography.small.copyWith(
        color: AppColors.iconMutedOf(context),
        letterSpacing: 1.2,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceOf(context),
        border: Border.all(color: AppColors.borderOf(context)),
        borderRadius: BorderRadius.circular(AppDimens.cardRadius),
      ),
      child: child,
    );
  }
}

class _StatBlock extends StatelessWidget {
  const _StatBlock({required this.label, required this.value, this.valueColor});
  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          value,
          style: AppTypography.body.copyWith(
            fontWeight: FontWeight.w600,
            color: valueColor ?? AppColors.textPrimary(context),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: AppTypography.small.copyWith(
              color: AppColors.iconMutedOf(context), fontSize: 11),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _TSBStat extends StatelessWidget {
  const _TSBStat({
    required this.label,
    required this.value,
    required this.subtitle,
    required this.color,
  });
  final String label;
  final String value;
  final String subtitle;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label,
            style: AppTypography.small.copyWith(color: color, fontSize: 11)),
        const SizedBox(height: 2),
        Text(value,
            style: AppTypography.h3.copyWith(color: color)),
        const SizedBox(height: 2),
        Text(subtitle,
            style: AppTypography.small
                .copyWith(color: AppColors.iconMutedOf(context), fontSize: 10)),
      ],
    );
  }
}

class _LegendLine extends StatelessWidget {
  const _LegendLine({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
            width: 16,
            height: 3,
            decoration: BoxDecoration(
                color: color, borderRadius: BorderRadius.circular(1.5))),
        const SizedBox(width: 4),
        Text(label,
            style: AppTypography.small
                .copyWith(color: AppColors.iconMutedOf(context), fontSize: 10)),
      ],
    );
  }
}

class _IntensityBar extends StatelessWidget {
  const _IntensityBar({required this.label, required this.pct, required this.color});
  final String label;
  final double pct;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 80,
          child: Text(label,
              style: AppTypography.small
                  .copyWith(color: AppColors.iconMutedOf(context))),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: pct / 100,
              backgroundColor: AppColors.borderOf(context),
              color: color,
              minHeight: 8,
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.s),
        SizedBox(
          width: 36,
          child: Text('${pct.toStringAsFixed(0)}%',
              textAlign: TextAlign.end,
              style: AppTypography.small.copyWith(
                  color: AppColors.textPrimary(context),
                  fontWeight: FontWeight.w600)),
        ),
      ],
    );
  }
}

class _RecordRow extends StatelessWidget {
  const _RecordRow({required this.label, required this.record, required this.isLast});
  final String label;
  final PersonalRecord? record;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.l, vertical: AppSpacing.m),
          child: Row(
            children: [
              SizedBox(
                width: 50,
                child: Text(label,
                    style: AppTypography.small
                        .copyWith(color: AppColors.iconMutedOf(context))),
              ),
              if (record == null)
                Expanded(
                  child: Text('—',
                      style: AppTypography.small
                          .copyWith(color: AppColors.iconMutedOf(context))),
                )
              else ...[
                Expanded(
                  child: Text(
                    _fmtPace(record!.paceSecKm.toInt()),
                    style: AppTypography.body.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary(context)),
                  ),
                ),
                if (record!.isRecent)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.rpeLow.withOpacity(0.15),
                      border: Border.all(color: AppColors.rpeLow.withOpacity(0.5)),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text('NUEVO RP',
                        style: AppTypography.small.copyWith(
                            color: AppColors.rpeLow,
                            fontSize: 9,
                            fontWeight: FontWeight.w700)),
                  )
                else if (record!.deltaSec != null) ...[
                  Text(
                    record!.deltaSec! >= 0
                        ? '↑ ${record!.deltaSec!.toStringAsFixed(0)}s'
                        : '↓ ${(-record!.deltaSec!).toStringAsFixed(0)}s',
                    style: AppTypography.small.copyWith(
                      color: record!.deltaSec! >= 0 ? AppColors.rpeLow : AppColors.rpeMax,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                const SizedBox(width: AppSpacing.m),
                Text(
                  _fmtDate(record!.date),
                  style: AppTypography.small.copyWith(
                      color: AppColors.iconMutedOf(context), fontSize: 10),
                ),
              ],
            ],
          ),
        ),
        if (!isLast) Divider(height: 1, color: AppColors.borderOf(context), indent: 16),
      ],
    );
  }

  static String _fmtPace(int secKm) {
    final m = secKm ~/ 60;
    final s = secKm % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  static String _fmtDate(DateTime d) => '${d.day}/${d.month}/${d.year % 100}';
}
