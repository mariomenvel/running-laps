import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:running_laps/app/tema.dart';
import 'package:running_laps/features/profile/views/avatar_editor_wrapper_view.dart';
import 'package:running_laps/features/profile/viewmodels/profile_controller.dart';
import 'package:running_laps/features/training/data/entrenamiento.dart';
import 'package:running_laps/features/training/views/training_start_view.dart';
import 'package:running_laps/features/profile/views/profile_menu_screen.dart';
import 'package:running_laps/features/home/views/home_view.dart';
import '../../training/data/serie.dart';
import '../../training/data/tag_model.dart';
import '../../training/data/tag_manager.dart';
import '../../training/widgets/tag_chip.dart';
import '../../training/widgets/tag_selector_sheet.dart';
import '../../../core/widgets/app_footer.dart';
import '../../../core/widgets/app_header.dart';
import 'package:intl/intl.dart';
import 'package:running_laps/core/services/pdf_generator_service.dart';
import 'package:printing/printing.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:running_laps/features/profile/views/widgets/history_filter_sheet.dart';
import 'package:running_laps/features/profile/views/widgets/history_calendar_widget.dart';
import 'package:running_laps/features/profile/views/analytics_screen.dart';
import 'package:universal_html/html.dart' as html;
import 'package:running_laps/core/widgets/modern_snackbar.dart';

class ProfileView extends StatefulWidget {
  const ProfileView({Key? key}) : super(key: key);

  @override
  _ProfileViewState createState() {
    return _ProfileViewState();
  }
}

class _ProfileViewState extends State<ProfileView> {
  // Colores de la vista (Actualizados para estética premium)
  static const Color _bgCustomGrey = Color(0xFFF4F6F8);
  static const Color _brandDark = Color(0xFF2C3E50);

  late final ProfileController _controller;
  
  // VIEW MODE: List vs Calendar
  bool _isCalendarView = false;
  DateTime? _selectedCalendarDate;

