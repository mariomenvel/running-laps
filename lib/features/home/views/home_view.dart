import 'dart:math' show min;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:running_laps/core/theme/app_colors.dart';
import 'package:running_laps/core/theme/app_theme.dart';
import 'package:running_laps/core/utils/app_transitions.dart';
import 'package:running_laps/features/athlete/data/athlete_session_model.dart';
import 'package:running_laps/features/athlete/data/progress_repository.dart';
import 'package:running_laps/features/history/views/history_screen.dart';
import 'package:running_laps/features/home/viewmodels/home_view_model.dart';
import 'package:running_laps/features/training/data/entrenamiento.dart';
import 'package:running_laps/features/training/views/training_start_view.dart';

// Zone color helpers — Z1..Z5 matching ZonesService thresholds
Color _zoneColor(int zone) {
  switch (zone) {
    case 1: return AppColors.rest;
    case 2: return AppColors.rpeLow;
    case 3: return AppColors.rpeMid;
    case 4: return AppColors.effort;
    case 5: return AppColors.rpeMax;
    default: return AppColors.border;
  }
}

Color _loadColor(double load) {
  if (load < 150) return AppColors.rpeLow;
  if (load < 400) return AppColors.rpeMid;
  if (load < 700) return AppColors.effort;
  return AppColors.rpeMax;
}

String _loadLabel(double load) {
  if (load < 150) return 'Baja';
  if (load < 400) return 'Moderada';
  if (load < 700) return 'Alta';
  return 'Muy alta';
}

