// ⚠️ HUÉRFANO — sin referencias activas detectadas
// por auditoría del 2026-06-19. NO USAR como base para
// nuevo desarrollo. Pendiente de confirmar con testing
// manual antes de eliminar. Ver CHANGELOG.md.
import 'package:flutter/material.dart';
import 'package:running_laps/core/utils/app_transitions.dart';

import 'package:firebase_auth/firebase_auth.dart';

import 'package:running_laps/features/training/data/entrenamiento.dart';
import 'package:running_laps/features/training/data/training_repository.dart';
import 'package:running_laps/features/home/widgets/home_flagship_chart.dart'; // Added Chart Import
import 'package:running_laps/features/training/views/training_start_view.dart';
import 'package:running_laps/features/profile/views/profile_menu_screen_legacy.dart';
import 'package:running_laps/core/widgets/kpi_card_with_delta.dart';
import 'package:running_laps/core/constants/app_help_content.dart';
import 'package:running_laps/config/app_theme.dart';
import 'package:running_laps/core/services/settings_service.dart';
import 'package:running_laps/core/theme/app_colors.dart' hide AppColors;

// GROUPS IMPORTS
import 'package:running_laps/features/groups/data/repositories/groups_repository.dart';
import 'package:running_laps/features/groups/data/repositories/user_groups_repository.dart';
import 'package:running_laps/features/groups/data/models/group_models.dart';
import 'package:running_laps/features/groups/views/groups_list_screen.dart';
import 'package:running_laps/features/groups/views/group_screen.dart';
import 'package:running_laps/core/widgets/group_skeleton_card.dart';
import 'package:running_laps/core/widgets/skeleton_shimmer.dart';
import 'package:running_laps/features/analytics/data/coach_insight_service.dart';
import 'package:running_laps/features/analytics/widgets/coach_insight_widget.dart';
import 'package:running_laps/features/home/data/global_challenges_repository.dart';
import 'package:running_laps/features/home/widgets/global_challenge_card.dart';
import 'package:running_laps/features/groups/data/models/challenge_models.dart';
import 'package:running_laps/features/groups/data/models/result_notification_model.dart';
import 'package:running_laps/features/groups/views/widgets/challenge_result_dialog.dart';
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:running_laps/features/athlete/data/athlete_session_model.dart';
import 'package:running_laps/features/athlete/data/athlete_session_repository.dart';
import 'package:running_laps/features/templates/data/template_models.dart';
import 'package:running_laps/core/widgets/modern_snackbar.dart';
import 'package:running_laps/core/services/session_recovery_service.dart';

/// Home View rediseñado con widgets configurables
/// Versión moderna con sistema de personalización
class HomeView extends StatefulWidget {
  const HomeView({super.key, this.user});

