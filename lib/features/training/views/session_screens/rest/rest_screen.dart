import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:running_laps/features/templates/data/workout_session.dart';
import 'package:running_laps/core/theme/app_colors.dart';

import '../../../../training/data/serie.dart';
import '../shared/session_theme.dart';
import '../shared/session_layout.dart';
import '../shared/metrics/fc_widget.dart';
import '../shared/metrics/time_widget.dart';
import '../shared/metrics/progress_bar.dart';

class RestScreen extends StatelessWidget {
  final WorkoutSession session;
  final int restDurationSec;
  final String? nextRepInfo;
  final int nextRepNumber;
  final int totalReps;
  final VoidCallback onSkip;
  final ValueListenable<Duration> elapsedNotifier;
  final ValueListenable<int?> fcNotifier;
  final ValueListenable<int?> fcZoneNotifier;
  final int? fcStartedAt;
  final Serie? completedSerie;
  final int? targetPaceMinSec;
  final int? targetPaceMaxSec;

  const RestScreen({
    super.key,
    required this.session,
    required this.restDurationSec,
    required this.nextRepNumber,
    required this.totalReps,
    required this.onSkip,
    required this.elapsedNotifier,
    required this.fcNotifier,
    required this.fcZoneNotifier,
    this.nextRepInfo,
    this.fcStartedAt,
    this.completedSerie,
    this.targetPaceMinSec,
    this.targetPaceMaxSec,
  });

  @override
  Widget build(BuildContext context) {
    final theme = SessionTheme.forType(WorkoutType.continuous);
    // COLOR_SYSTEM.md § Descanso: "Toda la UI vira a azul" — AppColors.rest.
    const restColor = AppColors.rest;

    return SessionLayout(
      theme: theme,
      // "Fondo que se tiñe de azul de abajo hacia arriba según progreso"
      // + burbujas flotantes — como recuperar el aliento.
      backdrop: _RestFillBackdrop(
        elapsedNotifier: elapsedNotifier,
        totalDuration: Duration(seconds: restDurationSec),
      ),
      header: _buildHeader(context, restColor),
      body: _buildBody(context, restColor),
      footerButton: _buildFooterButton(context, restColor),
    );
  }

