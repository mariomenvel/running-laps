import 'package:flutter/material.dart';
import 'package:running_laps/features/analytics/viewmodels/analytics_hub_controller.dart';
import 'package:running_laps/app/tema.dart';

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
          onTap: () => _showRangePicker(context),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Tema.brandPurple.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Tema.brandPurple.withOpacity(0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.calendar_today, size: 14, color: Tema.brandPurple),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: const TextStyle(
                    color: Tema.brandPurple,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.arrow_drop_down, size: 18, color: Tema.brandPurple),
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
        return '7 días';
      case AnalyticsTimeRange.month:
        return '30 días';
      case AnalyticsTimeRange.threeMonths:
        return '3 meses';
      case AnalyticsTimeRange.year:
        return 'Este año';
      case AnalyticsTimeRange.custom:
        return 'Personalizado';
    }
  }

  void _showRangePicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Seleccionar periodo",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            _buildOption(context, AnalyticsTimeRange.week, "Últimos 7 días"),
            _buildOption(context, AnalyticsTimeRange.month, "Últimos 30 días"),
            _buildOption(context, AnalyticsTimeRange.threeMonths, "Últimos 3 meses"),
            _buildOption(context, AnalyticsTimeRange.year, "Último año"),
            const Divider(height: 30),
            ListTile(
              leading: const Icon(Icons.date_range, color: Tema.brandPurple),
              title: const Text("Rango personalizado"),
              onTap: () async {
                Navigator.pop(context);
                final range = await showDateRangePicker(
                  context: context,
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now(),
                  builder: (context, child) {
                    return Theme(
                      data: Theme.of(context).copyWith(
                        colorScheme: const ColorScheme.light(
                          primary: Tema.brandPurple,
                        ),
                      ),
                      child: child!,
                    );
                  },
                );
                
                if (range != null) {
                  controller.setRange(AnalyticsTimeRange.custom, custom: range);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOption(BuildContext context, AnalyticsTimeRange range, String text) {
    final isSelected = controller.selectedRange.value == range;
    return ListTile(
      leading: Icon(
        isSelected ? Icons.check_circle : Icons.circle_outlined,
        color: isSelected ? Tema.brandPurple : Colors.grey,
      ),
      title: Text(
        text,
        style: TextStyle(
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          color: isSelected ? Tema.brandPurple : Colors.black87,
        ),
      ),
      onTap: () {
        controller.setRange(range);
        Navigator.pop(context);
      },
    );
  }
}
