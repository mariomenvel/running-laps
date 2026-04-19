import 'dart:math' show max, min;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:running_laps/core/theme/app_colors.dart';
import 'package:running_laps/core/utils/app_transitions.dart';
import 'package:running_laps/core/widgets/app_header.dart';
import 'package:running_laps/core/widgets/modern_snackbar.dart';
import 'package:running_laps/features/athlete/data/athlete_session_model.dart';
import 'package:running_laps/features/athlete/data/athlete_session_repository.dart';
import 'package:running_laps/features/athlete/data/progress_repository.dart';
import 'package:running_laps/features/athlete/viewmodels/athlete_calendar_viewmodel.dart';
import 'package:running_laps/features/athlete/views/session_planner_view.dart';
import 'package:running_laps/features/templates/data/template_models.dart';
import 'package:running_laps/features/training/views/training_start_view.dart';
import 'package:running_laps/features/training/views/manual_training_view.dart';

class AthleteHubView extends StatefulWidget {
  final String uid;

  const AthleteHubView({super.key, required this.uid});

  @override
  State<AthleteHubView> createState() => _AthleteHubViewState();
}

class _AthleteHubViewState extends State<AthleteHubView> {
  late final AthleteCalendarViewModel _viewModel;
  int _selectedTab = 0;

  @override
  void initState() {
    super.initState();
    _viewModel = AthleteCalendarViewModel();
    _viewModel.init(widget.uid);
  }

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? Colors.black : Colors.white,
      body: Column(
        children: [
          AppHeader(
            title: const Text(
              'Modo atleta',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(
            child: ValueListenableBuilder<AthleteCalendarState>(
              valueListenable: _viewModel.state,
              builder: (context, state, _) => Column(
                children: [
                  SizedBox(
                    height: 380,
                    child: _buildCalendarContent(state, isDark),
                  ),
                  _TabSelector(
                    selectedTab: _selectedTab,
                    onTabChange: (i) => setState(() => _selectedTab = i),
                  ),
                  Expanded(
                    child: _selectedTab == 0
                        ? _ProgressTab(
                            uid: widget.uid,
                            selectedDay: state.selectedDay ?? DateTime.now(),
                            sessions: _viewModel.sessionsForDay(
                                state.selectedDay ?? DateTime.now()),
                          )
                        : _PlanningTab(uid: widget.uid),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCalendarContent(AthleteCalendarState state, bool isDark) {
    final titleColor = isDark ? Colors.white : const Color(0xFF1C1C1E);
    final defaultTextColor = isDark ? Colors.white : const Color(0xFF1C1C1E);
    final outsideTextColor =
        isDark ? const Color(0xFF3A3A3C) : const Color(0xFFC7C7CC);
    final weekdayColor =
        isDark ? const Color(0xFF8E8E93) : const Color(0xFF6C6C70);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: TableCalendar<AthleteSession>(
        firstDay: DateTime(2020, 1, 1),
        lastDay: DateTime(2027, 12, 31),
        focusedDay: state.focusedMonth,
        selectedDayPredicate: (day) => isSameDay(day, state.selectedDay),
        eventLoader: _viewModel.sessionsForDay,
        availableGestures: AvailableGestures.horizontalSwipe,
        onDaySelected: (selected, focused) {
          _viewModel.selectDay(selected);
          final sessions = _viewModel.sessionsForDay(selected);
          showModalBottomSheet(
            context: context,
            backgroundColor: Colors.transparent,
            isScrollControlled: true,
            builder: (_) => _DayActionSheet(
              day: selected,
              uid: widget.uid,
              sessions: sessions,
            ),
          );
        },
        onPageChanged: (focused) => _viewModel.onPageChanged(focused),
        rowHeight: 42.0,
        daysOfWeekHeight: 32.0,
        headerStyle: HeaderStyle(
          formatButtonVisible: false,
          titleCentered: true,
          titleTextStyle: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.4,
            color: titleColor,
          ),
          leftChevronIcon: const Icon(
            Icons.chevron_left,
            color: AppColors.brandPurple,
            size: 28,
          ),
          rightChevronIcon: const Icon(
            Icons.chevron_right,
            color: AppColors.brandPurple,
            size: 28,
          ),
          headerPadding: const EdgeInsets.symmetric(vertical: 12),
        ),
        calendarStyle: CalendarStyle(
          defaultTextStyle: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w400,
            letterSpacing: -0.2,
            color: defaultTextColor,
          ),
          weekendTextStyle: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w400,
            letterSpacing: -0.2,
            color: defaultTextColor,
          ),
          todayDecoration: BoxDecoration(
            color: AppColors.brandPurple.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          todayTextStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: AppColors.brandPurple,
          ),
          selectedDecoration: const BoxDecoration(
            color: AppColors.brandPurple,
            shape: BoxShape.circle,
          ),
          selectedTextStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
          outsideTextStyle: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w400,
            color: outsideTextColor,
          ),
          markersMaxCount: 0,
          cellMargin: const EdgeInsets.all(4),
        ),
        daysOfWeekStyle: DaysOfWeekStyle(
          weekdayStyle: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.2,
            color: weekdayColor,
          ),
          weekendStyle: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.2,
            color: weekdayColor,
          ),
        ),
        calendarBuilders: CalendarBuilders<AthleteSession>(
          defaultBuilder: (context, day, focusedDay) {
            final sessions = _viewModel.sessionsForDay(day);
            if (sessions.isEmpty) return null;
            return _DayWithSession(
              day: day,
              isToday: false,
              isSelected: false,
              hasSessions: true,
              isDark: isDark,
            );
          },
          todayBuilder: (context, day, focusedDay) {
            final sessions = _viewModel.sessionsForDay(day);
            return _DayWithSession(
              day: day,
              isToday: true,
              isSelected: false,
              hasSessions: sessions.isNotEmpty,
              isDark: isDark,
            );
          },
          selectedBuilder: (context, day, focusedDay) {
            final sessions = _viewModel.sessionsForDay(day);
            return _DayWithSession(
              day: day,
              isToday: false,
              isSelected: true,
              hasSessions: sessions.isNotEmpty,
              isDark: isDark,
            );
          },
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _TabSelector
// ─────────────────────────────────────────────────────────────────────────────

class _TabSelector extends StatelessWidget {
  final int selectedTab;
  final ValueChanged<int> onTabChange;

  const _TabSelector({required this.selectedTab, required this.onTabChange});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final containerBg =
        isDark ? const Color(0xFF1C1C1E) : const Color(0xFFE5E5EA);
    const labels = ['Progreso', 'Planificación'];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Container(
        decoration: BoxDecoration(
          color: containerBg,
          borderRadius: BorderRadius.circular(10),
        ),
        padding: const EdgeInsets.all(2),
        child: Row(
          children: List.generate(labels.length, (i) {
            final selected = i == selectedTab;
            final selectedBg = isDark ? const Color(0xFF2C2C2E) : Colors.white;
            final selectedText =
                isDark ? Colors.white : const Color(0xFF1C1C1E);
            return Expanded(
              child: GestureDetector(
                onTap: () => onTabChange(i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: selected ? selectedBg : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: selected
                        ? [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.08),
                              blurRadius: 4,
                              offset: const Offset(0, 1),
                            )
                          ]
                        : null,
                  ),
                  child: Text(
                    labels[i],
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight:
                          selected ? FontWeight.w600 : FontWeight.w400,
                      color: selected
                          ? selectedText
                          : const Color(0xFF8E8E93),
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _ProgressTab
// ─────────────────────────────────────────────────────────────────────────────

class _ProgressTab extends StatefulWidget {
  final String uid;
  final DateTime selectedDay;
  final List<AthleteSession> sessions;

  const _ProgressTab({
    required this.uid,
    required this.selectedDay,
    required this.sessions,
  });

  @override
  State<_ProgressTab> createState() => _ProgressTabState();
}

class _ProgressTabState extends State<_ProgressTab> {
  late Future<Map<int, PersonalRecord>> _recordsFuture;
  late Future<List<SeriesProgressGroup>> _progressFuture;

  @override
  void initState() {
    super.initState();
    final repo = ProgressRepository();
    _recordsFuture = repo.getPersonalRecords(widget.uid);
    _progressFuture = repo.getSeriesProgress(widget.uid);
  }

  double? _trendFor(SeriesProgressGroup group) {
    if (group.count < 6) return null;
    final mid = group.history.length ~/ 2;
    final first = group.history.sublist(0, mid);
    final second = group.history.sublist(mid);
    final avgFirst =
        first.fold<double>(0, (s, p) => s + p.paceSecPerKm) / first.length;
    final avgSecond =
        second.fold<double>(0, (s, p) => s + p.paceSecPerKm) / second.length;
    return avgFirst - avgSecond;
  }

  String _fmtPace(double secPerKm) {
    final t = secPerKm.round();
    return '${t ~/ 60}:${(t % 60).toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final secondary =
        isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;

    // If selected day has a completed session, show detail view
    final completed = widget.sessions
        .where((s) =>
            s.status == AthleteSessionStatus.completed &&
            s.completedTrainingId != null)
        .toList();
    if (completed.isNotEmpty) {
      return _ExecutedSessionDetail(
          uid: widget.uid, session: completed.first);
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Récords personales ──────────────────────────────────────
          const _SectionTitle(
            'RÉCORDS PERSONALES',
            explanation:
                'Tu mejor tiempo en cada distancia, detectado '
                'automáticamente en todos tus entrenamientos. '
                'Solo cuenta si la serie tiene GPS activo y '
                'la distancia es precisa.',
          ),
          const SizedBox(height: 10),
          FutureBuilder<Map<int, PersonalRecord>>(
            future: _recordsFuture,
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const SizedBox(
                  height: 60,
                  child: Center(
                    child: CircularProgressIndicator(
                        color: AppColors.brandPurple, strokeWidth: 2),
                  ),
                );
              }
              if (snap.hasError) {
                return Text('No disponible',
                    style: TextStyle(fontSize: 13, color: secondary));
              }
              final records = snap.data ?? {};
              return SizedBox(
                height: 72,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [400, 1000, 1500, 5000, 10000].map((d) {
                    final rec = records[d];
                    final label = d == 400
                        ? '400m'
                        : d == 1000
                            ? '1km'
                            : d == 1500
                                ? '1.5km'
                                : d == 5000
                                    ? '5km'
                                    : '10km';
                    final paceStr =
                        rec != null ? _fmtPace(rec.paceSecPerKm) : '—';
                    return Container(
                      width: 80,
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF1C1C1E)
                            : const Color(0xFFF2F2F7),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(label,
                              style: const TextStyle(
                                  fontSize: 11, color: Color(0xFF8E8E93))),
                          const SizedBox(height: 4),
                          Text(paceStr,
                              style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.brandPurple)),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              );
            },
          ),
          const SizedBox(height: 24),

          // ── Pace en series ──────────────────────────────────────────
          const _SectionTitle(
            'PACE EN SERIES',
            explanation:
                'Si entrenas la misma distancia varias veces, '
                'la app detecta si estás mejorando. Una flecha verde '
                'significa que tu ritmo está bajando en las últimas '
                'sesiones.',
          ),
          const SizedBox(height: 10),
          FutureBuilder<List<SeriesProgressGroup>>(
            future: _progressFuture,
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const SizedBox(
                  height: 40,
                  child: Center(
                    child: CircularProgressIndicator(
                        color: AppColors.brandPurple, strokeWidth: 2),
                  ),
                );
              }
              final groups = snap.data ?? [];
              if (groups.isEmpty) {
                return Text('Necesitas más entrenamientos',
                    style: TextStyle(fontSize: 13, color: secondary));
              }
              final first = groups.first;
              return _ProgressGroupCard(
                  group: first, trend: _trendFor(first), isDark: isDark);
            },
          ),
          const SizedBox(height: 24),

          // ── Esfuerzo vs rendimiento ─────────────────────────────────
          const _SectionTitle(
            'ESFUERZO VS RENDIMIENTO',
            explanation:
                'Compara tu RPE (esfuerzo percibido del 1 al 10) '
                'con tu ritmo real. Si haces el mismo tiempo con menos '
                'esfuerzo, estás mejorando aunque el cronómetro diga '
                'lo mismo.',
          ),
          const SizedBox(height: 10),
          FutureBuilder<List<SeriesProgressGroup>>(
            future: _progressFuture,
            builder: (context, snap) {
              final groups = snap.data ?? [];
              final trend = groups.isNotEmpty ? _trendFor(groups.first) : null;
              if (trend == null) {
                return Text(
                  'Completa más sesiones para ver si mejoras al mismo esfuerzo',
                  style: TextStyle(fontSize: 13, color: secondary),
                );
              }
              final g = groups.first;
              final distLabel = g.baseDistanceM >= 1000
                  ? '${(g.baseDistanceM / 1000).toStringAsFixed(0)} km'
                  : '${g.baseDistanceM}m';
              final improved = trend > 0;
              final absT = trend.abs().round();
              final msg = improved
                  ? 'En series de $distLabel, tu pace ha mejorado ${absT}s/km manteniendo RPE similar'
                  : 'En series de $distLabel, tu pace ha empeorado ${absT}s/km. Revisa tu carga.';
              return Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF1C1C1E)
                      : const Color(0xFFF2F2F7),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(msg,
                    style: TextStyle(
                        fontSize: 13, color: secondary, height: 1.4)),
              );
            },
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _ExecutedSessionDetail
// ─────────────────────────────────────────────────────────────────────────────

class _ExecutedSessionDetail extends StatefulWidget {
  final String uid;
  final AthleteSession session;

  const _ExecutedSessionDetail(
      {required this.uid, required this.session});

  @override
  State<_ExecutedSessionDetail> createState() =>
      _ExecutedSessionDetailState();
}

class _ExecutedSessionDetailState extends State<_ExecutedSessionDetail> {
  late Future<Map<String, dynamic>?> _trainingFuture;

  @override
  void initState() {
    super.initState();
    _trainingFuture = _loadTraining();
  }

  Future<Map<String, dynamic>?> _loadTraining() async {
    final id = widget.session.completedTrainingId;
    if (id == null) return null;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.uid)
          .collection('trainings')
          .doc(id)
          .get();
      return doc.exists ? doc.data() : null;
    } catch (e) {
      debugPrint('Error cargando training: $e');
      return null;
    }
  }

  String _fmtPace(double secPerKm) {
    final t = secPerKm.round();
    return '${t ~/ 60}:${(t % 60).toString().padLeft(2, '0')} /km';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final secondary =
        isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;
    final surfaceColor =
        isDark ? const Color(0xFF1C1C1E) : const Color(0xFFF2F2F7);

    final title = widget.session.category != null
        ? SessionCategoryX.fromValue(widget.session.category!).label
        : 'Sesión';

    return FutureBuilder<Map<String, dynamic>?>(
      future: _trainingFuture,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(
                color: AppColors.brandPurple, strokeWidth: 2),
          );
        }
        final data = snap.data;
        final comparison =
            data?['plannedComparison'] as Map<String, dynamic>?;
        final blocks =
            (comparison?['blocks'] as List<dynamic>? ?? [])
                .cast<Map<String, dynamic>>();

        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  const Icon(Icons.check_circle_rounded,
                      color: AppColors.rpeLow, size: 18),
                  const SizedBox(width: 8),
                  Text(title,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w700)),
                  const SizedBox(width: 8),
                  Text(widget.session.date,
                      style: TextStyle(fontSize: 13, color: secondary)),
                ],
              ),
              const SizedBox(height: 16),

              if (blocks.isNotEmpty) ...[
                const _SectionTitle('Comparativa por serie'),
                const SizedBox(height: 10),
                ...blocks.asMap().entries.map((e) {
                  final i = e.key;
                  final block = e.value;
                  final planned =
                      block['planned'] as Map<String, dynamic>?;
                  final executed =
                      block['executed'] as Map<String, dynamic>?;
                  final plannedPaceSec =
                      (planned?['targetPaceSec'] as num?)?.toDouble();
                  final execPaceSec =
                      (executed?['paceSec'] as num?)?.toDouble();
                  final deltaSec =
                      (plannedPaceSec != null && execPaceSec != null)
                          ? execPaceSec - plannedPaceSec
                          : null;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: surfaceColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Text('Serie ${i + 1}',
                            style: const TextStyle(
                                fontSize: 13, fontWeight: FontWeight.w600)),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            plannedPaceSec != null
                                ? 'Obj: ${_fmtPace(plannedPaceSec)}'
                                : 'Sin objetivo',
                            style: TextStyle(
                                fontSize: 12, color: secondary),
                          ),
                        ),
                        Text(
                          execPaceSec != null
                              ? _fmtPace(execPaceSec)
                              : '—',
                          style: const TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w700),
                        ),
                        if (deltaSec != null) ...[
                          const SizedBox(width: 8),
                          _DeltaBadge(deltaSec: deltaSec),
                        ],
                      ],
                    ),
                  );
                }),
              ] else ...[
                Text(
                  'Sesión completada. Ver detalles en el historial de entrenamientos.',
                  style: TextStyle(fontSize: 13, color: secondary, height: 1.4),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _PlanningTab
// ─────────────────────────────────────────────────────────────────────────────

class _PlanningTab extends StatefulWidget {
  final String uid;

  const _PlanningTab({required this.uid});

  @override
  State<_PlanningTab> createState() => _PlanningTabState();
}

class _PlanningTabState extends State<_PlanningTab> {
  late Future<({int completed, int planned, double km})> _weekStatsFuture;
  late Future<List<WeeklyVolume>> _volumeFuture;
  late Future<AthleteSession?> _nextRaceFuture;

  String _fmt(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  @override
  void initState() {
    super.initState();
    _weekStatsFuture = _loadWeekStats();
    _volumeFuture =
        ProgressRepository().getWeeklyVolume(widget.uid, weeks: 8);
    _nextRaceFuture = _loadNextRace();
  }

  Future<({int completed, int planned, double km})> _loadWeekStats() async {
    try {
      final now = DateTime.now();
      final monday = now.subtract(Duration(days: now.weekday - 1));
      final sunday = monday.add(const Duration(days: 6));
      final sessions = await AthleteSessionRepository()
          .streamSessionsInRange(
            uid: widget.uid,
            startDate: _fmt(monday),
            endDate: _fmt(sunday),
          )
          .first;
      final completedCount = sessions
          .where((s) => s.status == AthleteSessionStatus.completed)
          .length;
      final plannedCount = sessions
          .where((s) => s.status == AthleteSessionStatus.planned)
          .length;
      final volumes =
          await ProgressRepository().getWeeklyVolume(widget.uid, weeks: 1);
      final km = volumes.isNotEmpty ? volumes.last.km : 0.0;
      return (completed: completedCount, planned: plannedCount, km: km);
    } catch (e) {
      debugPrint('Error cargando estadísticas semanales: $e');
      return (completed: 0, planned: 0, km: 0.0);
    }
  }

  Future<AthleteSession?> _loadNextRace() async {
    try {
      final now = DateTime.now();
      final sessions = await AthleteSessionRepository()
          .streamSessionsInRange(
            uid: widget.uid,
            startDate: _fmt(now),
            endDate: _fmt(now.add(const Duration(days: 365))),
          )
          .first;
      final races = sessions
          .where((s) =>
              s.category == 'competicion' &&
              s.status == AthleteSessionStatus.planned)
          .toList()
        ..sort((a, b) => a.date.compareTo(b.date));
      return races.isNotEmpty ? races.first : null;
    } catch (e) {
      debugPrint('Error cargando próxima competición: $e');
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final secondary =
        isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Esta semana ─────────────────────────────────────────────
          const _SectionTitle('ESTA SEMANA'),
          const SizedBox(height: 10),
          FutureBuilder<({int completed, int planned, double km})>(
            future: _weekStatsFuture,
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const SizedBox(
                  height: 56,
                  child: Center(
                    child: CircularProgressIndicator(
                        color: AppColors.brandPurple, strokeWidth: 2),
                  ),
                );
              }
              final stats =
                  snap.data ?? (completed: 0, planned: 0, km: 0.0);
              return Row(
                children: [
                  _WeekStatChip(
                    icon: Icons.check_circle_outline_rounded,
                    iconColor: AppColors.rpeLow,
                    value: '${stats.completed}',
                    label: 'Completadas',
                    isDark: isDark,
                  ),
                  const SizedBox(width: 8),
                  _WeekStatChip(
                    icon: Icons.calendar_today_rounded,
                    iconColor: AppColors.brandPurple,
                    value: '${stats.planned}',
                    label: 'Planificadas',
                    isDark: isDark,
                  ),
                  const SizedBox(width: 8),
                  _WeekStatChip(
                    icon: Icons.directions_run_rounded,
                    iconColor: const Color(0xFF2196F3),
                    value: '${stats.km.toStringAsFixed(1)} km',
                    label: 'Ejecutados',
                    isDark: isDark,
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 24),

          // ── Carga últimas 8 semanas ─────────────────────────────────
          const _SectionTitle(
            'CARGA SEMANAL',
            explanation:
                'Estimación del estrés físico acumulado cada semana, '
                'calculado a partir de la distancia y la intensidad de '
                'cada sesión. Una semana alta seguida de una baja es '
                'normal y recomendable.',
          ),
          const SizedBox(height: 10),
          FutureBuilder<List<WeeklyVolume>>(
            future: _volumeFuture,
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const SizedBox(
                  height: 80,
                  child: Center(
                    child: CircularProgressIndicator(
                        color: AppColors.brandPurple, strokeWidth: 2),
                  ),
                );
              }
              final volumes = snap.data ?? [];
              if (volumes.isEmpty) {
                return Text('Sin datos de volumen',
                    style: TextStyle(fontSize: 13, color: secondary));
              }
              return SizedBox(
                height: 100,
                child: _WeeklyBarChart(volumes: volumes, isDark: isDark),
              );
            },
          ),
          const SizedBox(height: 24),

          // ── Próxima competición ─────────────────────────────────────
          FutureBuilder<AthleteSession?>(
            future: _nextRaceFuture,
            builder: (context, snap) {
              final race = snap.data;
              if (race == null) return const SizedBox.shrink();
              return _RaceCountdownCard(session: race, isDark: isDark);
            },
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _SectionTitle
// ─────────────────────────────────────────────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  final String title;
  final String? explanation;

  const _SectionTitle(this.title, {this.explanation});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 0, 0, 0),
      child: Row(
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.6,
              color: Color(0xFF8E8E93),
            ),
          ),
          if (explanation != null) ...[
            const SizedBox(width: 4),
            _InfoButton(title: title, explanation: explanation!),
          ],
          const Spacer(),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _InfoButton + _ExplanationSheet
// ─────────────────────────────────────────────────────────────────────────────

class _InfoButton extends StatelessWidget {
  final String title;
  final String explanation;

  const _InfoButton({required this.title, required this.explanation});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        builder: (_) =>
            _ExplanationSheet(title: title, explanation: explanation),
      ),
      child: Container(
        padding: const EdgeInsets.all(4),
        child: const Icon(
          Icons.info_outline_rounded,
          size: 16,
          color: Color(0xFF8E8E93),
        ),
      ),
    );
  }
}

class _ExplanationSheet extends StatelessWidget {
  final String title;
  final String explanation;

  const _ExplanationSheet(
      {required this.title, required this.explanation});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF1C1C1E) : Colors.white;
    final titleColor = isDark ? Colors.white : const Color(0xFF1C1C1E);
    final textColor =
        isDark ? const Color(0xFFEBEBF5) : const Color(0xFF3A3A3C);

    return Container(
      margin: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.info_outline_rounded,
                  color: AppColors.brandPurple, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: titleColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            explanation,
            style: TextStyle(fontSize: 15, height: 1.5, color: textColor),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.brandPurple,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () => Navigator.pop(context),
              child: const Text('Entendido'),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _ProgressGroupCard
// ─────────────────────────────────────────────────────────────────────────────

class _ProgressGroupCard extends StatelessWidget {
  final SeriesProgressGroup group;
  final double? trend;
  final bool isDark;

  const _ProgressGroupCard(
      {required this.group, required this.trend, required this.isDark});

  String _distLabel(int m) => m >= 1000
      ? '${(m / 1000).toStringAsFixed(m % 1000 == 0 ? 0 : 1)} km'
      : '${m}m';

  String _fmtDate(DateTime d) {
    const months = [
      '',
      'ene',
      'feb',
      'mar',
      'abr',
      'may',
      'jun',
      'jul',
      'ago',
      'sep',
      'oct',
      'nov',
      'dic'
    ];
    return '${d.day} ${months[d.month]}';
  }

  @override
  Widget build(BuildContext context) {
    final surfaceColor =
        isDark ? const Color(0xFF1C1C1E) : const Color(0xFFF2F2F7);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${_distLabel(group.baseDistanceM)}  ·  ${group.count} series',
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w700),
                ),
              ),
              if (trend != null) _TrendBadge(improving: trend! > 0),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 60,
            child: _MiniLineChart(
                points:
                    group.history.map((p) => p.paceSecPerKm).toList()),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(_fmtDate(group.history.first.date),
                  style: const TextStyle(
                      fontSize: 10, color: Color(0xFFAAAAAA))),
              Text(_fmtDate(group.history.last.date),
                  style: const TextStyle(
                      fontSize: 10, color: Color(0xFFAAAAAA))),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _TrendBadge
// ─────────────────────────────────────────────────────────────────────────────

class _TrendBadge extends StatelessWidget {
  final bool improving;
  const _TrendBadge({required this.improving});

  @override
  Widget build(BuildContext context) {
    final color = improving ? AppColors.rpeLow : AppColors.effort;
    final icon = improving
        ? Icons.arrow_upward_rounded
        : Icons.arrow_downward_rounded;
    final label = improving ? 'Mejorando' : 'A revisar';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 3),
          Text(label,
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: color)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _DeltaBadge
// ─────────────────────────────────────────────────────────────────────────────

class _DeltaBadge extends StatelessWidget {
  final double deltaSec;
  const _DeltaBadge({required this.deltaSec});

  @override
  Widget build(BuildContext context) {
    final abs = deltaSec.abs();
    final color = abs <= 15
        ? AppColors.rpeLow
        : abs <= 30
            ? AppColors.rpeMid
            : AppColors.rpeMax;
    final sign = deltaSec >= 0 ? '+' : '-';
    final t = abs.round();
    final label =
        '$sign${t ~/ 60}:${(t % 60).toString().padLeft(2, '0')}';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color)),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _WeekStatChip
// ─────────────────────────────────────────────────────────────────────────────

class _WeekStatChip extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String value;
  final String label;
  final bool isDark;

  const _WeekStatChip({
    required this.icon,
    required this.iconColor,
    required this.value,
    required this.label,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final surfaceColor =
        isDark ? const Color(0xFF1C1C1E) : const Color(0xFFF2F2F7);
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: surfaceColor,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 16, color: iconColor),
            const SizedBox(height: 6),
            Text(value,
                style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w700)),
            Text(label,
                style: const TextStyle(
                    fontSize: 11, color: Color(0xFF8E8E93))),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _WeeklyBarChart
// ─────────────────────────────────────────────────────────────────────────────

class _WeeklyBarChart extends StatelessWidget {
  final List<WeeklyVolume> volumes;
  final bool isDark;

  const _WeeklyBarChart({required this.volumes, required this.isDark});

  @override
  Widget build(BuildContext context) {
    if (volumes.isEmpty) return const SizedBox.shrink();

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final currentMonday = today.subtract(Duration(days: today.weekday - 1));
    final maxKm = volumes.fold<double>(0, (m, v) => max(m, v.km));

    return Column(
      children: [
        Expanded(
          child: CustomPaint(
            painter: _WeeklyBarPainter(
              volumes: volumes,
              currentMonday: currentMonday,
              maxKm: maxKm,
            ),
            size: Size.infinite,
          ),
        ),
        const SizedBox(height: 4),
        SizedBox(
          height: 14,
          child: Row(
            children: volumes.map((v) {
              final isCurrent = v.weekStart == currentMonday;
              return Expanded(
                child: Text(
                  isCurrent ? 'HOY' : '',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 8,
                    fontWeight: FontWeight.w700,
                    color: AppColors.brandPurple,
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

class _WeeklyBarPainter extends CustomPainter {
  final List<WeeklyVolume> volumes;
  final DateTime currentMonday;
  final double maxKm;

  const _WeeklyBarPainter({
    required this.volumes,
    required this.currentMonday,
    required this.maxKm,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (volumes.isEmpty || maxKm <= 0) return;
    const minBarH = 3.0;
    const radius = Radius.circular(3);
    final n = volumes.length;
    final barW = size.width / n;
    final barPad = barW * 0.15;

    for (var i = 0; i < n; i++) {
      final v = volumes[i];
      if (v.km <= 0) continue;
      final isCurrent = v.weekStart == currentMonday;
      final barPaint = Paint()
        ..color = isCurrent
            ? AppColors.brandPurple
            : AppColors.brandPurple.withOpacity(0.4)
        ..style = PaintingStyle.fill;
      final h = max(minBarH, (v.km / maxKm) * size.height * 0.95);
      final left = i * barW + barPad;
      final right = (i + 1) * barW - barPad;
      canvas.drawRRect(
        RRect.fromLTRBR(left, size.height - h, right, size.height, radius),
        barPaint,
      );
    }
  }

  @override
  bool shouldRepaint(_WeeklyBarPainter old) =>
      old.volumes != volumes || old.currentMonday != currentMonday;
}

// ─────────────────────────────────────────────────────────────────────────────
// _RaceCountdownCard
// ─────────────────────────────────────────────────────────────────────────────

class _RaceCountdownCard extends StatelessWidget {
  final AthleteSession session;
  final bool isDark;

  const _RaceCountdownCard({required this.session, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final surfaceColor =
        isDark ? const Color(0xFF1C1C1E) : const Color(0xFFF2F2F7);
    final parts = session.date.split('-');
    final raceDate = parts.length == 3
        ? DateTime(
            int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]))
        : null;
    final daysLeft =
        raceDate?.difference(DateTime.now()).inDays;
    final raceName = session.raceName ?? 'Competición';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle('Próxima competición'),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: surfaceColor,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
                color: AppColors.brandPurple.withOpacity(0.3)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.brandPurple.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.emoji_events_rounded,
                    color: AppColors.brandPurple, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(raceName,
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w600)),
                    Text(session.date,
                        style: const TextStyle(
                            fontSize: 12, color: Color(0xFF8E8E93))),
                  ],
                ),
              ),
              if (daysLeft != null)
                Column(
                  children: [
                    Text(
                      '$daysLeft',
                      style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: AppColors.brandPurple),
                    ),
                    const Text('días',
                        style: TextStyle(
                            fontSize: 11, color: Color(0xFF8E8E93))),
                  ],
                ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _MiniLineChart + _MiniLinePainter
// ─────────────────────────────────────────────────────────────────────────────

class _MiniLineChart extends StatelessWidget {
  final List<double> points;
  const _MiniLineChart({required this.points});

  @override
  Widget build(BuildContext context) {
    if (points.length < 2) return const SizedBox.shrink();
    return CustomPaint(
        painter: _MiniLinePainter(points: points), size: Size.infinite);
  }
}

class _MiniLinePainter extends CustomPainter {
  final List<double> points;
  const _MiniLinePainter({required this.points});

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;
    final minVal = points.reduce(min);
    final maxVal = points.reduce(max);
    final range = maxVal - minVal;

    double norm(double v) {
      if (range == 0) return size.height / 2;
      return size.height -
          ((v - minVal) / range) * size.height * 0.85 -
          size.height * 0.075;
    }

    final linePaint = Paint()
      ..color = AppColors.brandPurple
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final dotPaint = Paint()
      ..color = AppColors.brandPurpleLight
      ..style = PaintingStyle.fill;

    final path = Path();
    for (var i = 0; i < points.length; i++) {
      final x = (i / (points.length - 1)) * size.width;
      final y = norm(points[i]);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(path, linePaint);

    for (var i = 0; i < points.length; i++) {
      final x = (i / (points.length - 1)) * size.width;
      final y = norm(points[i]);
      canvas.drawCircle(Offset(x, y), 3, dotPaint);
    }
  }

  @override
  bool shouldRepaint(_MiniLinePainter old) => old.points != points;
}

// ─────────────────────────────────────────────────────────────────────────────
// _DayActionSheet
// ─────────────────────────────────────────────────────────────────────────────

class _DayActionSheet extends StatelessWidget {
  final DateTime day;
  final String uid;
  final List<AthleteSession> sessions;

  const _DayActionSheet({
    required this.day,
    required this.uid,
    required this.sessions,
  });

  String _formatDay(DateTime d) {
    const weekdays = [
      '',
      'Lunes',
      'Martes',
      'Miércoles',
      'Jueves',
      'Viernes',
      'Sábado',
      'Domingo',
    ];
    const months = [
      '',
      'enero',
      'febrero',
      'marzo',
      'abril',
      'mayo',
      'junio',
      'julio',
      'agosto',
      'septiembre',
      'octubre',
      'noviembre',
      'diciembre',
    ];
    return '${weekdays[d.weekday]}, ${d.day} de ${months[d.month]}';
  }

  String _sessionTitle(AthleteSession s) {
    if (s.category != null) {
      return SessionCategoryX.fromValue(s.category!).label;
    }
    return 'Sesión';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF1C1C1E) : Colors.white;
    final titleColor = isDark ? Colors.white : const Color(0xFF1C1C1E);
    final divColor =
        isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE5E5EA);

    return Container(
      margin: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _formatDay(day),
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: titleColor,
            ),
          ),
          const SizedBox(height: 16),

          if (sessions.isNotEmpty) ...[
            ...sessions.asMap().entries.map((e) {
              final s = e.value;
              final isLast = e.key == sessions.length - 1;
              final completed = s.status == AthleteSessionStatus.completed;
              return Column(
                children: [
                  Container(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _sessionTitle(s),
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w500,
                                  color: titleColor,
                                ),
                              ),
                              if (s.blocks.isNotEmpty)
                                Text(
                                  '${s.blocks.length} series',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: Color(0xFF8E8E93),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        if (completed)
                          const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.check_circle_rounded,
                                  color: AppColors.rpeLow, size: 16),
                              SizedBox(width: 4),
                              Text(
                                'Completada',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: AppColors.rpeLow,
                                ),
                              ),
                            ],
                          )
                        else
                          FilledButton(
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.brandPurple,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12),
                              minimumSize: const Size(0, 34),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            onPressed: () {
                              Navigator.pop(context);
                              _launchGuidedSession(context, s, uid);
                            },
                            child: const Text('Ejecutar',
                                style: TextStyle(fontSize: 13)),
                          ),
                      ],
                    ),
                  ),
                  if (!isLast)
                    Divider(height: 1, thickness: 1, color: divColor),
                ],
              );
            }),
            const SizedBox(height: 12),
            Divider(height: 1, thickness: 1, color: divColor),
            const SizedBox(height: 8),
          ],

          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  AppRoute(
                    page: SessionPlannerView(
                      uid: uid,
                      initialDate: day,
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.add_rounded),
              label: const Text('Planificar sesión'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.brandPurple,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  AppRoute(page: ManualTrainingView(initialDate: day)),
                );
              },
              icon: const Icon(Icons.edit_note_rounded, size: 18),
              label: const Text('Registrar entrenamiento'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.brandPurple,
                side: const BorderSide(color: AppColors.brandPurple),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'Cancelar',
                style: TextStyle(color: Color(0xFF8E8E93)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _launchGuidedSession
// ─────────────────────────────────────────────────────────────────────────────

Future<void> _launchGuidedSession(
  BuildContext context,
  AthleteSession session,
  String uid,
) async {
  if (session.blocks.isEmpty) {
    ModernSnackBar.showError(
        context, 'Esta sesión no tiene series configuradas');
    return;
  }

  final now = DateTime.now();
  final blocks = session.blocks.asMap().entries.map((e) {
    final b = e.value;
    final isDistance = b.distanceM != null;
    return TemplateBlock(
      id: b.id,
      order: e.key,
      type: isDistance ? TemplateBlockType.distance : TemplateBlockType.time,
      value: isDistance ? b.distanceM! : (b.durationMinutes ?? 0) * 60,
      restSeconds: b.restSeconds ?? 0,
      alerts: TemplateAlerts(
        enabled: b.targetPaceMinMin != null,
        mode: 'pace',
        timeMin: 0,
        timeSec: 0,
        paceMin: b.targetPaceMinMin ?? 0,
        paceSec: b.targetPaceMinSec ?? 0,
        segmentDistance: b.distanceM ?? 1000,
      ),
      targetPaceMin: b.targetPaceMinMin,
      targetPaceSec: b.targetPaceMinSec,
      targetRpe: b.targetRpe,
      targetZone: b.targetZone,
    );
  }).toList();

  final sessionName = session.category != null
      ? SessionCategoryX.fromValue(session.category!).label
      : 'Sesión planificada';

  final template = TrainingTemplate(
    id: session.id,
    name: sessionName,
    colorValue: AppColors.brandPurple.value,
    isWarmupCooldown: false,
    blocks: blocks,
    createdAt: now,
    updatedAt: now,
  );

  if (!context.mounted) return;
  Navigator.push(
    context,
    AppRoute(
      page: TrainingStartView(
        sourceTemplate: template,
        athleteSessionId: session.id,
      ),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// _DayWithSession
// ─────────────────────────────────────────────────────────────────────────────

class _DayWithSession extends StatelessWidget {
  final DateTime day;
  final bool isToday;
  final bool isSelected;
  final bool hasSessions;
  final bool isDark;

  const _DayWithSession({
    required this.day,
    required this.isToday,
    required this.isSelected,
    required this.hasSessions,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    if (isSelected) {
      return _DayCircle(
        day: day,
        backgroundColor: AppColors.brandPurple,
        textColor: Colors.white,
        textWeight: FontWeight.w600,
        border: null,
      );
    }
    if (isToday && hasSessions) {
      return _DayCircle(
        day: day,
        backgroundColor: AppColors.brandPurple.withValues(alpha: 0.15),
        textColor: AppColors.brandPurple,
        textWeight: FontWeight.w600,
        border: Border.all(color: AppColors.brandPurple, width: 1.5),
      );
    }
    if (isToday) {
      return _DayCircle(
        day: day,
        backgroundColor: AppColors.brandPurple.withValues(alpha: 0.15),
        textColor: AppColors.brandPurple,
        textWeight: FontWeight.w600,
        border: null,
      );
    }
    if (hasSessions) {
      final defaultColor =
          isDark ? Colors.white : const Color(0xFF1C1C1E);
      return _DayCircle(
        day: day,
        backgroundColor: Colors.transparent,
        textColor: defaultColor,
        textWeight: FontWeight.w400,
        border: Border.all(color: AppColors.brandPurple, width: 1.5),
      );
    }
    return const SizedBox.shrink();
  }
}

class _DayCircle extends StatelessWidget {
  final DateTime day;
  final Color backgroundColor;
  final Color textColor;
  final FontWeight textWeight;
  final Border? border;

  const _DayCircle({
    required this.day,
    required this.backgroundColor,
    required this.textColor,
    required this.textWeight,
    required this.border,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: backgroundColor,
        shape: BoxShape.circle,
        border: border,
      ),
      child: Text(
        '${day.day}',
        style: TextStyle(
          fontSize: 15,
          fontWeight: textWeight,
          color: textColor,
        ),
      ),
    );
  }
}
