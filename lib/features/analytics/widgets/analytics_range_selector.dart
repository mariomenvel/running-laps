import 'package:flutter/material.dart';
import 'package:running_laps/features/analytics/viewmodels/analytics_hub_controller.dart';
import 'package:running_laps/config/app_theme.dart';
import 'package:running_laps/core/widgets/premium_date_range_picker.dart';
import 'package:running_laps/core/theme/app_colors.dart';
// For BackdropFilter

class AnalyticsRangeSelector extends StatelessWidget {
  final AnalyticsHubController controller;

  const AnalyticsRangeSelector({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AnalyticsTimeRange>(
      valueListenable: controller.selectedRange,
      builder: (context, currentRange, text) {
        String label = _getLabel(currentRange);
        if (currentRange == AnalyticsTimeRange.custom && controller.customDateRange.value != null) {
          final start = controller.customDateRange.value!.start;
          final end = controller.customDateRange.value!.end;
          label = "${start.day}/${start.month} - ${end.day}/${end.month}";
        }

        return GestureDetector(
          onTap: () => _showPremiumRangePicker(context),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.brand,
              borderRadius: BorderRadius.circular(30),
              boxShadow: [
                 BoxShadow(
                   color: AppColors.brand.withValues(alpha: 0.4),
                   blurRadius: 10,
                   offset: const Offset(0, 4),
                 ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.calendar_month_rounded, size: 16, color: Colors.white),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(width: 6),
                const Icon(Icons.keyboard_arrow_down_rounded, size: 20, color: Colors.white70),
              ],
            ),
          ),
        );
      },
    );
  }

  String _getLabel(AnalyticsTimeRange range) {
    switch (range) {
      case AnalyticsTimeRange.week:
        return '7 Días';
      case AnalyticsTimeRange.month:
        return '30 Días';
      case AnalyticsTimeRange.threeMonths:
        return '3 Meses';
      case AnalyticsTimeRange.year:
        return 'Este Año';
      case AnalyticsTimeRange.custom:
        return 'Personalizado';
    }
  }

  void _showPremiumRangePicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(25)),
          boxShadow: [
            BoxShadow(
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.transparent
                  : Colors.black.withValues(alpha: 0.08),
              blurRadius: 20,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
             // Handle bar
             Container(
               width: 40,
               height: 4,
               margin: const EdgeInsets.only(bottom: 20),
               decoration: BoxDecoration(
                 color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.2),
                 borderRadius: BorderRadius.circular(2),
               ),
             ),

             Text(
               "Seleccionar Periodo",
               style: TextStyle(
                 fontSize: 20,
                 fontWeight: FontWeight.w600,
                 color: Theme.of(context).colorScheme.onSurface,
               ),
             ),
             const SizedBox(height: 24),
             
             _buildPremiumOption(context, AnalyticsTimeRange.week, "Últimos 7 días", Icons.calendar_view_week_rounded),
             const SizedBox(height: 12),
             _buildPremiumOption(context, AnalyticsTimeRange.month, "Últimos 30 días", Icons.calendar_view_month_rounded),
             const SizedBox(height: 12),
             _buildPremiumOption(context, AnalyticsTimeRange.threeMonths, "Últimos 3 meses", Icons.grid_view_rounded),
             const SizedBox(height: 12),
             _buildPremiumOption(context, AnalyticsTimeRange.year, "Último año", Icons.calendar_today_rounded),
             
             const Padding(
               padding: EdgeInsets.symmetric(vertical: 16.0),
               child: Divider(),
             ),
             
             ListTile(
               contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
               shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
               tileColor: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.04),
               leading: Container(
                 padding: const EdgeInsets.all(8),
                 decoration: BoxDecoration(
                   color: AppColors.rest.withValues(alpha: 0.1),
                   borderRadius: BorderRadius.circular(10),
                 ),
                 child: const Icon(Icons.date_range_rounded, color: AppColors.rest),
               ),
               title: const Text(
                 "Rango Personalizado",
                 style: TextStyle(fontWeight: FontWeight.w600),
               ),
               trailing: Icon(Icons.chevron_right, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5)),
               onTap: () async {
                 Navigator.pop(context);
                 final range = await showModalBottomSheet<DateTimeRange>(
                   context: context,
                   isScrollControlled: true,
                   backgroundColor: Colors.transparent,
                   builder: (context) => SizedBox(
                     height: MediaQuery.of(context).size.height * 0.75,
                     child: PremiumDateRangePicker(
                       firstDate: DateTime(2020),
                       lastDate: DateTime.now(),
                       initialDateRange: controller.customDateRange.value,
                       onRangeSelected: (range) {},
                     ),
                   ),
                 );
                 
                 if (range != null) {
                   controller.setRange(AnalyticsTimeRange.custom, custom: range);
                 }
               },
             ),
             
             const SizedBox(height: 20),
             SizedBox(
               width: double.infinity,
               child: TextButton(
                 onPressed: () => Navigator.pop(context),
                 style: TextButton.styleFrom(
                   padding: const EdgeInsets.symmetric(vertical: 16),
                   shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                   foregroundColor: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                 ),
                 child: const Text("Cancelar", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
               ),
             ),
          ],
        ),
      ),
    );
  }

  Widget _buildPremiumOption(BuildContext context, AnalyticsTimeRange range, String text, IconData icon) {
    return ValueListenableBuilder<AnalyticsTimeRange>(
      valueListenable: controller.selectedRange,
      builder: (context, selected, _) {
        final isSelected = selected == range;
        return InkWell(
          onTap: () {
            controller.setRange(range);
            Navigator.pop(context);
          },
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            decoration: BoxDecoration(
              color: isSelected ? AppColors.brand.withValues(alpha: 0.08) : Colors.transparent,
              borderRadius: BorderRadius.circular(16),
              border: isSelected ? Border.all(color: AppColors.brand, width: 1.5) : Border.all(color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  color: isSelected ? AppColors.brand : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                  size: 22,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    text,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                      color: isSelected ? AppColors.brand : Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ),
                if (isSelected)
                  Icon(Icons.check_circle_rounded, color: Theme.of(context).brightness == Brightness.dark ? AppColors.brandLight : AppColors.brand, size: 24),
              ],
            ),
          ),
        );
      },
    );
  }
}

