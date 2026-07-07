import 'dart:math' show min;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:running_laps/core/theme/app_colors.dart';
import 'package:running_laps/core/theme/app_theme.dart';
import 'package:running_laps/core/utils/app_transitions.dart';
import 'package:running_laps/core/widgets/main_shell.dart';
import 'package:running_laps/core/widgets/block_preview_tile.dart';
import 'package:running_laps/features/training/views/pre_execution_screen.dart';
import 'package:running_laps/features/athlete/data/athlete_session_model.dart';
import 'package:running_laps/features/athlete/data/progress_repository.dart';
import 'package:running_laps/features/home/viewmodels/home_view_model.dart';
import 'package:running_laps/features/training/data/entrenamiento.dart';
import 'package:running_laps/features/templates/data/athlete_session_mapper.dart';
import 'package:running_laps/features/training/views/training_start_view.dart';
import 'package:running_laps/features/training/views/complete_session_manually_view.dart';
import 'package:running_laps/core/widgets/modern_snackbar.dart';
import 'package:running_laps/features/ai_coach/data/ai_coach_automation_service.dart';
import 'package:running_laps/features/ai_coach/data/ai_coach_models.dart';
import 'package:running_laps/features/ai_coach/data/ai_coach_repository.dart';
import 'package:running_laps/features/ai_coach/views/ai_coach_onboarding_launcher.dart';
import 'package:running_laps/features/ai_coach/views/ai_coach_weekly_feedback_view.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

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

class _HomeViewState extends State<HomeView> with WidgetsBindingObserver {
  HomeViewModel? _vm;
  bool _vmReady = false;
  bool _hasAiCoachProfile = false;
  bool _showFeedbackBanner = false;
  bool _showMissingPlanBanner = false;
  bool _initialized = false;
  AiCoachWeeklyState? _weeklyState;

  String _weekStartStr(DateTime monday) =>
      '${monday.year}-${monday.month.toString().padLeft(2, '0')}-${monday.day.toString().padLeft(2, '0')}';

  String _feedbackWeekToEvaluate() {
    final now = DateTime.now();
    final weekday = now.weekday;
    if (weekday >= 6) {
      final monday = now.subtract(Duration(days: weekday - 1));
      return _weekStartStr(monday);
    } else if (weekday <= 2) {
      final lastMonday = now.subtract(Duration(days: weekday - 1 + 7));
      return _weekStartStr(lastMonday);
    }
    return '';
  }

  String _feedbackBannerTitle() {
    final weekday = DateTime.now().weekday;
    return weekday <= 2 ? '¿Cómo fue la semana pasada?' : '¿Cómo fue la semana?';
  }

  Future<void> _checkWeeklyFeedback(String uid) async {
    if (!_hasAiCoachProfile) {
      return;
    }

    final weekToEval = _feedbackWeekToEvaluate();

    if (weekToEval.isEmpty) {
      if (mounted) setState(() => _showFeedbackBanner = false);
      return;
    }

    final existing = await AiCoachRepository().getWeeklyFeedback(
      uid: uid,
      weekStart: weekToEval,
    );

    if (mounted) {
      setState(() => _showFeedbackBanner = existing == null);
    }

    if (DateTime.now().weekday == 7 && existing == null) {
      _scheduleWeeklyFeedbackNotification();
    }
  }

  Future<void> _checkMissingPlan(String uid) async {
    if (!_hasAiCoachProfile) return;
    if (_showFeedbackBanner) return;
    final missing =
        await AiCoachAutomationService().isCurrentWeekPlanMissing(uid);
    if (mounted) setState(() => _showMissingPlanBanner = missing);
  }

