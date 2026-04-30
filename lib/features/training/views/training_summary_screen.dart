import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../data/serie.dart';
import '../data/entrenamiento.dart';
import '../data/training_repository.dart';
import '../../../../core/services/gps_service.dart';
import '../../../../core/utils/app_transitions.dart';
import 'package:running_laps/core/widgets/main_shell.dart';
import '../../history/widgets/training_map_view.dart';
import 'package:running_laps/config/app_theme.dart';
import 'package:running_laps/core/theme/app_colors.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Screen — post-save, informational only
// ─────────────────────────────────────────────────────────────────────────────

class TrainingSummaryScreen extends StatefulWidget {
  /// The training that has already been saved to Firestore.
  final Entrenamiento entrenamiento;

  const TrainingSummaryScreen({
    Key? key,
    required this.entrenamiento,
  }) : super(key: key);

  @override
  State<TrainingSummaryScreen> createState() => _TrainingSummaryScreenState();
}

class _TrainingSummaryScreenState extends State<TrainingSummaryScreen>
    with TickerProviderStateMixin {
  // ── Animations ─────────────────────────────────────────────────────────────
  late final AnimationController _sparkleCtrl;
  late final AnimationController _staggerCtrl;
  late final List<Animation<double>> _sectionFades;
  late final List<Animation<Offset>> _sectionSlides;

  // ── Derived totals ─────────────────────────────────────────────────────────
  late final int _distanciaM;
  late final double _tiempoTotalSec;
  late final int? _ritmoSecKm;
  late final int? _fastestIdx;    // index into series of fastest pace

  // ── Comparison ─────────────────────────────────────────────────────────────
  Future<Entrenamiento?>? _similarFuture;

  // ── Colors ─────────────────────────────────────────────────────────────────
  static const _green = Color(0xFF10B981);
  static const _blue  = Color(0xFF3B82F6);
  static const _amber = Color(0xFFF59E0B);
  static const _red   = Color(0xFFEF4444);

  Color get _adaptivePurple => Theme.of(context).brightness == Brightness.dark
      ? AppColors.brandLight
      : AppColors.brand;

  // ─────────────────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();

    final series = widget.entrenamiento.series;

    _distanciaM     = series.fold(0,   (s, e) => s + e.distanciaM);
    _tiempoTotalSec = series.fold(0.0, (s, e) => s + e.tiempoSec);

    int? ritmoTemp;
    if (_distanciaM > 0) {
      ritmoTemp = (_tiempoTotalSec / (_distanciaM / 1000.0)).round();
    }
    _ritmoSecKm = ritmoTemp;

    // Fastest serie = lowest sec/km
    int? fastIdx;
    int? fastPace;
    for (int i = 0; i < series.length; i++) {
      final s = series[i];
      if (s.distanciaM > 0) {
        final p = (s.tiempoSec / (s.distanciaM / 1000.0)).round();
        if (fastPace == null || p < fastPace) {
          fastPace = p;
          fastIdx  = i;
        }
      }
    }
    _fastestIdx = fastIdx;

    // Sparkle — loops while screen is alive
    _sparkleCtrl = AnimationController(
      duration: const Duration(milliseconds: 2400),
      vsync: this,
    )..repeat();

    // Stagger — 5 sections, plays once
    const kSections = 5;
    _staggerCtrl = AnimationController(
      duration: const Duration(milliseconds: 900),
      vsync: this,
    );

    _sectionFades = List.generate(kSections, (i) {
      final start = (i * 0.14).clamp(0.0, 1.0);
      final end   = (start + 0.45).clamp(0.0, 1.0);
      return Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(
          parent: _staggerCtrl,
          curve: Interval(start, end, curve: Curves.easeOut),
        ),
      );
    });

    _sectionSlides = List.generate(kSections, (i) {
      final start = (i * 0.14).clamp(0.0, 1.0);
      final end   = (start + 0.45).clamp(0.0, 1.0);
      return Tween<Offset>(
        begin: const Offset(0, 0.06),
        end: Offset.zero,
      ).animate(
        CurvedAnimation(
          parent: _staggerCtrl,
          curve: Interval(start, end, curve: Curves.easeOut),
        ),
      );
    });

    _staggerCtrl.forward();
    _similarFuture = _fetchSimilarTraining();
  }

  @override
  void dispose() {
    _sparkleCtrl.dispose();
    _staggerCtrl.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Comparison logic
  // ─────────────────────────────────────────────────────────────────────────

  Future<Entrenamiento?> _fetchSimilarTraining() async {
    try {
      final all = (await TrainingRepository().getTrainings(pageSize: 500)).trainings;
      for (final t in all) {
        // Skip the just-saved training itself
        if (t.id != null &&
            t.id == widget.entrenamiento.id) continue;
        if (_isSimilarSession(widget.entrenamiento, t)) return t;
      }
    } catch (_) {}
    return null;
  }

  /// Similar = same number of series AND every distance within ±20% (sorted).
  bool _isSimilarSession(Entrenamiento current, Entrenamiento candidate) {
    if (current.series.isEmpty) return false;
    if (current.series.length != candidate.series.length) return false;

    final currDists = current.series
        .map((s) => s.distanciaM)
        .toList()
      ..sort();
    final prevDists = candidate.series
        .map((s) => s.distanciaM)
        .toList()
      ..sort();

    for (int i = 0; i < currDists.length; i++) {
      if (prevDists[i] == 0) return false;
      final ratio = currDists[i] / prevDists[i];
      if (ratio < 0.80 || ratio > 1.25) return false;
    }
    return true;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Helpers
  // ─────────────────────────────────────────────────────────────────────────

  String _formatPace(int secKm) {
    final m = secKm ~/ 60;
    final s = secKm % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  String _timeValue() {
    final total = _tiempoTotalSec.round();
    final h = total ~/ 3600;
    final m = (total % 3600) ~/ 60;
    final s = total % 60;
    if (h > 0) return '$h:${m.toString().padLeft(2, '0')}';
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  String _timeUnit() => (_tiempoTotalSec ~/ 3600) > 0 ? 'h:min' : 'min:seg';

  String _formatDate(DateTime d) {
    const months = [
      'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio',
      'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre',
    ];
    final h   = d.hour.toString().padLeft(2, '0');
    final min = d.minute.toString().padLeft(2, '0');
    return '${d.day} de ${months[d.month - 1]} · $h:$min';
  }

  String _formatDateShort(DateTime d) {
    const months = [
      'ene', 'feb', 'mar', 'abr', 'may', 'jun',
      'jul', 'ago', 'sep', 'oct', 'nov', 'dic',
    ];
    return '${d.day} ${months[d.month - 1]}';
  }

  Color _rpeColor(double rpe) {
    if (rpe <= 4) return _green;
    if (rpe <= 7) return _amber;
    return _red;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Build
  // ─────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final hasGps = widget.entrenamiento.trackPoints.isNotEmpty;

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    const SizedBox(height: 28),
                    _section(0, _buildHeader()),
                    const SizedBox(height: 24),
                    _section(1, _buildHeroMetrics()),
                    const SizedBox(height: 14),
                    _section(2, _buildSeriesCard()),
                    if (hasGps) ...[
                      const SizedBox(height: 14),
                      _section(3, _buildMapCard()),
                    ],
                    const SizedBox(height: 14),
                    _section(4, _buildComparisonCard()),
                    const SizedBox(height: 28),
                  ],
                ),
              ),
            ),
            _buildActions(),
          ],
        ),
      ),
    );
  }

  Widget _section(int i, Widget child) => FadeTransition(
        opacity: _sectionFades[i],
        child: SlideTransition(position: _sectionSlides[i], child: child),
      );

  // ─────────────────────────────────────────────────────────────────────────
  // Header
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    return Column(
      children: [
        SizedBox(
          height: 56,
          width: double.infinity,
          child: AnimatedBuilder(
            animation: _sparkleCtrl,
            builder: (_, __) => CustomPaint(
              painter: _SparklePainter(progress: _sparkleCtrl.value),
            ),
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          '¡Entrenamiento\ncompletado!',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white,
            fontSize: 30,
            fontWeight: FontWeight.w900,
            height: 1.1,
            letterSpacing: -0.8,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          _formatDate(widget.entrenamiento.fecha),
          style: TextStyle(
            color: Colors.white.withOpacity(0.4),
            fontSize: 13,
          ),
        ),
        if (widget.entrenamiento.titulo.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            widget.entrenamiento.titulo,
            style: TextStyle(
              color: _adaptivePurple.withOpacity(0.85),
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Hero metrics
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildHeroMetrics() {
    final distValue = _distanciaM >= 1000
        ? (_distanciaM / 1000).toStringAsFixed(2)
        : '$_distanciaM';
    final distUnit = _distanciaM >= 1000 ? 'km' : 'm';

    return Row(
      children: [
        Expanded(
          child: _MetricCard(
            label: 'Distancia',
            value: distValue,
            unit: distUnit,
            accent: _green,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _MetricCard(
            label: 'Tiempo',
            value: _timeValue(),
            unit: _timeUnit(),
            accent: _adaptivePurple,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _MetricCard(
            label: 'Ritmo medio',
            value: _ritmoSecKm != null ? _formatPace(_ritmoSecKm!) : '—',
            unit: _ritmoSecKm != null ? '/km' : '',
            accent: _blue,
          ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Smart series card
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildSeriesCard() {
    final series = widget.entrenamiento.series;
    final count  = series.length;

    // Group by distance for summary line
    final Map<int, int> groups = {};
    for (final s in series) {
      groups[s.distanciaM] = (groups[s.distanciaM] ?? 0) + 1;
    }
    final sortedGroups = groups.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    final groupText = sortedGroups
        .map((e) => '${e.value} × ${e.key}m')
        .join(' · ');

    return _GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──────────────────────────────────────────────────────
          Row(
            children: [
              Icon(Icons.check_circle_rounded,
                  color: _adaptivePurple, size: 20),
              const SizedBox(width: 8),
              Text(
                '$count ${count == 1 ? 'serie completada' : 'series completadas'}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            groupText,
            style: TextStyle(
              color: Colors.white.withOpacity(0.45),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),

          const Divider(
              color: Colors.white12, height: 24, thickness: 0.5),

          // ── Per-serie rows ───────────────────────────────────────────────
          ...List.generate(series.length, (i) {
            final s         = series[i];
            final isFastest = i == _fastestIdx;

            int? paceSecKm;
            String paceText = '—';
            if (s.distanciaM > 0) {
              paceSecKm = (s.tiempoSec / (s.distanciaM / 1000.0)).round();
              paceText  = _formatPace(paceSecKm);
            }

            final rpeClr = _rpeColor(s.rpe);

            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  // Serie label
                  SizedBox(
                    width: 26,
                    child: Text(
                      'S${i + 1}',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.38),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  // Distance
                  SizedBox(
                    width: 48,
                    child: Text(
                      '${s.distanciaM}m',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.55),
                        fontSize: 12,
                      ),
                    ),
                  ),
                  // Pace + fastest badge
                  Expanded(
                    child: Row(
                      children: [
                        Text(
                          '$paceText/km',
                          style: TextStyle(
                            color: isFastest ? _green : Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (isFastest) ...[
                          const SizedBox(width: 4),
                          const Icon(Icons.flash_on_rounded,
                              size: 13, color: _green),
                        ],
                      ],
                    ),
                  ),
                  // RPE dot + value
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: rpeClr,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        s.rpe.toStringAsFixed(1),
                        style: TextStyle(
                          color: rpeClr.withOpacity(0.9),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // GPS map (unchanged)
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildMapCard() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Container(
        height: 220,
        decoration: BoxDecoration(
          border: Border.all(color: Colors.white.withOpacity(0.1)),
          borderRadius: BorderRadius.circular(16),
        ),
        child: TrainingMapView(points: widget.entrenamiento.trackPoints),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Smart comparison card
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildComparisonCard() {
    return FutureBuilder<Entrenamiento?>(
      future: _similarFuture,
      builder: (context, snapshot) {
        // Hide while loading or if no similar session found
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox.shrink();
        }
        final similar = snapshot.data;
        if (similar == null) return const SizedBox.shrink();

        final currSeries = widget.entrenamiento.series;
        final prevSeries = similar.series;

        // Sort both by distance ascending for a meaningful side-by-side
        final currSorted = [...currSeries]
          ..sort((a, b) => a.distanciaM.compareTo(b.distanciaM));
        final prevSorted = [...prevSeries]
          ..sort((a, b) => a.distanciaM.compareTo(b.distanciaM));

        // Build per-distance rows (only where both have distance > 0)
        final rows = <Widget>[];
        for (int i = 0; i < currSorted.length; i++) {
          final curr = currSorted[i];
          final prev = prevSorted[i];
          if (curr.distanciaM == 0 || prev.distanciaM == 0) continue;

          final currPace =
              (curr.tiempoSec / (curr.distanciaM / 1000.0)).round();
          final prevPace =
              (prev.tiempoSec / (prev.distanciaM / 1000.0)).round();
          final diff     = currPace - prevPace; // negative = faster
          final diffClr  = diff <= 0 ? _green : _red;
          final sign     = diff <= 0 ? '−' : '+';
          final diffText = '$sign${_formatPace(diff.abs())} /km';

          rows.add(
            Padding(
              padding: const EdgeInsets.only(bottom: 9),
              child: Row(
                children: [
                  // Distance label
                  SizedBox(
                    width: 46,
                    child: Text(
                      '${curr.distanciaM}m',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.4),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  // Current pace vs previous pace
                  Text(
                    '${_formatPace(currPace)} vs ${_formatPace(prevPace)}',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 12,
                    ),
                  ),
                  const Spacer(),
                  // Diff badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: diffClr.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(6),
                      border:
                          Border.all(color: diffClr.withOpacity(0.3)),
                    ),
                    child: Text(
                      diffText,
                      style: TextStyle(
                        color: diffClr,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        if (rows.isEmpty) return const SizedBox.shrink();

        return _GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.analytics_outlined,
                      color: _adaptivePurple.withOpacity(0.7), size: 16),
                  const SizedBox(width: 8),
                  const Text(
                    'Comparativa con sesión similar',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(Icons.arrow_forward_rounded,
                      color: Colors.white.withOpacity(0.28), size: 12),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '${similar.titulo.isNotEmpty ? similar.titulo : 'Sesión sin nombre'} · ${_formatDateShort(similar.fecha)} ${similar.fecha.year}',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.45),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                'SESIÓN ANTERIOR',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.28),
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 8),
              ...rows,
            ],
          ),
        );
      },
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Single action button
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildActions() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.background,
        border: Border(
          top: BorderSide(color: Colors.white.withOpacity(0.07)),
        ),
      ),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.brand,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14)),
            elevation: 0,
          ),
          onPressed: () => Navigator.pushAndRemoveUntil(
            context,
            AppRoute(page: const MainShell()),
            (route) => false,
          ),
          child: const Text(
            'Volver al inicio',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Glass card
// ─────────────────────────────────────────────────────────────────────────────

class _GlassCard extends StatelessWidget {
  final Widget child;

  const _GlassCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.10)),
      ),
      child: child,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Metric card
// ─────────────────────────────────────────────────────────────────────────────

class _MetricCard extends StatelessWidget {
  final String label;
  final String value;
  final String unit;
  final Color  accent;

  const _MetricCard({
    required this.label,
    required this.value,
    required this.unit,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 18, 14, 16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.10)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 3,
            decoration: BoxDecoration(
              color: accent,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
              height: 1.0,
            ),
          ),
          if (unit.isNotEmpty) ...[
            const SizedBox(height: 3),
            Text(
              unit,
              style: TextStyle(
                color: accent.withOpacity(0.75),
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.38),
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sparkle painter — deterministic particles that loop indefinitely
// ─────────────────────────────────────────────────────────────────────────────

class _SparklePainter extends CustomPainter {
  final double progress;

  static const List<Color> _colors = [
    Color(0xFF8E24AA),
    Color(0xFF10B981),
    Color(0xFF3B82F6),
    Color(0xFFF59E0B),
    Colors.white,
  ];

  static final _r = math.Random(42);
  static final List<_Particle> _particles = List.generate(20, (i) {
    return _Particle(
      bx:    _r.nextDouble(),
      by:    _r.nextDouble() * 0.65,
      size:  2.0 + _r.nextDouble() * 3.5,
      ci:    i % _colors.length,
      phase: _r.nextDouble(),
      speed: 0.35 + _r.nextDouble() * 0.65,
    );
  });

  const _SparklePainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in _particles) {
      final t       = ((progress + p.phase) % 1.0);
      final opacity = math.sin(t * math.pi);
      final dx      = math.cos(p.phase * math.pi * 2) * 28.0 * t;
      final dy      = -52.0 * t * p.speed;
      final paint   = Paint()
        ..color = _colors[p.ci].withOpacity(opacity * 0.65)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(
        Offset(size.width * p.bx + dx, size.height * p.by + dy),
        p.size * (1 - t * 0.35),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _SparklePainter old) =>
      old.progress != progress;
}

class _Particle {
  final double bx, by, size, phase, speed;
  final int ci;
  const _Particle({
    required this.bx,
    required this.by,
    required this.size,
    required this.ci,
    required this.phase,
    required this.speed,
  });
}
