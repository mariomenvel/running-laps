import 'package:flutter/material.dart';
import 'package:running_laps/core/theme/app_colors.dart';
import 'package:running_laps/features/ai_coach/data/ai_coach_models.dart';
import 'package:running_laps/features/ai_coach/data/vdot_calculator.dart';

/// Los ritmos que el coach usa ahora mismo, y por qué son esos.
///
/// "Cómo entrena tu coach" ya prometía que los ritmos salen de las marcas
/// reales del atleta y no de tablas genéricas. Esto lo hace comprobable: se ven
/// los ritmos, se ve el VDOT del que salen, y se ve qué lo movió la última vez.
///
/// Sin dependencias de Firebase — la vista le pasa la estimación ya cargada.
class VdotPacesCard extends StatelessWidget {
  const VdotPacesCard({super.key, required this.estimate});

  final AiCoachVdotEstimate estimate;

  static String formatPace(int secPerKm) {
    final m = secPerKm ~/ 60;
    final s = secPerKm % 60;
    return "$m:${s.toString().padLeft(2, '0')}";
  }

  @override
  Widget build(BuildContext context) {
    if (estimate.vdot <= 0) return const SizedBox.shrink();
    final paces = VdotCalculator.pacesFromVdot(estimate.vdot);
    if (paces == null) return const SizedBox.shrink();

    final previous = estimate.previousVdot;
    final delta = previous == null ? 0.0 : estimate.vdot - previous;
    final improved = delta > 0.05;
    final dropped = delta < -0.05;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceOf(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderOf(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Tus ritmos ahora',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary(context),
                  ),
                ),
              ),
              if (improved || dropped)
                _DeltaChip(improved: improved, delta: delta.abs()),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'VDOT ${estimate.vdot.toStringAsFixed(1)}',
            style: TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary(context),
            ),
          ),
          const SizedBox(height: 14),
          _PaceRow(
            label: 'Rodaje suave',
            min: paces.z2MinSecPerKm,
            max: paces.z2MaxSecPerKm,
          ),
          const SizedBox(height: 8),
          _PaceRow(
            label: 'Umbral',
            min: paces.z4MinSecPerKm,
            max: paces.z4MaxSecPerKm,
          ),
          const SizedBox(height: 8),
          _PaceRow(
            label: 'Series',
            min: paces.z5MinSecPerKm,
            max: paces.z5MaxSecPerKm,
          ),
          if (estimate.lastReason.isNotEmpty) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.brand.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                estimate.lastReason,
                style: TextStyle(
                  fontSize: 12,
                  height: 1.4,
                  color: AppColors.textPrimary(context),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _DeltaChip extends StatelessWidget {
  const _DeltaChip({required this.improved, required this.delta});

  final bool improved;
  final double delta;

  @override
  Widget build(BuildContext context) {
    // Bajar el VDOT no es un fracaso: es el coach ajustándose a la realidad.
    // Por eso se pinta en color de descanso, no de error.
    final color = improved ? AppColors.feedbackSuccess : AppColors.rest;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            improved
                ? Icons.arrow_upward_rounded
                : Icons.arrow_downward_rounded,
            size: 11,
            color: color,
          ),
          const SizedBox(width: 3),
          Text(
            delta.toStringAsFixed(1),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _PaceRow extends StatelessWidget {
  const _PaceRow({required this.label, required this.min, required this.max});

  final String label;
  final int min;
  final int max;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary(context),
            ),
          ),
        ),
        Text(
          '${VdotPacesCard.formatPace(min)} – ${VdotPacesCard.formatPace(max)} /km',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            fontFeatures: const [FontFeature.tabularFigures()],
            color: AppColors.textPrimary(context),
          ),
        ),
      ],
    );
  }
}
