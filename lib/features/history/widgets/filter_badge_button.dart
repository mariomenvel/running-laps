import 'package:flutter/material.dart';
import 'package:running_laps/config/app_theme.dart';
import 'package:running_laps/core/theme/app_colors.dart';

/// Botón de filtros con badge mostrando número de filtros activos
class FilterBadgeButton extends StatelessWidget {
  final int activeFiltersCount;
  final VoidCallback onTap;

  const FilterBadgeButton({
    Key? key,
    required this.activeFiltersCount,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        // Botón principal
        IconButton(
          onPressed: onTap,
          icon: Icon(
            Icons.tune_rounded,
            color: Theme.of(context).brightness == Brightness.dark ? AppColors.brandLight : AppColors.brand,
          ),
          tooltip: 'Filtros avanzados',
        ),
        
        // Badge con contador (solo si hay filtros activos)
        if (activeFiltersCount > 0)
          Positioned(
            right: 6,
            top: 6,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: AppColors.brand,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.brand.withOpacity(0.3),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              constraints: const BoxConstraints(
                minWidth: 18,
                minHeight: 18,
              ),
              child: Center(
                child: Text(
                  activeFiltersCount > 9 ? '9+' : activeFiltersCount.toString(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

