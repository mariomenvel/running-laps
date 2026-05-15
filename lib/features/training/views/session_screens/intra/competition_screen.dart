import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:running_laps/features/templates/data/workout_session.dart';
import 'package:running_laps/features/templates/data/workout_block.dart';
import 'package:running_laps/features/templates/data/workout_segment.dart';
import 'package:running_laps/core/theme/app_colors.dart';

import '../shared/session_theme.dart';
import '../shared/session_layout.dart';
import '../shared/metrics/distance_widget.dart';
import '../shared/metrics/pace_widget.dart';
import '../shared/metrics/fc_widget.dart';
import '../shared/metrics/time_widget.dart';
import '../shared/metrics/progress_bar.dart';

class CompetitionScreen extends StatelessWidget {
  final WorkoutSession session;
  final WorkoutBlock currentBlock;
  final WorkoutSegment currentSegment;
  final bool gpsActivo;
  final int? fcMax;
  final VoidCallback onFinish;
  final ValueListenable<double> distanciaMNotifier;
  final ValueListenable<String> paceNotifier;
  final ValueListenable<Duration> tiempoNotifier;
  final ValueListenable<int?> fcNotifier;
  final ValueListenable<int?> fcZoneNotifier;

  const CompetitionScreen({
    super.key,
    required this.session,
    required this.currentBlock,
    required this.currentSegment,
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
  int? get _targetMinSec => currentSegment.target?.paceMinSecPerKm;
  int? get _targetMaxSec => currentSegment.target?.paceMaxSecPerKm;

  String? _targetTimeLabel() {
    if (_targetDistanceM == null || _targetMinSec == null) return null;
    final totalSec = (_targetDistanceM! / 1000 * _targetMinSec!).round();
    final h = totalSec ~/ 3600;
    final m = (totalSec % 3600) ~/ 60;
    final s = totalSec % 60;
    if (h > 0) {
      return '${h}h ${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  String _projectedTime(double metersDone, Duration elapsed) {
    if (_targetDistanceM == null || metersDone <= 0) return '—';
    final secPerMeter = elapsed.inMilliseconds / 1000 / metersDone;
    final totalSec = (secPerMeter * _targetDistanceM!).round();
    final h = totalSec ~/ 3600;
    final m = (totalSec % 3600) ~/ 60;
    final s = totalSec % 60;
    if (h > 0) {
      return '${h}h ${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  Color _projectionColor(
      double metersDone, Duration elapsed, BuildContext context) {
    if (_targetDistanceM == null || _targetMinSec == null || metersDone <= 0) {
      return AppColors.textPrimary(context);
    }
    final secPerMeter = elapsed.inMilliseconds / 1000 / metersDone;
    final projectedTotal = secPerMeter * _targetDistanceM!;
    final targetTotal = _targetDistanceM! / 1000 * _targetMinSec!;
    final diff = projectedTotal - targetTotal;
    if (diff < 10) return AppColors.rpeLow;
    if (diff < 30) return AppColors.rpeMid;
    return AppColors.rpeMax;
  }

  @override
  Widget build(BuildContext context) {
    final theme = SessionTheme.forType(WorkoutType.competition);

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
      child: Row(
        children: [
          Icon(Icons.emoji_events_rounded,
              color: theme.primary(context), size: 20),
          const SizedBox(width: 8),
          Text(
            'COMPETICIÓN',
            style: TextStyle(
              fontSize: 13,
              letterSpacing: 2.5,
              fontWeight: FontWeight.w800,
              color: theme.primary(context),
            ),
          ),
          const Spacer(),
          if (_targetDistanceM != null && _targetTimeLabel() != null)
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: theme.primary(context).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '${(_targetDistanceM! / 1000).toStringAsFixed(1)}K · ${_targetTimeLabel()}',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: theme.primary(context),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBody(BuildContext context, SessionTheme theme) {
    return Column(
      children: [
        const SizedBox(height: 24),

        // ─── DISTANCIA HERO ───
        ValueListenableBuilder<double>(
          valueListenable: distanciaMNotifier,
          builder: (_, meters, __) {
            return DistanceWidget(
              meters: meters,
              targetMeters: _targetDistanceM,
              hero: true,
            );
          },
        ),

        if (_targetDistanceM != null) ...[
          const SizedBox(height: 16),
          ValueListenableBuilder<double>(
            valueListenable: distanciaMNotifier,
            builder: (_, meters, __) {
              return SessionProgressBar(
                progress: meters / _targetDistanceM!,
                color: theme.primary(context),
                height: 8,
                showPercentage: true,
              );
            },
          ),
        ],

        const SizedBox(height: 36),

        // ─── TIEMPO ACTUAL + PROYECCIÓN ───
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: theme.primary(context).withValues(alpha: 0.4),
              width: 1.5,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'TIEMPO',
                      style: TextStyle(
                        fontSize: 10,
                        letterSpacing: 1.5,
                        color: AppColors.textSecondary(context),
                      ),
                    ),
                    const SizedBox(height: 4),
                    ValueListenableBuilder<Duration>(
                      valueListenable: tiempoNotifier,
                      builder: (_, t, __) =>
                          TimeWidget(elapsed: t, fontSize: 26),
                    ),
                  ],
                ),
              ),
              if (_targetDistanceM != null)
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'PROYECCIÓN',
                        style: TextStyle(
                          fontSize: 10,
                          letterSpacing: 1.5,
                          color: AppColors.textSecondary(context),
                        ),
                      ),
                      const SizedBox(height: 4),
                      ValueListenableBuilder<double>(
                        valueListenable: distanciaMNotifier,
                        builder: (_, meters, __) {
                          return ValueListenableBuilder<Duration>(
                            valueListenable: tiempoNotifier,
                            builder: (_, t, __) => Text(
                              _projectedTime(meters, t),
                              style: TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.w800,
                                color: _projectionColor(meters, t, context),
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // ─── PACE actual vs objetivo ───
        if (gpsActivo)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'PACE',
                      style: TextStyle(
                        fontSize: 10,
                        letterSpacing: 1.5,
                        color: AppColors.textSecondary(context),
                      ),
                    ),
                    if (_targetMinSec != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        'Obj. ${_targetMinSec! ~/ 60}:${(_targetMinSec! % 60).toString().padLeft(2, '0')}/km',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary(context),
                        ),
                      ),
                    ],
                  ],
                ),
                ValueListenableBuilder<String>(
                  valueListenable: paceNotifier,
                  builder: (_, pace, __) => PaceWidget(
                    paceString: pace,
                    targetMinSec: _targetMinSec,
                    targetMaxSec: _targetMaxSec,
                    fontSize: 28,
                  ),
                ),
              ],
            ),
          ),

        const SizedBox(height: 12),

        // ─── FC ───
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
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
          foregroundColor: Colors.black,
          padding: const EdgeInsets.symmetric(vertical: 18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 0,
        ),
        child: const Text(
          'TERMINÉ LA CARRERA',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.0,
          ),
        ),
      ),
    );
  }
}
