import 'package:flutter/material.dart';
import 'package:running_laps/core/utils/app_transitions.dart';
import '../../../config/app_theme.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_header.dart';
import '../../../core/widgets/gradient_banner.dart';
import 'package:running_laps/features/training/data/entrenamiento.dart';
import '../data/repositories/group_detail_repository.dart';
import '../data/services/gamification_service.dart';
import '../../profile/views/profile_menu_screen_legacy.dart';

class ParticipantProfileScreen extends StatefulWidget {
  final String uid;
  final String name;
  final String? photoUrl;
  final String? profilePicType;
  final Map<String, dynamic>? avatarConfig;

  const ParticipantProfileScreen({
    Key? key,
    required this.uid,
    required this.name,
    this.photoUrl,
    this.profilePicType,
    this.avatarConfig,
  }) : super(key: key);

  @override
  _ParticipantProfileScreenState createState() => _ParticipantProfileScreenState();
}

class _ParticipantProfileScreenState extends State<ParticipantProfileScreen> {
  final GroupDetailRepository _repository = GroupDetailRepository();
  bool _isLoading = true;
  List<Entrenamiento> _history = [];
  List<Achievement> _achievements = [];

  // Stats calculate
  int _totalRuns = 0;
  double _totalKm = 0;
  String _bestPace = "-";

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final trainings = await _repository.fetchUserTrainings(widget.uid);
    final calculated = GamificationService.calculateAchievements(trainings);

    // Calculate specific stats
    double km = 0;
    int bestSecKm = 99999;
    
    for (var t in trainings) {
      km += t.distanciaTotalM() / 1000.0;
      if (t.distanciaTotalM() > 500) { // filter very short runs
        final pace = t.ritmoMedioSecPorKm();
        if (pace != null && pace > 0 && pace < bestSecKm) bestSecKm = pace;
      }
    }

    String paceText = "-";
    if (bestSecKm < 99999) {
      final mm = bestSecKm ~/ 60;
      final ss = bestSecKm % 60;
      paceText = "$mm:${ss.toString().padLeft(2, '0')}";
    }

    if (mounted) {
      setState(() {
        _history = trainings;
        _achievements = calculated;
        _totalRuns = trainings.length;
        _totalKm = km;
        _bestPace = paceText;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        top: false,
        bottom: false,
        child: Column(
          children: [
            // 1. HEADER
            AppHeader(
              onTapRight: () {
                 Navigator.push(
                   context,
                   AppRoute(page: const ProfileMenuView()),
                 );
              },
              showBottomDivider: false,
            ),

            // 2. BANNER
            GradientBanner(
              title: "Perfil de Corredor",
              subtitle: widget.name,
              icon: Icons.verified_user_rounded,
              accentColor: AppColors.brandSurface,
              height: 90,
            ),

            // 2. CONTENT
            Expanded(
              child: _isLoading 
                ? const Center(child: CircularProgressIndicator())
                : SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    child: Column(
                      children: [
                        // --- AVATAR & NAME CARD ---
                        Stack(
                          clipBehavior: Clip.none,
                          alignment: Alignment.center,
                          children: [
                            Container(
                              margin: const EdgeInsets.only(top: 60),
                              padding: const EdgeInsets.only(top: 60, bottom: 20, left: 20, right: 20),
                              width: double.infinity,
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.surface,
                                borderRadius: BorderRadius.circular(25),
                                boxShadow: [
                                  BoxShadow(
                                    color: Theme.of(context).brightness == Brightness.dark
                                        ? Colors.transparent
                                        : Colors.black.withValues(alpha: 0.05),
                                    blurRadius: 10, offset: const Offset(0, 5),
                                  )
                                ],
                              ),
                              child: Column(
                                children: [
                                  Text(
                                    widget.name,
                                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Theme.of(context).colorScheme.onSurface),
                                  ),
                                  const SizedBox(height: 5),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: AppColors.brand.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text("Corredor/a", style: TextStyle(color: Theme.of(context).brightness == Brightness.dark ? AppColors.brandLight : AppColors.brand, fontWeight: FontWeight.w600, fontSize: 12)),
                                  ),
                                  const SizedBox(height: 20),
                                  // STATS ROW
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                                    children: [
                                      _StatItem(label: "Carreras", value: "$_totalRuns"),
                                      Container(width: 1, height: 30, color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3)),
                                      _StatItem(label: "Km Totales", value: _totalKm.toStringAsFixed(1)),
                                      Container(width: 1, height: 30, color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3)),
                                      _StatItem(label: "Mejor Ritmo", value: _bestPace),
                                    ],
                                  )
                                ],
                              ),
                            ),
                            // FLOATING AVATAR
                            Positioned(
                              top: 0,
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.surface,
                                  shape: BoxShape.circle,
                                ),
                                child: AvatarHelper.construirAvatar(
                                  radius: 50,
                                  type: widget.profilePicType ?? 'none',
                                  config: widget.avatarConfig,
                                  url: widget.photoUrl
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 30),

                        // --- ACHIEVEMENTS GRID ---
                        const Align(
                          alignment: Alignment.centerLeft,
                          child: Text("Logros & Medallas", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                        ),
                        const SizedBox(height: 15),
                        
                        GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            childAspectRatio: 1.1,
                            crossAxisSpacing: 15,
                            mainAxisSpacing: 15,
                          ),
                          itemCount: _achievements.length,
                          itemBuilder: (context, index) {
                            return _AchievementCard(item: _achievements[index]);
                          },
                        ),
                        
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
            ),

          ],
        ),
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  const _StatItem({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
        Text(label, style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5))),
      ],
    );
  }
}

class _AchievementCard extends StatelessWidget {
  final Achievement item;
  const _AchievementCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final bool unlocked = item.isUnlocked;
    final cs = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: unlocked ? cs.surface : cs.onSurface.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(20),
        border: unlocked ? null : Border.all(color: cs.outline.withValues(alpha: 0.3)),
        boxShadow: unlocked ? [
          BoxShadow(
            color: item.color.withValues(alpha: 0.2),
            blurRadius: 10, offset: const Offset(0, 4)
          )
        ] : [],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: unlocked ? item.color.withValues(alpha: 0.1) : cs.onSurface.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              item.icon,
              color: unlocked ? item.color : cs.onSurface.withValues(alpha: 0.4),
              size: 28,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            item.title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 14,
              color: unlocked ? cs.onSurface : cs.onSurface.withValues(alpha: 0.4)
            ),
          ),
          const SizedBox(height: 4),
          Text(
            item.description,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 10, color: cs.onSurface.withValues(alpha: 0.5)),
          )
        ],
      ),
    );
  }
}



