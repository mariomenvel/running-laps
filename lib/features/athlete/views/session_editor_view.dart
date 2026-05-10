import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:running_laps/core/theme/app_colors.dart';
import 'package:running_laps/core/widgets/number_picker_field.dart';
import 'package:running_laps/core/widgets/modern_snackbar.dart';
import 'package:running_laps/features/athlete/data/athlete_session_model.dart';
import 'package:running_laps/features/athlete/viewmodels/session_editor_viewmodel.dart';
import 'package:running_laps/features/athlete/widgets/save_as_template_sheet.dart';
import 'package:running_laps/features/athlete/widgets/session_block_editor.dart';
import 'package:running_laps/features/profile/data/zones_repository.dart';
import 'package:running_laps/features/templates/data/template_models.dart';

// ─────────────────────────────────────────────────────────────────────────────
// SessionEditorView
// ─────────────────────────────────────────────────────────────────────────────

class SessionEditorView extends StatefulWidget {
  final String uid;
  final DateTime initialDate;
  final AthleteSession? session; // null = crear

  const SessionEditorView({
    super.key,
    required this.uid,
    required this.initialDate,
    this.session,
  });

  @override
  State<SessionEditorView> createState() => _SessionEditorViewState();
}

class _SessionEditorViewState extends State<SessionEditorView> {
  late final SessionEditorViewModel _vm;

  // ── Form state ────────────────────────────────────────────────────────────
  late DateTime _selectedDate;
  TimeOfDay? _selectedTime;
  SessionCategory? _selectedCategory;

  // Warmup
  bool _hasWarmup = false;
  final TextEditingController _warmupDescCtrl  = TextEditingController();
  final TextEditingController _warmupDurCtrl   = TextEditingController();

  // Cooldown
  bool _hasCooldown = false;
  final TextEditingController _cooldownDescCtrl = TextEditingController();
  final TextEditingController _cooldownDurCtrl  = TextEditingController();

  // Notes
  final TextEditingController _planningNotesCtrl   = TextEditingController();
  final TextEditingController _executionNotesCtrl  = TextEditingController();

  // Race fields (only when category == competicion)
  final TextEditingController _raceNameCtrl        = TextEditingController();
  int? _standardDistanceM;   // null = none, -1 = custom, else one of the std values
  int _customDistanceM = 1000;
  final TextEditingController _targetHCtrl         = TextEditingController();
  final TextEditingController _targetMCtrl         = TextEditingController();
  final TextEditingController _targetSCtrl         = TextEditingController();

  // Blocks
  List<SessionBlock> _currentBlocks = [];
  bool _hasFcConfig = false;

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _vm = SessionEditorViewModel();
    _vm.init(widget.uid);
    _currentBlocks = widget.session?.blocks ?? [];
    _loadProfile();

    final s = widget.session;
    _selectedDate = s != null
        ? (DateTime.tryParse(s.date) ?? widget.initialDate)
        : widget.initialDate;

