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

class FartlekScreen extends StatelessWidget {
  final bool isHighIntensity;
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

  const FartlekScreen({
    super.key,
    required this.isHighIntensity,
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
  int? get _targetMinSec => currentSegment.target?.paceMinSecPerKm;
  int? get _targetMaxSec => currentSegment.target?.paceMaxSecPerKm;

  @override
  Widget build(BuildContext context) {
    final baseTheme = SessionTheme.forType(WorkoutType.fartlek);
    final theme = baseTheme.dualMode(isHighIntensity);

    return SessionLayout(
      theme: theme,
      header: _buildHeader(context, theme),
      body: _buildBody(context, theme),
      footerButton: _buildFooterButton(context, theme),
    );
  }

  Widget _buildHeader(BuildContext context, SessionTheme theme) {
    final icon = isHighIntensity
        ? Icons.local_fire_department_rounded
        : Icons.ac_unit_rounded;
    final label = isHighIntensity ? 'RÁPIDO' : 'SUAVE';

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
      child: Row(
        children: [
          Icon(icon, color: theme.primary(context), size: 20),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              letterSpacing: 2.5,
              fontWeight: FontWeight.w800,
              color: theme.primary(context),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: theme.primary(context).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '$currentRep / $totalReps',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: theme.primary(context),
              ),
            ),
          ),
          const Spacer(),
          if (_targetZone != null)
            Text(
              'Objetivo Z$_targetZone',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary(context),
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

        // ─── TIEMPO DEL TRAMO HERO ───
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
          const SizedBox(height: 20),
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

        // ─── FC PROTAGONISTA ───
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
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
                      fontSize: 36,
                    ),
                  );
                },
              ),
              if (_targetZone != null) ...[
                const SizedBox(height: 8),
                Text(
                  isHighIntensity
                      ? 'Sube a Z$_targetZone, mantén intensidad'
                      : 'Baja a Z$_targetZone, recupera',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary(context),
                  ),
                ),
              ],
            ],
          ),
        ),

        const SizedBox(height: 16),

        // ─── Pace + distancia secundarios ───
        if (gpsActivo)
          ValueListenableBuilder<String>(
            valueListenable: paceNotifier,
            builder: (_, pace, __) {
              return Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
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
                          const SizedBox(height: 4),
                          PaceWidget(
                            paceString: pace,
                            targetMinSec: _targetMinSec,
                            targetMaxSec: _targetMaxSec,
                            fontSize: 24,
                            showLabel: false,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'DISTANCIA TRAMO',
                            style: TextStyle(
                              fontSize: 10,
                              letterSpacing: 1.5,
                              color: AppColors.textSecondary(context),
                            ),
                          ),
                          const SizedBox(height: 4),
                          ValueListenableBuilder<double>(
                            valueListenable: distanciaMNotifier,
                            builder: (_, m, __) => Text(
                              '${m.toInt()} m',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary(context),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
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
          'FINALIZAR TRAMO',
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