  final User? user;

  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> with TickerProviderStateMixin {
  final TrainingRepository _trainingRepository = TrainingRepository();
  final GroupsRepository _groupsRepository = GroupsRepository();
  final UserGroupsRepository _userGroupsRepository = UserGroupsRepository();
  final CoachInsightService _coachService = CoachInsightService();
  final GlobalChallengesRepository _globalChallengesRepo =
      GlobalChallengesRepository();
  final PageController _challengesPageController = PageController();
  int _challengesPage = 0;
  RecoveredSession? _recoveredSession;

  List<Entrenamiento> _entrenamientos = [];
  Map<String, dynamic>? _userDoc;
  bool _isLoadingData = true;
  int _bestMarkDistanceM = 400;

  // Groups State
  Future<List<Group>>? _userGroupsFuture;

  AthleteSession? _todaySession;

  StreamSubscription? _notifSubscription;
  String? _currentUserId;
  final Set<String> _showingNotifIds = {};
  bool _isShowingDialog = false;

  // ── Entrance animation ──────────────────────────────────────────
  // Single controller, 900ms. Each element gets a Interval slice.
  // Played once on first load; pull-to-refresh does NOT re-trigger.
  late final AnimationController _entranceController;
  bool _entranceAnimationPlayed = false;
  late final Animation<double> _aGreeting;    // delay   0ms
  late final Animation<double> _aCoach;       // delay  80ms
  late final Animation<double> _aChallenges;  // delay 120ms
  late final Animation<double> _aKpi0;        // delay 160ms  (Km totales)
  late final Animation<double> _aKpi1;     // delay 220ms  (Ritmo medio)
  late final Animation<double> _aKpi2;     // delay 280ms  (Sesiones)
  late final Animation<double> _aKpi3;     // delay 340ms  (Tiempo total)
  late final Animation<double> _aChart;    // delay 420ms
  late final Animation<double> _aRecent;   // delay 500ms
  late final Animation<double> _aGroups;   // delay 580ms
  // ────────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _aGreeting    = CurvedAnimation(parent: _entranceController, curve: const Interval(0.000, 0.517, curve: Curves.easeOutQuart));
    _aCoach       = CurvedAnimation(parent: _entranceController, curve: const Interval(0.067, 0.583, curve: Curves.easeOutQuart));
    _aChallenges  = CurvedAnimation(parent: _entranceController, curve: const Interval(0.100, 0.617, curve: Curves.easeOutQuart));
    _aKpi0        = CurvedAnimation(parent: _entranceController, curve: const Interval(0.133, 0.650, curve: Curves.easeOutQuart));
    _aKpi1     = CurvedAnimation(parent: _entranceController, curve: const Interval(0.183, 0.700, curve: Curves.easeOutQuart));
    _aKpi2     = CurvedAnimation(parent: _entranceController, curve: const Interval(0.233, 0.750, curve: Curves.easeOutQuart));
    _aKpi3     = CurvedAnimation(parent: _entranceController, curve: const Interval(0.283, 0.800, curve: Curves.easeOutQuart));
    _aChart    = CurvedAnimation(parent: _entranceController, curve: const Interval(0.350, 0.867, curve: Curves.easeOutQuart));
    _aRecent   = CurvedAnimation(parent: _entranceController, curve: const Interval(0.417, 0.933, curve: Curves.easeOutQuart));
    _aGroups   = CurvedAnimation(parent: _entranceController, curve: const Interval(0.483, 1.000, curve: Curves.easeOutQuart));
    _currentUserId = widget.user?.uid ?? FirebaseAuth.instance.currentUser?.uid ?? '';
    _initializeHome();
    _loadGroups();
    _initNotificationListener();
    _loadTodaySession();
    _checkRecoveredSession();
  }

  Future<void> _checkRecoveredSession() async {
    final session = await SessionRecoveryService().loadSession();
    if (session != null && mounted) {
      setState(() => _recoveredSession = session);
    }
  }

  void _resumeSession() {
    final session = _recoveredSession!;
    setState(() => _recoveredSession = null);
    Navigator.push(
      context,
      AppRoute(
        page: TrainingStartView(
          recoveredSeries: session.series,
          recoveredStartTime: session.startTime,
        ),
      ),
    );
  }

  void _discardSession() {
    SessionRecoveryService().clearSession();
    setState(() => _recoveredSession = null);
  }

  Future<void> _loadTodaySession() async {
    try {
      final uid = _currentUserId;
      if (uid == null || uid.isEmpty) return;
      final today = DateTime.now();
      final dateStr = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
      final sessions = await AthleteSessionRepository()
          .getSessionsForDate(uid: uid, date: dateStr);
      final pending = sessions
          .where((s) => s.status == AthleteSessionStatus.planned)
          .toList();
      if (!mounted) return;
      setState(() => _todaySession = pending.isNotEmpty ? pending.first : null);
    } catch (e) {
      debugPrint('Error cargando sesión de hoy: $e');
    }
  }

  Future<void> _launchGuidedSession(
    BuildContext context,
    AthleteSession session,
  ) async {
    if (session.blocks.isEmpty) {
      ModernSnackBar.showError(context, 'Esta sesión no tiene series configuradas');
      return;
    }
    final now    = DateTime.now();
    final blocks = session.blocks.asMap().entries.map((e) {
      final b          = e.value;
      final isDistance = b.distanceM != null;
      return TemplateBlock(
        id:          b.id,
        order:       e.key,
        type:        isDistance ? TemplateBlockType.distance : TemplateBlockType.time,
        value:       isDistance ? b.distanceM! : (b.durationMinutes ?? 0) * 60,
        restSeconds: b.restSeconds ?? 0,
        alerts: TemplateAlerts(
          enabled:         b.targetPaceMinMin != null,
          mode:            'pace',
          timeMin:         0,
          timeSec:         0,
          paceMin:         b.targetPaceMinMin ?? 0,
          paceSec:         b.targetPaceMinSec ?? 0,
          segmentDistance: b.distanceM ?? 1000,
        ),
        targetPaceMin: b.targetPaceMinMin,
        targetPaceSec: b.targetPaceMinSec,
        targetRpe:     b.targetRpe,
        targetZone:    b.targetZone,
      );
    }).toList();

    final sessionName = session.category != null
        ? SessionCategoryX.fromValue(session.category!).label
        : 'Sesión planificada';

    final template = TrainingTemplate(
      id:               session.id,
      name:             sessionName,
      colorValue:       AppColors.brand.value,
      isWarmupCooldown: false,
      blocks:           blocks,
      createdAt:        now,
      updatedAt:        now,
    );

    if (!context.mounted) return;
    Navigator.push(
      context,
      AppRoute(
        page: TrainingStartView(
          sourceTemplate:   template,
          athleteSessionId: session.id,
        ),
      ),
    );
  }