    if (s != null) {
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
      if (s.category != null) {
        try {
          _selectedCategory = SessionCategoryX.fromValue(s.category!);
        } catch (_) {}
      }
      // Warmup
      if (s.warmup != null) {
        _hasWarmup = true;
        _warmupDescCtrl.text = s.warmup!.description ?? '';
        _warmupDurCtrl.text  = s.warmup!.durationMinutes?.toString() ?? '';
      }
      // Cooldown
      if (s.cooldown != null) {
        _hasCooldown = true;
        _cooldownDescCtrl.text = s.cooldown!.description ?? '';
        _cooldownDurCtrl.text  = s.cooldown!.durationMinutes?.toString() ?? '';
      }
      // Notes
      _planningNotesCtrl.text  = s.planningNotes  ?? '';
      _executionNotesCtrl.text = s.executionNotes ?? '';
      // Race fields
      _raceNameCtrl.text = s.raceName ?? '';
      final dist = s.raceDistanceM;
      if (dist != null) {
        const stdDists = [5000, 10000, 21097, 42195];
        if (stdDists.contains(dist)) {
          _standardDistanceM = dist;
        } else {
          _standardDistanceM = -1;
          _customDistanceM = dist;
        }
      }
      final t = s.targetTimeSeconds;
      if (t != null && t > 0) {
        _targetHCtrl.text = (t ~/ 3600).toString();
        _targetMCtrl.text = ((t % 3600) ~/ 60).toString();
        _targetSCtrl.text = (t % 60).toString();
      }
    }
  }

  @override
  void dispose() {
    _warmupDescCtrl.dispose();
    _warmupDurCtrl.dispose();
    _cooldownDescCtrl.dispose();
    _cooldownDurCtrl.dispose();
    _planningNotesCtrl.dispose();
    _executionNotesCtrl.dispose();
    _raceNameCtrl.dispose();
    _targetHCtrl.dispose();
    _targetMCtrl.dispose();
    _targetSCtrl.dispose();
    _vm.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    try {
      final profile =
          await ZonesRepository().getUserProfile(widget.uid);
      if (!mounted) return;
      setState(() => _hasFcConfig = profile?.fcMax != null);
    } catch (e) {
      debugPrint('[SessionEditorView] _loadProfile error: $e');
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  bool get _isEditing => widget.session != null;

  String _formatDate(DateTime d) {
    const months = [
      '', 'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio',
      'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre',
    ];
    return '${d.day} de ${months[d.month]} de ${d.year}';
  }

  String _formatTime(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  String _normalizeDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  SessionWarmupCooldown? _buildWarmupCooldown(
    TextEditingController descCtrl,
    TextEditingController durCtrl,
  ) {
    final desc = descCtrl.text.trim();
    final dur  = int.tryParse(durCtrl.text.trim());
    if (desc.isEmpty && dur == null) return null;
    return SessionWarmupCooldown(
      description:     desc.isEmpty ? null : desc,
      durationMinutes: dur,
    );
  }

  int? _buildTargetSeconds() {
    final h = int.tryParse(_targetHCtrl.text) ?? 0;
    final m = int.tryParse(_targetMCtrl.text) ?? 0;
    final s = int.tryParse(_targetSCtrl.text) ?? 0;
    final total = h * 3600 + m * 60 + s;
    return total > 0 ? total : null;
  }

  AthleteSession _buildSession() {
    final now = DateTime.now();
    final existing = widget.session;
    final isComp = _selectedCategory == SessionCategory.competicion;
    return AthleteSession(
      id:            existing?.id ?? '',
      uid:           widget.uid,
      date:          _normalizeDate(_selectedDate),
      time:          _selectedTime != null ? _formatTime(_selectedTime!) : null,
      category:      _selectedCategory?.toValue,
      status:        existing?.status ?? AthleteSessionStatus.planned,
      warmup:        _hasWarmup
          ? _buildWarmupCooldown(_warmupDescCtrl, _warmupDurCtrl)
          : null,
      blocks:        _currentBlocks,
      cooldown:      _hasCooldown
          ? _buildWarmupCooldown(_cooldownDescCtrl, _cooldownDurCtrl)
          : null,
      planningNotes:  _planningNotesCtrl.text.trim().isEmpty
          ? null
          : _planningNotesCtrl.text.trim(),
      executionNotes: _executionNotesCtrl.text.trim().isEmpty
          ? null
          : _executionNotesCtrl.text.trim(),
      raceName: isComp && _raceNameCtrl.text.trim().isNotEmpty
          ? _raceNameCtrl.text.trim() : null,
      raceDistanceM: isComp
          ? (_standardDistanceM == -1
              ? _customDistanceM
              : _standardDistanceM)
          : null,
      targetTimeSeconds: isComp ? _buildTargetSeconds() : null,
      createdAt: existing?.createdAt ?? now,
      updatedAt: now,
    );
  }

  // ── Actions ───────────────────────────────────────────────────────────────

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context:     context,
      initialDate: _selectedDate,
      firstDate:   DateTime(2020),
      lastDate:    DateTime(2027),
      locale:      const Locale('es', 'ES'),
    );
    if (picked != null && mounted) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context:     context,
      initialTime: _selectedTime ?? TimeOfDay.now(),
    );
    if (picked != null && mounted) {
      setState(() => _selectedTime = picked);
    }
  }

  Future<void> _save() async {
    if (_selectedCategory == null) {
      ModernSnackBar.showError(
          context, 'Selecciona el tipo de sesión antes de guardar');
      return;
    }
    final session = _buildSession();
    final ok = await _vm.save(uid: widget.uid, session: session);
    if (!mounted) return;
    if (ok) {
      Navigator.pop(context, true);
    } else {
      ModernSnackBar.showError(
          context, _vm.state.value.errorMessage ?? 'Error al guardar');
    }
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar sesión'),
        content: const Text('¿Eliminar esta sesión planificada? Esta acción no se puede deshacer.'),
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
    if (confirmed != true || !mounted) return;

    final ok = await _vm.delete(
      uid:       widget.uid,
      sessionId: widget.session!.id,
    );
    if (!mounted) return;
    if (ok) {
      Navigator.pop(context, true);
    } else {
      ModernSnackBar.showError(
          context, _vm.state.value.errorMessage ?? 'Error al eliminar');
    }
  }

  void _showTemplateSheet(List<TrainingTemplate> templates) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _TemplateSelectorSheet(
        templates: templates,
        onSelected: (t) {
          Navigator.pop(ctx);
          debugPrint('[SessionEditorView] cargar plantilla ${t.id}');
          setState(() {
            _currentBlocks = t.blocks.asMap().entries.map((e) {
              final i = e.key;
              final b = e.value;
              return SessionBlock(
                id:    '${DateTime.now().millisecondsSinceEpoch}${b.id}',
                order: i,
                type:  b.type == TemplateBlockType.time
                    ? SessionBlockType.continuousTime
                    : SessionBlockType.series,
                reps:            b.type == TemplateBlockType.distance ? 1 : null,
                distanceM:       b.type == TemplateBlockType.distance ? b.value : null,
                durationMinutes: b.type == TemplateBlockType.time
                    ? (b.value ~/ 60)
                    : null,
                restSeconds:     b.restSeconds,
                targetPaceMinMin: b.targetPaceMin,
                targetPaceMinSec: b.targetPaceSec,
                targetRpe:        b.targetRpe,
                targetZone:       b.targetZone,
              );
            }).toList();
          });
        },
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<SessionEditorState>(
      valueListenable: _vm.state,
      builder: (context, state, _) {
        return Scaffold(
          appBar: AppBar(
            title: Text(_isEditing ? 'Editar sesión' : 'Nueva sesión'),
            actions: [
              if (state.isSaving)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.brand,
                      ),
                    ),
                  ),
                )
              else
                TextButton(
                  onPressed: _save,
                  child: const Text(
                    'Guardar',
                    style: TextStyle(
                      color:      AppColors.brand,
                      fontWeight: FontWeight.w700,
                      fontSize:   16,
                    ),
                  ),
                ),
            ],
          ),
          body: state.isLoading
              ? const Center(
                  child: CircularProgressIndicator(color: AppColors.brand),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildMetadataSection(),
                      if (_selectedCategory == SessionCategory.competicion) ...[
                        const SizedBox(height: 28),
                        _buildRaceSection(),
                      ],
                      const SizedBox(height: 28),
                      _buildWarmupSection(),
                      const SizedBox(height: 28),
                      _buildMainSection(),
                      const SizedBox(height: 28),
                      _buildCooldownSection(),
                      const SizedBox(height: 28),
                      _buildNotesSection(),
                      const SizedBox(height: 28),
                      _buildSecondaryActions(state),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
        );
      },
    );
  }

  // ── Sección 1: Metadatos ──────────────────────────────────────────────────

  Widget _buildMetadataSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Fecha
        _RowField(
          icon:  Icons.calendar_today_rounded,
          label: _formatDate(_selectedDate),
          onTap: _pickDate,
        ),
        const SizedBox(height: 12),

        // Hora
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: _RowField(
                    icon:  Icons.access_time_rounded,
                    label: _selectedTime != null
                        ? _formatTime(_selectedTime!)
                        : 'Sin hora',
                    onTap: _pickTime,
                  ),
                ),
                if (_selectedTime != null) ...[
                  const SizedBox(width: 8),
                  IconButton(
                    icon:           const Icon(Icons.close, size: 20),
                    onPressed:      () => setState(() => _selectedTime = null),
                    color:          const Color(0xFFAAAAAA),
                    visualDensity:  VisualDensity.compact,
                    padding:        EdgeInsets.zero,
                  ),
                ],
              ],
            ),
            if (_selectedTime != null) ...[
              const SizedBox(height: 4),
              const Padding(
                padding: EdgeInsets.only(left: 4),
                child: Text(
                  'Se enviará una notificación recordatorio',
                  style: TextStyle(fontSize: 12, color: Color(0xFFAAAAAA)),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 12),

        // Tipo de sesión
        DropdownButtonFormField<SessionCategory?>(
          value:       _selectedCategory,
          hint:        const Text('Tipo de sesión (opcional)'),
          isExpanded:  true,
          decoration:  _inputDecoration(),
          items: [
            const DropdownMenuItem(
              value: null,
              child: Text('Sin tipo'),
            ),
            ...SessionCategory.values.map((c) => DropdownMenuItem(
              value: c,
              child: Text(c.label),
            )),
          ],
          onChanged: (v) => setState(() => _selectedCategory = v),
        ),
      ],
    );
  }

  // ── Sección 1b: Detalles de competición ──────────────────────────────────

  Widget _buildRaceSection() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final secondary = isDark
        ? AppColors.textSecondaryDark
        : AppColors.textSecondaryLight;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader('Detalles de competición', color: AppColors.rpeMax),
        const SizedBox(height: 10),
        TextFormField(
          controller: _raceNameCtrl,
          decoration: _inputDecoration(
            hint: 'Nombre de la carrera (p. ej. "10K Valencia")',
          ),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<int?>(
          value: _standardDistanceM,
          isExpanded: true,
          decoration: _inputDecoration(hint: 'Distancia oficial'),
          items: const [
            DropdownMenuItem(value: null,  child: Text('Sin distancia')),
            DropdownMenuItem(value: 5000,  child: Text('5K')),
            DropdownMenuItem(value: 10000, child: Text('10K')),
            DropdownMenuItem(value: 21097, child: Text('Media maratón (21,1 km)')),
            DropdownMenuItem(value: 42195, child: Text('Maratón (42,2 km)')),
            DropdownMenuItem(value: -1,    child: Text('Otra distancia')),
          ],
          onChanged: (v) => setState(() => _standardDistanceM = v),
        ),
        if (_standardDistanceM == -1) ...[
          const SizedBox(height: 10),
          NumberPickerField(
            label:     'Distancia',
            value:     _customDistanceM,
            min:       100,
            max:       42000,
            step:      100,
            unit:      'm',
            onChanged: (v) => setState(() => _customDistanceM = v),
          ),
        ],
        const SizedBox(height: 12),
        Text(
          'Tiempo objetivo',
          style: TextStyle(fontSize: 13, color: secondary),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            _TimePartField(ctrl: _targetHCtrl, label: 'h'),
            const SizedBox(width: 8),
            _TimePartField(ctrl: _targetMCtrl, label: 'min'),
            const SizedBox(width: 8),
            _TimePartField(ctrl: _targetSCtrl, label: 'seg'),
          ],
        ),
      ],
    );
  }

  // ── Sección 2: Calentamiento ──────────────────────────────────────────────

  Widget _buildWarmupSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader('Calentamiento'),
        const SizedBox(height: 10),
        if (!_hasWarmup)
          OutlinedButton.icon(
            onPressed: () => setState(() => _hasWarmup = true),
            icon:  const Icon(Icons.add, size: 18),
            label: const Text('Añadir calentamiento'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.brand,
              side:            const BorderSide(color: AppColors.brand),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          )
        else
          _WarmupCooldownForm(
            descCtrl: _warmupDescCtrl,
            durCtrl:  _warmupDurCtrl,
            hint:     'Descripción del calentamiento',
            onRemove: () => setState(() {
              _hasWarmup = false;
              _warmupDescCtrl.clear();
              _warmupDurCtrl.clear();
            }),
          ),
      ],
    );
  }

  // ── Sección 3: Parte principal ────────────────────────────────────────────

  Widget _buildMainSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader('Parte principal'),
        const SizedBox(height: 10),
        SessionBlockEditor(
          initialBlocks:   _currentBlocks,
          hasFcConfig:     _hasFcConfig,
          onBlocksChanged: (blocks) =>
              setState(() => _currentBlocks = blocks),
        ),
      ],
    );
  }

  // ── Sección 4: Vuelta a la calma ──────────────────────────────────────────

  Widget _buildCooldownSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader('Vuelta a la calma'),
        const SizedBox(height: 10),
        if (!_hasCooldown)
          OutlinedButton.icon(
            onPressed: () => setState(() => _hasCooldown = true),
            icon:  const Icon(Icons.add, size: 18),
            label: const Text('Añadir vuelta a la calma'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.brand,
              side:            const BorderSide(color: AppColors.brand),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          )
        else
          _WarmupCooldownForm(
            descCtrl: _cooldownDescCtrl,
            durCtrl:  _cooldownDurCtrl,
            hint:     'Descripción de la vuelta a la calma',
            onRemove: () => setState(() {
              _hasCooldown = false;
              _cooldownDescCtrl.clear();
              _cooldownDurCtrl.clear();
            }),
          ),
      ],
    );
  }

  // ── Sección 5: Notas ──────────────────────────────────────────────────────

  Widget _buildNotesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader('Notas de planificación'),
        const SizedBox(height: 10),
        TextFormField(
          controller: _planningNotesCtrl,
          maxLines:   null,
          minLines:   3,
          decoration: _inputDecoration(
            hint: 'Intención, contexto, condiciones previstas...',
          ),
        ),
        const SizedBox(height: 20),
        _SectionHeader(
          'Notas de ejecución',
          color: const Color(0xFFBBBBBB),
        ),
        const SizedBox(height: 10),
        TextFormField(
          controller: _executionNotesCtrl,
          maxLines:   null,
          minLines:   3,
          decoration: _inputDecoration(
            hint: 'Sensaciones, desviaciones, cómo fue realmente...',
          ),
        ),
      ],
    );
  }

  // ── Sección 6: Acciones secundarias ──────────────────────────────────────

  Widget _buildSecondaryActions(SessionEditorState state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OutlinedButton.icon(
          onPressed: state.availableTemplates.isEmpty
              ? null
              : () => _showTemplateSheet(state.availableTemplates),
          icon:  const Icon(Icons.file_copy_outlined, size: 18),
          label: const Text('Partir de plantilla existente'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.brand,
            side: BorderSide(
              color: state.availableTemplates.isEmpty
                  ? const Color(0xFFAAAAAA)
                  : AppColors.brand,
            ),
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: (_currentBlocks.isEmpty &&
                  !_hasWarmup &&
                  !_hasCooldown)
              ? null
              : () => showSaveAsTemplateSheet(
                    context: context,
                    uid:     widget.uid,
                    session: _buildSession(),
                  ),
          icon:  const Icon(Icons.bookmark_add_outlined, size: 18),
          label: const Text('Guardar como plantilla'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.brand,
            side: BorderSide(
              color: (_currentBlocks.isEmpty && !_hasWarmup && !_hasCooldown)
                  ? const Color(0xFFAAAAAA)
                  : AppColors.brand,
            ),
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
          ),
        ),
        if (_isEditing) ...[
          const SizedBox(height: 16),
          TextButton(
            onPressed: state.isSaving ? null : _confirmDelete,
            child: const Text(
              'Eliminar sesión',
              style: TextStyle(color: AppColors.rpeMax, fontSize: 15),
            ),
          ),
        ],
      ],
    );
  }

  // ── Input decoration helper ───────────────────────────────────────────────

  InputDecoration _inputDecoration({String? hint}) {
    return InputDecoration(
      hintText:     hint,
      isDense:      true,
      border:       OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide:   const BorderSide(color: Color(0xFFDDDDDD)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide:   BorderSide(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.5),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide:   const BorderSide(color: AppColors.brand),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _SectionHeader
// ─────────────────────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String text;
  final Color color;

  const _SectionHeader(this.text, {this.color = const Color(0xFFAAAAAA)});

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: TextStyle(
        fontSize:      11,
        fontWeight:    FontWeight.w700,
        letterSpacing: 0.8,
        color:         color,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _RowField  (tappable row — fecha / hora)
// ─────────────────────────────────────────────────────────────────────────────

class _RowField extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _RowField({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color:        AppColors.surfaceOf(context),
          borderRadius: BorderRadius.circular(10),
          border:       Border.all(
            color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.5),
          ),
        ),
        child: Row(children: [
          Icon(icon, size: 18, color: AppColors.brand),
          const SizedBox(width: 10),
          Text(label, style: const TextStyle(fontSize: 15)),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _WarmupCooldownForm
// ─────────────────────────────────────────────────────────────────────────────

class _WarmupCooldownForm extends StatefulWidget {
  final TextEditingController descCtrl;
  final TextEditingController durCtrl;
  final String hint;
  final VoidCallback onRemove;

  const _WarmupCooldownForm({
    required this.descCtrl,
    required this.durCtrl,
    required this.hint,
    required this.onRemove,
  });

  @override
  State<_WarmupCooldownForm> createState() => _WarmupCooldownFormState();
}

class _WarmupCooldownFormState extends State<_WarmupCooldownForm> {
  late int _durMin;

  @override
  void initState() {
    super.initState();
    _durMin = int.tryParse(widget.durCtrl.text) ?? 1;
    widget.durCtrl.addListener(_syncFromCtrl);
  }

  void _syncFromCtrl() {
    final v = int.tryParse(widget.durCtrl.text) ?? 1;
    if (v != _durMin) setState(() => _durMin = v);
  }

  @override
  void dispose() {
    widget.durCtrl.removeListener(_syncFromCtrl);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: widget.descCtrl,
          maxLines:   null,
          decoration: InputDecoration(
            hintText:       widget.hint,
            isDense:        true,
            border:         OutlineInputBorder(
                borderRadius: BorderRadius.circular(10)),
            enabledBorder:  OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide:   BorderSide(
                  color: Theme.of(context)
                      .colorScheme
                      .outline
                      .withValues(alpha: 0.5),
                )),
            focusedBorder:  OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide:   const BorderSide(color: AppColors.brand)),
            contentPadding: const EdgeInsets.symmetric(
                horizontal: 14, vertical: 12),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            const Icon(Icons.timer_outlined, size: 16, color: AppColors.brand),
            const SizedBox(width: 6),
            Expanded(
              child: NumberPickerField(
                label:     'Duración',
                value:     _durMin,
                min:       1,
                max:       300,
                step:      1,
                unit:      'min',
                onChanged: (v) {
                  setState(() => _durMin = v);
                  widget.durCtrl.text = v.toString();
                },
              ),
            ),
            const SizedBox(width: 8),
            TextButton.icon(
              onPressed:  widget.onRemove,
              icon:        const Icon(Icons.close, size: 16),
              label:       const Text('Quitar'),
              style:       TextButton.styleFrom(
                foregroundColor: AppColors.rpeMax,
                visualDensity:   VisualDensity.compact,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _TimePartField  (h / min / seg for target time)
// ─────────────────────────────────────────────────────────────────────────────

class _TimePartField extends StatefulWidget {
  final TextEditingController ctrl;
  final String label;

  const _TimePartField({required this.ctrl, required this.label});

  @override
  State<_TimePartField> createState() => _TimePartFieldState();
}

class _TimePartFieldState extends State<_TimePartField> {
  late int _value;

  @override
  void initState() {
    super.initState();
    _value = int.tryParse(widget.ctrl.text) ?? 0;
    widget.ctrl.addListener(_syncFromCtrl);
  }

  void _syncFromCtrl() {
    final v = int.tryParse(widget.ctrl.text) ?? 0;
    if (v != _value) setState(() => _value = v);
  }

  @override
  void dispose() {
    widget.ctrl.removeListener(_syncFromCtrl);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 80,
          child: NumberPickerField(
            label:     widget.label,
            value:     _value,
            min:       0,
            max:       59,
            step:      1,
            unit:      '',
            onChanged: (v) {
              setState(() => _value = v);
              widget.ctrl.text = v.toString();
            },
          ),
        ),
        const SizedBox(width: 4),
        Text(widget.label, style: const TextStyle(fontSize: 13)),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _TemplateSelectorSheet
// ─────────────────────────────────────────────────────────────────────────────

class _TemplateSelectorSheet extends StatelessWidget {
  final List<TrainingTemplate> templates;
  final ValueChanged<TrainingTemplate> onSelected;

  const _TemplateSelectorSheet({
    required this.templates,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return DraggableScrollableSheet(
      expand:          false,
      initialChildSize: 0.5,
      minChildSize:     0.3,
      maxChildSize:     0.85,
      builder: (_, scrollCtrl) => Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width:  40,
            height: 4,
            decoration: BoxDecoration(
              color:        const Color(0xFFAAAAAA),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Selecciona una plantilla',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: ListView.builder(
              controller: scrollCtrl,
              padding:    const EdgeInsets.symmetric(horizontal: 16),
              itemCount:  templates.length,
              itemBuilder: (_, i) {
                final t = templates[i];
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Color(t.colorValue).withValues(alpha: 0.15),
                    child: Icon(Icons.list_alt_rounded,
                        color: Color(t.colorValue), size: 20),
                  ),
                  title: Text(t.name,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(
                    '${t.blocks.length} bloque${t.blocks.length != 1 ? 's' : ''}',
                    style: const TextStyle(fontSize: 12),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  tileColor: AppColors.surfaceOf(context),
                  onTap: () => onSelected(t),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
