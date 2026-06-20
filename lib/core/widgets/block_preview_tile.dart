import 'package:flutter/material.dart';
import 'package:running_laps/core/theme/app_colors.dart';
import 'package:running_laps/core/widgets/rpe_badge.dart';
import 'package:running_laps/features/athlete/data/athlete_session_model.dart';

/// Variante visual de BlockPreviewTile.
enum BlockPreviewStyle {
  /// Una línea compacta de texto, sin card (Home,
  /// resumen de Calendario).
  compact,
  /// Card completa con franja de color y chips
  /// (detalle de sesión, selección).
  card,
}

/// Previsualización de solo lectura de un SessionBlock.
/// Unifica el formato de texto que antes estaba
/// duplicado (con pequeñas inconsistencias) en
/// home_view.dart, calendar_view.dart y
/// save_as_template_sheet.dart.
class BlockPreviewTile extends StatelessWidget {
  final SessionBlock block;
  final BlockPreviewStyle style;
  final int? index; // para numeración en estilo card
  final bool selected;
  final VoidCallback? onTap;

  const BlockPreviewTile({
    super.key,
    required this.block,
    this.style = BlockPreviewStyle.compact,
    this.index,
    this.selected = false,
    this.onTap,
  });

  /// Texto principal: "6 × 400 m", "45 min", "8.5 km"
  String get mainLabel {
    switch (block.type) {
      case SessionBlockType.series:
        final reps = block.reps ?? 1;
        final dist = block.distanceM ?? 0;
        return reps > 1 ? '$reps × $dist m' : '$dist m';
      case SessionBlockType.continuousTime:
        return '${block.durationMinutes ?? 0} min';
      case SessionBlockType.continuousDistance:
        final m = block.distanceM ?? 0;
        return m >= 1000
            ? '${(m / 1000).toStringAsFixed(1)} km'
            : '$m m';
    }
  }

  Color get _accentColor {
    if (block.targetZone != null) {
      switch (block.targetZone!) {
        case 1: return const Color(0xFF639922);
        case 2: return const Color(0xFF378ADD);
        case 3: return const Color(0xFFEF9F27);
        case 4: return const Color(0xFFD85A30);
        case 5: return const Color(0xFFE24B4A);
      }
    }
    return const Color(0xFF888780);
  }

  @override
  Widget build(BuildContext context) {
    switch (style) {
      case BlockPreviewStyle.compact:
        return _buildCompact(context);
      case BlockPreviewStyle.card:
        return _buildCard(context);
    }
  }

  Widget _buildCompact(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 6, right: 6),
            width: 4, height: 4,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _accentColor,
            ),
          ),
          Expanded(
            child: Text(
              mainLabel,
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary(context),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        decoration: BoxDecoration(
          color: AppColors.surface2Of(context),
          borderRadius: BorderRadius.circular(10),
          border: Border(
            left: BorderSide(color: _accentColor, width: 3),
          ),
        ),
        padding: const EdgeInsets.symmetric(
            horizontal: 12, vertical: 9),
        child: Row(
          children: [
            if (index != null) ...[
              Text('${index! + 1}',
                style: TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w700,
                  color: selected
                      ? AppColors.brand
                      : AppColors.textSecondary(context))),
              const SizedBox(width: 10),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(mainLabel,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: selected
                          ? FontWeight.w600 : FontWeight.w500,
                      color: AppColors.textPrimary(context))),
                  if (block.targetRpe != null ||
                      block.targetZone != null) ...[
                    const SizedBox(height: 4),
                    Wrap(spacing: 6, children: [
                      if (block.targetRpe != null)
                        RpeBadge(rpe: block.targetRpe!),
                      if (block.targetZone != null)
                        _ZoneChip(zone: block.targetZone!),
                    ]),
                  ],
                ],
              ),
            ),
            if (selected)
              const Icon(Icons.check_circle,
                color: AppColors.brand, size: 18),
          ],
        ),
      ),
    );
  }
}

class _ZoneChip extends StatelessWidget {
  final int zone;
  const _ZoneChip({required this.zone});

  Color get _color {
    switch (zone) {
      case 1: return const Color(0xFF639922);
      case 2: return const Color(0xFF378ADD);
      case 3: return const Color(0xFFEF9F27);
      case 4: return const Color(0xFFD85A30);
      case 5: return const Color(0xFFE24B4A);
      default: return const Color(0xFF888780);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text('Z$zone',
        style: TextStyle(fontSize: 12,
          fontWeight: FontWeight.w500, color: _color)),
    );
  }
}