  @override
  void initState() {
    super.initState();
    _controller = ProfileController();
    _controller.loadTrainings();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgCustomGrey,
      body: SafeArea(
        child: Column(
          children: <Widget>[
            // 1. HEADER (Reutilizando AppHeader que ya tiene el gradiente)
            _buildHeader(),

            // 2. CONTENIDO PRINCIPAL
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                   // TÍTULO Y CONTROLES
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20.0, 24.0, 20.0, 10.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Historial',
                          style: TextStyle(
                            fontSize: 22, // Más grande
                            fontWeight: FontWeight.w800, // Más bold
                            color: Colors.black87,
                            letterSpacing: -0.5,
                          ),
                        ),
                        // Controles: View Toggle + Filter
                        Row(
                          children: [
                            // View Toggle
                            IconButton(
                              onPressed: () {
                                setState(() {
                                  _isCalendarView = !_isCalendarView;
                                  if (!_isCalendarView) {
                                    _selectedCalendarDate = null;
                                    _controller.setDateRange(null, null);
                                  }
                                });
                              },
                              icon: Icon(
                                _isCalendarView ? Icons.list_rounded : Icons.calendar_month_rounded,
                                color: Tema.brandPurple,
                              ),
                              tooltip: _isCalendarView ? 'Ver lista' : 'Ver calendario',
                            ),

                            // ANALYTICS BUTTON
                            IconButton(
                              onPressed: () {
                                Navigator.push(
                                  context, 
                                  MaterialPageRoute(
                                    builder: (_) => AnalyticsScreen(viewModel: _controller.analytics),
                                  ),
                                );
                              }, 
                              icon: const Icon(Icons.bar_chart_rounded, color: Tema.brandPurple),
                              tooltip: 'Ver estadísticas',
                            ),
                            
                            // Filter menu button
                             _buildFilterMenu(),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // CALENDAR WIDGET (Solo visible en modo calendario)
                  if (_isCalendarView)
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      height: _isCalendarView ? null : 0,
                      child: ValueListenableBuilder<List<Entrenamiento>>(
                        valueListenable: _controller.trainings, // Escuchamos cambios para actualizar puntos? 
                        // Mejor escuchar _allTrainings, pero get eventsByDay usa _allTrainings.
                        // Usaremos AnimatedBuilder para reconstruir si cargan datos
                        builder: (context, _, __) {
                           // Necesitamos reconstruir el calendario si cargan nuevos datos
                           return HistoryCalendarWidget(
                             events: _controller.eventsByDay,
                             selectedDay: _selectedCalendarDate,
                             getTagColor: _controller.getColorForTag, // PASAMOS EL PROVIDER
                             onDaySelected: (date) {
                               setState(() {
                                 _selectedCalendarDate = date;
                               });
                               // Filtrar lista por este día
                               _controller.setDateRange(date, date); 
                             },
                           );
                        },
                      ),
                    ),


                  // FILTROS ACTIVOS (CHIPS)
                  if (!_isCalendarView) 
                    _buildActiveFilters(), // Ocultar chips si estamos en calendario? O mostrarlos?
                  // Dejémoslos visibles si no son de fecha, o mostrarlos siempre para saber qué pasa.
                  // Si estamos en calendario, el filtro de fecha es implícito visualmente, pero los demás (tags) siguen aplicando.
                  // Vamos a mostrarlos siempre, pero quizas con padding ajustado.
                  if (_isCalendarView && _selectedCalendarDate != null)
                     Padding(
                       padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                       child: Row(
                         children: [
                           Text(
                             'Entrenos del ${_formatDateShort(_selectedCalendarDate!)}',
                             style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey),
                           ),
                           const Spacer(),
                           TextButton(
                             onPressed: () {
                               setState(() {
                                  _selectedCalendarDate = null;
                                  _controller.setDateRange(null, null);
                               });
                             }, 
                             child: const Text('Ver todos')
                           )
                         ],
                       ),
                     ),
                  
                  if (_isCalendarView && _selectedCalendarDate != null)
                    const Divider(height: 1),

                  /*
                  // BARRA DE BÚSQUEDA
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20.0, 0, 20.0, 16.0),
                    child: TextField(
                      decoration: InputDecoration(
                        hintText: 'Buscar por título...',
                        hintStyle: TextStyle(color: Colors.grey.shade500),
                        prefixIcon: Icon(Icons.search, color: Colors.grey.shade600),
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(color: Colors.grey.shade200),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(color: Tema.brandPurple, width: 2),
                        ),
                        contentPadding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onChanged: (value) => _controller.setSearchQuery(value),
                    ),
                  ),
                  */

                  // LISTA (scrollable)
                  Expanded(child: _buildTrainingList()),
                ],
              ),
            ),


