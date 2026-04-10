import 'package:flutter/material.dart';
import 'package:running_laps/core/theme/app_colors.dart';
import 'package:running_laps/core/utils/app_transitions.dart';
import 'package:running_laps/core/widgets/app_footer.dart';
import 'package:running_laps/core/widgets/app_header.dart';
import 'package:running_laps/core/widgets/standard_table_calendar.dart';
import 'package:running_laps/features/athlete/data/athlete_session_model.dart';
import 'package:running_laps/features/athlete/viewmodels/athlete_calendar_viewmodel.dart';
import 'package:running_laps/features/athlete/views/session_editor_view.dart';
import 'package:running_laps/features/training/views/training_start_view.dart';
import 'package:table_calendar/table_calendar.dart';

class AthleteCalendarView extends StatefulWidget {
  final String uid;

  const AthleteCalendarView({super.key, required this.uid});

  @override
  State<AthleteCalendarView> createState() => _AthleteCalendarViewState();
}

class _AthleteCalendarViewState extends State<AthleteCalendarView> {
  late final AthleteCalendarViewModel _vm;

  @override
  void initState() {
    super.initState();
    _vm = AthleteCalendarViewModel();
    _vm.init(widget.uid);
  }

  @override
  void dispose() {
    _vm.dispose();
    super.dispose();
  }

  Future<void> _openEditor({
    required String date,
    AthleteSession? existing,
  }) async {
    await Navigator.push<bool>(
      context,
      AppModalRoute(
        page: SessionEditorView(
          uid:         widget.uid,
          initialDate: DateTime.tryParse(date) ?? DateTime.now(),
          session:     existing,
        ),
      ),
    );
    // Stream auto-updates calendar after save; no manual refresh needed.
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
            child: ValueListenableBuilder<AthleteCalendarState>(
              valueListenable: _vm.state,
              builder: (context, state, _) {
                return Column(
                  children: [
                    // Calendar
                    StandardTableCalendar<AthleteSession>(
                      lastDay: DateTime.now().add(const Duration(days: 365)),
                      focusedDay: state.focusedMonth,
                      selectedDay: state.selectedDay,
                      eventLoader: _vm.sessionsForDay,
                      onDaySelected: (selected, _) => _vm.selectDay(selected),
                      onPageChanged: _vm.onPageChanged,
                      calendarBuilders: CalendarBuilders<AthleteSession>(
                        markerBuilder: (context, day, events) {
                          if (events.isEmpty) return null;
                          return _buildMarkers(context, events);
                        },
                      ),
                    ),

                    // Day detail
                    Expanded(
                      child: _DayPanel(
                        uid:         widget.uid,
                        selectedDay: state.selectedDay,
                        sessions:    state.selectedDay != null
                            ? _vm.sessionsForDay(state.selectedDay!)
                            : [],
                        onAdd: () {
                          final day = state.selectedDay ?? DateTime.now();
                          _openEditor(
                            date:
                                '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}',
                          );
                        },
                        onEdit: (s) => _openEditor(
                            date: s.date, existing: s),
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

  Widget _buildMarkers(BuildContext context, List<AthleteSession> sessions) {
    const int maxDots = 3;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final brandColor =
        isDark ? AppColors.brandPurpleLight : AppColors.brandPurple;
    final displayCount =
        sessions.length > maxDots ? maxDots - 1 : sessions.length;
    final markers = <Widget>[];

    for (int i = 0; i < displayCount; i++) {
      final color = _categoryColor(sessions[i].category);
      markers.add(Container(
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
      ));
      if (i < displayCount - 1) markers.add(const SizedBox(width: 3));
    }

    if (sessions.length > maxDots) {
      markers.add(const SizedBox(width: 2));
      markers.add(Container(
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
      ));
    }

    return Positioned(
      bottom: 2,
      child: Row(mainAxisSize: MainAxisSize.min, children: markers),
    );
  }
}

// ── Category color ────────────────────────────────────────────────────────────

Color _categoryColor(String? category) {
  switch (category) {
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

String _categoryLabel(String? category) {
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
    default:                return category ?? 'Sesión';
  }
}

// ── _DayPanel ─────────────────────────────────────────────────────────────────

class _DayPanel extends StatelessWidget {
  final String uid;
  final DateTime? selectedDay;
  final List<AthleteSession> sessions;
  final VoidCallback onAdd;
  final ValueChanged<AthleteSession> onEdit;

  const _DayPanel({
    required this.uid,
    this.selectedDay,
    required this.sessions,
    required this.onAdd,
    required this.onEdit,
  });

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
            onPressed: onAdd,
            icon:  const Icon(Icons.add),
            label: const Text('Programar sesión'),
            style: TextButton.styleFrom(foregroundColor: AppColors.brandPurple),
          ),
        ],
      );
    }

    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            padding:     const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            itemCount:   sessions.length,
            itemBuilder: (context, i) =>
                _SessionCard(session: sessions[i], onTap: () => onEdit(sessions[i])),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: TextButton.icon(
            onPressed: onAdd,
            icon:  const Icon(Icons.add, size: 18),
            label: const Text('Añadir sesión'),
            style: TextButton.styleFrom(foregroundColor: AppColors.brandPurple),
          ),
        ),
      ],
    );
  }
}

// ── _SessionCard ──────────────────────────────────────────────────────────────

class _SessionCard extends StatelessWidget {
  final AthleteSession session;
  final VoidCallback onTap;

  const _SessionCard({required this.session, required this.onTap});

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
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: categoryColor,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _categoryLabel(session.category),
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  if (session.time != null || session.blocks.isNotEmpty)
                    const SizedBox(height: 2),
                  if (session.time != null)
                    Text(session.time!,
                        style: TextStyle(fontSize: 12, color: secondaryColor)),
                  if (session.blocks.isNotEmpty)
                    Text(
                      '${session.blocks.length} bloque${session.blocks.length != 1 ? 's' : ''}',
                      style: TextStyle(fontSize: 12, color: secondaryColor),
                    ),
                ],
              ),
            ),
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

  IconData _statusIcon(AthleteSessionStatus s) {
    switch (s) {
      case AthleteSessionStatus.planned:   return Icons.schedule;
      case AthleteSessionStatus.completed: return Icons.check_circle;
      case AthleteSessionStatus.skipped:   return Icons.cancel;
    }
  }

  Color _statusColor(AthleteSessionStatus s) {
    switch (s) {
      case AthleteSessionStatus.planned:   return const Color(0xFFAAAAAA);
      case AthleteSessionStatus.completed: return AppColors.rpeLow;
      case AthleteSessionStatus.skipped:   return AppColors.rpeMax;
    }
  }
}
