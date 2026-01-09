import 'package:flutter/material.dart';
import 'package:running_laps/config/app_theme.dart';

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
          icon: const Icon(
            Icons.tune_rounded,
            color: Tema.brandPurple,
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
                color: Tema.brandPurple,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Tema.brandPurple.withOpacity(0.3),
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

