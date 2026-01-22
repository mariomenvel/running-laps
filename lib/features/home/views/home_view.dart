import 'package:flutter/material.dart';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:running_laps/features/home/viewmodels/home_config_controller.dart';
import 'package:running_laps/features/home/widgets/configurable_widget_renderer.dart';
import 'package:running_laps/features/home/views/edit_home_view.dart';
import 'package:running_laps/features/training/data/entrenamiento.dart';
import 'package:running_laps/features/training/data/training_repository.dart';
import 'package:running_laps/features/home/widgets/home_flagship_chart.dart'; // Added Chart Import
import 'package:running_laps/features/training/views/training_start_view.dart';
import 'package:running_laps/features/profile/views/profile_menu_screen.dart';
import 'package:running_laps/core/widgets/app_footer.dart';
import 'package:running_laps/core/widgets/kpi_card_with_delta.dart';
import 'package:running_laps/core/constants/app_help_content.dart';
import 'package:running_laps/config/app_theme.dart';

// GROUPS IMPORTS
import 'package:running_laps/features/groups/data/repositories/groups_repository.dart';
import 'package:running_laps/features/groups/data/repositories/user_groups_repository.dart';
import 'package:running_laps/features/groups/data/models/group_models.dart';
import 'package:running_laps/features/groups/views/groups_list_screen.dart';
import 'package:running_laps/features/groups/views/group_screen.dart';
import 'package:running_laps/core/widgets/group_skeleton_card.dart';
import 'package:running_laps/features/analytics/data/coach_insight_service.dart';
import 'package:running_laps/features/analytics/widgets/coach_insight_widget.dart';
import 'package:running_laps/features/groups/data/models/result_notification_model.dart';
import 'package:running_laps/features/groups/views/widgets/challenge_result_dialog.dart';
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Home View rediseñado con widgets configurables
/// Versión moderna con sistema de personalización
class HomeView extends StatefulWidget {
  const HomeView({super.key});

  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> {
  late final HomeConfigController _configController;
  final TrainingRepository _trainingRepository = TrainingRepository();
  final GroupsRepository _groupsRepository = GroupsRepository();
  final UserGroupsRepository _userGroupsRepository = UserGroupsRepository();
  final CoachInsightService _coachService = CoachInsightService();
  
  List<Entrenamiento> _entrenamientos = [];
  List<Entrenamiento> _allEntrenamientos = []; // Full history for Flagship Chart
  bool _isLoadingData = true;

  // Groups State
  Future<List<Group>>? _userGroupsFuture;
  
  // Selector de rango temporal
  TimeRange _selectedRange = TimeRange.thirtyDays;

  StreamSubscription? _notifSubscription;
  String? _currentUserId;
  final Set<String> _showingNotifIds = {};
  bool _isShowingDialog = false;

  @override
  void initState() {
    super.initState();
    _currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
    _configController = HomeConfigController(userId: _currentUserId!);
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
      print("Error fetching groups: $e");
      return [];
    }
  }

  Future<void> _initializeHome() async {
    await _configController.initialize();
    await _loadEntrenamientos();
  }

