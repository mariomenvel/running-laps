import 'package:flutter/material.dart';
import 'package:running_laps/core/theme/app_colors.dart';
import 'package:running_laps/core/theme/app_theme.dart';
import 'package:running_laps/core/widgets/app_confirm_dialog.dart';
import 'package:running_laps/core/widgets/main_shell.dart';
import 'package:running_laps/core/widgets/modern_snackbar.dart';
import 'package:running_laps/core/widgets/shell_embedding_scope.dart';
import 'package:running_laps/features/templates/data/workout_block.dart';
import 'package:running_laps/features/templates/data/workout_session.dart';
import 'package:running_laps/features/templates/viewmodels/workout_ai_panel_view_model.dart';
import 'package:running_laps/features/templates/viewmodels/workout_editor_view_model.dart';
import 'package:running_laps/features/templates/views/widgets/blocks_list_section.dart';
import 'package:running_laps/features/templates/views/widgets/workout_type_selector.dart';

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
  late final WorkoutEditorViewModel _vm;

  late final TextEditingController _titleController;
  late final TextEditingController _notesController;

  // Panel de IA: estado propio de la UI (desplegado/plegado, dictado). La
  // generación en sí la hace el viewmodel.
  final _aiPromptController = TextEditingController();
  final _aiPanelViewModel = WorkoutAiPanelViewModel();
  final _aiPanelExpanded = ValueNotifier<bool>(false);

  @override
  void initState() {
    super.initState();
    _vm = WorkoutEditorViewModel(
      initialSession: widget.initialSession,
      scheduledDate:  widget.scheduledDate,
      shellParams:    widget.shellParams,
      isQuickStart:   widget.isQuickStart,
    );

    _titleController = TextEditingController(text: _vm.title.value);
    _vm.title.addListener(_syncTitleController);

    _notesController = TextEditingController(text: _vm.notes.value);
    _notesController.addListener(
        () => _vm.onNotesChanged(_notesController.text));

    _aiPanelViewModel.recognizedText.addListener(_onRecognizedTextChanged);
    // Ojo: nada de initSpeech() aquí — el reconocimiento de voz se inicializa
    // (y pide permisos) al pulsar el micro por primera vez. Ver CLAUDE.md,
    // "Permisos runtime".
  }

  @override
  void dispose() {
    _vm.title.removeListener(_syncTitleController);
    _vm.dispose();
    _titleController.dispose();
    _notesController.dispose();
    _aiPanelViewModel.recognizedText.removeListener(_onRecognizedTextChanged);
    _aiPanelViewModel.dispose();
    _aiPromptController.dispose();
    _aiPanelExpanded.dispose();
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

  /// El viewmodel cambia el nombre por su cuenta al elegir tipo o generar con
  /// IA; el TextField necesita reflejarlo. La comparación evita reescribir el
  /// controlador cuando el cambio vino del propio teclado (movería el cursor).
  void _syncTitleController() {
    if (_titleController.text != _vm.title.value) {
      _titleController.text = _vm.title.value;
    }
  }

  void _onRecognizedTextChanged() {
    _aiPromptController.text = _aiPanelViewModel.recognizedText.value;
  }

  // ── Actions ───────────────────────────────────────────────────────────────

  Future<void> _toggleAiListening() async {
    await _aiPanelViewModel.toggleListening();
    final error = _aiPanelViewModel.speechError.value;
    if (error != null && mounted) {
      ModernSnackBar.showError(context, error);
    }
  }

  Future<void> _generateFromAi() async {
    // Enviar corta el dictado si sigue abierto: el micro no debe seguir
    // escuchando (y sobrescribiendo el campo) mientras se genera.
    if (_aiPanelViewModel.isListening.value) {
      await _aiPanelViewModel.toggleListening();
    }

    final result = await _vm.generateFromAi(_aiPromptController.text);
    if (!mounted) return;

    if (result.success) {
      _aiPanelExpanded.value = false;
      _aiPromptController.clear();
      ModernSnackBar.showSuccess(context, 'Entrenamiento generado');
    } else if (result.errorMessage != null) {
      ModernSnackBar.showError(context, result.errorMessage!);
    }
  }

  Future<void> _onClose() async {
    if (!_vm.hasChanges()) {
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
    final result = await _vm.save();
    final session = result.session;
    if (session == null) return; // blocked: falta tipo y bloques

    widget.onSave?.call(session);
    if (mounted) _navigateBack();
  }


  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {

    // Solo intercepta el atrás del sistema cuando esta pantalla es la visible:
    // en el shell el IndexedStack la mantiene montada aunque esté oculta.
    // Ojo con la condición del callback: cuando CUALQUIER PopScope de la ruta
    // bloquea el pop, Flutter llama a los callbacks de TODOS con
    // didPop == false — así que sin `isVisible` aquí, este diálogo saltaría
    // porque lo bloqueó otra pestaña.
    final isVisible = ShellSlotScope.isVisible(context);
    return PopScope(
      canPop: !isVisible,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && isVisible) _onClose();
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
              valueListenable: _vm.selectedType,
              builder: (_, type, __) {
                return WorkoutTypeSelector(
                  selected: type,
                  onSelected: _vm.onTypeSelected,
                );
              },
            ),

            _divider(context),

            // ── Sección 2: Nombre ────────────────────────────────────
            _SectionLabel('NOMBRE'),
            const SizedBox(height: AppSpacing.s),
            TextField(
              controller: _titleController,
              onChanged: _vm.onTitleEdited,
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
              valueListenable: _vm.selectedType,
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
                            valueListenable: _vm.blocks,
                            builder: (_, blocks, __) => BlocksListSection(
                              blocks: blocks,
                              workoutType: type,
                              onBlocksChanged: _vm.onBlocksChanged,
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
              animation: _vm.formFields,
              builder: (_, __) {
                final blocks = _vm.blocks.value;
                final isEditingExisting = widget.initialSession != null;
                final hasChanges = _vm.hasChanges();
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
                              valueListenable: _vm.aiGenerating,
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
