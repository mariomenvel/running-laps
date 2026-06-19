// ⚠️ HUÉRFANO — sin referencias activas detectadas
// por auditoría del 2026-06-19. NO USAR como base para
// nuevo desarrollo. Pendiente de confirmar con testing
// manual antes de eliminar. Ver CHANGELOG.md.
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:running_laps/config/app_theme.dart';
import 'package:running_laps/core/utils/app_transitions.dart';
import 'package:running_laps/core/widgets/modern_snackbar.dart';
import 'package:running_laps/features/groups/data/models/challenge_models.dart';
import 'package:running_laps/features/groups/data/helpers/challenge_color_helper.dart';
import 'package:running_laps/features/groups/data/models/enums.dart';
import 'package:running_laps/features/groups/views/challenge_detail_screen.dart';
import '../data/global_challenges_repository.dart';

class GlobalChallengeCard extends StatefulWidget {
  final Challenge challenge;
  final String userId;
  final GlobalChallengesRepository repository;

  const GlobalChallengeCard({
    Key? key,
    required this.challenge,
    required this.userId,
    required this.repository,
  }) : super(key: key);

  @override
  State<GlobalChallengeCard> createState() => _GlobalChallengeCardState();
}

class _GlobalChallengeCardState extends State<GlobalChallengeCard> {
  bool _isJoining = false;
  int _participantCount = 0;


  @override
  void initState() {
    super.initState();
    _fetchCount();
  }

  @override
  void dispose() {
    super.dispose();
  }

  void _fetchCount() async {
    final count =
        await widget.repository.getParticipantCount(widget.challenge.id);
    if (mounted) setState(() => _participantCount = count);
  }

  Future<void> _join() async {
    if (_isJoining) return;
    setState(() => _isJoining = true);
    try {
      await widget.repository.joinChallenge(
          widget.userId, widget.challenge.id);
      final newCount =
          await widget.repository.getParticipantCount(widget.challenge.id);
      if (mounted) setState(() => _participantCount = newCount);
    } catch (e) {
      if (mounted) ModernSnackBar.showError(context, 'Error al unirse: $e');
    } finally {
      if (mounted) setState(() => _isJoining = false);
    }
  }

  IconData _metricIcon(ChallengeMetric m) {
    if (m == ChallengeMetric.distance) return Icons.straighten_rounded;
    if (m == ChallengeMetric.time) return Icons.timer_rounded;
    if (m == ChallengeMetric.sessions) return Icons.fitness_center_rounded;
    return Icons.emoji_events_rounded;
  }

  String _formatScore(double score, ChallengeMetric metric) {
    if (metric == ChallengeMetric.distance) {
      return '${(score / 1000).toStringAsFixed(1)} km';
    }
    if (metric == ChallengeMetric.time) return '${(score / 3600).floor()}h';
    if (metric == ChallengeMetric.sessions) return '${score.toInt()} ses.';
    return score.toStringAsFixed(1);
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.challenge;
    final accentColor = ChallengeColorHelper.accentForMetric(c.metric);
    final endDate = DateFormat('dd MMM').format(c.endAt);

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        AppRoute(
          page: ChallengeDetailScreen(
            groupId: 'global',
            challengeId: c.id,
          ),
        ),
      ),
      child: Container(
        constraints: const BoxConstraints(minHeight: 140),
        decoration: BoxDecoration(
          color: accentColor,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: accentColor.withOpacity(0.35),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Stack(
          children: [
            // Decorative watermark circle
            Positioned(
              top: -28,
              right: -28,
              child: Container(
                width: 110,
                height: 110,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.08),
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Row 1: metric icon + end date badge
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          _metricIcon(c.metric),
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Hasta $endDate',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 8),

                  // Title
                  Text(
                    c.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                      letterSpacing: -0.3,
                      height: 1.2,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),

                  const SizedBox(height: 4),

                  // Participant count
                  Row(
                    children: [
                      Icon(Icons.people_outline_rounded,
                          size: 12, color: Colors.white.withOpacity(0.7)),
                      const SizedBox(width: 4),
                      Text(
                        '$_participantCount participantes',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.75),
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // Join button or progress — driven by participation stream
                  StreamBuilder<ChallengeParticipant?>(
                    stream: widget.repository.streamMyParticipation(
                        widget.userId, c.id),
                    builder: (ctx, snap) {
                      if (snap.connectionState == ConnectionState.waiting &&
                          snap.data == null) {
                        return SizedBox(
                          height: 38,
                          child: Center(
                            child: SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white54,
                              ),
                            ),
                          ),
                        );
                      }
                      final participant = snap.data;
                      if (participant != null) {
                        final progress = c.goal.value > 0
                            ? (participant.score / c.goal.value)
                                .clamp(0.0, 1.0)
                            : 0.0;
                        return _buildJoinedState(participant, c, progress);
                      }
                      return _buildJoinButton();
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildJoinButton() {
    final accentColor = ChallengeColorHelper.accentForMetric(widget.challenge.metric);
    return GestureDetector(
      onTap: _isJoining ? null : _join,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.12),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Center(
          child: _isJoining
              ? SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: accentColor,
                  ),
                )
              : Text(
                  'Unirse',
                  style: TextStyle(
                    color: accentColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildJoinedState(
    ChallengeParticipant p,
    Challenge c,
    double progress,
  ) {
    final scoreStr = _formatScore(p.score, c.metric);
    final goalStr = _formatScore(c.goal.value, c.metric);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Progress bar
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress,
            backgroundColor: Colors.white.withOpacity(0.25),
            color: Colors.white,
            minHeight: 6,
          ),
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              scoreStr,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
            Row(
              children: [
                const Icon(Icons.check_circle_rounded,
                    color: Colors.white, size: 12),
                const SizedBox(width: 4),
                Text(
                  'de $goalStr',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }
}
