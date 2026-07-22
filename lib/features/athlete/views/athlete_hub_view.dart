import 'dart:async';
import 'dart:math' show max, min;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:running_laps/core/theme/app_colors.dart';
import 'package:running_laps/core/utils/app_transitions.dart';
import 'package:running_laps/core/widgets/app_header.dart';
import 'package:running_laps/core/widgets/main_shell.dart';
import 'package:running_laps/core/widgets/modern_snackbar.dart';
import 'package:running_laps/features/athlete/data/athlete_session_model.dart';
import 'package:running_laps/features/athlete/data/athlete_session_repository.dart';
import 'package:running_laps/features/athlete/data/progress_repository.dart';
import 'package:running_laps/features/athlete/viewmodels/athlete_calendar_viewmodel.dart';
import 'package:running_laps/features/ai_coach/data/ai_coach_automation_service.dart';
import 'package:running_laps/features/ai_coach/data/ai_coach_repository.dart';
import 'package:running_laps/features/ai_coach/data/ai_coach_weekly_planner_service.dart';
import 'package:running_laps/features/ai_coach/data/race_goal.dart';
import 'package:running_laps/features/ai_coach/data/race_goal_repository.dart';
import 'package:running_laps/features/ai_coach/views/ai_coach_onboarding_launcher.dart';
import 'package:running_laps/features/ai_coach/views/race_goals_section.dart';
import 'package:running_laps/features/templates/data/template_models.dart';
import 'package:running_laps/features/templates/data/templates_repository.dart';
import 'package:running_laps/features/templates/data/workout_session.dart';
import 'package:running_laps/features/templates/views/workout_editor_screen.dart';
import 'package:running_laps/features/training/views/training_start_view.dart';
import 'package:running_laps/features/training/views/manual_training_view.dart';
import 'package:running_laps/core/services/notification_service.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AthleteHubView extends StatefulWidget {
  final String uid;

  const AthleteHubView({super.key, required this.uid});

  @override
  State<AthleteHubView> createState() => _AthleteHubViewState();
}

class _AthleteHubViewState extends State<AthleteHubView> {
  late final AthleteCalendarViewModel _viewModel;
  int _selectedTab = 0;
  bool _calendarExpanded = true;

  StreamSubscription<List<RaceGoal>>? _raceGoalsSub;
  Set<String> _raceGoalDates = {};

  @override
  void initState() {
    super.initState();
    _viewModel = AthleteCalendarViewModel();
    _viewModel.init(widget.uid);
    _requestNotificationPermissions();
    _raceGoalsSub = RaceGoalRepository()
        .streamGoals(uid: widget.uid)
        .listen((goals) {
      if (!mounted) return;
      setState(() {
        _raceGoalDates = goals.map((g) => g.date).toSet();
      });
    });
  }

  Future<void> _requestNotificationPermissions() async {
    final prefs = await SharedPreferences.getInstance();
    final asked = prefs.getBool('notif_permissions_asked') ?? false;
    if (!asked) {
      await NotificationService().requestPermissions();
      await prefs.setBool('notif_permissions_asked', true);
    }
  }