            // 3. FOOTER (Fijo abajo)
            AppFooter(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (BuildContext context) {
                      return const TrainingStartView();
                    },
                  ),
                );
              },
              isLoading: false,
            ),
          ],
        ),
      ),
    );
  }

  // ============================
  // HEADER
  // ============================
  Widget _buildHeader() {
    return AppHeader(
      onTapLeft: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (BuildContext context) {
              return const HomeView();
            },
          ),
        );
      },
      onTapRight: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (BuildContext context) {
              return const ProfileMenuView();
            },
          ),
        );
      },
    );
  }

  // ============================
  // FILTER MENU BUTTON & CHIPS
  // ============================
  Widget _buildFilterMenu() {
    // 1. Botón Principal de Filtro (Abre el Sheet)
    return Padding(
      padding: const EdgeInsets.only(left: 8.0),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () {
            showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (context) => HistoryFilterSheet(controller: _controller),
            );
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade200),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.tune_rounded, size: 18, color: Tema.brandPurple),
                const SizedBox(width: 6),
                ValueListenableBuilder<int>( // Escuchar cambios en profile_controller para mostrar badge
                  valueListenable: ValueNotifier<int>(0), // TODO: Esto debería ser reactivo real, ver abajo
                  builder: (context, _, __) {
                    // Hack rápido: Usamos AnimatedBuilder para reconstruir cuando cambie ALGO en el controller
                    return AnimatedBuilder(
                      animation: Listenable.merge([
                        _controller.currentFilter,
                        _controller.searchQuery,
                        _controller.selectedTags,
                        _controller.filterStartDate,
                        _controller.filterEndDate,
                        _controller.filterMinDist,
                        _controller.filterMaxDist,
                        _controller.filterSeriesDistance,
                      ]),
                      builder: (context, _) {
                        final int count = _controller.activeFiltersCount;
                        if (count == 0) return const Text('Filtrar', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13));
                        
                        return Text(
                          'Filtros ($count)', 
                          style: const TextStyle(fontWeight: FontWeight.bold, color: Tema.brandPurple, fontSize: 13)
                        );
                      },
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Widget para mostrar los chips de filtros activos debajo del título
  Widget _buildActiveFilters() {
    return AnimatedBuilder(
      animation: Listenable.merge([
        _controller.currentFilter,
        _controller.searchQuery,
        _controller.selectedTags,
        _controller.filterStartDate,
        _controller.filterEndDate,
        _controller.filterMinDist,
        _controller.filterMaxDist,
        _controller.filterSeriesDistance,
      ]),
      builder: (context, _) {
        final List<Widget> chips = [];

        // 1. Rando Fechas
        if (_controller.filterStartDate.value != null || _controller.filterEndDate.value != null) {
            String label = 'Fechas';
            if (_controller.filterStartDate.value != null && _controller.filterEndDate.value != null) {
              label = '${DateFormat('dd/MM').format(_controller.filterStartDate.value!)} - ${DateFormat('dd/MM').format(_controller.filterEndDate.value!)}';
            } else if (_controller.filterStartDate.value != null) {
              label = 'Desde ${DateFormat('dd/MM').format(_controller.filterStartDate.value!)}';
            } else {
              label = 'Hasta ${DateFormat('dd/MM').format(_controller.filterEndDate.value!)}';
            }
            chips.add(_buildChip(label, () => _controller.setDateRange(null, null)));
        }

        // 2. Distancia
        if (_controller.filterMinDist.value != null || _controller.filterMaxDist.value != null) {
           String label = 'Distancia';
           if (_controller.filterMinDist.value != null && _controller.filterMaxDist.value != null) {
             label = '${(_controller.filterMinDist.value!/1000).toStringAsFixed(1)}-${(_controller.filterMaxDist.value!/1000).toStringAsFixed(1)} km';
           } else if (_controller.filterMinDist.value != null) {
             label = '> ${(_controller.filterMinDist.value!/1000).toStringAsFixed(1)} km';
           } else {
             label = '< ${(_controller.filterMaxDist.value!/1000).toStringAsFixed(1)} km';
           }
           chips.add(_buildChip(label, () => _controller.setDistanceRange(null, null)));
        }

        // 3. Series
        if (_controller.filterSeriesDistance.value != null) {
          chips.add(_buildChip('Series ${_controller.filterSeriesDistance.value}m', () => _controller.setSeriesDistanceFilter(null)));
        }
        
        // 4. Tags
        for (var tag in _controller.selectedTags.value) {
          chips.add(_buildChip('#$tag', () => _controller.toggleTagFilter(tag)));
        }

        if (chips.isEmpty) return const SizedBox.shrink();

        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ...chips,
              // Botón limpiar todo
              GestureDetector(
                onTap: _controller.clearAllFilters,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text('Borrar todo', style: TextStyle(fontSize: 11, color: Colors.red, fontWeight: FontWeight.bold)),
                ),
              )
            ],
          ),
        );
      },
    );
  }

  Widget _buildChip(String label, VoidCallback onRemove) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Tema.brandPurple.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Tema.brandPurple.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: Tema.brandPurple, fontWeight: FontWeight.w600),
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: onRemove,
            child: const Icon(Icons.close, size: 14, color: Tema.brandPurple),
          ),
        ],
      ),
    );
  }

  // ============================
  // LISTA DE ENTRENAMIENTOS
  // ============================
  Widget _buildTrainingList() {
    return ValueListenableBuilder<bool>(
      valueListenable: _controller.isLoading,
      builder: (BuildContext context, bool isLoading, Widget? child) {
        if (isLoading && _controller.trainings.value.isEmpty) {
          return const Center(
            child: CircularProgressIndicator(color: Tema.brandPurple),
          );
        }

        return ValueListenableBuilder<String?>(
          valueListenable: _controller.error,
          builder: (BuildContext context, String? error, Widget? child) {
            if (error != null) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: GestureDetector(
                    onTap: _controller.loadTrainings,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        Icon(Icons.error_outline, size: 48, color: Colors.red.shade300),
                        const SizedBox(height: 16),
                        Text(
                          error,
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey.shade700),
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                          onPressed: _controller.loadTrainings,
                          icon: const Icon(Icons.refresh, size: 18),
                          label: const Text('Reintentar'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Tema.brandPurple,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }

            return ValueListenableBuilder<List<Entrenamiento>>(
              valueListenable: _controller.trainings,
              builder:
                  (
                    BuildContext context,
                    List<Entrenamiento> trainings,
                    Widget? child,
                  ) {
                    if (trainings.isEmpty && !isLoading) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.directions_run, size: 64, color: Colors.grey.shade300),
                            const SizedBox(height: 16),
                            Text(
                              'Aún no hay entrenos.',
                              style: TextStyle(
                                color: Colors.grey.shade500,
                                fontSize: 16,
                                fontWeight: FontWeight.w500
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              '¡Sal y conquista tus metas!',
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    return ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
                      itemCount: trainings.length,
                      itemBuilder: (BuildContext context, int index) {
                        final Entrenamiento training = trainings[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 16.0),
                          child: TrainingCard(
                            training: training,
                            onUpdate: _controller.loadTrainings, // Recargar al actualizar
                          ),
                        );
                      },
                    );
                  },
            );
          },
        );
      },
    );
  }
  String _formatDateShort(DateTime date) {
    return '${date.day}/${date.month}';
  }
}

