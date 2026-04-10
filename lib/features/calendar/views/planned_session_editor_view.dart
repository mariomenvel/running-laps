import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:running_laps/core/theme/app_colors.dart';
import 'package:running_laps/core/widgets/modern_snackbar.dart';
import 'package:running_laps/features/calendar/data/planned_session_model.dart';
import 'package:running_laps/features/calendar/viewmodels/planned_session_viewmodel.dart';
import 'package:running_laps/features/templates/data/template_models.dart';

class PlannedSessionEditorView extends StatefulWidget {
  final String uid;
  final DateTime initialDate;

  /// null = crear nueva sesión, non-null = editar existente
  final PlannedSession? session;

  const PlannedSessionEditorView({
    super.key,
    required this.uid,
    required this.initialDate,
    this.session,
  });

  @override
  State<PlannedSessionEditorView> createState() =>
      _PlannedSessionEditorViewState();
}

class _PlannedSessionEditorViewState extends State<PlannedSessionEditorView> {
  late final PlannedSessionViewModel _viewModel;
  final _formKey = GlobalKey<FormState>();

  // Form field state
  late DateTime _selectedDate;
  TimeOfDay? _selectedTime;
  SessionCategory? _selectedCategory;
  TrainingTemplate? _selectedTemplate;
  final _notesController = TextEditingController();

  bool get _isEditing => widget.session != null;

  @override
  void initState() {
    super.initState();
    _viewModel = PlannedSessionViewModel();
    _viewModel.init(widget.uid);

    // Pre-fill from existing session
    _selectedDate = widget.initialDate;
    if (_isEditing) {
      final s = widget.session!;
      // Parse date
      try {
        _selectedDate = DateTime.parse(s.date);
      } catch (_) {}
      // Parse time
      if (s.time != null) {
        final parts = s.time!.split(':');
        if (parts.length == 2) {
          _selectedTime = TimeOfDay(
            hour:   int.tryParse(parts[0]) ?? 0,
            minute: int.tryParse(parts[1]) ?? 0,
          );
        }
      }
      // Category
      if (s.category.isNotEmpty) {
        _selectedCategory = SessionCategoryX.fromValue(s.category);
      }
      _notesController.text = s.notes ?? '';
      // Template is resolved after init() loads templates — see build()
    }
  }

  @override
  void dispose() {
    _notesController.dispose();
    _viewModel.dispose();
    super.dispose();
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  String _formatDate(DateTime d) =>
      DateFormat('d MMMM yyyy', 'es').format(d);

  String _formatTime(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  String _normalizeDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  // ── Actions ───────────────────────────────────────────────────────────────

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context:      context,
      initialDate:  _selectedDate,
      firstDate:    DateTime(2020),
      lastDate:     DateTime.now().add(const Duration(days: 365)),
      locale:       const Locale('es', 'ES'),
    );
    if (!mounted) return;
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context:     context,
      initialTime: _selectedTime ?? TimeOfDay.now(),
    );
    if (!mounted) return;
    if (picked != null) setState(() => _selectedTime = picked);
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final session = PlannedSession(
      id:                  _isEditing ? widget.session!.id : '',
      uid:                 widget.uid,
      date:                _normalizeDate(_selectedDate),
      time:                _selectedTime != null ? _formatTime(_selectedTime!) : null,
      category:            _selectedCategory!.toValue,
      templateId:          _selectedTemplate?.id,
      notes:               _notesController.text.trim().isEmpty
                               ? null
                               : _notesController.text.trim(),
      status:              _isEditing ? widget.session!.status : PlannedSessionStatus.planned,
      completedTrainingId: _isEditing ? widget.session!.completedTrainingId : null,
      skippedReason:       _isEditing ? widget.session!.skippedReason : null,
      createdAt:           _isEditing ? widget.session!.createdAt : DateTime.now(),
      updatedAt:           DateTime.now(),
    );

    final ok = await _viewModel.save(uid: widget.uid, session: session);
    if (!mounted) return;

