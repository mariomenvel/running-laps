import 'package:flutter/material.dart';
import 'package:running_laps/core/theme/app_colors.dart';
import 'package:running_laps/core/utils/app_transitions.dart';
import 'package:running_laps/core/widgets/app_footer.dart';
import 'package:running_laps/core/widgets/app_header.dart';
import 'package:running_laps/core/widgets/standard_table_calendar.dart';
import 'package:running_laps/features/calendar/data/planned_session_model.dart';
import 'package:running_laps/features/calendar/viewmodels/calendar_viewmodel.dart';
import 'package:running_laps/features/calendar/views/planned_session_editor_view.dart';
import 'package:running_laps/features/training/views/training_start_view.dart';
import 'package:table_calendar/table_calendar.dart';

class CalendarView extends StatefulWidget {
  final String uid;

  const CalendarView({super.key, required this.uid});

  @override
  State<CalendarView> createState() => _CalendarViewState();
}

class _CalendarViewState extends State<CalendarView> {
  late final CalendarViewModel _viewModel;

  @override
  void initState() {
    super.initState();
    _viewModel = CalendarViewModel();
    _viewModel.init(widget.uid);
  }

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          AppHeader(
            title: const Text(
              'Calendario',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),
          ),
          Expanded(
            child: ValueListenableBuilder<CalendarViewModelState>(
              valueListenable: _viewModel.state,
              builder: (context, state, _) {
                return Column(
                  children: [
                    // 1 ── Weekly summary ──────────────────────────────────
                    _WeekSummaryHeader(selectedDay: state.selectedDay),

                    // 2 ── Calendar ────────────────────────────────────────
                    StandardTableCalendar<PlannedSession>(
                      lastDay: DateTime.now().add(const Duration(days: 365)),
                      focusedDay: state.focusedMonth,
                      selectedDay: state.selectedDay,
                      eventLoader: _viewModel.sessionsForDay,
                      onDaySelected: (selected, focused) =>
                          _viewModel.selectDay(selected),
                      onPageChanged: _viewModel.onPageChanged,
                      calendarBuilders: CalendarBuilders<PlannedSession>(
                        markerBuilder: (context, day, events) {
                          if (events.isEmpty) return null;
                          return _buildSessionMarkers(context, events);
                        },
                      ),
                    ),

                    // 3 ── Day detail ──────────────────────────────────────
                    Expanded(
                      child: _DayDetailPanel(
                        uid: widget.uid,
                        selectedDay: state.selectedDay,
                        sessions: state.selectedDay != null
                            ? _viewModel.sessionsForDay(state.selectedDay!)
                            : [],
                      ),
                    ),
                  ],
                );
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

  Widget _buildSessionMarkers(
      BuildContext context, List<PlannedSession> sessions) {
    const int maxDots = 3;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final brandColor =
        isDark ? AppColors.brandPurpleLight : AppColors.brandPurple;

    final displayCount =
        sessions.length > maxDots ? maxDots - 1 : sessions.length;
    final markers = <Widget>[];

    for (int i = 0; i < displayCount; i++) {
      final color = _categoryColor(sessions[i].category);
      markers.add(
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                  color: color.withOpacity(0.4),
                  blurRadius: 2,
                  offset: const Offset(0, 1)),
            ],
          ),
        ),
      );
      if (i < displayCount - 1) markers.add(const SizedBox(width: 3));
    }

    if (sessions.length > maxDots) {
      markers.add(const SizedBox(width: 2));
      markers.add(
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
          decoration: BoxDecoration(
            color: AppColors.brandPurple.withOpacity(0.15),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            '+${sessions.length - displayCount}',
            style: TextStyle(
              fontSize: 8,
              fontWeight: FontWeight.bold,
              color: brandColor.withOpacity(0.8),
            ),
          ),
        ),
      );
    }

    return Positioned(
      bottom: 2,
      child: Row(mainAxisSize: MainAxisSize.min, children: markers),
    );
  }
}

// ── Category → Color ──────────────────────────────────────────────────────────

Color _categoryColor(String category) {
  switch (category) {
    case 'regenerativo':
      return AppColors.rest;
    case 'rodaje_base':
      return AppColors.rpeLow;
    case 'tempo':
    case 'fartlek':
      return AppColors.rpeMid;
    case 'series_largas':
    case 'series_cuestas':
    case 'series_mixtas':
      return AppColors.effort;
    case 'series_cortas':
    case 'competicion':
      return AppColors.rpeMax;
    default:
      return AppColors.brandPurple;
  }
}

