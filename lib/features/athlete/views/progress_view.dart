import 'dart:math' show max, min;

import 'package:flutter/material.dart';
import 'package:running_laps/core/theme/app_colors.dart';
import 'package:running_laps/core/utils/app_transitions.dart';
import 'package:running_laps/core/widgets/app_header.dart';
import 'package:running_laps/features/athlete/data/progress_repository.dart';
import 'package:running_laps/features/athlete/viewmodels/progress_viewmodel.dart';
import 'package:running_laps/features/athlete/views/athlete_hub_view.dart';

class ProgressView extends StatefulWidget {
  final String uid;

  const ProgressView({super.key, required this.uid});

  @override
  State<ProgressView> createState() => _ProgressViewState();
}

class _ProgressViewState extends State<ProgressView> {
  late final ProgressViewModel _vm;

  @override
  void initState() {
    super.initState();
    _vm = ProgressViewModel();
    _vm.init(widget.uid);
  }

  @override
  void dispose() {
    _vm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          AppHeader(
            title: const Text(
              'Progreso',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),
          ),
          Expanded(
            child: ValueListenableBuilder<ProgressViewModelState>(
              valueListenable: _vm.state,
              builder: (context, state, _) {
                if (state.isLoading) {
                  return const Center(
                    child: CircularProgressIndicator(
                        color: AppColors.brand),
                  );
                }
                if (state.errorMessage != null) {
                  return _buildError(context, state.errorMessage!);
                }
                return SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_vm.hasPersonalRecords) ...[
                        _buildPersonalRecords(context, state),
                        const SizedBox(height: 32),
                      ],
                      _buildSeriesProgress(context, state),
                      const SizedBox(height: 32),
                      _buildWeeklyVolume(context, state),
                      const SizedBox(height: 32),
                      _buildPlannedVsExecuted(context, state),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ── Error state ────────────────────────────────────────────────────────────

  Widget _buildError(BuildContext context, String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message,
                style: const TextStyle(color: AppColors.paceSlow),
                textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => _vm.init(widget.uid),
              style: FilledButton.styleFrom(
                  backgroundColor: AppColors.brand),
              child: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }

  // ── Sección 1: Récords personales ─────────────────────────────────────────

  Widget _buildPersonalRecords(
      BuildContext context, ProgressViewModelState state) {
    const distances = [400, 1000, 5000, 10000];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle('Récords personales'),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 2,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 1.6,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: distances
              .map((d) => _PersonalRecordCard(
                    distanceM: d,
                    record: state.personalRecords[d],
                  ))
              .toList(),
        ),
      ],
    );
  }

  // ── Sección 2: Progreso en series ─────────────────────────────────────────

  Widget _buildSeriesProgress(
      BuildContext context, ProgressViewModelState state) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final secondary =
        isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle('Progreso en series'),
        const SizedBox(height: 2),
        Text('Evolución de tu pace en series equivalentes',
            style: TextStyle(fontSize: 13, color: secondary)),
        const SizedBox(height: 12),
        if (!_vm.hasSeriesProgress)
          Text(
            'Necesitas al menos 3 series de la misma distancia '
            'para ver la progresión',
            style: TextStyle(fontSize: 14, color: secondary),
          )
        else
          ...state.seriesProgress.take(3).map((group) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _SeriesProgressCard(
                  group: group,
                  trend: _vm.trendForGroup(group),
                  isDark: isDark,
                ),
              )),
      ],
    );
  }

  // ── Sección 3: Volumen semanal ─────────────────────────────────────────────

  Widget _buildWeeklyVolume(
      BuildContext context, ProgressViewModelState state) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final secondary =
        isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle('Volumen semanal'),
        const SizedBox(height: 2),
        Text('Últimas 12 semanas',
            style: TextStyle(fontSize: 13, color: secondary)),
        const SizedBox(height: 16),
        SizedBox(
          height: 120,
          child: _VolumeChart(
            volumes: state.weeklyVolume,
            movingAverage: state.movingAverage,
            isDark: isDark,
          ),
        ),
      ],
    );
  }

  // ── Sección 4: Planificado vs ejecutado ───────────────────────────────────

  Widget _buildPlannedVsExecuted(
      BuildContext context, ProgressViewModelState state) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final secondary =
        isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle('Planificado vs ejecutado'),
        const SizedBox(height: 12),
        if (!_vm.hasPlannedVsExecuted)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Vincula tus entrenamientos con sesiones planificadas '
                'para ver la comparativa',
                style: TextStyle(fontSize: 14, color: secondary),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  AppRoute(
                      page: AthleteHubView(uid: widget.uid)),
                ),
                icon: const Icon(Icons.calendar_month_outlined),
                label: const Text('Planificar sesión'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.brand,
                  side: const BorderSide(color: AppColors.brand),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          )
        else
          ...state.plannedVsExecuted.take(10).map((pve) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _PveCard(
                  pve: pve,
                  deviation: _vm.paceDeviationSecPerKm(pve),
                  isDark: isDark,
                ),
              )),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _SectionTitle