// ============================
// WIDGET: TARJETA ENTRENAMIENTO (REDISENADA)
// ============================
class TrainingCard extends StatefulWidget {
  final Entrenamiento training;
  final VoidCallback? onUpdate; // Callback para recargar

  const TrainingCard({
    Key? key,
    required this.training,
    this.onUpdate,
  }) : super(key: key);

  @override
  _TrainingCardState createState() {
    return _TrainingCardState();
  }
}

class _TrainingCardState extends State<TrainingCard> {
  bool _expanded = false;

  String _formatDate(DateTime date) {
    // Formato más amigable: "12 OCT, 2023"
    try {
      // Necesita inicialización de locale, que hacemos en main/home.
      // Si falla, fallback.
      return DateFormat('d MMM, y', 'es').format(date).toUpperCase();
    } catch (e) {
      final String day = date.day.toString().padLeft(2, '0');
      final String month = date.month.toString().padLeft(2, '0');
      final String year = date.year.toString();
      return '$day/$month/$year';
    }
  }

  String _formatSeconds(int totalSeconds) {
    if (totalSeconds < 60) {
      return '${totalSeconds}s';
    }
    final int minutes = totalSeconds ~/ 60;
    final int seconds = totalSeconds % 60;
    if (minutes > 60) {
       final int hours = minutes ~/ 60;
       final int mins = minutes % 60;
       return '${hours}h ${mins}m';
    }
    return '${minutes}m ${seconds.toString().padLeft(2, '0')}s';
  }

