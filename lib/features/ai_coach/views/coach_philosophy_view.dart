import 'package:flutter/material.dart';
import 'package:running_laps/core/theme/app_colors.dart';
import 'package:running_laps/core/widgets/app_header.dart';
import 'package:running_laps/features/ai_coach/data/ai_coach_mesocycle_engine.dart';
import 'package:running_laps/features/ai_coach/data/ai_coach_models.dart';
import 'package:running_laps/features/ai_coach/data/ai_coach_repository.dart';

class CoachPhilosophyView extends StatefulWidget {
  const CoachPhilosophyView({super.key});

  @override
  State<CoachPhilosophyView> createState() => _CoachPhilosophyViewState();
}

class _CoachPhilosophyViewState extends State<CoachPhilosophyView> {
  late final Future<AiCoachMesocycle?> _blockFuture;

  @override
  void initState() {
    super.initState();
    _blockFuture = AiCoachRepository().getMesocycle();
  }

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
                itemCount: _blocks.length + 2,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
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
                  if (index == 1) {
                    // Evidencia viva: los 4 principios de abajo dejan de ser
                    // promesas y pasan a tener su curva real debajo.
                    return FutureBuilder<AiCoachMesocycle?>(
                      future: _blockFuture,
                      builder: (context, snapshot) {
                        final block = snapshot.data;
                        if (block == null || block.weekPattern.isEmpty) {
                          return const SizedBox.shrink();
                        }
                        return BlockVolumeCurve(block: block);
                      },
                    );
                  }
                  return _PhilosophyCard(block: _blocks[index - 2]);
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

/// Curva de volumen del bloque activo.
///
/// Convierte "progresión sostenible" y "tu fatiga manda" de promesa en dato:
/// el atleta ve cuánto sube cada semana y, sobre todo, ve la semana de
/// descarga dibujada **antes** de llegar a ella.
class BlockVolumeCurve extends StatelessWidget {
  const BlockVolumeCurve({super.key, required this.block, this.today});

  final AiCoachMesocycle block;

  /// Inyectable para tests; por defecto la fecha real.
  final DateTime? today;

  static const _engine = AiCoachMesocycleEngine();

  int get _currentIndex {
    final now = today ?? DateTime.now();
    final date = DateTime(now.year, now.month, now.day);
    final monday = date.subtract(Duration(days: date.weekday - 1));
    return block.weekIndexFor(monday);
  }

  @override
  Widget build(BuildContext context) {
    final volumes = [
      for (var i = 0; i < block.lengthWeeks; i++)
        _engine.targetVolumeForWeek(block, i),
    ];
    if (volumes.isEmpty) return const SizedBox.shrink();
    final peak = volumes.reduce((a, b) => a > b ? a : b);
    if (peak <= 0) return const SizedBox.shrink();

    final current = _currentIndex;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceOf(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderOf(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Tu bloque ahora',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary(context),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            block.focus,
            style: TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary(context),
            ),
          ),
          const SizedBox(height: 16),
          // Holgura deliberada: texto + barra + etiqueta rondan los 100px y
          // con escalado de fuente accesible crecen más.
          SizedBox(
            height: 124,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (var i = 0; i < volumes.length; i++)
                  Expanded(
                    child: _VolumeBar(
                      km: volumes[i],
                      heightFactor: volumes[i] / peak,
                      weekType: block.weekTypeAt(i),
                      weekNumber: i + 1,
                      isCurrent: i == current,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'La semana de descarga está planificada desde el principio: '
            'es cuando el cuerpo asimila lo que has entrenado.',
            style: TextStyle(
              fontSize: 12,
              height: 1.4,
              color: AppColors.textSecondary(context),
            ),
          ),
        ],
      ),
    );
  }
}

class _VolumeBar extends StatelessWidget {
  const _VolumeBar({
    required this.km,
    required this.heightFactor,
    required this.weekType,
    required this.weekNumber,
    required this.isCurrent,
  });

  final double km;
  final double heightFactor;
  final AiCoachWeekType weekType;
  final int weekNumber;
  final bool isCurrent;

  bool get _isEasy =>
      weekType == AiCoachWeekType.absorb ||
      weekType == AiCoachWeekType.recovery ||
      weekType == AiCoachWeekType.taper ||
      weekType == AiCoachWeekType.restart;

  @override
  Widget build(BuildContext context) {
    final color = _isEasy ? AppColors.rest : AppColors.brand;
    // Las semanas futuras se dibujan translúcidas: son plan, no hecho.
    final alpha = isCurrent ? 1.0 : 0.45;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Text(
            km.round().toString(),
            style: TextStyle(
              fontSize: 11,
              fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500,
              color: isCurrent
                  ? color
                  : AppColors.textSecondary(context),
            ),
          ),
          const SizedBox(height: 4),
          Container(
            height: (heightFactor * 56).clamp(6.0, 56.0),
            decoration: BoxDecoration(
              color: color.withValues(alpha: alpha),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'S$weekNumber',
            style: TextStyle(
              fontSize: 10,
              fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w400,
              color: isCurrent
                  ? AppColors.textPrimary(context)
                  : AppColors.textSecondary(context),
            ),
          ),
        ],
      ),
    );
  }
}
