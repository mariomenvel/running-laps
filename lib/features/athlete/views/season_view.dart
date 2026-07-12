import 'dart:math' show max;

import 'package:flutter/material.dart';
import 'package:running_laps/core/services/training_load_service.dart';
import 'package:running_laps/core/theme/app_colors.dart';
import 'package:running_laps/core/widgets/app_header.dart';
import 'package:running_laps/core/utils/app_transitions.dart';
import 'package:running_laps/features/athlete/data/athlete_session_model.dart';
import 'package:running_laps/features/athlete/viewmodels/season_viewmodel.dart';
import 'package:running_laps/features/athlete/views/athlete_hub_view.dart';

class SeasonView extends StatefulWidget {
  final String uid;

  const SeasonView({super.key, required this.uid});

  @override
  State<SeasonView> createState() => _SeasonViewState();
}

class _SeasonViewState extends State<SeasonView> {
  late final SeasonViewModel _vm;

  @override
  void initState() {
    super.initState();
    _vm = SeasonViewModel();
    _vm.init(widget.uid);
  }

  @override
  void dispose() {
    _vm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          AppHeader(
            title: const Text(
              'Temporada',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(
            child: ValueListenableBuilder<SeasonViewModelState>(
              valueListenable: _vm.state,
              builder: (context, state, _) {
                if (state.isLoading) {
                  return const Center(
                    child: CircularProgressIndicator(color: AppColors.brand),
                  );
                }
                if (state.errorMessage != null) {
                  return Center(
                    child: Text(
                      state.errorMessage!,
                      style: const TextStyle(color: AppColors.paceSlow),
                    ),
                  );
                }
                return SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildLoadChart(context, state),
                      const SizedBox(height: 32),
                      _buildUpcomingRaces(context, state),
                      const SizedBox(height: 32),
                      _buildStats(context, state),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ── Sección 1: Carga semanal ───────────────────────────────────────────────

  Widget _buildLoadChart(BuildContext context, SeasonViewModelState state) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final secondary = isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;
    final weeks = state.weeklyLoads;

    const barMaxHeight = 120.0;
    const barWidth     = 28.0;
    const barMinHeight = 4.0;

    final maxLoad = weeks.fold<double>(
      0,
      (prev, w) => max(prev, w.loadScore),
    );

    final now          = DateTime.now();
    final currentMonday = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: now.weekday - 1));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Carga semanal',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 2),
        Text(
          'Últimas 16 semanas',
          style: TextStyle(fontSize: 13, color: secondary),
        ),
        const SizedBox(height: 16),

        // Scrollable bar chart
        SizedBox(
          height: barMaxHeight + 28,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: weeks.asMap().entries.map((entry) {
                final i    = entry.key;
                final week = entry.value;

                final isCurrentWeek = week.weekStart == currentMonday;

                final double barH = maxLoad > 0
                    ? max(barMinHeight, (week.loadScore / maxLoad) * barMaxHeight)
                    : barMinHeight;

                final Color barColor;
                if (week.hasRace) {
                  barColor = AppColors.rpeMax;
                } else if (week.isRaceWeek) {
                  barColor = AppColors.effort;
                } else {
                  final avg = weeks.isEmpty
                      ? 0.0
                      : weeks.fold<double>(0, (s, w) => s + w.loadScore) /
                          weeks.length;
                  barColor = (avg > 0 && week.loadScore > avg * 1.3)
                      ? AppColors.rpeMid
                      : AppColors.brand;
                }

                final String label = isCurrentWeek
                    ? 'HOY'
                    : 'S${i + 1}';

                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Container(
                        width:              barWidth,
                        height:             barH,
                        decoration: BoxDecoration(
                          color:        barColor
                              .withValues(alpha: isCurrentWeek ? 1.0 : 0.85),
                          borderRadius: BorderRadius.circular(4),
                          border: isCurrentWeek
                              ? Border.all(color: barColor, width: 2)
                              : null,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        label,
                        style: TextStyle(
                          fontSize:   isCurrentWeek ? 10 : 9,
                          fontWeight: isCurrentWeek
                              ? FontWeight.w600
                              : FontWeight.w400,
                          color: isCurrentWeek ? barColor : secondary,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ),

        const SizedBox(height: 12),

        // Leyenda
        Wrap(
          spacing: 16,
          runSpacing: 6,
          children: [
            _LegendDot(color: AppColors.rpeMax,       label: 'Competición'),
            _LegendDot(color: AppColors.effort,       label: 'Taper'),
            _LegendDot(color: AppColors.rpeMid,       label: 'Carga alta'),
            _LegendDot(color: AppColors.brand,  label: 'Normal'),
          ],
        ),

        const SizedBox(height: 8),

        const Text(
          'Carga estimada basada en distancia y RPE.\nMejora con pulsómetro conectado.',
          style: TextStyle(fontSize: 11, color: Color(0xFFAAAAAA), height: 1.4),
        ),
      ],
    );
  }

  // ── Sección 2: Próximas competiciones ─────────────────────────────────────

  Widget _buildUpcomingRaces(BuildContext context, SeasonViewModelState state) {
    final isDark    = Theme.of(context).brightness == Brightness.dark;
    final secondary = isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Próximas competiciones',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        if (state.upcomingRaces.isEmpty) ...[
          Text(
            'No tienes competiciones planificadas',
            style: TextStyle(fontSize: 14, color: secondary),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => Navigator.push(
                context,
                AppRoute(page: AthleteHubView(uid: widget.uid)),
              ),
              icon:  const Icon(Icons.add_rounded),
              label: const Text('Programar competición'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.brand,
                side: const BorderSide(color: AppColors.brand),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ] else
          ...state.upcomingRaces.map(
            (r) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _RaceCard(race: r),
            ),
          ),
      ],
    );
  }

  // ── Sección 3: Estadísticas del período ───────────────────────────────────

  Widget _buildStats(BuildContext context, SeasonViewModelState state) {
    final isDark    = Theme.of(context).brightness == Brightness.dark;
    final weeks     = state.weeklyLoads;

    final totalKm      = weeks.fold<double>(0, (s, w) => s + w.totalKm);
    final totalSess    = weeks.fold<int>(0,    (s, w) => s + w.sessionCount);
    final totalLoad    = weeks.fold<double>(0, (s, w) => s + w.loadScore);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Período (16 semanas)',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _StatChip(
              value: '${totalKm.toStringAsFixed(1)} km',
              label: 'Total km',
              color: AppColors.brand,
              isDark: isDark,
            )),
            const SizedBox(width: 10),
            Expanded(child: _StatChip(
              value: '$totalSess',
              label: 'Sesiones',
              color: AppColors.rpeLow,
              isDark: isDark,
            )),
            const SizedBox(width: 10),
            Expanded(child: _StatChip(
              value: '${totalLoad.round()}',
              label: 'Carga total',
              color: AppColors.rpeMid,
              isDark: isDark,
            )),
          ],
        ),
      ],
    );
  }
}

