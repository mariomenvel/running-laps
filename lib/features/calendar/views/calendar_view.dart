import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:running_laps/core/theme/app_colors.dart';
import 'package:running_laps/core/theme/app_theme.dart';
import 'package:running_laps/core/utils/app_transitions.dart';
import 'package:running_laps/core/widgets/standard_table_calendar.dart';
import 'package:running_laps/features/athlete/data/athlete_session_model.dart';
import 'package:running_laps/features/calendar/viewmodels/calendar_view_model.dart';
import 'package:running_laps/core/widgets/main_shell.dart';
import 'package:running_laps/features/templates/data/template_models.dart';
import 'package:running_laps/features/training/data/entrenamiento.dart';
import 'package:running_laps/features/training/views/training_start_view.dart';
import 'package:running_laps/features/templates/data/athlete_session_mapper.dart';

class CalendarView extends StatefulWidget {
  const CalendarView({super.key});

  @override
  State<CalendarView> createState() => _CalendarViewState();
}

class _CalendarViewState extends State<CalendarView> {
  late final CalendarViewModel _vm;
  int _focusedYear = DateTime.now().year;

  @override
  void initState() {
    super.initState();
    _vm = CalendarViewModel(userId: FirebaseAuth.instance.currentUser!.uid);
    _vm.loadAll();
  }

