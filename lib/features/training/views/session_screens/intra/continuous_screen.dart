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

class ContinuousScreen extends StatelessWidget {
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

  const ContinuousScreen({
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

  String _blockLabel() {
    switch (currentBlock.role) {
      case BlockRole.warmup:
        return 'CALENTAMIENTO';
      case BlockRole.cooldown:
        return 'VUELTA A LA CALMA';
      case BlockRole.main:
        return 'RODAJE';
      case BlockRole.custom:
        return currentBlock.label?.toUpperCase() ?? 'BLOQUE';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = SessionTheme.forType(WorkoutType.continuous);

    return SessionLayout(
      theme: theme,
      header: _buildHeader(context, theme),
      body: _buildBody(context, theme),
      footerButton: _buildFooterButton(context, theme),
    );
  }

  Widget _buildHeader(BuildContext context, SessionTheme theme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Row(
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
            _blockLabel(),
            style: TextStyle(
              fontSize: 12,
              letterSpacing: 2.0,
              fontWeight: FontWeight.w600,
              color: theme.primary(context),
            ),
          ),
          if (_targetDistanceM != null) ...[
            const Spacer(),
            Text(
              '${(_targetDistanceM! / 1000).toStringAsFixed(1)} km obj.',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary(context),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBody(BuildContext context, SessionTheme theme) {
    return Column(
      children: [
        const SizedBox(height: 32),

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

        // ─── BARRA DE PROGRESO ───
        if (_targetDistanceM != null) ...[
          const SizedBox(height: 16),
          ValueListenableBuilder<double>(
            valueListenable: distanciaMNotifier,
            builder: (_, meters, __) {
              return SessionProgressBar(
                progress: meters / _targetDistanceM!,
                color: theme.primary(context),
                height: 6,
                showPercentage: true,
              );
            },
          ),
        ],

        const SizedBox(height: 40),

        // ─── RITMO ───
        if (gpsActivo)
          ValueListenableBuilder<String>(
            valueListenable: paceNotifier,
            builder: (_, pace, __) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
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
                        if (_targetMinSec != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            'Objetivo: ${_targetMinSec! ~/ 60}:${(_targetMinSec! % 60).toString().padLeft(2, '0')}'
                            '${_targetMaxSec != null ? '–${_targetMaxSec! ~/ 60}:${(_targetMaxSec! % 60).toString().padLeft(2, '0')}' : ''}',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.textSecondary(context),
                            ),
                          ),
                        ],
                      ],
                    ),
                    PaceWidget(
                      paceString: pace,
                      targetMinSec: _targetMinSec,
                      targetMaxSec: _targetMaxSec,
                      fontSize: 36,
                    ),
                  ],
                ),
              );
            },
          ),

        const SizedBox(height: 16),

        // ─── TIEMPO + FC ───
        Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(16),
                ),
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
                      builder: (_, t, __) => TimeWidget(elapsed: t, fontSize: 22),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'FC',
                      style: TextStyle(
                        fontSize: 10,
                        letterSpacing: 1.5,
                        color: AppColors.textSecondary(context),
                      ),
                    ),
                    const SizedBox(height: 4),
                    ValueListenableBuilder<int?>(
                      valueListenable: fcNotifier,
                      builder: (_, bpm, __) {
                        return ValueListenableBuilder<int?>(
                          valueListenable: fcZoneNotifier,
                          builder: (_, zone, __) => FcWidget(
                            bpm: bpm,
                            currentZone: zone,
                            targetZone: currentSegment.target?.zone != null
                                ? currentSegment.target!.zone!.index + 1
                                : null,
                            fontSize: 22,
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
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
        child: Text(
          _finishButtonLabel(),
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }

  String _finishButtonLabel() {
    switch (currentBlock.role) {
      case BlockRole.warmup:
        return 'FINALIZAR CALENTAMIENTO';
      case BlockRole.cooldown:
        return 'FINALIZAR VUELTA A LA CALMA';
      default:
        return 'FINALIZAR RODAJE';
    }
  }
}
