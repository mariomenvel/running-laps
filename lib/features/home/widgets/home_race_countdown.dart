import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:running_laps/core/theme/app_colors.dart';
import 'package:running_laps/core/theme/app_theme.dart';
import 'package:running_laps/features/ai_coach/data/race_goal.dart';
import 'package:running_laps/features/ai_coach/data/race_goal_repository.dart';

/// Línea slim de cuenta atrás en Home. Aparece **solo** cuando hay una
/// competición de prioridad alta próxima (nada de banner permanente).
/// Si no hay ninguna, se colapsa a [SizedBox.shrink].
class HomeRaceCountdown extends StatefulWidget {
  const HomeRaceCountdown({super.key});

  @override
  State<HomeRaceCountdown> createState() => _HomeRaceCountdownState();
}

class _HomeRaceCountdownState extends State<HomeRaceCountdown> {
  Stream<List<RaceGoal>>? _stream;

  @override
  void initState() {
    super.initState();
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      _stream = RaceGoalRepository().streamGoals(uid: uid);
    }
  }

  @override
  Widget build(BuildContext context) {
    final stream = _stream;
    if (stream == null) return const SizedBox.shrink();

    return StreamBuilder<List<RaceGoal>>(
      stream: stream,
      builder: (context, snapshot) {
        final goals = snapshot.data;
        if (goals == null) return const SizedBox.shrink();

        final now = DateTime.now();
        final primary = goals.nextPrimaryFrom(now);
        final date = primary?.parsedDate;
        if (primary == null || date == null) return const SizedBox.shrink();

        final days = DateTime(date.year, date.month, date.day)
            .difference(DateTime(now.year, now.month, now.day))
            .inDays;
        final weeks = days ~/ 7;

        final distLabel = primary.distance == RaceDistance.other &&
                primary.customDistanceM != null
            ? '${(primary.customDistanceM! / 1000).round()}K'
            : primary.distance.label;

        final String countdown;
        if (days <= 0) {
          countdown = 'Hoy es tu $distLabel';
        } else if (days <= 14) {
          countdown = 'Faltan $days ${days == 1 ? 'día' : 'días'} para tu $distLabel';
        } else {
          countdown =
              'Faltan $weeks ${weeks == 1 ? 'semana' : 'semanas'} para tu $distLabel';
        }

        final String? phaseChip = weeks <= 1
            ? 'Semana de carrera'
            : weeks <= 3
                ? 'Taper'
                : null;

        return Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.xl),
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.brand.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14),
              border:
                  Border.all(color: AppColors.brand.withValues(alpha: 0.20)),
            ),
            child: Row(
              children: [
                const Icon(Icons.flag_rounded,
                    color: AppColors.brand, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    countdown,
                    style: AppTypography.body.copyWith(
                      color: AppColors.textPrimary(context),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (phaseChip != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.effort.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      phaseChip,
                      style: AppTypography.small.copyWith(
                        color: AppColors.effort,
                        fontWeight: FontWeight.w700,
                        fontSize: 10,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
