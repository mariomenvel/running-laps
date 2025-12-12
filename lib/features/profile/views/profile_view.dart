import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:running_laps/app/tema.dart';
import 'package:running_laps/features/profile/views/avatar_editor_wrapper_view.dart';
import 'package:running_laps/features/profile/viewmodels/profile_controller.dart';
import 'package:running_laps/features/training/data/entrenamiento.dart';
import 'package:running_laps/features/training/views/training_start_view.dart';
import 'package:running_laps/features/profile/views/profile_menu_view.dart';
import 'package:running_laps/features/home/views/home_view.dart';
import '../../training/data/serie.dart';
import '../../../core/widgets/app_footer.dart';
import '../../../core/widgets/app_header.dart';
import 'package:intl/intl.dart';
import 'package:running_laps/core/services/pdf_generator_service.dart';
import 'package:printing/printing.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:universal_html/html.dart' as html;

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
                   // TÍTULO CON ESTILO MEJORADO
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20.0, 24.0, 20.0, 10.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Historial de Entrenos',
                          style: TextStyle(
                            fontSize: 22, // Más grande
                            fontWeight: FontWeight.w800, // Más bold
                            color: Colors.black87,
                            letterSpacing: -0.5,
                          ),
                        ),
                        // Filter menu button
                         _buildFilterMenu(),
                      ],
                    ),
                  ),

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
  // FILTER MENU
  // ============================
  Widget _buildFilterMenu() {
    return ValueListenableBuilder<TrainingFilter>(
      valueListenable: _controller.currentFilter,
      builder: (context, currentFilter, child) {
        String filterLabel = _getFilterLabel(currentFilter);
        
        return Theme(
          data: Theme.of(context).copyWith(
            popupMenuTheme: PopupMenuThemeData(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 6,
              color: Colors.white,
              surfaceTintColor: Colors.white,
            ),
          ),
          child: PopupMenuButton<TrainingFilter>(
            tooltip: 'Filtrar historial',
            offset: const Offset(0, 40),
            onSelected: (filter) {
              _controller.setFilter(filter);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Tema.brandPurple.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    filterLabel,
                    style: const TextStyle(
                      color: Tema.brandPurple,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(
                    Icons.filter_list_rounded,
                    color: Tema.brandPurple,
                    size: 16,
                  ),
                ],
              ),
            ),
            itemBuilder: (context) => [
              _buildFilterMenuItem(TrainingFilter.all, 'Todos', Icons.list_rounded, currentFilter),
              const PopupMenuDivider(height: 1),
              _buildFilterMenuItem(TrainingFilter.last7Days, 'Últimos 7 días', Icons.calendar_today_rounded, currentFilter),
              _buildFilterMenuItem(TrainingFilter.last30Days, 'Últimos 30 días', Icons.calendar_month_rounded, currentFilter),
              _buildFilterMenuItem(TrainingFilter.thisMonth, 'Este mes', Icons.date_range_rounded, currentFilter),
              const PopupMenuDivider(height: 1),
              _buildFilterMenuItem(TrainingFilter.longRuns, 'Carreras largas (+10km)', Icons.directions_run_rounded, currentFilter),
              _buildFilterMenuItem(TrainingFilter.highIntensity, 'Alta intensidad (RPE>7)', Icons.local_fire_department_rounded, currentFilter),
            ],
          ),
        );
      },
    );
  }

  PopupMenuItem<TrainingFilter> _buildFilterMenuItem(
    TrainingFilter filter,
    String label,
    IconData icon,
    TrainingFilter currentFilter,
  ) {
    final bool isSelected = filter == currentFilter;
    
    return PopupMenuItem<TrainingFilter>(
      value: filter,
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: isSelected 
                  ? Tema.brandPurple.withOpacity(0.15)
                  : Colors.grey.withOpacity(0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              size: 16,
              color: isSelected ? Tema.brandPurple : Colors.grey.shade600,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? Tema.brandPurple : Colors.black87,
              ),
            ),
          ),
          if (isSelected)
            const Icon(
              Icons.check_circle_rounded,
              size: 18,
              color: Tema.brandPurple,
            ),
        ],
      ),
    );
  }

  String _getFilterLabel(TrainingFilter filter) {
    switch (filter) {
      case TrainingFilter.all:
        return 'Todos';
      case TrainingFilter.last7Days:
        return '7 días';
      case TrainingFilter.last30Days:
        return '30 días';
      case TrainingFilter.thisMonth:
        return 'Este mes';
      case TrainingFilter.longRuns:
        return 'Largos';
      case TrainingFilter.highIntensity:
        return 'Intensos';
    }
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
}

// ============================
// WIDGET: TARJETA ENTRENAMIENTO (REDISENADA)
// ============================
class TrainingCard extends StatefulWidget {
  final Entrenamiento training;

  const TrainingCard({
    Key? key,
    required this.training,
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
          if (val == 'pdf') {
            // Mostrar loading
            ScaffoldMessenger.of(context).showSnackBar(
               const SnackBar(
                content: Row(
                  children: [
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(width: 12),
                    Text('Generando PDF...', style: TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
                behavior: SnackBarBehavior.floating,
                backgroundColor: Tema.brandPurple,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.all(Radius.circular(12)),
                ),
                margin: EdgeInsets.all(16),
                duration: Duration(seconds: 2),
               )
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
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Row(
                      children: [
                        Icon(Icons.check_circle, color: Colors.white),
                        SizedBox(width: 12),
                        Text('PDF descargado correctamente', style: TextStyle(fontWeight: FontWeight.bold)),
                      ],
                    ),
                    behavior: SnackBarBehavior.floating,
                    backgroundColor: Colors.green,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.all(Radius.circular(12)),
                    ),
                    margin: EdgeInsets.all(16),
                  )
                );
              }
            } catch (e) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Row(
                      children: [
                        const Icon(Icons.error_outline, color: Colors.white),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text('Error al generar PDF: $e', style: const TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                    behavior: SnackBarBehavior.floating,
                    backgroundColor: Colors.red,
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.all(Radius.circular(12)),
                    ),
                    margin: const EdgeInsets.all(16),
                  )
                );
              }
            }
          }
        },
        itemBuilder: (context) => [
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
          ...widget.training.series.asMap().entries.map((entry) {
             return _buildSerieRow(entry.key + 1, entry.value);
          }).toList(),
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
                 _buildSerieDetail(serie.ritmoTexto(), Icons.speed, Colors.grey.shade800),
                 _buildSerieDetail('RPE ${serie.rpe}', Icons.bolt, Colors.grey.shade600),
                 _buildSerieDetail('${serie.descansoSec}s', Icons.timer_off_outlined, Colors.grey.shade500),
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
