import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:running_laps/core/theme/app_colors.dart';
import 'package:running_laps/core/widgets/rpe_badge.dart';
import 'package:running_laps/features/training/data/entrenamiento.dart';
import 'package:running_laps/features/training/data/serie.dart';
import 'package:running_laps/features/training/widgets/tag_chip.dart';
import 'package:running_laps/features/training/widgets/tag_selector_sheet.dart';
import 'package:running_laps/core/widgets/modern_snackbar.dart';
import 'package:running_laps/core/services/pdf_generator_service.dart';
import 'package:printing/printing.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:universal_html/html.dart' as html;
import 'package:running_laps/core/widgets/main_shell.dart';

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
      return DateFormat('d MMM, y', 'es').format(date);
    } catch (_) {
      return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
    }
  }

  String _formatSeconds(int totalSeconds) {
    if (totalSeconds < 60) return '${totalSeconds}s';
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    if (minutes >= 60) {
      final hours = minutes ~/ 60;
      final mins = minutes % 60;
      return '${hours}h ${mins}m';
    }
    return '${minutes}m ${seconds.toString().padLeft(2, '0')}s';
  }

  void _handleTap() {
    if (widget.selectionMode) {
      widget.onSelectionChanged?.call(!widget.isSelected);
    } else {
      setState(() => _expanded = !_expanded);
    }
  }

  void _handleLongPress() {
    if (!widget.selectionMode) {
      widget.onSelectionChanged?.call(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final km = widget.training.distanciaTotalM() / 1000.0;
    final distText = km.toStringAsFixed(2);
    final ritmoText = widget.training.ritmoMedioTexto();
    final tiempoText =
        _formatSeconds(widget.training.tiempoTotalSec().round());

    return AnimatedScale(
      scale: widget.isSelected ? 0.98 : 1.0,
      duration: const Duration(milliseconds: 150),
      child: GestureDetector(
        onTap: _handleTap,
        onLongPress: _handleLongPress,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
          decoration: BoxDecoration(
            color: widget.isSelected
                ? AppColors.brand.withValues(alpha: 0.05)
                : AppColors.surfaceOf(context),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: widget.isSelected
                  ? AppColors.brand
                  : AppColors.borderOf(context),
              width: widget.isSelected ? 1.5 : 0.5,
            ),
          ),
          child: Column(
            children: [
              _buildCardHeader(context),
              _buildStatsRow(context, distText, tiempoText, ritmoText,
                  widget.training.rpePromedio()),
              AnimatedCrossFade(
                firstChild: const SizedBox.shrink(),
                secondChild: _buildExpandedContent(context),
                crossFadeState: _expanded
                    ? CrossFadeState.showSecond
                    : CrossFadeState.showFirst,
                duration: const Duration(milliseconds: 280),
              ),
              _buildFooter(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCardHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 8, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.selectionMode)
            Padding(
              padding: const EdgeInsets.only(right: 12, top: 2),
              child: _buildCheckbox(),
            )
          else
            Container(
              width: 40,
              height: 40,
              margin: const EdgeInsets.only(right: 12),
              decoration: BoxDecoration(
                color: AppColors.brand.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.directions_run_rounded,
                color: Theme.of(context).brightness == Brightness.dark
                    ? AppColors.brandLight
                    : AppColors.brand,
                size: 20,
              ),
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
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                          color: AppColors.textPrimary(context),
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
                          color: AppColors.brand.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                              color: AppColors.brand.withValues(alpha: 0.3)),
                        ),
                        child: Text(
                          'Manual',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w400,
                            color: Theme.of(context).brightness ==
                                    Brightness.dark
                                ? AppColors.brandLight
                                : AppColors.brand,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  _formatDate(widget.training.fecha),
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary(context),
                  ),
                ),
                if (widget.training.tags != null &&
                    widget.training.tags!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: widget.training.tags!
                        .map((name) => TagChip(tagName: name, small: true))
                        .toList(),
                  ),
                ],
              ],
            ),
          ),
          if (!widget.selectionMode) _buildPopupMenu(),
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
        color: widget.isSelected ? AppColors.brand : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: widget.isSelected
              ? AppColors.brand
              : AppColors.iconMutedOf(context),
          width: 2,
        ),
      ),
      child: widget.isSelected
          ? const Icon(Icons.check_rounded, color: Colors.white, size: 16)
          : null,
    );
  }

  Widget _buildStatsRow(BuildContext context, String dist, String tiempo,
      String ritmo, double rpe) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _StatChip(icon: Icons.straighten_rounded, value: dist, unit: 'km', color: AppColors.rest),
          _StatChip(icon: Icons.timer_outlined, value: tiempo, unit: '', color: AppColors.rpeMid),
          _StatChip(icon: Icons.speed_rounded, value: ritmo, unit: '/km', color: AppColors.rpeLow),
          RpeBadge(rpe: rpe, size: RpeBadgeSize.chip, showIcon: true),
        ],
      ),
    );
  }

  Widget _buildExpandedContent(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Divider(
          height: 1,
          thickness: 0.5,
          color: AppColors.borderOf(context),
          indent: 16,
          endIndent: 16,
        ),
        Container(
          margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.surface2Of(context),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'SERIES',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: AppColors.iconMutedOf(context),
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 10),
              ..._buildSeriesList(),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          child: OutlinedButton.icon(
            icon: const Icon(Icons.analytics_rounded, size: 18),
            label: Text(
                widget.training.gps ? 'Ver Análisis y Mapa' : 'Ver Análisis'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Theme.of(context).brightness == Brightness.dark
                  ? AppColors.brandLight
                  : AppColors.brand,
              side: BorderSide(color: AppColors.brand.withValues(alpha: 0.4)),
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () {
              if (widget.selectionMode) return;
              MainShell.shellKey.currentState?.navigateTo(5, params: widget.training);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildFooter(BuildContext context) {
    return GestureDetector(
      onTap: () {
        if (widget.selectionMode) {
          _handleTap();
        } else {
          setState(() => _expanded = !_expanded);
        }
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.surface2Of(context),
          borderRadius:
              const BorderRadius.vertical(bottom: Radius.circular(16)),
          border: Border(
            top: BorderSide(color: AppColors.borderOf(context), width: 0.5),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _expanded
                  ? 'Ver menos'
                  : 'Ver ${widget.training.series.length} series',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary(context),
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              _expanded
                  ? Icons.expand_less_rounded
                  : Icons.expand_more_rounded,
              size: 16,
              color: AppColors.iconMutedOf(context),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildSeriesList() {
    final list = <Widget>[];
    final series = widget.training.series;
    for (int i = 0; i < series.length; i++) {
      list.add(_buildSerieRow(i + 1, series[i]));
      if (i < series.length - 1 && series[i].descansoSec > 0) {
        list.add(_buildRestRow(series[i].descansoSec));
      }
    }
    return list;
  }

  Widget _buildRestRow(int seconds) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.timer_off_outlined,
              size: 13, color: AppColors.iconMutedOf(context)),
          const SizedBox(width: 4),
          Text(
            'Descanso: ${_formatSeconds(seconds)}',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary(context),
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSerieRow(int num, Serie serie) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Container(
            width: 22,
            height: 22,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.brand.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Text(
              '$num',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: Theme.of(context).brightness == Brightness.dark
                    ? AppColors.brandLight
                    : AppColors.brand,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _serieDetail('${serie.distanciaM}m'),
                _serieDetail(_formatSeconds(serie.tiempoSec.round())),
                _serieDetail(serie.ritmoTexto()),
                _serieDetail('RPE ${serie.rpe}',
                    color: AppColors.iconMutedOf(context)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _serieDetail(String text, {Color? color}) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: color ?? AppColors.textPrimary(context),
      ),
    );
  }

  Widget _buildPopupMenu() {
    return Theme(
      data: Theme.of(context).copyWith(
        popupMenuTheme: PopupMenuThemeData(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 6,
          color: AppColors.surfaceOf(context),
          surfaceTintColor: AppColors.surfaceOf(context),
        ),
      ),
      child: PopupMenuButton<String>(
        icon: Icon(Icons.more_horiz_rounded,
            color: AppColors.iconMutedOf(context), size: 20),
        splashRadius: 24,
        tooltip: 'Opciones',
        offset: const Offset(0, 40),
        onSelected: (val) async {
          if (val == 'tags') {
            if (widget.training.id == null) {
              ModernSnackBar.showError(
                  context, 'Error: No se puede editar este entrenamiento');
              return;
            }
            final result = await showModalBottomSheet<bool>(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (context) => Padding(
                padding: EdgeInsets.only(
                    bottom: MediaQuery.of(context).viewInsets.bottom),
                child: TagSelectorSheet(
                    training: widget.training,
                    trainingId: widget.training.id!),
              ),
            );
            if (result == true && mounted) {
              widget.onUpdate?.call();
              ModernSnackBar.showSuccess(context, 'Etiquetas actualizadas',
                  duration: const Duration(seconds: 2));
            }
          } else if (val == 'pdf') {
            ModernSnackBar.showInfo(context, 'Generando PDF...',
                duration: const Duration(seconds: 2));
            try {
              final pdfBytes = await PdfGeneratorService.generateTrainingPdf(
                  widget.training);
              final filename =
                  '${widget.training.titulo.replaceAll(' ', '_')}_${widget.training.fecha.day}-${widget.training.fecha.month}-${widget.training.fecha.year}.pdf';
              if (kIsWeb) {
                final blob = html.Blob([pdfBytes], 'application/pdf');
                final url = html.Url.createObjectUrlFromBlob(blob);
                html.AnchorElement(href: url)
                  ..setAttribute('download', filename)
                  ..click();
                html.Url.revokeObjectUrl(url);
              } else {
                await Printing.sharePdf(bytes: pdfBytes, filename: filename);
              }
              if (mounted) {
                ModernSnackBar.showSuccess(context, 'PDF descargado correctamente');
              }
            } catch (e) {
              if (mounted) {
                ModernSnackBar.showError(context, 'Error al generar PDF: $e');
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
                    color: AppColors.brand.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.label_rounded,
                      size: 18,
                      color: Theme.of(context).brightness == Brightness.dark
                          ? AppColors.brandLight
                          : AppColors.brand),
                ),
                const SizedBox(width: 12),
                Text('Editar etiquetas',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                        color: AppColors.textPrimary(context))),
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
                    color: AppColors.rpeMax.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.picture_as_pdf_rounded,
                      size: 18, color: AppColors.rpeMax),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Descargar PDF',
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w400,
                            color: AppColors.textPrimary(context))),
                    Text('Guardar reporte',
                        style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary(context))),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String value;
  final String unit;
  final Color color;

  const _StatChip({
    required this.icon,
    required this.value,
    required this.unit,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: AppColors.textPrimary(context),
                letterSpacing: -0.3,
              ),
            ),
            if (unit.isNotEmpty) ...[
              const SizedBox(width: 2),
              Text(
                unit,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w400,
                  color: AppColors.textSecondary(context),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 3),
        Icon(icon, size: 14, color: color),
      ],
    );
  }
}
