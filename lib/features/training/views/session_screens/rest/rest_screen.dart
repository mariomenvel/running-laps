import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:running_laps/features/templates/data/workout_session.dart';
import 'package:running_laps/core/theme/app_colors.dart';

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
  });

  @override
  Widget build(BuildContext context) {
    final theme = SessionTheme.forType(WorkoutType.continuous);
    const restColor = Color(0xFF4A90A4);

    return SessionLayout(
      theme: theme,
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
              fontWeight: FontWeight.w700,
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

        const SizedBox(height: 40),

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
                            fontWeight: FontWeight.w700,
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
                          fontWeight: FontWeight.w700,
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
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: onSkip,
        style: OutlinedButton.styleFrom(
          foregroundColor: restColor,
          side: BorderSide(color: restColor, width: 2),
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: const Text(
          'SALTAR DESCANSO',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds.remainder(60);
    return '$m:${s.toString().padLeft(2, '0')}';
  }
}