  Future<void> _loadEntrenamientos() async {
    setState(() => _isLoadingData = true);
    
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId != null) {
        final allData = await _trainingRepository.getAllEntrenamientos(userId);
        
        // Filtrar por rango
        final now = DateTime.now();
        final cutoffDate = _getCutoffDate(now, _selectedRange);
        
        setState(() {
          _allEntrenamientos = allData; // Store full history
          _entrenamientos = allData
              .where((e) => e.fecha.isAfter(cutoffDate))
              .toList()
            ..sort((a, b) => b.fecha.compareTo(a.fecha));
        });
      }
    } catch (e) {
      print('Error loading entrenamientos: $e');
    } finally {
      setState(() => _isLoadingData = false);
    }
  }

  DateTime _getCutoffDate(DateTime now, TimeRange range) {
    switch (range) {
      case TimeRange.sevenDays:
        return now.subtract(const Duration(days: 7));
      case TimeRange.thirtyDays:
        return now.subtract(const Duration(days: 30));
      case TimeRange.ninetyDays:
        return now.subtract(const Duration(days: 90));
    }
  }

  @override
  void dispose() {
    _configController.dispose();
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
              debugPrint('Error deleting notification: $e');
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
      backgroundColor: const Color(0xFFF4F6F8),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(child: _buildBody()),
            AppFooter(onTap: _onPlayButtonTap),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: Alignment.topCenter,
          radius: 1.2,
          colors: [const Color(0xFFF9F5FB), Colors.white], // Fixed typo
          stops: const [0.0, 1.0],
        ),
        image: const DecorationImage(
          image: AssetImage('assets/images/fondo.png'),
          fit: BoxFit.cover,
        ),
      ),
      child: Column(
        children: [
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
                      MaterialPageRoute(
                        builder: (context) => const ProfileMenuView(),
                      ),
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
          Container(height: 1, color: Colors.grey.shade200),
        ],
      ),
    );
  }

  Widget _buildBody() {
    return ValueListenableBuilder<bool>(
      valueListenable: _configController.isLoading,
      builder: (context, configLoading, _) {
        if (configLoading || _isLoadingData) {
          return const Center(
            child: CircularProgressIndicator(color: Tema.brandPurple),
          );
        }

        return RefreshIndicator(
          onRefresh: _loadEntrenamientos,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildWelcomeHeader(),
                const SizedBox(height: 12),
                CoachInsightWidget(insight: _coachService.generateInsight(_allEntrenamientos)),
                const SizedBox(height: 24),
                _buildKPICards(),
                const SizedBox(height: 32),
                
                // --- FLAGSHIP CHART ---
                HomeFlagshipChart(workouts: _allEntrenamientos),
                const SizedBox(height: 32),
                // ----------------------

                _buildRecentWorkoutsSection(),
                const SizedBox(height: 32),
                _buildGroupsPreview(), // Added Groups Preview
                const SizedBox(height: 100), // Bottom padding
              ],
            ),
          ),
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
              const Text(
                "Mis comunidades",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const GroupsListScreen()),
                  ).then((_) {
                     setState(() {
                       _loadGroups();
                     });
                  });
                },
                child: const Text(
                  "Ver todos",
                  style: TextStyle(
                    color: Tema.brandPurple,
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
                height: 180,
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
              height: 180,
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
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 20, offset: const Offset(0, 10))
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
            child: const Icon(Icons.groups_outlined, size: 48, color: Tema.brandPurple),
          ),
          const SizedBox(height: 16),
          const Text(
            "¡Únete a tu primera comunidad!",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const GroupsListScreen()),
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


  Widget _buildWelcomeHeader() {
    final hour = DateTime.now().hour;
    String greeting = hour < 12
        ? '¡Buenos días!'
        : hour < 19
            ? '¡Buenas tardes!'
            : '¡Buenas noches!';

    return Text(
      greeting,
      style: const TextStyle(
        fontSize: 28,
        fontWeight: FontWeight.bold,
        color: Colors.black87,
      ),
    );
  }



  Widget _buildKPICards() {
    // Calcular KPIs del periodo
    final totalKm = _entrenamientos.fold<double>(
      0,
      (sum, e) => sum + (e.distanciaTotalM() / 1000.0),
    );

    final avgPace = _calculateAveragePace();
    final totalWorkouts = _entrenamientos.length;
    final totalDurationSec = _entrenamientos.fold<double>(
      0,
      (sum, e) => sum + e.tiempoTotalSec(),
    );

    return GridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.2,
      children: [
        KpiCardWithDelta(
          title: 'Km totales',
          value: totalKm.toStringAsFixed(1),
          primaryColor: const Color(0xFF4CAF50),
          icon: Icons.directions_run,
          helpText: AppHelpContent.homeKmTotales,
        ),
        KpiCardWithDelta(
          title: 'Ritmo medio',
          value: _formatPace(avgPace),
          primaryColor: const Color(0xFF2196F3),
          icon: Icons.speed,
          isInverted: true,
          helpText: AppHelpContent.homeRitmoMedio,
        ),
        KpiCardWithDelta(
          title: 'Sesiones',
          value: totalWorkouts.toString(),
          primaryColor: const Color(0xFFFF9800),
          icon: Icons.fitness_center,
          helpText: AppHelpContent.homeSesiones,
        ),
        KpiCardWithDelta(
          title: 'Tiempo total',
          value: _formatDuration(totalDurationSec),
          primaryColor: Colors.teal,
          icon: Icons.timer,
          helpText: AppHelpContent.homeTiempoTotal,
        ),
      ],
    );
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
            const Text(
              'Últimos entrenamientos',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
                letterSpacing: -0.5,
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ProfileMenuView(),
                  ),
                );
              },
              child: const Text(
                'Ver todos',
                style: TextStyle(
                  color: Tema.brandPurple,
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
      MaterialPageRoute(builder: (context) => TrainingStartView()),
    );
  }
}

/// Enum para rangos temporales
enum TimeRange {
  sevenDays,
  thirtyDays,
  ninetyDays,
}

// ===================================================================
// TARJETA DESTACADA DE GRUPO
// ===================================================================
class _GroupHighlightCard extends StatelessWidget {
  final Group group;

  const _GroupHighlightCard({required this.group});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => GroupScreen(groupId: group.id),
          ),
        );
      },
      child: Container(
        width: 160,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 16,
              offset: const Offset(0, 8),
            )
          ],
          border: Border.all(color: Colors.grey.shade100),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Icono y Nombre
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Tema.brandPurple.withOpacity(0.15), Tema.brandPurple.withOpacity(0.05)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.groups_rounded, size: 22, color: Tema.brandPurple),
                ),
                const SizedBox(height: 12),
                Text(
                  group.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700, 
                    fontSize: 14,
                    height: 1.2,
                    letterSpacing: -0.3,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
            
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Member Count
                Row(
                  children: [
                    Icon(Icons.person_outline_rounded, size: 14, color: Colors.grey.shade500),
                    const SizedBox(width: 4),
                    Text(
                      "${group.memberCount} ${group.memberCount == 1 ? 'miembro' : 'miembros'}",
                      style: TextStyle(
                        fontSize: 12, 
                        color: Colors.grey.shade600, 
                        fontWeight: FontWeight.w500
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Botón Entrar Minimalista
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: Tema.brandPurple,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: Tema.brandPurple.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Text(
                      "Entrar",
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

