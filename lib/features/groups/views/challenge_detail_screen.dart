import 'package:flutter/material.dart';
import 'package:running_laps/core/utils/app_transitions.dart';
import '../viewmodels/challenge_detail_controller.dart';
import '../data/models/challenge_models.dart';
import '../data/helpers/challenge_helpers.dart';
import '../data/models/enums.dart';

import 'package:intl/intl.dart';
import 'package:running_laps/config/app_theme.dart';
import '../../../../core/widgets/app_header.dart';
import '../../../../core/widgets/gradient_banner.dart';
import '../../profile/views/profile_menu_screen.dart';

class ChallengeDetailScreen extends StatefulWidget {
  final String groupId;
  final String challengeId;

  const ChallengeDetailScreen({
    Key? key,
    required this.groupId,
    required this.challengeId,
  }) : super(key: key);

  @override
  State<ChallengeDetailScreen> createState() => _ChallengeDetailScreenState();
}

class _ChallengeDetailScreenState extends State<ChallengeDetailScreen>
    with TickerProviderStateMixin {
  late ChallengeDetailController _controller;
  late AnimationController _heroAnimController;
  late Animation<double> _heroScaleAnimation;

  // Gradient colors by metric type
  static const Map<ChallengeMetric, List<Color>> _metricGradients = {
    ChallengeMetric.distance: [Color(0xFF1E88E5), Color(0xFF42A5F5)],
    ChallengeMetric.time: [Color(0xFFFB8C00), Color(0xFFFFA726)],
    ChallengeMetric.sessions: [Color(0xFFE91E63), Color(0xFFF48FB1)],
  };

  @override
  void initState() {
    super.initState();
    _controller = ChallengeDetailController(
      groupId: widget.groupId,
      challengeId: widget.challengeId,
    );
    _controller.init();

    _heroAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _heroScaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _heroAnimController, curve: Curves.easeOutBack),
    );
    _heroAnimController.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    _heroAnimController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F8),
      body: SafeArea(
        child: Column(
          children: [
            // Header
            AppHeader(
              onTapLeft: null,
              onTapRight: () {
                Navigator.push(
                  context,
                  AppRoute(page: const ProfileMenuView()),
                );
              },
              showBottomDivider: false,
            ),

            // Back Button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                children: [
                  _AnimatedBackButton(onTap: () => Navigator.pop(context)),
                ],
              ),
            ),

            // Content
            Expanded(
              child: ValueListenableBuilder<bool>(
                valueListenable: _controller.isLoading,
                builder: (context, loading, _) {
                  if (loading) {
                    return const Center(
                      child: CircularProgressIndicator(color: Tema.brandPurple),
                    );
                  }

                  return ValueListenableBuilder<String?>(
                    valueListenable: _controller.error,
                    builder: (context, error, _) {
                      if (error != null) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.error_outline,
                                size: 64,
                                color: Colors.red.shade300,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Error: $error',
                                style: TextStyle(color: Colors.red.shade600),
                              ),
                            ],
                          ),
                        );
                      }

                      return ValueListenableBuilder<Challenge?>(
                        valueListenable: _controller.challenge,
                        builder: (context, challenge, _) {
                          if (challenge == null) {
                            return const Center(
                              child: Text('Reto no encontrado'),
                            );
                          }

                          return _buildContent(challenge);
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(Challenge challenge) {
    final gradientColors = _metricGradients[challenge.metric] ??
        [Tema.brandPurple, Tema.brandPurple.withOpacity(0.7)];

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Challenge Header Banner
          _buildChallengeBanner(challenge, gradientColors),

          const SizedBox(height: 24),

          // Hero Progress Section
          ScaleTransition(
            scale: _heroScaleAnimation,
            child: _buildHeroSection(challenge, gradientColors),
          ),

          const SizedBox(height: 32),

          // Leaderboard Section
          _buildLeaderboardHeader(),
          const SizedBox(height: 16),
          _buildLeaderboardList(challenge, gradientColors),

          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildChallengeBanner(Challenge challenge, List<Color> gradientColors) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradientColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: gradientColors.first.withOpacity(0.35),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          // Icon
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(
              _getMetricIcon(challenge.metric),
              size: 40,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),

          // Title
          Text(
            challenge.title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 8),

          // Dates
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '${DateFormat('dd MMM').format(challenge.startAt)} - ${DateFormat('dd MMM').format(challenge.endAt)}',
              style: TextStyle(
                color: Colors.white.withOpacity(0.95),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroSection(Challenge challenge, List<Color> gradientColors) {
    return ValueListenableBuilder<ChallengeParticipant?>(
      valueListenable: _controller.myParticipant,
      builder: (context, me, _) {
        if (me == null) {
          return Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              children: [
                Icon(
                  Icons.person_add_rounded,
                  size: 48,
                  color: Colors.grey.shade300,
                ),
                const SizedBox(height: 16),
                Text(
                  'No estás participando',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Únete al reto desde la pantalla del grupo',
                  style: TextStyle(
                    color: Colors.grey.shade400,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          );
        }

        final progress = _controller.getProgress();
        final isCompleted = progress >= 1.0;

        return Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: gradientColors.first.withOpacity(0.12),
                blurRadius: 30,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Column(
            children: [
              // Circular Progress
              TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 0, end: progress),
                duration: const Duration(milliseconds: 1500),
                curve: Curves.easeOutCubic,
                builder: (context, animatedProgress, _) {
                  final percentage = (animatedProgress * 100).clamp(0, 100).toInt();

                  return SizedBox(
                    height: 180,
                    width: 180,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Background Circle
                        SizedBox(
                          height: 180,
                          width: 180,
                          child: CircularProgressIndicator(
                            value: 1.0,
                            strokeWidth: 14,
                            color: Colors.grey.shade100,
                            backgroundColor: Colors.transparent,
                          ),
                        ),
                        // Progress Arc
                        SizedBox(
                          height: 180,
                          width: 180,
                          child: CircularProgressIndicator(
                            value: animatedProgress,
                            strokeWidth: 14,
                            strokeCap: StrokeCap.round,
                            color: isCompleted
                                ? Colors.green
                                : gradientColors.first,
                            backgroundColor: Colors.transparent,
                          ),
                        ),
                        // Center Info
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              "$percentage%",
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                color: isCompleted
                                    ? Colors.green
                                    : gradientColors.first,
                                fontSize: 44,
                                letterSpacing: -2,
                              ),
                            ),
                            Text(
                              isCompleted ? "¡COMPLETADO!" : "PROGRESO",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: isCompleted
                                    ? Colors.green.withOpacity(0.7)
                                    : gradientColors.first.withOpacity(0.6),
                                fontSize: 11,
                                letterSpacing: 1.2,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),

              const SizedBox(height: 32),

              // Stats Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStatColumn(
                    "ACTUAL",
                    _formatScore(me.score, challenge.metric),
                    gradientColors.first,
                  ),
                  Container(
                    width: 1,
                    height: 45,
                    color: Colors.grey.shade200,
                  ),
                  _buildStatColumn(
                    "META",
                    _formatGoal(challenge.goal),
                    Colors.grey.shade700,
                  ),
                ],
              ),

              if (isCompleted) ...[
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.green.shade400, Colors.green.shade600],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.green.withOpacity(0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.celebration, color: Colors.white, size: 20),
                      SizedBox(width: 10),
                      Text(
                        "¡Lo conseguiste!",
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatColumn(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey.shade500,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.8,
          ),
        ),
      ],
    );
  }

  Widget _buildLeaderboardHeader() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.amber.shade50,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            Icons.leaderboard_rounded,
            color: Colors.amber.shade700,
            size: 22,
          ),
        ),
        const SizedBox(width: 14),
        const Text(
          'Ranking',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: Colors.black87,
          ),
        ),
      ],
    );
  }

  Widget _buildLeaderboardList(Challenge challenge, List<Color> gradientColors) {
    return ValueListenableBuilder<List<ChallengeParticipant>>(
      valueListenable: _controller.participants,
      builder: (context, participants, _) {
        if (participants.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              children: [
                Icon(Icons.people_outline, size: 48, color: Colors.grey.shade300),
                const SizedBox(height: 12),
                Text(
                  'Sin participantes',
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 15),
                ),
              ],
            ),
          );
        }

        return Column(
          children: List.generate(participants.length, (index) {
            final p = participants[index];
            final rank = index + 1;
            final isMe = p.uid == _controller.myParticipant.value?.uid;

            return TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: 1.0),
              duration: Duration(milliseconds: 400 + (index * 80)),
              curve: Curves.easeOutCubic,
              builder: (context, value, child) {
                return Transform.translate(
                  offset: Offset(0, 20 * (1 - value)),
                  child: Opacity(opacity: value, child: child),
                );
              },
              child: _buildLeaderboardItem(
                participant: p,
                rank: rank,
                isMe: isMe,
                challenge: challenge,
                gradientColors: gradientColors,
              ),
            );
          }),
        );
      },
    );
  }

  Widget _buildLeaderboardItem({
    required ChallengeParticipant participant,
    required int rank,
    required bool isMe,
    required Challenge challenge,
    required List<Color> gradientColors,
  }) {
    Widget rankWidget;
    if (rank == 1) {
      rankWidget = const Text("🥇", style: TextStyle(fontSize: 24));
    } else if (rank == 2) {
      rankWidget = const Text("🥈", style: TextStyle(fontSize: 24));
    } else if (rank == 3) {
      rankWidget = const Text("🥉", style: TextStyle(fontSize: 24));
    } else {
      rankWidget = Text(
        '$rank',
        style: TextStyle(
          color: Colors.grey.shade600,
          fontWeight: FontWeight.bold,
          fontSize: 16,
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: isMe ? gradientColors.first.withOpacity(0.08) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isMe
              ? gradientColors.first.withOpacity(0.3)
              : Colors.grey.shade100,
          width: isMe ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isMe
                ? gradientColors.first.withOpacity(0.1)
                : Colors.black.withOpacity(0.03),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            alignment: Alignment.center,
            child: rankWidget,
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 44,
            height: 44,
            child: AvatarHelper.construirAvatar(
              radius: 22,
              type: participant.profilePicType ?? 'none',
              config: participant.avatarConfig,
              url: participant.photoUrl,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isMe ? 'Tú' : (participant.displayName ?? 'Usuario ${participant.uid.substring(0, 4)}'),
                  style: TextStyle(
                    color: Colors.black87,
                    fontWeight: isMe ? FontWeight.w800 : FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
                if (isMe)
                  Text(
                    "¡Sigue así!",
                    style: TextStyle(
                      color: gradientColors.first,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              gradient: isMe
                  ? LinearGradient(colors: gradientColors)
                  : null,
              color: isMe ? null : Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
              border: isMe
                  ? null
                  : Border.all(color: Colors.grey.shade200),
            ),
            child: Text(
              _formatScore(participant.score, challenge.metric),
              style: TextStyle(
                color: isMe ? Colors.white : Colors.black87,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  IconData _getMetricIcon(ChallengeMetric metric) {
    if (metric == ChallengeMetric.distance) return Icons.straighten_rounded;
    if (metric == ChallengeMetric.time) return Icons.timer_rounded;
    if (metric == ChallengeMetric.sessions) return Icons.fitness_center_rounded;
    return Icons.emoji_events_rounded;
  }

  String _formatScore(double score, ChallengeMetric metric) {
    if (metric == ChallengeMetric.distance) {
      return '${(score / 1000).toStringAsFixed(1)} km';
    } else if (metric == ChallengeMetric.time) {
      final hours = (score / 3600).floor();
      return '${hours}h';
    } else if (metric == ChallengeMetric.sessions) {
      return '${score.toInt()} ses.';
    }
    return score.toStringAsFixed(1);
  }

  String _formatGoal(ChallengeGoal goal) {
    return _formatScore(goal.value, goal.kind.toMetric());
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

extension GoalKindToMetric on GoalKind {
  ChallengeMetric toMetric() {
    switch (this) {
      case GoalKind.distance:
        return ChallengeMetric.distance;
      case GoalKind.time:
        return ChallengeMetric.time;
      case GoalKind.sessions:
        return ChallengeMetric.sessions;
      default:
        return ChallengeMetric.distance;
    }
  }
}