  @override
  Widget build(BuildContext context) {
    final double kmTotal = widget.training.distanciaTotalM() / 1000.0;
    final String distanciaTexto = kmTotal.toStringAsFixed(2);
    
    final String ritmoTexto = widget.training.ritmoMedioTexto();
    final String rpeTexto = widget.training.rpePromedio().toStringAsFixed(1);
    
    final String tiempoTexto = _formatSeconds(widget.training.tiempoTotalSec().round());

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20.0), // Bordes más redondeados
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            offset: const Offset(0, 4),
            blurRadius: 16,
          ),
           BoxShadow(
            color: Tema.brandPurple.withOpacity(0.03),
            offset: const Offset(0, 2),
            blurRadius: 4,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20.0),
        child: Column(
          children: <Widget>[
            // --- HEADER TARJETA ---
            _buildCardHeader(context),

            // --- ESTADÍSTICAS PRINCIPALES (GRID) ---
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 20.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                   _buildStatItem(Icons.straighten_rounded, distanciaTexto, 'km', Colors.blue.shade400),
                   Container(width: 1, height: 24, color: Colors.grey.shade200),
                   _buildStatItem(Icons.timer_outlined, tiempoTexto, '', Colors.orange.shade400),
                   Container(width: 1, height: 24, color: Colors.grey.shade200),
                   _buildStatItem(Icons.speed_rounded, ritmoTexto, '/km', Colors.green.shade400),
                   Container(width: 1, height: 24, color: Colors.grey.shade200),
                   _buildStatItem(Icons.bolt_rounded, rpeTexto, 'RPE', Colors.red.shade400),
                ],
              ),
            ),

            // --- SEPARADOR DISCRETO ---
            if (_expanded)
               Divider(height: 1, thickness: 1, color: Colors.grey.shade100),

            // --- DETALLES DESPLEGABLES ---
            AnimatedCrossFade(
              firstChild: const SizedBox.shrink(),
              secondChild: _buildExpandedContent(),
              crossFadeState: _expanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
              duration: const Duration(milliseconds: 300),
            ),
            
            // --- BOTÓN DESPLEGAR (Integrado visualmente) ---
             Material(
               color: Colors.transparent,
               child: InkWell(
                 onTap: () {
                   setState(() {
                     _expanded = !_expanded;
                   });
                 },
                 child: Container(
                   width: double.infinity,
                   padding: const EdgeInsets.symmetric(vertical: 12),
                   decoration: BoxDecoration(
                     color: Colors.grey.shade50,
                     border: Border(top: BorderSide(color: Colors.grey.shade100))
                   ),
                   child: Row(
                     mainAxisAlignment: MainAxisAlignment.center,
                     children: [
                       Text(
                         _expanded ? 'Ver menos detalles' : 'Ver ${widget.training.series.length} series',
                         style: TextStyle(
                           fontSize: 12,
                           fontWeight: FontWeight.w600,
                           color: Colors.grey.shade600,
                         ),
                       ),
                       const SizedBox(width: 6),
                       Icon(
                         _expanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                         size: 18,
                         color: Colors.grey.shade600,
                       ),
                     ],
                   ),
                 ),
               ),
             )
          ],
        ),
      ),
    );
  }

  Widget _buildCardHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 12, 10), // Padding ajustado
      decoration: const BoxDecoration(
        color: Colors.white, // Header blanco limpio
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
           Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Tema.brandPurple.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.directions_run_rounded, color: Tema.brandPurple, size: 24),
           ),
           const SizedBox(width: 14),
           Expanded(
             child: Column(
               crossAxisAlignment: CrossAxisAlignment.start,
               children: [
                 Text(
                   widget.training.titulo,
                   style: const TextStyle(
                     fontWeight: FontWeight.bold,
                     fontSize: 16,
                     color: Colors.black87,
                   ),
                   maxLines: 1,
                   overflow: TextOverflow.ellipsis,
                 ),
                 const SizedBox(height: 4),
                 Text(
                   _formatDate(widget.training.fecha),
                   style: TextStyle(
                     fontSize: 12,
                     fontWeight: FontWeight.w500,
                     color: Colors.grey.shade500,
                   ),
                 ),
                 // Mostrar etiquetas si existen
                 if (widget.training.tags != null && widget.training.tags!.isNotEmpty) ...[
                   const SizedBox(height: 8),
                   FutureBuilder<List<TrainingTag>>(
                     future: TagManager().getUserTags(),
                     builder: (context, snapshot) {
                       if (snapshot.hasError) return const SizedBox.shrink(); // Silenciar error en UI
                       if (!snapshot.hasData) return const SizedBox.shrink();
                       
                       final allTags = snapshot.data!;
                       final tagMap = {for (var t in allTags) t.name: t};
                       
                       return Wrap(
                         spacing: 6,
                         runSpacing: 4,
                         children: widget.training.tags!.map((tagName) {
                           final tag = tagMap[tagName];
                           if (tag == null) return const SizedBox.shrink();
                           
                           return TagChip(
                             tagName: tag.name,
                             color: tag.color,
                             small: true,
                           );
                         }).toList(),
                       );
                     },
                   ),
                 ],
               ],
             ),
           ),
           _buildPopupMenu(),
        ],
      ),
    );
  }

  Widget _buildStatItem(IconData icon, String value, String unit, Color iconColor) {
    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              value,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: Colors.black87,
                letterSpacing: -0.5,
              ),
            ),
            if (unit.isNotEmpty) ...[
              const SizedBox(width: 2),
               Padding(
                 padding: const EdgeInsets.only(bottom: 2.0),
                 child: Text(
                  unit,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade500,
                  ),
                             ),
               ),
            ]
          ],
        ),
        const SizedBox(height: 4),
        Icon(icon, size: 16, color: iconColor.withOpacity(0.8)),
      ],
    );
  }

  Widget _buildPopupMenu() {
    return Theme(
      data: Theme.of(context).copyWith(
        popupMenuTheme: PopupMenuThemeData(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 6,
          color: Colors.white,
          surfaceTintColor: Colors.white,
        ),
      ),
      child: PopupMenuButton<String>(
        icon: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(50),
          ),
          child: Icon(Icons.more_horiz_rounded, color: Colors.grey.shade400),
        ),
        splashRadius: 24,
        tooltip: 'Opciones',
        offset: const Offset(0, 40),
        onSelected: (val) async {
          if (val == 'tags') {
            // Verificar que tenemos ID
            if (widget.training.id == null) {
              ModernSnackBar.showError(
                context,
                'Error: No se puede editar este entrenamiento',
              );
              return;
            }

            // Abrir selector de etiquetas
            final result = await showModalBottomSheet<bool>(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (context) => Padding(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).viewInsets.bottom,
                ),
                child: TagSelectorSheet(
                  training: widget.training,
                  trainingId: widget.training.id!,
                ),
              ),
            );

              // Si se guardaron cambios, recargar
              if (result == true && mounted) {
                // Notificar actualización al padre
                widget.onUpdate?.call();
                
                // Opcional: Mostrar confirmación
                ModernSnackBar.showSuccess(
                  context,
                  'Etiquetas actualizadas',
                  duration: const Duration(seconds: 2),
                );
              }
          } else if (val == 'pdf') {
            // Mostrar loading
            ModernSnackBar.showInfo(
              context,
              'Generando PDF...',
              duration: const Duration(seconds: 2),
            );

            try {
              // Generar PDF
              final pdfBytes = await PdfGeneratorService.generateTrainingPdf(widget.training);
              
              // Descargar según plataforma
              final filename = '${widget.training.titulo.replaceAll(' ', '_')}_${widget.training.fecha.day}-${widget.training.fecha.month}-${widget.training.fecha.year}.pdf';
              
              if (kIsWeb) {
                // Web: usar blob download
                final blob = html.Blob([pdfBytes], 'application/pdf');
                final url = html.Url.createObjectUrlFromBlob(blob);
                final anchor = html.AnchorElement(href: url)
                  ..setAttribute('download', filename)
                  ..click();
                html.Url.revokeObjectUrl(url);
              } else {
                // Móvil/Desktop: usar printing
                await Printing.sharePdf(
                  bytes: pdfBytes,
                  filename: filename,
                );
              }

              if (mounted) {
                ModernSnackBar.showSuccess(
                  context,
                  'PDF descargado correctamente',
                );
              }
            } catch (e) {
              if (mounted) {
                ModernSnackBar.showError(
                  context,
                  'Error al generar PDF: $e',
                );
              }
            }
          }
        },
        itemBuilder: (context) => [
          PopupMenuItem(
            value: 'tags',
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Tema.brandPurple.withOpacity(0.1),
                    borderRadius: const BorderRadius.all(Radius.circular(8)),
                  ),
                  child: const Icon(Icons.label_rounded, size: 18, color: Tema.brandPurple),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Editar etiquetas',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors
.black87
                  ),
                ),
              ],
            ),
          ),
          const PopupMenuDivider(height: 1),
          PopupMenuItem(
            value: 'pdf',
             height: 48,
             padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0x1AFF0000),
                    borderRadius: const BorderRadius.all(Radius.circular(8)),
                  ),
                  child: const Icon(Icons.picture_as_pdf_rounded, size: 18, color: Colors.red),
                ),
                const SizedBox(width: 12),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                     Text(
                      'Descargar PDF',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87
                      ),
                    ),
                    Text(
                      'Guardar reporte',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExpandedContent() {
    return Container(
      color: Colors.grey.shade50,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Detalle de Series",
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: Colors.black54,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 12),
          // Lista de series
          ..._buildSeriesList(),
        ],
      ),
    );
  }

  List<Widget> _buildSeriesList() {
    final List<Widget> list = [];
    final series = widget.training.series;
    for (int i = 0; i < series.length; i++) {
      list.add(_buildSerieRow(i + 1, series[i]));
      
      // Mostrar descanso entre series si existe
      if (i < series.length - 1 && series[i].descansoSec > 0) {
        list.add(_buildRestRow(series[i].descansoSec));
      }
    }
    return list;
  }

  Widget _buildRestRow(int seconds) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.timer_off_outlined, size: 14, color: Colors.grey.shade400),
          const SizedBox(width: 4),
          Text(
            "Descanso: ${_formatSeconds(seconds)}",
            style: TextStyle(
              fontSize: 12, 
              color: Colors.grey.shade500, 
              fontStyle: FontStyle.italic
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSerieRow(int num, Serie serie) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        children: [
          // Index Badge
          Container(
            width: 24,
            height: 24,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Tema.brandPurple.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Text(
              num.toString(),
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Tema.brandPurple,
              ),
            ),
          ),
          const SizedBox(width: 12),
          
          // Data
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                 _buildSerieDetail('${serie.distanciaM}m', Icons.straighten, Colors.grey.shade800),
                 _buildSerieDetail(_formatSeconds(serie.tiempoSec.round()), Icons.timer_outlined, Colors.grey.shade800),
                 _buildSerieDetail(serie.ritmoTexto(), Icons.speed, Colors.grey.shade800),
                 _buildSerieDetail('RPE ${serie.rpe}', Icons.bolt, Colors.grey.shade600),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildSerieDetail(String text, IconData icon, Color color) {
    return Row(
      children: [
        // Opcional: Icon(icon, size: 12, color: Colors.grey.shade400),
        // SizedBox(width: 4),
        Text(
          text,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: color,
          ),
        ),
      ],
    );
  }
}
