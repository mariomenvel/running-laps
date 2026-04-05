import 'package:flutter/material.dart';
import 'package:running_laps/core/utils/app_transitions.dart';

import 'package:firebase_auth/firebase_auth.dart';

import 'package:running_laps/features/training/data/entrenamiento.dart';
import 'package:running_laps/features/training/data/training_repository.dart';
import 'package:running_laps/features/home/widgets/home_flagship_chart.dart'; // Added Chart Import
import 'package:running_laps/features/training/views/training_start_view.dart';
import 'package:running_laps/features/profile/views/profile_menu_screen.dart';
import 'package:running_laps/core/widgets/app_footer.dart';
import 'package:running_laps/core/widgets/kpi_card_with_delta.dart';
import 'package:running_laps/core/constants/app_help_content.dart';
import 'package:running_laps/config/app_theme.dart';
import 'package:running_laps/core/services/settings_service.dart';
import 'package:running_laps/core/theme/app_colors.dart';

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
import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';

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

  List<Entrenamiento> _entrenamientos = [];
  bool _isLoadingData = true;
  int _bestMarkDistanceM = 400;

  // Groups State
  Future<List<Group>>? _userGroupsFuture;

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
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId != null) {
        final allData = await _trainingRepository.getAllEntrenamientos(userId);
        setState(() {
          _entrenamientos = allData..sort((a, b) => b.fecha.compareTo(a.fecha));
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
          // El footer cubre TAMBIÉN la zona del home indicator (safe area inferior)
          AppFooter(onTap: _onPlayButtonTap),
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
              gradient: RadialGradient(
                center: Alignment.topCenter,
                radius: 1.2,
                colors: [Color(0xFFF9F5FB), Colors.white],
                stops: [0.0, 1.0],
              ),
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
                  backgroundColor: Tema.brandPurple,
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
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _slideFromLeft(_aGreeting, _buildWelcomeHeader()),
            const SizedBox(height: 12),
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
        padding: const EdgeInsets.all(20),
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
              backgroundColor: Tema.brandPurple,
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
                      color: Tema.brandPurple.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${challenges.length}',
                      style: TextStyle(
                        color: Theme.of(context).brightness == Brightness.dark ? AppColors.brandPurpleLight : Tema.brandPurple,
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
                          ? Tema.brandPurple
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
                    color: Theme.of(context).brightness == Brightness.dark ? AppColors.brandPurpleLight : Tema.brandPurple,
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
              gradient: LinearGradient(
                colors: [Tema.brandPurple.withOpacity(0.1), Tema.brandPurple.withOpacity(0.05)],
              ),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.groups_outlined, size: 48, color: Theme.of(context).brightness == Brightness.dark ? AppColors.brandPurpleLight : Tema.brandPurple),
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
              backgroundColor: Tema.brandPurple,
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
    Color c(Color vivid) => isMonochrome ? Tema.brandPurple : vivid;
    final colored = !isMonochrome;

    final totalKm = _entrenamientos.fold<double>(
        0, (s, e) => s + e.distanciaTotalM() / 1000.0);
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
        value: '${_entrenamientos.length}',
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
                  color: Theme.of(context).brightness == Brightness.dark ? AppColors.brandPurpleLight : Tema.brandPurple,
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

  /// Card de entrenamiento - Estilo premium neutro con detalles espectaculares
  Widget _buildWorkoutCard(Entrenamiento workout, {int index = 0}) {
    final km = (workout.distanciaTotalM() / 1000).toStringAsFixed(1);
    final pace = workout.ritmoMedioTexto();
    final duration = _formatDuration(workout.tiempoTotalSec());
    final rpe = workout.rpePromedio().round();
    
    // Formatting Date
    final now = DateTime.now();
    final diff = now.difference(workout.fecha).inDays;
    String dateLabel;
    if (diff == 0) {
      dateLabel = 'Hoy';
    } else if (diff == 1) {
      dateLabel = 'Ayer';
    } else {
      dateLabel = '${workout.fecha.day}/${workout.fecha.month}';
    }
    
    // Determine theme colors based on Tags
    Color primaryThemeColor;
    List<Color> backgroundGradientColors;

    if (workout.tags != null && workout.tags!.isNotEmpty) {
      final firstColor = _getTagColor(workout.tags![0]);
      
      if (workout.tags!.length > 1) {
         // Multiple tags: Rich gradient from Tag 1 to Tag 2
         final secondColor = _getTagColor(workout.tags![1]);
         primaryThemeColor = firstColor; 
         backgroundGradientColors = [
           firstColor,
           secondColor,
         ];
      } else {
        // Single tag: Rich gradient from Color to slightly darker/varied version
        primaryThemeColor = firstColor;
        backgroundGradientColors = [
           firstColor,
           firstColor.withBlue((firstColor.blue + 20).clamp(0, 255)).withRed((firstColor.red - 20).clamp(0, 255)),
        ];
      }
    } else {
      // No tags: Brand Purple Gradient
      primaryThemeColor = Tema.brandPurple;
      backgroundGradientColors = [
         Colors.purple.shade900,
         Colors.purple.shade500,
      ];
    }

    return Container(
      width: 280, 
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: backgroundGradientColors.first.withOpacity(0.4), // Glowing shadow matches card
            blurRadius: 12,
            offset: const Offset(0, 8),
            spreadRadius: -2,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          children: [
            // 1. Vivid Background
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: backgroundGradientColors,
                ),
              ),
            ),
            
            // 2. Artistic "Watermark" Circle (Decorative)
            Positioned(
              top: -40,
              right: -40,
              child: Container(
                width: 150,
                height: 150,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.1),
                ),
              ),
            ),

            // 3. Main Content
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header: Date & RPE Badge
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.2), // Dark glass
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          dateLabel,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      
                      // RPE Pill
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: _getRpeColor(rpe), // Semantic color
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [
                             BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 4),
                          ]
                        ),
                        child: Text(
                           "RPE $rpe",
                           style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      )
                    ],
                  ),
                  
                  const Spacer(),
                  
                  // Big Main Stat (Distance)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        km,
                        style: const TextStyle(
                          fontSize: 42,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: -2,
                          height: 1.0,
                          shadows: [
                            Shadow(color: Colors.black26, offset: Offset(0, 2), blurRadius: 4)
                          ]
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Text(
                        "km",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  // Glass Stats Panel
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15), // Frosted glass
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white.withOpacity(0.2)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        // Duration
                        _buildGlassStat(Icons.timer_outlined, duration),
                        // Divider
                        Container(width: 1, height: 20, color: Colors.white.withOpacity(0.3)),
                        // Pace
                        _buildGlassStat(Icons.speed, pace),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGlassStat(IconData icon, String value) {
    return Row(
      children: [
        Icon(icon, color: Colors.white70, size: 14),
        const SizedBox(width: 6),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
      ],
    );
  }

  Widget _buildTagBadge(String tag) {
    final color = _getTagColor(tag);
    return Container(
      margin: const EdgeInsets.only(left: 6),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.3), width: 0.5),
      ),
      child: Text(
        tag,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
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

  Color _getRpeColor(int rpe) {
    if (rpe <= 3) return Colors.green;
    if (rpe <= 5) return Colors.blue;
    if (rpe <= 7) return Colors.orange;
    return Colors.redAccent;
  }

  Color _getTagColor(String tag) {
    // Consistent color hashing based on tag string
    final hash = tag.codeUnits.fold(0, (previous, current) => previous + current);
    final colors = [
      Colors.blue,
      Colors.indigo,
      Colors.teal,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.pink,
      Colors.red,
    ];
    return colors[hash % colors.length];
  }


  void _onPlayButtonTap() {
    Navigator.push(
      context,
      AppRoute(page: TrainingStartView()),
    );
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
    // Paleta de colores para Liquid Glass
    final List<List<Color>> palettes = [
      [const Color(0xFF6A11CB), const Color(0xFF2575FC)], // Purple Blue
      [const Color(0xFFFF5F6D), const Color(0xFFFFC371)], // Sunset
      [const Color(0xFF11998E), const Color(0xFF38EF7D)], // Emerald
      [const Color(0xFFFC466B), const Color(0xFF3F5EFB)], // Pink Blue
    ];
    final backgroundGradient = palettes[group.name.length % palettes.length];

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          AppRoute(page: GroupScreen(groupId: group.id)),
        );
      },
      child: Container(
        width: 220,
        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: backgroundGradient.first.withOpacity(0.35),
              blurRadius: 15,
              offset: const Offset(0, 8),
              spreadRadius: -2,
            )
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Stack(
            children: [
              // 1. LIQUID GRADIENT BACKGROUND
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: backgroundGradient,
                  ),
                ),
              ),
              
              // 2. LAYERED ARTISTIC WATERMARKS
              Positioned(
                top: -20,
                right: -20,
                child: Container(
                  width: 130,
                  height: 130,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.12),
                  ),
                ),
              ),
              Positioned(
                bottom: -30,
                left: -10,
                child: Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.08),
                  ),
                ),
              ),

              // 3. GLASS INTERACTION LAYER (Subtle Blur)
              Positioned.fill(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 0.5, sigmaY: 0.5),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(24),
                    ),
                  ),
                ),
              ),

              // 4. MAIN CONTENT
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Ranking/Type Badge
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.25),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.white.withOpacity(0.2)),
                          ),
                          child: const Icon(
                            Icons.groups_rounded, 
                            size: 16, 
                            color: Colors.white,
                          ),
                        ),
                        if (userRank != null)
                          _GlassBadge(
                            label: "#$userRank",
                            color: Colors.white,
                          ),
                      ],
                    ),
                    
                    const Spacer(),
                    
                    // Group Name
                    Text(
                      group.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w900, 
                        fontSize: 19,
                        height: 1.1,
                        letterSpacing: -0.6,
                        color: Colors.white,
                        shadows: [
                          Shadow(color: Colors.black38, offset: Offset(0, 1), blurRadius: 4)
                        ]
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    
                    const SizedBox(height: 14),
                    
                    // Stats Panel (Frosted Glass)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.white.withOpacity(0.2)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.person_outline_rounded, size: 12, color: Colors.white70),
                          const SizedBox(width: 4),
                          Text(
                            "${group.memberCount}",
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
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


