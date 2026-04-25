import 'package:flutter/material.dart';
import 'package:running_laps/core/utils/app_transitions.dart';
import 'package:intl/intl.dart';
import 'package:running_laps/config/app_theme.dart';
import 'package:running_laps/core/theme/app_colors.dart';
import 'package:running_laps/features/training/data/entrenamiento.dart';
import 'package:running_laps/features/training/data/serie.dart';
import 'package:running_laps/features/training/data/tag_model.dart';
import 'package:running_laps/features/training/data/tag_manager.dart';
import 'package:running_laps/features/training/widgets/tag_chip.dart';
import 'package:running_laps/features/training/widgets/tag_selector_sheet.dart';
import 'package:running_laps/core/widgets/modern_snackbar.dart';
import 'package:running_laps/core/services/pdf_generator_service.dart';
import 'package:printing/printing.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:universal_html/html.dart' as html;
import 'package:running_laps/features/history/views/training_detail_view.dart';
import 'package:running_laps/features/history/views/training_no_gps_detail_view.dart';

class PremiumTrainingCard extends StatefulWidget {
  final Entrenamiento training;
  final bool isSelected;
  final bool selectionMode;
  final ValueChanged<bool>? onSelectionChanged;
  final VoidCallback? onUpdate;

  const PremiumTrainingCard({
    Key? key,
    required this.training,
    this.isSelected = false,
    this.selectionMode = false,
    this.onSelectionChanged,
    this.onUpdate,
  }) : super(key: key);

  @override
  State<PremiumTrainingCard> createState() => _PremiumTrainingCardState();
}

class _PremiumTrainingCardState extends State<PremiumTrainingCard> {
  bool _expanded = false;

