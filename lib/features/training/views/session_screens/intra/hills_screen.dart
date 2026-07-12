import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:running_laps/features/templates/data/workout_session.dart';
import 'package:running_laps/features/templates/data/workout_block.dart';
import 'package:running_laps/features/templates/data/workout_segment.dart';
import 'package:running_laps/core/theme/app_colors.dart';

import '../shared/session_theme.dart';
import '../shared/session_layout.dart';
import '../shared/metrics/fc_widget.dart';
import '../shared/metrics/time_widget.dart';
import '../shared/metrics/progress_bar.dart';

class HillsScreen extends StatelessWidget {
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

  const HillsScreen({
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

  int? get _targetDurationSec => currentSegment.durationSec;
  int? get _targetZone => currentSegment.target?.zone != null
      ? currentSegment.target!.zone!.index + 1
      : null;
  int? get _targetRpe => currentSegment.target?.rpe;

  @override
  Widget build(BuildContext context) {
    final theme = SessionTheme.forType(WorkoutType.hills);

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
              Icon(Icons.terrain_rounded,
                  color: theme.primary(context), size: 20),
              const SizedBox(width: 8),
              Text(
                'SUBIDA $currentRep / $totalReps',
                style: TextStyle(
                  fontSize: 13,
                  letterSpacing: 2.0,
                  fontWeight: FontWeight.w600,
                  color: theme.primary(context),
                ),
              ),
              const Spacer(),
              if (_targetDurationSec != null)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: theme.primary(context).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${_targetDurationSec}s objetivo',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: theme.primary(context),
                    ),
                  ),
                ),
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

        // ─── TIEMPO HERO ───
        ValueListenableBuilder<Duration>(
          valueListenable: tiempoNotifier,
          builder: (_, t, __) {
            return TimeWidget(
              elapsed: t,
              target: _targetDurationSec != null
                  ? Duration(seconds: _targetDurationSec!)
                  : null,
              hero: true,
            );
          },
        ),

        if (_targetDurationSec != null) ...[
          const SizedBox(height: 16),
          ValueListenableBuilder<Duration>(
            valueListenable: tiempoNotifier,
            builder: (_, t, __) {
              return SessionProgressBar(
                progress: t.inSeconds / _targetDurationSec!,
                color: theme.primary(context),
                height: 8,
              );
            },
          ),
        ],

        const SizedBox(height: 36),

        // ─── FC GRANDE ───
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 22),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: theme.primary(context).withValues(alpha: 0.3),
              width: 2,
            ),
          ),
          child: Column(
            children: [
              Text(
                'FRECUENCIA CARDÍACA',
                style: TextStyle(
                  fontSize: 11,
                  letterSpacing: 2.0,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary(context),
                ),
              ),
              const SizedBox(height: 12),
              ValueListenableBuilder<int?>(
                valueListenable: fcNotifier,
                builder: (_, bpm, __) {
                  return ValueListenableBuilder<int?>(
                    valueListenable: fcZoneNotifier,
                    builder: (_, zone, __) => FcWidget(
                      bpm: bpm,
                      currentZone: zone,
                      targetZone: _targetZone,
                      fontSize: 34,
                    ),
                  );
                },
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // ─── RPE OBJETIVO ───
        if (_targetRpe != null)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              color: AppColors.effortColor(_targetRpe!.toDouble())
                  .withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppColors.effortColor(_targetRpe!.toDouble())
                    .withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.bolt_rounded,
                  color: AppColors.effortColor(_targetRpe!.toDouble()),
                  size: 24,
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'RPE OBJETIVO',
                      style: TextStyle(
                        fontSize: 10,
                        letterSpacing: 1.5,
                        color: AppColors.textSecondary(context),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$_targetRpe / 10',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w600,
                        color:
                            AppColors.effortColor(_targetRpe!.toDouble()),
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                Text(
                  _rpeLabel(_targetRpe!),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.effortColor(_targetRpe!.toDouble()),
                  ),
                ),
              ],
            ),
          ),

        const SizedBox(height: 12),

        Text(
          'En cuesta el pace no es representativo — escucha tu cuerpo',
          style: TextStyle(
            fontSize: 11,
            fontStyle: FontStyle.italic,
            color: AppColors.textSecondary(context),
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  String _rpeLabel(int rpe) {
    if (rpe >= 9) return 'Máximo';
    if (rpe >= 7) return 'Muy fuerte';
    if (rpe >= 5) return 'Moderado';
    return 'Suave';
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
          'COMPLETAR SUBIDA',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }
}
