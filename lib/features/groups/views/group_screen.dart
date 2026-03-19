import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:running_laps/core/utils/app_transitions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:confetti/confetti.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';

import '../viewmodels/group_challenges_controller.dart';
import '../data/models/enums.dart';
import '../data/models/challenge_models.dart';
import '../data/repositories/challenges_repository.dart';
import 'package:running_laps/config/app_theme.dart';
import '../../../../core/widgets/app_header.dart';
import '../../../../core/widgets/app_footer.dart';
import '../../../../core/widgets/gradient_banner.dart';

// Screens
import 'challenge_detail_screen.dart';
import 'group_rewards_screen.dart';
import 'participant_profile_screen.dart';
import '../data/models/group_stats_model.dart';

// Widgets
import 'widgets/create_challenge_modal.dart';
import '../../../../features/groups/data/helpers/challenge_helpers.dart';
import '../../training/views/training_start_view.dart';
import '../../profile/views/profile_menu_screen.dart';
import '../data/repositories/invites_repository.dart';
import '../data/helpers/invite_token_helper.dart';
import '../../../../core/widgets/modern_snackbar.dart';

/// Pantalla de Grupo Rediseñada: Premium, moderna con animaciones fluidas
class GroupScreen extends StatefulWidget {
  final String groupId;

  const GroupScreen({
    super.key,
    required this.groupId,
  });

  @override
  State<GroupScreen> createState() => _GroupScreenState();
}

class _GroupScreenState extends State<GroupScreen> with TickerProviderStateMixin {
  late GroupChallengesController _controller;
  late ConfettiController _confettiController;
  late TabController _tabController;
  late AnimationController _headerAnimController;
  late Animation<double> _headerFadeAnimation;

  // ── Entrance animation ──────────────────────────────────────────
  late final AnimationController _entranceCtrl;
  bool _entrancePlayed = false;
  late final Animation<double> _aBanner;   // 0ms   – fade + slide left
  late final Animation<double> _aTabBar;   // 120ms – scale in
  late final Animation<double> _aContent;  // 200ms – fade + slide bottom
  // ────────────────────────────────────────────────────────────────

  final ScrollController _scrollController = ScrollController();
  bool _isOwner = false;

  // Gradient colors for different challenge types
  static const Map<ChallengeMetric, List<Color>> _metricGradients = {
    ChallengeMetric.distance: [Color(0xFF1E88E5), Color(0xFF42A5F5)],
    ChallengeMetric.time: [Color(0xFFFB8C00), Color(0xFFFFA726)],
    ChallengeMetric.sessions: [Color(0xFFE91E63), Color(0xFFF48FB1)],
  };

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(duration: const Duration(seconds: 3));
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(_onTabChanged);
    _controller = GroupChallengesController(groupId: widget.groupId);
    _controller.init();

    _headerAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _headerFadeAnimation = CurvedAnimation(
      parent: _headerAnimController,
      curve: Curves.easeOut,
    );
    _headerAnimController.forward();