  String _formatDate(DateTime date) {
    try {
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

  void _handleTap() {
    if (widget.selectionMode) {
      widget.onSelectionChanged?.call(!widget.isSelected);
    } else {
      // Si no estamos en modo selección, nada especial por defecto.
      // Podríamos expandir/colapsar al tocar el cuerpo principal,
      // pero actualmente eso se hace con el botón inferior.
      // Opcional: Expandir al tap en el cuerpo
      setState(() {
        _expanded = !_expanded;
      });
    }
  }

  void _handleLongPress() {
    // Entrar en modo selección si no estamos ya
    if (!widget.selectionMode && widget.onSelectionChanged != null) {
      widget.onSelectionChanged?.call(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final double kmTotal = widget.training.distanciaTotalM() / 1000.0;
    final String distanciaTexto = kmTotal.toStringAsFixed(2);
    final String ritmoTexto = widget.training.ritmoMedioTexto();
    final String rpeTexto = widget.training.rpePromedio().toStringAsFixed(1);
    final String tiempoTexto = _formatSeconds(widget.training.tiempoTotalSec().round());

    // Animación de escala sutil al seleccionar
    return AnimatedScale(
      scale: widget.isSelected ? 0.98 : 1.0,
      duration: const Duration(milliseconds: 150),
      child: GestureDetector(
        onTap: _handleTap,
        onLongPress: _handleLongPress,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          decoration: BoxDecoration(
            color: widget.isSelected ? Tema.brandPurple.withOpacity(0.05) : Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(20.0),
            border: widget.isSelected 
                ? Border.all(color: Tema.brandPurple, width: 2)
                : Border.all(color: Colors.transparent, width: 2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                offset: const Offset(0, 4),
                blurRadius: 16,
              ),
              if (widget.isSelected)
                BoxShadow(
                  color: Tema.brandPurple.withOpacity(0.15),
                  offset: const Offset(0, 4),
                  blurRadius: 12,
                ),
            ],
          ),
          child: Column(
            children: [
              // --- HEADER TARJETA ---
              _buildCardHeader(context),

              // --- ESTADÍSTICAS PRINCIPALES (GRID) ---
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 20.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                     _buildStatItem(Icons.straighten_rounded, distanciaTexto, 'km', Colors.blue.shade400),
                     Container(width: 1, height: 24, color: Theme.of(context).colorScheme.outline.withOpacity(0.3)),
                     _buildStatItem(Icons.timer_outlined, tiempoTexto, '', Colors.orange.shade400),
                     Container(width: 1, height: 24, color: Theme.of(context).colorScheme.outline.withOpacity(0.3)),
                     _buildStatItem(Icons.speed_rounded, ritmoTexto, '/km', Colors.green.shade400),
                     Container(width: 1, height: 24, color: Theme.of(context).colorScheme.outline.withOpacity(0.3)),
                     _buildStatItem(Icons.bolt_rounded, rpeTexto, 'RPE', Colors.red.shade400),
                  ],
                ),
              ),

              // --- SEPARADOR DISCRETO ---
              if (_expanded)
                 Divider(height: 1, thickness: 1, color: Theme.of(context).colorScheme.outline.withOpacity(0.15)),

              // --- DETALLES DESPLEGABLES ---
              AnimatedCrossFade(
                firstChild: const SizedBox.shrink(),
                secondChild: _buildExpandedContent(),
                crossFadeState: _expanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
                duration: const Duration(milliseconds: 300),
              ),
              
              // --- BOTÓN DESPLEGAR (Integrado visualmente) ---
              // En modo selección, este botón también activa la selección para evitar conflictos
               Material(
                 color: Colors.transparent,
                 child: InkWell(
                   onTap: () {
                     if (widget.selectionMode) {
                       _handleTap();
                     } else {
                       setState(() {
                         _expanded = !_expanded;
                       });
                     }
                   },
                   borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
                   child: Container(
                     width: double.infinity,
                     padding: const EdgeInsets.symmetric(vertical: 12),
                     decoration: BoxDecoration(
                       color: Theme.of(context).colorScheme.onSurface.withOpacity(0.03),
                       border: Border(top: BorderSide(color: Theme.of(context).colorScheme.outline.withOpacity(0.15))),
                       borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
                     ),
                     child: Row(
                       mainAxisAlignment: MainAxisAlignment.center,
                       children: [
                         Text(
                           _expanded ? 'Ver menos detalles' : 'Ver ${widget.training.series.length} series',
                           style: TextStyle(
                             fontSize: 12,
                             fontWeight: FontWeight.w600,
                             color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                           ),
                         ),
                         const SizedBox(width: 6),
                         Icon(
                           _expanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                           size: 18,
                           color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                         ),
                       ],
                     ),
                   ),
                 ),
               )
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCardHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 12, 10),
      decoration: const BoxDecoration(
        color: Colors.transparent, // Transparente para heredar color de selección
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
           // CHECKBOX O ICONO SEGÚN MODO
           if (widget.selectionMode)
             Padding(
               padding: const EdgeInsets.only(right: 14, top: 2),
               child: _buildCheckbox(),
             )
           else
             Container(
              padding: const EdgeInsets.all(10),
              margin: const EdgeInsets.only(right: 14),
              decoration: BoxDecoration(
                color: Tema.brandPurple.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.directions_run_rounded, color: Theme.of(context).brightness == Brightness.dark ? AppColors.brandPurpleLight : Tema.brandPurple, size: 24),
             ),

           Expanded(
             child: Column(
               crossAxisAlignment: CrossAxisAlignment.start,
               children: [
                 Row(
                   children: [
                     Expanded(
                       child: Text(
                         widget.training.titulo,
                         style: TextStyle(
                           fontWeight: FontWeight.bold,
                           fontSize: 16,
                           color: Theme.of(context).colorScheme.onSurface,
                         ),
                         maxLines: 1,
                         overflow: TextOverflow.ellipsis,
                       ),
                     ),
                     if (widget.training.isManual) ...[
                       const SizedBox(width: 6),
                       Container(
                         padding: const EdgeInsets.symmetric(
                             horizontal: 8, vertical: 3),
                         decoration: BoxDecoration(
                           color: const Color(0xFF1E1530),
                           border: Border.all(
                               color: AppColors.brandPurple.withOpacity(0.6)),
                           borderRadius: BorderRadius.circular(6),
                         ),
                         child: Row(
                           mainAxisSize: MainAxisSize.min,
                           children: [
                             const Icon(Icons.edit_rounded,
                                 color: AppColors.brandPurple, size: 12),
                             const SizedBox(width: 3),
                             const Text(
                               'Manual',
                               style: TextStyle(
                                 fontSize: 11,
                                 fontWeight: FontWeight.w600,
                                 color: AppColors.brandPurpleLight,
                               ),
                             ),
                           ],
                         ),
                       ),
                     ],
                   ],
                 ),
                 const SizedBox(height: 4),
                 Text(
                   _formatDate(widget.training.fecha),
                   style: TextStyle(
                     fontSize: 12,
                     fontWeight: FontWeight.w500,
                     color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                   ),
                 ),
                 // Mostrar etiquetas si existen
                 if (widget.training.tags != null && widget.training.tags!.isNotEmpty) ...[
                   const SizedBox(height: 8),
                   FutureBuilder<List<TrainingTag>>(
                     future: TagManager().getUserTags(),
                     builder: (context, snapshot) {
                       if (snapshot.hasError) return const SizedBox.shrink();
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
           
           // Si estamos en modo selección, ocultamos el menú para simplificar
           if (!widget.selectionMode)
             _buildPopupMenu(),
        ],
      ),
    );
  }

  Widget _buildCheckbox() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        color: widget.isSelected ? Tema.brandPurple : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: widget.isSelected ? Tema.brandPurple : Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
          width: 2,
        ),
      ),
      child: widget.isSelected
          ? const Icon(Icons.check_rounded, color: Colors.white, size: 16)
          : null,
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
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: Theme.of(context).colorScheme.onSurface,
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
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
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
          color: Theme.of(context).colorScheme.surface,
          surfaceTintColor: Theme.of(context).colorScheme.surface,
        ),
      ),
      child: PopupMenuButton<String>(
        icon: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(50),
          ),
          child: Icon(Icons.more_horiz_rounded, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4)),
        ),
        splashRadius: 24,
        tooltip: 'Opciones',
        offset: const Offset(0, 40),
        onSelected: (val) async {
          if (val == 'tags') {
            if (widget.training.id == null) {
              ModernSnackBar.showError(
                context,
                'Error: No se puede editar este entrenamiento',
              );
              return;
            }

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

            if (result == true && mounted) {
              widget.onUpdate?.call();
              ModernSnackBar.showSuccess(
                context,
                'Etiquetas actualizadas',
                duration: const Duration(seconds: 2),
              );
            }
          } else if (val == 'pdf') {
            ModernSnackBar.showInfo(
              context,
              'Generando PDF...',
              duration: const Duration(seconds: 2),
            );

            try {
              final pdfBytes = await PdfGeneratorService.generateTrainingPdf(widget.training);
              
              final filename = '${widget.training.titulo.replaceAll(' ', '_')}_${widget.training.fecha.day}-${widget.training.fecha.month}-${widget.training.fecha.year}.pdf';
              
              if (kIsWeb) {
                final blob = html.Blob([pdfBytes], 'application/pdf');
                final url = html.Url.createObjectUrlFromBlob(blob);
                final anchor = html.AnchorElement(href: url)
                  ..setAttribute('download', filename)
                  ..click();
                html.Url.revokeObjectUrl(url);
              } else {
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
                  child: Icon(Icons.label_rounded, size: 18, color: Theme.of(context).brightness == Brightness.dark ? AppColors.brandPurpleLight : Tema.brandPurple),
                ),
                const SizedBox(width: 12),
                Text(
                  'Editar etiquetas',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurface,
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
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                     Text(
                      'Descargar PDF',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    Text(
                      'Guardar reporte',
                      style: TextStyle(
                        fontSize: 11,
                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
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
      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.02),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Detalle de Series",
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 12),
          // Lista de series
          ..._buildSeriesList(),
          
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              icon: const Icon(Icons.analytics_rounded, size: 20),
              label: Text(widget.training.gps ? "Ver Análisis y Mapa" : "Ver Análisis"),
              style: OutlinedButton.styleFrom(
                foregroundColor: Theme.of(context).brightness == Brightness.dark ? AppColors.brandPurpleLight : Tema.brandPurple,
                side: BorderSide(color: Tema.brandPurple.withOpacity(0.5)),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () {
                 if (widget.selectionMode) return;
                 Navigator.push(
                   context,
                   AppModalRoute(
                     page: widget.training.gps
                         ? TrainingDetailView(training: widget.training)
                         : TrainingNoGpsDetailView(training: widget.training),
                   ),
                 );
              },
            ),
          ),
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
          Icon(Icons.timer_off_outlined, size: 14, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4)),
          const SizedBox(width: 4),
          Text(
            "Descanso: ${_formatSeconds(seconds)}",
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
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
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).brightness == Brightness.dark
                    ? AppColors.brandPurpleLight
                    : Tema.brandPurple,
              ),
            ),
          ),
          const SizedBox(width: 12),
          
          // Data
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                 _buildSerieDetail('${serie.distanciaM}m', Icons.straighten, Theme.of(context).colorScheme.onSurface),
                 _buildSerieDetail(_formatSeconds(serie.tiempoSec.round()), Icons.timer_outlined, Theme.of(context).colorScheme.onSurface),
                 _buildSerieDetail(serie.ritmoTexto(), Icons.speed, Theme.of(context).colorScheme.onSurface),
                 _buildSerieDetail('RPE ${serie.rpe}', Icons.bolt, Theme.of(context).colorScheme.onSurface.withOpacity(0.6)),
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

