import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import '../../config/app_theme.dart';
import '../../core/theme/app_colors.dart';

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
  DateTime _focusedDay = DateTime.now();
  CalendarFormat _calendarFormat = CalendarFormat.month;

  @override
  void initState() {
    super.initState();
    if (widget.initialDateRange != null) {
      _rangeStart = widget.initialDateRange!.start;
      _rangeEnd = widget.initialDateRange!.end;
      _focusedDay = widget.initialDateRange!.start;
    }
  }

  void _onRangeSelected(DateTime? start, DateTime? end, DateTime focusedDay) {
    setState(() {
      _rangeStart = start;
      _rangeEnd = end;
      _focusedDay = focusedDay;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: Colors.grey.shade100)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Selecciona rango",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[800],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _getRangeText(),
                        style: TextStyle(
                          fontSize: 14,
                          color: Theme.of(context).brightness == Brightness.dark ? AppColors.brandPurpleLight : Tema.brandPurple,
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
                    backgroundColor: Colors.grey.shade100,
                    shape: const CircleBorder(),
                  ),
                ),
              ],
            ),
          ),

          // Calendar and Button Section
          Expanded(
            child: Column(
              children: [
                // Calendar Wrapper
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                  child: TableCalendar(
                    firstDay: widget.firstDate,
                    lastDay: widget.lastDate,
                    focusedDay: _focusedDay,
                    calendarFormat: _calendarFormat,
                    rangeSelectionMode: RangeSelectionMode.toggledOn,
                    startingDayOfWeek: StartingDayOfWeek.monday,
                    locale: 'es_ES',
                    
                    selectedDayPredicate: (day) => isSameDay(_rangeStart, day),
                    rangeStartDay: _rangeStart,
                    rangeEndDay: _rangeEnd,
                    
                    onRangeSelected: _onRangeSelected,
                    
                    onPageChanged: (focusedDay) {
                      _focusedDay = focusedDay;
                    },
                    
                    // ESTILOS
                    headerStyle: HeaderStyle(
                      formatButtonVisible: false,
                      titleCentered: true,
                      titleTextStyle: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: Theme.of(context).brightness == Brightness.dark ? AppColors.brandPurpleLight : Tema.brandPurple,
                      ),
                      leftChevronIcon: Icon(Icons.chevron_left, color: Theme.of(context).brightness == Brightness.dark ? AppColors.brandPurpleLight : Tema.brandPurple),
                      rightChevronIcon: Icon(Icons.chevron_right, color: Theme.of(context).brightness == Brightness.dark ? AppColors.brandPurpleLight : Tema.brandPurple),
                    ),

                    calendarStyle: CalendarStyle(
                      // Rango
                      rangeHighlightColor: Tema.brandPurple.withOpacity(0.2),
                      withinRangeDecoration: const BoxDecoration(
                        color: Colors.transparent, 
                        shape: BoxShape.circle,
                      ),
                      
                      // Inicio y Fin del Rango
                      rangeStartDecoration: const BoxDecoration(
                        color: Tema.brandPurple,
                        shape: BoxShape.circle,
                      ),
                      rangeEndDecoration: const BoxDecoration(
                        color: Tema.brandPurple,
                        shape: BoxShape.circle,
                      ),
                      
                      // Texto seleccionado
                      rangeStartTextStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      rangeEndTextStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      
                      // Día actual no seleccionado
                      todayDecoration: BoxDecoration(
                        border: Border.all(color: Tema.brandPurple, width: 2),
                        shape: BoxShape.circle,
                      ),
                      todayTextStyle: TextStyle(color: Theme.of(context).brightness == Brightness.dark ? AppColors.brandPurpleLight : Tema.brandPurple, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                
                // Spacer para empujar el botón al fondo
                const Spacer(),
                
                // Bottom Action
                if (_rangeStart != null && _rangeEnd != null)
                  SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: SizedBox(
                         width: double.infinity,
                         child: ElevatedButton(
                           onPressed: () {
                             // Ajustar fin del día
                             final start = DateTime(_rangeStart!.year, _rangeStart!.month, _rangeStart!.day);
                             final end = DateTime(_rangeEnd!.year, _rangeEnd!.month, _rangeEnd!.day, 23, 59, 59);
                             
                             // Notificar y Cerrar
                             widget.onRangeSelected(DateTimeRange(start: start, end: end));
                             Navigator.pop(context, DateTimeRange(start: start, end: end));
                           },
                           style: ElevatedButton.styleFrom(
                             backgroundColor: Tema.brandPurple,
                             foregroundColor: Colors.white,
                             padding: const EdgeInsets.symmetric(vertical: 16),
                             shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                             elevation: 0,
                           ),
                           child: const Text("Aplicar Rango", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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
    if (_rangeStart == null) return "Selecciona inicio";
    final startStr = DateFormat('d MMM', 'es').format(_rangeStart!);
    if (_rangeEnd == null) return "$startStr - ...";
    final endStr = DateFormat('d MMM', 'es').format(_rangeEnd!);
    return "$startStr - $endStr";
  }
}