// ─────────────────────────────────────────────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _PersonalRecordCard
// ─────────────────────────────────────────────────────────────────────────────

class _PersonalRecordCard extends StatelessWidget {
  final int distanceM;
  final PersonalRecord? record;

  const _PersonalRecordCard({
    required this.distanceM,
    required this.record,
  });

  String _distanceLabel(int m) {
    if (m == 400)   return '400 m';
    if (m == 1000)  return '1 km';
    if (m == 5000)  return '5 km';
    if (m == 10000) return '10 km';
    return '${m}m';
  }

  String _formatPace(double secPerKm) {
    final total = secPerKm.round();
    final mm    = total ~/ 60;
    final ss    = (total % 60).toString().padLeft(2, '0');
    return '$mm:$ss /km';
  }

  String _formatDate(DateTime d) {
    const months = [
      '', 'ene', 'feb', 'mar', 'abr', 'may', 'jun',
      'jul', 'ago', 'sep', 'oct', 'nov', 'dic',
    ];
    return '${d.day} ${months[d.month]} ${d.year}';
  }

  @override
  Widget build(BuildContext context) {

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface2Of(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppColors.borderOf(context),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            _distanceLabel(distanceM),
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFFAAAAAA),
            ),
          ),
          if (record != null) ...[
            Text(
              _formatPace(record!.paceSecPerKm),
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppColors.brand,
              ),
            ),
            Text(
              _formatDate(record!.date),
              style: const TextStyle(fontSize: 11, color: Color(0xFFAAAAAA)),
            ),
          ] else
            const Text(
              '—',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: Color(0xFFAAAAAA),
              ),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _SeriesProgressCard
// ─────────────────────────────────────────────────────────────────────────────

class _SeriesProgressCard extends StatelessWidget {
  final SeriesProgressGroup group;
  final double? trend;
  final bool isDark;

  const _SeriesProgressCard({
    required this.group,
    required this.trend,
    required this.isDark,
  });