    _entranceCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200));
    _aBanner  = CurvedAnimation(parent: _entranceCtrl, curve: const Interval(0.000, 0.517, curve: Curves.easeOutQuart));
    _aTabBar  = CurvedAnimation(parent: _entranceCtrl, curve: const Interval(0.100, 0.617, curve: Curves.easeOutQuart));
    _aContent = CurvedAnimation(parent: _entranceCtrl, curve: const Interval(0.167, 0.683, curve: Curves.easeOutQuart));
    if (!_entrancePlayed) {
      _entrancePlayed = true;
      _entranceCtrl.forward();
    }

    _controller.showAutoJoinPrompt.addListener(_checkAutoJoinPrompt);
    _controller.group.addListener(_checkOwnership);
  }

  void _onTabChanged() {
    if (mounted) setState(() {});
  }

  void _checkOwnership() {
    final currentUser = FirebaseAuth.instance.currentUser;
    final group = _controller.group.value;
    if (mounted && group != null && currentUser != null) {
      setState(() {
        _isOwner = group.ownerId == currentUser.uid;
      });
    }
  }

  void _checkAutoJoinPrompt() {
    if (_controller.showAutoJoinPrompt.value && mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showAutoJoinDialog();
      });
    }
  }

  @override
  void dispose() {
    _entranceCtrl.dispose();
    _confettiController.dispose();
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    _scrollController.dispose();
    _headerAnimController.dispose();
    _controller.showAutoJoinPrompt.removeListener(_checkAutoJoinPrompt);
    _controller.group.removeListener(_checkOwnership);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        alignment: Alignment.topCenter,
        children: [
          SafeArea(
            child: Column(
              children: [
                // 1. Header Fijo
                AppHeader(
                  showBottomDivider: false,
                  onTapRight: () {
                    Navigator.push(
                      context,
                      AppRoute(page: const ProfileMenuView()),
                    );
                  },
                ),

                // 2. Banner del grupo con gradiente
                _slideFromLeft(_aBanner, ValueListenableBuilder(
                  valueListenable: _controller.group,
                  builder: (context, group, _) {
                    return GradientBanner(
                      title: group?.name ?? 'Cargando...',
                      subtitle: '${group?.memberCount ?? 0} miembros activos',
                      icon: Icons.groups_rounded,
                      height: 85,
                    );
                  },
                )),

                // 3. Botón volver
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Row(
                    children: [
                      _AnimatedBackButton(onTap: () => Navigator.pop(context)),
                    ],
                  ),
                ),

                // 4. Tab Bar Premium
                _scaleIn(_aTabBar, _buildAnimatedTabBar()),

                // 5. Contenido
                Expanded(
                  child: _slideFromBottom(_aContent, TabBarView(
                    controller: _tabController,
                    children: [
                      _buildChallengesTab(),
                      _buildMembersTab(),
                      GroupRewardsBody(groupId: widget.groupId),
                    ],
                  )),
                ),

              ],
            ),
          ),

          // Confetti
          ConfettiWidget(
            confettiController: _confettiController,
            blastDirectionality: BlastDirectionality.explosive,
            shouldLoop: false,
            colors: const [Tema.brandPurple, Colors.blue, Colors.pink, Colors.orange],
          ),

            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: AppFooter(
                onTap: () {
                   Navigator.of(context).push(
                    AppRoute(page: TrainingStartView()),
                  );
                },
              ),
            ),
        ],
      ),
      floatingActionButton: _isOwner && _tabController.index == 0
          ? Builder(builder: (context) {
              final isDark = Theme.of(context).brightness == Brightness.dark;
              return Container(
              height: 56,
              width: 56,
              margin: const EdgeInsets.only(bottom: 130, right: 8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: isDark ? Colors.transparent : Colors.black.withOpacity(0.1),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _showCreateChallengeModal,
                  borderRadius: BorderRadius.circular(28),
                  child: Center(
                    child: ShaderMask(
                      shaderCallback: (Rect bounds) {
                        return const LinearGradient(
                          colors: [Tema.brandPurple, Colors.pinkAccent],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ).createShader(bounds);
                      },
                      blendMode: BlendMode.srcIn,
                      child: const Icon(Icons.add_rounded, size: 34),
                    ),
                  ),
                ),
              ),
            );
          })
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  // ── Entrance animation helpers ────────────────────────────────────
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
  // ─────────────────────────────────────────────────────────────────

  // --- Custom Animated Tab Bar ---
  Widget _buildAnimatedTabBar() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.transparent : Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          color: Tema.brandPurple,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Tema.brandPurple.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        labelColor: Colors.white,
        unselectedLabelColor: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
        dividerColor: Colors.transparent,
        splashBorderRadius: BorderRadius.circular(16),
        tabs: const [
          Tab(text: "Retos"),
          Tab(text: "Miembros"),
          Tab(text: "Premios"),
        ],
      ),
    );
  }

  // --- TABS CONTENT ---

  Widget _buildChallengesTab() {
    return CustomScrollView(
      slivers: [
        const SliverPadding(padding: EdgeInsets.only(top: 8)),

        // Auto Join Indicator
        SliverToBoxAdapter(
          child: _buildAutoJoinIndicator(),
        ),

        // Challenges List
        ValueListenableBuilder(
          valueListenable: _controller.activeChallenges,
          builder: (context, challenges, _) {
            if (challenges.isEmpty) {
              return SliverToBoxAdapter(
                child: _buildEmptyChallengesState(),
              );
            }

            return ValueListenableBuilder<Map<String, ChallengeParticipant?>>(
              valueListenable: _controller.myParticipations,
              builder: (context, participations, _) {
                return SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final challenge = challenges[index];
                      final participant = participations[challenge.id];
                      return _StaggeredChallengeItem(
                        index: index,
                        child: _PremiumChallengeCard(
                          challenge: challenge,
                          participant: participant,
                          gradientColors: _metricGradients[challenge.metric] ??
                              [Tema.brandPurple, Tema.brandPurple.withOpacity(0.7)],
                          onTap: () {
                            Navigator.of(context).push(
                              AppModalRoute(
                                page: ChallengeDetailScreen(
                                  groupId: widget.groupId,
                                  challengeId: challenge.id,
                                ),
                              ),
                            );
                          },
                          onJoin: () async {
                            await _controller.joinChallenge(challenge.id);
                            if (mounted) {
                              ModernSnackBar.showSuccess(context, '¡Te has unido al reto! 🚀');
                              _confettiController.play();
                            }
                          },
                        ),
                      );
                    },
                    childCount: challenges.length,
                  ),
                );
              },
            );
          },
        ),

        const SliverPadding(padding: EdgeInsets.only(bottom: 100)),
      ],
    );
  }

  Widget _buildMembersTab() {
    return ValueListenableBuilder<bool>(
      valueListenable: _controller.isLoading,
      builder: (context, isLoading, _) {
        if (isLoading) {
          return const Center(
            child: CircularProgressIndicator(color: Tema.brandPurple),
          );
        }


        return ValueListenableBuilder<List<GroupMemberStats>>(
          valueListenable: _controller.members,
          builder: (context, members, _) {
            // Unify list for ScrollView or just use ListView with header
            return ListView(
              padding: const EdgeInsets.all(20),
              children: [
                // Invite Button (Only if Owner)
                 if (_isOwner)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 20),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _showInviteDialog,
                        icon: const Icon(Icons.person_add_rounded, size: 20, color: Colors.white),
                        label: const Text(
                          "Invitar Miembro",
                          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Tema.brandPurple,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          elevation: 4,
                          shadowColor: Tema.brandPurple.withOpacity(0.4),
                        ),
                      ),
                    ),
                  ),

                if (members.isEmpty)
                   _buildEmptyMembersState()
                else
                  ...List.generate(members.length, (index) {
                    final member = members[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _StaggeredMemberItem(
                        index: index,
                        child: _PremiumMemberCard(
                          member: member,
                          rank: index + 1,
                          onTap: () {
                            Navigator.push(
                              context,
                              AppModalRoute(
                                page: ParticipantProfileScreen(
                                  uid: member.uid,
                                  name: member.name,
                                  photoUrl: member.photoUrl,
                                  profilePicType: member.profilePicType,
                                  avatarConfig: member.avatarConfig,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    );
                  }),
              ],
            );
          },
        );
      },
    );
  }

  void _showInviteDialog() {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _InviteSheet(
        groupId: widget.groupId,
        currentUserUid: currentUser.uid,
      ),
    );
  }

  Widget _buildEmptyMembersState() {
     // ... (Existing empty state logic reused inside ListView)
     return Center(
      child: Padding(
        padding: const EdgeInsets.all(40.0),
        child: Column(
            // ... copy of previous empty state excluding Tween for simplicity inside list, OR reuse widget
             mainAxisSize: MainAxisSize.min,
             mainAxisAlignment: MainAxisAlignment.center,
             children: [
               Container(
                 padding: const EdgeInsets.all(28),
                 decoration: BoxDecoration(
                   gradient: LinearGradient(
                     colors: [
                       Colors.blue.withOpacity(0.1),
                       Colors.blue.withOpacity(0.05),
                     ],
                   ),
                   shape: BoxShape.circle,
                 ),
                 child: Icon(
                   Icons.people_outline_rounded,
                   size: 56,
                   color: Colors.blue.withOpacity(0.5),
                 ),
               ),
               const SizedBox(height: 28),
               Text(
                 'Sin miembros aún',
                 style: TextStyle(
                   fontSize: 22,
                   fontWeight: FontWeight.w800,
                   color: Theme.of(context).colorScheme.onSurface,
                 ),
               ),
             ],
           ),
      ),
    );
  }

  // --- WIDGETS AUXILIARES ---

  Widget _buildEmptyChallengesState() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40.0, vertical: 60.0),
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
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Tema.brandPurple.withOpacity(0.1),
                    Tema.brandPurple.withOpacity(0.05),
                  ],
                ),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.fitness_center_outlined,
                size: 56,
                color: Tema.brandPurple.withOpacity(0.5),
              ),
            ),
            const SizedBox(height: 28),
            Text(
              'Aún no hay retos',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Sé el primero en desafiar al grupo\ny comienza la competición.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                height: 1.5,
                fontSize: 15,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAutoJoinIndicator() {
    return ValueListenableBuilder(
      valueListenable: _controller.prefs,
      builder: (context, prefs, _) {
        final isEnabled = prefs?.autoJoinTemplates ?? false;
        if (!isEnabled) return const SizedBox.shrink();

        return TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.0, end: 1.0),
          duration: const Duration(milliseconds: 500),
          builder: (context, value, child) {
            return Transform.translate(
              offset: Offset(0, 20 * (1 - value)),
              child: Opacity(opacity: value, child: child),
            );
          },
          child: Container(
            margin: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.green.shade50,
                  Colors.green.shade100.withOpacity(0.5),
                ],
              ),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.green.shade200.withOpacity(0.5)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.green.withOpacity(0.15),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                  child: const Icon(Icons.auto_awesome, color: Colors.green, size: 20),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Modo Automático Activo',
                        style: TextStyle(
                          color: Colors.green,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Te unirás a nuevos retos automáticamente.',
                        style: TextStyle(
                          color: Colors.green.shade700,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showAutoJoinDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Row(
          children: [
            Icon(Icons.auto_awesome, color: Tema.brandPurple),
            SizedBox(width: 12),
            Text('Unión Automática'),
          ],
        ),
        content: const Text(
          '¿Quieres unirte automáticamente a todos los retos semanales y mensuales de este grupo?',
          style: TextStyle(height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () {
              _controller.setAutoJoinChoice(false);
              Navigator.of(context).pop();
            },
            child: Text(
              'No, preguntar siempre',
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6)),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Tema.brandPurple,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () {
              _controller.setAutoJoinChoice(true);
              Navigator.of(context).pop();
            },
            child: const Text('Sí, activar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showCreateChallengeModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CreateChallengeModal(
        onCreate: (title, kind, value, start, end) async {
          final currentUser = FirebaseAuth.instance.currentUser;
          if (currentUser == null) return;

          ChallengeMetric metric;
          double finalValue;

          if (kind == GoalKind.distance) {
            metric = ChallengeMetric.distance;
            finalValue = value * 1000;
          } else if (kind == GoalKind.time) {
            metric = ChallengeMetric.time;
            finalValue = value * 60;
          } else {
            metric = ChallengeMetric.sessions;
            finalValue = value;
          }

          final challenge = Challenge(
            id: '',
            title: title,
            origin: ChallengeOrigin.owner,
            templateId: null,
            periodKey: 'manual_${DateTime.now().millisecondsSinceEpoch}',
            startAt: start,
            endAt: end,
            status: ChallengeStatus.active,
            metric: metric,
            aggregation: ChallengeAggregation.sum,
            filters: const ChallengeFilters(),
            goal: ChallengeGoal(
              kind: kind,
              value: finalValue,
            ),
            tieBreakers: const [TieBreakerType.earliestCompletion],
            awardsMedals: true,
            awardsBadges: true,
            medalsAwarded: false,
            badgesAwarded: false,
            createdAt: DateTime.now(),
            createdBy: currentUser.uid,
          );

          try {
            final repo = ChallengesRepository();
            await repo.createChallenge(widget.groupId, challenge);

            if (mounted) {
              _confettiController.play();
              ModernSnackBar.showSuccess(context, 'Reto "$title" creado ');
            }
          } catch (e) {
            if (mounted) {
              ModernSnackBar.showError(context, 'Error al crear el reto: $e');
            }
          }
        },
      ),
    );
  }
}

/// Botón de volver con animación
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
          color: _isPressed
              ? Theme.of(context).colorScheme.onSurface.withOpacity(0.06)
              : Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.transparent
                  : Colors.black.withOpacity(_isPressed ? 0.03 : 0.06),
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

/// Tarjeta Premium de Reto con gradiente según tipo
class _PremiumChallengeCard extends StatefulWidget {
  final Challenge challenge;
  final ChallengeParticipant? participant;
  final List<Color> gradientColors;
  final VoidCallback onTap;
  final VoidCallback? onJoin;

  const _PremiumChallengeCard({
    required this.challenge,
    required this.participant,
    required this.gradientColors,
    required this.onTap,
    this.onJoin,
  });

  @override
  State<_PremiumChallengeCard> createState() => _PremiumChallengeCardState();
}

class _PremiumChallengeCardState extends State<_PremiumChallengeCard> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    // Calcular progreso
    double progress = 0.0;
    if (widget.participant != null) {
      final goalValue = widget.challenge.goal.value;
      if (goalValue > 0) {
        progress = (widget.participant!.score / goalValue).clamp(0.0, 1.0);
      }
    }
    final bool isCompleted = progress >= 1.0;

    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) {
        setState(() => _isPressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        transform: Matrix4.identity()..scale(_isPressed ? 0.98 : 1.0),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: widget.gradientColors.first.withOpacity(_isPressed ? 0.15 : 0.1),
              blurRadius: _isPressed ? 12 : 24,
              offset: Offset(0, _isPressed ? 4 : 10),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Stack(
            children: [
              // Decoración de fondo
              Positioned(
                top: -20,
                right: -20,
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [
                        widget.gradientColors.first.withOpacity(0.1),
                        widget.gradientColors.last.withOpacity(0.05),
                      ],
                    ),
                  ),
                ),
              ),

              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header del reto
                    Row(
                      children: [
                        // Icono con gradiente
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: widget.gradientColors,
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: widget.gradientColors.first.withOpacity(0.3),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Icon(
                            _getMetricIcon(widget.challenge.metric),
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.challenge.title,
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w800,
                                  color: Theme.of(context).colorScheme.onSurface,
                                  letterSpacing: -0.3,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Objetivo: ${widget.challenge.goal.displayLabel ?? _formatGoalValue(widget.challenge.goal)}',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        
                        // Status indicator
                        if (isCompleted)
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: const BoxDecoration(
                              color: Colors.green,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.check, color: Colors.white, size: 14),
                          )
                        else
                          Icon(
                            Icons.chevron_right,
                            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
                          ),
                      ],
                    ),

                    // Barra de progreso si participa
                    if (widget.participant != null) ...[
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "Tu progreso",
                            style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            "${(progress * 100).toInt()}%",
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                              color: isCompleted
                                  ? Colors.green
                                  : widget.gradientColors.first,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0, end: progress),
                          duration: const Duration(milliseconds: 1000),
                          curve: Curves.easeOutCubic,
                          builder: (context, value, _) {
                            return LinearProgressIndicator(
                              value: value,
                              backgroundColor: Theme.of(context).colorScheme.onSurface.withOpacity(0.06),
                              color: isCompleted
                                  ? Colors.green
                                  : widget.gradientColors.first,
                              minHeight: 10,
                            );
                          },
                        ),
                      ),
                      if (isCompleted)
                        Padding(
                          padding: const EdgeInsets.only(top: 10),
                          child: Text(
                            "¡Reto completado! 🎉",
                            style: TextStyle(
                              color: Colors.green.shade600,
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        )
                    ] else ...[
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: widget.gradientColors.first.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.info_outline_rounded,
                                  size: 14,
                                  color: widget.gradientColors.first,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  "Toca para detalles",
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: widget.gradientColors.first,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (widget.onJoin != null)
                            GestureDetector(
                              onTap: widget.onJoin,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(colors: widget.gradientColors),
                                  borderRadius: BorderRadius.circular(20),
                                  boxShadow: [
                                    BoxShadow(
                                      color: widget.gradientColors.first.withOpacity(0.3),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: const Row(
                                  children: [
                                    Text(
                                      "Unirme",
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                    ),
                                    SizedBox(width: 4),
                                    Icon(Icons.add_circle_outline, color: Colors.white, size: 16),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getMetricIcon(ChallengeMetric metric) {
    if (metric == ChallengeMetric.distance) return Icons.straighten_rounded;
    if (metric == ChallengeMetric.time) return Icons.timer_rounded;
    if (metric == ChallengeMetric.sessions) return Icons.fitness_center_rounded;
    return Icons.emoji_events_rounded;
  }

  String _formatGoalValue(ChallengeGoal goal) {
    final val = goal.value;
    if (goal.kind == GoalKind.distance) return '${(val / 1000).toStringAsFixed(1)} km';
    if (goal.kind == GoalKind.time) return '${(val / 3600).toStringAsFixed(1)} h';
    return '${val.toInt()}';
  }
}

/// Tarjeta Premium de Miembro
class _PremiumMemberCard extends StatelessWidget {
  final GroupMemberStats member;
  final int rank;
  final VoidCallback onTap;

  const _PremiumMemberCard({
    required this.member,
    required this.rank,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isPodium = rank <= 3;
    final rankColor = _getRankColor(rank);
    final isPending = member.status == MemberStatus.pending;

    return GestureDetector(
      onTap: onTap,
      child: Opacity(
        opacity: isPending ? 0.6 : 1.0,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(20),
            border: isPodium && !isPending
                ? Border.all(color: rankColor.withOpacity(0.3), width: 2)
                : isPending
                    ? Border.all(color: Colors.orange.withOpacity(0.5), width: 1.5, style: BorderStyle.solid)
                    : null,
            boxShadow: [
              BoxShadow(
                color: (isPodium && !isPending)
                    ? rankColor.withOpacity(0.1)
                    : (Theme.of(context).brightness == Brightness.dark
                        ? Colors.transparent
                        : Colors.black.withOpacity(0.04)),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              // Rank Badge
              if (!isPending)
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: isPodium ? rankColor : Theme.of(context).colorScheme.onSurface.withOpacity(0.06),
                    shape: BoxShape.circle,
                    boxShadow: isPodium
                        ? [BoxShadow(color: rankColor.withOpacity(0.3), blurRadius: 8)]
                        : null,
                  ),
                  child: Center(
                    child: isPodium
                        ? const Icon(Icons.emoji_events, color: Colors.white, size: 18)
                        : Text(
                            '$rank',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                            ),
                          ),
                  ),
                )
              else
                Container(
                   width: 36,
                   height: 36,
                   decoration: BoxDecoration(
                     color: Colors.orange.withOpacity(0.1),
                     shape: BoxShape.circle,
                   ),
                   child: const Icon(Icons.hourglass_empty_rounded, color: Colors.orange, size: 18),
                ),
              const SizedBox(width: 14),

              // Avatar
              SizedBox(
                width: 52,
                height: 52,
                child: AvatarHelper.construirAvatar(
                  radius: 26,
                  type: member.profilePicType ?? 'none',
                  config: member.avatarConfig,
                  url: member.photoUrl,
                ),
              ),
              const SizedBox(width: 14),

              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          member.name,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                        if (isPending)
                          Padding(
                            padding: const EdgeInsets.only(left: 6.0),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.orange.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text(
                                "Pendiente",
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.orange,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    if (!isPending)
                      Row(
                        children: [
                          Icon(
                            Icons.directions_run,
                            size: 14,
                            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            "${member.totalKm.toStringAsFixed(1)} km",
                            style: const TextStyle(
                              color: Tema.brandPurple,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      )
                    else
                      const Text(
                        "Esperando aceptación...",
                        style: TextStyle(fontSize: 12, color: Colors.grey, fontStyle: FontStyle.italic),
                      ),
                  ],
                ),
              ),

              // Arrow
              if (!isPending)
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.06),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 14,
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getRankColor(int rank) {
    if (rank == 1) return const Color(0xFFFFD700);
    if (rank == 2) return const Color(0xFFC0C0C0);
    if (rank == 3) return const Color(0xFFCD7F32);
    return Colors.grey.shade300;
  }
}

/// Animación staggered para items de reto
class _StaggeredChallengeItem extends StatefulWidget {
  final int index;
  final Widget child;

  const _StaggeredChallengeItem({required this.index, required this.child});

  @override
  State<_StaggeredChallengeItem> createState() => _StaggeredChallengeItemState();
}

class _StaggeredChallengeItemState extends State<_StaggeredChallengeItem>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _animation = CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);

    Future.delayed(Duration(milliseconds: widget.index * 80), () {
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

/// Animación staggered para items de miembro
class _StaggeredMemberItem extends StatefulWidget {
  final int index;
  final Widget child;

  const _StaggeredMemberItem({required this.index, required this.child});

  @override
  State<_StaggeredMemberItem> createState() => _StaggeredMemberItemState();
}

class _StaggeredMemberItemState extends State<_StaggeredMemberItem>
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

    Future.delayed(Duration(milliseconds: widget.index * 60), () {
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
          begin: const Offset(0.05, 0),
          end: Offset.zero,
        ).animate(_animation),
        child: widget.child,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Invite bottom sheet: code + QR + share + email invite
// ─────────────────────────────────────────────────────────────────────────────

class _InviteSheet extends StatefulWidget {
  final String groupId;
  final String currentUserUid;

  const _InviteSheet({
    required this.groupId,
    required this.currentUserUid,
  });

  @override
  State<_InviteSheet> createState() => _InviteSheetState();
}

class _InviteSheetState extends State<_InviteSheet> {
  final _invitesRepo = InvitesRepository();
  final _emailController = TextEditingController();

  String? _shortCode;
  DateTime? _expiresAt;
  bool _isGenerating = false;
  bool _isSendingEmail = false;
  String? _generateError;

  @override
  void initState() {
    super.initState();
    _generateCode();
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _generateCode() async {
    setState(() {
      _isGenerating = true;
      _generateError = null;
    });
    try {
      final result = await _invitesRepo.createInviteWithCode(
        widget.groupId,
        widget.currentUserUid,
      );
      if (!mounted) return;
      setState(() {
        _shortCode = result.shortCode;
        _expiresAt = DateTime.now().add(const Duration(days: 7));
        _isGenerating = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _generateError = 'No se pudo generar el código: $e';
        _isGenerating = false;
      });
    }
  }

  Future<void> _sendEmailInvite() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) return;
    setState(() => _isSendingEmail = true);
    try {
      final uid = await _invitesRepo.inviteUserByEmail(widget.groupId, email);
      if (!mounted) return;
      if (uid != null) {
        _emailController.clear();
        ModernSnackBar.showSuccess(context, 'Invitación enviada a $email');
      } else {
        ModernSnackBar.showError(context, 'Usuario no encontrado con ese email');
      }
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString().contains('already a member')
          ? 'El usuario ya es miembro o está invitado'
          : 'Error al invitar: $e';
      ModernSnackBar.showError(context, msg);
    } finally {
      if (mounted) setState(() => _isSendingEmail = false);
    }
  }

  void _copyCode() {
    if (_shortCode == null) return;
    Clipboard.setData(ClipboardData(text: _shortCode!));
    ModernSnackBar.showSuccess(context, 'Código copiado');
  }

  void _shareLink() {
    if (_shortCode == null) return;
    final url = InviteTokenHelper.buildInviteUrl(_shortCode!);
    Share.share(
      'Únete a mi grupo en Running Laps con el código $_shortCode '
      'o este enlace: $url',
      subject: 'Invitación a Running Laps',
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        top: 16,
        left: 24,
        right: 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: cs.outline.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Title
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Tema.brandPurple.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.link_rounded,
                      color: Tema.brandPurple, size: 22),
                ),
                const SizedBox(width: 14),
                Text(
                  'Invitar al grupo',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: cs.onSurface,
                    letterSpacing: -0.3,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // ── Code section ────────────────────────────────────────────────
            Text(
              'CÓDIGO DE INVITACIÓN',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
                color: cs.onSurface.withOpacity(0.45),
              ),
            ),
            const SizedBox(height: 12),

            if (_isGenerating)
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 32),
                  child: CircularProgressIndicator(color: Tema.brandPurple),
                ),
              )
            else if (_generateError != null)
              Center(
                child: Column(
                  children: [
                    Text(_generateError!,
                        style: TextStyle(
                            color: cs.error, fontSize: 13),
                        textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    TextButton.icon(
                      onPressed: _generateCode,
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Reintentar'),
                    ),
                  ],
                ),
              )
            else if (_shortCode != null) ...[
              // Code card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: cs.onSurface.withOpacity(isDark ? 0.06 : 0.04),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: Tema.brandPurple.withOpacity(0.2), width: 1.5),
                ),
                child: Column(
                  children: [
                    // Large code display + copy tap
                    GestureDetector(
                      onTap: _copyCode,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            _shortCode!,
                            style: const TextStyle(
                              fontSize: 40,
                              fontWeight: FontWeight.w900,
                              color: Tema.brandPurple,
                              letterSpacing: 8,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Icon(Icons.copy_rounded,
                              color: Tema.brandPurple.withOpacity(0.7),
                              size: 22),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (_expiresAt != null)
                      Text(
                        'Válido hasta ${DateFormat("d MMM yyyy", "es_ES").format(_expiresAt!)}',
                        style: TextStyle(
                            fontSize: 12,
                            color: cs.onSurface.withOpacity(0.45)),
                      ),
                    const SizedBox(height: 20),

                    // QR Code
                    Center(
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: QrImageView(
                          data: InviteTokenHelper.buildInviteUrl(_shortCode!),
                          version: QrVersions.auto,
                          size: 160,
                          backgroundColor: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Action buttons
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _copyCode,
                            icon: const Icon(Icons.copy_rounded, size: 18),
                            label: const Text('Copiar código'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Tema.brandPurple,
                              side: BorderSide(
                                  color: Tema.brandPurple.withOpacity(0.4)),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14)),
                              padding:
                                  const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _shareLink,
                            icon: const Icon(Icons.share_rounded,
                                size: 18, color: Colors.white),
                            label: const Text('Compartir',
                                style: TextStyle(color: Colors.white)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Tema.brandPurple,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14)),
                              padding:
                                  const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // Regenerate button
                    SizedBox(
                      width: double.infinity,
                      child: TextButton.icon(
                        onPressed: _isGenerating ? null : _generateCode,
                        icon: Icon(Icons.refresh_rounded,
                            size: 16,
                            color: cs.onSurface.withOpacity(0.5)),
                        label: Text(
                          'Generar nuevo código',
                          style: TextStyle(
                              color: cs.onSurface.withOpacity(0.5),
                              fontSize: 13),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 28),

            // ── Email invite section ─────────────────────────────────────────
            Text(
              'INVITAR POR EMAIL',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
                color: cs.onSurface.withOpacity(0.45),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    style: const TextStyle(fontSize: 15),
                    decoration: InputDecoration(
                      hintText: 'correo@ejemplo.com',
                      hintStyle:
                          TextStyle(color: cs.onSurface.withOpacity(0.35)),
                      filled: true,
                      fillColor: cs.onSurface.withOpacity(0.04),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide:
                            const BorderSide(color: Tema.brandPurple, width: 2),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _isSendingEmail ? null : _sendEmailInvite,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Tema.brandPurple,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                    ),
                    child: _isSendingEmail
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2),
                          )
                        : const Icon(Icons.send_rounded,
                            color: Colors.white, size: 20),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'El usuario debe estar registrado en la app.',
              style: TextStyle(
                  fontSize: 12, color: cs.onSurface.withOpacity(0.4)),
            ),
          ],
        ),
      ),
    );
  }
}

class _PremiumFloatingActionButton extends StatefulWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _PremiumFloatingActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  State<_PremiumFloatingActionButton> createState() => _PremiumFloatingActionButtonState();
}

class _PremiumFloatingActionButtonState extends State<_PremiumFloatingActionButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) => Transform.scale(
          scale: _scaleAnimation.value,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Colors.black, Color(0xFF333333)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(30),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(widget.icon, color: Colors.white, size: 22),
                const SizedBox(width: 8),
                Text(
                  widget.label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}





