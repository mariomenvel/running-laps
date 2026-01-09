import 'package:flutter/material.dart';
import '../../../config/app_theme.dart';
import '../../../core/widgets/app_header.dart';
import '../../../core/widgets/app_footer.dart';
import 'package:running_laps/features/training/data/entrenamiento.dart';
import '../data/repositories/group_detail_repository.dart';
import '../data/services/gamification_service.dart';
import '../data/models/group_stats_model.dart';
import '../../home/views/home_view.dart';
import '../../profile/views/profile_menu_screen.dart';

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
      try {
        if (t.distanciaTotalM() > 500) { // filter very short runs
          final pace = t.ritmoMedioSecPorKm();
          if (pace > 0 && pace < bestSecKm) bestSecKm = pace;
        }
      } catch (_) {}
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
      backgroundColor: const Color(0xFFF4F6F8),
      body: SafeArea(
        child: Column(
          children: [
            // 1. HEADER
            AppHeader(
              onTapLeft: () {
                 Navigator.pushAndRemoveUntil(
                   context,
                   MaterialPageRoute(builder: (_) => const HomeView()),
                   (route) => false,
                 );
              },
              onTapRight: () {
                 Navigator.push(
                   context,
                   MaterialPageRoute(builder: (_) => const ProfileMenuView()),
                 );
              },
              showBottomDivider: false,
            ),

            // 1.5 CUSTOM BACK BUTTON
             Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
                child: GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        )
                      ],
                      border: Border.all(color: Colors.deepPurple.withOpacity(0.1)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(Icons.arrow_back_ios_new_rounded, size: 16, color: Colors.deepPurple),
                        SizedBox(width: 5),
                        Text("Volver", style: TextStyle(color: Colors.deepPurple, fontWeight: FontWeight.bold, fontSize: 13)),
                      ],
                    ),
                  ),
                ),
              ),
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
                              margin: const EdgeInsets.only(top: 50),
                              padding: const EdgeInsets.only(top: 60, bottom: 20, left: 20, right: 20),
                              width: double.infinity,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(25),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.05),
                                    blurRadius: 10, offset: const Offset(0, 5)
                                  )
                                ],
                              ),
                              child: Column(
                                children: [
                                  Text(
                                    widget.name,
                                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Colors.black87),
                                  ),
                                  const SizedBox(height: 5),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.purple.shade50,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Text("Corredor/a", style: TextStyle(color: Colors.purple, fontWeight: FontWeight.bold, fontSize: 12)),
                                  ),
                                  const SizedBox(height: 20),
                                  // STATS ROW
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                                    children: [
                                      _StatItem(label: "Carreras", value: "$_totalRuns"),
                                      Container(width: 1, height: 30, color: Colors.grey.shade200),
                                      _StatItem(label: "Km Totales", value: _totalKm.toStringAsFixed(1)),
                                      Container(width: 1, height: 30, color: Colors.grey.shade200),
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
                                decoration: const BoxDecoration(
                                  color: Colors.white,
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
                          child: Text("Logros & Medallas", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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

            // 3. FOOTER
            AppFooter(isLoading: false, onTap: () {}),
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
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
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
    
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: unlocked ? Colors.white : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(20),
        border: unlocked ? null : Border.all(color: Colors.grey.shade300),
        boxShadow: unlocked ? [
          BoxShadow(
            color: item.color.withOpacity(0.2),
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
              color: unlocked ? item.color.withOpacity(0.1) : Colors.grey.shade300,
              shape: BoxShape.circle,
            ),
            child: Icon(
              item.icon,
              color: unlocked ? item.color : Colors.grey,
              size: 28,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            item.title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: unlocked ? Colors.black87 : Colors.grey
            ),
          ),
          const SizedBox(height: 4),
          Text(
            item.description,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 10, color: Colors.grey),
          )
        ],
      ),
    );
  }
}



