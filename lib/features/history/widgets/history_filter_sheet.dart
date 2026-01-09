import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:running_laps/config/app_theme.dart';
import 'package:running_laps/features/history/viewmodels/history_controller.dart';
import 'package:running_laps/features/training/data/tag_manager.dart';
import 'package:running_laps/features/training/data/tag_model.dart';

class HistoryFilterSheet extends StatefulWidget {
  final HistoryController controller;

  const HistoryFilterSheet({Key? key, required this.controller}) : super(key: key);

  @override
  _HistoryFilterSheetState createState() => _HistoryFilterSheetState();
}

class _HistoryFilterSheetState extends State<HistoryFilterSheet> {
  // Local state for the form before applying
  late DateTime? _startDate;
  late DateTime? _endDate;
  late TextEditingController _minDistController;
  late TextEditingController _maxDistController;
  late TextEditingController _seriesDistController;
  late Set<String> _selectedTags;

  // Future for loading tags
  late Future<List<TrainingTag>> _tagsFuture;

  @override
  void initState() {
    super.initState();
    // Initialize with current controller values
    _startDate = widget.controller.filterStartDate.value;
    _endDate = widget.controller.filterEndDate.value;
    
    _minDistController = TextEditingController(
      text: widget.controller.filterMinDist.value != null 
          ? (widget.controller.filterMinDist.value! / 1000).toStringAsFixed(1) // Show in KM
          : ''
    );
    
    _maxDistController = TextEditingController(
      text: widget.controller.filterMaxDist.value != null 
          ? (widget.controller.filterMaxDist.value! / 1000).toStringAsFixed(1) 
          : ''
    );

    _seriesDistController = TextEditingController(
      text: widget.controller.filterSeriesDistance.value?.toString() ?? ''
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
    // Parse distances to meters
    double? minM;
    if (_minDistController.text.isNotEmpty) {
      final val = double.tryParse(_minDistController.text.replaceAll(',', '.'));
      if (val != null) minM = val * 1000;
    }

    double? maxM;
    if (_maxDistController.text.isNotEmpty) {
      final val = double.tryParse(_maxDistController.text.replaceAll(',', '.'));
      if (val != null) maxM = val * 1000;
    }

    int? seriesM;
    if (_seriesDistController.text.isNotEmpty) {
      seriesM = int.tryParse(_seriesDistController.text);
    }

    // Apply to controller
    widget.controller.setDateRange(_startDate, _endDate);
    widget.controller.setDistanceRange(minM, maxM);
    widget.controller.setSeriesDistanceFilter(seriesM);
    widget.controller.selectedTags.value = _selectedTags;
    // Trigger filter update in controller
    widget.controller.setFilter(TrainingFilter.all); // Reset quick filter to custom effectively, or just apply
    
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
    // Optional: apply immediately or wait for user to hit "Apply"?
    // Usually "Clear" in a sheet resets the form. 
    // To clear ACTUAL filters, user taps "Apply" with empty form, OR we provide a "Reset & Apply" button.
    // Let's make this button just reset local state.
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        top: 20, 
        left: 20, 
        right: 20, 
        bottom: MediaQuery.of(context).viewInsets.bottom + 20
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min, // Wrap content
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Filtrar Entrenamientos',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade800,
                ),
              ),
              TextButton(
                onPressed: _clearFilters,
                child: const Text('Limpiar', style: TextStyle(color: Colors.redAccent)),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Scrollable content
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. FECHAS
                  _sectionTitle('Rango de Fechas'),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _dateButton(
                          label: 'Desde',
                          date: _startDate,
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
                  
                  // 2. TAGS
                  _sectionTitle('Etiquetas'),
                  const SizedBox(height: 10),
                  FutureBuilder<List<TrainingTag>>(
                    future: _tagsFuture,
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) return const LinearProgressIndicator(minHeight: 2);
                      final tags = snapshot.data!;
                      if (tags.isEmpty) return const Text('No tienes etiquetas creadas.', style: TextStyle(color: Colors.grey));
                      
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
                            backgroundColor: Colors.grey.shade100,
                            selectedColor: Tema.brandPurple.withOpacity(0.2),
                            labelStyle: TextStyle(
                              color: isSelected ? Tema.brandPurple : Colors.grey.shade700,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            ),
                            checkmarkColor: Tema.brandPurple,
                            side: BorderSide.none,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          );
                        }).toList(),
                      );
                    },
                  ),

                  const SizedBox(height: 24),

                  // 3. DATOS DE ENTRENAMIENTO
                  _sectionTitle('Detalles'),
                  const SizedBox(height: 10),
                  
                  // Distancia Total Row
                  Row(
                    children: [
                      Expanded(
                        child: _buildTextField(
                          controller: _minDistController,
                          label: 'Min Km',
                          icon: Icons.map_outlined,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildTextField(
                          controller: _maxDistController,
                          label: 'Max Km',
                          icon: Icons.map_outlined,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Series Distance
                  _buildTextField(
                    controller: _seriesDistController,
                    label: 'Series de (metros)',
                    hint: 'Ej: 400',
                    icon: Icons.repeat_rounded,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Busca entrenos con al menos una serie de esta distancia.',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                  ),

                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Action Buttons
          ElevatedButton(
            onPressed: _applyFilters,
            style: ElevatedButton.styleFrom(
              backgroundColor: Tema.brandPurple,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 2,
            ),
            child: const Text('Aplicar Filtros', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.bold,
        color: Colors.black54,
        letterSpacing: 0.5,
      ),
    );
  }

  Widget _dateButton({required String label, DateTime? date, required VoidCallback onTap}) {
    final text = date != null ? DateFormat('dd/MM/yyyy').format(date) : '-----';
    final isSet = date != null;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          border: Border.all(color: isSet ? Tema.brandPurple : Colors.grey.shade300),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  text,
                  style: TextStyle(
                    fontSize: 15, 
                    fontWeight: isSet ? FontWeight.bold : FontWeight.normal,
                    color: isSet ? Colors.black87 : Colors.grey.shade400
                  ),
                ),
                Icon(Icons.calendar_today_rounded, size: 16, color: isSet ? Tema.brandPurple : Colors.grey.shade400),
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
  }) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, color: Colors.grey.shade400, size: 20),
        filled: true,
        fillColor: Colors.grey.shade50,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Tema.brandPurple),
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
      ),
    );
  }
}

