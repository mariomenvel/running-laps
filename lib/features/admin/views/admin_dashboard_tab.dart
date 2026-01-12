import 'package:flutter/material.dart';
import '../viewmodels/admin_controller.dart';

class AdminDashboardTab extends StatelessWidget {
  final AdminController controller;

  const AdminDashboardTab({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    if (controller.stats.isEmpty) {
      controller.loadDashboardStats();
    }

    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        if (controller.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        final stats = controller.stats;
        final usuarios = stats['totalUsers'] ?? 0;
        final retos = stats['activeChallenges'] ?? 0;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Visión General",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  _buildStatCard(
                    "Usuarios Totales",
                    usuarios.toString(),
                    Icons.people,
                    Colors.blue,
                  ),
                  const SizedBox(width: 16),
                  _buildStatCard(
                    "Retos Globales",
                    retos.toString(),
                    Icons.public,
                    Colors.purple,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Card(
                child: ListTile(
                  title: Text("Estado del Sistema"),
                  subtitle: Text("Operacional"),
                  trailing: Icon(Icons.check_circle, color: Colors.green),
                ),
              ),
              // Aquí se pueden añadir gráficas (Placeholders)
              const SizedBox(height: 20),
              Container(
                height: 200,
                color: Colors.grey[200],
                alignment: Alignment.center,
                child: const Text("Gráfico de Actividad (Próximamente)"),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Expanded(
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 30),
              const SizedBox(height: 8),
              Text(
                value,
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
