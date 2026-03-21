import 'package:flutter/material.dart';
import 'package:running_laps/config/app_theme.dart';
import 'package:running_laps/core/theme/app_colors.dart';
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
            color: Colors.black.withOpacity(0.08),
            offset: const Offset(0, 4),
            blurRadius: 20,
          ),
          BoxShadow(
            color: Tema.brandPurple.withOpacity(0.05),
            offset: const Offset(0, 2),
            blurRadius: 8,
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
              return isSameDay(widget.selectedDay, day) == true;
            },
            onDaySelected: (selectedDay, focusedDay) {
              if (!isSameDay(widget.selectedDay, selectedDay)) {
                widget.onDaySelected(selectedDay);
                setState(() {
                  _focusedDay = focusedDay;
                });
              } else {
                widget.onDaySelected(selectedDay);
              }
            },
            onFormatChanged: (format) {
               setState(() {
                 _calendarFormat = format;
               });
            },
            onPageChanged: (focusedDay) {
              setState(() {
                _focusedDay = focusedDay;
              });
            },
            
            eventLoader: (day) {
               final normalized = DateTime(day.year, day.month, day.day);
               return widget.events[normalized] ?? [];
            },

            // ESTILOS PREMIUM
            headerStyle: HeaderStyle(
              formatButtonVisible: false,
              titleCentered: true,
              titleTextStyle: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: Theme.of(context).brightness == Brightness.dark ? AppColors.brandPurpleLight : Tema.brandPurple,
                letterSpacing: 0.3,
              ),
              leftChevronIcon: Icon(Icons.chevron_left, color: Theme.of(context).brightness == Brightness.dark ? AppColors.brandPurpleLight : Tema.brandPurple, size: 28),
              rightChevronIcon: Icon(Icons.chevron_right, color: Theme.of(context).brightness == Brightness.dark ? AppColors.brandPurpleLight : Tema.brandPurple, size: 28),
              headerPadding: const EdgeInsets.symmetric(vertical: 16),
            ),
            
            calendarStyle: CalendarStyle(
              // Estilo del día actual
              todayDecoration: BoxDecoration(
                border: Border.all(color: Tema.brandPurple, width: 2),
                shape: BoxShape.circle,
              ),
              todayTextStyle: TextStyle(
                color: Theme.of(context).brightness == Brightness.dark ? AppColors.brandPurpleLight : Tema.brandPurple,
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
              
              // Estilo del día seleccionado
              selectedDecoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Tema.brandPurple,
                    Tema.brandPurple.withOpacity(0.8),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Tema.brandPurple.withOpacity(0.4),
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
              
              // Estilo de días normales
              defaultTextStyle: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
              
              // Espaciado de celdas
              cellMargin: const EdgeInsets.all(6),
              
              // Removemos la decoración de marcadores por defecto
              markerDecoration: const BoxDecoration(
                color: Colors.transparent,
              ),
              markersMaxCount: 3, // Permitir hasta 3 marcadores
            ),
            
            calendarBuilders: CalendarBuilders(
               markerBuilder: (context, day, events) {
                 if (events.isEmpty) return null;
                 
                 // Recolectar todas las etiquetas únicas del día
                 final uniqueTags = _collectUniqueTags(events);
                 
                 return _buildTagMarkers(uniqueTags);
               },
            ),
          ),
          
          // Separador sutil
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Container(
              height: 1,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.transparent,
                    Colors.grey.shade200,
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          
          // Leyenda dinámica
          _buildDynamicLegend(),
        ],
      ),
    );
  }

  /// Recolecta todas las etiquetas únicas de los entrenamientos de un día
  List<String> _collectUniqueTags(List<Entrenamiento> events) {
    final Set<String> uniqueTags = {};
    
    for (var training in events) {
      if (training.tags != null && training.tags!.isNotEmpty) {
        uniqueTags.addAll(training.tags!);
      }
    }
    
    // Si no hay etiquetas, retornar lista con null para mostrar marcador gris
    if (uniqueTags.isEmpty) {
      return ['_no_tag_'];
    }
    
    return uniqueTags.toList();
  }

  /// Construye los marcadores de etiquetas (hasta 3 puntos de colores)
  Widget _buildTagMarkers(List<String> tags) {
    final int maxMarkers = 3;
    final List<Widget> markers = [];
    
    // Determinar cuántos marcadores mostrar
    final int displayCount = tags.length > maxMarkers ? maxMarkers - 1 : tags.length;
    
    // Crear marcadores de colores
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
                color: color.withOpacity(0.4),
                blurRadius: 2,
                offset: const Offset(0, 1),
              ),
            ],
          ),
        ),
      );
      
      // Añadir espaciado entre marcadores
      if (i < displayCount - 1) {
        markers.add(const SizedBox(width: 3));
      }
    }
    
    // Si hay más etiquetas, añadir indicador "+N"
    if (tags.length > maxMarkers) {
      markers.add(const SizedBox(width: 2));
      markers.add(
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
          decoration: BoxDecoration(
            color: Tema.brandPurple.withOpacity(0.15),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            '+${tags.length - displayCount}',
            style: TextStyle(
              fontSize: 8,
              fontWeight: FontWeight.bold,
              color: (Theme.of(context).brightness == Brightness.dark ? AppColors.brandPurpleLight : Tema.brandPurple).withOpacity(0.8),
            ),
          ),
        ),
      );
    }
    
    return Positioned(
      bottom: 2,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: markers,
      ),
    );
  }

  /// Obtiene las etiquetas activas en el mes actual
  Map<String, int> _getActiveTagsInMonth() {
    final Map<String, int> tagCounts = {};
    
    // Filtrar eventos del mes enfocado
    widget.events.forEach((date, trainings) {
      if (date.year == _focusedDay.year && date.month == _focusedDay.month) {
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

  /// Construye la leyenda dinámica mostrando las etiquetas activas
  Widget _buildDynamicLegend() {
    final activeTags = _getActiveTagsInMonth();
    
    // Si no hay etiquetas activas, mostrar mensaje simple
    if (activeTags.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 16, top: 4),
        child: Text(
          'Sin etiquetas este mes',
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade500,
            fontStyle: FontStyle.italic,
          ),
        ),
      );
    }
    
    // Ordenar etiquetas por frecuencia (más usadas primero)
    final sortedTags = activeTags.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    
    // Limitar a las 6 etiquetas más usadas
    final displayTags = sortedTags.take(6).toList();
    
    return Padding(
      padding: const EdgeInsets.only(left: 16, right: 16, bottom: 16, top: 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Título de la leyenda
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              'Etiquetas activas',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Colors.grey.shade600,
                letterSpacing: 0.5,
              ),
            ),
          ),
          
          // Etiquetas en grid compacto
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: displayTags.map((entry) {
              return _legendItem(
                widget.getTagColor(entry.key),
                entry.key,
                entry.value,
              );
            }).toList(),
          ),
          
          // Indicador si hay más etiquetas
          if (sortedTags.length > 6)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                '+${sortedTags.length - 6} más',
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.grey.shade400,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Item de leyenda con contador
  Widget _legendItem(Color color, String label, int count) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Punto de color con sombra
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.3),
                blurRadius: 3,
                offset: const Offset(0, 1),
              ),
            ],
          ),
        ),
        const SizedBox(width: 6),
        
        // Nombre de la etiqueta
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade700,
          ),
        ),
        
        // Contador
        const SizedBox(width: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
          decoration: BoxDecoration(
            color: color.withOpacity(0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            count.toString(),
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ),
      ],
    );
  }
}

