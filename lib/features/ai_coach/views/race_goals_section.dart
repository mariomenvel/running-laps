import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:running_laps/core/theme/app_colors.dart';
import 'package:running_laps/core/widgets/app_bottom_sheet.dart';
import 'package:running_laps/core/widgets/app_confirm_dialog.dart';
import 'package:running_laps/core/widgets/app_date_picker.dart';
import 'package:running_laps/core/widgets/modern_snackbar.dart';
import 'package:running_laps/core/widgets/number_picker_field.dart';
import 'package:running_laps/features/ai_coach/data/race_goal.dart';
import 'package:running_laps/features/ai_coach/data/race_goal_repository.dart';

/// Sección "Tus objetivos": lista de competiciones marcadas con cuenta atrás
/// + botón para añadir. Fuente única de la fecha objetivo del Coach.
///
/// Se embebe en el hub del Coach (pestaña Planificación). Al tocar una
/// competición se abre el editor; el botón "Añadir" abre el mismo sheet vacío.
class RaceGoalsSection extends StatefulWidget {
  final String uid;

  const RaceGoalsSection({super.key, required this.uid});

  @override
  State<RaceGoalsSection> createState() => _RaceGoalsSectionState();
}

class _RaceGoalsSectionState extends State<RaceGoalsSection> {
  final RaceGoalRepository _repo = RaceGoalRepository();
  late final Stream<List<RaceGoal>> _stream;