  Future<void> _generateCurrentWeekPlan() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final generated =
        await AiCoachAutomationService().forceGenerateCurrentWeekPlan(uid);
    if (mounted) {
      if (generated) {
        setState(() => _showMissingPlanBanner = false);
        ModernSnackBar.showSuccess(context, 'Plan de esta semana generado');
      } else {
        ModernSnackBar.showError(context, 'No se pudo generar el plan');
      }
    }
  }

  Future<void> _generateAiPlanFromHome() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final generated = await AiCoachAutomationService()
        .forceGenerateNextWeekPlan(uid);
    if (mounted) {
      if (generated) {
        ModernSnackBar.showSuccess(context, 'Plan de la próxima semana generado');
      } else {
        ModernSnackBar.showError(context, 'No se pudo generar el plan');
      }
    }
  }

  Future<void> _scheduleWeeklyFeedbackNotification() async {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'ai_coach_feedback',
      'Feedback semanal',
      channelDescription: 'Recordatorio semanal del coach IA',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
    );
    const NotificationDetails details = NotificationDetails(android: androidDetails);
    await FlutterLocalNotificationsPlugin().show(
      999,
      '¿Cómo fue la semana?',
      'Tu coach quiere saber cómo te has sentido',
      details,
    );
  }

  @override
  void _onNeedsReload() {
    _vm?.loadAll();
  }

  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    HomeViewModel.needsReload.addListener(_onNeedsReload);
    _initWithAuth();
    MainShell.shellKey.currentState?.tabIndexNotifier
        .addListener(_onTabChanged);
  }

  Future<void> _initWithAuth() async {
    // currentUser primero (síncrono, disponible si ya autenticado)
    // authStateChanges como fallback con timeout de 5s
    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      user = await FirebaseAuth.instance.authStateChanges()
          .firstWhere((u) => u != null)
          .timeout(
            const Duration(seconds: 5),
            onTimeout: () => FirebaseAuth.instance.currentUser,
          );
    }
    if (user == null) return;
    if (!mounted) return;
    setState(() {
      _vm = HomeViewModel(userId: user!.uid);
      _vmReady = true;
    });
    _vm!.loadAll();
    _checkAiCoachProfile(user!.uid);
  }

  Future<void> _checkAiCoachProfile(String uid) async {
    final repo = AiCoachRepository();
    final results = await Future.wait([
      repo.getProfile(uid: uid),
      repo.getWeeklyState(uid: uid),
    ]);
    if (!mounted) return;
    setState(() {
      _hasAiCoachProfile = results[0] != null;
      _weeklyState = results[1] as AiCoachWeeklyState?;
    });
    if (results[0] != null) {
      await _checkWeeklyFeedback(uid);
      _checkMissingPlan(uid);
    }
    _initialized = true;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    HomeViewModel.needsReload.removeListener(_onNeedsReload);
    MainShell.shellKey.currentState?.tabIndexNotifier
        .removeListener(_onTabChanged);
    _vm?.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    final currentTab =
        MainShell.shellKey.currentState?.tabIndexNotifier.value;
    if (currentTab == 0 && _initialized) {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        _checkWeeklyFeedback(uid);
        _checkMissingPlan(uid);
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        _checkWeeklyFeedback(uid);
        _checkMissingPlan(uid);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_vmReady) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    return ValueListenableBuilder<bool>(
      valueListenable: _vm!.isLoading,
      builder: (_, loading, __) {
        if (loading) return _buildSkeleton();
        return ValueListenableBuilder<bool>(
          valueListenable: _vm!.isAthleteMode,
          builder: (_, isAthlete, __) {
            return RefreshIndicator(
              color: AppColors.brand,
              onRefresh: _vm!.refresh,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.l),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: AppSpacing.m),
                    _buildDateHeader(isAthlete),
                    const SizedBox(height: AppSpacing.xl),
                    // eliminado — sustituido por tutorial de bienvenida post-onboarding
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
      valueListenable: _vm!.userName,
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
      if (_showFeedbackBanner && _hasAiCoachProfile && _feedbackWeekToEvaluate().isNotEmpty) _buildFeedbackBanner()
      else if (_showMissingPlanBanner && _hasAiCoachProfile) _buildMissingPlanBanner(),
      if (!_hasAiCoachProfile) _buildAiCoachCta(),
      _buildTodaySessionCard(),
      const SizedBox(height: AppSpacing.xl),
      _buildWeekSessionsList(),
    ];
  }

  Widget _buildFeedbackBanner() => Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.xl),
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
          border: Border.all(color: AppColors.brand.withValues(alpha: 0.25)),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () async {
              await Navigator.of(context).push(AppRoute(
                page: AiCoachWeeklyFeedbackView(
                  weekStart: _feedbackWeekToEvaluate(),
                  generatePlanAfter: true,
                  daysSinceLastTraining:
                      _weeklyState?.daysSinceLastTraining ?? 0,
                  consecutiveMissedWeeks:
                      _weeklyState?.consecutiveMissedWeeks ?? 0,
                  onCompleted: () {
                    if (!mounted) return;
                    setState(() => _showFeedbackBanner = false);
                  },
                ),
              ));
            },
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.brand.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.rate_review_outlined,
                        color: AppColors.brand, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _feedbackBannerTitle(),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary(context),
                          ),
                        ),
                        Text(
                          'Cuéntale a tu coach cómo te has sentido',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded, color: AppColors.brand),
                ],
              ),
            ),
          ),
        ),
      );

  Widget _buildMissingPlanBanner() {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.xl),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.brand.withValues(alpha: 0.10),
            AppColors.brand.withValues(alpha: 0.03),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.brand.withValues(alpha: 0.20)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: _generateCurrentWeekPlan,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.brand.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.calendar_month_outlined,
                      color: AppColors.brand, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'No tienes plan para esta semana',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary(context),
                        ),
                      ),
                      Text(
                        'Toca para generar tu plan ahora',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary(context),
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: AppColors.brand),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAiCoachCta() {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.xl),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.brand.withValues(alpha: 0.15),
            AppColors.brand.withValues(alpha: 0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.brand.withValues(alpha: 0.3)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => launchAiCoachOnboarding(
            context,
            onCompleted: () async {
              if (!mounted) return;
              setState(() => _hasAiCoachProfile = true);
            },
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.brand.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.auto_awesome_rounded,
                      color: AppColors.brand, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Activa tu entrenador IA',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary(context),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Planes personalizados según tu historial y objetivos',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary(context),
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded, color: AppColors.brand),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTodaySessionCard() {
    return ValueListenableBuilder<AthleteSession?>(
      valueListenable: _vm!.completedTodaySession,
      builder: (_, completed, __) {
        return ValueListenableBuilder<AthleteSession?>(
          valueListenable: _vm!.todaySession,
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
                  if (session != null)
                    ..._buildPlannedSessionContent(session)
                  else if (completed != null)
                    ValueListenableBuilder<String?>(
                      valueListenable: _vm!.completedTodayCoachAnalysis,
                      builder: (_, analysis, __) => Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children:
                            _buildCompletedSessionContent(completed, analysis),
                      ),
                    )
                  else
                    ..._buildNoSessionContent(),
                ],
              ),
            );
          },
        );
      },
    );
  }

  List<Widget> _buildPlannedSessionContent(AthleteSession session) {
    return [
      Text(
        _categoryLabel(session.category),
        style: AppTypography.h3.copyWith(color: AppColors.textPrimary(context)),
      ),
      if (session.blocks.isNotEmpty) ...[
        const SizedBox(height: 8),
        ...session.blocks.take(3).map((b) =>
            BlockPreviewTile(
              block: b,
              style: BlockPreviewStyle.card,
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
          onPressed: () {
            final workoutSession = mapAthleteSessionToWorkout(session);
            if (workoutSession != null) {
              Navigator.of(context).push(AppRoute(
                page: PreExecutionScreen(
                  session: workoutSession,
                  athleteSession: session,
                ),
              ));
            } else {
              Navigator.push(context, AppRoute(page: const TrainingStartView()));
            }
          },
          child: const Text('EMPEZAR ENTRENAMIENTO'),
        ),
      ),
      Center(
        child: TextButton(
          style: TextButton.styleFrom(foregroundColor: AppColors.textSecondary(context)),
          onPressed: () => Navigator.push(
            context,
            AppRoute(page: CompleteSessionManuallyView(session: session)),
          ),
          child: const Text('Completar manualmente'),
        ),
      ),
    ];
  }

  List<Widget> _buildCompletedSessionContent(
      AthleteSession session, String? coachAnalysis) {
    final hasAnalysis = coachAnalysis != null && coachAnalysis.isNotEmpty;
    return [
      Row(
        children: [
          const Icon(Icons.check_circle_rounded, color: AppColors.rpeLow, size: 16),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              session.title ?? _categoryLabel(session.category),
              style: AppTypography.h3.copyWith(color: AppColors.textPrimary(context)),
            ),
          ),
        ],
      ),
      if (!hasAnalysis) ...[
        const SizedBox(height: 4),
        Text(
          '¡Buen trabajo! Revisa tu resumen en el historial.',
          style: AppTypography.small.copyWith(color: AppColors.iconMutedOf(context)),
        ),
      ],
      if (hasAnalysis) ...[
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.brand.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.auto_awesome_outlined, size: 15, color: AppColors.brand),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  coachAnalysis,
                  style: AppTypography.small.copyWith(
                    color: AppColors.textPrimary(context),
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    ];
  }

  List<Widget> _buildNoSessionContent() {
    return [
      Text(
        'No hay sesión planificada para hoy',
        style: AppTypography.body.copyWith(color: AppColors.iconMutedOf(context)),
      ),
      const SizedBox(height: 4),
      Text(
        'Puedes entrenar libre o planificar en el calendario',
        style: AppTypography.small.copyWith(color: AppColors.iconMutedOf(context)),
      ),
    ];
  }

  Widget _buildWeekSessionsList() {
    return ValueListenableBuilder<AthleteSession?>(
      valueListenable: _vm!.todaySession,
      builder: (_, today, __) {
        return ValueListenableBuilder<List<AthleteSession>>(
          valueListenable: _vm!.weekSessions,
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
      valueListenable: _vm!.weeklyVolumeKm,
      builder: (_, km, __) => ValueListenableBuilder<int>(
        valueListenable: _vm!.weeklySessionCount,
        builder: (_, count, __) => ValueListenableBuilder<int>(
          valueListenable: _vm!.weeklyTimeMinutes,
          builder: (_, minutes, __) => ValueListenableBuilder<double>(
            valueListenable: _vm!.weeklyRpeAvg,
            builder: (_, rpe, __) => ValueListenableBuilder<double>(
              valueListenable: _vm!.weeklyLoadTotal,
              builder: (_, load, __) => ValueListenableBuilder<Map<int, double>>(
                valueListenable: _vm!.weeklyZoneSeconds,
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
              onPressed: _vm!.toggleAthleteMode,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPersonalRecords() {
    return ValueListenableBuilder<Map<int, PersonalRecord>>(
      valueListenable: _vm!.personalRecords,
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
      valueListenable: _vm!.recentWorkouts,
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
                  onTap: () => MainShell.shellKey.currentState?.navigateTo(4),
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
    final today = DateTime(now.year, now.month, now.day);
    final workoutDay = DateTime(d.year, d.month, d.day);
    final diff = today.difference(workoutDay).inDays;
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