// ── _WeekSummaryHeader ────────────────────────────────────────────────────────

class _WeekSummaryHeader extends StatelessWidget {
  final DateTime? selectedDay;

  const _WeekSummaryHeader({this.selectedDay});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor =
        isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _SummaryChip(label: '— km',   icon: Icons.straighten,      color: AppColors.brandPurple, textColor: textColor),
          _SummaryChip(label: '— %',    icon: Icons.monitor_heart,   color: AppColors.rpeLow,      textColor: textColor),
          _SummaryChip(label: '—/—',    icon: Icons.check_circle_outline, color: AppColors.effort, textColor: textColor),
        ],
      ),
    );
  }
}

class _SummaryChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final Color textColor;

  const _SummaryChip({
    required this.label,
    required this.icon,
    required this.color,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }
}

// ── _DayDetailPanel ───────────────────────────────────────────────────────────

class _DayDetailPanel extends StatelessWidget {
  final String uid;
  final DateTime? selectedDay;
  final List<PlannedSession> sessions;

  const _DayDetailPanel({
    required this.uid,
    this.selectedDay,
    required this.sessions,
  });

  Future<void> _openEditor(BuildContext context, {PlannedSession? session}) async {
    await Navigator.push(
      context,
      AppModalRoute(
        page: PlannedSessionEditorView(
          uid:         uid,
          initialDate: selectedDay ?? DateTime.now(),
          session:     session,
        ),
      ),
    );
    // Stream in CalendarViewModel auto-refreshes — no manual reload needed.
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final secondaryColor =
        isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;

    if (selectedDay == null) {
      return Center(
        child: Text(
          'Selecciona un día',
          style: TextStyle(fontSize: 15, color: secondaryColor),
        ),
      );
    }

    if (sessions.isEmpty) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'Sin sesiones planificadas',
            style: TextStyle(fontSize: 15, color: secondaryColor),
          ),
          const SizedBox(height: 16),
          TextButton.icon(
            onPressed: () => _openEditor(context),
            icon: const Icon(Icons.add),
            label: const Text('Planificar sesión'),
            style: TextButton.styleFrom(foregroundColor: AppColors.brandPurple),
          ),
        ],
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: sessions.length,
      itemBuilder: (context, i) => _PlannedSessionCard(
        session:    sessions[i],
        onTap:      () => _openEditor(context, session: sessions[i]),
      ),
    );
  }
}

// ── _PlannedSessionCard ───────────────────────────────────────────────────────

class _PlannedSessionCard extends StatelessWidget {
  final PlannedSession session;
  final VoidCallback onTap;

  const _PlannedSessionCard({required this.session, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final categoryColor = _categoryColor(session.category);
    final secondaryColor =
        isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isDark ? AppColors.borderDark : AppColors.borderLight,
          ),
        ),
        child: Row(
          children: [
            // Category dot
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: categoryColor,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 12),

            // Title + subtitle
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _categoryLabel(session.category),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (session.time != null || session.templateId != null)
                    const SizedBox(height: 2),
                  if (session.time != null)
                    Text(
                      session.time!,
                      style: TextStyle(fontSize: 12, color: secondaryColor),
                    ),
                  if (session.templateId != null)
                    Text(
                      'Con plantilla',
                      style: TextStyle(fontSize: 12, color: secondaryColor),
                    ),
                ],
              ),
            ),

            // Status icon
            Icon(
              _statusIcon(session.status),
              size: 20,
              color: _statusColor(session.status),
            ),
          ],
        ),
      ),
    );
  }

  IconData _statusIcon(PlannedSessionStatus status) {
    switch (status) {
      case PlannedSessionStatus.planned:   return Icons.schedule;
      case PlannedSessionStatus.completed: return Icons.check_circle;
      case PlannedSessionStatus.skipped:   return Icons.cancel;
    }
  }

  Color _statusColor(PlannedSessionStatus status) {
    switch (status) {
      case PlannedSessionStatus.planned:   return const Color(0xFFAAAAAA);
      case PlannedSessionStatus.completed: return AppColors.rpeLow;
      case PlannedSessionStatus.skipped:   return AppColors.rpeMax;
    }
  }

  String _categoryLabel(String category) {
    switch (category) {
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
      default:                return category;
    }
  }
}