  @override
  void dispose() {
    _vm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: _vm.isLoading,
      builder: (_, loading, __) {
        if (loading) return _buildSkeleton();
        return ValueListenableBuilder<bool>(
          valueListenable: _vm.isAthleteMode,
          builder: (_, isAthlete, __) {
            return Column(
              children: [
                _buildViewSelector(isAthlete),
                Expanded(
                  child: ValueListenableBuilder<CalendarViewType>(
                    valueListenable: _vm.viewType,
                    builder: (_, vt, __) {
                      switch (vt) {
                        case CalendarViewType.weekly:
                          return _buildWeeklyView(isAthlete);
                        case CalendarViewType.monthly:
                          return _buildMonthlyView(isAthlete);
                        case CalendarViewType.season:
                          return _buildSeasonView(isAthlete);
                      }
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ── Skeleton ──────────────────────────────────────────────────────────────

  Widget _buildSkeleton() {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.l),
      child: Column(children: [
        const SizedBox(height: AppSpacing.m),
        _skeletonBox(height: 44),
        const SizedBox(height: AppSpacing.l),
        _skeletonBox(height: 300),
        const SizedBox(height: AppSpacing.l),
        _skeletonBox(height: 120),
      ]),
    );
  }

  Widget _skeletonBox({required double height}) => Container(
    width: double.infinity,
    height: height,
    decoration: BoxDecoration(
      color: AppColors.surfaceOf(context),
      borderRadius: BorderRadius.circular(AppDimens.cardRadius),
    ),
  );

  // ── Selector de vista ─────────────────────────────────────────────────────

  Widget _buildViewSelector(bool isAthlete) {
    return ValueListenableBuilder<CalendarViewType>(
      valueListenable: _vm.viewType,
      builder: (_, current, __) => Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.l,
          vertical: AppSpacing.m,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _ViewTab('Semanal',   CalendarViewType.weekly,  current == CalendarViewType.weekly,  _vm),
            const SizedBox(width: AppSpacing.s),
            _ViewTab('Mensual',   CalendarViewType.monthly, current == CalendarViewType.monthly, _vm),
            if (isAthlete) ...[
              const SizedBox(width: AppSpacing.s),
              _ViewTab('Temporada', CalendarViewType.season, current == CalendarViewType.season, _vm),
            ],
          ],
        ),
      ),
    );
  }

  // ── Vista mensual — grid de semanas ──────────────────────────────────────

  Widget _buildMonthlyView(bool isAthlete) {
    return ValueListenableBuilder<DateTime>(
      valueListenable: _vm.focusedMonth,
      builder: (_, focused, __) => ValueListenableBuilder<List<Entrenamiento>>(
        valueListenable: _vm.allWorkouts,
        builder: (_, workouts, __) => ValueListenableBuilder<Map<String, List<AthleteSession>>>(
          valueListenable: _vm.sessionsByDate,
          builder: (_, sessionsByDate, __) {
            final weeks = _getWeeksOfMonth(focused.year, focused.month);

            return Column(
              children: [
                // ── Cabecera mes + navegación ─────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.l,
                    vertical: AppSpacing.m,
                  ),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () {
                          final prev = DateTime(focused.year, focused.month - 1);
                          _vm.onMonthChanged(prev);
                        },
                        child: Icon(Icons.chevron_left, color: AppColors.iconMutedOf(context)),
                      ),
                      Expanded(
                        child: Text(
                          _monthYearLabel(focused),
                          style: AppTypography.h3.copyWith(color: AppColors.textPrimary(context)),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          final next = DateTime(focused.year, focused.month + 1);
                          _vm.onMonthChanged(next);
                        },
                        child: Icon(Icons.chevron_right, color: AppColors.iconMutedOf(context)),
                      ),
                    ],
                  ),
                ),

                // ── Grid de semanas ───────────────────────────────────
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.l,
                      vertical: AppSpacing.s,
                    ),
                    itemCount: weeks.length,
                    itemBuilder: (_, i) => _buildWeekRow(
                      week:           weeks[i],
                      month:          focused.month,
                      trimp:          _calcWeekTrimp(weeks[i], workouts),
                      hasCompetition: _weekHasCompetition(weeks[i], workouts, sessionsByDate),
                      sessions:       sessionsByDate,
                      trainings:      workouts,
                      isAthlete:      isAthlete,
                    ),
                  ),
                ),

                // ── Leyenda ───────────────────────────────────────────
                _buildMonthlyLegend(),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildWeekRow({
    required List<DateTime> week,
    required int month,
    required double trimp,
    required bool hasCompetition,
    required Map<String, List<AthleteSession>> sessions,
    required List<Entrenamiento> trainings,
    required bool isAthlete,
  }) {
    final barColor = _colorForWeekLoad(trimp, hasCompetition);
    final volumeKm = _calcWeekVolumeKm(week, trainings);

    // Contar sesiones/entrenamientos de la semana
    int sessionCount = 0;
    for (final day in week) {
      final key = _normalize(day);
      if (isAthlete) {
        sessionCount += (sessions[key] ?? []).length;
      } else {
        if (trainings.any((w) => _normalize(w.fecha) == key)) sessionCount++;
      }
    }

    return GestureDetector(
      onTap: () => _showMonthlyWeekDetailSheet(
        week: week, sessions: sessions, trainings: trainings, isAthlete: isAthlete,
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.m),
        decoration: BoxDecoration(
          color: AppColors.surfaceOf(context),
          border: Border.all(color: AppColors.borderOf(context), width: 0.5),
          borderRadius: BorderRadius.circular(AppDimens.cardRadius),
        ),
        child: Column(
          children: [
            // Barra de carga TRIMP
            Container(
              height: 6,
              decoration: BoxDecoration(
                color: (trimp > 0 || hasCompetition) ? barColor : AppColors.borderOf(context),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(AppDimens.cardRadius)),
              ),
            ),

            // Días lun-dom
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.m,
                vertical: AppSpacing.m,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: week.map((day) {
                  final inMonth  = day.month == month;
                  final isToday  = _normalize(day) == _normalize(DateTime.now());
                  final hasData  = isAthlete
                      ? (sessions[_normalize(day)] ?? []).isNotEmpty
                      : trainings.any((w) => _normalize(w.fecha) == _normalize(day));

                  return Column(
                    children: [
                      Text(
                        _dayAbbr(day.weekday)[0],
                        style: AppTypography.small.copyWith(
                          color: AppColors.textSecondary(context),
                          fontSize: 10,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: isToday ? AppColors.brand : Colors.transparent,
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            '${day.day}',
                            style: AppTypography.small.copyWith(
                              color: isToday
                                  ? Colors.white
                                  : inMonth
                                      ? AppColors.textPrimary(context)
                                      : AppColors.iconMutedOf(context),
                              fontWeight: inMonth ? FontWeight.w600 : FontWeight.normal,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 3),
                      // Punto indicador de actividad
                      Container(
                        width: 4,
                        height: 4,
                        decoration: BoxDecoration(
                          color: hasData
                              ? (inMonth ? AppColors.brand : AppColors.brand.withOpacity(0.3))
                              : Colors.transparent,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),

            // Resumen km + sesiones
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.l,
                vertical: AppSpacing.s,
              ),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(color: AppColors.borderOf(context), width: 0.5),
                ),
              ),
              child: Row(
                children: [
                  Text(
                    volumeKm > 0 ? '${volumeKm.toStringAsFixed(1)} km' : '– km',
                    style: AppTypography.small.copyWith(
                      color: volumeKm > 0
                          ? AppColors.textPrimary(context)
                          : AppColors.iconMutedOf(context),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    sessionCount > 0
                        ? '$sessionCount ${sessionCount == 1 ? 'sesión' : 'sesiones'}'
                        : 'Descanso',
                    style: AppTypography.small.copyWith(
                      color: sessionCount > 0
                          ? AppColors.textSecondary(context)
                          : AppColors.iconMutedOf(context),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.s),
                  Icon(Icons.chevron_right, size: 14, color: AppColors.iconMutedOf(context)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showMonthlyWeekDetailSheet({
    required List<DateTime> week,
    required Map<String, List<AthleteSession>> sessions,
    required List<Entrenamiento> trainings,
    required bool isAthlete,
  }) {
    final monday = week.first;
    final sunday = week.last;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.92,
        expand: false,
        builder: (_, ctrl) => SingleChildScrollView(
          controller: ctrl,
          padding: const EdgeInsets.all(AppSpacing.l),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36, height: 4,
                  margin: const EdgeInsets.only(bottom: AppSpacing.l),
                  decoration: BoxDecoration(
                    color: AppColors.borderOf(context),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Text(
                _formatWeekRange(monday, sunday),
                style: AppTypography.h3.copyWith(color: AppColors.textPrimary(context)),
              ),
              const SizedBox(height: AppSpacing.l),
              ...week.map((day) {
                final key        = _normalize(day);
                final daySessions = sessions[key] ?? [];
                final dayWorkouts = trainings.where((w) => _normalize(w.fecha) == key).toList();
                final hasContent  = isAthlete ? daySessions.isNotEmpty : dayWorkouts.isNotEmpty;

                return Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.m),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 40,
                        child: Column(
                          children: [
                            Text(
                              _dayAbbr(day.weekday),
                              style: AppTypography.small.copyWith(
                                color: AppColors.textSecondary(context),
                                fontSize: 10,
                              ),
                            ),
                            Text(
                              '${day.day}',
                              style: AppTypography.body.copyWith(
                                color: AppColors.textPrimary(context),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: AppSpacing.m),
                      Expanded(
                        child: !hasContent
                            ? Text(
                                'Descanso',
                                style: AppTypography.small.copyWith(
                                  color: AppColors.iconMutedOf(context),
                                  fontStyle: FontStyle.italic,
                                ),
                              )
                            : Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: isAthlete
                                    ? daySessions.map((s) {
                                        final cat = s.title?.isNotEmpty == true
                                            ? s.title!
                                            : s.category != null
                                                ? SessionCategoryX.fromValue(s.category!).label
                                                : 'Entrenamiento';
                                        return Row(children: [
                                          Container(
                                            width: 6, height: 6,
                                            margin: const EdgeInsets.only(right: 6, top: 2),
                                            decoration: BoxDecoration(
                                              color: _statusColor(s.status),
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                          Text(cat,
                                              style: AppTypography.body.copyWith(
                                                  color: AppColors.textPrimary(context))),
                                        ]);
                                      }).toList()
                                    : dayWorkouts.map((w) {
                                        final km = w.distanciaTotalM() / 1000.0;
                                        return Row(children: [
                                          Container(
                                            width: 6, height: 6,
                                            margin: const EdgeInsets.only(right: 6, top: 2),
                                            decoration: const BoxDecoration(
                                              color: AppColors.brand,
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                          Text(
                                            '${w.titulo.isNotEmpty ? w.titulo : 'Entrenamiento'}'
                                            ' · ${km.toStringAsFixed(1)} km',
                                            style: AppTypography.body.copyWith(
                                                color: AppColors.textPrimary(context)),
                                          ),
                                        ]);
                                      }).toList(),
                              ),
                      ),
                    ],
                  ),
                );
              }),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  // ── Helpers vista mensual ─────────────────────────────────────────────────

  List<List<DateTime>> _getWeeksOfMonth(int year, int month) {
    final firstDay = DateTime(year, month, 1);
    final lastDay  = DateTime(year, month + 1, 0);
    final weeks    = <List<DateTime>>[];

    var weekStart = firstDay.subtract(Duration(days: firstDay.weekday - 1));

    while (!weekStart.isAfter(lastDay)) {
      if (_monthForWeek(weekStart) == month) {
        weeks.add(List.generate(7, (i) => weekStart.add(Duration(days: i))));
      }
      weekStart = weekStart.add(const Duration(days: 7));
    }
    return weeks;
  }

  // Returns the month (1-12) this week "belongs to": whichever month has more days.
  // weekEnd.day == days elapsed in the second month; (7 - weekEnd.day) == days in first.
  int _monthForWeek(DateTime weekStart) {
    final weekEnd = weekStart.add(const Duration(days: 6));
    if (weekStart.month == weekEnd.month) return weekStart.month;
    final daysInEndMonth   = weekEnd.day;       // e.g. 4 → 4 days in Jan
    final daysInStartMonth = 7 - daysInEndMonth; // e.g. 3 → 3 days in Dec
    return daysInStartMonth >= daysInEndMonth ? weekStart.month : weekEnd.month;
  }

  double _calcWeekVolumeKm(List<DateTime> week, List<Entrenamiento> workouts) {
    double total = 0;
    for (final day in week) {
      final key = _normalize(day);
      for (final w in workouts) {
        if (_normalize(w.fecha) == key) {
          total += w.distanciaTotalM() / 1000.0;
        }
      }
    }
    return total;
  }

  String _monthYearLabel(DateTime d) {
    const meses = [
      'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
      'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre',
    ];
    return '${meses[d.month - 1]} ${d.year}';
  }

  // Helper para el border top en Container decoration
  Widget _buildDayContent(bool isAthlete) =>
      isAthlete ? _buildAthleteDayContent() : _buildRecreativoDayContent();

  Widget _buildAthleteDayContent() {
    return ValueListenableBuilder<DateTime>(
      valueListenable: _vm.selectedDay,
      builder: (_, day, __) => ValueListenableBuilder<List<AthleteSession>>(
        valueListenable: _vm.selectedDaySessions,
        builder: (_, sessions, __) => SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.l, vertical: AppSpacing.m),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_formatDaySpanish(day), style: AppTypography.h3.copyWith(color: AppColors.textPrimary(context))),
              const SizedBox(height: AppSpacing.m),
              if (sessions.isEmpty)
                _buildEmptyAthleteDay(day)
              else
                ...sessions.map((s) => _buildSessionCard(s, day)),
              const SizedBox(height: 100),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRecreativoDayContent() {
    return ValueListenableBuilder<DateTime>(
      valueListenable: _vm.selectedDay,
      builder: (_, day, __) => ValueListenableBuilder<List<Entrenamiento>>(
        valueListenable: _vm.selectedDayWorkouts,
        builder: (_, workouts, __) => SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.l, vertical: AppSpacing.m),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_formatDaySpanish(day), style: AppTypography.h3.copyWith(color: AppColors.textPrimary(context))),
              const SizedBox(height: AppSpacing.m),
              if (workouts.isEmpty) _buildEmptyRecreativoDay() else ...workouts.map(_buildWorkoutCard),
              const SizedBox(height: AppSpacing.xl),
              _buildAthleteModeCta(),
              const SizedBox(height: 100),
            ],
          ),
        ),
      ),
    );
  }

  // ── Vista semanal ─────────────────────────────────────────────────────────

  Widget _buildWeeklyView(bool isAthlete) {
    return ValueListenableBuilder<List<DateTime>>(
      valueListenable: _vm.weekDays,
      builder: (_, days, __) {
        if (days.isEmpty) return const SizedBox.shrink();
        final monday = days.first;
        final sunday = days.last;
        final weekNum = _weekOfYear(monday);

        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.l),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Navegación de semana ────────────────────────────────
              Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.chevron_left, color: AppColors.iconMutedOf(context)),
                    onPressed: () => _vm.navigateWeek(-7),
                  ),
                  Expanded(
                    child: Column(
                      children: [
                        Text(
                          'Semana $weekNum',
                          style: AppTypography.h3.copyWith(color: AppColors.textPrimary(context)),
                          textAlign: TextAlign.center,
                        ),
                        Text(
                          _formatWeekRange(monday, sunday),
                          style: AppTypography.small.copyWith(color: AppColors.textSecondary(context)),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.chevron_right, color: AppColors.iconMutedOf(context)),
                    onPressed: () => _vm.navigateWeek(7),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.s),

              // ── Días de la semana ───────────────────────────────────
              if (isAthlete)
                ValueListenableBuilder<Map<String, List<AthleteSession>>>(
                  valueListenable: _vm.weekSessionsByDay,
                  builder: (_, byDay, __) => Column(
                    children: days.map((day) {
                      final key = _normalize(day);
                      return _buildWeekDayCard(
                        day: day,
                        sessions: byDay[key] ?? [],
                        workouts: const [],
                        isAthlete: true,
                      );
                    }).toList(),
                  ),
                )
              else
                ValueListenableBuilder<Map<String, List<Entrenamiento>>>(
                  valueListenable: _vm.weekWorkoutsByDay,
                  builder: (_, byDay, __) => Column(
                    children: days.map((day) {
                      final key = _normalize(day);
                      return _buildWeekDayCard(
                        day: day,
                        sessions: const [],
                        workouts: byDay[key] ?? [],
                        isAthlete: false,
                      );
                    }).toList(),
                  ),
                ),

              // ── Resumen semanal (atleta) ────────────────────────────
              if (isAthlete) ...[
                const SizedBox(height: AppSpacing.xl),
                _buildWeekSummary(),
              ],
              const SizedBox(height: 100),
            ],
          ),
        );
      },
    );
  }

  Widget _buildWeekDayCard({
    required DateTime day,
    required List<AthleteSession> sessions,
    required List<Entrenamiento> workouts,
    required bool isAthlete,
  }) {
    final now     = DateTime.now();
    final isToday = day.year == now.year && day.month == now.month && day.day == now.day;

    void onDayTap() {
      try {
        if (isAthlete) {
          final planned = sessions
              .where((s) => s.status == AthleteSessionStatus.planned)
              .firstOrNull;
          if (planned != null) {
            final workoutSession = mapAthleteSessionToWorkout(planned);
            if (workoutSession != null) {
              MainShell.shellKey.currentState?.navigateTo(
                16,
                params: PreExecutionShellParams(
                  session: workoutSession,
                  athleteSession: planned,
                ),
              );
              return;
            }
          }
          // Sin sesión planificada → editor para crear nueva
          MainShell.shellKey.currentState?.navigateTo(
            13,
            params: AthleteSessionShellParams(
              date: _normalize(day),
              session: null,
            ),
          );
        } else {
          Navigator.push(context, AppRoute(page: const TrainingStartView()));
        }
      } catch (e, st) {
        debugPrint('[CalendarView] onDayTap ERROR: $e');
        debugPrint('[CalendarView] stack: $st');
      }
    }

    Widget actionButton = const SizedBox.shrink();
    if (isAthlete) {
      if (sessions.isEmpty) {
        actionButton = GestureDetector(
          onTap: onDayTap,
          child: const Icon(Icons.add_circle_outline, color: AppColors.brand, size: 24),
        );
      } else if (sessions.any((s) => s.status == AthleteSessionStatus.planned)) {
        actionButton = GestureDetector(
          onTap: () {
            final planned = sessions
                .where((s) => s.status == AthleteSessionStatus.planned)
                .firstOrNull;
            if (planned != null) {
              final workoutSession = mapAthleteSessionToWorkout(planned);
              if (workoutSession != null) {
                MainShell.shellKey.currentState?.navigateTo(
                  16,
                  params: PreExecutionShellParams(
                    session: workoutSession,
                    athleteSession: planned,
                  ),
                );
                return;
              }
            }
            // Fallback si no hay sesión planificada o mapeo falla
            Navigator.push(context, AppRoute(page: const TrainingStartView()));
          },
          child: const Icon(Icons.play_circle_outline, color: AppColors.brand, size: 28),
        );
      } else if (sessions.every((s) => s.status == AthleteSessionStatus.completed)) {
        actionButton = Container(
          width: 24,
          height: 24,
          decoration: const BoxDecoration(color: AppColors.rpeLow, shape: BoxShape.circle),
          child: const Center(
            child: Icon(Icons.check, color: Colors.white, size: 16),
          ),
        );
      }
    }

    return InkWell(
      onTap: onDayTap,
      borderRadius: BorderRadius.circular(AppDimens.cardRadius),
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.s),
        decoration: BoxDecoration(
          color: AppColors.surfaceOf(context),
          border: Border.all(
            color: isToday ? AppColors.brand : AppColors.borderOf(context),
            width: isToday ? 1.5 : 0.5,
          ),
          borderRadius: BorderRadius.circular(AppDimens.cardRadius),
        ),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // ── Contenido del día ───────────────────────────────────────
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.m),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Cabecera del día
                      Row(
                        children: [
                          SizedBox(
                            width: 36,
                            child: Text(
                              _dayAbbr(day.weekday),
                              style: AppTypography.small.copyWith(color: AppColors.textSecondary(context)),
                            ),
                          ),
                          Text(
                            '${day.day}',
                            style: AppTypography.body.copyWith(
                              color: AppColors.textPrimary(context),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (isToday) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(color: AppColors.brand, borderRadius: BorderRadius.circular(10)),
                              child: const Text('HOY', style: TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.w600)),
                            ),
                          ],
                        ],
                      ),

                      // Contenido
                      if (isAthlete) ...[
                        if (sessions.isEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: AppSpacing.s),
                            child: Text(
                              'Descanso',
                              style: AppTypography.small.copyWith(
                                color: AppColors.textSecondary(context),
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          )
                        else
                          ...sessions.map((s) => Padding(
                            padding: const EdgeInsets.only(top: AppSpacing.s),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      width: 6, height: 6,
                                      decoration: BoxDecoration(
                                        color: _statusColor(s.status),
                                        borderRadius: BorderRadius.circular(3),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        s.title?.isNotEmpty == true
                                            ? s.title!
                                            : s.category != null
                                                ? SessionCategoryX.fromValue(s.category!).label
                                                : 'Entrenamiento',
                                        style: AppTypography.body.copyWith(color: AppColors.textPrimary(context)),
                                      ),
                                    ),
                                  ],
                                ),
                                if (s.blocks.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(left: 14, top: 2),
                                    child: Text(
                                      _blocksDescription(s.blocks),
                                      style: AppTypography.small.copyWith(color: AppColors.textSecondary(context)),
                                    ),
                                  ),
                              ],
                            ),
                          )),
                      ] else ...[
                        if (workouts.isEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: AppSpacing.s),
                            child: Text(
                              'Sin entrenamiento',
                              style: AppTypography.small.copyWith(
                                color: AppColors.textSecondary(context),
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          )
                        else
                          ...workouts.map((w) => Padding(
                            padding: const EdgeInsets.only(top: AppSpacing.s),
                            child: Row(
                              children: [
                                Container(
                                  width: 6, height: 6,
                                  decoration: BoxDecoration(color: AppColors.brand, borderRadius: BorderRadius.circular(3)),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    w.titulo.isNotEmpty ? w.titulo : 'Entrenamiento libre',
                                    style: AppTypography.body.copyWith(color: AppColors.textPrimary(context)),
                                  ),
                                ),
                                Text(
                                  '${(w.distanciaTotalM() / 1000).toStringAsFixed(1)} km',
                                  style: AppTypography.small.copyWith(color: AppColors.textSecondary(context)),
                                ),
                              ],
                            ),
                          )),
                      ],
                    ],
                  ),
                ),
              ),

              // ── Botón centrado verticalmente respecto al card completo ──
              Padding(
                padding: const EdgeInsets.only(right: AppSpacing.l),
                child: actionButton,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWeekSummary() {
    return ValueListenableBuilder<Map<String, List<AthleteSession>>>(
      valueListenable: _vm.weekSessionsByDay,
      builder: (_, byDay, __) {
        final allSessions = byDay.values.expand((l) => l).toList();
        final completed   = allSessions.where((s) => s.status == AthleteSessionStatus.completed).length;
        final total       = allSessions.length;

        // Volumen y carga de entrenamientos completados (de allWorkouts de la semana)
        final weekKeys = _vm.weekDays.value.map(_normalize).toSet();
        final weekWorkouts = _vm.allWorkouts.value
            .where((w) => weekKeys.contains(_normalize(w.fecha)))
            .toList();
        final km   = weekWorkouts.fold(0.0, (s, e) => s + e.distanciaTotalM() / 1000.0);
        final load = weekWorkouts.fold(0.0, (s, e) => s + (e.loadScore ?? 0.0));

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'RESUMEN SEMANAL',
              style: AppTypography.small.copyWith(
                color: AppColors.iconMutedOf(context),
                letterSpacing: 1.2,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: AppSpacing.m),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.l),
              decoration: _cardDecoration(),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _MiniStat('Sesiones', '$completed/$total'),
                  _MiniStat('Volumen', '${km.toStringAsFixed(1)} km'),
                  _MiniStat('Carga', load > 0 ? load.toStringAsFixed(0) : '–'),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  // ── Vista temporada ───────────────────────────────────────────────────────

  Widget _buildSeasonView(bool isAthlete) {
    if (!isAthlete) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.lock_outline, color: AppColors.iconMutedOf(context), size: 48),
              const SizedBox(height: AppSpacing.l),
              Text(
                'Solo disponible en modo atleta',
                style: AppTypography.body.copyWith(color: AppColors.textSecondary(context)),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.l),
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.brand),
                  foregroundColor: AppColors.brand,
                ),
                onPressed: _vm.toggleAthleteMode,
                child: const Text('Activar modo atleta'),
              ),
            ],
          ),
        ),
      );
    }

    return ValueListenableBuilder<List<Entrenamiento>>(
      valueListenable: _vm.allWorkouts,
      builder: (_, workouts, __) {
        final weeks = _getWeeksOfYear(_focusedYear, workouts);

        return SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.l),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Cabecera año + navegación ─────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  GestureDetector(
                    onTap: () => setState(() => _focusedYear--),
                    child: Icon(Icons.chevron_left, size: 24, color: AppColors.textPrimary(context)),
                  ),
                  const SizedBox(width: AppSpacing.l),
                  Text(
                    '$_focusedYear',
                    style: AppTypography.h3.copyWith(color: AppColors.textPrimary(context)),
                  ),
                  const SizedBox(width: AppSpacing.l),
                  GestureDetector(
                    onTap: () => setState(() => _focusedYear++),
                    child: Icon(Icons.chevron_right, size: 24, color: AppColors.textPrimary(context)),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xl),

              // ── Sección por mes ───────────────────────────────────
              ...List.generate(12, (i) => _buildMonthSection(i + 1, weeks)),

              // ── Leyenda ───────────────────────────────────────────
              _buildSeasonLegend(),
              const SizedBox(height: 100),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMonthSection(int month, List<_WeekData> allWeeks) {
    const abbrs = ['ENE','FEB','MAR','ABR','MAY','JUN','JUL','AGO','SEP','OCT','NOV','DIC'];
    final monthWeeks = allWeeks.where((w) =>
        _monthForWeek(w.weekStart) == month).toList();

    if (monthWeeks.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          abbrs[month - 1],
          style: AppTypography.body.copyWith(
            color: AppColors.textSecondary(context),
            letterSpacing: 2,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: AppSpacing.s),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: monthWeeks.map((w) => Padding(
            padding: const EdgeInsets.only(right: 8),
            child: _buildWeekSquare(w),
          )).toList(),
        ),
        const SizedBox(height: AppSpacing.xl),
      ],
    );
  }

  Widget _buildWeekSquare(_WeekData week) {
    final color  = _colorForWeekLoad(week.trimp, week.hasCompetition);
    final height = week.trimp > 0 || week.hasCompetition
        ? (24.0 + (week.trimp / 500.0).clamp(0.0, 1.0) * 24.0)
        : 24.0;

    return GestureDetector(
      onTap: () => _showWeekDetailSheet(week),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'S${week.weekNumber}',
            style: AppTypography.small.copyWith(
              fontSize: 9,
              color: AppColors.textSecondary(context),
            ),
          ),
          const SizedBox(height: 3),
          Container(
            width: 28,
            height: height,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                color: week.isCurrentWeek ? AppColors.brand : Colors.transparent,
                width: 2,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _colorForWeekLoad(double trimp, bool hasCompetition) {
    if (hasCompetition) return AppColors.brand;
    if (trimp <= 0)     return AppColors.borderOf(context);
    if (trimp < 150)    return AppColors.rpeLow;
    if (trimp < 300)    return AppColors.rpeMid;
    if (trimp < 500)    return AppColors.effortLight;
    return AppColors.rpeMax;
  }

  double _calcWeekTrimp(List<DateTime> week, List<Entrenamiento> workouts) {
    double total = 0;
    for (final day in week) {
      final key = _normalize(day);
      for (final w in workouts) {
        if (_normalize(w.fecha) == key) total += _proximyLoadScore(w);
      }
    }
    return total;
  }

  bool _weekHasCompetition(
    List<DateTime> week,
    List<Entrenamiento> workouts,
    Map<String, List<AthleteSession>> sessions,
  ) {
    for (final day in week) {
      final key = _normalize(day);
      for (final w in workouts) {
        if (_normalize(w.fecha) == key &&
            w.tags != null && w.tags!.contains('competición')) return true;
      }
      for (final s in sessions[key] ?? []) {
        if (s.category == 'competicion' || s.category == 'competición') return true;
      }
    }
    return false;
  }

  double _proximyLoadScore(Entrenamiento t) {
    try {
      final distKm = t.distanciaTotalM() / 1000.0;
      if (distKm <= 0) return 0;
      final rpe = t.rpePromedio();
      return distKm * (rpe > 0 ? rpe : 5.0);
    } catch (_) {
      return 0;
    }
  }

  Widget _buildSeasonLegend() => _buildLoadLegend();

  Widget _buildMonthlyLegend() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.l, vertical: AppSpacing.m),
      child: _buildLoadLegend(),
    );
  }

  Widget _buildLoadLegend() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'CARGA SEMANAL',
          style: AppTypography.small.copyWith(
            color: AppColors.textSecondary(context),
            letterSpacing: 1.5,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: AppSpacing.m),
        Wrap(
          spacing: AppSpacing.l,
          runSpacing: AppSpacing.s,
          children: [
            _legendItem('Sin datos',  AppColors.borderOf(context)),
            _legendItem('Suave',      AppColors.rpeLow),
            _legendItem('Moderada',   AppColors.rpeMid),
            _legendItem('Carga',      AppColors.effortLight),
            _legendItem('Pico',       AppColors.rpeMax),
            _legendItemDiamond('Competición', AppColors.brand),
          ],
        ),
      ],
    );
  }

  Widget _legendItem(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12, height: 12,
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2)),
        ),
        const SizedBox(width: 6),
        Text(label, style: AppTypography.small.copyWith(color: AppColors.textSecondary(context))),
      ],
    );
  }

  Widget _legendItemDiamond(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Transform.rotate(
          angle: 0.785398,
          child: Container(
            width: 10, height: 10,
            decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(1)),
          ),
        ),
        const SizedBox(width: 6),
        Text(label, style: AppTypography.small.copyWith(color: AppColors.textSecondary(context))),
      ],
    );
  }

  void _showWeekDetailSheet(_WeekData week) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(AppSpacing.l),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36, height: 4,
                margin: const EdgeInsets.only(bottom: AppSpacing.l),
                decoration: BoxDecoration(
                  color: AppColors.borderOf(context),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text(
              'Semana ${week.weekNumber}',
              style: AppTypography.h3.copyWith(color: AppColors.textPrimary(context)),
            ),
            const SizedBox(height: 4),
            Text(
              _formatWeekRange(week.weekStart, week.weekEnd),
              style: AppTypography.small.copyWith(color: AppColors.textSecondary(context)),
            ),
            const SizedBox(height: AppSpacing.xl),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _MiniStat(
                  week.volumeKm > 0 ? '${week.volumeKm.toStringAsFixed(1)} km' : '–',
                  'Volumen',
                ),
                _MiniStat('${week.sessionCount}', 'Sesiones'),
                _MiniStat(_trimpLabel(week.trimp, week.hasCompetition), 'Tipo'),
              ],
            ),
            const SizedBox(height: AppSpacing.xl),
          ],
        ),
      ),
    );
  }

  String _trimpLabel(double trimp, bool hasCompetition) {
    if (hasCompetition) return 'Competición';
    if (trimp <= 0)     return 'Sin datos';
    if (trimp < 150)    return 'Suave';
    if (trimp < 300)    return 'Moderada';
    if (trimp < 500)    return 'Carga';
    return 'Pico';
  }

  // ── Helpers vista temporada ───────────────────────────────────────────────

  List<_WeekData> _getWeeksOfYear(int year, List<Entrenamiento> workouts) {
    final jan1   = DateTime(year, 1, 1);
    final dec31  = DateTime(year, 12, 31);
    final result = <_WeekData>[];

    // Empezar en el lunes de la semana que contiene el 1 de enero
    var start     = jan1.subtract(Duration(days: jan1.weekday - 1));
    int weekNum   = 1;
    final today   = DateTime.now();

    while (!start.isAfter(dec31)) {
      final end = start.add(const Duration(days: 6));

      // Solo semanas que solapan con el año
      if (!end.isBefore(jan1)) {
        double vol          = 0;
        double weekTrimp    = 0;
        bool   hasCompet    = false;
        int    count        = 0;
        for (final w in workouts) {
          final d = DateTime(w.fecha.year, w.fecha.month, w.fecha.day);
          if (!d.isBefore(start) && !d.isAfter(end)) {
            vol        += w.distanciaTotalM() / 1000.0;
            weekTrimp  += _proximyLoadScore(w);
            count++;
            if (w.tags != null && w.tags!.contains('competición')) hasCompet = true;
          }
        }
        final isCurrent = !today.isBefore(start) && !today.isAfter(end);
        result.add(_WeekData(
          weekNumber:    weekNum,
          weekStart:     start,
          weekEnd:       end,
          volumeKm:      vol,
          trimp:         weekTrimp,
          hasCompetition: hasCompet,
          sessionCount:  count,
          isCurrentWeek: isCurrent,
        ));
      }

      start   = start.add(const Duration(days: 7));
      weekNum++;
      if (weekNum > 54) break;
    }
    return result;
  }

  // ── Helpers — cards día (vista mensual) ───────────────────────────────────

  Widget _buildEmptyAthleteDay(DateTime day) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.l),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Sin sesión planificada', style: AppTypography.body.copyWith(color: AppColors.iconMutedOf(context))),
          const SizedBox(height: AppSpacing.m),
          OutlinedButton.icon(
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('Planificar sesión'),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AppColors.brand),
              foregroundColor: AppColors.brand,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppDimens.buttonRadius)),
            ),
            onPressed: () => MainShell.shellKey.currentState?.navigateTo(
              13,
              params: AthleteSessionShellParams(date: _normalize(day)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSessionCard(AthleteSession session, DateTime day) {
    final color = _statusColor(session.status);
    final label = _statusLabel(session.status);
    final categoryLabel = session.title?.isNotEmpty == true
        ? session.title!
        : session.category != null
            ? SessionCategoryX.fromValue(session.category!).label
            : 'Entrenamiento';

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: AppSpacing.m),
      padding: const EdgeInsets.all(AppSpacing.l),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(width: 8, height: 8, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4))),
              const SizedBox(width: 8),
              Expanded(child: Text(categoryLabel, style: AppTypography.body.copyWith(color: AppColors.textPrimary(context)))),
              Text(label, style: AppTypography.small.copyWith(color: color)),
            ],
          ),
          if (session.blocks.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.s),
            ...session.blocks.take(3).map((b) {
              final detail = b.distanceM != null
                  ? '${b.reps != null && b.reps! > 1 ? '${b.reps}×' : ''}${b.distanceM}m'
                  : b.durationMinutes != null ? '${b.durationMinutes} min' : 'bloque';
              return Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Text('• $detail', style: AppTypography.small.copyWith(color: AppColors.textSecondary(context))),
              );
            }),
          ],
          if (session.status == AthleteSessionStatus.planned) ...[
            const SizedBox(height: AppSpacing.m),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.brand,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppDimens.buttonRadius)),
                    ),
                    onPressed: () {
                      final workoutSession = mapAthleteSessionToWorkout(session);
                      if (workoutSession != null) {
                        MainShell.shellKey.currentState?.navigateTo(
                          16,
                          params: PreExecutionShellParams(
                            session: workoutSession,
                            athleteSession: session,
                          ),
                        );
                      }
                    },
                    child: const Text('EMPEZAR'),
                  ),
                ),
                const SizedBox(width: AppSpacing.m),
                IconButton(
                  icon: const Icon(Icons.edit_outlined),
                  color: AppColors.iconMutedOf(context),
                  onPressed: () => MainShell.shellKey.currentState?.navigateTo(
                    13,
                    params: AthleteSessionShellParams(date: _normalize(day), session: session),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEmptyRecreativoDay() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.l),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('No entrenaste este día', style: AppTypography.body.copyWith(color: AppColors.iconMutedOf(context))),
          const SizedBox(height: AppSpacing.m),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.brand,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppDimens.buttonRadius)),
            ),
            onPressed: () => Navigator.push(context, AppRoute(page: const TrainingStartView())),
            child: const Text('ENTRENAR AHORA'),
          ),
        ],
      ),
    );
  }

  Widget _buildWorkoutCard(Entrenamiento w) {
    final km = w.distanciaTotalM() / 1000.0;
    final kmStr = km < 1 ? '${w.distanciaTotalM()}m' : '${km.toStringAsFixed(1)} km';
    String pace = '';
    try { pace = w.ritmoMedioTexto(); } catch (_) {}

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.s),
      padding: const EdgeInsets.all(AppSpacing.m),
      decoration: _cardDecoration(),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(w.titulo.isNotEmpty ? w.titulo : 'Entrenamiento libre', style: AppTypography.body.copyWith(color: AppColors.textPrimary(context))),
                Text(kmStr, style: AppTypography.small.copyWith(color: AppColors.iconMutedOf(context))),
              ],
            ),
          ),
          if (pace.isNotEmpty)
            Text(pace, style: AppTypography.body.copyWith(color: AppColors.brand)),
        ],
      ),
    );
  }

  Widget _buildAthleteModeCta() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.l),
      decoration: BoxDecoration(
        color: AppColors.surfaceOf(context),
        border: Border(
          left: const BorderSide(color: AppColors.brand, width: 3),
          top: BorderSide(color: AppColors.borderOf(context), width: 0.5),
          right: BorderSide(color: AppColors.borderOf(context), width: 0.5),
          bottom: BorderSide(color: AppColors.borderOf(context), width: 0.5),
        ),
        borderRadius: BorderRadius.circular(AppDimens.cardRadius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('¿Quieres planificar tus entrenos?', style: AppTypography.body.copyWith(color: AppColors.textPrimary(context))),
          const SizedBox(height: 4),
          Text('Activa el modo atleta para usar el calendario de planificación', style: AppTypography.small.copyWith(color: AppColors.iconMutedOf(context))),
          const SizedBox(height: AppSpacing.m),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppColors.brand, padding: EdgeInsets.zero),
            onPressed: _vm.toggleAthleteMode,
            child: const Text('Activar modo atleta →'),
          ),
        ],
      ),
    );
  }

  // ── Helpers generales ─────────────────────────────────────────────────────

  BoxDecoration _cardDecoration() => BoxDecoration(
    color: AppColors.surfaceOf(context),
    border: Border.all(color: AppColors.borderOf(context), width: 0.5),
    borderRadius: BorderRadius.circular(AppDimens.cardRadius),
  );

  Color _statusColor(AthleteSessionStatus s) {
    switch (s) {
      case AthleteSessionStatus.planned:   return AppColors.brand;
      case AthleteSessionStatus.completed: return AppColors.rpeLow;
      case AthleteSessionStatus.skipped:   return AppColors.rpeMax;
    }
  }

  String _statusLabel(AthleteSessionStatus s) {
    switch (s) {
      case AthleteSessionStatus.planned:   return 'Planificada';
      case AthleteSessionStatus.completed: return 'Completada';
      case AthleteSessionStatus.skipped:   return 'Saltada';
    }
  }

  List<Color> _dotsForSessions(List<AthleteSession> sessions) {
    final colors = <Color>[];
    if (sessions.any((s) => s.status == AthleteSessionStatus.completed)) colors.add(AppColors.rpeLow);
    if (sessions.any((s) => s.status == AthleteSessionStatus.planned && s.category != 'competicion')) colors.add(AppColors.brand);
    if (sessions.any((s) => s.category == 'competicion')) colors.add(AppColors.rpeMax);
    if (sessions.any((s) => s.status == AthleteSessionStatus.skipped)) colors.add(AppColors.rpeMax.withOpacity(0.6));
    return colors.take(3).toList();
  }


  String _dayAbbr(int weekday) {
    const days = ['LUN', 'MAR', 'MIÉ', 'JUE', 'VIE', 'SÁB', 'DOM'];
    return days[weekday - 1];
  }

  String _blocksDescription(List<SessionBlock> blocks) {
    final parts = <String>[];
    for (final b in blocks) {
      if (b.reps != null && b.distanceM != null) {
        parts.add('${b.reps}×${b.distanceM}m');
      } else if (b.distanceM != null) {
        parts.add('${b.distanceM}m');
      } else if (b.durationMinutes != null) {
        parts.add('${b.durationMinutes} min');
      }
    }
    return parts.join(' + ');
  }

  String _normalize(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  String _formatDaySpanish(DateTime d) {
    const dias  = ['Lunes','Martes','Miércoles','Jueves','Viernes','Sábado','Domingo'];
    const meses = ['Enero','Febrero','Marzo','Abril','Mayo','Junio','Julio','Agosto','Septiembre','Octubre','Noviembre','Diciembre'];
    return '${dias[d.weekday - 1]} ${d.day} ${meses[d.month - 1]}';
  }

  String _formatWeekRange(DateTime monday, DateTime sunday) {
    const meses = ['Ene','Feb','Mar','Abr','May','Jun','Jul','Ago','Sep','Oct','Nov','Dic'];
    final start = '${monday.day} ${meses[monday.month - 1]}';
    final end   = '${sunday.day} ${meses[sunday.month - 1]}';
    return '$start – $end';
  }

  int _weekOfYear(DateTime date) {
    final firstDay = DateTime(date.year, 1, 1);
    final days = date.difference(firstDay).inDays;
    return ((days + firstDay.weekday - 1) / 7).ceil();
  }
}

