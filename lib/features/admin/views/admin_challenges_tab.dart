import 'package:flutter/material.dart';
import '../../groups/data/models/challenge_models.dart';
import '../../groups/data/models/enums.dart'; 
import '../viewmodels/admin_controller.dart';
import '../../groups/views/widgets/create_challenge_modal.dart';
import '../../../../config/app_theme.dart';

class AdminChallengesTab extends StatelessWidget {
  final AdminController controller;

  const AdminChallengesTab({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StreamBuilder<List<Challenge>>(
        stream: controller.globalChallengesStream,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text("Error: ${snapshot.error}"));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final challenges = snapshot.data ?? [];

          if (challenges.isEmpty) {
            return const Center(child: Text("No hay retos globales activos"));
          }

          return ListView.separated(
            itemCount: challenges.length,
            separatorBuilder: (c, i) => const Divider(),
            itemBuilder: (context, index) {
              final challenge = challenges[index];
              return ListTile(
                title: Text(challenge.title),
                subtitle: Text("${challenge.startAt.day}/${challenge.startAt.month} - ${challenge.endAt.day}/${challenge.endAt.month}"),
                trailing: Chip(
                  label: Text(challenge.status.name.toUpperCase()),
                  backgroundColor: challenge.status.name == 'active' 
                      ? Colors.green.withOpacity(0.2) 
                      : Colors.orange.withOpacity(0.2),
                ),
                onTap: () {
                  // Todo: Ver detalles o editar
                },
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Tema.brandPurple,
        onPressed: () {
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (context) => CreateChallengeModal(
              onCreate: (title, kind, value, start, end) {
                // Conversión de unidades para backend
                double finalValue = value;
                 ChallengeMetric metric = ChallengeMetric.distance;

                switch (kind) {
                  case GoalKind.distance:
                    metric = ChallengeMetric.distance;
                    finalValue = value * 1000; // km -> m
                    break;
                  case GoalKind.time:
                    metric = ChallengeMetric.time;
                    finalValue = value * 60; // min -> sec
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