  String _distLabel(int m) =>
      m >= 1000 ? '${(m / 1000).toStringAsFixed(m % 1000 == 0 ? 0 : 1)} km' : '${m}m';

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceOf(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppColors.borderOf(context),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Row(
            children: [
              Expanded(
                child: Text(
                  '${_distLabel(group.baseDistanceM)}  ·  ${group.count} series',
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w700),
                ),
              ),
              if (trend != null)
                _TrendBadge(improving: trend! > 0),
            ],
          ),
          const SizedBox(height: 10),
          // Mini line chart
          SizedBox(
            height: 60,
            child: _MiniLineChart(
              points: group.history.map((p) => p.paceSecPerKm).toList(),
            ),
          ),
          const SizedBox(height: 6),
          // X-axis labels
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _fmtDate(group.history.first.date),
                style: const TextStyle(
                    fontSize: 10, color: Color(0xFFAAAAAA)),
              ),
              Text(
                _fmtDate(group.history.last.date),
                style: const TextStyle(
                    fontSize: 10, color: Color(0xFFAAAAAA)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _fmtDate(DateTime d) {
    const m = ['', 'ene', 'feb', 'mar', 'abr', 'may', 'jun',
                'jul', 'ago', 'sep', 'oct', 'nov', 'dic'];
    return '${d.day} ${m[d.month]}';
  }
}

class _TrendBadge extends StatelessWidget {
  final bool improving;
  const _TrendBadge({required this.improving});

  @override
  Widget build(BuildContext context) {
    final color = improving ? AppColors.rpeLow : AppColors.effort;
    final icon  = improving ? Icons.arrow_upward_rounded
                            : Icons.arrow_downward_rounded;
    final label = improving ? 'Mejorando' : 'A revisar';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color:        color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border:       Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 3),
          Text(label,
              style: TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w700, color: color)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _MiniLineChart  (CustomPaint)
// ─────────────────────────────────────────────────────────────────────────────

class _MiniLineChart extends StatelessWidget {
  final List<double> points;

  const _MiniLineChart({required this.points});

  @override
  Widget build(BuildContext context) {
    if (points.length < 2) return const SizedBox.shrink();
    return CustomPaint(
      painter: _MiniLinePainter(points: points),
      size: Size.infinite,
    );
  }
}

class _MiniLinePainter extends CustomPainter {
  final List<double> points;
  const _MiniLinePainter({required this.points});

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;

    final minVal = points.reduce(min);
    final maxVal = points.reduce(max);
    final range  = maxVal - minVal;

    // Normalise: lower pace (faster) → higher on chart
    double norm(double v) {
      if (range == 0) return size.height / 2;
      // pace is inverted: lower value = better = higher on chart
      return size.height - ((v - minVal) / range) * size.height * 0.85 -
          size.height * 0.075;
    }

    final linePaint = Paint()
      ..color       = AppColors.brand
      ..strokeWidth = 2
      ..style       = PaintingStyle.stroke
      ..strokeCap   = StrokeCap.round
      ..strokeJoin  = StrokeJoin.round;

    final dotPaint = Paint()
      ..color = AppColors.brandLight
      ..style = PaintingStyle.fill;

    final path = Path();
    for (var i = 0; i < points.length; i++) {
      final x = (i / (points.length - 1)) * size.width;
      final y = norm(points[i]);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(path, linePaint);

    for (var i = 0; i < points.length; i++) {
      final x = (i / (points.length - 1)) * size.width;
      final y = norm(points[i]);
      canvas.drawCircle(Offset(x, y), 3, dotPaint);
    }
  }

  @override
  bool shouldRepaint(_MiniLinePainter old) => old.points != points;
}

// ─────────────────────────────────────────────────────────────────────────────
// _VolumeChart  (barras + línea media móvil, CustomPaint)
// ─────────────────────────────────────────────────────────────────────────────

class _VolumeChart extends StatelessWidget {
  final List<WeeklyVolume> volumes;
  final List<double> movingAverage;
  final bool isDark;

  const _VolumeChart({
    required this.volumes,
    required this.movingAverage,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    if (volumes.isEmpty) return const SizedBox.shrink();

    const labelHeight  = 20.0;

    final maxKm = volumes.fold<double>(0, (m, w) => max(m, w.km));

    final now           = DateTime.now();
    final today         = DateTime(now.year, now.month, now.day);
    final currentMonday = today.subtract(Duration(days: today.weekday - 1));

    return Column(
      children: [
        Expanded(
          child: CustomPaint(
            painter: _VolumePainter(
              volumes:       volumes,
              movingAverage: movingAverage,
              maxKm:         maxKm,
              isDark:        isDark,
            ),
            size: Size.infinite,
          ),
        ),
        SizedBox(
          height: labelHeight,
          child: Row(
            children: volumes.asMap().entries.map((e) {
              final i         = e.key;
              final w         = e.value;
              final isCurrent = w.weekStart == currentMonday;
              return Expanded(
                child: Text(
                  isCurrent ? 'HOY' : 'S${i + 1}',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize:   isCurrent ? 9 : 8,
                    fontWeight:
                        isCurrent ? FontWeight.w700 : FontWeight.w400,
                    color: isCurrent
                        ? AppColors.brand
                        : const Color(0xFFAAAAAA),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

class _VolumePainter extends CustomPainter {
  final List<WeeklyVolume> volumes;
  final List<double> movingAverage;
  final double maxKm;
  final bool isDark;

  const _VolumePainter({
    required this.volumes,
    required this.movingAverage,
    required this.maxKm,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (volumes.isEmpty) return;
    const minBarH = 4.0;
    final n       = volumes.length;
    final barW    = size.width / n;
    final barPad  = barW * 0.15;

    final barPaint = Paint()
      ..color = AppColors.brand.withValues(alpha: 0.6)
      ..style = PaintingStyle.fill;

    final linePaint = Paint()
      ..color       = AppColors.brandLight
      ..strokeWidth = 2
      ..style       = PaintingStyle.stroke
      ..strokeCap   = StrokeCap.round
      ..strokeJoin  = StrokeJoin.round;

    // Draw bars
    for (var i = 0; i < n; i++) {
      final km = volumes[i].km;
      if (km <= 0) continue;
      final h = maxKm > 0
          ? max(minBarH, (km / maxKm) * (size.height * 0.90))
          : minBarH;
      final left   = i * barW + barPad;
      final right  = (i + 1) * barW - barPad;
      final top    = size.height - h;
      final bottom = size.height;
      canvas.drawRRect(
        RRect.fromLTRBR(left, top, right, bottom, const Radius.circular(3)),
        barPaint,
      );
    }

    // Draw moving average line
    if (movingAverage.length == n && maxKm > 0) {
      final path = Path();
      bool started = false;
      for (var i = 0; i < n; i++) {
        final x = i * barW + barW / 2;
        final y = size.height -
            (movingAverage[i] / maxKm) * size.height * 0.90;
        if (!started) {
          path.moveTo(x, y);
          started = true;
        } else {
          path.lineTo(x, y);
        }
      }
      canvas.drawPath(path, linePaint);
    }
  }

  @override
  bool shouldRepaint(_VolumePainter old) =>
      old.volumes != volumes || old.movingAverage != movingAverage;
}

// ─────────────────────────────────────────────────────────────────────────────
// _PveCard
// ─────────────────────────────────────────────────────────────────────────────

class _PveCard extends StatelessWidget {
  final PlannedVsExecuted pve;
  final double? deviation;
  final bool isDark;

  const _PveCard({
    required this.pve,
    required this.deviation,
    required this.isDark,
  });

  String _categoryLabel(String? c) {
    switch (c) {
      case 'regenerativo':    return 'Regenerativo';
      case 'rodaje_base':     return 'Rodaje base (Z2)';
      case 'tempo':           return 'Tempo (Z3)';
      case 'fartlek':         return 'Fartlek';
      case 'series_largas':   return 'Series largas';
      case 'series_cortas':   return 'Series cortas';
      case 'series_cuestas':  return 'Series en cuestas';
      case 'series_mixtas':   return 'Series mixtas';
      case 'competicion':     return 'Competición';
      case 'test':            return 'Test';
      default:                return c ?? 'Entrenamiento';
    }
  }

  String _formatPace(double secPerKm) {
    final total = secPerKm.abs().round();
    final mm    = total ~/ 60;
    final ss    = (total % 60).toString().padLeft(2, '0');
    return '$mm:$ss';
  }

  String _formatDelta(double secPerKm) {
    final prefix = secPerKm >= 0 ? '+' : '-';
    return '$prefix${_formatPace(secPerKm)} /km';
  }

  Color _deltaColor(double dev) {
    final abs = dev.abs();
    if (abs <= 15) return AppColors.rpeLow;
    if (abs <= 30) return AppColors.rpeMid;
    return AppColors.rpeMax;
  }

  String _execPaceLabel() {
    final series = pve.executed.series
        .where((s) => s.distanciaM > 0 && s.tiempoSec > 0)
        .toList();
    if (series.isEmpty) return '—';
    final avg = series.fold<double>(
          0,
          (s, e) => s + e.tiempoSec / (e.distanciaM / 1000.0),
        ) /
        series.length;
    return '${_formatPace(avg)} /km';
  }

  @override
  Widget build(BuildContext context) {
    final secondary = isDark
        ? AppColors.textSecondaryDark
        : AppColors.textSecondaryLight;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color:        AppColors.surfaceOf(context),
        borderRadius: BorderRadius.circular(14),
        border:       Border.all(
          color: AppColors.borderOf(context),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Text(
            '${pve.planned.date}  ·  ${_categoryLabel(pve.planned.category)}',
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: secondary),
          ),
          const SizedBox(height: 10),

          if (deviation != null) ...[
            // Comparison row headers
            Row(
              children: [
                Expanded(child: Text('Objetivo',
                    style: TextStyle(fontSize: 11, color: secondary),
                    textAlign: TextAlign.center)),
                Expanded(child: Text('Ejecutado',
                    style: TextStyle(fontSize: 11, color: secondary),
                    textAlign: TextAlign.center)),
                Expanded(child: Text('Diferencia',
                    style: TextStyle(fontSize: 11, color: secondary),
                    textAlign: TextAlign.center)),
              ],
            ),
            const SizedBox(height: 4),
            // Comparison row values
            Row(
              children: [
                Expanded(
                  child: _buildPaceTarget(secondary),
                ),
                Expanded(
                  child: Text(
                    _execPaceLabel(),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w700),
                  ),
                ),
                Expanded(
                  child: Text(
                    _formatDelta(deviation!),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize:   14,
                      fontWeight: FontWeight.w700,
                      color:      _deltaColor(deviation!),
                    ),
                  ),
                ),
              ],
            ),
          ] else ...[
            // Fallback: distance + RPE
            Text(
              'Distancia: ${(pve.executed.distanciaTotalM() / 1000).toStringAsFixed(2)} km'
              '  ·  RPE: ${pve.executed.rpePromedio().toStringAsFixed(1)}',
              style: TextStyle(fontSize: 13, color: secondary),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPaceTarget(Color secondary) {
    // Find the target block again for display
    for (final block in pve.planned.blocks) {
      if (block.targetPaceMinMin != null) {
        final minStr =
            '${block.targetPaceMinMin}:${(block.targetPaceMinSec ?? 0).toString().padLeft(2, '0')}';
        if (block.targetPaceMaxMin != null) {
          final maxStr =
              '${block.targetPaceMaxMin}:${(block.targetPaceMaxSec ?? 0).toString().padLeft(2, '0')}';
          return Text('$minStr–$maxStr',
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w700));
        }
        return Text('$minStr /km',
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontSize: 14, fontWeight: FontWeight.w700));
      }
    }
    return Text('—',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 14, color: secondary));
  }
}
