import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:running_laps/core/services/notification_service.dart';
import 'package:running_laps/core/theme/app_colors.dart';
import 'package:running_laps/core/widgets/modern_snackbar.dart';
import 'package:running_laps/features/athlete/data/athlete_session_model.dart';
import 'package:running_laps/features/athlete/data/athlete_session_repository.dart';
import 'package:running_laps/features/templates/data/template_models.dart';
import 'package:running_laps/features/templates/data/templates_repository.dart';

// ── Constantes ────────────────────────────────────────────────────────────────

const List<int> _standardDistances = [
  50, 100, 150, 200, 250, 300, 400, 500, 600, 800,
  1000, 1200, 1500, 2000, 3000, 4000, 5000,
];

const List<int> _restValues = [
  0, 15, 30, 45, 60, 90, 120, 150, 180, 240, 300, 360, 420, 480, 600,
];

const List<double> _rpeValues = [
  1, 1.5, 2, 2.5, 3, 3.5, 4, 4.5, 5, 5.5,
  6, 6.5, 7, 7.5, 8, 8.5, 9, 9.5, 10,
];

const List<int> _paceMinValues = [2, 3, 4, 5, 6, 7, 8, 9];
const List<int> _paceSecValues = [0, 5, 10, 15, 20, 25, 30, 35, 40, 45, 50, 55];

// ── Helpers ───────────────────────────────────────────────────────────────────

String _distanceLabel(int m) {
  if (m < 1000) return '${m}m';
  final km = m / 1000;
  return km == km.truncateToDouble() ? '${km.toInt()}km' : '${km}km';
}

String _restLabel(int v) {
  if (v == 0) return 'Sin desc.';
  if (v < 60) return '${v}s';
  final m = v ~/ 60;
  final s = v % 60;
  return s > 0 ? "${m}' ${s}s" : "${m}'";
}

Color _zoneColor(int zone) {
  switch (zone) {
    case 1: return const Color(0xFF5A9E9E); // Z1 cyan-teal
    case 2: return AppColors.rpeLow;        // Z2 green
    case 3: return AppColors.rpeMid;        // Z3 amber
    case 4: return AppColors.effort;        // Z4 orange-red
    case 5: return AppColors.rpeMax;        // Z5 red
    default: return const Color(0xFF8E8E93);
  }
}

String _zoneLabel(int zone) {
  switch (zone) {
    case 1: return 'Z1 · Regenerativo';
    case 2: return 'Z2 · Base aeróbica';
    case 3: return 'Z3 · Umbral';
    case 4: return 'Z4 · VO2max';
    case 5: return 'Z5 · Máximo';
    default: return 'Z$zone';
  }
}

// ── SessionBlockData ──────────────────────────────────────────────────────────

class SessionBlockData {
  final String id;
  int? distanceM;
  int? durationMinutes;
  int? durationSeconds;
  int? paceMinutes;
  int? paceSeconds;
  int? paceMaxMinutes;
  int? paceMaxSeconds;
  double? rpe;
  int? restSeconds;
  int? zone; // 1-5

  SessionBlockData({
    required this.id,
    this.distanceM,
    this.durationMinutes,
    this.durationSeconds,
    this.paceMinutes,
    this.paceSeconds,
    this.paceMaxMinutes,
    this.paceMaxSeconds,
    this.rpe,
    this.restSeconds,
    this.zone,
  });

  SessionBlockData copyWith({
    int? distanceM,
    int? durationMinutes,
    int? durationSeconds,
    int? paceMinutes,
    int? paceSeconds,
    int? paceMaxMinutes,
    int? paceMaxSeconds,
    double? rpe,
    int? restSeconds,
    int? zone,
  }) => SessionBlockData(
        id:              id,
        distanceM:       distanceM       ?? this.distanceM,
        durationMinutes: durationMinutes ?? this.durationMinutes,
        durationSeconds: durationSeconds ?? this.durationSeconds,
        paceMinutes:     paceMinutes     ?? this.paceMinutes,
        paceSeconds:     paceSeconds     ?? this.paceSeconds,
        paceMaxMinutes:  paceMaxMinutes  ?? this.paceMaxMinutes,
        paceMaxSeconds:  paceMaxSeconds  ?? this.paceMaxSeconds,
        rpe:             rpe             ?? this.rpe,
        restSeconds:     restSeconds     ?? this.restSeconds,
        zone:            zone            ?? this.zone,
      );
}

// ── SessionPlannerView ────────────────────────────────────────────────────────

class SessionPlannerView extends StatefulWidget {
  final String uid;
  final DateTime initialDate;

  const SessionPlannerView({
    super.key,
    required this.uid,
    required this.initialDate,
  });

  @override
  State<SessionPlannerView> createState() => _SessionPlannerViewState();
}

class _SessionPlannerViewState extends State<SessionPlannerView> {
  late DateTime _selectedDate;
  TimeOfDay? _selectedTime;
  final List<SessionBlockData> _blocks = [];
  bool _saving = false;

  final _repo = AthleteSessionRepository();

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.initialDate;
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  String _formatFullDate(DateTime d) {
    const weekdays = [
      '', 'Lunes', 'Martes', 'Miércoles', 'Jueves',
      'Viernes', 'Sábado', 'Domingo',
    ];
    const months = [
      '', 'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio',
      'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre',
    ];
    return '${weekdays[d.weekday]}, ${d.day} de ${months[d.month]} de ${d.year}';
  }

