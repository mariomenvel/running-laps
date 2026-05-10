import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:running_laps/core/theme/app_colors.dart';
import 'package:running_laps/core/theme/app_theme.dart';
import 'package:running_laps/core/widgets/main_shell.dart';
import 'package:running_laps/core/widgets/shell_embedding_scope.dart';
import 'package:running_laps/features/athlete/data/athlete_session_repository.dart';
import 'package:running_laps/features/templates/data/athlete_session_mapper.dart';
import 'package:running_laps/features/templates/data/templates_repository.dart';
import 'package:running_laps/features/templates/data/workout_block.dart';
import 'package:running_laps/features/templates/data/workout_segment.dart';
import 'package:running_laps/features/templates/data/workout_session.dart';
import 'package:running_laps/features/templates/views/widgets/blocks_list_section.dart';
import 'package:running_laps/features/templates/views/widgets/workout_type_selector.dart';
import 'package:uuid/uuid.dart';

class WorkoutEditorScreen extends StatefulWidget {
  const WorkoutEditorScreen({
    super.key,
    this.initialSession,
    this.scheduledDate,
    this.shellParams,
    this.isQuickStart = false,
    this.onSave,
  });

  final WorkoutSession? initialSession;
  final DateTime? scheduledDate;
  final AthleteSessionShellParams? shellParams;
  final bool isQuickStart;
  final void Function(WorkoutSession)? onSave;

  @override
  State<WorkoutEditorScreen> createState() => _WorkoutEditorScreenState();
}

class _WorkoutEditorScreenState extends State<WorkoutEditorScreen> {
  late final ValueNotifier<WorkoutType?> _selectedType;
  late final ValueNotifier<String> _title;
  late final ValueNotifier<List<WorkoutBlock>> _blocks;
  late final ValueNotifier<bool> _saveAsTemplate;
  late final ValueNotifier<TimeOfDay?> _scheduledTime;
  late final ValueNotifier<String> _notes;

  late final TextEditingController _titleController;
  late final TextEditingController _notesController;

  // Effective scheduled date resolved from explicit param > shellParams > initialSession
  DateTime? _effectiveScheduledDate;

  bool _titleEdited = false;
  bool _titleIsAuto = true;

  @override
  void initState() {
    super.initState();
    try {
      final mapped = mapAthleteSessionToWorkout(widget.shellParams?.session);
      final s = widget.initialSession ?? mapped;

      _effectiveScheduledDate = widget.scheduledDate
          ?? _parseShellDate(widget.shellParams?.date)
          ?? s?.scheduledDate;

      _selectedType    = ValueNotifier(s?.type);
      _title           = ValueNotifier(s?.title ?? '');
      _blocks          = ValueNotifier(List.of(s?.blocks ?? []));
      _saveAsTemplate  = ValueNotifier(s?.isTemplate ?? false);
      _scheduledTime   = ValueNotifier(s?.scheduledTime);
      _notes           = ValueNotifier(s?.notes ?? '');

      _titleController = TextEditingController(text: _title.value);
      _titleController.addListener(() => _title.value = _titleController.text);

      _notesController = TextEditingController(text: _notes.value);
      _notesController.addListener(() => _notes.value = _notesController.text);

      if (s != null && s.title.isNotEmpty) {
        _titleEdited = true;
        final autoTitle = generateTitle(s);
        _titleIsAuto = s.title == autoTitle || s.title == titleFromType(s.type);
      } else {
        _titleIsAuto = true;
      }
    } catch (e, st) {
      debugPrint('[WorkoutEditor] initState ERROR: $e');
      debugPrint('[WorkoutEditor] stack: $st');
    }
  }

