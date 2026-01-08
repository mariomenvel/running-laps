import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:confetti/confetti.dart';

import '../viewmodels/group_challenges_controller.dart';
import '../data/enums.dart';
import '../data/challenge_models.dart';
import '../data/challenges_repository.dart';
import '../../../../app/tema.dart';
import '../../../../core/widgets/app_header.dart';
import '../../../../core/widgets/app_footer.dart';
import '../../../../core/widgets/gradient_banner.dart';

// Screens
import 'challenge_detail_screen.dart';
import 'group_rewards_screen.dart';
import '../group/view/participant_profile_screen.dart';
import '../group_model.dart';

// Widgets
import 'widgets/create_challenge_modal.dart';
import '../../../../features/groups/data/challenge_helpers.dart';
import '../../training/views/training_start_view.dart';
import '../../profile/views/profile_menu_screen.dart';
import '../data/invites_repository.dart';
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
    _tabController = TabController(length: 2, vsync: this);
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

    _controller.showAutoJoinPrompt.addListener(_checkAutoJoinPrompt);
    _controller.group.addListener(_checkOwnership);
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
    _confettiController.dispose();
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
      backgroundColor: const Color(0xFFF4F6F8),
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
                      MaterialPageRoute(builder: (context) => const ProfileMenuView()),
                    );
                  },
                ),

                // 2. Banner del grupo con gradiente
                FadeTransition(
                  opacity: _headerFadeAnimation,
                  child: ValueListenableBuilder(
                    valueListenable: _controller.group,
                    builder: (context, group, _) {
                      return GradientBanner(
                        title: group?.name ?? 'Cargando...',
                        subtitle: '${group?.memberCount ?? 0} miembros activos',
                        icon: Icons.groups_rounded,
                        height: 85,
                        trailing: IconButton(
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => GroupRewardsScreen(groupId: widget.groupId),
                              ),
                            );
                          },
                          icon: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              Icons.emoji_events_outlined,
                              color: Colors.amber.shade200,
                              size: 22,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),

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
                _buildAnimatedTabBar(),

                // 5. Contenido
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildChallengesTab(),
                      _buildMembersTab(),
                    ],
                  ),
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
                    MaterialPageRoute(builder: (_) => TrainingStartView()),
                  );
                },
              ),
            ),
        ],
      ),
      floatingActionButton: _isOwner
          ? Container(
              height: 56,
              width: 56,
              margin: const EdgeInsets.only(bottom: 130, right: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
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
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  // --- Custom Animated Tab Bar ---
  Widget _buildAnimatedTabBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Tema.brandPurple.withOpacity(0.15),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        labelColor: Tema.brandPurple,
        unselectedLabelColor: Colors.grey.shade500,
        labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
        unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        dividerColor: Colors.transparent,
        splashBorderRadius: BorderRadius.circular(16),
        tabs: const [
          Tab(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.flag_rounded, size: 18),
                SizedBox(width: 8),
                Text("Retos"),
              ],
            ),
          ),
          Tab(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.people_alt_rounded, size: 18),
                SizedBox(width: 8),
                Text("Miembros"),
              ],
            ),
          ),
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
                              MaterialPageRoute(
                                builder: (_) => ChallengeDetailScreen(
                                  groupId: widget.groupId,
                                  challengeId: challenge.id,
                                ),
                              ),
                            );
                          },
                          onJoin: () async {
                            await _controller.joinChallenge(challenge.id);
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: const Text("¡Te has unido al reto! 🚀"),
                                  backgroundColor: Colors.green,
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                              );
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
                          "Invitar Miembro por Email",
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
                              MaterialPageRoute(
                                builder: (_) => ParticipantProfileScreen(
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
    final emailController = TextEditingController();
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              title: const Row(
                children: [
                  Icon(Icons.mail_outline_rounded, color: Tema.brandPurple),
                  SizedBox(width: 12),
                  Text("Invitar Miembro"),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    "Introduce el correo electrónico del usuario. Debe estar registrado en la app.",
                    style: TextStyle(color: Colors.grey, fontSize: 13),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: emailController,
                    decoration: InputDecoration(
                      labelText: "Email del usuario",
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      filled: true,
                      fillColor: Colors.grey.shade50,
                    ),
                    keyboardType: TextInputType.emailAddress,
                  ),
                  if (isLoading)
                     const Padding(
                       padding: EdgeInsets.only(top: 16.0),
                       child: CircularProgressIndicator(),
                     ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: isLoading ? null : () => Navigator.pop(context),
                  child: const Text("Cancelar", style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Tema.brandPurple,
                     shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: isLoading ? null : () async {
                    final email = emailController.text.trim();
                    if (email.isEmpty) return;

                    setState(() => isLoading = true);
                    final repo = InvitesRepository();
                    try {
                      final uid = await repo.inviteUserByEmail(widget.groupId, email);
                      if (uid != null) {
                        if (mounted) {
                          Navigator.pop(context); // Close dialog
                          ModernSnackBar.showSuccess(context, "Invitación enviada correctamente 🚀");
                        }
                      } else {
                        setState(() => isLoading = false);
                        if (mounted) {
                          ModernSnackBar.showError(context, "Usuario no encontrado con ese email.");
                        }
                      }
                    } catch (e) {
                      setState(() => isLoading = false);
                      if (mounted) {
                         // Check specific error messages
                         if (e.toString().contains("already a member")) {
                            ModernSnackBar.showError(context, "El usuario ya es miembro o está invitado.");
                         } else {
                            ModernSnackBar.showError(context, "Error al invitar: $e");
                         }
                      }
                    }
                  },
                  child: const Text("Invitar", style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
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
               const Text(
                 'Sin miembros aún',
                 style: TextStyle(
                   fontSize: 22,
                   fontWeight: FontWeight.w800,
                   color: Colors.black87,
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
            const Text(
              'Aún no hay retos',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Sé el primero en desafiar al grupo\ny comienza la competición.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey.shade500,
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
                    color: Colors.white,
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
              style: TextStyle(color: Colors.grey.shade600),
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
      builder: (context) => CreateChallengeModal(
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
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Row(
                    children: [
                      const Icon(Icons.check_circle, color: Colors.white),
                      const SizedBox(width: 12),
                      Text('Reto "$title" creado 🚀'),
                    ],
                  ),
                  backgroundColor: Colors.green.shade600,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              );
            }
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
              );
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
          color: Colors.white,
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
                                style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.black87,
                                  letterSpacing: -0.3,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Objetivo: ${widget.challenge.goal.displayLabel ?? _formatGoalValue(widget.challenge.goal)}',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey.shade500,
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
                            color: Colors.grey.shade300,
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
                              color: Colors.grey.shade400,
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
                              backgroundColor: Colors.grey.shade100,
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
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: isPodium && !isPending
                ? Border.all(color: rankColor.withOpacity(0.3), width: 2)
                : isPending 
                    ? Border.all(color: Colors.orange.withOpacity(0.5), width: 1.5, style: BorderStyle.solid)
                    : null,
            boxShadow: [
              BoxShadow(
                color: isPodium && !isPending
                    ? rankColor.withOpacity(0.1)
                    : Colors.black.withOpacity(0.04),
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
                    color: isPodium ? rankColor : Colors.grey.shade100,
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
                              color: Colors.grey.shade600,
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
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                            color: Colors.black87,
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
                            color: Colors.grey.shade400,
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
                    color: Colors.grey.shade50,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 14,
                    color: Colors.grey.shade400,
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