    if (ok) {
      Navigator.pop(context, true);
    } else {
      final msg = _viewModel.state.value.errorMessage ?? 'Error guardando';
      ModernSnackBar.showError(context, msg);
    }
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar sesión'),
        content: const Text('¿Seguro que quieres eliminar esta sesión planificada?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.rpeMax),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    if (confirmed != true) return;

    final ok = await _viewModel.delete(
      uid:       widget.uid,
      sessionId: widget.session!.id,
    );
    if (!mounted) return;

    if (ok) {
      Navigator.pop(context, true);
    } else {
      final msg = _viewModel.state.value.errorMessage ?? 'Error eliminando';
      ModernSnackBar.showError(context, msg);
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Editar sesión' : 'Nueva sesión'),
        centerTitle: true,
      ),
      body: ValueListenableBuilder<PlannedSessionEditorState>(
        valueListenable: _viewModel.state,
        builder: (context, state, _) {
          // Resolve template selection after templates load
          if (_isEditing &&
              _selectedTemplate == null &&
              widget.session!.templateId != null &&
              state.availableTemplates.isNotEmpty) {
            try {
              _selectedTemplate = state.availableTemplates
                  .firstWhere((t) => t.id == widget.session!.templateId);
            } catch (_) {}
          }

          if (state.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          return Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 1 ── Fecha ──────────────────────────────────────
                        _FieldLabel('Fecha'),
                        _TapRow(
                          icon: Icons.calendar_today,
                          text: _formatDate(_selectedDate),
                          onTap: _pickDate,
                        ),
                        const SizedBox(height: 20),

                        // 2 ── Hora ───────────────────────────────────────
                        _FieldLabel('Hora (opcional)'),
                        Row(
                          children: [
                            Expanded(
                              child: _TapRow(
                                icon: Icons.access_time,
                                text: _selectedTime != null
                                    ? _formatTime(_selectedTime!)
                                    : 'Sin hora',
                                onTap: _pickTime,
                              ),
                            ),
                            if (_selectedTime != null) ...[
                              const SizedBox(width: 8),
                              IconButton(
                                onPressed: () =>
                                    setState(() => _selectedTime = null),
                                icon: const Icon(Icons.close, size: 20),
                                color: isDark
                                    ? AppColors.textSecondaryDark
                                    : AppColors.textSecondaryLight,
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 20),

                        // 3 ── Tipo de sesión ──────────────────────────────
                        _FieldLabel('Tipo de sesión'),
                        DropdownButtonFormField<SessionCategory>(
                          value: _selectedCategory,
                          decoration: _inputDecoration(context),
                          hint: const Text('Selecciona un tipo'),
                          items: SessionCategory.values.map((cat) {
                            return DropdownMenuItem(
                              value: cat,
                              child: Text(cat.label),
                            );
                          }).toList(),
                          onChanged: (cat) => setState(() {
                            _selectedCategory = cat;
                            // Reset template if it no longer matches
                            if (_selectedTemplate != null &&
                                cat != null &&
                                _selectedTemplate!.category != null &&
                                _selectedTemplate!.category != cat.toValue) {
                              _selectedTemplate = null;
                            }
                          }),
                          validator: (v) =>
                              v == null ? 'Selecciona un tipo de sesión' : null,
                        ),
                        const SizedBox(height: 20),

                        // 4 ── Plantilla ───────────────────────────────────
                        _FieldLabel('Plantilla (opcional)'),
                        if (state.availableTemplates.isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Text(
                              'No tienes plantillas',
                              style: TextStyle(
                                fontSize: 14,
                                color: isDark
                                    ? AppColors.textSecondaryDark
                                    : AppColors.textSecondaryLight,
                              ),
                            ),
                          )
                        else
                          DropdownButtonFormField<TrainingTemplate?>(
                            value: _selectedTemplate,
                            decoration: _inputDecoration(context),
                            hint: const Text('Sin plantilla'),
                            items: [
                              const DropdownMenuItem<TrainingTemplate?>(
                                value: null,
                                child: Text('Sin plantilla'),
                              ),
                              ..._sortedTemplates(state.availableTemplates)
                                  .map((t) => DropdownMenuItem<TrainingTemplate?>(
                                        value: t,
                                        child: Text(t.name),
                                      )),
                            ],
                            onChanged: (t) =>
                                setState(() => _selectedTemplate = t),
                          ),
                        const SizedBox(height: 20),

                        // 5 ── Notas ───────────────────────────────────────
                        _FieldLabel('Notas (opcional)'),
                        TextFormField(
                          controller: _notesController,
                          decoration: _inputDecoration(context).copyWith(
                            hintText: 'Añade notas…',
                          ),
                          maxLines: 3,
                          minLines: 1,
                          keyboardType: TextInputType.multiline,
                          textCapitalization: TextCapitalization.sentences,
                        ),

                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
                ),
              ),

              // ── Bottom buttons ─────────────────────────────────────────
              _BottomBar(
                isEditing:  _isEditing,
                isSaving:   state.isSaving,
                onDelete:   _isEditing ? _confirmDelete : null,
                onSave:     _save,
              ),
            ],
          );
        },
      ),
    );
  }

  List<TrainingTemplate> _sortedTemplates(List<TrainingTemplate> all) {
    if (_selectedCategory == null) return all;
    final catValue = _selectedCategory!.toValue;
    final matching    = all.where((t) => t.category == catValue).toList();
    final nonMatching = all.where((t) => t.category != catValue).toList();
    return [...matching, ...nonMatching];
  }

  InputDecoration _inputDecoration(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InputDecoration(
      filled: true,
      fillColor: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: isDark ? AppColors.borderDark : AppColors.borderLight,
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: isDark ? AppColors.borderDark : AppColors.borderLight,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.brandPurple, width: 2),
      ),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }
}

// ── Small helpers ─────────────────────────────────────────────────────────────

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: isDark
              ? AppColors.textSecondaryDark
              : AppColors.textSecondaryLight,
        ),
      ),
    );
  }
}

class _TapRow extends StatelessWidget {
  final IconData icon;
  final String text;
  final VoidCallback onTap;

  const _TapRow({
    required this.icon,
    required this.text,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark ? AppColors.borderDark : AppColors.borderLight,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: AppColors.brandPurple),
            const SizedBox(width: 12),
            Text(
              text,
              style: const TextStyle(fontSize: 15),
            ),
          ],
        ),
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  final bool isEditing;
  final bool isSaving;
  final VoidCallback? onDelete;
  final VoidCallback onSave;

  const _BottomBar({
    required this.isEditing,
    required this.isSaving,
    required this.onDelete,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(20, 12, 20, 12 + bottomPadding),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          top: BorderSide(
            color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
          ),
        ),
      ),
      child: Row(
        children: [
          if (isEditing) ...[
            TextButton(
              onPressed: isSaving ? null : onDelete,
              style: TextButton.styleFrom(foregroundColor: AppColors.rpeMax),
              child: const Text('Eliminar'),
            ),
            const Spacer(),
          ],
          Expanded(
            flex: isEditing ? 0 : 1,
            child: SizedBox(
              width: isEditing ? 140 : double.infinity,
              child: FilledButton(
                onPressed: isSaving ? null : onSave,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.brandPurple,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Guardar',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
