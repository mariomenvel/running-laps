import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../groups/data/models/challenge_models.dart';
import '../../groups/data/models/enums.dart';
import '../../groups/data/helpers/challenge_color_helper.dart';
import '../viewmodels/admin_controller.dart';
import '../../groups/views/widgets/create_challenge_modal.dart';
import '../../../../config/app_theme.dart';

class AdminChallengesTab extends StatelessWidget {
  final AdminController controller;

  const AdminChallengesTab({super.key, required this.controller});

  // ── Metric helpers ──────────────────────────────────────────────
  IconData _metricIcon(ChallengeMetric m) {
    switch (m) {
      case ChallengeMetric.distance: return Icons.straighten_rounded;
      case ChallengeMetric.time: return Icons.timer_rounded;
      case ChallengeMetric.sessions: return Icons.fitness_center_rounded;
      case ChallengeMetric.avgPace:
      case ChallengeMetric.bestPace: return Icons.speed_rounded;
    }
  }

  String _metricLabel(ChallengeMetric m) {
    switch (m) {
      case ChallengeMetric.distance: return 'Distancia';
      case ChallengeMetric.time: return 'Tiempo';
      case ChallengeMetric.sessions: return 'Sesiones';
      case ChallengeMetric.avgPace: return 'Ritmo Medio';
      case ChallengeMetric.bestPace: return 'Mejor Ritmo';
    }
  }

  // ── Status helpers ───────────────────────────────────────────────
  Color _statusColor(ChallengeStatus s) {
    switch (s) {
      case ChallengeStatus.draft: return Colors.grey;
      case ChallengeStatus.active: return Colors.green;
      default: return Tema.brandPurple;
    }
  }

  String _statusLabel(ChallengeStatus s) {
    switch (s) {
      case ChallengeStatus.draft: return 'BORRADOR';
      case ChallengeStatus.active: return 'ACTIVO';
      default: return s.name.toUpperCase();
    }
  }

  // ── Delete confirmation ─────────────────────────────────────────
  Future<void> _confirmDelete(BuildContext context, Challenge challenge) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar reto'),
        content: Text('¿Eliminar "${challenge.title}"? Esta acción no se puede deshacer.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await controller.deleteChallenge(challenge.id);
    }
  }

  // ── Card ────────────────────────────────────────────────────────
  Widget _buildChallengeCard(BuildContext context, Challenge challenge) {
    final cs = Theme.of(context).colorScheme;
    final accent = ChallengeColorHelper.accentForMetric(challenge.metric);
    final statusColor = _statusColor(challenge.status);
    final isDraft = challenge.status == ChallengeStatus.draft;
    final fmt = DateFormat('dd MMM');

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outline.withOpacity(0.15)),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.transparent
                : Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 1: metric icon + title + status badge
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: accent.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(_metricIcon(challenge.metric), color: accent, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  challenge.title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: cs.onSurface,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _statusLabel(challenge.status),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: statusColor,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // Row 2: metric label + date range
          Row(
            children: [
              Icon(_metricIcon(challenge.metric),
                  size: 12, color: cs.onSurface.withOpacity(0.4)),
              const SizedBox(width: 4),
              Text(
                _metricLabel(challenge.metric),
                style: TextStyle(
                  fontSize: 12,
                  color: cs.onSurface.withOpacity(0.5),
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: 14),
              Icon(Icons.calendar_today_rounded,
                  size: 12, color: cs.onSurface.withOpacity(0.4)),
              const SizedBox(width: 4),
              Text(
                '${fmt.format(challenge.startAt)} – ${fmt.format(challenge.endAt)}',
                style: TextStyle(
                  fontSize: 12,
                  color: cs.onSurface.withOpacity(0.5),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Row 3: action buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (isDraft) ...[
                FilledButton.tonal(
                  onPressed: () => controller.publishGlobalChallenge(challenge.id),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.green.withOpacity(0.12),
                    foregroundColor: Colors.green.shade700,
                    minimumSize: const Size(0, 34),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.rocket_launch_rounded, size: 14),
                      SizedBox(width: 6),
                      Text('Publicar',
                          style: TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
              ],
              IconButton(
                onPressed: () => _confirmDelete(context, challenge),
                icon: const Icon(Icons.delete_outline_rounded),
                iconSize: 20,
                color: Colors.red.shade400,
                style: IconButton.styleFrom(
                  backgroundColor: Colors.red.withOpacity(0.08),
                  minimumSize: const Size(34, 34),
                  padding: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: cs.surface,
      body: StreamBuilder<List<Challenge>>(
        stream: controller.globalChallengesStream,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text("Error: ${snapshot.error}",
                  style: TextStyle(color: cs.error)),
            );
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(color: Tema.brandPurple));
          }

          final challenges = snapshot.data ?? [];

          if (challenges.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.emoji_events_outlined,
                      size: 48, color: cs.onSurface.withOpacity(0.2)),
                  const SizedBox(height: 12),
                  Text(
                    'No hay retos globales',
                    style: TextStyle(
                        color: cs.onSurface.withOpacity(0.5), fontSize: 15),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: challenges.length,
            itemBuilder: (context, index) =>
                _buildChallengeCard(context, challenges[index]),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Tema.brandPurple,
        foregroundColor: Colors.white,
        onPressed: () {
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (context) => CreateChallengeModal(
              onCreate: (title, kind, value, start, end) {
                double finalValue = value;
                ChallengeMetric metric = ChallengeMetric.distance;

                switch (kind) {
                  case GoalKind.distance:
                    metric = ChallengeMetric.distance;
                    finalValue = value * 1000;
                    break;
                  case GoalKind.time:
                    metric = ChallengeMetric.time;
                    finalValue = value * 60;
                    break;
                  case GoalKind.sessions:
                    metric = ChallengeMetric.sessions;
                    break;
                  default:
                    metric = ChallengeMetric.distance;
                }

                controller.createGlobalChallenge(
                  title: title,
                  description: "",
                  startAt: start,
                  endAt: end,
                  metric: metric,
                  goalValue: finalValue,
                );
              },
            ),
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
