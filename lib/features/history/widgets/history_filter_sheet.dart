import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:running_laps/core/theme/app_colors.dart';
import 'package:running_laps/features/history/viewmodels/history_controller.dart';
import 'package:running_laps/features/training/data/tag_manager.dart';
import 'package:running_laps/features/training/data/tag_model.dart';

class HistoryFilterSheet extends StatefulWidget {
  final HistoryController controller;

  const HistoryFilterSheet({super.key, required this.controller});

  @override
  State<HistoryFilterSheet> createState() => _HistoryFilterSheetState();
}

class _HistoryFilterSheetState extends State<HistoryFilterSheet> {
  late DateTime? _startDate;
  late DateTime? _endDate;
  late TextEditingController _minDistController;
  late TextEditingController _maxDistController;
  late TextEditingController _seriesDistController;
  late Set<String> _selectedTags;
  late Future<List<TrainingTag>> _tagsFuture;

  @override
  void initState() {
    super.initState();
    _startDate = widget.controller.filterStartDate.value;
    _endDate = widget.controller.filterEndDate.value;

    _minDistController = TextEditingController(
      text: widget.controller.filterMinDist.value != null
          ? (widget.controller.filterMinDist.value! / 1000).toStringAsFixed(1)
          : '',
    );
    _maxDistController = TextEditingController(
      text: widget.controller.filterMaxDist.value != null
          ? (widget.controller.filterMaxDist.value! / 1000).toStringAsFixed(1)
          : '',
    );
    _seriesDistController = TextEditingController(
      text: widget.controller.filterSeriesDistance.value?.toString() ?? '',
    );
    _selectedTags = Set.from(widget.controller.selectedTags.value);
    _tagsFuture = TagManager().getUserTags();
  }

  @override
  void dispose() {
    _minDistController.dispose();
    _maxDistController.dispose();
    _seriesDistController.dispose();
    super.dispose();
  }

  void _applyFilters() {
    double? minM;
    if (_minDistController.text.isNotEmpty) {
      final val =
          double.tryParse(_minDistController.text.replaceAll(',', '.'));
      if (val != null) minM = val * 1000;
    }
    double? maxM;
    if (_maxDistController.text.isNotEmpty) {
      final val =
          double.tryParse(_maxDistController.text.replaceAll(',', '.'));
      if (val != null) maxM = val * 1000;
    }
    int? seriesM;
    if (_seriesDistController.text.isNotEmpty) {
      seriesM = int.tryParse(_seriesDistController.text);
    }

    widget.controller.setDateRange(_startDate, _endDate);
    widget.controller.setDistanceRange(minM, maxM);
    widget.controller.setSeriesDistanceFilter(seriesM);
    widget.controller.selectedTags.value = _selectedTags;
    widget.controller.setFilter(TrainingFilter.all);

    Navigator.pop(context);
  }