  @override
  void initState() {
    super.initState();
    _stream = _repo.streamGoals(uid: widget.uid);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<RaceGoal>>(
      stream: _stream,
      builder: (context, snapshot) {
        final goals =
            (snapshot.data ?? const <RaceGoal>[]).upcomingFrom(DateTime.now());
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  'TUS OBJETIVOS',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.6,
                    color: Color(0xFF8E8E93),
                  ),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: () => showRaceGoalSheet(context, uid: widget.uid),
                  icon: const Icon(Icons.add_rounded,
                      size: 18, color: AppColors.brand),
                  label: const Text(
                    'Añadir',
                    style: TextStyle(
                      color: AppColors.brand,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: const Size(0, 32),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            if (goals.isEmpty)
              _EmptyGoals(
                  onTap: () => showRaceGoalSheet(context, uid: widget.uid))
            else
              ...goals.map(
                (goal) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _RaceGoalCard(
                    goal: goal,
                    onTap: () => showRaceGoalSheet(
                      context,
                      uid: widget.uid,
                      existing: goal,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _EmptyGoals extends StatelessWidget {
  final VoidCallback onTap;

  const _EmptyGoals({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
        decoration: BoxDecoration(
          color: AppColors.surfaceOf(context),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppColors.brand.withValues(alpha: 0.35),
            width: 1,
          ),
        ),
        child: Column(
          children: [
            const Icon(Icons.flag_rounded, color: AppColors.brand, size: 26),
            const SizedBox(height: 8),
            Text(
              '¿Tienes una carrera a la vista?',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary(context),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'Márcala y ajusto tu plan hacia ella',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RaceGoalCard extends StatelessWidget {
  final RaceGoal goal;
  final VoidCallback onTap;

  const _RaceGoalCard({required this.goal, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final date = goal.parsedDate;
    final days = date == null
        ? null
        : DateTime(date.year, date.month, date.day)
            .difference(DateTime(
                DateTime.now().year, DateTime.now().month, DateTime.now().day))
            .inDays;

    // Urgencia del contador (mismo patrón que la card de competición previa).
    final Color badgeBg;
    final Color badgeText;
    if (days != null && days <= 7) {
      badgeBg = AppColors.rpeMax.withValues(alpha: 0.18);
      badgeText = AppColors.rpeMax;
    } else if (days != null && days <= 21) {
      badgeBg = AppColors.effort.withValues(alpha: 0.18);
      badgeText = AppColors.effort;
    } else {
      badgeBg = AppColors.surface2Of(context);
      badgeText = AppColors.textSecondary(context);
    }

    final dateLabel = date != null
        ? DateFormat('d MMM yyyy', 'es_ES').format(date)
        : goal.date;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surfaceOf(context),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.borderOf(context)),
        ),
        child: Row(
          children: [
            Icon(
              goal.priority == RaceGoalPriority.high
                  ? Icons.flag_rounded
                  : Icons.outlined_flag_rounded,
              color: AppColors.effort,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          goal.displayTitle,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary(context),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      _PriorityChip(priority: goal.priority),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    goal.targetTimeSeconds != null
                        ? '$dateLabel · objetivo ${_fmtTime(goal.targetTimeSeconds!)}'
                        : dateLabel,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF8E8E93),
                    ),
                  ),
                ],
              ),
            ),
            if (days != null) ...[
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: badgeBg,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  days == 0 ? 'hoy' : '${days}d',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: badgeText,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PriorityChip extends StatelessWidget {
  final RaceGoalPriority priority;

  const _PriorityChip({required this.priority});

  @override
  Widget build(BuildContext context) {
    final Color color = switch (priority) {
      RaceGoalPriority.high => AppColors.brand,
      RaceGoalPriority.medium => AppColors.effort,
      RaceGoalPriority.low => AppColors.textSecondary(context),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        priority.label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: color,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

String _fmtTime(int seconds) {
  final h = seconds ~/ 3600;
  final m = (seconds % 3600) ~/ 60;
  final s = seconds % 60;
  if (h > 0) {
    return '$h:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }
  return '$m:${s.toString().padLeft(2, '0')}';
}

/// Abre el editor de competición (crear si [existing] es null, editar si no).
/// [initialDate] prerrellena la fecha al crear (entrada desde el calendario).
Future<void> showRaceGoalSheet(
  BuildContext context, {
  required String uid,
  RaceGoal? existing,
  DateTime? initialDate,
}) async {
  await showAppBottomSheet<void>(
    context: context,
    builder: (_) => _RaceGoalSheet(
      uid: uid,
      existing: existing,
      initialDate: initialDate,
    ),
  );
}

class _RaceGoalSheet extends StatefulWidget {
  final String uid;
  final RaceGoal? existing;
  final DateTime? initialDate;

  const _RaceGoalSheet({required this.uid, this.existing, this.initialDate});

  @override
  State<_RaceGoalSheet> createState() => _RaceGoalSheetState();
}

class _RaceGoalSheetState extends State<_RaceGoalSheet> {
  final RaceGoalRepository _repo = RaceGoalRepository();
  final TextEditingController _nameCtrl = TextEditingController();

  late DateTime _date;
  late RaceDistance _distance;
  late int _customKm;
  late RaceGoalPriority _priority;
  int _targetMinutes = 0;
  int _targetSeconds = 0;
  bool _saving = false;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _date = existing?.parsedDate ??
        widget.initialDate ??
        DateTime.now().add(const Duration(days: 42));
    _distance = existing?.distance ?? RaceDistance.k5;
    _customKm = existing?.customDistanceM != null
        ? (existing!.customDistanceM! / 1000).round().clamp(1, 100).toInt()
        : 10;
    _priority = existing?.priority ?? RaceGoalPriority.high;
    _nameCtrl.text = existing?.name ?? '';
    final target = existing?.targetTimeSeconds;
    if (target != null) {
      _targetMinutes = (target ~/ 60).clamp(0, 359).toInt();
      _targetSeconds = target % 60;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showAppDatePicker(
      context: context,
      initialDate: _date,
      minimumDate: DateTime(now.year, now.month, now.day),
      maximumDate: DateTime(now.year + 2, now.month, now.day),
      title: 'Día de la carrera',
    );
    if (picked != null && mounted) {
      setState(() => _date = picked);
    }
  }

  int? _buildTargetSeconds() {
    final total = _targetMinutes * 60 + _targetSeconds;
    return total > 0 ? total : null;
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final now = DateTime.now();
    final existing = widget.existing;
    final goal = RaceGoal(
      id: existing?.id ?? '',
      date: raceGoalDateKey(_date),
      distance: _distance,
      customDistanceM:
          _distance == RaceDistance.other ? _customKm * 1000 : null,
      name: _nameCtrl.text.trim().isEmpty ? null : _nameCtrl.text.trim(),
      targetTimeSeconds: _buildTargetSeconds(),
      priority: _priority,
      createdAt: existing?.createdAt ?? now,
      updatedAt: now,
    );
    try {
      await _repo.saveGoal(goal, uid: widget.uid);
      if (!mounted) return;
      Navigator.of(context).pop();
      ModernSnackBar.showSuccess(
        context,
        _isEditing ? 'Competición actualizada' : 'Competición marcada',
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ModernSnackBar.showError(context, 'No se pudo guardar la competición');
    }
  }

  Future<void> _delete() async {
    final existing = widget.existing;
    if (existing == null) return;
    final confirmed = await showAppConfirmDialog(
      context: context,
      title: '¿Eliminar competición?',
      message: 'Dejará de contar para la planificación de tu Coach.',
      confirmLabel: 'Eliminar',
      isDestructive: true,
    );
    if (confirmed != true) return;
    try {
      await _repo.deleteGoal(existing.id, uid: widget.uid);
      if (!mounted) return;
      Navigator.of(context).pop();
      ModernSnackBar.showSuccess(context, 'Competición eliminada');
    } catch (e) {
      if (!mounted) return;
      ModernSnackBar.showError(context, 'No se pudo eliminar');
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateLabel = DateFormat('d MMM yyyy', 'es_ES').format(_date);
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
          Center(
            child: Text(
              _isEditing ? 'Editar competición' : 'Nueva competición',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary(context),
              ),
            ),
          ),
          const SizedBox(height: 16),

          _FieldLabel('Fecha'),
          GestureDetector(
            onTap: _pickDate,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.surfaceOf(context),
                border:
                    Border.all(color: AppColors.borderOf(context), width: 0.5),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Día de la carrera',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary(context),
                    ),
                  ),
                  Text(
                    dateLabel,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.brand,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),

          _FieldLabel('Distancia'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: RaceDistance.values
                .map(
                  (d) => _ChoiceChip(
                    label: d.label,
                    selected: _distance == d,
                    onTap: () => setState(() => _distance = d),
                  ),
                )
                .toList(),
          ),
          if (_distance == RaceDistance.other) ...[
            const SizedBox(height: 10),
            NumberPickerField(
              label: 'Distancia',
              value: _customKm,
              min: 1,
              max: 100,
              step: 1,
              unit: 'km',
              onChanged: (v) => setState(() => _customKm = v),
            ),
          ],
          const SizedBox(height: 14),

          _FieldLabel('Prioridad'),
          Wrap(
            spacing: 8,
            children: RaceGoalPriority.values
                .map(
                  (p) => _ChoiceChip(
                    label: p.label,
                    selected: _priority == p,
                    onTap: () => setState(() => _priority = p),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 6),
          Text(
            _priorityHint(_priority),
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary(context),
            ),
          ),
          const SizedBox(height: 14),

          _FieldLabel('Nombre (opcional)'),
          TextField(
            controller: _nameCtrl,
            textCapitalization: TextCapitalization.sentences,
            style: TextStyle(color: AppColors.textPrimary(context)),
            decoration: InputDecoration(
              hintText: 'Ej: 10K de la Villa',
              isDense: true,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide:
                    BorderSide(color: AppColors.borderOf(context), width: 0.5),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppColors.brand, width: 1),
              ),
            ),
          ),
          const SizedBox(height: 14),

          _FieldLabel('Tiempo objetivo (opcional)'),
          Row(
            children: [
              Expanded(
                child: NumberPickerField(
                  label: 'Minutos',
                  value: _targetMinutes,
                  min: 0,
                  max: 359,
                  step: 1,
                  unit: 'min',
                  onChanged: (v) => setState(() => _targetMinutes = v),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: NumberPickerField(
                  label: 'Segundos',
                  value: _targetSeconds,
                  min: 0,
                  max: 59,
                  step: 5,
                  unit: 's',
                  onChanged: (v) => setState(() => _targetSeconds = v),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _saving ? null : _save,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.brand,
                minimumSize: const Size(0, 48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                _saving
                    ? 'Guardando...'
                    : (_isEditing ? 'Guardar cambios' : 'Guardar objetivo'),
                style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w600),
              ),
            ),
          ),
          if (_isEditing) ...[
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: _saving ? null : _delete,
                child: Text(
                  'Eliminar competición',
                  style: TextStyle(color: AppColors.feedbackError),
                ),
              ),
            ),
          ],
        ],
      ),
        ),
        ),
    );
  }
}

String _priorityHint(RaceGoalPriority priority) {
  switch (priority) {
    case RaceGoalPriority.high:
      return 'Alta · el plan apunta aquí, taper completo';
    case RaceGoalPriority.medium:
      return 'Media · la corres fuerte, taper corto';
    case RaceGoalPriority.low:
      return 'Baja · rodaje, la corres como un entreno';
  }
}

class _FieldLabel extends StatelessWidget {
  final String text;

  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.4,
          color: Color(0xFF8E8E93),
        ),
      ),
    );
  }
}

class _ChoiceChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ChoiceChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.brand : AppColors.surfaceOf(context),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? AppColors.brand : AppColors.borderOf(context),
            width: 0.5,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : AppColors.textSecondary(context),
          ),
        ),
      ),
    );
  }
}