  @override
  void dispose() {
    _selectedType.dispose();
    _title.dispose();
    _blocks.dispose();
    _saveAsTemplate.dispose();
    _scheduledTime.dispose();
    _notes.dispose();
    _titleController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  void _navigateBack() {
    if (ShellEmbeddingScope.isEmbedded(context)) {
      MainShell.shellKey.currentState?.navigateBack();
    } else {
      Navigator.of(context).pop();
    }
  }

  static DateTime? _parseShellDate(String? date) {
    if (date == null) return null;
    return DateTime.tryParse(date);
  }

  bool _hasChanges() {
    final s = widget.initialSession;
    if (s == null) {
      return _selectedType.value != null ||
          _title.value.isNotEmpty ||
          _blocks.value.isNotEmpty ||
          _scheduledTime.value != null ||
          _notes.value.isNotEmpty;
    }
    return _selectedType.value != s.type ||
        _title.value != s.title ||
        _blocks.value.length != s.blocks.length ||
        _scheduledTime.value != s.scheduledTime ||
        _notes.value != (s.notes ?? '');
  }

  // ── Actions ───────────────────────────────────────────────────────────────

  void _onTypeSelected(WorkoutType type) {
    _selectedType.value = type;
    if (!_titleEdited) {
      _title.value = titleFromType(type);
      _titleController.text = _title.value;
      _titleIsAuto = true;
    }
    if (_blocks.value.isEmpty) {
      _blocks.value = [
        WorkoutBlock(
          role: BlockRole.main,
          repetitions: 1,
          segments: [],
        ),
      ];
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _scheduledTime.value ?? TimeOfDay.now(),
    );
    if (picked != null) _scheduledTime.value = picked;
  }

  Future<void> _onClose() async {
    if (!_hasChanges()) {
      if (mounted) _navigateBack();
      return;
    }
    final leave = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceOf(context),
        title: Text(
          '¿Salir sin guardar?',
          style: TextStyle(color: AppColors.textPrimary(context)),
        ),
        content: Text(
          'Los cambios se perderán.',
          style: TextStyle(color: AppColors.textSecondary(context)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Salir'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              'Seguir editando',
              style: TextStyle(color: AppColors.brand),
            ),
          ),
        ],
      ),
    );
    if ((leave ?? false) && mounted) _navigateBack();
  }

  Future<void> _onSave() async {
    final type = _selectedType.value;
    if (type == null && _blocks.value.isEmpty && !widget.isQuickStart) return;

    final resolvedType = type ?? WorkoutType.free;

    final blocks = _blocks.value.isNotEmpty
        ? _blocks.value
        : [
            WorkoutBlock(
              role: BlockRole.main,
              repetitions: 1,
              segments: [],
            ),
          ];

    final userTitle = _title.value.trim();
    final shouldRegenerate = userTitle.isEmpty || _titleIsAuto;

    String resolvedTitle;
    if (!shouldRegenerate) {
      resolvedTitle = userTitle;
    } else {
      final mainBlock = blocks
          .where((b) => b.role == BlockRole.main)
          .firstOrNull;
      final firstSeg = mainBlock?.segments
          .where((s) => s.type == SegmentType.interval)
          .firstOrNull;
      final reps = mainBlock?.repetitions ?? 1;
      final distM = firstSeg?.distanceM;
      final durSec = firstSeg?.durationSec;

      if ((resolvedType == WorkoutType.intervals ||
           resolvedType == WorkoutType.hills) &&
          distM != null && distM > 0) {
        final distLabel = distM >= 1000
            ? '${(distM / 1000).toStringAsFixed(distM % 1000 == 0 ? 0 : 1)}km'
            : '${distM}m';
        resolvedTitle = reps > 1 ? '$reps×$distLabel' : distLabel;
      } else if ((resolvedType == WorkoutType.intervals ||
                  resolvedType == WorkoutType.hills) &&
                 durSec != null && durSec > 0) {
        final min = durSec ~/ 60;
        final sec = durSec % 60;
        final timeLabel = sec == 0 ? '$min min' : "$min'$sec\"";
        resolvedTitle = reps > 1 ? '$reps×$timeLabel' : timeLabel;
      } else if (resolvedType == WorkoutType.continuous && distM != null) {
        final km = distM / 1000;
        resolvedTitle = 'Rodaje ${km.toStringAsFixed(km % 1 == 0 ? 0 : 1)}km';
      } else if (resolvedType == WorkoutType.continuous && durSec != null) {
        resolvedTitle = 'Rodaje ${durSec ~/ 60} min';
      } else {
        resolvedTitle = titleFromType(resolvedType);
      }
    }

    final notesValue = _notes.value.trim().isEmpty ? null : _notes.value.trim();

    final session = WorkoutSession(
      id:             widget.initialSession?.id ?? const Uuid().v4(),
      title:          resolvedTitle,
      type:           resolvedType,
      blocks:         blocks,
      scheduledDate:  _effectiveScheduledDate,
      scheduledTime:  _scheduledTime.value,
      notes:          notesValue,
      isTemplate:     _saveAsTemplate.value,
      templateId:     widget.initialSession?.templateId,
    );

    if (_saveAsTemplate.value) {
      try {
        await TrainingTemplatesRepository().saveWorkoutSession(session);
      } catch (e) {
        debugPrint('[WorkoutEditor] saveWorkoutSession error: $e');
      }
    }

    // Persiste como sesión planificada en Firestore si viene del calendario.
    if (widget.shellParams != null || widget.scheduledDate != null) {
      try {
        final uid = FirebaseAuth.instance.currentUser?.uid;
        if (uid != null) {
          final athleteSession =
              mapWorkoutSessionToAthlete(session, uid: uid);
          final repo = AthleteSessionRepository();
          if (widget.shellParams?.session != null) {
            final originalId = widget.shellParams!.session!.id;
            final sessionWithId = WorkoutSession(
              id:            originalId,
              title:         session.title,
              description:   session.description,
              type:          session.type,
              blocks:        session.blocks,
              scheduledDate: session.scheduledDate,
              scheduledTime: session.scheduledTime,
              notes:         session.notes,
              isTemplate:    session.isTemplate,
              templateId:    session.templateId,
            );
            await repo.updateSession(
              mapWorkoutSessionToAthlete(sessionWithId, uid: uid),
            );
          } else {
            await repo.createSession(athleteSession);
          }
        }
      } catch (e) {
        debugPrint('[WorkoutEditor] persistAthleteSession error: $e');
      }
    }

    if (widget.onSave != null) {
      widget.onSave!(session);
      // onSave es responsable del pop — no llamar _navigateBack()
    } else {
      if (mounted) _navigateBack();
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isNew = widget.initialSession == null;

    return Scaffold(
      backgroundColor: AppColors.background(context),
      appBar: AppBar(
        backgroundColor: AppColors.background(context),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close),
          color: AppColors.textPrimary(context),
          onPressed: _onClose,
        ),
        title: Text(
          isNew ? 'Nueva sesión' : 'Editar sesión',
          style: TextStyle(
            color: AppColors.textPrimary(context),
            fontSize: 17,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          ValueListenableBuilder2<WorkoutType?, List<WorkoutBlock>>(
            first: _selectedType,
            second: _blocks,
            builder: (_, type, blocks, __) {
              final disabled = type == null && blocks.isEmpty;
              return IconButton(
                icon: Icon(
                  Icons.check,
                  color: disabled
                      ? AppColors.iconMutedOf(context)
                      : AppColors.brand,
                ),
                onPressed: disabled ? null : _onSave,
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.l),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: AppSpacing.l),

            // ── Sección 1: Tipo ──────────────────────────────────────
            _SectionLabel('TIPO'),
            const SizedBox(height: AppSpacing.s),
            ValueListenableBuilder<WorkoutType?>(
              valueListenable: _selectedType,
              builder: (_, type, __) => WorkoutTypeSelector(
                selected: type,
                onSelected: _onTypeSelected,
              ),
            ),

            _divider(context),

            // ── Sección 1b: Hora ─────────────────────────────────────
            ValueListenableBuilder<TimeOfDay?>(
              valueListenable: _scheduledTime,
              builder: (_, time, __) => GestureDetector(
                onTap: _pickTime,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.s),
                  child: Row(
                    children: [
                      Icon(
                        Icons.schedule,
                        size: 20,
                        color: AppColors.iconMutedOf(context),
                      ),
                      const SizedBox(width: AppSpacing.s),
                      Text(
                        'Hora',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.textSecondary(context),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        time == null
                            ? 'Sin hora'
                            : '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}',
                        style: TextStyle(
                          fontSize: 14,
                          color: time == null
                              ? AppColors.textSecondary(context)
                              : AppColors.brand,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.chevron_right,
                        size: 18,
                        color: AppColors.iconMutedOf(context),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            _divider(context),

            // ── Sección 2: Nombre ────────────────────────────────────
            _SectionLabel('NOMBRE'),
            const SizedBox(height: AppSpacing.s),
            TextField(
              controller: _titleController,
              onChanged: (v) {
              _title.value = v;
              _titleEdited = true;
              _titleIsAuto = false;
            },
              maxLength: 60,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: AppColors.textPrimary(context),
              ),
              decoration: InputDecoration(
                hintText: 'Nombre de la sesión',
                hintStyle: TextStyle(color: AppColors.textSecondary(context)),
                border: InputBorder.none,
                counterText: '',
              ),
            ),

            _divider(context),

            // ── Sección 3: Bloques ───────────────────────────────────
            ValueListenableBuilder<WorkoutType?>(
              valueListenable: _selectedType,
              builder: (_, type, __) => AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: type == null
                    ? const SizedBox.shrink()
                    : Column(
                        key: const ValueKey('blocks-section'),
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _SectionLabel('BLOQUES'),
                          const SizedBox(height: AppSpacing.s),
                          ValueListenableBuilder<List<WorkoutBlock>>(
                            valueListenable: _blocks,
                            builder: (_, blocks, __) => BlocksListSection(
                              blocks: blocks,
                              workoutType: type,
                              onBlocksChanged: (updated) =>
                                  _blocks.value = updated,
                            ),
                          ),
                          _divider(context),
                        ],
                      ),
              ),
            ),

            // ── Sección 4: Opciones ──────────────────────────────────
            _SectionLabel('OPCIONES'),
            const SizedBox(height: AppSpacing.s),
            ValueListenableBuilder<bool>(
              valueListenable: _saveAsTemplate,
              builder: (_, save, __) => Row(
                children: [
                  Switch(
                    value: save,
                    activeThumbColor: AppColors.brand,
                    activeTrackColor: AppColors.brand.withValues(alpha: 0.4),
                    onChanged: (v) => _saveAsTemplate.value = v,
                  ),
                  const SizedBox(width: AppSpacing.s),
                  Text(
                    'Guardar como plantilla',
                    style: TextStyle(
                      fontSize: 15,
                      color: AppColors.textPrimary(context),
                    ),
                  ),
                ],
              ),
            ),

            _divider(context),

            // ── Sección 5: Notas ─────────────────────────────────────
            _SectionLabel('NOTAS'),
            const SizedBox(height: AppSpacing.s),
            Container(
              decoration: BoxDecoration(
                color: AppColors.surface2Of(context),
                borderRadius: BorderRadius.circular(10),
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.m,
                vertical: AppSpacing.s,
              ),
              child: TextField(
                controller: _notesController,
                maxLines: 4,
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textPrimary(context),
                ),
                decoration: InputDecoration(
                  hintText: 'Notas de planificación...',
                  hintStyle: TextStyle(color: AppColors.textSecondary(context)),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ),

            const SizedBox(height: AppSpacing.xxl),

            // ── Botón principal ──────────────────────────────────────
            ValueListenableBuilder<List<WorkoutBlock>>(
              valueListenable: _blocks,
              builder: (_, blocks, __) {
                final disabled =
                    !widget.isQuickStart && blocks.isEmpty;
                return SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: disabled ? null : _onSave,
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          disabled ? AppColors.borderOf(context) : AppColors.brand,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      widget.isQuickStart
                          ? 'Empezar entrenamiento'
                          : 'Guardar sesión',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                );
              },
            ),

            const SizedBox(height: AppSpacing.xxl),
          ],
        ),
      ),
    );
  }

  Widget _divider(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.l),
        child: Divider(
          color: AppColors.borderOf(context),
          thickness: 0.5,
          height: 0,
        ),
      );
}

// ── Helpers de layout ────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          letterSpacing: 1.2,
          color: AppColors.textSecondary(context),
        ),
      );
}

// ── ValueListenableBuilder2 ───────────────────────────────────────────────────

class ValueListenableBuilder2<A, B> extends StatelessWidget {
  const ValueListenableBuilder2({
    super.key,
    required this.first,
    required this.second,
    required this.builder,
  });

  final ValueListenable<A> first;
  final ValueListenable<B> second;
  final Widget Function(BuildContext, A, B, Widget?) builder;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<A>(
      valueListenable: first,
      builder: (ctx, a, _) => ValueListenableBuilder<B>(
        valueListenable: second,
        builder: (ctx2, b, child) => builder(ctx2, a, b, child),
      ),
    );
  }
}
