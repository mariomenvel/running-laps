import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:running_laps/config/app_theme.dart';
import 'package:running_laps/core/widgets/app_header.dart';
import 'package:running_laps/core/widgets/gradient_banner.dart';
import '../../profile/views/profile_menu_screen.dart';
import '../viewmodels/group_rewards_controller.dart';
import '../data/models/rewards_models.dart';
import '../data/models/enums.dart';

class GroupRewardsScreen extends StatefulWidget {
  final String groupId;

  const GroupRewardsScreen({Key? key, required this.groupId}) : super(key: key);

  @override
  State<GroupRewardsScreen> createState() => _GroupRewardsScreenState();
}

class _GroupRewardsScreenState extends State<GroupRewardsScreen>
    with SingleTickerProviderStateMixin {
  late GroupRewardsController _controller;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _controller = GroupRewardsController(groupId: widget.groupId);
    _controller.init();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _controller.dispose();
    _tabController.dispose();
    super.dispose();
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
              onTapLeft: null,
              onTapRight: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const ProfileMenuView()),
                );
              },
              showBottomDivider: false,
            ),

            // 2. Back Button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                children: [
                  _AnimatedBackButton(onTap: () => Navigator.pop(context)),
                ],
              ),
            ),

            // 3. TITLE BANNER
            GradientBanner(
              title: "Recompensas",
              subtitle: "Medallero y logros del grupo",
              icon: Icons.emoji_events_rounded,
              height: 85,
              gradientColors: [
                Colors.amber.shade600,
                Colors.orange.shade400,
              ],
            ),

            // 4. TABS
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(20),
              ),
              child: TabBar(
                controller: _tabController,
                indicatorSize: TabBarIndicatorSize.tab, // Same size for all
                indicator: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.amber.shade600,
                      Colors.orange.shade500,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.amber.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                labelColor: Colors.white,
                unselectedLabelColor: Colors.grey.shade600,
                labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                dividerColor: Colors.transparent,
                labelPadding: EdgeInsets.zero, // Remove extra padding to maximize space
                tabs: const [
                  Tab(
                    height: 36,
                    child: Center(child: Text("Medallero")),
                  ),
                  Tab(
                    height: 36,
                    child: Center(child: Text("Logros")),
                  ),
                  Tab(
                    height: 36,
                    child: Center(child: Text("Mi Historial")),
                  ),
                ],
              ),
            ),

            // 5. CONTENT
            Expanded(
              child: ValueListenableBuilder<bool>(
                valueListenable: _controller.isLoading,
                builder: (context, loading, _) {
                  if (loading) {
                    return const Center(
                      child: CircularProgressIndicator(color: Tema.brandPurple),
                    );
                  }

                  return TabBarView(
                    controller: _tabController,
                    children: [
                      _buildMedalsTab(),
                      _buildBadgesTab(),
                      _buildHistoryTab(),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- TABS ---

  Widget _buildMedalsTab() {
    return ValueListenableBuilder<List<GroupMedals>>(
      valueListenable: _controller.medalsTable,
      builder: (context, list, _) {
        if (list.isEmpty) {
          return _buildEmptyState("Aún no hay medallas", Icons.emoji_events_outlined);
        }

        return ListView.builder(
          padding: const EdgeInsets.all(20),
          itemCount: list.length,
          itemBuilder: (context, index) {
            final item = list[index];
            final rank = index + 1;

            return _StaggeredItem(
              index: index,
              child: _PremiumMedalCard(
                item: item,
                rank: rank,
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildBadgesTab() {
    return ValueListenableBuilder<List<GroupBadges>>(
      valueListenable: _controller.badgesTable,
      builder: (context, list, _) {
        if (list.isEmpty) {
          return _buildEmptyState("Nadie tiene logros aún", Icons.verified_outlined);
        }

        return ListView.builder(
          padding: const EdgeInsets.all(20),
          itemCount: list.length,
          itemBuilder: (context, index) {
            final item = list[index];

            return _StaggeredItem(
              index: index,
              child: _PremiumBadgeCard(item: item),
            );
          },
        );
      },
    );
  }

  Widget _buildHistoryTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader("MIS MEDALLAS RECIENTES", Icons.emoji_events_rounded),
          const SizedBox(height: 12),
          ValueListenableBuilder<List<MedalHistoryEntry>>(
            valueListenable: _controller.myMedalHistory,
            builder: (context, list, _) {
              if (list.isEmpty) return _buildMiniEmptyState("Sin medallas aún");

              return Column(
                children: list.asMap().entries.map((entry) {
                  return _StaggeredItem(
                    index: entry.key,
                    child: _buildHistoryItem(
                      icon: Icons.emoji_events,
                      iconColor: _getMedalColor(entry.value.medal),
                      title: entry.value.challengeTitle,
                      date: entry.value.awardedAt,
                      trailing: "Rank #${entry.value.rank}",
                    ),
                  );
                }).toList(),
              );
            },
          ),

          const SizedBox(height: 32),

          _buildSectionHeader("MIS LOGROS RECIENTES", Icons.verified_rounded),
          const SizedBox(height: 12),
          ValueListenableBuilder<List<BadgeHistoryEntry>>(
            valueListenable: _controller.myBadgeHistory,
            builder: (context, list, _) {
              if (list.isEmpty) return _buildMiniEmptyState("Sin logros aún");

              return Column(
                children: list.asMap().entries.map((entry) {
                  return _StaggeredItem(
                    index: entry.key,
                    child: _buildHistoryItem(
                      icon: Icons.verified_rounded,
                      iconColor: Colors.green,
                      title: entry.value.challengeTitle,
                      date: entry.value.awardedAt,
                      trailing: entry.value.periodKey,
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  // --- HELPERS ---

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Tema.brandPurple.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 18, color: Tema.brandPurple),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w900,
            color: Colors.grey.shade600,
            letterSpacing: 1.0,
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(String msg, IconData icon) {
    return Center(
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.0, end: 1.0),
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeOutBack,
        builder: (context, value, child) {
          return Transform.scale(
            scale: 0.8 + (0.2 * value),
            child: Opacity(opacity: value.clamp(0.0, 1.0), child: child),
          );
        },
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.amber.withOpacity(0.1),
                    Colors.orange.withOpacity(0.05),
                  ],
                ),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 56, color: Colors.amber.shade300),
            ),
            const SizedBox(height: 20),
            Text(
              msg,
              style: TextStyle(
                color: Colors.grey.shade500,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniEmptyState(String msg) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inbox_rounded, color: Colors.grey.shade300, size: 20),
          const SizedBox(width: 10),
          Text(
            msg,
            style: TextStyle(color: Colors.grey.shade400, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryItem({
    required IconData icon,
    required Color iconColor,
    required String title,
    required DateTime date,
    required String trailing,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [iconColor.withOpacity(0.2), iconColor.withOpacity(0.1)],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const SizedBox(height: 4),
                Text(
                  DateFormat('d MMM yyyy', 'es_ES').format(date),
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              trailing,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: iconColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getMedalColor(MedalType type) {
    switch (type) {
      case MedalType.gold:
        return const Color(0xFFFFD700);
      case MedalType.silver:
        return const Color(0xFFC0C0C0);
      case MedalType.bronze:
        return const Color(0xFFCD7F32);
    }
  }
}

/// Card de medallas premium
class _PremiumMedalCard extends StatelessWidget {
  final GroupMedals item;
  final int rank;

  const _PremiumMedalCard({required this.item, required this.rank});

  @override
  Widget build(BuildContext context) {
    final String? myUid = FirebaseAuth.instance.currentUser?.uid;
    final bool isMe = item.uid == myUid;
    final bool isTop3 = rank <= 3;
    final rankColor = _getRankColor(rank);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: isTop3
            ? Border.all(color: rankColor.withOpacity(0.4), width: 2)
            : null,
        boxShadow: [
          BoxShadow(
            color: isTop3
                ? rankColor.withOpacity(0.15)
                : Colors.black.withOpacity(0.04),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          // Rank Badge
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: isTop3
                  ? LinearGradient(
                      colors: [rankColor, rankColor.withOpacity(0.7)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                  : null,
              color: isTop3 ? null : Colors.grey.shade100,
              shape: BoxShape.circle,
              boxShadow: isTop3
                  ? [
                      BoxShadow(
                        color: rankColor.withOpacity(0.4),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      )
                    ]
                  : null,
            ),
            child: Center(
              child: Text(
                "#$rank",
                style: TextStyle(
                  color: isTop3 ? Colors.white : Colors.grey.shade600,
                  fontWeight: FontWeight.w900,
                  fontSize: 15,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),

          // Avatar & Content
          Expanded(
            child: Row(
              children: [
                AvatarHelper.construirAvatar(
                  radius: 18,
                  type: item.profilePicType ?? 'none',
                  config: item.avatarConfig,
                  url: item.photoUrl,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isMe ? "Tú" : (item.displayName ?? "Usuario ${item.uid.substring(0, 4)}"),
                        style: TextStyle(
                          fontWeight: isMe ? FontWeight.w900 : FontWeight.bold,
                          fontSize: 16,
                          color: isMe ? Tema.brandPurple : Colors.black87,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          if (item.gold > 0) ...[
                            _MedalCounter(type: MedalType.gold, count: item.gold),
                            const SizedBox(width: 8),
                          ],
                          if (item.silver > 0) ...[
                            _MedalCounter(type: MedalType.silver, count: item.silver),
                            const SizedBox(width: 8),
                          ],
                          if (item.bronze > 0) ...[
                            _MedalCounter(type: MedalType.bronze, count: item.bronze),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Total
          Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Tema.brandPurple, Tema.brandPurple.withOpacity(0.7)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Tema.brandPurple.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Text(
                  "${item.total}",
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                "Total",
                style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color _getRankColor(int rank) {
    if (rank == 1) return const Color(0xFFFFD700);
    if (rank == 2) return const Color(0xFFC0C0C0);
    if (rank == 3) return const Color(0xFFCD7F32);
    return Colors.grey.shade400;
  }
}

/// Card de badges premium
class _PremiumBadgeCard extends StatelessWidget {
  final GroupBadges item;

  const _PremiumBadgeCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final String? myUid = FirebaseAuth.instance.currentUser?.uid;
    final bool isMe = item.uid == myUid;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.green.withOpacity(0.08),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          // Icon
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.green.shade400, Colors.green.shade600],
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.green.withOpacity(0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(Icons.verified_rounded, color: Colors.white, size: 26),
          ),
          const SizedBox(width: 16),

          // Avatar & Content
          Expanded(
            child: Row(
              children: [
                AvatarHelper.construirAvatar(
                  radius: 18,
                  type: item.profilePicType ?? 'none',
                  config: item.avatarConfig,
                  url: item.photoUrl,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isMe ? "Tú" : (item.displayName ?? "Usuario ${item.uid.substring(0, 4)}"),
                        style: TextStyle(
                          fontWeight: isMe ? FontWeight.w900 : FontWeight.bold,
                          fontSize: 16,
                          color: isMe ? Colors.green.shade700 : Colors.black87,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          _buildBadgeStat("${item.weeklyCompleted}", "Sem."),
                          const SizedBox(width: 12),
                          _buildBadgeStat("${item.monthlyCompleted}", "Mens."),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Total badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.green.shade500, Colors.green.shade700],
              ),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: Colors.green.withOpacity(0.3),
                  blurRadius: 8,
                ),
              ],
            ),
            child: Text(
              "${item.completedCount}",
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBadgeStat(String value, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.green.shade700,
              fontSize: 13,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: Colors.green.shade500,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

/// Medal counter chip
class _MedalCounter extends StatelessWidget {
  final MedalType type;
  final int count;

  const _MedalCounter({required this.type, required this.count});

  @override
  Widget build(BuildContext context) {
    final color = _getMedalColor(type);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withOpacity(0.15), color.withOpacity(0.08)],
        ),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.emoji_events, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            "$count",
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Color _getMedalColor(MedalType type) {
    switch (type) {
      case MedalType.gold:
        return const Color(0xFFFFD700);
      case MedalType.silver:
        return const Color(0xFFC0C0C0);
      case MedalType.bronze:
        return const Color(0xFFCD7F32);
    }
  }
}

/// Animación staggered
class _StaggeredItem extends StatefulWidget {
  final int index;
  final Widget child;

  const _StaggeredItem({required this.index, required this.child});

  @override
  State<_StaggeredItem> createState() => _StaggeredItemState();
}

class _StaggeredItemState extends State<_StaggeredItem>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );
    _animation = CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);

    Future.delayed(Duration(milliseconds: widget.index * 70), () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _animation,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.1),
          end: Offset.zero,
        ).animate(_animation),
        child: widget.child,
      ),
    );
  }
}

/// Botón de volver animado
class _AnimatedBackButton extends StatefulWidget {
  final VoidCallback onTap;
  const _AnimatedBackButton({required this.onTap});

  @override
  State<_AnimatedBackButton> createState() => _AnimatedBackButtonState();
}

class _AnimatedBackButtonState extends State<_AnimatedBackButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) {
        setState(() => _isPressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: _isPressed ? Colors.grey.shade100 : Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(_isPressed ? 0.03 : 0.06),
              blurRadius: _isPressed ? 4 : 12,
              offset: Offset(0, _isPressed ? 2 : 4),
            ),
          ],
          border: Border.all(color: Tema.brandPurple.withOpacity(0.1)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.arrow_back_ios_new_rounded,
              size: 16,
              color: Tema.brandPurple,
            ),
            const SizedBox(width: 6),
            const Text(
              "Volver",
              style: TextStyle(
                color: Tema.brandPurple,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}