  @override
  void dispose() {
    _raceGoalsSub?.cancel();
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
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                    height: _calendarExpanded ? 380 : 160,
                    child: _buildCalendarContent(state, isDark),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        _InfoButton(
                          title: 'Leyenda del calendario',
                          explanation:
                              '• Punto verde: sesión completada\n'
                              '• Punto morado: sesión planificada\n'
                              '• Punto lila: sugerencia IA pendiente\n'
                              '• Punto rojo: competición\n'
                              '• Círculo morado sólido: día seleccionado\n'
                              '• Círculo morado tenue: hoy',
                        ),
                      ],
                    ),
                  ),
                  if (state.sessionsByDate.isEmpty)
                    _EmptyCalendarHint(uid: widget.uid),
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
    final defaultTextColor = isDark ? Colors.white : const Color(0xFF1C1C1E);
    final outsideTextColor =
        isDark ? const Color(0xFF3A3A3C) : const Color(0xFFC7C7CC);
    final weekdayColor =
        isDark ? const Color(0xFF8E8E93) : const Color(0xFF6C6C70);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: ClipRect(
        child: TableCalendar<AthleteSession>(
        firstDay: DateTime(2020, 1, 1),
        lastDay: DateTime(2027, 12, 31),
        focusedDay: state.focusedMonth,
        calendarFormat: _calendarExpanded
            ? CalendarFormat.month
            : CalendarFormat.week,
        availableCalendarFormats: const {
          CalendarFormat.month: 'Mes',
          CalendarFormat.week: 'Semana',
        },
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
        rowHeight: 52.0,
        daysOfWeekHeight: 32.0,
        headerStyle: HeaderStyle(
          formatButtonVisible: false,
          titleCentered: true,
          leftChevronIcon: const Icon(
            Icons.chevron_left,
            color: AppColors.brand,
            size: 28,
          ),
          rightChevronIcon: const Icon(
            Icons.chevron_right,
            color: AppColors.brand,
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
            color: AppColors.brand.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          todayTextStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: AppColors.brand,
          ),
          selectedDecoration: const BoxDecoration(
            color: AppColors.brand,
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
          headerTitleBuilder: (context, day) {
            return GestureDetector(
              onTap: () =>
                  setState(() => _calendarExpanded = !_calendarExpanded),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    DateFormat('MMMM yyyy', 'es_ES').format(day),
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.4,
                      color: isDark
                          ? Colors.white
                          : const Color(0xFF1C1C1E),
                    ),
                  ),
                  const SizedBox(width: 6),
                  AnimatedRotation(
                    turns: _calendarExpanded ? 0.0 : 0.5,
                    duration: const Duration(milliseconds: 300),
                    child: const Icon(
                      Icons.keyboard_arrow_up_rounded,
                      size: 20,
                      color: AppColors.brand,
                    ),
                  ),
                ],
              ),
            );
          },
          defaultBuilder: (context, day, focusedDay) {
            final sessions = _viewModel.sessionsForDay(day);
            final hasRaceGoal = _raceGoalDates.contains(raceGoalDateKey(day));
            if (sessions.isEmpty && !hasRaceGoal) return null;
            return _DayCircle(
              day: day.day,
              isToday: false,
              isSelected: false,
              sessions: sessions,
              hasRaceGoal: hasRaceGoal,
            );
          },
          todayBuilder: (context, day, focusedDay) {
            final sessions = _viewModel.sessionsForDay(day);
            return _DayCircle(
              day: day.day,
              isToday: true,
              isSelected: false,
              sessions: sessions,
              hasRaceGoal: _raceGoalDates.contains(raceGoalDateKey(day)),
            );
          },
          selectedBuilder: (context, day, focusedDay) {
            final sessions = _viewModel.sessionsForDay(day);
            return _DayCircle(
              day: day.day,
              isToday: false,
              isSelected: true,
              sessions: sessions,
              hasRaceGoal: _raceGoalDates.contains(raceGoalDateKey(day)),
            );
          },
        ),
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
                              color: Colors.black.withValues(alpha: 0.08),
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
                        color: AppColors.brand, strokeWidth: 2),
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
                                  color: AppColors.brand)),
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
                        color: AppColors.brand, strokeWidth: 2),
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
              if (groups.isEmpty || groups.first.count < 6) {
                return Text(
                  'Completa más sesiones para ver si mejoras al mismo esfuerzo',
                  style: TextStyle(fontSize: 13, color: secondary),
                );
              }
              final g = groups.first;
              final mid = g.history.length ~/ 2;
              final firstHalf  = g.history.sublist(0, mid);
              final secondHalf = g.history.sublist(mid);

              final avgPaceFirst  = firstHalf.fold<double>(0, (s, p) => s + p.paceSecPerKm) / firstHalf.length;
              final avgPaceSecond = secondHalf.fold<double>(0, (s, p) => s + p.paceSecPerKm) / secondHalf.length;
              final avgRpeFirst   = firstHalf.fold<double>(0, (s, p) => s + p.rpe) / firstHalf.length;
              final avgRpeSecond  = secondHalf.fold<double>(0, (s, p) => s + p.rpe) / secondHalf.length;

              final paceImproved = avgPaceSecond < avgPaceFirst;
              final rpeDown      = avgRpeSecond  < avgRpeFirst;
              final paceDelta    = (avgPaceFirst - avgPaceSecond).abs().round();
              final rpeDelta     = (avgRpeFirst  - avgRpeSecond).abs();

              final distLabel = g.baseDistanceM >= 1000
                  ? '${(g.baseDistanceM / 1000).toStringAsFixed(0)} km'
                  : '${g.baseDistanceM}m';

              // Headline interpretation
              final String headline;
              final Color  headlineColor;
              if (paceImproved && rpeDown) {
                headline = '¡Mejora eficiente! Más rápido con menos esfuerzo';
                headlineColor = AppColors.rpeLow;
              } else if (paceImproved && !rpeDown) {
                headline = 'Pace mejora, pero el esfuerzo también sube';
                headlineColor = const Color(0xFFFFC107);
              } else if (!paceImproved && rpeDown) {
                headline = 'Menos esfuerzo, pero el pace aún no acompaña';
                headlineColor = const Color(0xFFFFC107);
              } else {
                headline = 'Pace y esfuerzo han empeorado. Revisa tu carga';
                headlineColor = AppColors.rpeMax;
              }

              return Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1C1C1E) : const Color(0xFFF2F2F7),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // distance label
                    Text(
                      'Series de $distLabel — últimas ${g.count} sesiones',
                      style: TextStyle(fontSize: 11, color: secondary),
                    ),
                    const SizedBox(height: 8),
                    // comparison row
                    Row(
                      children: [
                        Expanded(
                          child: _RpeVsPaceHalfCard(
                            label: 'Primeras ${firstHalf.length}',
                            pace: _fmtPace(avgPaceFirst),
                            rpe: avgRpeFirst,
                            isDark: isDark,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Column(
                          children: [
                            Icon(
                              paceImproved ? Icons.arrow_forward_rounded : Icons.arrow_forward_rounded,
                              size: 16,
                              color: secondary,
                            ),
                          ],
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _RpeVsPaceHalfCard(
                            label: 'Últimas ${secondHalf.length}',
                            pace: _fmtPace(avgPaceSecond),
                            rpe: avgRpeSecond,
                            paceColor: paceImproved ? AppColors.rpeLow : AppColors.rpeMax,
                            rpeColor: rpeDown ? AppColors.rpeLow : AppColors.rpeMax,
                            isDark: isDark,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    // delta line
                    Row(
                      children: [
                        Icon(
                          paceImproved ? Icons.trending_down_rounded : Icons.trending_up_rounded,
                          size: 14,
                          color: paceImproved ? AppColors.rpeLow : AppColors.rpeMax,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${paceImproved ? '-' : '+'}${paceDelta}s/km pace  •  RPE ${rpeDown ? '-' : '+'}${rpeDelta.toStringAsFixed(1)}',
                          style: TextStyle(fontSize: 12, color: secondary),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // headline
                    Text(
                      headline,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: headlineColor,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
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
                color: AppColors.brand, strokeWidth: 2),
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
                          fontSize: 16, fontWeight: FontWeight.w600)),
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
                              fontSize: 13, fontWeight: FontWeight.w600),
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
  late Future<List<AthleteSession>> _upcomingFuture;
  late Future<List<AthleteSession>> _nextWeekSuggestionsFuture;
  late Future<bool> _aiEnabledFuture;
  bool _isGeneratingAiPlan = false;
  bool _isAcceptingAiPlan = false;
  bool _autoPlannerRan = false;
  bool _hasAiCoachProfile = false;
  bool _showFeedbackBanner = false;

  String _currentWeekStart() {
    final now = DateTime.now();
    final monday = now.subtract(Duration(days: now.weekday - 1));
    return '${monday.year}-${monday.month.toString().padLeft(2, '0')}-${monday.day.toString().padLeft(2, '0')}';
  }

  Future<void> _checkWeeklyFeedback() async {
    if (!_hasAiCoachProfile) return;
    final existing = await AiCoachRepository().getWeeklyFeedback(
      uid: widget.uid,
      weekStart: _currentWeekStart(),
    );
    if (mounted) {
      setState(() => _showFeedbackBanner = existing == null);
    }
  }

  String _fmt(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  bool _esHoy(String date) {
    final today = DateTime.now();
    final d = DateTime.parse(date);
    return d.year == today.year && d.month == today.month && d.day == today.day;
  }

  DateTime _mondayOf(DateTime value) {
    final date = DateTime(value.year, value.month, value.day);
    return date.subtract(Duration(days: date.weekday - 1));
  }

  Future<bool> _loadAiEnabled() async {
    final provider = await AiCoachRepository().getProviderConfig(uid: widget.uid);
    return provider.weeklyPlanningEnabled &&
        provider.provider == 'openrouter' &&
        (provider.apiKey?.trim().isNotEmpty ?? false);
  }

  Future<List<AthleteSession>> _loadNextWeekSuggestions() async {
    final now = DateTime.now();
    final nextWeekStart = _mondayOf(now).add(const Duration(days: 7));
    final nextWeekEnd = nextWeekStart.add(const Duration(days: 6));
    final sessions = await AthleteSessionRepository().getSessionsInRange(
      uid: widget.uid,
      startDate: _fmt(nextWeekStart),
      endDate: _fmt(nextWeekEnd),
    );
    return sessions.where((session) => _isAiPendingSuggestion(session)).toList()
      ..sort((a, b) => a.date.compareTo(b.date));
  }

  Future<void> _runAutoPlannerIfNeeded() async {
    if (_autoPlannerRan) return;
    _autoPlannerRan = true;
    try {
      final result =
          await AiCoachAutomationService().ensureNextWeekPlanIfDue(widget.uid);
      if (!mounted || !result.generated) return;
      setState(() {
        _nextWeekSuggestionsFuture = _loadNextWeekSuggestions();
        _upcomingFuture = _loadUpcoming();
        _weekStatsFuture = _loadWeekStats();
      });
      ModernSnackBar.showSuccess(
        context,
        'Plan IA semanal generado (${result.generatedSessions} sesiones)',
      );
    } catch (e) {
      debugPrint('[_PlanningTabState] auto planner error: $e');
    }
  }

  Future<void> _generateAiPlan() async {
    setState(() => _isGeneratingAiPlan = true);
    try {
      final result = await AiCoachWeeklyPlannerService().planNextWeek(widget.uid);
      if (!mounted) return;
      setState(() {
        _nextWeekSuggestionsFuture = _loadNextWeekSuggestions();
        _upcomingFuture = _loadUpcoming();
        _weekStatsFuture = _loadWeekStats();
      });
      ModernSnackBar.showSuccess(
        context,
        result.sessions.isEmpty
            ? 'No se han generado nuevas sugerencias para la próxima semana'
            : 'Plan IA generado (${result.sessions.length} sugerencias)',
      );
    } catch (e) {
      if (!mounted) return;
      ModernSnackBar.showError(
        context,
        'No se pudo generar el plan IA. ${e.toString().replaceFirst('Exception: ', '')}',
      );
    } finally {
      if (mounted) {
        setState(() => _isGeneratingAiPlan = false);
      }
    }
  }

  Future<void> _acceptAllAiSuggestions(List<AthleteSession> sessions) async {
    if (sessions.isEmpty) return;
    setState(() => _isAcceptingAiPlan = true);
    try {
      for (final session in sessions) {
        await AthleteSessionRepository().updateSuggestionStatus(
          uid: widget.uid,
          sessionId: session.id,
          status: AthleteSessionSuggestionStatus.accepted,
          responseNote: 'accepted_from_planning_tab',
        );
      }
      if (!mounted) return;
      setState(() {
        _nextWeekSuggestionsFuture = _loadNextWeekSuggestions();
        _upcomingFuture = _loadUpcoming();
        _weekStatsFuture = _loadWeekStats();
      });
      ModernSnackBar.showSuccess(context, 'Sugerencias IA aceptadas (${sessions.length})');
    } catch (e) {
      if (!mounted) return;
      ModernSnackBar.showError(context, 'No se pudieron aceptar las sugerencias IA');
    } finally {
      if (mounted) {
        setState(() => _isAcceptingAiPlan = false);
      }
    }
  }

  Future<void> _openAiSettings() async {
    await launchAiCoachOnboarding(
      context,
      onCompleted: () async {
        if (!mounted) return;
        setState(() {
          _aiEnabledFuture = _loadAiEnabled();
          _nextWeekSuggestionsFuture = _loadNextWeekSuggestions();
        });
      },
    );
  }

  @override
  void initState() {
    super.initState();
    _weekStatsFuture = _loadWeekStats();
    _volumeFuture =
        ProgressRepository().getWeeklyVolume(widget.uid, weeks: 8);
    _upcomingFuture = _loadUpcoming();
    _nextWeekSuggestionsFuture = _loadNextWeekSuggestions();
    _aiEnabledFuture = _loadAiEnabled();
    AiCoachRepository().getProfile(uid: widget.uid).then((profile) {
      if (mounted) {
        setState(() => _hasAiCoachProfile = profile != null);
        if (profile != null) _checkWeeklyFeedback();
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _runAutoPlannerIfNeeded();
    });
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

  Future<List<AthleteSession>> _loadUpcoming() async {
    try {
      final now = DateTime.now();
      final sessions = await AthleteSessionRepository()
          .streamSessionsInRange(
            uid: widget.uid,
            startDate: _fmt(now),
            endDate: _fmt(now.add(const Duration(days: 7))),
          )
          .first;
      return sessions
          .where((s) => s.status == AthleteSessionStatus.planned)
          .toList()
        ..sort((a, b) => a.date.compareTo(b.date));
    } catch (e) {
      debugPrint('Error cargando próximas sesiones: $e');
      return [];
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
                        color: AppColors.brand, strokeWidth: 2),
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
                    iconColor: AppColors.brand,
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
                        color: AppColors.brand, strokeWidth: 2),
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
          const _SectionTitle('PLAN IA SEMANAL'),
          const SizedBox(height: 10),
          FutureBuilder<bool>(
            future: _aiEnabledFuture,
            builder: (context, enabledSnap) {
              final aiEnabled = enabledSnap.data ?? false;
              return FutureBuilder<List<AthleteSession>>(
                future: _nextWeekSuggestionsFuture,
                builder: (context, suggestionsSnap) {
                  final suggestions = suggestionsSnap.data ?? const <AthleteSession>[];
                  final title = isDark ? Colors.white : const Color(0xFF1C1C1E);
                  final cardColor = isDark ? const Color(0xFF2A2333) : const Color(0xFFF5EEFF);
                  return Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: cardColor,
                      border: Border.all(color: const Color(0xFFD6B8FF)),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          aiEnabled
                              ? 'Sugerencias IA próxima semana: ${suggestions.length}'
                              : 'Configura OpenRouter para activar el plan IA',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: title,
                          ),
                        ),
                        if (aiEnabled && suggestions.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          ...suggestions.take(3).map((s) => Padding(
                                padding: const EdgeInsets.only(bottom: 4),
                                child: Text(
                                  '• ${DateFormat('EEE d', 'es_ES').format(DateTime.parse(s.date))}: ${_sessionTitleForCard(s)}',
                                  style: TextStyle(fontSize: 12, color: secondary),
                                ),
                              )),
                        ],
                        const SizedBox(height: 10),
                        if (_showFeedbackBanner && _hasAiCoachProfile)
                          Container(
                            margin: const EdgeInsets.fromLTRB(0, 0, 0, 12),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  AppColors.brand.withValues(alpha: 0.12),
                                  AppColors.brand.withValues(alpha: 0.04),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: AppColors.brand.withValues(alpha: 0.25),
                              ),
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(16),
                                onTap: () {
                                  MainShell.shellKey.currentState?.navigateTo(
                                    18,
                                    params: WeeklyFeedbackShellParams(
                                      weekStart: _currentWeekStart(),
                                      onCompleted: () => setState(
                                          () => _showFeedbackBanner = false),
                                    ),
                                  );
                                },
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: AppColors.brand
                                              .withValues(alpha: 0.12),
                                          borderRadius:
                                              BorderRadius.circular(10),
                                        ),
                                        child: Icon(
                                          Icons.rate_review_outlined,
                                          color: AppColors.brand,
                                          size: 20,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              '¿Cómo fue la semana?',
                                              style: TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w600,
                                                color: AppColors.textPrimary(
                                                    context),
                                              ),
                                            ),
                                            Text(
                                              'Cuéntale a tu coach cómo te has sentido',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: AppColors.textSecondary(
                                                    context),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Icon(
                                        Icons.chevron_right_rounded,
                                        color: AppColors.brand,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        if (_hasAiCoachProfile) ...[
                          Row(
                            children: [
                              Expanded(
                                child: FilledButton(
                                  onPressed: _isGeneratingAiPlan ? null : _generateAiPlan,
                                  style: FilledButton.styleFrom(
                                    backgroundColor: AppColors.brand,
                                    minimumSize: const Size(0, 38),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                  child: Text(_isGeneratingAiPlan ? 'Generando...' : 'Generar semana IA'),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: (!aiEnabled || suggestions.isEmpty || _isAcceptingAiPlan)
                                      ? null
                                      : () => _acceptAllAiSuggestions(suggestions),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: AppColors.brand,
                                    side: const BorderSide(color: AppColors.brand),
                                    minimumSize: const Size(0, 38),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                  child: Text(_isAcceptingAiPlan ? 'Aceptando...' : 'Aceptar todo'),
                                ),
                              ),
                            ],
                          ),
                        ] else ...[
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: () => launchAiCoachOnboarding(
                                context,
                                onCompleted: () async => setState(() => _hasAiCoachProfile = true),
                              ),
                              icon: const Icon(Icons.auto_awesome_rounded),
                              label: const Text('Configura tu entrenador IA'),
                            ),
                          ),
                        ],
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: _openAiSettings,
                            child: const Text('Configurar IA'),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
          const SizedBox(height: 24),

          RaceGoalsSection(uid: widget.uid),
          const SizedBox(height: 24),

          // ── Próximos 7 días ─────────────────────────────────────────
          const _SectionTitle('PRÓXIMOS 7 DÍAS'),
          const SizedBox(height: 10),
          FutureBuilder<List<AthleteSession>>(
            future: _upcomingFuture,
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const SizedBox(
                  height: 20,
                  child: Center(
                    child: SizedBox(
                      width: 20, height: 20,
                      child: CircularProgressIndicator(
                          color: AppColors.brand, strokeWidth: 2),
                    ),
                  ),
                );
              }
              final sessions = snap.data ?? [];
              final surfaceColor = isDark
                  ? const Color(0xFF1C1C1E)
                  : const Color(0xFFF2F2F7);
              final borderColor = AppColors.borderOf(context);
              if (sessions.isEmpty) {
                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: surfaceColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Center(
                    child: Text(
                      'Sin sesiones planificadas esta semana',
                      style: TextStyle(
                          fontSize: 14, color: Color(0xFF8E8E93)),
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              }
              return Column(
                children: sessions
                    .map((s) => _UpcomingSessionCard(
                          session: s,
                          uid: widget.uid,
                          isDark: isDark,
                          isToday: _esHoy(s.date),
                          surfaceColor: surfaceColor,
                          borderColor: borderColor,
                        ))
                    .toList(),
              );
            },
          ),
          const SizedBox(height: 16),

          // ── Botón planificar ────────────────────────────────────────
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.brand),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              icon: const Icon(Icons.add_rounded,
                  color: AppColors.brand),
              label: const Text('Planificar sesión',
                  style: TextStyle(
                      color: AppColors.brand,
                      fontSize: 15,
                      fontWeight: FontWeight.w600)),
              onPressed: () => Navigator.push(
                context,
                AppRoute(
                  page: WorkoutEditorScreen(
                    scheduledDate: DateTime.now(),
                    onSave: (session) =>
                        _onWorkoutSaved(context, session, widget.uid),
                  ),
                ),
              ),
            ),
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
                  color: AppColors.brand, size: 20),
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
                backgroundColor: AppColors.brand,
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
                      fontSize: 14, fontWeight: FontWeight.w600),
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
                  fontWeight: FontWeight.w600,
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
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
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
                    fontSize: 15, fontWeight: FontWeight.w600)),
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
                    fontWeight: FontWeight.w600,
                    color: AppColors.brand,
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
            ? AppColors.brand
            : AppColors.brand.withValues(alpha: 0.4)
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
// _UpcomingSessionCard
// ─────────────────────────────────────────────────────────────────────────────

class _UpcomingSessionCard extends StatelessWidget {
  final AthleteSession session;
  final String uid;
  final bool isDark;
  final bool isToday;
  final Color surfaceColor;
  final Color borderColor;

  const _UpcomingSessionCard({
    required this.session,
    required this.uid,
    required this.isDark,
    required this.isToday,
    required this.surfaceColor,
    required this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    final titleColor = isDark ? Colors.white : const Color(0xFF1C1C1E);
    final date = DateTime.tryParse(session.date);
    final dayNum = date != null ? '${date.day}' : '?';
    final monthStr = date != null
        ? DateFormat('MMM', 'es_ES').format(date)
        : '';
    final categoryLabel = session.category != null
        ? SessionCategoryX.fromValue(session.category!).label
        : 'Sesión';

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 44,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(dayNum,
                    style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: AppColors.brand)),
                Text(monthStr,
                    style: const TextStyle(
                        fontSize: 11, color: Color(0xFF8E8E93))),
              ],
            ),
          ),
          const SizedBox(width: 8),
          VerticalDivider(
              color: borderColor, width: 1, thickness: 1),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(categoryLabel,
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: titleColor)),
                if (session.blocks.isNotEmpty)
                  Text('${session.blocks.length} series',
                      style: const TextStyle(
                          fontSize: 12, color: Color(0xFF8E8E93))),
                if (session.time != null)
                  Text(session.time!,
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.brand)),
              ],
            ),
          ),
          if (isToday && session.blocks.isNotEmpty)
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.brand,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12),
                minimumSize: const Size(0, 32),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () =>
                  _launchGuidedSession(context, session, uid),
              child: const Text('Ejecutar',
                  style: TextStyle(fontSize: 13)),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _RaceCountdownCard