  Widget _buildHeader(BuildContext context, Color restColor) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
      child: Row(
        children: [
          Icon(Icons.pause_circle_outline, color: restColor, size: 18),
          const SizedBox(width: 8),
          Text(
            'DESCANSO',
            style: TextStyle(
              fontSize: 12,
              letterSpacing: 2.0,
              fontWeight: FontWeight.w600,
              color: restColor,
            ),
          ),
          const Spacer(),
          Text(
            'Siguiente: serie $nextRepNumber / $totalReps',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(BuildContext context, Color restColor) {
    final totalDuration = Duration(seconds: restDurationSec);

    return Column(
      children: [
        const SizedBox(height: 32),

        // ─── CUENTA ATRÁS HERO ───
        ValueListenableBuilder<Duration>(
          valueListenable: elapsedNotifier,
          builder: (_, elapsed, __) {
            final remaining = totalDuration - elapsed;
            final remainingPositive =
                remaining.isNegative ? Duration.zero : remaining;
            return Column(
              children: [
                TimeWidget(elapsed: remainingPositive, hero: true),
                const SizedBox(height: 8),
                Text(
                  'de ${_formatDuration(totalDuration)} de descanso',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary(context),
                  ),
                ),
              ],
            );
          },
        ),

        const SizedBox(height: 24),

        // ─── BARRA INVERSA ───
        ValueListenableBuilder<Duration>(
          valueListenable: elapsedNotifier,
          builder: (_, elapsed, __) {
            final progress = restDurationSec > 0
                ? 1.0 - (elapsed.inSeconds / restDurationSec)
                : 0.0;
            return SessionProgressBar(
              progress: progress,
              color: restColor,
              height: 8,
            );
          },
        ),

        if (completedSerie != null) ...[
          const SizedBox(height: 20),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ACABAS DE HACER',
                  style: TextStyle(
                    fontSize: 10,
                    letterSpacing: 1.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary(context),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _statCell(context, '${completedSerie!.distanciaM}m', 'distancia'),
                    _verticalDivider(context),
                    _statCell(context, _formatTime(completedSerie!.tiempoSec), 'tiempo'),
                    _verticalDivider(context),
                    _statCell(
                      context,
                      _formatPaceFromSerie(completedSerie!),
                      'pace',
                      color: _paceColor(context, completedSerie!),
                    ),
                    if (completedSerie!.fcMedia != null) ...[
                      _verticalDivider(context),
                      _statCell(context, '${completedSerie!.fcMedia!.toInt()}', 'FC media'),
                    ],
                  ],
                ),
                if (targetPaceMinSec != null && completedSerie!.distanciaM > 0) ...[
                  const SizedBox(height: 12),
                  _paceComparisonBar(context),
                ],
              ],
            ),
          ),
        ],

        const SizedBox(height: 20),

        // ─── FC RECUPERACIÓN ───
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'FC RECUPERACIÓN',
                style: TextStyle(
                  fontSize: 10,
                  letterSpacing: 1.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary(context),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (fcStartedAt != null) ...[
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'AL EMPEZAR',
                          style: TextStyle(
                            fontSize: 9,
                            color: AppColors.textSecondary(context),
                          ),
                        ),
                        Text(
                          '$fcStartedAt bpm',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary(context),
                          ),
                        ),
                      ],
                    ),
                    Icon(
                      Icons.arrow_forward_rounded,
                      color: AppColors.textSecondary(context),
                    ),
                  ],
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'AHORA',
                        style: TextStyle(
                          fontSize: 9,
                          color: AppColors.textSecondary(context),
                        ),
                      ),
                      ValueListenableBuilder<int?>(
                        valueListenable: fcNotifier,
                        builder: (_, bpm, __) {
                          return ValueListenableBuilder<int?>(
                            valueListenable: fcZoneNotifier,
                            builder: (_, zone, __) => FcWidget(
                              bpm: bpm,
                              currentZone: zone,
                              fontSize: 22,
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
              if (fcStartedAt != null) ...[
                const SizedBox(height: 12),
                ValueListenableBuilder<int?>(
                  valueListenable: fcNotifier,
                  builder: (_, bpm, __) {
                    if (bpm == null) return const SizedBox.shrink();
                    final diff = fcStartedAt! - bpm;
                    final color = diff > 15
                        ? AppColors.rpeLow
                        : diff > 5
                            ? AppColors.rpeMid
                            : AppColors.rpeMax;
                    final label = diff > 15
                        ? 'Buena recuperación ✓'
                        : diff > 5
                            ? 'Recuperación lenta'
                            : 'Sin apenas recuperación';
                    return Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        diff > 0 ? '-$diff bpm · $label' : label,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: color,
                        ),
                      ),
                    );
                  },
                ),
              ],
            ],
          ),
        ),

        const SizedBox(height: 16),

        // ─── PRÓXIMA REP ───
        if (nextRepInfo != null)
          Container(
            width: double.infinity,
            padding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: BoxDecoration(
              color: restColor.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: restColor.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                Icon(Icons.directions_run, color: restColor, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'SIGUIENTE',
                        style: TextStyle(
                          fontSize: 10,
                          letterSpacing: 1.5,
                          color: AppColors.textSecondary(context),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        nextRepInfo!,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary(context),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildFooterButton(BuildContext context, Color restColor) {
    // COLOR_SYSTEM.md § Descanso: "Botón Saltar descanso: textSecondary,
    // muy discreto" — el descanso es parte del entreno, no se incentiva saltarlo.
    return SizedBox(
      width: double.infinity,
      child: TextButton(
        onPressed: onSkip,
        style: TextButton.styleFrom(
          foregroundColor: AppColors.textSecondary(context),
          padding: const EdgeInsets.symmetric(vertical: 16),
        ),
        child: const Text(
          'Saltar descanso',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.3,
          ),
        ),
      ),
    );
  }

  String _formatTime(double sec) {
    final m = sec ~/ 60;
    final s = (sec % 60).toInt();
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  String _formatPaceFromSerie(Serie s) {
    if (s.distanciaM == 0) return '—';
    final paceSec = s.tiempoSec / (s.distanciaM / 1000);
    final m = paceSec ~/ 60;
    final sec = (paceSec % 60).round();
    return '$m:${sec.toString().padLeft(2, '0')}';
  }

  Color _paceColor(BuildContext context, Serie s) {
    if (targetPaceMinSec == null || s.distanciaM == 0) {
      return AppColors.textPrimary(context);
    }
    final pace = s.tiempoSec / (s.distanciaM / 1000);
    final max = targetPaceMaxSec ?? targetPaceMinSec! + 15;
    if (pace >= targetPaceMinSec! - 5 && pace <= max + 5) {
      return AppColors.rpeLow;
    }
    return pace < targetPaceMinSec! - 5 ? AppColors.rpeMid : AppColors.rpeMax;
  }

  Widget _statCell(BuildContext context, String value, String label, {Color? color}) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: color ?? AppColors.textPrimary(context),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: AppColors.textSecondary(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _verticalDivider(BuildContext context) {
    return Container(
      width: 1,
      height: 32,
      color: AppColors.borderOf(context).withValues(alpha: 0.3),
    );
  }

  Widget _paceComparisonBar(BuildContext context) {
    final pace = completedSerie!.tiempoSec / (completedSerie!.distanciaM / 1000);
    final inRange = targetPaceMaxSec != null
        ? pace >= targetPaceMinSec! - 5 && pace <= targetPaceMaxSec! + 5
        : pace >= targetPaceMinSec! - 5 && pace <= targetPaceMinSec! + 20;
    final color = inRange ? AppColors.rpeLow : AppColors.rpeMid;
    final msg = inRange ? '✓ En objetivo' : 'Fuera del objetivo';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        msg,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color),
      ),
    );
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds.remainder(60);
    return '$m:${s.toString().padLeft(2, '0')}';
  }
}

/// Fondo del descanso (COLOR_SYSTEM.md § Descanso): un "vaso" de azul que se
/// llena de abajo hacia arriba con el progreso del descanso — recuperar el
/// aliento — con burbujas flotantes sutiles ascendiendo por la zona llena.
class _RestFillBackdrop extends StatefulWidget {
  final ValueListenable<Duration> elapsedNotifier;
  final Duration totalDuration;

  const _RestFillBackdrop({
    required this.elapsedNotifier,
    required this.totalDuration,
  });

  @override
  State<_RestFillBackdrop> createState() => _RestFillBackdropState();
}

class _RestFillBackdropState extends State<_RestFillBackdrop>
    with SingleTickerProviderStateMixin {
  late final AnimationController _bubbles;

  @override
  void initState() {
    super.initState();
    _bubbles = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 7),
    )..repeat();
  }

  @override
  void dispose() {
    _bubbles.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // Spec (light): tinte 0xFFE3F2FD. En dark, mismo gesto con AppColors.rest
    // translúcido para no romper el fondo oscuro.
    final fillColor =
        isDark ? AppColors.rest.withValues(alpha: 0.14) : const Color(0xFFE3F2FD);
    final bubbleBase = const Color(0xFF90CAF9);

    return ValueListenableBuilder<Duration>(
      valueListenable: widget.elapsedNotifier,
      builder: (context, elapsed, _) {
        final totalMs = widget.totalDuration.inMilliseconds;
        final progress = totalMs <= 0
            ? 0.0
            : (elapsed.inMilliseconds / totalMs).clamp(0.0, 1.0);

        return AnimatedBuilder(
          animation: _bubbles,
          builder: (context, _) {
            return LayoutBuilder(
              builder: (context, constraints) {
                final h = constraints.maxHeight;
                final w = constraints.maxWidth;
                final fillTop = h * (1 - progress);

                return Stack(
                  children: [
                    // El agua
                    Positioned(
                      left: 0,
                      right: 0,
                      top: fillTop,
                      bottom: 0,
                      child: ColoredBox(color: fillColor),
                    ),
                    // Burbujas ascendiendo por la zona llena
                    for (var i = 0; i < 6; i++)
                      _bubble(i, w, h, fillTop, bubbleBase, isDark),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  /// Burbuja i: posición y tamaño deterministas por índice, fase desplazada.
  Widget _bubble(
      int i, double w, double h, double fillTop, Color base, bool isDark) {
    final t = (_bubbles.value + i / 6) % 1.0; // fase propia por burbuja
    final size = 8.0 + (i % 3) * 7.0; // 8, 15, 22
    final x = w * (0.12 + (i * 0.15) % 0.76);
    // Asciende desde el fondo hasta la superficie del agua
    final travel = h - fillTop - size;
    if (travel <= 0) return const SizedBox.shrink();
    final y = h - size - travel * t;
    // Se desvanece al acercarse a la superficie (spec: alpha 0.4–0.7)
    final alpha = (0.7 - 0.3 * t) * (isDark ? 0.6 : 1.0);

    return Positioned(
      left: x,
      top: y,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: base.withValues(alpha: alpha),
        ),
      ),
    );
  }
}
