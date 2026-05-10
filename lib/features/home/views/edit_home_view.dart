import 'package:flutter/material.dart';
import 'package:running_laps/features/home/viewmodels/home_config_controller.dart';
import 'package:running_laps/features/home/data/home_layout_config.dart';
import 'package:running_laps/config/app_theme.dart';
import 'package:running_laps/core/theme/app_colors.dart';
import 'package:running_laps/core/widgets/modern_snackbar.dart';

class EditHomeView extends StatefulWidget {
  final HomeConfigController controller;

  const EditHomeView({
    super.key,
    required this.controller,
  });

  @override
  State<EditHomeView> createState() => _EditHomeViewState();
}

class _EditHomeViewState extends State<EditHomeView> {
  static const int _maxActive = 4;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accentColor = isDark ? AppColors.brandLight : AppColors.brand;

    return Scaffold(
      backgroundColor: isDark
          ? Theme.of(context).colorScheme.background
          : const Color(0xFFF2F2F7),
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.surface,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: accentColor, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          children: [
            Text(
              'Personalizar inicio',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            Text(
              'Hasta $_maxActive estadísticas visibles',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.45),
              ),
            ),
          ],
        ),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: () => _confirmReset(context),
            child: Text('Reset', style: TextStyle(color: accentColor, fontSize: 15)),
          ),
        ],
      ),
      body: ValueListenableBuilder<HomeLayoutConfig?>(
        valueListenable: widget.controller.config,
        builder: (context, config, _) {
          if (config == null) {
            return const Center(child: CircularProgressIndicator(color: AppColors.brand));
          }

          final allWidgets = List<HomeWidget>.from(config.widgets)
            ..sort((a, b) => a.order.compareTo(b.order));
          final active = allWidgets.where((w) => w.visible).toList();
          final available = allWidgets.where((w) => !w.visible).toList();

          return SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 48),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sectionHeader(context, 'EN TU INICIO', badge: '${active.length}/$_maxActive'),
                _buildActiveSection(context, active),
                _sectionHeader(context, 'DISPONIBLES'),
                _buildAvailableSection(context, available, active.length),
              ],
            ),
          );
        },
      ),
    );
  }

  // ── Section header ────────────────────────────────────────────────────────

  Widget _sectionHeader(BuildContext context, String title, {String? badge}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 10),
      child: Row(
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.7,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.45),
            ),
          ),
          if (badge != null) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.brand.withOpacity(0.13),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                badge,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.brand,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── Active section ────────────────────────────────────────────────────────

  Widget _buildActiveSection(BuildContext context, List<HomeWidget> active) {
    if (active.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: Container(
          height: 90,
          width: double.infinity,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Theme.of(context).colorScheme.outline.withOpacity(0.25),
              width: 1.5,
            ),
          ),
          child: Center(
            child: Text(
              'Pulsa + para añadir estadísticas',
              style: TextStyle(
                fontSize: 13,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.35),
              ),
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 0.95,
        ),
        itemCount: active.length,
        itemBuilder: (context, index) => _buildActiveCard(context, active[index]),
      ),
    );
  }

  Widget _buildActiveCard(BuildContext context, HomeWidget w) {
    final hasBestMarkConfig = w.id == 'kpi_best_mark';
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      child: Stack(
        key: ValueKey(w.id),
        children: [
          _buildCardBase(context, w, dimmed: false),
          // Red minus button
          Positioned(
            top: 8,
            left: 8,
            child: GestureDetector(
              onTap: () => widget.controller.toggleWidgetVisibility(w.id),
              child: Container(
                width: 26,
                height: 26,
                decoration: const BoxDecoration(
                  color: Color(0xFFFF3B30),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.remove_rounded, color: Colors.white, size: 16),
              ),
            ),
          ),
          // Tune button for best mark distance
          if (hasBestMarkConfig)
            Positioned(
              top: 8,
              right: 8,
              child: GestureDetector(
                onTap: () => _showBestMarkPicker(context, w),
                child: Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.08),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.tune_rounded,
                    size: 14,
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ── Available section ─────────────────────────────────────────────────────

  Widget _buildAvailableSection(BuildContext context, List<HomeWidget> available, int activeCount) {
    if (available.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
        child: Text(
          'Todas las estadísticas están activas.',
          style: TextStyle(
            fontSize: 13,
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.35),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 0.95,
        ),
        itemCount: available.length,
        itemBuilder: (context, index) =>
            _buildAvailableCard(context, available[index], activeCount),
      ),
    );
  }

  Widget _buildAvailableCard(BuildContext context, HomeWidget w, int activeCount) {
    final isFull = activeCount >= _maxActive;
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      child: Stack(
        key: ValueKey(w.id),
        children: [
          _buildCardBase(context, w, dimmed: true),
          // Green plus button
          Positioned(
            top: 8,
            left: 8,
            child: GestureDetector(
              onTap: () {
                if (isFull) {
                  ModernSnackBar.showWarning(
                    context,
                    'Máximo $_maxActive estadísticas activas',
                  );
                } else {
                  widget.controller.toggleWidgetVisibility(w.id);
                }
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: isFull ? const Color(0xFF8E8E93) : const Color(0xFF34C759),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.add_rounded, color: Colors.white, size: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Card base ─────────────────────────────────────────────────────────────

  Widget _buildCardBase(BuildContext context, HomeWidget w, {required bool dimmed}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final iconColor = isDark ? AppColors.brandLight : AppColors.brand;
    final title = w.config['title'] as String? ?? w.type.displayName;

    return Opacity(
      opacity: dimmed ? 0.55 : 1.0,
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(18),
          boxShadow: isDark
              ? []
              : [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.07),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  ),
                ],
        ),
        padding: const EdgeInsets.fromLTRB(14, 42, 14, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 46,
              height: 46,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.brand.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(_iconForWidget(w.id), size: 22, color: iconColor),
            ),
            const Spacer(),
            Text(
              title,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurface,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 3),
            Text(
              '—',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.25),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Best mark distance picker (bottom sheet) ──────────────────────────────

  void _showBestMarkPicker(BuildContext context, HomeWidget w) {
    const distances = [100, 200, 400, 800, 1000, 1500, 5000, 10000];
    final selected = (w.config['bestMarkDistanceM'] as num?)?.toInt() ?? 400;

    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          int currentSelected = selected;
          return Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 36),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Distancia para mejor marca',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: distances.map((d) {
                    final isSel = d == currentSelected;
                    final label = d >= 1000 ? '${d ~/ 1000}k' : '${d}m';
                    return GestureDetector(
                      onTap: () {
                        setModalState(() => currentSelected = d);
                        widget.controller.updateWidgetConfig(
                          w.id,
                          {'bestMarkDistanceM': d},
                        );
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: isSel
                              ? AppColors.brand
                              : Theme.of(context).colorScheme.onSurface.withOpacity(0.07),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          label,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: isSel
                                ? Colors.white
                                : Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ── Icon mapping ──────────────────────────────────────────────────────────

  IconData _iconForWidget(String widgetId) {
    switch (widgetId) {
      case 'pace_progression':     return Icons.show_chart_rounded;
      case 'distance_progression': return Icons.bar_chart_rounded;
      case 'consistency_tracker':  return Icons.local_fire_department_rounded;
      case 'tags_distribution':    return Icons.donut_small_rounded;
      case 'load_chart':           return Icons.stacked_bar_chart_rounded;
      case 'rpe_trend':            return Icons.trending_up_rounded;
      case 'pattern_progress':     return Icons.track_changes_rounded;
      case 'recent_workouts':      return Icons.history_rounded;
      case 'kpi_total_km':         return Icons.directions_run_rounded;
      case 'kpi_avg_pace':         return Icons.speed_rounded;
      case 'kpi_sessions':         return Icons.fitness_center_rounded;
      case 'kpi_avg_rpe':          return Icons.favorite_rounded;
      case 'kpi_best_mark':        return Icons.emoji_events_rounded;
      case 'kpi_weekly_km':        return Icons.calendar_today_rounded;
      case 'kpi_streak':           return Icons.local_fire_department_rounded;
      case 'kpi_total_series':     return Icons.repeat_rounded;
      default:                     return Icons.widgets_rounded;
    }
  }

  // ── Reset dialog ──────────────────────────────────────────────────────────

  Future<void> _confirmReset(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Restablecer diseño?'),
        content: const Text('Esto volverá a la configuración original.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sí, restablecer', style: TextStyle(color: AppColors.rpeMax)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await widget.controller.resetToDefault();
    }
  }
}