  void _clearFilters() {
    setState(() {
      _startDate = null;
      _endDate = null;
      _minDistController.clear();
      _maxDistController.clear();
      _seriesDistController.clear();
      _selectedTags.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final brandColor =
        isDark ? AppColors.brandLight : AppColors.brand;

    return Container(
      padding: EdgeInsets.only(
        top: 20,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      decoration: BoxDecoration(
        color: AppColors.surfaceOf(context),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Handle bar ─────────────────────────────────────────────
          Center(
            child: Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: AppColors.borderOf(context),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // ── Header ─────────────────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Filtrar Entrenamientos',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: isDark
                      ? AppColors.textPrimaryDark
                      : AppColors.textPrimaryLight,
                ),
              ),
              TextButton(
                onPressed: _clearFilters,
                child: const Text(
                  'Limpiar',
                  style: TextStyle(color: AppColors.rpeMax),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // ── Scrollable content ──────────────────────────────────────
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. FECHAS
                  _sectionTitle('Rango de Fechas', isDark),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _dateButton(
                          label: 'Desde',
                          date: _startDate,
                          isDark: isDark,
                          brandColor: brandColor,
                          onTap: () async {
                            final d = await showDatePicker(
                              context: context,
                              initialDate: _startDate ?? DateTime.now(),
                              firstDate: DateTime(2020),
                              lastDate: DateTime.now(),
                            );
                            if (d != null) setState(() => _startDate = d);
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _dateButton(
                          label: 'Hasta',
                          date: _endDate,
                          isDark: isDark,
                          brandColor: brandColor,
                          onTap: () async {
                            final d = await showDatePicker(
                              context: context,
                              initialDate: _endDate ?? DateTime.now(),
                              firstDate: DateTime(2020),
                              lastDate: DateTime.now(),
                            );
                            if (d != null) setState(() => _endDate = d);
                          },
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // 2. ETIQUETAS
                  _sectionTitle('Etiquetas', isDark),
                  const SizedBox(height: 10),
                  FutureBuilder<List<TrainingTag>>(
                    future: _tagsFuture,
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return LinearProgressIndicator(
                          minHeight: 2,
                          color: brandColor,
                          backgroundColor: AppColors.surface2Of(context),
                        );
                      }
                      final tags = snapshot.data!;
                      if (tags.isEmpty) {
                        return Text(
                          'No tienes etiquetas creadas.',
                          style: TextStyle(
                            color: isDark
                                ? AppColors.textSecondaryDark
                                : AppColors.textSecondaryLight,
                          ),
                        );
                      }

                      return Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: tags.map((tag) {
                          final isSelected = _selectedTags.contains(tag.name);
                          return FilterChip(
                            label: Text(tag.name),
                            selected: isSelected,
                            onSelected: (val) {
                              setState(() {
                                if (val) {
                                  _selectedTags.add(tag.name);
                                } else {
                                  _selectedTags.remove(tag.name);
                                }
                              });
                            },
                            backgroundColor: AppColors.surface2Of(context),
                            selectedColor: brandColor.withValues(alpha: 0.22),
                            labelStyle: TextStyle(
                              color: isSelected
                                  ? brandColor
                                  : (isDark
                                      ? AppColors.textSecondaryDark
                                      : AppColors.textSecondaryLight),
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                            checkmarkColor: brandColor,
                            side: BorderSide(
                              color: isSelected
                                  ? brandColor.withValues(alpha: 0.5)
                                  : AppColors.borderOf(context),
                              width: 1,
                            ),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8)),
                          );
                        }).toList(),
                      );
                    },
                  ),

                  const SizedBox(height: 24),

                  // 3. DETALLES
                  _sectionTitle('Detalles', isDark),
                  const SizedBox(height: 10),

                  Row(
                    children: [
                      Expanded(
                        child: _buildTextField(
                          controller: _minDistController,
                          label: 'Min Km',
                          icon: Icons.map_outlined,
                          isDark: isDark,
                          brandColor: brandColor,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildTextField(
                          controller: _maxDistController,
                          label: 'Max Km',
                          icon: Icons.map_outlined,
                          isDark: isDark,
                          brandColor: brandColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildTextField(
                    controller: _seriesDistController,
                    label: 'Series de (metros)',
                    hint: 'Ej: 400',
                    icon: Icons.repeat_rounded,
                    isDark: isDark,
                    brandColor: brandColor,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Busca entrenos con al menos una serie de esta distancia.',
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark
                          ? AppColors.textTertiaryDark
                          : AppColors.textTertiaryLight,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // ── Apply button ────────────────────────────────────────────
          ElevatedButton(
            onPressed: _applyFilters,
            style: ElevatedButton.styleFrom(
              backgroundColor: brandColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              elevation: 0,
            ),
            child: const Text(
              'Aplicar Filtros',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }

  // ── Helpers ─────────────────────────────────────────────────────────

  Widget _sectionTitle(String title, bool isDark) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.5,
        color: isDark
            ? AppColors.textSecondaryDark
            : AppColors.textSecondaryLight,
      ),
    );
  }

  Widget _dateButton({
    required String label,
    required DateTime? date,
    required bool isDark,
    required Color brandColor,
    required VoidCallback onTap,
  }) {
    final text =
        date != null ? DateFormat('dd/MM/yyyy').format(date) : '-----';
    final isSet = date != null;

    final containerBg = AppColors.surface2Of(context);
    final borderColor = isSet
        ? brandColor
        : AppColors.borderOf(context);
    final labelColor = isDark
        ? AppColors.textTertiaryDark
        : AppColors.textTertiaryLight;
    final valueColor = isSet
        ? (isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight)
        : (isDark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: containerBg,
          border: Border.all(color: borderColor),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: TextStyle(fontSize: 11, color: labelColor)),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  text,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: isSet ? FontWeight.bold : FontWeight.normal,
                    color: valueColor,
                  ),
                ),
                Icon(Icons.calendar_today_rounded,
                    size: 16,
                    color: isSet ? brandColor : labelColor),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    String? hint,
    required IconData icon,
    required bool isDark,
    required Color brandColor,
  }) {
    final fillColor = AppColors.surface2Of(context);
    final enabledBorderColor = AppColors.borderOf(context);

    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      style: TextStyle(
        color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
      ),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: TextStyle(
          color: isDark
              ? AppColors.textSecondaryDark
              : AppColors.textSecondaryLight,
        ),
        hintStyle: TextStyle(
          color: isDark
              ? AppColors.textTertiaryDark
              : AppColors.textTertiaryLight,
        ),
        prefixIcon: Icon(icon,
            color: isDark
                ? AppColors.textTertiaryDark
                : AppColors.textTertiaryLight,
            size: 20),
        filled: true,
        fillColor: fillColor,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: enabledBorderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: brandColor, width: 1.5),
        ),
        contentPadding:
            const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
      ),
    );
  }
}
