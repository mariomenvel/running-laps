import 'package:flutter/material.dart';
import 'package:running_laps/core/theme/app_colors.dart';
import 'package:running_laps/core/widgets/app_header.dart';
import 'package:running_laps/core/widgets/back_pill.dart';
import 'package:running_laps/core/widgets/shell_embedding_scope.dart';

class CoachPhilosophyView extends StatelessWidget {
  const CoachPhilosophyView({super.key});

  static const List<_PhilosophyBlock> _blocks = [
    _PhilosophyBlock(
      icon: Icons.foundation_outlined,
      title: 'Base aeróbica primero',
      description:
          'El 70-80% de tu volumen es rodaje suave. Es lo que construye '
          'el motor que sostiene todo lo demás.',
    ),
    _PhilosophyBlock(
      icon: Icons.speed_outlined,
      title: 'Intensidad con criterio',
      description:
          'Tus ritmos de series salen de tus marcas reales (VDOT), no de '
          'tablas genéricas. Cada zona tiene un propósito.',
    ),
    _PhilosophyBlock(
      icon: Icons.battery_charging_full_outlined,
      title: 'Tu fatiga manda',
      description:
          'El plan se ajusta a tu carga acumulada (TSB). Si necesitas '
          'descargar, el coach lo detecta antes de que te rompas.',
    ),
    _PhilosophyBlock(
      icon: Icons.trending_up_outlined,
      title: 'Progresión sostenible',
      description:
          'Mejorar es acumular semanas consistentes, no reventarse en una. '
          'El coach progresa el volumen y la intensidad de forma gradual.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background(context),
      body: SafeArea(
        top: false,
        bottom: false,
        child: Column(
          children: [
            const AppHeader(showBottomDivider: false),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.all(20),
                itemCount: _blocks.length + 1,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (!ShellEmbeddingScope.isEmbedded(context)) ...[
                          Row(
                            children: [
                              BackPill(onTap: () => Navigator.of(context).pop()),
                            ],
                          ),
                          const SizedBox(height: 20),
                        ],
                        Text(
                          'Cómo entrena tu coach',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary(context),
                          ),
                        ),
                      ],
                    );
                  }
                  return _PhilosophyCard(block: _blocks[index - 1]);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PhilosophyBlock {
  final IconData icon;
  final String title;
  final String description;

  const _PhilosophyBlock({
    required this.icon,
    required this.title,
    required this.description,
  });
}

class _PhilosophyCard extends StatelessWidget {
  final _PhilosophyBlock block;

  const _PhilosophyCard({required this.block});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceOf(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderOf(context), width: 0.5),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.brand.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(block.icon, color: AppColors.brand, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  block.title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary(context),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  block.description,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.4,
                    color: AppColors.textSecondary(context),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
