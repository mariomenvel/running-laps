import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:running_laps/core/theme/app_colors.dart';
import 'package:running_laps/core/utils/app_transitions.dart';
import 'package:running_laps/core/widgets/app_footer.dart';
import 'package:running_laps/core/widgets/app_header.dart';
import 'package:running_laps/features/analytics/views/analytics_hub_screen.dart';
import 'package:running_laps/features/athlete/data/athlete_session_model.dart';
import 'package:running_laps/features/athlete/viewmodels/athlete_hub_viewmodel.dart';
import 'package:running_laps/features/athlete/views/athlete_calendar_view.dart';
import 'package:running_laps/features/training/views/training_start_view.dart';

class AthleteHubView extends StatefulWidget {
  const AthleteHubView({super.key});

  @override
  State<AthleteHubView> createState() => _AthleteHubViewState();
}

class _AthleteHubViewState extends State<AthleteHubView> {
  late final AthleteHubViewModel _vm;
  late final String _uid;

  @override
  void initState() {
    super.initState();
    _uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    _vm = AthleteHubViewModel();
    _vm.init(_uid);
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
              'Modo atleta',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),
          ),
          Expanded(
            child: ValueListenableBuilder<AthleteHubState>(
              valueListenable: _vm.state,
              builder: (context, state, _) {
                if (state.isLoading) {
                  return const Center(
                    child: CircularProgressIndicator(
                      color: AppColors.brandPurple,
                    ),
                  );
                }
                return state.hasAnyData
                    ? _buildContent(context, state)
                    : _buildEmptyState(context);
              },
            ),
          ),
          AppFooter(
            onTap: () => Navigator.push(
              context,
              AppRoute(page: const TrainingStartView()),
            ),
          ),
        ],
      ),
    );
  }

  // ── Content (with data) ────────────────────────────────────────────────────

  Widget _buildContent(BuildContext context, AthleteHubState state) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _WeeklySummaryCard(summary: state.weeklySummary),
          const SizedBox(height: 20),
          if (state.nextSession != null) ...[
            _NextSessionCard(session: state.nextSession!),
            const SizedBox(height: 20),
          ],
          _buildActionButtons(context),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FilledButton.icon(
          onPressed: () => Navigator.push(
            context,
            AppRoute(page: AthleteCalendarView(uid: _uid)),
          ),
          icon: const Icon(Icons.calendar_month_outlined),
          label: const Text(
            'Programar entrenamiento',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          ),
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.brandPurple,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () => Navigator.push(
            context,
            AppRoute(page: const AnalyticsHubScreen()),
          ),
          icon: const Icon(Icons.bar_chart_rounded),
          label: const Text(
            'Ver análisis',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          ),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.brandPurple,
            side: const BorderSide(color: AppColors.brandPurple),
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
      ],
    );
  }

  // ── Empty state ────────────────────────────────────────────────────────────

  Widget _buildEmptyState(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final secondaryColor =
        isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;

    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.directions_run_rounded,
            size: 64,
            color: AppColors.brandPurple.withOpacity(0.4),
          ),
          const SizedBox(height: 24),
          const Text(
            'Bienvenido al Modo atleta',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            'Planifica tus sesiones, define objetivos por bloque y haz un seguimiento real de tu progreso.',
            style: TextStyle(fontSize: 15, color: secondaryColor, height: 1.5),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => Navigator.push(
                context,
                AppRoute(page: AthleteCalendarView(uid: _uid)),
              ),
              icon: const Icon(Icons.add_rounded),
              label: const Text(
                'Programar entrenamiento',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.brandPurple,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── _WeeklySummaryCard ────────────────────────────────────────────────────────

class _WeeklySummaryCard extends StatelessWidget {
  final WeeklySummary summary;

  const _WeeklySummaryCard({required this.summary});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.borderDark : AppColors.borderLight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Esta semana',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: isDark
                  ? AppColors.textSecondaryDark
                  : AppColors.textSecondaryLight,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _SummaryChip(
                value: '${summary.completedCount}/${summary.sessionCount}',
                label: 'Completadas',
                color: AppColors.rpeLow,
              ),
              _SummaryChip(
                value: '${summary.plannedCount}',
                label: 'Pendientes',
                color: AppColors.brandPurple,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SummaryChip extends StatelessWidget {
  final String value;
  final String label;
  final Color color;

  const _SummaryChip({
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Theme.of(context).brightness == Brightness.dark
                ? AppColors.textSecondaryDark
                : AppColors.textSecondaryLight,
          ),
        ),
      ],
    );
  }
}

// ── _NextSessionCard ──────────────────────────────────────────────────────────

class _NextSessionCard extends StatelessWidget {
  final AthleteSession session;

  const _NextSessionCard({required this.session});

  Color _categoryColor(String? c) {
    switch (c) {
      case 'regenerativo':   return AppColors.rest;
      case 'rodaje_base':    return AppColors.rpeLow;
      case 'tempo':
      case 'fartlek':        return AppColors.rpeMid;
      case 'series_largas':
      case 'series_cuestas':
      case 'series_mixtas':  return AppColors.effort;
      case 'series_cortas':
      case 'competicion':    return AppColors.rpeMax;
      default:               return AppColors.brandPurple;
    }
  }

  String _categoryLabel(String? c) {
    switch (c) {
      case 'regenerativo':    return 'Regenerativo';
      case 'rodaje_base':     return 'Rodaje base (Z2)';
      case 'tempo':           return 'Tempo (Z3)';
      case 'fartlek':         return 'Fartlek';
      case 'series_largas':   return 'Series largas';
      case 'series_cortas':   return 'Series cortas';
      case 'series_cuestas':  return 'Series en cuestas';
      case 'series_mixtas':   return 'Series mixtas';
      case 'competicion':     return 'Competición';
      case 'test':            return 'Test';
      case 'gimnasio_fuerza': return 'Gimnasio / fuerza';
      default:                return c ?? 'Próximo entrenamiento';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color  = _categoryColor(session.category);
    final secondaryColor =
        isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Próximo entrenamiento',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: secondaryColor,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _categoryLabel(session.category),
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w600),
                ),
                if (session.time != null)
                  Text(
                    '${session.date}  ·  ${session.time}',
                    style: TextStyle(fontSize: 12, color: secondaryColor),
                  )
                else
                  Text(
                    session.date,
                    style: TextStyle(fontSize: 12, color: secondaryColor),
                  ),
              ],
            ),
          ),
          Icon(Icons.chevron_right, color: color),
        ],
      ),
    );
  }
}
