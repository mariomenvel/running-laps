import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:running_laps/core/theme/app_colors.dart';
import 'package:running_laps/core/theme/app_theme.dart';
import 'package:running_laps/core/utils/app_transitions.dart';
import 'package:running_laps/core/widgets/standard_table_calendar.dart';
import 'package:running_laps/features/athlete/data/athlete_session_model.dart';
import 'package:running_laps/features/athlete/views/athlete_session_editor_view.dart';
import 'package:running_laps/features/calendar/viewmodels/calendar_view_model.dart';
import 'package:running_laps/features/templates/data/template_models.dart';
import 'package:running_laps/features/training/data/entrenamiento.dart';
import 'package:running_laps/features/training/views/training_start_view.dart';

class CalendarView extends StatefulWidget {
  const CalendarView({super.key});

  @override
  State<CalendarView> createState() => _CalendarViewState();
}

class _CalendarViewState extends State<CalendarView> {
  late final CalendarViewModel _vm;

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
            // Precalcular volumen por semana (evitar recalcular en cada build de fila)
            final weekVolumes = weeks.map((w) => _calcWeekVolumeKm(w, workouts)).toList();
            final maxVol = weekVolumes.fold(0.0, (a, b) => a > b ? a : b);

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
                      week:        weeks[i],
                      month:       focused.month,
                      volumeKm:    weekVolumes[i],
                      maxVolumeKm: maxVol,
                      sessions:    sessionsByDate,
                      trainings:   workouts,
                      isAthlete:   isAthlete,
                    ),
                  ),
                ),
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
    required double volumeKm,
    required double maxVolumeKm,
    required Map<String, List<AthleteSession>> sessions,
    required List<Entrenamiento> trainings,
    required bool isAthlete,
  }) {
    final ratio    = maxVolumeKm > 0 ? (volumeKm / maxVolumeKm).clamp(0.0, 1.0) : 0.0;
    final barColor = ratio < 0.5
        ? Color.lerp(AppColors.rpeLow, const Color(0xFFFFCA28), ratio * 2)!
        : Color.lerp(const Color(0xFFFFCA28), AppColors.rpeMax, (ratio - 0.5) * 2)!;

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
      onTap: () => _showWeekDetailSheet(
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
            // Barra de volumen
            Container(
              height: 6,
              decoration: BoxDecoration(
                color: volumeKm > 0 ? barColor : AppColors.borderOf(context),
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

  void _showWeekDetailSheet({
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
                                        final cat = s.category != null
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

    // Empezar desde el lunes de la semana que contiene el día 1
    var weekStart = firstDay.subtract(Duration(days: firstDay.weekday - 1));

    while (!weekStart.isAfter(lastDay)) {
      weeks.add(List.generate(7, (i) => weekStart.add(Duration(days: i))));
      weekStart = weekStart.add(const Duration(days: 7));
    }
    return weeks;
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

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.s),
      decoration: BoxDecoration(
        color: AppColors.surfaceOf(context),
        border: Border.all(
          color: isToday ? AppColors.brand : AppColors.borderOf(context),
          width: isToday ? 1.5 : 0.5,
        ),
        borderRadius: BorderRadius.circular(AppDimens.cardRadius),
      ),
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
                const Spacer(),
                if (isAthlete && sessions.isEmpty)
                  GestureDetector(
                    onTap: () => Navigator.push(
                      context,
                      AppRoute(page: AthleteSessionEditorView(uid: _vm.userId, initialDate: _normalize(day))),
                    ),
                    child: const Icon(Icons.add_circle_outline, color: AppColors.brand, size: 20),
                  ),
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
                              s.category != null
                                  ? SessionCategoryX.fromValue(s.category!).label
                                  : 'Entrenamiento',
                              style: AppTypography.body.copyWith(color: AppColors.textPrimary(context)),
                            ),
                          ),
                          if (s.status == AthleteSessionStatus.completed)
                            const Icon(Icons.check_circle, color: AppColors.rpeLow, size: 16),
                          if (s.status == AthleteSessionStatus.planned)
                            GestureDetector(
                              onTap: () => Navigator.push(context, AppRoute(page: const TrainingStartView())),
                              child: const Icon(Icons.play_circle_outline, color: AppColors.brand, size: 20),
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

    return ValueListenableBuilder<List<SeasonWeekData>>(
      valueListenable: _vm.seasonWeeks,
      builder: (_, weeks, __) {
        if (weeks.isEmpty) {
          return Center(
            child: Text(
              'Cargando temporada...',
              style: AppTypography.small.copyWith(color: AppColors.textSecondary(context)),
            ),
          );
        }

        final maxLoad = weeks.map((w) => w.loadScore).fold(0.0, (a, b) => a > b ? a : b);

        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.l),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('TEMPORADA', style: AppTypography.h3.copyWith(color: AppColors.textPrimary(context))),
              const SizedBox(height: 2),
              Text('Últimas 16 semanas', style: AppTypography.small.copyWith(color: AppColors.textSecondary(context))),
              const SizedBox(height: AppSpacing.l),

              // Leyenda
              Wrap(
                spacing: AppSpacing.m,
                runSpacing: AppSpacing.s,
                children: [
                  _LegendDot('Carga',       const Color(0xFFE57373)),
                  _LegendDot('Base',        AppColors.brand),
                  _LegendDot('Descarga',    AppColors.rpeLow),
                  _LegendDot('Competición', AppColors.effort),
                  _LegendDot('Transición',  AppColors.iconMuted),
                ],
              ),
              const SizedBox(height: AppSpacing.l),

              // Filas de semanas
              ...weeks.map((week) {
                final isCurrentWeek = _isCurrentWeek(week.weekStart);
                final barHeight = maxLoad > 0 ? (week.loadScore / maxLoad * 36).clamp(4.0, 36.0) : 4.0;
                final typeColor = _weekTypeColor(week.weekType);

                return Container(
                  margin: const EdgeInsets.only(bottom: AppSpacing.s),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceOf(context),
                    border: Border.all(
                      color: isCurrentWeek ? AppColors.brand : AppColors.borderOf(context),
                      width: isCurrentWeek ? 1.5 : 0.5,
                    ),
                    borderRadius: BorderRadius.circular(AppDimens.cardRadius),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.m),
                    child: Row(
                      children: [
                        // Barra indicador de tipo
                        Container(
                          width: 4,
                          height: 40,
                          decoration: BoxDecoration(
                            color: typeColor,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.m),

                        // Info
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    'S${week.weekNumber}',
                                    style: AppTypography.body.copyWith(
                                      color: AppColors.textPrimary(context),
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    _weekTypeLabel(week.weekType),
                                    style: AppTypography.small.copyWith(color: typeColor),
                                  ),
                                  if (week.hasRace) ...[
                                    const SizedBox(width: 8),
                                    const Icon(Icons.emoji_events, color: AppColors.effort, size: 14),
                                  ],
                                ],
                              ),
                              Text(
                                _formatWeekRange(week.weekStart, week.weekStart.add(const Duration(days: 6))),
                                style: AppTypography.small.copyWith(color: AppColors.textSecondary(context)),
                              ),
                            ],
                          ),
                        ),

                        // Stats compactas
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '${week.volumeKm.toStringAsFixed(1)} km',
                              style: AppTypography.body.copyWith(color: AppColors.textPrimary(context)),
                            ),
                            Text(
                              '${week.sessionCount} sesiones',
                              style: AppTypography.small.copyWith(color: AppColors.textSecondary(context)),
                            ),
                          ],
                        ),
                        const SizedBox(width: AppSpacing.m),

                        // Barra de carga mini (vertical)
                        SizedBox(
                          width: 12,
                          height: 40,
                          child: Align(
                            alignment: Alignment.bottomCenter,
                            child: Container(
                              width: 8,
                              height: barHeight,
                              decoration: BoxDecoration(
                                color: typeColor.withOpacity(0.8),
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),

              const SizedBox(height: 100),
            ],
          ),
        );
      },
    );
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
            onPressed: () => Navigator.push(
              context,
              AppRoute(page: AthleteSessionEditorView(uid: _vm.userId, initialDate: _normalize(day))),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSessionCard(AthleteSession session, DateTime day) {
    final color = _statusColor(session.status);
    final label = _statusLabel(session.status);
    final categoryLabel = session.category != null
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
                    onPressed: () => Navigator.push(context, AppRoute(page: const TrainingStartView())),
                    child: const Text('EMPEZAR'),
                  ),
                ),
                const SizedBox(width: AppSpacing.m),
                IconButton(
                  icon: const Icon(Icons.edit_outlined),
                  color: AppColors.iconMutedOf(context),
                  onPressed: () => Navigator.push(
                    context,
                    AppRoute(page: AthleteSessionEditorView(uid: _vm.userId, initialDate: _normalize(day), existingSession: session)),
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

  Color _weekTypeColor(String weekType) {
    switch (weekType) {
      case 'carga':       return const Color(0xFFE57373);
      case 'base':        return AppColors.brand;
      case 'descarga':    return AppColors.rpeLow;
      case 'competición': return AppColors.effort;
      default:            return AppColors.iconMuted;
    }
  }

  String _weekTypeLabel(String weekType) {
    switch (weekType) {
      case 'carga':       return 'CARGA';
      case 'base':        return 'BASE';
      case 'descarga':    return 'DESCARGA';
      case 'competición': return 'COMPETICIÓN';
      default:            return 'TRANSICIÓN';
    }
  }

  bool _isCurrentWeek(DateTime weekStart) {
    final now    = DateTime.now();
    final monday = now.subtract(Duration(days: now.weekday - 1));
    final m      = DateTime(monday.year, monday.month, monday.day);
    final w      = DateTime(weekStart.year, weekStart.month, weekStart.day);
    return m == w;
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

class _LegendDot extends StatelessWidget {
  const _LegendDot(this.label, this.color);

  final String label;
  final Color  color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text(label, style: AppTypography.small.copyWith(color: AppColors.textSecondary(context))),
      ],
    );
  }
}
