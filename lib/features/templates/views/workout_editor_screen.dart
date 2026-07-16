import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:running_laps/core/theme/app_colors.dart';
import 'package:running_laps/core/theme/app_theme.dart';
import 'package:running_laps/core/services/notification_service.dart';
import 'package:running_laps/core/widgets/main_shell.dart';
import 'package:running_laps/core/widgets/shell_embedding_scope.dart';
import 'package:running_laps/features/ai_coach/data/ai_coach_prompt_session_generator.dart';
import 'package:running_laps/features/ai_coach/data/ai_coach_repository.dart';
import 'package:running_laps/features/athlete/data/athlete_session_repository.dart';
import 'package:running_laps/features/templates/data/athlete_session_mapper.dart';
import 'package:running_laps/core/widgets/app_confirm_dialog.dart';
import 'package:running_laps/core/widgets/modern_snackbar.dart';
import 'package:running_laps/features/templates/data/workout_block.dart';
import 'package:running_laps/features/templates/data/workout_segment.dart';
import 'package:running_laps/features/templates/data/workout_session.dart';
import 'package:running_laps/features/templates/viewmodels/workout_ai_panel_view_model.dart';
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
  late final ValueNotifier<TimeOfDay?> _scheduledTime;
  late final ValueNotifier<String> _notes;

  late final TextEditingController _titleController;
  late final TextEditingController _notesController;

  final _aiPromptController = TextEditingController();
  final _aiPanelViewModel = WorkoutAiPanelViewModel();
  final _aiPanelExpanded = ValueNotifier<bool>(false);
  final _aiGenerating = ValueNotifier<bool>(false);

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
      _scheduledTime   = ValueNotifier(s?.scheduledTime);
      _notes           = ValueNotifier(s?.notes ?? '');

      _titleController = TextEditingController(text: _title.value);
      _titleController.addListener(() => _title.value = _titleController.text);

      _notesController = TextEditingController(text: _notes.value);
      _notesController.addListener(() => _notes.value = _notesController.text);

      _aiPanelViewModel.recognizedText.addListener(_onRecognizedTextChanged);

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
    _scheduledTime.dispose();
    _notes.dispose();
    _titleController.dispose();
    _notesController.dispose();
    _aiPanelViewModel.recognizedText.removeListener(_onRecognizedTextChanged);
    _aiPanelViewModel.dispose();
    _aiPromptController.dispose();
    _aiPanelExpanded.dispose();
    _aiGenerating.dispose();
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

  List<WorkoutBlock> _defaultBlocksForType(WorkoutType type) {
    switch (type) {
      case WorkoutType.continuous:
        return [
          WorkoutBlock(role: BlockRole.warmup, repetitions: 1,
            segments: [WorkoutSegment(type: SegmentType.interval, durationSec: 600)]),
          WorkoutBlock(role: BlockRole.main, repetitions: 1,
            segments: [WorkoutSegment(type: SegmentType.interval, durationSec: 2700)]),
          WorkoutBlock(role: BlockRole.cooldown, repetitions: 1,
            segments: [WorkoutSegment(type: SegmentType.interval, durationSec: 600)]),
        ];

      case WorkoutType.intervals:
        return [
          WorkoutBlock(role: BlockRole.warmup, repetitions: 1,
            segments: [WorkoutSegment(type: SegmentType.interval, durationSec: 600)]),
          WorkoutBlock(role: BlockRole.main, repetitions: 5,
            segments: [
              WorkoutSegment(type: SegmentType.interval, distanceM: 1000),
              WorkoutSegment(type: SegmentType.recovery, durationSec: 90),
            ]),
          WorkoutBlock(role: BlockRole.cooldown, repetitions: 1,
            segments: [WorkoutSegment(type: SegmentType.interval, durationSec: 600)]),
        ];

      case WorkoutType.fartlek:
        return [
          WorkoutBlock(role: BlockRole.warmup, repetitions: 1,
            segments: [WorkoutSegment(type: SegmentType.interval, durationSec: 600)]),
          WorkoutBlock(role: BlockRole.main, repetitions: 4,
            segments: [
              WorkoutSegment(type: SegmentType.interval, durationSec: 180),
              WorkoutSegment(type: SegmentType.recovery, durationSec: 120),
            ]),
          WorkoutBlock(role: BlockRole.cooldown, repetitions: 1,
            segments: [WorkoutSegment(type: SegmentType.interval, durationSec: 600)]),
        ];

      case WorkoutType.hills:
        return [
          WorkoutBlock(role: BlockRole.warmup, repetitions: 1,
            segments: [WorkoutSegment(type: SegmentType.interval, durationSec: 600)]),
          WorkoutBlock(role: BlockRole.main, repetitions: 8,
            segments: [
              WorkoutSegment(type: SegmentType.interval, durationSec: 60),
              WorkoutSegment(type: SegmentType.recovery, durationSec: 90),
            ]),
          WorkoutBlock(role: BlockRole.cooldown, repetitions: 1,
            segments: [WorkoutSegment(type: SegmentType.interval, durationSec: 600)]),
        ];

      case WorkoutType.competition:
        return [
          WorkoutBlock(role: BlockRole.warmup, repetitions: 1,
            segments: [WorkoutSegment(type: SegmentType.interval, durationSec: 900)]),
          WorkoutBlock(role: BlockRole.main, repetitions: 1,
            segments: [WorkoutSegment(type: SegmentType.interval, distanceM: 5000)]),
          WorkoutBlock(role: BlockRole.cooldown, repetitions: 1,
            segments: [WorkoutSegment(type: SegmentType.interval, durationSec: 600)]),
        ];

      case WorkoutType.free:
        return [
          WorkoutBlock(role: BlockRole.main, repetitions: 1,
            segments: [WorkoutSegment(type: SegmentType.interval, durationSec: 3600)]),
        ];
    }
  }

  void _onTypeSelected(WorkoutType type) {
    _selectedType.value = type;
    if (!_titleEdited) {
      _title.value = titleFromType(type);
      _titleController.text = _title.value;
      _titleIsAuto = true;
    }

    final blocks = _blocks.value;
    final isEmpty = blocks.isEmpty ||
        (blocks.length == 1 &&
         blocks.first.role == BlockRole.main &&
         blocks.first.segments.isEmpty);

    if (isEmpty) {
      _blocks.value = _defaultBlocksForType(type);
    }
  }

  void _onRecognizedTextChanged() {
    _aiPromptController.text = _aiPanelViewModel.recognizedText.value;
  }

  Future<void> _toggleAiListening() async {
    await _aiPanelViewModel.toggleListening();
    final error = _aiPanelViewModel.speechError.value;
    if (error != null && mounted) {
      ModernSnackBar.showError(context, error);
    }
  }

  Future<void> _generateFromAi() async {
    final text = _aiPromptController.text.trim();
    if (text.isEmpty) return;

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    // Enviar corta el dictado si sigue abierto — el micro no debe seguir
    // escuchando (y sobrescribiendo el campo) mientras se genera.
    if (_aiPanelViewModel.isListening.value) {
      await _aiPanelViewModel.toggleListening();
    }

    _aiGenerating.value = true;

    try {
      final profile = await AiCoachRepository().getProfile(uid: uid);
      if (!mounted) return;

      const generator = AiCoachPromptSessionGenerator();
      final session = await generator.generate(
        prompt: text,
        profile: profile,
      );

      if (!mounted) return;

      _blocks.value = List.of(session.blocks);
      _titleEdited = true;
      _titleIsAuto = false;
      _onTypeSelected(session.type);
      _titleController.text = session.title;
      _title.value = session.title;

      _aiPanelExpanded.value = false;
      _aiPromptController.clear();
      ModernSnackBar.showSuccess(context, 'Entrenamiento generado');
    } catch (e) {
      if (!mounted) return;
      ModernSnackBar.showError(context, 'Error al generar');
    } finally {
      if (mounted) _aiGenerating.value = false;
    }
  }

  Future<void> _onClose() async {
    if (!_hasChanges()) {
      if (mounted) _navigateBack();
      return;
    }
    final leave = await showAppConfirmDialog(
      context: context,
      title: '¿Salir sin guardar?',
      message: 'Los cambios se perderán.',
      confirmLabel: 'Salir',
      cancelLabel: 'Seguir editando',
      isDestructive: true,
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
      isTemplate:     widget.initialSession?.isTemplate ?? false,
      templateId:     widget.initialSession?.templateId,
    );

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
            widget.shellParams?.onSaved?.call(athleteSession);
          }

          // Recordatorio "¡Entreno en 1 hora!" si la sesión tiene fecha y
          // hora concretas (antes solo lo programaba una vista huérfana).
          final schedDate = session.scheduledDate;
          final schedTime = session.scheduledTime;
          if (schedDate != null && schedTime != null) {
            final sessionDateTime = DateTime(
              schedDate.year, schedDate.month, schedDate.day,
              schedTime.hour, schedTime.minute,
            );
            NotificationService()
                .scheduleSessionReminder(
                  sessionId: session.id,
                  sessionDateTime: sessionDateTime,
                  sessionTitle: session.title,
                )
                .catchError((Object e) =>
                    debugPrint('[WorkoutEditor] session reminder: $e'));
          }
        }
      } catch (e) {
        debugPrint('[WorkoutEditor] persistAthleteSession error: $e');
      }
    }

    widget.onSave?.call(session);
    if (mounted) _navigateBack();
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _onClose();
      },
      child: Scaffold(
        backgroundColor: AppColors.background(context),
        body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.l),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: AppSpacing.l),

            // ── Panel IA inline ──────────────────────────────────────
            _buildAiPanel(),

            // ── Sección 1: Tipo ──────────────────────────────────────
            _SectionLabel('TIPO'),
            const SizedBox(height: AppSpacing.s),
            ValueListenableBuilder<WorkoutType?>(
              valueListenable: _selectedType,
              builder: (_, type, __) {
                return WorkoutTypeSelector(
                  selected: type,
                  onSelected: _onTypeSelected,
                );
              },
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
            // Escucha todo lo que _hasChanges() compara, para reflejar en
            // vivo si hay algo que guardar o no — evita el "guardar" que no
            // hace nada visible cuando el usuario no tocó nada.
            AnimatedBuilder(
              animation: Listenable.merge(
                [_selectedType, _title, _blocks, _scheduledTime, _notes],
              ),
              builder: (_, __) {
                final blocks = _blocks.value;
                final isEditingExisting = widget.initialSession != null;
                final hasChanges = _hasChanges();
                final blocksInvalid = !widget.isQuickStart && blocks.isEmpty;
                // En quick-start initialSession es el preset mínimo: aunque el
                // usuario no cambie nada, "Empezar entrenamiento" debe ejecutar
                // _onSave (que dispara onSave → pre-ejecución), nunca ser no-op.
                final noopSave =
                    isEditingExisting && !hasChanges && !widget.isQuickStart;
                final disabled = blocksInvalid;

                final String label;
                if (widget.isQuickStart) {
                  label = 'Empezar entrenamiento';
                } else if (noopSave) {
                  label = 'Sin cambios';
                } else {
                  label = 'Guardar sesión';
                }

                return SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: disabled
                        ? null
                        : (noopSave ? _navigateBack : _onSave),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: disabled
                          ? AppColors.borderOf(context)
                          : noopSave
                              ? AppColors.surface2Of(context)
                              : AppColors.brand,
                      foregroundColor:
                          noopSave ? AppColors.textSecondary(context) : Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      label,
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
    ),
    );
  }

  Widget _buildAiPanel() {
    return ValueListenableBuilder<bool>(
      valueListenable: _aiPanelExpanded,
      builder: (_, expanded, __) {
        return Container(
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppColors.brand.withValues(alpha: 0.10),
                AppColors.brand.withValues(alpha: 0.03),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.brand.withValues(alpha: 0.25)),
          ),
          child: Column(
            children: [
              InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => _aiPanelExpanded.value = !expanded,
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      Icon(Icons.auto_awesome_rounded,
                          color: AppColors.brand, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Crear con IA',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary(context),
                          ),
                        ),
                      ),
                      Icon(
                        expanded
                            ? Icons.expand_less_rounded
                            : Icons.expand_more_rounded,
                        color: AppColors.brand,
                      ),
                    ],
                  ),
                ),
              ),
              if (expanded) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                  child: Column(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: AppColors.surfaceOf(context),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.all(12),
                        child: TextField(
                          controller: _aiPromptController,
                          maxLines: 4,
                          maxLength: 500,
                          decoration: InputDecoration(
                            hintText: 'Ej: 5 series de 400m a ritmo 5K '
                                'con 90s de descanso...',
                            hintStyle: TextStyle(
                              color: AppColors.textSecondary(context),
                              fontSize: 13,
                            ),
                            border: InputBorder.none,
                            counterStyle: TextStyle(
                              color: AppColors.textSecondary(context),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          ValueListenableBuilder<bool>(
                            valueListenable: _aiPanelViewModel.speechAvailable,
                            builder: (_, available, __) {
                              if (!available) return const SizedBox.shrink();
                              return ValueListenableBuilder<bool>(
                                valueListenable: _aiPanelViewModel.isListening,
                                builder: (_, listening, __) => GestureDetector(
                                  onTap: _toggleAiListening,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 14, vertical: 10),
                                    decoration: BoxDecoration(
                                      color: listening
                                          ? AppColors.brand.withValues(alpha: 0.15)
                                          : AppColors.surfaceOf(context),
                                      borderRadius: BorderRadius.circular(24),
                                      border: Border.all(
                                        color: listening
                                            ? AppColors.brand
                                            : AppColors.borderOf(context),
                                      ),
                                    ),
                                    child: Icon(
                                      listening
                                          ? Icons.stop_rounded
                                          : Icons.mic_rounded,
                                      size: 20,
                                      color: listening
                                          ? AppColors.brand
                                          : AppColors.textSecondary(context),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: ValueListenableBuilder<bool>(
                              valueListenable: _aiGenerating,
                              builder: (_, generating, __) => FilledButton(
                                onPressed: generating ? null : _generateFromAi,
                                style: FilledButton.styleFrom(
                                  backgroundColor: AppColors.brand,
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: generating
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white),
                                      )
                                    : const Text('Generar'),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        );
      },
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
