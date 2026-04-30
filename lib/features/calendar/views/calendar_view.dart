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
                _buildCalendar(isAthlete),
                Expanded(child: _buildDayContent(isAthlete)),
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
      child: Column(
        children: [
          const SizedBox(height: AppSpacing.m),
          _skeletonBox(height: 320),
          const SizedBox(height: AppSpacing.xl),
          _skeletonBox(height: 120),
        ],
      ),
    );
  }

  Widget _skeletonBox({required double height}) {
    return Container(
      width: double.infinity,
      height: height,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppDimens.cardRadius),
      ),
    );
  }

  // ── Calendario ────────────────────────────────────────────────────────────

  Widget _buildCalendar(bool isAthlete) {
    return ValueListenableBuilder<DateTime>(
      valueListenable: _vm.focusedMonth,
      builder: (_, focused, __) => ValueListenableBuilder<DateTime>(
        valueListenable: _vm.selectedDay,
        builder: (_, selected, __) => isAthlete
            ? _buildAthleteCalendar(focused, selected)
            : _buildRecreativoCalendar(focused, selected),
      ),
    );
  }

  Widget _buildAthleteCalendar(DateTime focused, DateTime selected) {
    return ValueListenableBuilder<Map<String, List<AthleteSession>>>(
      valueListenable: _vm.sessionsByDate,
      builder: (_, byDate, __) {
        return StandardTableCalendar<AthleteSession>(
          lastDay: DateTime(2030, 12, 31),
          focusedDay: focused,
          selectedDay: selected,
          eventLoader: (day) {
            final key = _normalize(day);
            return byDate[key] ?? [];
          },
          onDaySelected: (sel, foc) {
            _vm.onDaySelected(sel, foc);
          },
          onPageChanged: _vm.onMonthChanged,
          calendarBuilders: CalendarBuilders<AthleteSession>(
            markerBuilder: (context, day, sessions) {
              if (sessions.isEmpty) return null;
              final dots = _dotsForSessions(sessions);
              return Positioned(
                bottom: 4,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: dots
                      .map((c) => Container(
                            width: 5,
                            height: 5,
                            margin: const EdgeInsets.symmetric(horizontal: 1),
                            decoration: BoxDecoration(
                              color: c,
                              shape: BoxShape.circle,
                            ),
                          ))
                      .toList(),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildRecreativoCalendar(DateTime focused, DateTime selected) {
    return ValueListenableBuilder<Set<String>>(
      valueListenable: _vm.trainingDates,
      builder: (_, dates, __) {
        return StandardTableCalendar<Object>(
          lastDay: DateTime(2030, 12, 31),
          focusedDay: focused,
          selectedDay: selected,
          eventLoader: (day) => dates.contains(_normalize(day)) ? [Object()] : [],
          onDaySelected: (sel, foc) {
            _vm.onDaySelected(sel, foc);
          },
          onPageChanged: _vm.onMonthChanged,
          calendarBuilders: CalendarBuilders<Object>(
            markerBuilder: (context, day, events) {
              if (events.isEmpty) return null;
              return Positioned(
                bottom: 4,
                child: Container(
                  width: 5,
                  height: 5,
                  decoration: const BoxDecoration(
                    color: AppColors.brand,
                    shape: BoxShape.circle,
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  // ── Contenido del día ─────────────────────────────────────────────────────

  Widget _buildDayContent(bool isAthlete) {
    return isAthlete ? _buildAthleteDayContent() : _buildRecreativoDayContent();
  }

  // ── Modo atleta ───────────────────────────────────────────────────────────

  Widget _buildAthleteDayContent() {
    return ValueListenableBuilder<DateTime>(
      valueListenable: _vm.selectedDay,
      builder: (_, day, __) => ValueListenableBuilder<List<AthleteSession>>(
        valueListenable: _vm.selectedDaySessions,
        builder: (_, sessions, __) {
          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.l,
              vertical: AppSpacing.m,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_formatDaySpanish(day), style: AppTypography.h3),
                const SizedBox(height: AppSpacing.m),
                if (sessions.isEmpty)
                  _buildEmptyAthleteDay(day)
                else
                  ...sessions.map((s) => _buildSessionCard(s, day)),
                const SizedBox(height: AppSpacing.xl),
                _buildWeeklyStubCard(),
                const SizedBox(height: 100),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyAthleteDay(DateTime day) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.l),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Sin sesión planificada',
            style: AppTypography.body.copyWith(color: AppColors.iconMuted),
          ),
          const SizedBox(height: AppSpacing.m),
          OutlinedButton.icon(
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('Planificar sesión'),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AppColors.brand),
              foregroundColor: AppColors.brand,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppDimens.buttonRadius),
              ),
            ),
            onPressed: () => Navigator.push(
              context,
              AppRoute(
                page: AthleteSessionEditorView(
                  uid: _vm.userId,
                  initialDate: _normalize(day),
                ),
              ),
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
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(categoryLabel, style: AppTypography.body),
              ),
              Text(
                label,
                style: AppTypography.small.copyWith(color: color),
              ),
            ],
          ),
          if (session.blocks.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.s),
            ...session.blocks.take(3).map((b) {
              final detail = b.distanceM != null
                  ? '${b.reps != null && b.reps! > 1 ? '${b.reps}×' : ''}${b.distanceM}m'
                  : b.durationMinutes != null
                      ? '${b.durationMinutes} min'
                      : 'bloque';
              return Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Text(
                  '• $detail',
                  style: AppTypography.small.copyWith(color: Colors.white70),
                ),
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
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(AppDimens.buttonRadius),
                      ),
                    ),
                    onPressed: () => Navigator.push(
                      context,
                      AppRoute(page: const TrainingStartView()),
                    ),
                    child: const Text('EMPEZAR'),
                  ),
                ),
                const SizedBox(width: AppSpacing.m),
                IconButton(
                  icon: const Icon(Icons.edit_outlined),
                  color: AppColors.iconMuted,
                  onPressed: () => Navigator.push(
                    context,
                    AppRoute(
                      page: AthleteSessionEditorView(
                        uid: _vm.userId,
                        initialDate: _normalize(day),
                        existingSession: session,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildWeeklyStubCard() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'RESUMEN SEMANAL',
          style: AppTypography.small.copyWith(
            color: AppColors.iconMuted,
            letterSpacing: 1.2,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: AppSpacing.m),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpacing.l),
          decoration: _cardDecoration(),
          child: Text(
            'Próximamente',
            style: AppTypography.small.copyWith(color: AppColors.iconMuted),
          ),
        ),
      ],
    );
  }

  // ── Modo recreativo ───────────────────────────────────────────────────────

  Widget _buildRecreativoDayContent() {
    return ValueListenableBuilder<DateTime>(
      valueListenable: _vm.selectedDay,
      builder: (_, day, __) => ValueListenableBuilder<List<Entrenamiento>>(
        valueListenable: _vm.selectedDayWorkouts,
        builder: (_, workouts, __) {
          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.l,
              vertical: AppSpacing.m,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_formatDaySpanish(day), style: AppTypography.h3),
                const SizedBox(height: AppSpacing.m),
                if (workouts.isEmpty)
                  _buildEmptyRecreativoDay()
                else
                  ...workouts.map((w) => _buildWorkoutCard(w)),
                const SizedBox(height: AppSpacing.xl),
                _buildAthleteModeCta(),
                const SizedBox(height: 100),
              ],
            ),
          );
        },
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
          Text(
            'No entrenaste este día',
            style: AppTypography.body.copyWith(color: AppColors.iconMuted),
          ),
          const SizedBox(height: AppSpacing.m),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.brand,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppDimens.buttonRadius),
              ),
            ),
            onPressed: () => Navigator.push(
              context,
              AppRoute(page: const TrainingStartView()),
            ),
            child: const Text('ENTRENAR AHORA'),
          ),
        ],
      ),
    );
  }

  Widget _buildWorkoutCard(Entrenamiento w) {
    final km = w.distanciaTotalM() / 1000.0;
    final kmStr = km < 1
        ? '${w.distanciaTotalM()}m'
        : '${km.toStringAsFixed(1)} km';
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
                Text(
                  w.titulo.isNotEmpty ? w.titulo : 'Entrenamiento libre',
                  style: AppTypography.body,
                ),
                Text(
                  kmStr,
                  style: AppTypography.small.copyWith(color: AppColors.iconMuted),
                ),
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
        color: AppColors.surface,
        border: Border(
          left: const BorderSide(color: AppColors.brand, width: 3),
          top: BorderSide(color: AppColors.border, width: 0.5),
          right: BorderSide(color: AppColors.border, width: 0.5),
          bottom: BorderSide(color: AppColors.border, width: 0.5),
        ),
        borderRadius: BorderRadius.circular(AppDimens.cardRadius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '¿Quieres planificar tus entrenos?',
            style: AppTypography.body,
          ),
          const SizedBox(height: 4),
          Text(
            'Activa el modo atleta para usar el calendario de planificación',
            style: AppTypography.small.copyWith(color: AppColors.iconMuted),
          ),
          const SizedBox(height: AppSpacing.m),
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: AppColors.brand,
              padding: EdgeInsets.zero,
            ),
            onPressed: _vm.toggleAthleteMode,
            child: const Text('Activar modo atleta →'),
          ),
        ],
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: AppColors.surface,
      border: Border.all(color: AppColors.border, width: 0.5),
      borderRadius: BorderRadius.circular(AppDimens.cardRadius),
    );
  }

  Color _statusColor(AthleteSessionStatus status) {
    switch (status) {
      case AthleteSessionStatus.planned:   return AppColors.brand;
      case AthleteSessionStatus.completed: return AppColors.rpeLow;
      case AthleteSessionStatus.skipped:   return AppColors.rpeMax;
    }
  }

  String _statusLabel(AthleteSessionStatus status) {
    switch (status) {
      case AthleteSessionStatus.planned:   return 'Planificada';
      case AthleteSessionStatus.completed: return 'Completada';
      case AthleteSessionStatus.skipped:   return 'Saltada';
    }
  }

  List<Color> _dotsForSessions(List<AthleteSession> sessions) {
    final colors = <Color>[];
    if (sessions.any((s) => s.status == AthleteSessionStatus.completed)) {
      colors.add(AppColors.rpeLow);
    }
    if (sessions.any((s) =>
        s.status == AthleteSessionStatus.planned &&
        s.category != 'competicion')) {
      colors.add(AppColors.brand);
    }
    if (sessions.any((s) => s.category == 'competicion')) {
      colors.add(AppColors.rpeMax);
    }
    if (sessions.any((s) => s.status == AthleteSessionStatus.skipped)) {
      colors.add(AppColors.rpeMax.withOpacity(0.6));
    }
    return colors.take(3).toList();
  }

  String _normalize(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  String _formatDaySpanish(DateTime d) {
    const dias  = ['Lunes','Martes','Miércoles','Jueves','Viernes','Sábado','Domingo'];
    const meses = ['Enero','Febrero','Marzo','Abril','Mayo','Junio',
                   'Julio','Agosto','Septiembre','Octubre','Noviembre','Diciembre'];
    return '${dias[d.weekday - 1]} ${d.day} ${meses[d.month - 1]}';
  }
}