  void _loadGroups() {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId != null) {
      _userGroupsFuture = _fetchUserGroups(userId);
    } else {
      _userGroupsFuture = Future.value([]);
    }
  }

  Future<List<Group>> _fetchUserGroups(String userId) async {
    try {
      final groupIds = await _userGroupsRepository.getUserGroupIds(userId);
      if (groupIds.isEmpty) return [];

      final groups = <Group>[];
      for (final id in groupIds) {
        final g = await _groupsRepository.getGroupById(id);
        if (g != null) groups.add(g);
      }
      return groups;
    } catch (e) {
      return [];
    }
  }

  Future<void> _initializeHome() async {
    await SettingsService().initCardStyle();
    await _loadBestMarkDistance();
    await _loadEntrenamientos();
  }

  Future<void> _loadBestMarkDistance() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('settings')
          .doc('bestMarkDistance')
          .get();
      if (doc.exists && doc.data()?['distanceM'] != null && mounted) {
        setState(() {
          _bestMarkDistanceM = (doc.data()!['distanceM'] as num).toInt();
        });
      }
    } catch (_) {}
  }

  Future<void> _loadEntrenamientos() async {
    setState(() => _isLoadingData = true);

    try {
      final userId = widget.user?.uid ?? FirebaseAuth.instance.currentUser?.uid;
      if (userId != null) {
        final results = await Future.wait([
          _trainingRepository.getAllEntrenamientos(userId),
          FirebaseFirestore.instance.collection('users').doc(userId).get(),
        ]);
        final allData = results[0] as List<Entrenamiento>;
        final doc = results[1] as DocumentSnapshot;
        setState(() {
          _entrenamientos = allData..sort((a, b) => b.fecha.compareTo(a.fecha));
          if (doc.exists) _userDoc = doc.data() as Map<String, dynamic>?;
        });
      }
    } catch (e) {
      // Error loading
    } finally {
      setState(() => _isLoadingData = false);
      if (mounted && !_entranceAnimationPlayed) {
        _entranceAnimationPlayed = true;
        _entranceController.forward();
      }
    }
  }

  @override
  void dispose() {
    _entranceController.dispose();
    _challengesPageController.dispose();
    _notifSubscription?.cancel();
    super.dispose();
  }

  void _initNotificationListener() {
    if (_currentUserId == null || _currentUserId!.isEmpty) return;
    
    _notifSubscription?.cancel();
    _notifSubscription = FirebaseFirestore.instance
        .collection('users')
        .doc(_currentUserId)
        .collection('result_notifications')
        .orderBy('createdAt', descending: true)
        .limit(20)
        .snapshots()
        .listen((snapshot) {
      if (!mounted) return;
      if (snapshot.docs.isNotEmpty) {
        for (final doc in snapshot.docs) {
          final notifId = doc.id;
          
          // Si ya la estamos mostrando o ya hay un diálogo abierto, pasamos
          if (_showingNotifIds.contains(notifId)) continue;
          if (_isShowingDialog) break; 

          final notif = GroupResultNotification.fromMap(doc.data(), notifId);
          _showingNotifIds.add(notifId);
          
          // Pequeño delay de cortesía (solo 500ms) para no ser brusco
          Future.delayed(const Duration(milliseconds: 500), () {
            if (mounted && !_isShowingDialog) {
              _showResultDialog(notif);
            }
          });
          break; // Solo procesamos una por snapshot
        }
      }
    });
  }

  void _showResultDialog(GroupResultNotification notif) {
    if (!mounted || _isShowingDialog) return;
    
    setState(() {
      _isShowingDialog = true;
    });

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return ChallengeResultDialog(
          notification: notif,
          onClosed: () async {
            // 1. Cerrar el diálogo usando su propio contexto
            if (dialogContext.mounted) {
              Navigator.of(dialogContext).pop();
            }
            
            // 2. Liberar el estado para la siguiente notificación
            if (mounted) {
              setState(() {
                _isShowingDialog = false;
              });
            }

            // 3. Borrar de Firestore (esto disparará el siguiente snapshot si hay más)
            try {
              await FirebaseFirestore.instance
                  .collection('users')
                  .doc(_currentUserId)
                  .collection('result_notifications')
                  .doc(notif.id)
                  .delete();
            } catch (e) {
              // Error deleting
            }
          },
        );
      },
    ).then((_) {
      // Backup por si se cierra por otros medios (aunque barrierDismissible es false)
      if (mounted && _isShowingDialog) {
        setState(() {
          _isShowingDialog = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // extendBody permite que el footer llegue hasta el borde inferior de la pantalla
      body: Column(
        children: [
          // El header cubre TAMBIÉN la zona del status bar (safe area superior)
          _buildHeader(),
          // El body solo ocupa el espacio seguro central
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final topPadding = MediaQuery.of(context).padding.top;
    return Container(
      decoration: isDark
          ? BoxDecoration(color: Theme.of(context).colorScheme.surface)
          : const BoxDecoration(
              color: Colors.white,
              image: DecorationImage(
                image: AssetImage('assets/images/fondo.png'),
                fit: BoxFit.cover,
              ),
            ),
      child: Column(
        children: [
          // Ocupa la zona del status bar con el color del header
          SizedBox(height: topPadding),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Logo
                const CircleAvatar(
                  radius: 24,
                  backgroundColor: AppColors.brand,
                  backgroundImage: AssetImage('assets/images/logo.png'),
                ),
                
                // Avatar perfil
                GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      AppRoute(page: const ProfileMenuView()),
                    );
                  },
                  child: Hero(
                    tag: 'profile_avatar',
                    child: AvatarHelper.construirImagenPerfil(radius: 24),
                  ),
                ),
              ],
            ),
          ),
          Container(height: 1, color: Theme.of(context).colorScheme.outline.withOpacity(0.5)),
        ],
      ),
    );
  }


  Widget _buildBody() {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: _isLoadingData
          ? _buildHomeLoadingSkeleton()
          : _buildHomeContent(),
    );
  }

  Widget _buildHomeContent() {
    return RefreshIndicator(
      key: const ValueKey('home_content'),
      onRefresh: _loadEntrenamientos,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _slideFromLeft(_aGreeting, _buildWelcomeHeader()),
            const SizedBox(height: 12),
            if (_recoveredSession != null)
              _RecoveryBanner(
                session: _recoveredSession!,
                onResume: _resumeSession,
                onDiscard: _discardSession,
              ),
            if (_todaySession != null) ...[
              _TodaySessionBanner(
                session: _todaySession!,
                onTap: () => _launchGuidedSession(context, _todaySession!),
              ),
              const SizedBox(height: 12),
            ],
            if (_entrenamientos.isEmpty) ...[
              const SizedBox(height: 8),
              _buildEmptyHomeState(),
            ] else ...[
              _slideFromLeft(_aCoach, CoachInsightWidget(insight: _coachService.generateInsight(_entrenamientos))),
              const SizedBox(height: 24),
              _slideFromBottom(_aChallenges, _buildGlobalChallengesSection()),
              ValueListenableBuilder<bool>(
                valueListenable: SettingsService.cardStyleNotifier,
                builder: (_, __, ___) => _buildKPICards(),
              ),
              const SizedBox(height: 32),

              // --- FLAGSHIP CHART ---
              _slideFromBottom(_aChart, HomeFlagshipChart(workouts: _entrenamientos)),
              const SizedBox(height: 32),
              // ----------------------

              _slideFromBottom(_aRecent, _buildRecentWorkoutsSection()),
              const SizedBox(height: 32),
            ],
            _slideFromBottom(_aGroups, _buildGroupsPreview()),
            const SizedBox(height: 100), // Bottom padding
          ],
        ),
      ),
    );
  }

  Widget _buildHomeLoadingSkeleton() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SkeletonShimmer(
      key: const ValueKey('home_loading'),
      builder: (sv) => SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SkeletonLine(width: 160, shimmerValue: sv),
            const SizedBox(height: 20),
            SkeletonBox(height: 80, shimmerValue: sv, borderRadius: 16),
            const SizedBox(height: 24),
            GridView.count(
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              childAspectRatio: 1.05,
              children: List.generate(4, (_) => Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  gradient: LinearGradient(
                    colors: [
                      isDark ? AppColors.skeletonBaseDark  : AppColors.skeletonBaseLight,
                      isDark ? AppColors.skeletonShineDark : AppColors.skeletonShineLight,
                      isDark ? AppColors.skeletonBaseDark  : AppColors.skeletonBaseLight,
                    ],
                    stops: const [0.0, 0.5, 1.0],
                    begin: Alignment(-1.0 - sv * 2, 0.0),
                    end: Alignment(1.0 - sv * 2, 0.0),
                  ),
                ),
              )),
            ),
          ],
        ),
      ),
    );
  }




  // --- EMPTY HOME STATE (no trainings yet) ---

  Widget _buildEmptyHomeState() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Skeleton 2×2 preview of the stats grid
        GridView.count(
          crossAxisCount: 2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          shrinkWrap: true,
          padding: EdgeInsets.zero,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 1.05,
          children: [
            _buildSkeletonKPICard(Icons.directions_run, 'Km totales'),
            _buildSkeletonKPICard(Icons.speed, 'Ritmo medio'),
            _buildSkeletonKPICard(Icons.fitness_center, 'Sesiones'),
            _buildSkeletonKPICard(Icons.emoji_events_outlined, 'Mejor marca'),
          ],
        ),
        const SizedBox(height: 20),
        Text(
          'Aquí verás tus km, ritmo y progreso',
          style: TextStyle(
            fontSize: 14,
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
            height: 1.4,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 20),
        SizedBox(
          height: 52,
          child: ElevatedButton(
            onPressed: () => Navigator.push(
              context,
              AppRoute(page: const TrainingStartView()),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.brand,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: const Text(
              'Entrenar ahora',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSkeletonKPICard(IconData icon, String label) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.transparent : Colors.black.withOpacity(0.04),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Grayed-out icon box
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.06),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3), size: 22),
          ),
          const Spacer(),
          // Label
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 3),
          // Value placeholder
          Text(
            '—',
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w700,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
              height: 1.0,
            ),
          ),
        ],
      ),
    );
  }

  // --- GLOBAL CHALLENGES SECTION ---
  Widget _buildGlobalChallengesSection() {
    return StreamBuilder<List<Challenge>>(
      stream: _globalChallengesRepo.streamActiveChallenges(),
      builder: (context, snap) {
        final challenges = snap.data ?? [];
        if (challenges.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Row(
                children: [
                  Text(
                    'Retos Activos',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.brand.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${challenges.length}',
                      style: TextStyle(
                        color: Theme.of(context).brightness == Brightness.dark ? AppColors.brandLight : AppColors.brand,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (challenges.length == 1)
              GlobalChallengeCard(
                challenge: challenges[0],
                userId: _currentUserId!,
                repository: _globalChallengesRepo,
              )
            else ...[
              SizedBox(
                height: 190,
                child: PageView.builder(
                  controller: _challengesPageController,
                  onPageChanged: (i) => setState(() => _challengesPage = i),
                  itemCount: challenges.length,
                  itemBuilder: (_, i) => Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: GlobalChallengeCard(
                      challenge: challenges[i],
                      userId: _currentUserId!,
                      repository: _globalChallengesRepo,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(challenges.length, (i) {
                  final active = _challengesPage.clamp(0, challenges.length - 1) == i;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: active ? 16 : 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: active
                          ? AppColors.brand
                          : Theme.of(context).colorScheme.outline.withOpacity(0.4),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  );
                }),
              ),
            ],
            const SizedBox(height: 24),
          ],
        );
      },
    );
  }

  // --- GROUPS PREVIEW SECTION ---
  Widget _buildGroupsPreview() {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return const SizedBox.shrink();

    return Column(
      children: [
        // HEADER DE SECCIÓN
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Mis comunidades",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    AppRoute(page: const GroupsListScreen()),
                  ).then((_) {
                     setState(() {
                       _loadGroups();
                     });
                  });
                },
                child: Text(
                  "Ver todos",
                  style: TextStyle(
                    color: Theme.of(context).brightness == Brightness.dark ? AppColors.brandLight : AppColors.brand,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),

        // LISTA DE TARJETAS
        FutureBuilder<List<Group>>(
          future: _userGroupsFuture,
          builder: (context, snapshot) {
             if (snapshot.connectionState == ConnectionState.waiting) {
              return SizedBox(
                height: 210,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: 3,
                  separatorBuilder: (context, index) => const SizedBox(width: 15),
                  itemBuilder: (context, index) => GroupSkeletonCard(),
                ),
              );
            }

            final groups = snapshot.data ?? [];

            if (groups.isEmpty) {
              return _buildEmptyGroupsState();
            }

            return SizedBox(
              height: 210,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: groups.length,
                separatorBuilder: (context, index) => const SizedBox(width: 15),
                itemBuilder: (context, index) {
                  return _GroupHighlightCard(group: groups[index]);
                },
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildEmptyGroupsState() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.transparent : Colors.black.withOpacity(0.04),
            blurRadius: 20,
            offset: const Offset(0, 10),
          )
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.brand.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.groups_outlined, size: 48, color: Theme.of(context).brightness == Brightness.dark ? AppColors.brandLight : AppColors.brand),
          ),
          const SizedBox(height: 16),
          Text(
            "¡Únete a tu primera comunidad!",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () {
              Navigator.push(
                context,
                AppRoute(page: const GroupsListScreen()),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.brand,
              foregroundColor: Colors.white,
            ),
            child: const Text("Explorar Comunidades"),
          )
        ],
      ),
    );
  }


  // ── Entrance animation helpers ───────────────────────────────────
  Widget _slideFromLeft(Animation<double> anim, Widget child) {
    return AnimatedBuilder(
      animation: anim,
      builder: (_, __) => Opacity(
        opacity: anim.value,
        child: Transform.translate(
          offset: Offset(-24 * (1 - anim.value), 0),
          child: child,
        ),
      ),
    );
  }

  Widget _slideFromBottom(Animation<double> anim, Widget child) {
    return AnimatedBuilder(
      animation: anim,
      builder: (_, __) => Opacity(
        opacity: anim.value,
        child: Transform.translate(
          offset: Offset(0, 24 * (1 - anim.value)),
          child: child,
        ),
      ),
    );
  }

  Widget _scaleIn(Animation<double> anim, Widget child) {
    return AnimatedBuilder(
      animation: anim,
      builder: (_, __) => Opacity(
        opacity: anim.value,
        child: Transform.scale(
          scale: 0.85 + 0.15 * anim.value,
          child: child,
        ),
      ),
    );
  }
  // ────────────────────────────────────────────────────────────────

  Widget _buildWelcomeHeader() {
    final hour = DateTime.now().hour;
    String greeting = hour < 12
        ? '¡Buenos días!'
        : hour < 19
            ? '¡Buenas tardes!'
            : '¡Buenas noches!';

    return Text(
      greeting,
      style: TextStyle(
        fontSize: 28,
        fontWeight: FontWeight.bold,
        color: Theme.of(context).colorScheme.onSurface,
      ),
    );
  }



  Widget _buildKPICards() {
    final isMonochrome = SettingsService.cardStyleNotifier.value;
    Color c(Color vivid) => isMonochrome ? AppColors.brand : vivid;
    final colored = !isMonochrome;

    final totalKm = (_userDoc?['totalKm'] as num?)?.toDouble() ??
        _entrenamientos.fold<double>(0, (s, e) => s + e.distanciaTotalM() / 1000.0);
    final avgPace = _calculateAveragePace();
    final best = _calcBestMarkTime(_bestMarkDistanceM);
    final distLabel = _bestMarkDistanceM >= 1000
        ? '${_bestMarkDistanceM ~/ 1000}k'
        : '${_bestMarkDistanceM}m';

    final cards = <Widget>[
      KpiCardWithDelta(
        title: 'Km totales',
        value: '${totalKm.toStringAsFixed(1)} km',
        primaryColor: c(const Color(0xFF4CAF50)),
        icon: Icons.directions_run,
        compact: true,
        coloredBackground: colored,
        helpText: AppHelpContent.homeKmTotales,
      ),
      KpiCardWithDelta(
        title: 'Ritmo medio',
        value: '${_formatPace(avgPace)} /km',
        primaryColor: c(const Color(0xFF2196F3)),
        icon: Icons.speed,
        isInverted: true,
        compact: true,
        coloredBackground: colored,
        helpText: AppHelpContent.homeRitmoMedio,
      ),
      KpiCardWithDelta(
        title: 'Sesiones',
        value: '${(_userDoc?['totalSessions'] as num?)?.toInt() ?? _entrenamientos.length}',
        primaryColor: c(const Color(0xFFFF9800)),
        icon: Icons.fitness_center,
        compact: true,
        coloredBackground: colored,
        helpText: AppHelpContent.homeSesiones,
      ),
      KpiCardWithDelta(
        title: 'Mejor $distLabel',
        value: best != null ? _formatTime(best) : '-',
        primaryColor: c(const Color(0xFF7B1FA2)),
        icon: Icons.emoji_events_outlined,
        isInverted: true,
        compact: true,
        coloredBackground: colored,
      ),
    ];

    return GridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      shrinkWrap: true,
      padding: EdgeInsets.zero,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.05,
      children: [
        _scaleIn(_aKpi0, cards[0]),
        _scaleIn(_aKpi1, cards[1]),
        _scaleIn(_aKpi2, cards[2]),
        _scaleIn(_aKpi3, cards[3]),
      ],
    );
  }

  // Returns the minimum tiempoSec from series matching targetDistM (±10%)
  double? _calcBestMarkTime(int targetDistM) {
    double? best;
    for (final e in _entrenamientos) {
      for (final s in e.series) {
        if (s.distanciaM <= 0) continue;
        final minD = targetDistM * 0.9;
        final maxD = targetDistM * 1.1;
        if (s.distanciaM < minD || s.distanciaM > maxD) continue;
        if (best == null || s.tiempoSec < best) best = s.tiempoSec;
      }
    }
    return best;
  }

  // Formats seconds as m:ss or mm:ss (e.g. 92s → "1:32", 605s → "10:05")
  String _formatTime(double totalSec) {
    final t = totalSec.round();
    final m = t ~/ 60;
    final s = t % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  double _calculateAveragePace() {
    if (_entrenamientos.isEmpty) return 0;

    double totalMeters = 0;
    double totalSeconds = 0;

    for (var e in _entrenamientos) {
      totalMeters += e.distanciaTotalM();
      totalSeconds += e.tiempoTotalSec();
    }

    if (totalMeters == 0) return 0;
    return (totalSeconds / (totalMeters / 1000.0));
  }

  String _formatPace(double secPerKm) {
    if (secPerKm == 0) return '-';
    final minutes = secPerKm ~/ 60;
    final seconds = (secPerKm % 60).toInt();
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }


  /// Sección de últimos entrenamientos - Premium carousel
  Widget _buildRecentWorkoutsSection() {
    if (_entrenamientos.isEmpty) return const SizedBox.shrink();

    final recentWorkouts = _entrenamientos.take(10).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Últimos entrenamientos',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
                letterSpacing: -0.5,
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.push(
                  context,
                  AppRoute(page: const ProfileMenuView()),
                );
              },
              child: Text(
                'Ver todos',
                style: TextStyle(
                  color: Theme.of(context).brightness == Brightness.dark ? AppColors.brandLight : AppColors.brand,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 220, // Increased height for new Vivid Glass card design
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: recentWorkouts.length,
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4), // Padding for shadows
            separatorBuilder: (_, __) => const SizedBox(width: 16),
            itemBuilder: (context, index) {
              return _buildWorkoutCard(recentWorkouts[index]);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildWorkoutCard(Entrenamiento workout, {int index = 0}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final km = (workout.distanciaTotalM() / 1000).toStringAsFixed(1);
    final pace = workout.ritmoMedioTexto();
    final duration = _formatDuration(workout.tiempoTotalSec());
    final rpe = workout.rpePromedio();
    final rpeRounded = rpe.round();

    final now = DateTime.now();
    final diff = now.difference(workout.fecha).inDays;
    final dateLabel = diff == 0
        ? 'Hoy'
        : diff == 1
            ? 'Ayer'
            : '${workout.fecha.day}/${workout.fecha.month}';

    final cardBg = isDark ? AppColors.surface : Colors.white;
    final cardBorder = isDark ? AppColors.border : const Color(0xFFE5E5E5);
    final distanceColor = isDark ? Colors.white : const Color(0xFF1A1A1A);
    final unitColor = isDark ? Colors.white60 : const Color(0xFF888888);
    final dateTextColor = isDark ? const Color(0xFFAAAAAA) : const Color(0xFF666666);

    return Container(
      width: 280,
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: cardBorder, width: 0.5),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withOpacity(0.06),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: fecha + RPE pill
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Chip de fecha
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.surface2,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    dateLabel,
                    style: TextStyle(
                      color: dateTextColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                // RPE pill
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.effortSurface(rpe),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: AppColors.effortBorderColor(rpe),
                      width: 0.5,
                    ),
                  ),
                  child: Text(
                    'RPE $rpeRounded',
                    style: TextStyle(
                      color: AppColors.effortColor(rpe),
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),

            const Spacer(),

            // Distancia principal
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  km,
                  style: TextStyle(
                    fontSize: 42,
                    fontWeight: FontWeight.w800,
                    color: distanceColor,
                    letterSpacing: -2,
                    height: 1.0,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  'km',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: unitColor,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 14),

            // Métricas secundarias
            Row(
              children: [
                Icon(Icons.timer_outlined, size: 14, color: AppColors.iconMuted),
                const SizedBox(width: 4),
                Text(
                  duration,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: isDark ? Colors.white70 : const Color(0xFF444444),
                  ),
                ),
                const SizedBox(width: 16),
                Icon(Icons.speed, size: 14, color: AppColors.iconMuted),
                const SizedBox(width: 4),
                Text(
                  pace,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: isDark ? Colors.white70 : const Color(0xFF444444),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatDuration(double seconds) {
    final duration = Duration(seconds: seconds.toInt());
    final h = duration.inHours;
    final m = duration.inMinutes.remainder(60);
    if (h > 0) return '${h}h ${m}m';
    return '${m}m';
  }

  void _onPlayButtonTap() {
    Navigator.push(context, AppRoute(page: const TrainingStartView()));
  }
}

// ===================================================================
// TARJETA DESTACADA DE GRUPO
// ===================================================================
class _GroupHighlightCard extends StatelessWidget {
  final Group group;
  final int? userRank;

  const _GroupHighlightCard({required this.group, this.userRank});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? AppColors.surface : Colors.white;
    final cardBorder = isDark ? AppColors.border : const Color(0xFFE5E5E5);
    final nameColor = isDark ? Colors.white : const Color(0xFF1A1A1A);

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        AppRoute(page: GroupScreen(groupId: group.id)),
      ),
      child: Container(
        width: 220,
        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: cardBorder, width: 0.5),
          boxShadow: isDark
              ? null
              : [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icono grupo + badge rank
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.brandSurface,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.groups_rounded,
                      size: 16,
                      color: AppColors.brandLight,
                    ),
                  ),
                  if (userRank != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.brandSurface,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.brandBorder, width: 0.5),
                      ),
                      child: Text(
                        '#$userRank',
                        style: const TextStyle(
                          color: AppColors.brandLight,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                ],
              ),

              const Spacer(),

              // Nombre del grupo
              Text(
                group.name,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 17,
                  height: 1.15,
                  letterSpacing: -0.4,
                  color: nameColor,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),

              const SizedBox(height: 12),

              // Contador de miembros
              Row(
                children: [
                  const Icon(
                    Icons.person_outline_rounded,
                    size: 13,
                    color: AppColors.iconMuted,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${group.memberCount}',
                    style: const TextStyle(
                      color: AppColors.iconMuted,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ===================================================================
// BANNER RECOVERY
// ===================================================================
class _RecoveryBanner extends StatelessWidget {
  final RecoveredSession session;
  final VoidCallback onResume;
  final VoidCallback onDiscard;

  const _RecoveryBanner({
    required this.session,
    required this.onResume,
    required this.onDiscard,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(0, 0, 0, 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.effortSurface(9),
        border: Border.all(color: AppColors.effort.withOpacity(0.5)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded,
              color: AppColors.effort, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Sesión interrumpida',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.effort,
                  ),
                ),
                Text(
                  '${session.series.length} series · ${session.elapsedFormatted}',
                  style: const TextStyle(
                      fontSize: 12, color: Color(0xFF8E8E93)),
                ),
              ],
            ),
          ),
          TextButton(
            style: TextButton.styleFrom(
                foregroundColor: AppColors.effort,
                padding: const EdgeInsets.symmetric(horizontal: 8)),
            onPressed: onResume,
            child: const Text('Recuperar'),
          ),
          TextButton(
            style: TextButton.styleFrom(
                foregroundColor: Color(0xFF8E8E93),
                padding: const EdgeInsets.symmetric(horizontal: 8)),
            onPressed: onDiscard,
            child: const Text('Descartar'),
          ),
        ],
      ),
    );
  }
}

// ===================================================================
// BANNER SESIÓN DE HOY
// ===================================================================
class _TodaySessionBanner extends StatelessWidget {
  final AthleteSession session;
  final VoidCallback onTap;

  const _TodaySessionBanner({required this.session, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF1A1030) : const Color(0xFFF3EFFE);
    final titleColor = isDark ? Colors.white : const Color(0xFF1C1C1E);

    final title = session.category != null
        ? SessionCategoryX.fromValue(session.category!).label
        : 'Sesión planificada';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 0),
      decoration: BoxDecoration(
        color: bgColor,
        border: Border.all(color: AppColors.brand.withOpacity(0.4)),
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.fitness_center_rounded,
                        color: AppColors.brand, size: 16),
                    const SizedBox(width: 4),
                    Text(
                      'Entreno de hoy',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.brand,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: titleColor,
                  ),
                ),
                if (session.blocks.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    '${session.blocks.length} series'
                    '${session.time != null ? ' · ${session.time}' : ''}',
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF8E8E93),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 16),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.brand,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: onTap,
            child: const Text('Empezar'),
          ),
        ],
      ),
    );
  }
}

/// Badge con efecto cristal para el Home
class _GlassBadge extends StatelessWidget {
  final String label;
  final Color color;

  const _GlassBadge({
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.25),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}