  String _formatTime(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  String _normalizeDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  // ── Actions ───────────────────────────────────────────────────────────────

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context:     context,
      initialDate: _selectedDate,
      firstDate:   DateTime(2020),
      lastDate:    DateTime(2027),
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

  void _addBlock() {
    setState(() => _blocks.add(SessionBlockData(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
        )));
  }

  void _duplicateBlock(SessionBlockData block) {
    final idx = _blocks.indexWhere((b) => b.id == block.id);
    if (idx == -1) return;
    setState(() => _blocks.insert(
          idx + 1,
          SessionBlockData(
            id:              DateTime.now().millisecondsSinceEpoch.toString(),
            distanceM:       block.distanceM,
            durationMinutes: block.durationMinutes,
            durationSeconds: block.durationSeconds,
            paceMinutes:     block.paceMinutes,
            paceSeconds:     block.paceSeconds,
            paceMaxMinutes:  block.paceMaxMinutes,
            paceMaxSeconds:  block.paceMaxSeconds,
            rpe:             block.rpe,
            restSeconds:     block.restSeconds,
            zone:            block.zone,
          ),
        ));
  }

  void _deleteBlock(String id) {
    setState(() => _blocks.removeWhere((b) => b.id == id));
  }

  void _updateBlock(SessionBlockData updated) {
    final idx = _blocks.indexWhere((b) => b.id == updated.id);
    if (idx == -1) return;
    setState(() => _blocks[idx] = updated);
  }

  Future<void> _saveSession() async {
    if (_blocks.isEmpty) {
      ModernSnackBar.showError(context, 'Añade al menos una serie');
      return;
    }
    setState(() => _saving = true);

    try {
      final now    = DateTime.now();
      final blocks = _blocks.asMap().entries.map((e) {
        final i = e.key;
        final b = e.value;
        final hasDistance = b.distanceM != null && b.distanceM! > 0;
        // Convert duration to minutes (round seconds up)
        int? totalDurMin;
        if (!hasDistance &&
            (b.durationMinutes != null || b.durationSeconds != null)) {
          final m = b.durationMinutes ?? 0;
          final s = b.durationSeconds ?? 0;
          totalDurMin = m + (s > 0 ? 1 : 0);
        }
        return SessionBlock(
          id:               b.id,
          order:            i,
          type:             hasDistance
              ? SessionBlockType.series
              : SessionBlockType.continuousTime,
          reps:             hasDistance ? 1 : null,
          distanceM:        hasDistance ? b.distanceM : null,
          durationMinutes:  !hasDistance ? totalDurMin : null,
          restSeconds:      b.restSeconds,
          targetPaceMinMin: b.paceMinutes,
          targetPaceMinSec: b.paceSeconds,
          targetRpe:        b.rpe,
          targetZone:       b.zone,
        );
      }).toList();

      final session = AthleteSession(
        id:        '',
        uid:       widget.uid,
        date:      _normalizeDate(_selectedDate),
        time:      _selectedTime != null ? _formatTime(_selectedTime!) : null,
        status:    AthleteSessionStatus.planned,
        blocks:    blocks,
        createdAt: now,
        updatedAt: now,
      );

      await _repo.createSession(session);
      if (!mounted) return;

      if (_selectedTime != null) {
        final sessionDateTime = DateTime(
          _selectedDate.year,
          _selectedDate.month,
          _selectedDate.day,
          _selectedTime!.hour,
          _selectedTime!.minute,
        );
        final title = session.blocks.isNotEmpty ? 'Sesión planificada' : 'Sesión planificada';
        NotificationService().scheduleSessionReminder(
          sessionId: session.id.isEmpty
              ? DateTime.now().millisecondsSinceEpoch.toString()
              : session.id,
          sessionDateTime: sessionDateTime,
          sessionTitle: title,
        ).catchError((e) => debugPrint('schedule reminder error: $e'));
      }

      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ModernSnackBar.showError(context, 'Error al guardar la sesión');
    }
  }

  Future<void> _saveAsTemplate() async {
    if (_blocks.isEmpty) {
      ModernSnackBar.showError(context, 'Añade al menos una serie antes de guardar');
      return;
    }
    final isDark = Theme.of(context).brightness == Brightness.dark;
    await showModalBottomSheet<void>(
      context:            context,
      backgroundColor:    Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _SaveTemplateSheet(
        isDark:  isDark,
        onSave:  (name) => _doSaveTemplate(name),
      ),
    );
  }

  Future<void> _doSaveTemplate(String name) async {
    try {
      final tBlocks = _blocks.asMap().entries.map((e) {
        final b = e.value;
        final isDistance = b.distanceM != null;
        return TemplateBlock(
          id:    b.id,
          order: e.key,
          type:  isDistance
              ? TemplateBlockType.distance
              : TemplateBlockType.time,
          value: isDistance
              ? b.distanceM!
              : (b.durationMinutes ?? 0) * 60 + (b.durationSeconds ?? 0),
          restSeconds: b.restSeconds ?? 0,
          alerts: TemplateAlerts(
            enabled:         false,
            mode:            'pace',
            timeMin:         0,
            timeSec:         0,
            paceMin:         b.paceMinutes ?? 0,
            paceSec:         b.paceSeconds ?? 0,
            segmentDistance: 0,
          ),
          targetPaceMin: b.paceMinutes,
          targetPaceSec: b.paceSeconds,
          targetRpe:     b.rpe,
          targetZone:    b.zone,
        );
      }).toList();

      final now = DateTime.now();
      final template = TrainingTemplate(
        id:               now.millisecondsSinceEpoch.toString(),
        name:             name,
        colorValue:       AppColors.brandPurple.value,
        isWarmupCooldown: false,
        blocks:           tBlocks,
        createdAt:        now,
        updatedAt:        now,
      );

      await TrainingTemplatesRepository().createTemplate(template);
      if (!mounted) return;
      ModernSnackBar.showSuccess(context, 'Plantilla guardada');
    } catch (e) {
      debugPrint('[SessionPlannerView] _doSaveTemplate error: $e');
      if (!mounted) return;
      ModernSnackBar.showError(context, 'Error al guardar');
    }
  }

  Future<void> _loadTemplate() async {
    List<TrainingTemplate> templates;
    try {
      final all = await TrainingTemplatesRepository().getUserTemplates();
      templates = all.where((t) => !t.isWarmupCooldown).toList();
    } catch (e) {
      debugPrint('[SessionPlannerView] _loadTemplate fetch error: $e');
      if (!mounted) return;
      ModernSnackBar.showError(context, 'Error al cargar plantillas');
      return;
    }
    if (!mounted) return;

    if (templates.isEmpty) {
      ModernSnackBar.showError(context, 'No tienes plantillas guardadas');
      return;
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final selected = await showModalBottomSheet<TrainingTemplate>(
      context:            context,
      backgroundColor:    Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _LoadTemplateSheet(
        isDark:    isDark,
        templates: templates,
      ),
    );
    if (!mounted || selected == null) return;

    if (_blocks.isNotEmpty) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('¿Reemplazar sesión actual?'),
          content: const Text(
              'Se reemplazarán las series actuales con las de la plantilla.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                  backgroundColor: AppColors.brandPurple),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Reemplazar'),
            ),
          ],
        ),
      );
      if (!mounted || confirmed != true) return;
    }

    setState(() {
      _blocks.clear();
      _blocks.addAll(selected.blocks.map((b) {
        final isDistance = b.type == TemplateBlockType.distance;
        return SessionBlockData(
          id:              '${DateTime.now().millisecondsSinceEpoch}${b.id}',
          distanceM:       isDistance ? b.value : null,
          durationMinutes: !isDistance ? b.value ~/ 60 : null,
          durationSeconds: !isDistance ? b.value % 60  : null,
          paceMinutes:     b.targetPaceMin,
          paceSeconds:     b.targetPaceSec,
          rpe:             b.targetRpe,
          restSeconds:     b.restSeconds,
          zone:            b.targetZone,
        );
      }));
    });
    if (!mounted) return;
    ModernSnackBar.showSuccess(context, 'Plantilla cargada');
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDark      = Theme.of(context).brightness == Brightness.dark;
    final bgColor     = isDark ? const Color(0xFF1C1C1E) : Colors.white;
    final titleColor  = isDark ? Colors.white : const Color(0xFF1C1C1E);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation:       0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: AppColors.brandPurple),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Nueva sesión',
          style: TextStyle(
            fontSize:   17,
            fontWeight: FontWeight.w600,
            color:      titleColor,
          ),
        ),
        actions: [
          _saving
              ? const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Center(
                    child: SizedBox(
                      width:  20,
                      height: 20,
                      child:  CircularProgressIndicator(
                        strokeWidth: 2,
                        color:       AppColors.brandPurple,
                      ),
                    ),
                  ),
                )
              : TextButton(
                  onPressed: _saveSession,
                  child: const Text(
                    'Guardar',
                    style: TextStyle(
                      color:      AppColors.brandPurple,
                      fontSize:   15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Cuándo ──────────────────────────────────────────────────────
            _SectionHeader('CUÁNDO'),
            _FieldRow(
              icon:  Icons.calendar_today_rounded,
              label: _formatFullDate(_selectedDate),
              onTap: _pickDate,
              isDark: isDark,
            ),
            _FieldRow(
              icon:       Icons.notifications_outlined,
              label:      _selectedTime != null
                  ? 'Notificación a las ${_formatTime(_selectedTime!)}'
                  : 'Añadir recordatorio',
              labelColor: _selectedTime == null
                  ? const Color(0xFF8E8E93)
                  : null,
              onTap: _pickTime,
              isDark: isDark,
              trailing: _selectedTime != null
                  ? IconButton(
                      icon:           const Icon(Icons.close, size: 18),
                      color:          const Color(0xFF8E8E93),
                      visualDensity:  VisualDensity.compact,
                      padding:        EdgeInsets.zero,
                      onPressed:      () =>
                          setState(() => _selectedTime = null),
                    )
                  : null,
            ),

            // ── Entrenamiento ────────────────────────────────────────────────
            _SectionHeader('ENTRENAMIENTO'),
            ListView.builder(
              shrinkWrap: true,
              physics:    const NeverScrollableScrollPhysics(),
              itemCount:  _blocks.length,
              itemBuilder: (_, i) => _BlockRow(
                block:       _blocks[i],
                index:       i,
                isDark:      isDark,
                onDelete:    _deleteBlock,
                onDuplicate: _duplicateBlock,
                onChanged:   _updateBlock,
              ),
            ),
            GestureDetector(
              onTap: _addBlock,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Row(
                  children: const [
                    Icon(Icons.add_circle_rounded,
                        color: AppColors.brandPurple),
                    SizedBox(width: 8),
                    Text(
                      'Añadir serie',
                      style: TextStyle(
                          fontSize: 15, color: AppColors.brandPurple),
                    ),
                  ],
                ),
              ),
            ),

            // ── Plantillas ────────────────────────────────────────────────
            _SectionHeader('PLANTILLAS'),
            _ActionRow(
              icon:   Icons.upload_rounded,
              label:  'Guardar como plantilla',
              onTap:  _saveAsTemplate,
              isDark: isDark,
            ),
            _ActionRow(
              icon:   Icons.download_rounded,
              label:  'Cargar plantilla',
              onTap:  _loadTemplate,
              isDark: isDark,
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _SectionHeader
// ─────────────────────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String label;
  const _SectionHeader(this.label);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 8),
      child: Text(
        label,
        style: const TextStyle(
          fontSize:      12,
          fontWeight:    FontWeight.w600,
          letterSpacing: 0.8,
          color:         Color(0xFF8E8E93),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _FieldRow
// ─────────────────────────────────────────────────────────────────────────────

class _FieldRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? labelColor;
  final VoidCallback onTap;
  final Widget? trailing;
  final bool isDark;

  const _FieldRow({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.isDark,
    this.labelColor,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final dividerColor =
        isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE5E5EA);
    final textColor = labelColor ??
        (isDark ? Colors.white : const Color(0xFF1C1C1E));

    return InkWell(
      onTap: onTap,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Row(
              children: [
                Icon(icon, size: 20, color: AppColors.brandPurple),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(label,
                      style: TextStyle(fontSize: 15, color: textColor)),
                ),
                if (trailing != null) trailing!,
              ],
            ),
          ),
          Divider(height: 1, thickness: 1, color: dividerColor),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _ActionRow
// ─────────────────────────────────────────────────────────────────────────────

class _ActionRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isDark;

  const _ActionRow({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final dividerColor =
        isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE5E5EA);
    final textColor =
        isDark ? Colors.white : const Color(0xFF1C1C1E);

    return InkWell(
      onTap: onTap,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Row(
              children: [
                Icon(icon, size: 20, color: const Color(0xFF8E8E93)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(label,
                      style: TextStyle(fontSize: 15, color: textColor)),
                ),
              ],
            ),
          ),
          Divider(height: 1, thickness: 1, color: dividerColor),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _BlockRow
// ─────────────────────────────────────────────────────────────────────────────

class _BlockRow extends StatelessWidget {
  final SessionBlockData block;
  final int index;
  final bool isDark;
  final void Function(String id) onDelete;
  final void Function(SessionBlockData block) onDuplicate;
  final void Function(SessionBlockData block) onChanged;

  const _BlockRow({
    required this.block,
    required this.index,
    required this.isDark,
    required this.onDelete,
    required this.onDuplicate,
    required this.onChanged,
  });

  // Display strings ──────────────────────────────────────────────────────────

  String get _distanceDisplay {
    final d = block.distanceM;
    if (d == null) return '—';
    return _distanceLabel(d);
  }

  String get _durationDisplay {
    final m = block.durationMinutes;
    final s = block.durationSeconds ?? 0;
    if (m == null) return '—';
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  String get _paceDisplay {
    final m = block.paceMinutes;
    final s = block.paceSeconds ?? 0;
    if (m == null) return '—';
    final minStr = '$m:${s.toString().padLeft(2, '0')}';
    final mMax = block.paceMaxMinutes;
    if (mMax != null) {
      final sMax = block.paceMaxSeconds ?? 0;
      return '$minStr–$mMax:${sMax.toString().padLeft(2, '0')} /km';
    }
    return '$minStr /km';
  }

  String get _rpeDisplay {
    final r = block.rpe;
    if (r == null) return '—';
    return r == r.truncateToDouble() ? r.toInt().toString() : r.toString();
  }

  String get _restDisplay {
    final r = block.restSeconds;
    if (r == null) return '—';
    return _restLabel(r);
  }

  String get _zoneDisplay {
    final z = block.zone;
    if (z == null) return '—';
    return 'Z$z';
  }

  // Pickers ──────────────────────────────────────────────────────────────────

  Future<void> _openDistancePicker(BuildContext context) async {
    final result = await showModalBottomSheet<int>(
      context:           context,
      backgroundColor:   Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _DistancePickerSheet(initial: block.distanceM),
    );
    if (result != null) {
      onChanged(block.copyWith(distanceM: result));
    }
  }

  Future<void> _openDurationPicker(BuildContext context) async {
    final result = await showModalBottomSheet<(int, int)>(
      context:           context,
      backgroundColor:   Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _DurationPickerSheet(
        initialMinutes: block.durationMinutes,
        initialSeconds: block.durationSeconds,
      ),
    );
    if (result != null) {
      onChanged(block.copyWith(
        durationMinutes: result.$1,
        durationSeconds: result.$2,
      ));
    }
  }

  Future<void> _openPacePicker(BuildContext context) async {
    final result = await showModalBottomSheet<(int, int, int?, int?)>(
      context:            context,
      backgroundColor:    Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _PacePickerSheet(
        initialMinutes:    block.paceMinutes,
        initialSeconds:    block.paceSeconds,
        initialMaxMinutes: block.paceMaxMinutes,
        initialMaxSeconds: block.paceMaxSeconds,
      ),
    );
    if (result != null) {
      onChanged(block.copyWith(
        paceMinutes:    result.$1,
        paceSeconds:    result.$2,
        paceMaxMinutes: result.$3,
        paceMaxSeconds: result.$4,
      ));
    }
  }

  Future<void> _openRpePicker(BuildContext context) async {
    final result = await showModalBottomSheet<double>(
      context:           context,
      backgroundColor:   Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _RpePickerSheet(initial: block.rpe),
    );
    if (result != null) {
      onChanged(block.copyWith(rpe: result));
    }
  }

  Future<void> _openRestPicker(BuildContext context) async {
    final result = await showModalBottomSheet<int>(
      context:           context,
      backgroundColor:   Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _RestPickerSheet(initial: block.restSeconds),
    );
    if (result != null) {
      onChanged(block.copyWith(restSeconds: result));
    }
  }

  Future<void> _openZonePicker(BuildContext context) async {
    final result = await showModalBottomSheet<int>(
      context:           context,
      backgroundColor:   Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _ZonePickerSheet(initial: block.zone),
    );
    if (result != null) {
      onChanged(block.copyWith(zone: result));
    }
  }

  @override
  Widget build(BuildContext context) {
    final cardColor =
        isDark ? const Color(0xFF2C2C2E) : const Color(0xFFF2F2F7);

    return Card(
      color:     cardColor,
      shape:     RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin:    const EdgeInsets.symmetric(vertical: 4),
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(
              children: [
                Text(
                  'Serie ${index + 1}',
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w600),
                ),
                const Spacer(),
                IconButton(
                  icon:          const Icon(Icons.drag_handle_rounded),
                  color:         const Color(0xFF8E8E93),
                  iconSize:      20,
                  visualDensity: VisualDensity.compact,
                  padding:       EdgeInsets.zero,
                  onPressed:     () {},
                ),
                IconButton(
                  icon:          const Icon(Icons.copy_rounded),
                  color:         const Color(0xFF8E8E93),
                  iconSize:      20,
                  visualDensity: VisualDensity.compact,
                  padding:       EdgeInsets.zero,
                  onPressed:     () => onDuplicate(block),
                ),
                IconButton(
                  icon:          const Icon(Icons.delete_outline_rounded),
                  color:         const Color(0xFF8E8E93),
                  iconSize:      20,
                  visualDensity: VisualDensity.compact,
                  padding:       EdgeInsets.zero,
                  onPressed:     () => onDelete(block.id),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Fields grid — tappable chips
            Wrap(
              spacing:    8,
              runSpacing: 8,
              children: [
                _PickerChip(
                  label:   'Distancia',
                  value:   _distanceDisplay,
                  isDark:  isDark,
                  onTap:   () => _openDistancePicker(context),
                ),
                _PickerChip(
                  label:   'Duración',
                  value:   _durationDisplay,
                  isDark:  isDark,
                  onTap:   () => _openDurationPicker(context),
                ),
                _PickerChip(
                  label:   'Pace',
                  value:   _paceDisplay,
                  isDark:  isDark,
                  onTap:   () => _openPacePicker(context),
                ),
                _PickerChip(
                  label:   'RPE',
                  value:   _rpeDisplay,
                  isDark:  isDark,
                  onTap:   () => _openRpePicker(context),
                ),
                _PickerChip(
                  label:   'Descanso',
                  value:   _restDisplay,
                  isDark:  isDark,
                  onTap:   () => _openRestPicker(context),
                ),
                _PickerChip(
                  label:   'Zona FC',
                  value:   _zoneDisplay,
                  isDark:  isDark,
                  onTap:   () => _openZonePicker(context),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _PickerChip  (tappable display cell — replaces _MiniField)
// ─────────────────────────────────────────────────────────────────────────────

class _PickerChip extends StatelessWidget {
  final String label;
  final String value;
  final bool isDark;
  final VoidCallback onTap;

  const _PickerChip({
    required this.label,
    required this.value,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor    = isDark ? const Color(0xFF3A3A3C) : Colors.white;
    final labelColor = isDark ? const Color(0xFF8E8E93) : const Color(0xFF6C6C70);
    final valueColor = value == '—'
        ? labelColor
        : (isDark ? Colors.white : const Color(0xFF1C1C1E));

    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 110,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w500, color: labelColor),
            ),
            const SizedBox(height: 4),
            Container(
              width:   110,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              decoration: BoxDecoration(
                color:        bgColor,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                value,
                style: TextStyle(fontSize: 14, color: valueColor),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _SheetContainer  (shared bottom-sheet wrapper)
// ─────────────────────────────────────────────────────────────────────────────

class _SheetContainer extends StatelessWidget {
  final double height;
  final Widget child;

  const _SheetContainer({required this.height, required this.child});

  @override
  Widget build(BuildContext context) {
    final isDark   = Theme.of(context).brightness == Brightness.dark;
    final bgColor  = isDark ? const Color(0xFF1C1C1E) : Colors.white;

    return Container(
      height:      height,
      margin:      const EdgeInsets.all(12),
      decoration:  BoxDecoration(
        color:        bgColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: child,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _DistancePickerSheet
// ─────────────────────────────────────────────────────────────────────────────

class _DistancePickerSheet extends StatefulWidget {
  final int? initial;
  const _DistancePickerSheet({this.initial});

  @override
  State<_DistancePickerSheet> createState() => _DistancePickerSheetState();
}

class _DistancePickerSheetState extends State<_DistancePickerSheet> {
  late int _selectedIndex; // index into _standardDistances, or last = "Otra"

  @override
  void initState() {
    super.initState();
    if (widget.initial != null) {
      final idx = _standardDistances.indexOf(widget.initial!);
      _selectedIndex = idx >= 0 ? idx : _standardDistances.length - 1;
    } else {
      _selectedIndex = 0;
    }
  }

  String _itemLabel(int m) => _distanceLabel(m);

  Future<void> _openCustom() async {
    Navigator.pop(context); // close this sheet first

    final ctrl = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Distancia personalizada'),
        content: TextField(
          controller:   ctrl,
          autofocus:    true,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            hintText: 'Metros (ej. 7500)',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: AppColors.brandPurple),
            onPressed: () {
              final v = int.tryParse(ctrl.text.trim());
              Navigator.pop(ctx);
              if (v != null && v > 0 && context.mounted) {
                Navigator.pop(context, v);
              }
            },
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark      = Theme.of(context).brightness == Brightness.dark;
    final labelColor  = isDark ? Colors.white : const Color(0xFF1C1C1E);
    final totalItems  = _standardDistances.length + 1; // +1 for "Otra"

    return _SheetContainer(
      height: 300,
      child: Column(
        children: [
          const SizedBox(height: 12),
          Text(
            'Distancia',
            style: TextStyle(
                fontSize: 15, fontWeight: FontWeight.w600, color: labelColor),
          ),
          Expanded(
            child: CupertinoPicker(
              scrollController: FixedExtentScrollController(
                  initialItem: _selectedIndex),
              itemExtent: 40,
              onSelectedItemChanged: (i) {
                setState(() => _selectedIndex = i);
              },
              children: [
                ...(_standardDistances.map((d) => Center(
                      child: Text(
                        _itemLabel(d),
                        style: TextStyle(fontSize: 18, color: labelColor),
                      ),
                    ))),
                Center(
                  child: Text(
                    'Otra distancia →',
                    style: TextStyle(
                        fontSize: 18, color: AppColors.brandPurple),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(
                    backgroundColor: AppColors.brandPurple),
                onPressed: () {
                  if (_selectedIndex == _standardDistances.length) {
                    _openCustom();
                  } else {
                    Navigator.pop(
                        context, _standardDistances[_selectedIndex]);
                  }
                },
                child: const Text('Confirmar'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _DurationPickerSheet
// ─────────────────────────────────────────────────────────────────────────────

class _DurationPickerSheet extends StatefulWidget {
  final int? initialMinutes;
  final int? initialSeconds;
  const _DurationPickerSheet({this.initialMinutes, this.initialSeconds});

  @override
  State<_DurationPickerSheet> createState() => _DurationPickerSheetState();
}

class _DurationPickerSheetState extends State<_DurationPickerSheet> {
  late int _minutes;
  late int _seconds; // 0, 15, 30, 45

  static const List<int> _secValues = [0, 15, 30, 45];

  @override
  void initState() {
    super.initState();
    _minutes = (widget.initialMinutes ?? 0).clamp(0, 180);
    final s   = widget.initialSeconds ?? 0;
    _seconds = _secValues.contains(s) ? s : 0;
  }

  @override
  Widget build(BuildContext context) {
    final isDark     = Theme.of(context).brightness == Brightness.dark;
    final textColor  = isDark ? Colors.white : const Color(0xFF1C1C1E);
    final hintColor  = isDark ? const Color(0xFF8E8E93) : const Color(0xFF6C6C70);

    return _SheetContainer(
      height: 300,
      child: Column(
        children: [
          const SizedBox(height: 12),
          Text(
            'Duración',
            style: TextStyle(
                fontSize: 15, fontWeight: FontWeight.w600, color: textColor),
          ),
          Expanded(
            child: Row(
              children: [
                // Minutes
                Expanded(
                  child: Column(
                    children: [
                      Expanded(
                        child: CupertinoPicker(
                          scrollController: FixedExtentScrollController(
                              initialItem: _minutes),
                          itemExtent: 40,
                          onSelectedItemChanged: (i) =>
                              setState(() => _minutes = i),
                          children: List.generate(
                            181,
                            (i) => Center(
                              child: Text(
                                '$i',
                                style: TextStyle(
                                    fontSize: 18, color: textColor),
                              ),
                            ),
                          ),
                        ),
                      ),
                      Text('min',
                          style:
                              TextStyle(fontSize: 13, color: hintColor)),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
                // Seconds
                Expanded(
                  child: Column(
                    children: [
                      Expanded(
                        child: CupertinoPicker(
                          scrollController: FixedExtentScrollController(
                              initialItem:
                                  _secValues.indexOf(_seconds)),
                          itemExtent: 40,
                          onSelectedItemChanged: (i) =>
                              setState(() => _seconds = _secValues[i]),
                          children: _secValues
                              .map((s) => Center(
                                    child: Text(
                                      s.toString().padLeft(2, '0'),
                                      style: TextStyle(
                                          fontSize: 18, color: textColor),
                                    ),
                                  ))
                              .toList(),
                        ),
                      ),
                      Text('seg',
                          style:
                              TextStyle(fontSize: 13, color: hintColor)),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(
                    backgroundColor: AppColors.brandPurple),
                onPressed: () =>
                    Navigator.pop(context, (_minutes, _seconds)),
                child: const Text('Confirmar'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _PacePickerSheet
// ─────────────────────────────────────────────────────────────────────────────

class _PacePickerSheet extends StatefulWidget {
  final int? initialMinutes;
  final int? initialSeconds;
  final int? initialMaxMinutes;
  final int? initialMaxSeconds;

  const _PacePickerSheet({
    this.initialMinutes,
    this.initialSeconds,
    this.initialMaxMinutes,
    this.initialMaxSeconds,
  });

  @override
  State<_PacePickerSheet> createState() => _PacePickerSheetState();
}

class _PacePickerSheetState extends State<_PacePickerSheet> {
  late int _minIdx;
  late int _secIdx;
  late int _maxMinIdx;
  late int _maxSecIdx;
  late bool _hasMax;

  @override
  void initState() {
    super.initState();
    final m   = widget.initialMinutes ?? 5;
    final s   = widget.initialSeconds ?? 0;
    _minIdx   = _paceMinValues.indexOf(m);
    _secIdx   = _paceSecValues.indexOf(s);
    if (_minIdx < 0) _minIdx = _paceMinValues.indexOf(5);
    if (_secIdx < 0) _secIdx = 0;

    _hasMax = widget.initialMaxMinutes != null;
    final mMax = widget.initialMaxMinutes ?? 5;
    final sMax = widget.initialMaxSeconds ?? 30;
    _maxMinIdx = _paceMinValues.indexOf(mMax);
    _maxSecIdx = _paceSecValues.indexOf(sMax);
    if (_maxMinIdx < 0) _maxMinIdx = _paceMinValues.indexOf(5);
    if (_maxSecIdx < 0) _maxSecIdx = 6; // 30s
  }

  Widget _buildPairPickers(
    BuildContext context, {
    required int minIdx,
    required int secIdx,
    required void Function(int) onMinChanged,
    required void Function(int) onSecChanged,
    required Color textColor,
    required Color hintColor,
  }) {
    return Row(
      children: [
        Expanded(
          child: Column(
            children: [
              Expanded(
                child: CupertinoPicker(
                  scrollController:
                      FixedExtentScrollController(initialItem: minIdx),
                  itemExtent: 40,
                  onSelectedItemChanged: onMinChanged,
                  children: _paceMinValues
                      .map((v) => Center(
                            child: Text('$v',
                                style: TextStyle(
                                    fontSize: 18, color: textColor)),
                          ))
                      .toList(),
                ),
              ),
              Text('min',
                  style: TextStyle(fontSize: 13, color: hintColor)),
              const SizedBox(height: 4),
            ],
          ),
        ),
        Expanded(
          child: Column(
            children: [
              Expanded(
                child: CupertinoPicker(
                  scrollController:
                      FixedExtentScrollController(initialItem: secIdx),
                  itemExtent: 40,
                  onSelectedItemChanged: onSecChanged,
                  children: _paceSecValues
                      .map((v) => Center(
                            child: Text(
                              v.toString().padLeft(2, '0'),
                              style: TextStyle(
                                  fontSize: 18, color: textColor),
                            ),
                          ))
                      .toList(),
                ),
              ),
              Text('seg /km',
                  style: TextStyle(fontSize: 13, color: hintColor)),
              const SizedBox(height: 4),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark    = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : const Color(0xFF1C1C1E);
    final hintColor = isDark ? const Color(0xFF8E8E93) : const Color(0xFF6C6C70);
    final bgColor   = isDark ? const Color(0xFF1C1C1E) : Colors.white;

    final sheetHeight = _hasMax ? 520.0 : 320.0;

    return Container(
      height:     sheetHeight,
      margin:     const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color:        bgColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Text(
            'Pace objetivo',
            style: TextStyle(
                fontSize: 15, fontWeight: FontWeight.w600, color: textColor),
          ),

          // ── Pace mínimo (más rápido) ────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Row(
              children: [
                Text('Mínimo (más rápido)',
                    style: TextStyle(fontSize: 12, color: hintColor)),
              ],
            ),
          ),
          SizedBox(
            height: 140,
            child: _buildPairPickers(
              context,
              minIdx:       _minIdx,
              secIdx:       _secIdx,
              onMinChanged: (i) => setState(() => _minIdx = i),
              onSecChanged: (i) => setState(() => _secIdx = i),
              textColor:    textColor,
              hintColor:    hintColor,
            ),
          ),

          // ── Toggle rango ────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                Text('Añadir pace máximo',
                    style: TextStyle(fontSize: 13, color: textColor)),
                const Spacer(),
                CupertinoSwitch(
                  value:          _hasMax,
                  activeTrackColor: AppColors.brandPurple,
                  onChanged: (v) => setState(() => _hasMax = v),
                ),
              ],
            ),
          ),

          // ── Pace máximo (más lento) ─────────────────────────────
          if (_hasMax) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
              child: Row(
                children: [
                  Text('Máximo (más lento)',
                      style: TextStyle(fontSize: 12, color: hintColor)),
                ],
              ),
            ),
            SizedBox(
              height: 140,
              child: _buildPairPickers(
                context,
                minIdx:       _maxMinIdx,
                secIdx:       _maxSecIdx,
                onMinChanged: (i) => setState(() => _maxMinIdx = i),
                onSecChanged: (i) => setState(() => _maxSecIdx = i),
                textColor:    textColor,
                hintColor:    hintColor,
              ),
            ),
          ],

          const Spacer(),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(
                    backgroundColor: AppColors.brandPurple),
                onPressed: () => Navigator.pop(
                  context,
                  (
                    _paceMinValues[_minIdx],
                    _paceSecValues[_secIdx],
                    _hasMax ? _paceMinValues[_maxMinIdx] : null,
                    _hasMax ? _paceSecValues[_maxSecIdx] : null,
                  ),
                ),
                child: const Text('Confirmar'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _RpePickerSheet
// ─────────────────────────────────────────────────────────────────────────────

class _RpePickerSheet extends StatefulWidget {
  final double? initial;
  const _RpePickerSheet({this.initial});

  @override
  State<_RpePickerSheet> createState() => _RpePickerSheetState();
}

class _RpePickerSheetState extends State<_RpePickerSheet> {
  late int _idx;

  @override
  void initState() {
    super.initState();
    final v  = widget.initial ?? 5.0;
    _idx     = _rpeValues.indexOf(v);
    if (_idx < 0) _idx = _rpeValues.indexOf(5.0);
  }

  Color _rpeColor(double v) {
    if (v <= 3) return AppColors.rpeLow;
    if (v <= 6) return AppColors.rpeMid;
    if (v <= 8) return AppColors.effort;
    return AppColors.rpeMax;
  }

  @override
  Widget build(BuildContext context) {
    final isDark      = Theme.of(context).brightness == Brightness.dark;
    final defaultColor = isDark ? Colors.white : const Color(0xFF1C1C1E);

    return _SheetContainer(
      height: 300,
      child: Column(
        children: [
          const SizedBox(height: 12),
          Text(
            'RPE (esfuerzo percibido)',
            style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: defaultColor),
          ),
          Expanded(
            child: CupertinoPicker(
              scrollController:
                  FixedExtentScrollController(initialItem: _idx),
              itemExtent: 40,
              onSelectedItemChanged: (i) => setState(() => _idx = i),
              children: _rpeValues.map((v) {
                final isSelected = _rpeValues[_idx] == v;
                final color =
                    isSelected ? _rpeColor(v) : defaultColor;
                final label = v == v.truncateToDouble()
                    ? v.toInt().toString()
                    : v.toString();
                return Center(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize:   18,
                      fontWeight: isSelected
                          ? FontWeight.w700
                          : FontWeight.w400,
                      color: color,
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(
                    backgroundColor: AppColors.brandPurple),
                onPressed: () =>
                    Navigator.pop(context, _rpeValues[_idx]),
                child: const Text('Listo'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _RestPickerSheet
// ─────────────────────────────────────────────────────────────────────────────

class _RestPickerSheet extends StatefulWidget {
  final int? initial;
  const _RestPickerSheet({this.initial});

  @override
  State<_RestPickerSheet> createState() => _RestPickerSheetState();
}

class _RestPickerSheetState extends State<_RestPickerSheet> {
  late int _idx;

  @override
  void initState() {
    super.initState();
    final v  = widget.initial ?? 60;
    _idx     = _restValues.indexOf(v);
    if (_idx < 0) _idx = _restValues.indexOf(60);
  }

  @override
  Widget build(BuildContext context) {
    final isDark      = Theme.of(context).brightness == Brightness.dark;
    final textColor   = isDark ? Colors.white : const Color(0xFF1C1C1E);

    return _SheetContainer(
      height: 300,
      child: Column(
        children: [
          const SizedBox(height: 12),
          Text(
            'Descanso entre series',
            style: TextStyle(
                fontSize: 15, fontWeight: FontWeight.w600, color: textColor),
          ),
          Expanded(
            child: CupertinoPicker(
              scrollController:
                  FixedExtentScrollController(initialItem: _idx),
              itemExtent: 40,
              onSelectedItemChanged: (i) => setState(() => _idx = i),
              children: _restValues
                  .map((v) => Center(
                        child: Text(
                          _restLabel(v),
                          style:
                              TextStyle(fontSize: 18, color: textColor),
                        ),
                      ))
                  .toList(),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(
                    backgroundColor: AppColors.brandPurple),
                onPressed: () =>
                    Navigator.pop(context, _restValues[_idx]),
                child: const Text('Listo'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _SaveTemplateSheet
// ─────────────────────────────────────────────────────────────────────────────

class _SaveTemplateSheet extends StatefulWidget {
  final bool isDark;
  final Future<void> Function(String name) onSave;

  const _SaveTemplateSheet({required this.isDark, required this.onSave});

  @override
  State<_SaveTemplateSheet> createState() => _SaveTemplateSheetState();
}

class _SaveTemplateSheetState extends State<_SaveTemplateSheet> {
  final _ctrl = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bgColor     = widget.isDark ? const Color(0xFF1C1C1E) : Colors.white;
    final titleColor  = widget.isDark ? Colors.white : const Color(0xFF1C1C1E);
    final fieldColor  = widget.isDark ? const Color(0xFF2C2C2E) : const Color(0xFFF2F2F7);

    return Container(
      margin:     const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color:        bgColor,
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Guardar plantilla',
            style: TextStyle(
                fontSize: 17, fontWeight: FontWeight.w600, color: titleColor),
          ),
          const SizedBox(height: 8),
          const Text(
            'Los bloques actuales se guardarán como plantilla',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: Color(0xFF8E8E93)),
          ),
          const SizedBox(height: 20),
          TextField(
            controller:           _ctrl,
            autofocus:            true,
            textCapitalization:   TextCapitalization.sentences,
            style:                TextStyle(color: titleColor),
            decoration: InputDecoration(
              filled:      true,
              fillColor:   fieldColor,
              hintText:    'Nombre de la plantilla',
              hintStyle:   const TextStyle(color: Color(0xFF8E8E93)),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide:   BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.brandPurple,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: _saving
                  ? null
                  : () async {
                      final name = _ctrl.text.trim();
                      if (name.isEmpty) return;
                      setState(() => _saving = true);
                      Navigator.pop(context);
                      await widget.onSave(name);
                    },
              child: const Text('Guardar'),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'Cancelar',
                style: TextStyle(color: Color(0xFF8E8E93)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _LoadTemplateSheet
// ─────────────────────────────────────────────────────────────────────────────

class _LoadTemplateSheet extends StatelessWidget {
  final bool isDark;
  final List<TrainingTemplate> templates;

  const _LoadTemplateSheet({
    required this.isDark,
    required this.templates,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor    = isDark ? const Color(0xFF1C1C1E) : Colors.white;
    final titleColor = isDark ? Colors.white : const Color(0xFF1C1C1E);
    final divColor   = isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE5E5EA);

    return Container(
      margin:     const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color:        bgColor,
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Cargar plantilla',
            style: TextStyle(
                fontSize: 17, fontWeight: FontWeight.w600, color: titleColor),
          ),
          const SizedBox(height: 4),
          const Text(
            'Selecciona una plantilla para cargar sus series',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: Color(0xFF8E8E93)),
          ),
          const SizedBox(height: 16),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 400),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount:  templates.length,
              itemBuilder: (_, i) {
                final t = templates[i];
                return InkWell(
                  onTap: () => Navigator.pop(context, t),
                  borderRadius: BorderRadius.circular(8),
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            vertical: 12, horizontal: 4),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    t.name,
                                    style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w500,
                                        color: titleColor),
                                  ),
                                  Text(
                                    '${t.blocks.length} series',
                                    style: const TextStyle(
                                        fontSize: 13,
                                        color: Color(0xFF8E8E93)),
                                  ),
                                ],
                              ),
                            ),
                            Icon(Icons.chevron_right_rounded,
                                color: const Color(0xFF8E8E93)),
                          ],
                        ),
                      ),
                      if (i < templates.length - 1)
                        Divider(height: 1, thickness: 1, color: divColor),
                    ],
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'Cancelar',
                style: TextStyle(color: Color(0xFF8E8E93)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _ZonePickerSheet
// ─────────────────────────────────────────────────────────────────────────────

class _ZonePickerSheet extends StatelessWidget {
  final int? initial;
  const _ZonePickerSheet({this.initial});

  @override
  Widget build(BuildContext context) {
    final isDark     = Theme.of(context).brightness == Brightness.dark;
    final bgColor    = isDark ? const Color(0xFF1C1C1E) : Colors.white;
    final titleColor = isDark ? Colors.white : const Color(0xFF1C1C1E);

    return Container(
      margin:     const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color:        bgColor,
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Zona de frecuencia cardíaca',
            style: TextStyle(
                fontSize: 15, fontWeight: FontWeight.w600, color: titleColor),
          ),
          const SizedBox(height: 16),
          ...List.generate(5, (i) {
            final zone      = i + 1;
            final color     = _zoneColor(zone);
            final isSelected = initial == zone;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    backgroundColor:
                        color.withValues(alpha: isSelected ? 0.2 : 0.08),
                    side: BorderSide(
                        color: isSelected
                            ? color
                            : color.withValues(alpha: 0.3),
                        width: isSelected ? 2 : 1),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () => Navigator.pop(context, zone),
                  child: Text(
                    _zoneLabel(zone),
                    style: TextStyle(
                        color: color,
                        fontWeight: isSelected
                            ? FontWeight.w700
                            : FontWeight.w500),
                  ),
                ),
              ),
            );
          }),
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: () => Navigator.pop(context, 0),
              child: const Text(
                'Sin zona',
                style: TextStyle(color: Color(0xFF8E8E93)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
