import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:running_laps/core/theme/app_colors.dart';
import 'package:running_laps/core/widgets/standard_table_calendar.dart';

class PremiumDateRangePicker extends StatefulWidget {
  final DateTimeRange? initialDateRange;
  final DateTime firstDate;
  final DateTime lastDate;
  final ValueChanged<DateTimeRange> onRangeSelected;

  const PremiumDateRangePicker({
    super.key,
    this.initialDateRange,
    required this.firstDate,
    required this.lastDate,
    required this.onRangeSelected,
  });

  @override
  State<PremiumDateRangePicker> createState() => _PremiumDateRangePickerState();
}

class _PremiumDateRangePickerState extends State<PremiumDateRangePicker> {
  DateTime? _rangeStart;
  DateTime? _rangeEnd;
  late final ValueNotifier<DateTime> _focusedDay;

  @override
  void initState() {
    super.initState();
    if (widget.initialDateRange != null) {
      _rangeStart = widget.initialDateRange!.start;
      _rangeEnd = widget.initialDateRange!.end;
      _focusedDay = ValueNotifier(widget.initialDateRange!.start);
    } else {
      _focusedDay = ValueNotifier(DateTime.now());
    }
  }

  @override
  void dispose() {
    _focusedDay.dispose();
    super.dispose();
  }

  void _onRangeSelected(
      DateTime? start, DateTime? end, DateTime focusedDay) {
    setState(() {
      _rangeStart = start;
      _rangeEnd = end;
    });
    _focusedDay.value = focusedDay;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor =
        isDark ? AppColors.surfaceDark : AppColors.surfaceLight;
    final brandColor =
        isDark ? AppColors.brandPurpleLight : AppColors.brandPurple;

    return Container(
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius:
            const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // ── Header ────────────────────────────────────────────────
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: isDark
                      ? AppColors.borderDark
                      : AppColors.borderLight,
                ),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Selecciona rango',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: isDark
                              ? AppColors.textPrimaryDark
                              : AppColors.textPrimaryLight,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _getRangeText(),
                        style: TextStyle(
                          fontSize: 14,
                          color: brandColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                  style: IconButton.styleFrom(
                    backgroundColor: isDark
                        ? AppColors.surfaceVariantDark
                        : AppColors.surfaceVariantLight,
                    shape: const CircleBorder(),
                  ),
                ),
              ],
            ),
          ),

          // ── Calendar + Confirm button ──────────────────────────────
          Expanded(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                  child: ValueListenableBuilder<DateTime>(
                    valueListenable: _focusedDay,
                    builder: (context, focusedDay, _) {
                      return StandardTableCalendar<Object>(
                        firstDay: widget.firstDate,
                        lastDay: widget.lastDate,
                        focusedDay: focusedDay,
                        rangeStart: _rangeStart,
                        rangeEnd: _rangeEnd,
                        rangeSelectionMode: RangeSelectionMode.toggledOn,
                        startingDayOfWeek: StartingDayOfWeek.monday,
                        onRangeSelected: _onRangeSelected,
                        onPageChanged: (day) => _focusedDay.value = day,
                      );
                    },
                  ),
                ),

                const Spacer(),

                // ── Confirm button ─────────────────────────────────
                if (_rangeStart != null && _rangeEnd != null)
                  SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () {
                            final start = DateTime(_rangeStart!.year,
                                _rangeStart!.month, _rangeStart!.day);
                            final end = DateTime(_rangeEnd!.year,
                                _rangeEnd!.month, _rangeEnd!.day, 23, 59, 59);
                            widget.onRangeSelected(
                                DateTimeRange(start: start, end: end));
                            Navigator.pop(
                                context, DateTimeRange(start: start, end: end));
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.brandPurple,
                            foregroundColor: Colors.white,
                            padding:
                                const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16)),
                            elevation: 0,
                          ),
                          child: const Text('Aplicar Rango',
                              style: TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getRangeText() {
    if (_rangeStart == null) return 'Selecciona inicio';
    final startStr = DateFormat('d MMM', 'es').format(_rangeStart!);
    if (_rangeEnd == null) return '$startStr - ...';
    final endStr = DateFormat('d MMM', 'es').format(_rangeEnd!);
    return '$startStr - $endStr';
  }
}