// ── Widgets privados ──────────────────────────────────────────────────────────

class _ViewTab extends StatelessWidget {
  const _ViewTab(this.label, this.type, this.isActive, this.vm);

  final String           label;
  final CalendarViewType type;
  final bool             isActive;
  final CalendarViewModel vm;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => vm.viewType.value = type,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.l, vertical: AppSpacing.s),
        decoration: BoxDecoration(
          color: isActive ? AppColors.brand : AppColors.surfaceOf(context),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isActive ? AppColors.brand : AppColors.borderOf(context)),
        ),
        child: Text(
          label,
          style: AppTypography.small.copyWith(
            color: isActive ? Colors.white : AppColors.textSecondary(context),
            fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value, style: AppTypography.h3.copyWith(color: AppColors.brand)),
        const SizedBox(height: 2),
        Text(label, style: AppTypography.small.copyWith(color: AppColors.iconMutedOf(context))),
      ],
    );
  }
}


class _WeekData {
  final int      weekNumber;
  final DateTime weekStart;
  final DateTime weekEnd;
  final double   volumeKm;
  final double   trimp;
  final bool     hasCompetition;
  final int      sessionCount;
  final bool     isCurrentWeek;

  const _WeekData({
    required this.weekNumber,
    required this.weekStart,
    required this.weekEnd,
    required this.volumeKm,
    required this.trimp,
    required this.hasCompetition,
    required this.sessionCount,
    required this.isCurrentWeek,
  });
}

