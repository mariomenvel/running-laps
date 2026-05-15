import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:running_laps/features/templates/data/workout_session.dart';
import 'package:running_laps/features/templates/data/workout_block.dart';
import 'package:running_laps/features/templates/data/workout_segment.dart';
import 'package:running_laps/core/theme/app_colors.dart';

import '../shared/session_theme.dart';
import '../shared/session_layout.dart';
import '../shared/metrics/pace_widget.dart';
import '../shared/metrics/fc_widget.dart';
import '../shared/metrics/time_widget.dart';
import '../shared/metrics/progress_bar.dart';

class IntervalScreen extends StatelessWidget {
  final WorkoutSession session;
  final WorkoutBlock currentBlock;
  final WorkoutSegment currentSegment;
  final int currentRep;
  final int totalReps;
  final bool gpsActivo;
  final int? fcMax;
  final VoidCallback onFinish;
  final ValueListenable<double> distanciaMNotifier;
  final ValueListenable<String> paceNotifier;
  final ValueListenable<Duration> tiempoNotifier;
  final ValueListenable<int?> fcNotifier;
  final ValueListenable<int?> fcZoneNotifier;

  const IntervalScreen({
    super.key,
    required this.session,
    required this.currentBlock,
    required this.currentSegment,
    required this.currentRep,
    required this.totalReps,
    required this.gpsActivo,
    required this.fcMax,
    required this.onFinish,
    required this.distanciaMNotifier,
    required this.paceNotifier,
    required this.tiempoNotifier,
    required this.fcNotifier,
    required this.fcZoneNotifier,
  });

  double? get _targetDistanceM => currentSegment.distanceM?.toDouble();
  int? get _targetDurationSec => currentSegment.durationSec;
  int? get _targetMinSec => currentSegment.target?.paceMinSecPerKm;
  int? get _targetMaxSec => currentSegment.target?.paceMaxSecPerKm;
  int? get _targetZone => currentSegment.target?.zone != null
      ? currentSegment.target!.zone!.index + 1
      : null;

  String _targetPaceLabel() {
    if (_targetMinSec == null) return '—';
    final minStr =
        '${_targetMinSec! ~/ 60}:${(_targetMinSec! % 60).toString().padLeft(2, '0')}';
    if (_targetMaxSec == null) return '$minStr /km';
    final maxStr =
        '${_targetMaxSec! ~/ 60}:${(_targetMaxSec! % 60).toString().padLeft(2, '0')}';
    return '$minStr – $maxStr /km';
  }

  @override
  Widget build(BuildContext context) {
    final theme = SessionTheme.forType(WorkoutType.intervals);

    return SessionLayout(
      theme: theme,
      header: _buildHeader(context, theme),
      body: _buildBody(context, theme),
      footerButton: _buildFooterButton(context, theme),
    );
  }

  Widget _buildHeader(BuildContext context, SessionTheme theme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: theme.primary(context),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'SERIE $currentRep / $totalReps',
                style: TextStyle(
                  fontSize: 12,
                  letterSpacing: 2.0,
                  fontWeight: FontWeight.w700,
                  color: theme.primary(context),
                ),
              ),
              const Spacer(),
              if (_targetDistanceM != null)
                Text(
                  '${_targetDistanceM!.toInt()}m',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary(context),
                  ),
                ),
              if (_targetMinSec != null) ...[
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: theme.primary(context).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _targetPaceLabel(),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: theme.primary(context),
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          _buildSeriesIndicator(context, theme),
        ],
      ),
    );
  }

  Widget _buildSeriesIndicator(BuildContext context, SessionTheme theme) {
    return Row(
      children: List.generate(totalReps, (i) {
        final isCompleted = i < currentRep - 1;
        final isCurrent = i == currentRep - 1;
        return Expanded(
          child: Container(
            margin: EdgeInsets.only(right: i < totalReps - 1 ? 4 : 0),
            height: 4,
            decoration: BoxDecoration(
              color: isCompleted
                  ? theme.primary(context)
                  : isCurrent
                      ? theme.primary(context).withValues(alpha: 0.5)
                      : AppColors.borderOf(context).withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildBody(BuildContext context, SessionTheme theme) {
    return Column(
      children: [
        const SizedBox(height: 24),

        // ─── TIEMPO HERO con centésimas ───
        ValueListenableBuilder<Duration>(
          valueListenable: tiempoNotifier,
          builder: (_, t, __) {
            return TimeWidget(
              elapsed: t,
              target: _targetDurationSec != null
                  ? Duration(seconds: _targetDurationSec!)
                  : null,
              hero: true,
              showCentiseconds: true,
            );
          },
        ),

        // ─── PROGRESO por distancia ───
        if (_targetDistanceM != null) ...[
          const SizedBox(height: 20),
          ValueListenableBuilder<double>(
            valueListenable: distanciaMNotifier,
            builder: (_, meters, __) {
              return SessionProgressBar(
                progress: meters / _targetDistanceM!,
                color: theme.primary(context),
                height: 8,
              );
            },
          ),
          const SizedBox(height: 4),
          ValueListenableBuilder<double>(
            valueListenable: distanciaMNotifier,
            builder: (_, meters, __) {
              return Text(
                '${meters.toInt()}m / ${_targetDistanceM!.toInt()}m',
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary(context),
                ),
              );
            },
          ),
        ],

        const SizedBox(height: 32),

        // ─── RITMO ACTUAL ───
        if (gpsActivo)
          ValueListenableBuilder<String>(
            valueListenable: paceNotifier,
            builder: (_, pace, __) {
              return Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 24, vertical: 18),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'RITMO',
                          style: TextStyle(
                            fontSize: 10,
                            letterSpacing: 1.5,
                            color: AppColors.textSecondary(context),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Actual',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary(context),
                          ),
                        ),
                      ],
                    ),
                    PaceWidget(
                      paceString: pace,
                      targetMinSec: _targetMinSec,
                      targetMaxSec: _targetMaxSec,
                      fontSize: 40,
                    ),
                  ],
                ),
              );
            },
          ),

        const SizedBox(height: 16),

        // ─── FC ───
        Container(
          width: double.infinity,
          padding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Text(
                'FC',
                style: TextStyle(
                  fontSize: 10,
                  letterSpacing: 1.5,
                  color: AppColors.textSecondary(context),
                ),
              ),
              const Spacer(),
              ValueListenableBuilder<int?>(
                valueListenable: fcNotifier,
                builder: (_, bpm, __) {
                  return ValueListenableBuilder<int?>(
                    valueListenable: fcZoneNotifier,
                    builder: (_, zone, __) => FcWidget(
                      bpm: bpm,
                      currentZone: zone,
                      targetZone: _targetZone,
                      fontSize: 22,
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFooterButton(BuildContext context, SessionTheme theme) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onFinish,
        style: ElevatedButton.styleFrom(
          backgroundColor: theme.primary(context),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 0,
        ),
        child: const Text(
          'FINALIZAR SERIE',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }
}
