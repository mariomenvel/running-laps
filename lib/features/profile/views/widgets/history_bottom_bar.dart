import 'package:flutter/material.dart';
import 'package:running_laps/app/tema.dart';

/// Bottom action bar contextual para History screen
/// 
/// Muestra botones según el estado:
/// - "Ver dashboards" cuando hay filtros activos
/// - "Comparar (N)" cuando hay entrenamientos seleccionados
class HistoryBottomBar extends StatelessWidget {
  final int selectedCount;
  final int filteredCount;
  final VoidCallback? onViewDashboards;
  final VoidCallback? onCompare;

  const HistoryBottomBar({
    Key? key,
    this.selectedCount = 0,
    required this.filteredCount,
    this.onViewDashboards,
    this.onCompare,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // No mostrar si no hay acciones disponibles
    if (onViewDashboards == null && onCompare == null) {
      return const SizedBox.shrink();
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Row(
            children: [
              // Botón "Ver dashboards" (si hay filtros activos)
              if (onViewDashboards != null && selectedCount == 0)
                Expanded(
                  child: _buildPrimaryButton(
                    icon: Icons.bar_chart_rounded,
                    label: 'Ver dashboards del filtro',
                    subtitle: '$filteredCount entrenos',
                    onTap: onViewDashboards!,
                  ),
                ),
              
              // Botón "Comparar" (si hay selección)
              if (onCompare != null && selectedCount > 0)
                Expanded(
                  child: _buildPrimaryButton(
                    icon: Icons.compare_arrows_rounded,
                    label: 'Comparar ($selectedCount)',
                    subtitle: 'Ver diferencias',
                    onTap: onCompare!,
                    color: Tema.brandPurple,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPrimaryButton({
    required IconData icon,
    required String label,
    required String subtitle,
    required VoidCallback onTap,
    Color? color,
  }) {
    final buttonColor = color ?? Tema.brandPurple;
    
    return Material(
      color: buttonColor,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: Colors.white, size: 24),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
