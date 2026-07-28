import 'package:flutter/material.dart';
import 'package:running_laps/core/theme/app_colors.dart';
import 'package:running_laps/core/theme/app_theme.dart';
import 'package:running_laps/core/widgets/main_shell.dart';
import 'package:running_laps/features/ai_coach/data/ai_coach_models.dart';
import 'package:running_laps/features/ai_coach/data/ai_coach_repository.dart';

/// Tira de bloque en Home: dónde está el atleta dentro de su mesociclo.
///
/// Es la parte visible de la periodización (docs/AI_COACH_MESOCYCLE.md fase 3).
/// Sin ella, el bloque mejora cómo entrena el sistema pero el atleta no lo
/// percibe — y lo que no se percibe no se paga.
///
/// La semana de descarga se marca en otro color **a propósito**: ver que el
/// descanso está planificado, no improvisado, es lo que más confianza genera.
///
/// Si el atleta no tiene bloque (modo recreativo, o Coach sin estrenar) se
/// colapsa a [SizedBox.shrink] — nada de hueco vacío.
class HomeBlockStrip extends StatefulWidget {
  const HomeBlockStrip({super.key});

  @override
  State<HomeBlockStrip> createState() => _HomeBlockStripState();
}

class _HomeBlockStripState extends State<HomeBlockStrip> {
  late final Future<AiCoachMesocycle?> _future;

  @override
  void initState() {
    super.initState();
    _future = AiCoachRepository().getMesocycle();
  }

  DateTime _mondayOf(DateTime value) {
    final date = DateTime(value.year, value.month, value.day);
    return date.subtract(Duration(days: date.weekday - 1));
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<AiCoachMesocycle?>(
      future: _future,
      builder: (context, snapshot) {
        final block = snapshot.data;
        if (block == null || block.weekPattern.isEmpty) {
          return const SizedBox.shrink();
        }

        final rawIndex = block.weekIndexFor(_mondayOf(DateTime.now()));
        // Un bloque caducado (el planificador aún no ha abierto el siguiente)
        // no se pinta: mejor nada que una posición mentirosa.
        if (rawIndex < 0 || rawIndex >= block.lengthWeeks) {
          return const SizedBox.shrink();
        }

        return Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.xl),
          child: BlockStripCard(block: block, weekIndex: rawIndex),
        );
      },
    );
  }
}

/// Tarjeta del bloque, sin dependencias de Firebase para poder testearla.
class BlockStripCard extends StatelessWidget {
  const BlockStripCard({
    super.key,
    required this.block,
    required this.weekIndex,
  });

  final AiCoachMesocycle block;
  final int weekIndex;

  static bool isEasyWeek(AiCoachWeekType type) =>
      type == AiCoachWeekType.absorb ||
      type == AiCoachWeekType.recovery ||
      type == AiCoachWeekType.taper ||
      type == AiCoachWeekType.restart;

  String get _phaseLabel {
    switch (block.phase) {
      case AiCoachBlockPhase.base:
        return 'BLOQUE BASE';
      case AiCoachBlockPhase.specific:
        return 'BLOQUE ESPECÍFICO';
      case AiCoachBlockPhase.taper:
        return 'AFINANDO';
      case AiCoachBlockPhase.race:
        return 'SEMANA DE CARRERA';
    }
  }

  /// Etiqueta de la semana actual. La de descarga se nombra explícitamente:
  /// que el atleta sepa que bajar de volumen es parte del plan.
  String? get _weekTag {
    switch (block.weekTypeAt(weekIndex)) {
      case AiCoachWeekType.absorb:
      case AiCoachWeekType.recovery:
        return 'Descarga';
      case AiCoachWeekType.taper:
        return 'Taper';
      case AiCoachWeekType.race:
        return 'Competición';
      case AiCoachWeekType.restart:
        return 'Vuelta';
      case AiCoachWeekType.build:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final tag = _weekTag;
    final easyWeek = isEasyWeek(block.weekTypeAt(weekIndex));
    final accent = easyWeek ? AppColors.rest : AppColors.brand;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => MainShell.shellKey.currentState?.navigateTo(17),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: accent.withValues(alpha: 0.20)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '$_phaseLabel · Semana ${weekIndex + 1} de ${block.lengthWeeks}',
                      style: AppTypography.label.copyWith(
                        color: accent,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (tag != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        tag,
                        style: AppTypography.small.copyWith(
                          color: accent,
                          fontWeight: FontWeight.w700,
                          fontSize: 10,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              _WeekDots(
                pattern: block.weekPattern,
                currentIndex: weekIndex,
                accent: accent,
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      block.focus,
                      style: AppTypography.body.copyWith(
                        color: AppColors.textPrimary(context),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 18,
                    color: AppColors.textSecondary(context),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Puntos de progreso del bloque. Las semanas suaves se dibujan huecas y en
/// color de descanso aunque ya hayan pasado — se leen como "respiro
/// planificado", no como "semana pendiente".
class _WeekDots extends StatelessWidget {
  const _WeekDots({
    required this.pattern,
    required this.currentIndex,
    required this.accent,
  });

  final List<AiCoachWeekType> pattern;
  final int currentIndex;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final muted = AppColors.textSecondary(context).withValues(alpha: 0.35);

    return Row(
      children: [
        for (var i = 0; i < pattern.length; i++) ...[
          if (i > 0)
            Container(
              width: 14,
              height: 2,
              color: i <= currentIndex
                  ? accent.withValues(alpha: 0.45)
                  : muted.withValues(alpha: 0.4),
            ),
          _Dot(
            done: i < currentIndex,
            current: i == currentIndex,
            easy: BlockStripCard.isEasyWeek(pattern[i]),
            accent: accent,
            muted: muted,
          ),
        ],
      ],
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({
    required this.done,
    required this.current,
    required this.easy,
    required this.accent,
    required this.muted,
  });

  final bool done;
  final bool current;
  final bool easy;
  final Color accent;
  final Color muted;

  @override
  Widget build(BuildContext context) {
    final color = easy ? AppColors.rest : accent;
    final filled = done || current;
    final size = current ? 12.0 : 9.0;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: filled ? color : Colors.transparent,
        border: Border.all(
          color: filled ? color : muted,
          width: current ? 2.5 : 1.5,
        ),
      ),
    );
  }
}