// ─────────────────────────────────────────────────────────────────────────────

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
      ..color = AppColors.brand
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final dotPaint = Paint()
      ..color = AppColors.brandLight
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
    if ((s.title ?? '').trim().isNotEmpty) {
      return s.title!.trim();
    }
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
                              if (_isAiPendingSuggestion(s))
                                const Text(
                                  'Sugerencia IA pendiente',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFFB084F5),
                                    fontWeight: FontWeight.w600,
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
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              OutlinedButton(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppColors.brand,
                                  side: const BorderSide(
                                      color: AppColors.brand, width: 0.8),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12),
                                  minimumSize: const Size(0, 34),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                onPressed: () {
                                  Navigator.pop(context);
                                  final sessionDate =
                                      DateTime.tryParse(s.date);
                                  Navigator.push(
                                    context,
                                    AppRoute(
                                      page: WorkoutEditorScreen(
                                        scheduledDate: sessionDate,
                                        onSave: (session) async {
                                          await _onWorkoutSaved(
                                              context, session, uid);
                                          if (_isAiPendingSuggestion(s)) {
                                            try {
                                              await AthleteSessionRepository()
                                                  .updateSuggestionStatus(
                                                uid: uid,
                                                sessionId: s.id,
                                                status: AthleteSessionSuggestionStatus.edited,
                                                responseNote: 'edited_from_day_sheet',
                                              );
                                            } catch (_) {}
                                          }
                                        },
                                      ),
                                    ),
                                  );
                                },
                                child: const Text('Editar',
                                    style: TextStyle(fontSize: 13)),
                              ),
                              const SizedBox(width: 8),
                              FilledButton(
                                style: FilledButton.styleFrom(
                                  backgroundColor: AppColors.brand,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12),
                                  minimumSize: const Size(0, 34),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                onPressed: () {
                                  Navigator.pop(context);
                                  if (_isAiPendingSuggestion(s)) {
                                    AthleteSessionRepository().updateSuggestionStatus(
                                      uid: uid,
                                      sessionId: s.id,
                                      status: AthleteSessionSuggestionStatus.accepted,
                                      responseNote: 'accepted_from_day_sheet_execute',
                                    );
                                  }
                                  _launchGuidedSession(context, s, uid);
                                },
                                child: const Text('Ejecutar',
                                    style: TextStyle(fontSize: 13)),
                              ),
                            ],
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
                debugPrint('🟣 Abriendo WorkoutEditorScreen desde _DayActionSheet');
                Navigator.pop(context);
                Navigator.push(
                  context,
                  AppRoute(
                    page: WorkoutEditorScreen(
                      scheduledDate: day,
                      onSave: (session) =>
                          _onWorkoutSaved(context, session, uid),
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.add_rounded),
              label: const Text('Planificar sesión'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.brand,
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
                foregroundColor: AppColors.brand,
                side: const BorderSide(color: AppColors.brand),
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
                final nav = Navigator.of(context);
                final navContext = nav.context;
                nav.pop();
                showRaceGoalSheet(navContext, uid: uid, initialDate: day);
              },
              icon: const Icon(Icons.flag_rounded, size: 18),
              label: const Text('Marcar competición'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.effort,
                side: const BorderSide(color: AppColors.effort),
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
// _onWorkoutSaved — persiste WorkoutSession y crea AthleteSession planificada
// ─────────────────────────────────────────────────────────────────────────────

Future<void> _onWorkoutSaved(
  BuildContext context,
  WorkoutSession session,
  String uid,
) async {
  // Persiste la estructura completa del workout (colección templates).
  try {
    await TrainingTemplatesRepository().saveWorkoutSession(session);
  } catch (e) {
    debugPrint('[_onWorkoutSaved] saveWorkoutSession error: $e');
  }

  // Si tiene fecha planificada, crea también un AthleteSession para que
  // el calendario lo muestre. El stream del viewmodel lo recoge automáticamente.
  final scheduledDate = session.scheduledDate;
  if (scheduledDate == null) return;

  final String dateStr =
      '${scheduledDate.year}-'
      '${scheduledDate.month.toString().padLeft(2, '0')}-'
      '${scheduledDate.day.toString().padLeft(2, '0')}';

  final athleteSession = AthleteSession(
    id: session.id,
    uid: uid,
    date: dateStr,
    status: AthleteSessionStatus.planned,
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  );

  try {
    await AthleteSessionRepository().createSession(athleteSession);
  } catch (e) {
    debugPrint('[_onWorkoutSaved] createSession error: $e');
    if (context.mounted) {
      ModernSnackBar.showError(context, 'Error al guardar la sesión planificada');
    }
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
    colorValue: AppColors.brand.toARGB32(),
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
// _DayCircle — día con puntos de estado opcionales
// ─────────────────────────────────────────────────────────────────────────────

bool _isAiPendingSuggestion(AthleteSession session) {
  final suggestion = session.suggestion;
  return suggestion?.origin == AthleteSessionOrigin.ai &&
      suggestion?.status == AthleteSessionSuggestionStatus.suggested;
}

String _sessionTitleForCard(AthleteSession session) {
  if ((session.title ?? '').trim().isNotEmpty) {
    return session.title!.trim();
  }
  if (session.category != null) {
    return SessionCategoryX.fromValue(session.category!).label;
  }
  return 'Sesión';
}

List<Color> _dotsForDay(
  List<AthleteSession> sessions,
  bool isSelected, {
  bool hasRaceGoal = false,
}) {
  final colors = <Color>[];
  final hasCompleted =
      sessions.any((s) => s.status == AthleteSessionStatus.completed);
  final hasPlanned = sessions.any((s) =>
      s.status == AthleteSessionStatus.planned &&
      !_isAiPendingSuggestion(s) &&
      s.category != 'competicion');
  final hasAiPending = sessions.any((s) =>
      s.status == AthleteSessionStatus.planned &&
      _isAiPendingSuggestion(s));
  final hasRace =
      hasRaceGoal || sessions.any((s) => s.category == 'competicion');

  if (hasCompleted) {
    colors.add(isSelected ? Colors.white : AppColors.rpeLow);
  }
  if (hasPlanned) {
    colors.add(isSelected
        ? Colors.white.withValues(alpha: 0.7)
        : AppColors.brand);
  }
  if (hasAiPending) {
    colors.add(isSelected
        ? Colors.white.withValues(alpha: 0.85)
        : const Color(0xFFB084F5));
  }
  if (hasRace) {
    colors.add(isSelected ? Colors.white : AppColors.rpeMax);
  }
  return colors.take(3).toList();
}

class _DayCircle extends StatelessWidget {
  final int day;
  final bool isToday;
  final bool isSelected;
  final List<AthleteSession> sessions;

  final bool hasRaceGoal;

  const _DayCircle({
    required this.day,
    required this.isToday,
    required this.isSelected,
    this.sessions = const [],
    this.hasRaceGoal = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final defaultColor =
        isDark ? Colors.white : const Color(0xFF1C1C1E);
    final dots = _dotsForDay(sessions, isSelected, hasRaceGoal: hasRaceGoal);

    final Color textColor;
    final FontWeight textWeight;
    BoxDecoration? circleDecoration;

    if (isSelected) {
      textColor = Colors.white;
      textWeight = FontWeight.w600;
      circleDecoration = const BoxDecoration(
        color: AppColors.brand,
        shape: BoxShape.circle,
      );
    } else if (isToday) {
      textColor = AppColors.brand;
      textWeight = FontWeight.w600;
      circleDecoration = BoxDecoration(
        color: AppColors.brand.withValues(alpha: 0.15),
        shape: BoxShape.circle,
      );
    } else {
      textColor = defaultColor;
      textWeight = FontWeight.w400;
      circleDecoration = null;
    }

    return SizedBox(
      width: 40,
      height: 44,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: circleDecoration,
            child: Text(
              '$day',
              style: TextStyle(
                fontSize: 15,
                fontWeight: textWeight,
                color: textColor,
              ),
            ),
          ),
          if (dots.isNotEmpty) ...[
            const SizedBox(height: 3),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: dots
                  .map((c) => Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 1.5),
                        child: _SessionDot(color: c),
                      ))
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }
}

class _SessionDot extends StatelessWidget {
  final Color color;
  const _SessionDot({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 5,
      height: 5,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _EmptyCalendarHint
// ─────────────────────────────────────────────────────────────────────────────

// ─────────────────────────────────────────────────────────────────────────────
// _RpeVsPaceHalfCard
// ─────────────────────────────────────────────────────────────────────────────

class _RpeVsPaceHalfCard extends StatelessWidget {
  final String label;
  final String pace;
  final double rpe;
  final Color? paceColor;
  final Color? rpeColor;
  final bool isDark;

  const _RpeVsPaceHalfCard({
    required this.label,
    required this.pace,
    required this.rpe,
    this.paceColor,
    this.rpeColor,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final bg = isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE5E5EA);
    final labelColor = isDark ? const Color(0xFF8E8E93) : const Color(0xFF6C6C70);
    final valuePaceColor = paceColor ?? (isDark ? Colors.white : const Color(0xFF1C1C1E));
    final valueRpeColor  = rpeColor  ?? (isDark ? Colors.white : const Color(0xFF1C1C1E));

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 10, color: labelColor)),
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(Icons.speed_rounded, size: 12, color: labelColor),
              const SizedBox(width: 3),
              Text(pace,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: valuePaceColor,
                  )),
            ],
          ),
          const SizedBox(height: 2),
          Row(
            children: [
              Icon(Icons.favorite_rounded, size: 12, color: labelColor),
              const SizedBox(width: 3),
              Text('RPE ${rpe.toStringAsFixed(1)}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: valueRpeColor,
                  )),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _EmptyCalendarHint extends StatelessWidget {
  final String uid;
  const _EmptyCalendarHint({required this.uid});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.calendar_month_outlined,
              color: Color(0xFF8E8E93), size: 40),
          const SizedBox(height: 8),
          const Text(
            'Sin sesiones planificadas',
            style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: Color(0xFF8E8E93)),
          ),
          const SizedBox(height: 4),
          const Text(
            'Toca un día para planificar tu entrenamiento',
            style: TextStyle(fontSize: 13, color: Color(0xFF8E8E93)),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.brand,
              side: const BorderSide(color: AppColors.brand),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            icon: const Icon(Icons.add_rounded, color: AppColors.brand),
            label: const Text('Planificar sesión',
                style: TextStyle(color: AppColors.brand)),
            onPressed: () {
              Navigator.push(
                context,
                AppRoute(
                  page: WorkoutEditorScreen(
                    scheduledDate: DateTime.now(),
                    onSave: (session) =>
                        _onWorkoutSaved(context, session, uid),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