class HomeView extends StatefulWidget {
  const HomeView({super.key});

  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> {
  late final HomeViewModel _vm;

  @override
  void initState() {
    super.initState();
    final uid = FirebaseAuth.instance.currentUser!.uid;
    _vm = HomeViewModel(userId: uid);
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
            return RefreshIndicator(
              color: AppColors.brand,
              onRefresh: _vm.refresh,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.l),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: AppSpacing.m),
                    _buildDateHeader(isAthlete),
                    const SizedBox(height: AppSpacing.xl),
                    if (isAthlete) ..._buildAthleteContent(),
                    if (!isAthlete) ..._buildRecreativoContent(),
                    _buildRecentWorkouts(),
                    const SizedBox(height: AppSpacing.xl),
                    _buildWeeklyProgress(),
                    const SizedBox(height: 100),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ── Skeleton ────────────────────────────────────────────────────────────────

  Widget _buildSkeleton() {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.l),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: AppSpacing.m),
          _skeletonBox(height: 48),
          const SizedBox(height: AppSpacing.xl),
          _skeletonBox(height: 140),
          const SizedBox(height: AppSpacing.xl),
          _skeletonBox(height: 100),
          const SizedBox(height: AppSpacing.xl),
          _skeletonBox(height: 80),
        ],
      ),
    );
  }

  Widget _skeletonBox({required double height}) {
    return Container(
      width: double.infinity,
      height: height,
      decoration: BoxDecoration(
        color: AppColors.surfaceOf(context),
        borderRadius: BorderRadius.circular(AppDimens.cardRadius),
      ),
    );
  }

  // ── Date header ─────────────────────────────────────────────────────────────

  Widget _buildDateHeader(bool isAthlete) {
    return ValueListenableBuilder<String>(
      valueListenable: _vm.userName,
      builder: (_, name, __) {
        return Row(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _formatDateSpanish(),
                  style: AppTypography.h2.copyWith(color: AppColors.textPrimary(context)),
                ),
                const SizedBox(height: 2),
                Text(
                  'Hola, $name',
                  style: AppTypography.small.copyWith(color: AppColors.iconMutedOf(context)),
                ),
              ],
            ),
            const Spacer(),
            Tooltip(
              message: isAthlete ? 'Cambiar a modo libre' : 'Cambiar a modo atleta',
              child: IconButton(
                icon: const Icon(Icons.sync_rounded),
                color: AppColors.iconMutedOf(context),
                onPressed: _vm.toggleAthleteMode,
              ),
            ),
          ],
        );
      },
    );
  }

  String _formatDateSpanish() {
    final now = DateTime.now();
    const dias   = ['Lunes','Martes','Miércoles','Jueves','Viernes','Sábado','Domingo'];
    const meses  = ['Enero','Febrero','Marzo','Abril','Mayo','Junio','Julio','Agosto','Septiembre','Octubre','Noviembre','Diciembre'];
    return '${dias[now.weekday - 1]} ${now.day} ${meses[now.month - 1]}';
  }

  // ── Atleta ──────────────────────────────────────────────────────────────────

  List<Widget> _buildAthleteContent() {
    return [
      _buildTodaySessionCard(),
      const SizedBox(height: AppSpacing.xl),
      _buildWeekSessionsList(),
    ];
  }

  Widget _buildTodaySessionCard() {
    return ValueListenableBuilder<AthleteSession?>(
      valueListenable: _vm.todaySession,
      builder: (_, session, __) {
        return _card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                const Text('◇', style: TextStyle(color: AppColors.brand, fontSize: 14)),
                const SizedBox(width: 8),
                Text(
                  'SESIÓN DE HOY',
                  style: AppTypography.small.copyWith(
                    color: AppColors.brand,
                    letterSpacing: 1.2,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ]),
              const SizedBox(height: 12),
              if (session != null) ...[
                Text(
                  _categoryLabel(session.category),
                  style: AppTypography.h3.copyWith(color: AppColors.textPrimary(context)),
                ),
                if (session.blocks.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  ...session.blocks.take(3).map((b) => Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Text(
                      _blockSummary(b),
                      style: AppTypography.body.copyWith(color: AppColors.textSecondary(context)),
                    ),
                  )),
                ],
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
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
                    child: const Text('EMPEZAR ENTRENAMIENTO'),
                  ),
                ),
              ] else ...[
                Text(
                  'No hay sesión planificada para hoy',
                  style: AppTypography.body.copyWith(color: AppColors.iconMutedOf(context)),
                ),
                const SizedBox(height: 4),
                Text(
                  'Puedes entrenar libre o planificar en el calendario',
                  style: AppTypography.small.copyWith(color: AppColors.iconMutedOf(context)),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildWeekSessionsList() {
    return ValueListenableBuilder<AthleteSession?>(
      valueListenable: _vm.todaySession,
      builder: (_, today, __) {
        return ValueListenableBuilder<List<AthleteSession>>(
          valueListenable: _vm.weekSessions,
          builder: (_, week, __) {
            final todayStr = _todayDateStr();
            final upcoming = week.where((s) => s.date != todayStr).toList();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'PRÓXIMOS ENTRENAMIENTOS',
                  style: AppTypography.small.copyWith(
                    color: AppColors.iconMutedOf(context),
                    letterSpacing: 1.2,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppSpacing.m),
                _card(
                  child: upcoming.isEmpty
                      ? Text(
                          'Sin entrenos planificados esta semana',
                          style: AppTypography.small.copyWith(color: AppColors.iconMutedOf(context)),
                        )
                      : Column(
                          children: [
                            for (var i = 0; i < upcoming.length; i++) ...[
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 0,
                                  vertical: AppSpacing.s,
                                ),
                                child: Row(
                                  children: [
                                    SizedBox(
                                      width: 80,
                                      child: Text(
                                        _weekdayLabel(upcoming[i].date),
                                        style: AppTypography.body.copyWith(
                                          color: AppColors.textSecondary(context),
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      child: Text(
                                        _categoryLabel(upcoming[i].category),
                                        style: AppTypography.body.copyWith(
                                          color: AppColors.textPrimary(context),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (i < upcoming.length - 1)
                                Divider(color: AppColors.borderOf(context), height: 1),
                            ],
                          ],
                        ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildWeeklyProgress() {
    return ValueListenableBuilder<double>(
      valueListenable: _vm.weeklyVolumeKm,
      builder: (_, km, __) => ValueListenableBuilder<int>(
        valueListenable: _vm.weeklySessionCount,
        builder: (_, count, __) => ValueListenableBuilder<int>(
          valueListenable: _vm.weeklyTimeMinutes,
          builder: (_, minutes, __) => ValueListenableBuilder<double>(
            valueListenable: _vm.weeklyRpeAvg,
            builder: (_, rpe, __) => ValueListenableBuilder<double>(
              valueListenable: _vm.weeklyLoadTotal,
              builder: (_, load, __) => ValueListenableBuilder<Map<int, double>>(
                valueListenable: _vm.weeklyZoneSeconds,
                builder: (_, zones, __) {
                  const target = 60.0;
                  final hours  = minutes ~/ 60;
                  final mins   = minutes % 60;
                  final timeStr = hours > 0 ? '${hours}h ${mins}m' : '${mins}m';
                  final rpeStr  = rpe > 0 ? rpe.toStringAsFixed(1) : '–';

                  final totalZoneSec = zones.values.fold(0.0, (a, b) => a + b);

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'PROGRESO SEMANAL',
                        style: AppTypography.small.copyWith(
                          color: AppColors.iconMutedOf(context),
                          letterSpacing: 1.2,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.m),
                      _card(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // ── Stat row ───────────────────────────────
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                _StatItem(label: 'Sesiones', value: '$count'),
                                _StatItem(label: 'Tiempo',   value: timeStr),
                                _StatItem(label: 'RPE med.', value: rpeStr),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Divider(color: AppColors.borderOf(context), height: 1),
                            const SizedBox(height: 16),

                            // ── Volumen + barra ─────────────────────────
                            Row(
                              children: [
                                Text(
                                  'Volumen',
                                  style: AppTypography.body.copyWith(color: AppColors.textPrimary(context)),
                                ),
                                const Spacer(),
                                Text(
                                  '${km.toStringAsFixed(1)} km',
                                  style: AppTypography.body.copyWith(color: AppColors.brand),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: min(1.0, km / target),
                                backgroundColor: AppColors.borderOf(context),
                                valueColor: const AlwaysStoppedAnimation(AppColors.brand),
                                minHeight: 8,
                              ),
                            ),

                            // ── Carga ───────────────────────────────────
                            if (load > 0) ...[
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  Text(
                                    'Carga',
                                    style: AppTypography.body.copyWith(color: AppColors.textPrimary(context)),
                                  ),
                                  const Spacer(),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: _loadColor(load).withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      '${load.toStringAsFixed(0)} · ${_loadLabel(load)}',
                                      style: AppTypography.small.copyWith(
                                        color: _loadColor(load),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],

                            // ── Distribución de zonas ───────────────────
                            if (totalZoneSec > 0) ...[
                              const SizedBox(height: 16),
                              Text(
                                'Zonas de FC',
                                style: AppTypography.small.copyWith(color: AppColors.iconMutedOf(context)),
                              ),
                              const SizedBox(height: 8),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: Row(
                                  children: [
                                    for (int z = 1; z <= 5; z++)
                                      if ((zones[z] ?? 0) > 0)
                                        Flexible(
                                          flex: ((zones[z]! / totalZoneSec) * 100).round(),
                                          child: Container(
                                            height: 10,
                                            color: _zoneColor(z),
                                          ),
                                        ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  for (int z = 1; z <= 5; z++)
                                    if ((zones[z] ?? 0) > 0) ...[
                                      Container(
                                        width: 8, height: 8,
                                        decoration: BoxDecoration(
                                          color: _zoneColor(z),
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      const SizedBox(width: 3),
                                      Text(
                                        'Z$z',
                                        style: AppTypography.small.copyWith(
                                          color: AppColors.iconMutedOf(context),
                                          fontSize: 10,
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                    ],
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Recreativo ──────────────────────────────────────────────────────────────

  List<Widget> _buildRecreativoContent() {
    return [
      _buildWhatTodayCard(),
      const SizedBox(height: AppSpacing.xl),
      _buildPersonalRecords(),
    ];
  }

  Widget _buildWhatTodayCard() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Text('◇', style: TextStyle(color: AppColors.brand, fontSize: 14)),
            const SizedBox(width: 8),
            Text(
              '¿QUÉ QUIERES HACER HOY?',
              style: AppTypography.small.copyWith(
                color: AppColors.brand,
                letterSpacing: 1.2,
                fontWeight: FontWeight.w700,
              ),
            ),
          ]),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.play_arrow_rounded),
              label: const Text('ENTRENAR AHORA'),
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
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              icon: const Icon(Icons.diamond_outlined),
              label: const Text('PASAR A MODO ATLETA'),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.brand),
                foregroundColor: AppColors.brand,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppDimens.buttonRadius),
                ),
              ),
              onPressed: _vm.toggleAthleteMode,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPersonalRecords() {
    return ValueListenableBuilder<Map<int, PersonalRecord>>(
      valueListenable: _vm.personalRecords,
      builder: (_, records, __) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'TU PROGRESO',
              style: AppTypography.small.copyWith(
                color: AppColors.iconMutedOf(context),
                letterSpacing: 1.2,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: AppSpacing.m),
            _card(
              child: records.isEmpty
                  ? Text(
                      'Aún no hay records. ¡Sal a entrenar!',
                      style: AppTypography.small.copyWith(color: AppColors.iconMutedOf(context)),
                    )
                  : Column(
                      children: records.entries.map((e) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: AppSpacing.s),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 80,
                                child: Text(
                                  _formatDistance(e.key),
                                  style: AppTypography.body.copyWith(
                                    color: AppColors.textSecondary(context),
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  _formatPace(e.value.paceSecPerKm),
                                  style: AppTypography.body.copyWith(
                                    color: AppColors.textPrimary(context),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
            ),
          ],
        );
      },
    );
  }

  // ── Entrenamientos recientes (compartido) ────────────────────────────────────

  Widget _buildRecentWorkouts() {
    return ValueListenableBuilder<List<Entrenamiento>>(
      valueListenable: _vm.recentWorkouts,
      builder: (_, workouts, __) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: AppSpacing.xl),
            Row(
              children: [
                Text(
                  'ÚLTIMOS ENTRENAMIENTOS',
                  style: AppTypography.small.copyWith(
                    color: AppColors.iconMutedOf(context),
                    letterSpacing: 1.2,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () => Navigator.push(
                    context,
                    AppRoute(page: const HistoryScreen()),
                  ),
                  child: Text(
                    'Ver todos',
                    style: AppTypography.small.copyWith(color: AppColors.brand),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.m),
            if (workouts.isEmpty)
              Text(
                'Sin entrenamientos todavía',
                style: AppTypography.small.copyWith(color: AppColors.iconMutedOf(context)),
              )
            else
              Column(
                children: workouts.map((w) => _buildWorkoutRow(w)).toList(),
              ),
          ],
        );
      },
    );
  }

  Widget _buildWorkoutRow(Entrenamiento w) {
    final km = (w.distanciaTotalM() / 1000).toStringAsFixed(1);
    String pace = '';
    try {
      pace = w.ritmoMedioTexto();
    } catch (_) {}

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.s),
      padding: const EdgeInsets.all(AppSpacing.m),
      decoration: BoxDecoration(
        color: AppColors.surfaceOf(context),
        border: Border.all(color: AppColors.borderOf(context), width: 0.5),
        borderRadius: BorderRadius.circular(AppDimens.cardRadius),
      ),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _formatWorkoutDate(w.fecha),
                style: AppTypography.body.copyWith(color: AppColors.textPrimary(context)),
              ),
              const SizedBox(height: 2),
              Text(
                w.titulo.isNotEmpty ? w.titulo : 'Entrenamiento libre',
                style: AppTypography.small.copyWith(color: AppColors.iconMutedOf(context)),
              ),
            ],
          ),
          const Spacer(),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$km km',
                style: AppTypography.body.copyWith(color: AppColors.textPrimary(context)),
              ),
              if (pace.isNotEmpty)
                Text(pace, style: AppTypography.small.copyWith(color: AppColors.iconMutedOf(context))),
            ],
          ),
          const SizedBox(width: AppSpacing.s),
          const Icon(Icons.check_circle, size: 16, color: AppColors.brand),
        ],
      ),
    );
  }

  // ── Helpers UI ───────────────────────────────────────────────────────────────

  Widget _card({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.l),
      decoration: BoxDecoration(
        color: AppColors.surfaceOf(context),
        border: Border.all(color: AppColors.borderOf(context), width: 0.5),
        borderRadius: BorderRadius.circular(AppDimens.cardRadius),
      ),
      child: child,
    );
  }

  // ── Helpers de datos ─────────────────────────────────────────────────────────

  String _categoryLabel(String? cat) {
    if (cat == null || cat.isEmpty) return 'Entrenamiento';
    const map = {
      'series_cortas':   'Series cortas',
      'series_largas':   'Series largas',
      'series_cuestas':  'Series en cuesta',
      'series_mixtas':   'Series mixtas',
      'tempo':           'Tempo',
      'fartlek':         'Fartlek',
      'rodaje_base':     'Rodaje base',
      'regenerativo':    'Regenerativo',
      'competicion':     'Competición',
      'test':            'Test',
    };
    return map[cat] ?? cat;
  }

  String _blockSummary(SessionBlock b) {
    if (b.reps != null && b.distanceM != null) {
      return '• ${b.reps}×${b.distanceM}m';
    }
    if (b.distanceM != null) return '• ${b.distanceM}m';
    if (b.durationMinutes != null) return '• ${b.durationMinutes} min';
    return '• bloque';
  }

  String _weekdayLabel(String dateStr) {
    final d = DateTime.tryParse(dateStr);
    if (d == null) return dateStr;
    const dias = ['Lunes','Martes','Miérc.','Jueves','Viernes','Sábado','Domingo'];
    return dias[d.weekday - 1];
  }

  String _todayDateStr() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  String _formatDistance(int meters) {
    if (meters >= 1000) return '${meters ~/ 1000} km';
    return '${meters}m';
  }

  String _formatPace(double secPerKm) {
    final m = secPerKm ~/ 60;
    final s = (secPerKm % 60).toInt();
    return '$m:${s.toString().padLeft(2, '0')}/km';
  }

  String _formatWorkoutDate(DateTime d) {
    final now = DateTime.now();
    final diff = now.difference(d).inDays;
    if (diff == 0) return 'Hoy';
    if (diff == 1) return 'Ayer';
    const meses = ['ene','feb','mar','abr','may','jun','jul','ago','sep','oct','nov','dic'];
    return '${d.day} ${meses[d.month - 1]}';
  }
}

// ── Widgets ──────────────────────────────────────────────────────────────────

class _StatItem extends StatelessWidget {
  const _StatItem({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: AppTypography.h3.copyWith(color: AppColors.brand),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: AppTypography.small.copyWith(color: AppColors.iconMutedOf(context)),
        ),
      ],
    );
  }
}