// ── _RaceCard ─────────────────────────────────────────────────────────────────

class _RaceCard extends StatelessWidget {
  final AthleteSession race;

  const _RaceCard({required this.race});

  String _distanceLabel(int? m) {
    if (m == null)  return '';
    if (m == 5000)  return '5K';
    if (m == 10000) return '10K';
    if (m == 21097) return 'Media maratón';
    if (m == 42195) return 'Maratón';
    return '${(m / 1000).toStringAsFixed(1)} km';
  }

  @override
  Widget build(BuildContext context) {
    final days         = TrainingLoadService.instance.daysUntil(race, DateTime.now());
    final distLabel    = _distanceLabel(race.raceDistanceM);

    final String badgeLabel;
    final Color  badgeColor;
    if (days == 0) {
      badgeLabel = '¡Hoy!';
      badgeColor = AppColors.rpeMax;
    } else if (days <= 7) {
      badgeLabel = 'En $days días';
      badgeColor = AppColors.rpeMax;
    } else if (days <= 21) {
      badgeLabel = 'En $days días';
      badgeColor = AppColors.effort;
    } else {
      badgeLabel = 'En $days días';
      badgeColor = AppColors.textSecondaryLight;
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color:        AppColors.effortSurfaceConst,
        borderRadius: BorderRadius.circular(14),
        border:       Border.all(color: AppColors.effortBorder),
      ),
      child: Row(
        children: [
          const Icon(Icons.flag_rounded, color: AppColors.rpeMax, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  race.raceName?.isNotEmpty == true
                      ? race.raceName!
                      : 'Competición',
                  style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white,
                  ),
                ),
                Text(
                  distLabel.isNotEmpty
                      ? '${race.date}  ·  $distLabel'
                      : race.date,
                  style: const TextStyle(fontSize: 12, color: Color(0xFFCCCCCC)),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color:        badgeColor.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(8),
              border:       Border.all(color: badgeColor.withValues(alpha: 0.4)),
            ),
            child: Text(
              badgeLabel,
              style: TextStyle(
                fontSize: 12, fontWeight: FontWeight.w600, color: badgeColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── _LegendDot ────────────────────────────────────────────────────────────────

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10, height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
          ),
        ),
      ],
    );
  }
}

// ── _StatChip ─────────────────────────────────────────────────────────────────

class _StatChip extends StatelessWidget {
  final String value;
  final String label;
  final Color  color;
  final bool   isDark;

  const _StatChip({
    required this.value,
    required this.label,
    required this.color,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
      decoration: BoxDecoration(
        color:        AppColors.surfaceOf(context),
        borderRadius: BorderRadius.circular(14),
        border:       Border.all(
          color: AppColors.borderOf(context),
        ),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize:   18,
              fontWeight: FontWeight.w800,
              color:      color,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
