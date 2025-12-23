import 'package:flutter/material.dart';
import 'package:running_laps/app/tema.dart';
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
  _HistoryCalendarWidgetState createState() => _HistoryCalendarWidgetState();
}

class _HistoryCalendarWidgetState extends State<HistoryCalendarWidget> {
  late DateTime _focusedDay;
  CalendarFormat _calendarFormat = CalendarFormat.month;

  @override
  void initState() {
    super.initState();
    _focusedDay = widget.selectedDay ?? DateTime.now();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            offset: const Offset(0, 4),
            blurRadius: 16,
          ),
        ],
      ),
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TableCalendar<Entrenamiento>(
            firstDay: DateTime(2020),
            lastDay: DateTime.now().add(const Duration(days: 30)), 
            focusedDay: _focusedDay,
            calendarFormat: _calendarFormat,
            locale: 'es_ES',
            
            selectedDayPredicate: (day) {
              // Robust check: Ensure we never return null
              return isSameDay(widget.selectedDay, day) == true;
            },
            onDaySelected: (selectedDay, focusedDay) {
              if (!isSameDay(widget.selectedDay, selectedDay)) {
                widget.onDaySelected(selectedDay);
                setState(() {
                  _focusedDay = focusedDay;
                });
              } else {
                // Force update even if same day
                widget.onDaySelected(selectedDay);
              }
            },
            onFormatChanged: (format) {
               setState(() {
                 _calendarFormat = format;
               });
            },
            onPageChanged: (focusedDay) {
              _focusedDay = focusedDay;
            },
            
            eventLoader: (day) {
               final normalized = DateTime(day.year, day.month, day.day);
               return widget.events[normalized] ?? [];
            },

            // ESTILOS
            headerStyle: HeaderStyle(
              formatButtonVisible: false,
              titleCentered: true,
              titleTextStyle: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Tema.brandPurple,
              ),
              leftChevronIcon: const Icon(Icons.chevron_left, color: Tema.brandPurple),
              rightChevronIcon: const Icon(Icons.chevron_right, color: Tema.brandPurple),
            ),
            
            calendarStyle: CalendarStyle(
              todayDecoration: BoxDecoration(
                color: Tema.brandPurple.withOpacity(0.3),
                shape: BoxShape.circle,
              ),
              todayTextStyle: const TextStyle(color: Tema.brandPurple, fontWeight: FontWeight.bold),
              
              selectedDecoration: const BoxDecoration(
                color: Tema.brandPurple,
                shape: BoxShape.circle,
              ),
              
              markerDecoration: const BoxDecoration(
                color: Colors.orange, 
                shape: BoxShape.circle,
              ),
              markersMaxCount: 1, 
            ),
            
            calendarBuilders: CalendarBuilders(
               markerBuilder: (context, day, events) {
                 if (events.isEmpty) return null;
                 return Positioned(
                   bottom: 1,
                   child: Container(
                     width: 6,
                     height: 6,
                      decoration: BoxDecoration(
                        color: _getMarkerColor(events),
                        shape: BoxShape.circle,
                      ),
                    ),
                  );
               },
            ),
          ),
          _buildLegend(),
        ],
      ),
    );
  }

  Color _getMarkerColor(List<Entrenamiento> events) {
    if (events.isEmpty) return Colors.transparent;
    
    // Priorizamos el primer entreno y su primer tag
    final first = events.first;
    if (first.tags != null && first.tags!.isNotEmpty) {
       return widget.getTagColor(first.tags!.first);
    }
    return widget.getTagColor(null); // Color por defecto (gris)
  }

  Widget _buildLegend() {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _legendItem(widget.getTagColor(null), 'Sin etiqueta'),
          const SizedBox(width: 16),
          _legendItem(widget.getTagColor('Ejemplo'), 'Con etiqueta'),
        ],
      ),
    );
  }

  Widget _legendItem(Color color, String label) {
    return Row(
      children: [
        Container(
          width: 8, 
          height: 8, 
          decoration: BoxDecoration(color: color, shape: BoxShape.circle)
        ),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
      ],
    );
  }
}
