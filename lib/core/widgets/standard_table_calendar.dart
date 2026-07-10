import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:running_laps/core/theme/app_colors.dart';

/// A standardized, brightness-aware [TableCalendar] wrapper.
///
/// Applies the app's brand palette for headers, selected days, today, and
/// range highlights automatically based on [Theme.of(context).brightness].
///
/// [CalendarFormat] is managed internally via [ValueNotifier] so callers
/// don't need to track it.
///
/// Supports both **single-day** and **range** selection modes by passing
/// [rangeStart] / [rangeEnd] and setting [rangeSelectionMode].
class StandardTableCalendar<T extends Object> extends StatefulWidget {
  /// The earliest navigable day. Defaults to 1 Jan 2020.
  final DateTime firstDay;

  /// The latest navigable day.
  final DateTime lastDay;

  /// The currently focused (displayed) day.
  final DateTime focusedDay;

  /// Selected day (single-selection). `null` → no selection highlighted.
  final DateTime? selectedDay;

  /// Range start day (range-selection mode).
  final DateTime? rangeStart;

  /// Range end day (range-selection mode).
  final DateTime? rangeEnd;

  /// Whether range selection is active. Defaults to [RangeSelectionMode.disabled].
  final RangeSelectionMode rangeSelectionMode;

  /// The day the week starts on. Defaults to [StartingDayOfWeek.monday].
  final StartingDayOfWeek startingDayOfWeek;

  /// Locale string passed to [TableCalendar]. Defaults to `'es_ES'`.
  final String locale;

  /// Returns the event list for [day]; drives dot markers.
  final List<T> Function(DateTime day)? eventLoader;

  /// Called when the user taps a day.
  final void Function(DateTime selectedDay, DateTime focusedDay)? onDaySelected;

  /// Called when the user picks a range.
  final void Function(DateTime? start, DateTime? end, DateTime focusedDay)?
      onRangeSelected;

  /// Called whenever the visible month/page changes.
  final void Function(DateTime focusedDay)? onPageChanged;

  /// Custom builders — pass [CalendarBuilders.markerBuilder] etc. here.
  final CalendarBuilders<T> calendarBuilders;

  StandardTableCalendar({
    super.key,
    DateTime? firstDay,
    required this.lastDay,
    required this.focusedDay,
    this.selectedDay,
    this.rangeStart,
    this.rangeEnd,
    this.rangeSelectionMode = RangeSelectionMode.disabled,
    this.startingDayOfWeek = StartingDayOfWeek.monday,
    this.locale = 'es_ES',
    this.eventLoader,
    this.onDaySelected,
    this.onRangeSelected,
    this.onPageChanged,
    CalendarBuilders<T>? calendarBuilders,
  })  : firstDay = firstDay ?? DateTime(2020),
        calendarBuilders = calendarBuilders ?? const CalendarBuilders();

  @override
  State<StandardTableCalendar<T>> createState() =>
      _StandardTableCalendarState<T>();
}

class _StandardTableCalendarState<T extends Object>
    extends State<StandardTableCalendar<T>> {
  late final ValueNotifier<CalendarFormat> _format;

  @override
  void initState() {
    super.initState();
    _format = ValueNotifier(CalendarFormat.month);
  }

  @override
  void dispose() {
    _format.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final brandColor =
        isDark ? AppColors.brandLight : AppColors.brand;

    return ValueListenableBuilder<CalendarFormat>(
      valueListenable: _format,
      builder: (context, fmt, _) => TableCalendar<T>(
        firstDay: widget.firstDay,
        lastDay: widget.lastDay,
        focusedDay: widget.focusedDay,
        calendarFormat: fmt,
        locale: widget.locale,
        startingDayOfWeek: widget.startingDayOfWeek,

        // ── Selection ────────────────────────────────────────────
        rangeSelectionMode: widget.rangeSelectionMode,
        rangeStartDay: widget.rangeStart,
        rangeEndDay: widget.rangeEnd,
        selectedDayPredicate: (day) =>
            widget.selectedDay != null &&
            isSameDay(widget.selectedDay, day),

        // ── Callbacks ────────────────────────────────────────────
        onDaySelected: widget.onDaySelected,
        onRangeSelected: widget.onRangeSelected,
        onFormatChanged: (f) => _format.value = f,
        onPageChanged: widget.onPageChanged,

        // ── Events ───────────────────────────────────────────────
        eventLoader: widget.eventLoader,

        // ── Custom builders ──────────────────────────────────────
        calendarBuilders: widget.calendarBuilders,

        // ── Header ───────────────────────────────────────────────
        headerStyle: HeaderStyle(
          formatButtonVisible: false,
          titleCentered: true,
          titleTextStyle: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: brandColor,
            letterSpacing: 0.3,
          ),
          leftChevronIcon: Icon(Icons.chevron_left, color: brandColor, size: 28),
          rightChevronIcon:
              Icon(Icons.chevron_right, color: brandColor, size: 28),
          headerPadding: const EdgeInsets.symmetric(vertical: 16),
        ),

        // ── Calendar style ───────────────────────────────────────
        calendarStyle: CalendarStyle(
          // Today
          todayDecoration: BoxDecoration(
            border: Border.all(color: brandColor, width: 2),
            shape: BoxShape.circle,
          ),
          todayTextStyle: TextStyle(
            color: brandColor,
            fontWeight: FontWeight.bold,
            fontSize: 15,
          ),

          // Selected
          selectedDecoration: BoxDecoration(
            color: AppColors.brand,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: AppColors.brand.withValues(alpha: 0.4),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          selectedTextStyle: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 15,
          ),

          // Range
          rangeHighlightColor: AppColors.brand.withValues(alpha: 0.2),
          rangeStartDecoration: const BoxDecoration(
            color: AppColors.brand,
            shape: BoxShape.circle,
          ),
          rangeEndDecoration: const BoxDecoration(
            color: AppColors.brand,
            shape: BoxShape.circle,
          ),
          rangeStartTextStyle: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
          rangeEndTextStyle: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
          withinRangeDecoration: const BoxDecoration(
            color: Colors.transparent,
            shape: BoxShape.circle,
          ),

          // Default day
          defaultTextStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),

          // Markers — callers provide their own [markerBuilder] via [calendarBuilders]
          markerDecoration: const BoxDecoration(color: Colors.transparent),
          markersMaxCount: 3,

          cellMargin: const EdgeInsets.all(6),
        ),
      ),
    );
  }
}
