import 'package:flutter/material.dart';
import 'package:running_laps/core/theme/app_colors.dart';
import 'package:running_laps/core/widgets/standard_table_calendar.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:running_laps/features/training/data/entrenamiento.dart';

class HistoryCalendarWidget extends StatefulWidget {
  final Map<DateTime, List<Entrenamiento>> events;
  final DateTime? selectedDay;
  final Function(DateTime) onDaySelected;
  final Color Function(String?) getTagColor;

  const HistoryCalendarWidget({
    Key? key,
    required this.events,
    required this.onDaySelected,
    required this.getTagColor,
    this.selectedDay,
  }) : super(key: key);

  @override
  State<HistoryCalendarWidget> createState() => _HistoryCalendarWidgetState();
}

class _HistoryCalendarWidgetState extends State<HistoryCalendarWidget> {
  late final ValueNotifier<DateTime> _focusedDay;

  @override
  void initState() {
    super.initState();
    _focusedDay = ValueNotifier(widget.selectedDay ?? DateTime.now());
  }

  @override
  void dispose() {
    _focusedDay.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.transparent
                : Colors.black.withValues(alpha: 0.08),
            offset: const Offset(0, 4),
            blurRadius: 20,
          ),
          BoxShadow(
            color: AppColors.brand.withValues(alpha: 0.05),
            offset: const Offset(0, 2),
            blurRadius: 8,
          ),
        ],
      ),
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: ValueListenableBuilder<DateTime>(
        valueListenable: _focusedDay,
        builder: (context, focusedDay, _) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Standardised calendar ─────────────────────────────
              StandardTableCalendar<Entrenamiento>(
                lastDay: DateTime.now().add(const Duration(days: 30)),
                focusedDay: focusedDay,
                selectedDay: widget.selectedDay,
                eventLoader: (day) {
                  final normalized = DateTime(day.year, day.month, day.day);
                  return widget.events[normalized] ?? [];
                },
                onDaySelected: (selectedDay, newFocused) {
                  _focusedDay.value = newFocused;
                  widget.onDaySelected(selectedDay);
                },
                onPageChanged: (newFocused) {
                  _focusedDay.value = newFocused;
                },
                calendarBuilders: CalendarBuilders<Entrenamiento>(
                  markerBuilder: (context, day, events) {
                    if (events.isEmpty) return null;
                    final uniqueTags = _collectUniqueTags(events);
                    return _buildTagMarkers(uniqueTags);
                  },
                ),
              ),

              // ── Separator ─────────────────────────────────────────
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: Container(
                  height: 1,
                  decoration: BoxDecoration(
                    color: AppColors.borderOf(context),
                  ),
                ),
              ),

              // ── Dynamic legend ────────────────────────────────────
              _buildDynamicLegend(focusedDay),
            ],
          );
        },
      ),
    );
  }

  /// Collects unique tags from a day's trainings.
  List<String> _collectUniqueTags(List<Entrenamiento> events) {
    final Set<String> uniqueTags = {};
    for (var training in events) {
      if (training.tags != null && training.tags!.isNotEmpty) {
        uniqueTags.addAll(training.tags!);
      }
    }
    return uniqueTags.isEmpty ? ['_no_tag_'] : uniqueTags.toList();
  }

  /// Coloured dot markers (up to 3) positioned below the day number.
  Widget _buildTagMarkers(List<String> tags) {
    const int maxMarkers = 3;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final brandColor =
        isDark ? AppColors.brandLight : AppColors.brand;
    final int displayCount =
        tags.length > maxMarkers ? maxMarkers - 1 : tags.length;
    final List<Widget> markers = [];

    for (int i = 0; i < displayCount; i++) {
      final tag = tags[i];
      final color = tag == '_no_tag_'
          ? widget.getTagColor(null)
          : widget.getTagColor(tag);

      markers.add(
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                  color: color.withValues(alpha: 0.4),
                  blurRadius: 2,
                  offset: const Offset(0, 1)),
            ],
          ),
        ),
      );
      if (i < displayCount - 1) markers.add(const SizedBox(width: 3));
    }

    if (tags.length > maxMarkers) {
      markers.add(const SizedBox(width: 2));
      markers.add(
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
          decoration: BoxDecoration(
            color: AppColors.brand.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            '+${tags.length - displayCount}',
            style: TextStyle(
              fontSize: 8,
              fontWeight: FontWeight.bold,
              color: brandColor.withValues(alpha: 0.8),
            ),
          ),
        ),
      );
    }

    return Positioned(
      bottom: 2,
      child: Row(mainAxisSize: MainAxisSize.min, children: markers),
    );
  }

  /// Returns count of each tag used in [month].
  Map<String, int> _getActiveTagsInMonth(DateTime month) {
    final Map<String, int> tagCounts = {};
    widget.events.forEach((date, trainings) {
      if (date.year == month.year && date.month == month.month) {
        for (var training in trainings) {
          if (training.tags != null) {
            for (var tag in training.tags!) {
              tagCounts[tag] = (tagCounts[tag] ?? 0) + 1;
            }
          }
        }
      }
    });
    return tagCounts;
  }

  Widget _buildDynamicLegend(DateTime focusedDay) {
    final activeTags = _getActiveTagsInMonth(focusedDay);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (activeTags.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 16, top: 4),
        child: Text(
          'Sin etiquetas este mes',
          style: TextStyle(
            fontSize: 12,
            color: isDark
                ? AppColors.textSecondaryDark
                : AppColors.textSecondaryLight,
            fontStyle: FontStyle.italic,
          ),
        ),
      );
    }

    final sortedTags = activeTags.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final displayTags = sortedTags.take(6).toList();

    return Padding(
      padding: const EdgeInsets.only(left: 16, right: 16, bottom: 16, top: 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              'Etiquetas activas',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: isDark
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondaryLight,
                letterSpacing: 0.5,
              ),
            ),
          ),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: displayTags.map((entry) {
              return _legendItem(
                  widget.getTagColor(entry.key), entry.key, entry.value);
            }).toList(),
          ),
          if (sortedTags.length > 6)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                '+${sortedTags.length - 6} más',
                style: TextStyle(
                  fontSize: 10,
                  color: isDark
                      ? AppColors.textTertiaryDark
                      : AppColors.textTertiaryLight,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _legendItem(Color color, String label, int count) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                  color: color.withValues(alpha: 0.3),
                  blurRadius: 3,
                  offset: const Offset(0, 1)),
            ],
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isDark
                ? AppColors.textPrimaryDark
                : AppColors.textPrimaryLight,
          ),
        ),
        const SizedBox(width: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            count.toString(),
            style:
                TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color),
          ),
        ),
      ],
    );
  }
}
