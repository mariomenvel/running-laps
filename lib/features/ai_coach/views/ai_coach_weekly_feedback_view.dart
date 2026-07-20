import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../data/ai_coach_automation_service.dart';
import '../data/ai_coach_models.dart';
import '../data/ai_coach_repository.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart' show AppMotion;
import '../../../core/widgets/app_header.dart';
import '../../../core/widgets/back_pill.dart';
import '../../../core/widgets/modern_snackbar.dart';
import '../../../core/widgets/main_shell.dart';
import '../../../core/widgets/shell_embedding_scope.dart';
import 'package:flutter_svg/flutter_svg.dart';

class AiCoachWeeklyFeedbackView extends StatefulWidget {
  final String weekStart;
  final VoidCallback? onCompleted;
  final bool generatePlanAfter;
  final int daysSinceLastTraining;
  final int consecutiveMissedWeeks;

  const AiCoachWeeklyFeedbackView({
    super.key,
    required this.weekStart,
    this.onCompleted,
    this.generatePlanAfter = true,
    this.daysSinceLastTraining = 0,
    this.consecutiveMissedWeeks = 0,
  });

  @override
  State<AiCoachWeeklyFeedbackView> createState() =>
      _AiCoachWeeklyFeedbackViewState();
}

class _AiCoachWeeklyFeedbackViewState
    extends State<AiCoachWeeklyFeedbackView> {

  int _sensaciones = 3;
  String _sueno = 'bien';
  String? _motivoParon;
  final _molestiaController = TextEditingController();
  final _observacionesController = TextEditingController();
  bool _isSaving = false;
  bool _isGeneratingPlan = false;

  String get _sensacionesLabel {
    if (widget.consecutiveMissedWeeks >= 4) {
      return '¿Cómo te encuentras físicamente?';
    } else if (widget.daysSinceLastTraining >= 10) {
      return '¿Cómo te sientes después del parón?';
    } else {
      return '¿Cómo te has sentido entrenando?';
    }
  }

  String get _sensacionesHint {
    if (widget.consecutiveMissedWeeks >= 4) {
      return '1 = muy bajo, 5 = en plena forma';
    } else if (widget.daysSinceLastTraining >= 10) {
      return '1 = muy cansado, 5 = con mucha energía';
    } else {
      return '1 = muy mal, 5 = muy bien';
    }
  }

  String get _suenoLabel {
    if (widget.daysSinceLastTraining >= 7) {
      return 'Sueño en las últimas semanas';
    } else {
      return 'Sueño esta semana';
    }
  }

  @override
  void dispose() {
    _molestiaController.dispose();
    _observacionesController.dispose();
    super.dispose();
  }

  String? _validateCoachText(String? value) {
    if (value == null || value.isEmpty) return null;
    final lower = value.toLowerCase();
    const suspiciousPatterns = [
      'ignore', 'ignora', 'olvida', 'forget',
      'system prompt', 'instrucciones anteriores',
      'eres ahora', 'you are now', 'jailbreak',
      'dan mode', 'developer mode',
    ];
    if (suspiciousPatterns.any((p) => lower.contains(p))) {
      return 'Por favor escribe solo información de entrenamiento';
    }
    return null;
  }

  Future<void> _save() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final molestiaError = _validateCoachText(_molestiaController.text);
    final obsError = _validateCoachText(_observacionesController.text);
    if (molestiaError != null || obsError != null) {
      ModernSnackBar.showError(context, molestiaError ?? obsError!);
      return;
    }

    setState(() => _isSaving = true);

    final feedback = AiCoachWeeklyFeedback(
      uid: uid,
      weekStart: widget.weekStart,
      sensaciones: _sensaciones,
      sueno: _sueno,
      molestias: _molestiaController.text.trim().isEmpty
          ? null
          : _molestiaController.text.trim(),
      observaciones: _observacionesController.text.trim().isEmpty
          ? null
          : _observacionesController.text.trim(),
      motivoParon: _motivoParon,
      createdAt: DateTime.now(),
    );

    try {
      await AiCoachRepository().saveWeeklyFeedback(feedback);
      if (!mounted) return;
      ModernSnackBar.showSuccess(context, '¡Gracias! Tu coach lo tendrá en cuenta');

      debugPrint('[Feedback] generatePlanAfter=${widget.generatePlanAfter}');
      if (widget.generatePlanAfter) {
        debugPrint('[Feedback] iniciando generación...');
        setState(() => _isGeneratingPlan = true);
        try {
          final weekday = DateTime.now().weekday;
          if (weekday <= 2) {
            // Lunes o martes: generar la semana ACTUAL
            await AiCoachAutomationService()
                .forceGenerateCurrentWeekPlan(uid);
          } else {
            // Sábado/domingo: generar la semana SIGUIENTE
            await AiCoachAutomationService()
                .forceGenerateNextWeekPlan(uid);
          }
          debugPrint('[Feedback] plan generado OK');
        } catch (e) {
          debugPrint('[Feedback] error generando plan: $e');
        }
        if (mounted) setState(() => _isGeneratingPlan = false);
      }

      widget.onCompleted?.call();
      if (mounted) {
        if (ShellEmbeddingScope.isEmbedded(context)) {
          MainShell.shellKey.currentState?.navigateBack();
        } else {
          Navigator.of(context).pop();
        }
      }
    } catch (e, st) {
      debugPrint('[Feedback] ERROR EXTERIOR: $e');
      debugPrint('[Feedback] tipo: ${e.runtimeType}');
      debugPrint('[Feedback] stack: $st');
      if (!mounted) return;
      ModernSnackBar.showError(context, 'Error al guardar. Inténtalo de nuevo.');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceOf(context),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            const AppHeader(showBottomDivider: false),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (!ShellEmbeddingScope.isEmbedded(context)) ...[
                      Row(
                        children: [
                          BackPill(onTap: () => Navigator.of(context).pop()),
                        ],
                      ),
                      const SizedBox(height: 20),
                    ],
                    Text(
                      '¿Cómo fue la semana?',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary(context),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Tu coach ajustará el plan según cómo te has sentido.',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary(context),
                      ),
                    ),
                    const SizedBox(height: 32),

                    _sectionLabel(_sensacionesLabel),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: List.generate(5, (i) {
                        final val = i + 1;
                        final selected = _sensaciones == val;
                        return GestureDetector(
                          onTap: () => setState(() => _sensaciones = val),
                          child: AnimatedContainer(
                            duration: AppMotion.base,
                            width: 60,
                            height: 60,
                            padding: EdgeInsets.all(selected ? 3 : 6),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: selected
                                    ? AppColors.brand
                                    : Colors.transparent,
                                width: 3,
                              ),
                            ),
                            child: SvgPicture.asset(
                              'assets/icons/mood/mood_$val.svg',
                            ),
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 6),
                    Center(
                      child: Text(
                        _sensacionesHint,
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary(context),
                        ),
                      ),
                    ),
                    const SizedBox(height: 26),

                    if (widget.consecutiveMissedWeeks >= 2) ...[
                      _sectionLabel('¿Por qué paraste?'),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _motivoChip('Lesión o molestia', 'lesion'),
                          _motivoChip('Viaje o trabajo', 'viaje'),
                          _motivoChip('Falta de tiempo', 'tiempo'),
                          _motivoChip('Desmotivación', 'motivacion'),
                          _motivoChip('Otro', 'otro'),
                        ],
                      ),
                      const SizedBox(height: 32),
                    ],

                    _sectionLabel(_suenoLabel),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _suenoChip('bien', 'Bien'),
                        _suenoChip('regular', 'Regular'),
                        _suenoChip('mal', 'Mal'),
                        _suenoChip('no_medido', 'No medido'),
                      ],
                    ),
                    const SizedBox(height: 32),

                    _sectionLabel('¿Algún dolor o molestia? (opcional)'),
                    const SizedBox(height: 12),
                    _textField(
                      controller: _molestiaController,
                      hint: 'Ej: Molestia en el talón izquierdo...',
                      maxLength: 200,
                    ),
                    const SizedBox(height: 24),

                    _sectionLabel('¿Algo más para tu coach? (opcional)'),
                    const SizedBox(height: 12),
                    _textField(
                      controller: _observacionesController,
                      hint: 'Ej: Esta semana viajé y no pude entrenar como quería...',
                      maxLines: 3,
                      maxLength: 300,
                    ),
                  ],
                ),
              ),
            ),

            Container(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
              decoration: BoxDecoration(
                color: AppColors.surfaceOf(context),
                border: Border(
                  top: BorderSide(
                    color: AppColors.borderOf(context).withValues(alpha: 0.3),
                  ),
                ),
              ),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _isSaving ? null : _save,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.brand,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: _isGeneratingPlan
                      ? const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            ),
                            SizedBox(width: 10),
                            Text(
                              'Generando plan...',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        )
                      : _isSaving
                          ? const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CupertinoActivityIndicator(
                                    color: Colors.white,
                                    radius: 8,
                                  ),
                                ),
                                SizedBox(width: 10),
                                Text(
                                  'Guardando...',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            )
                          : const Text(
                              'Enviar al coach',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(String text) => Text(
        text,
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary(context),
        ),
      );

  Widget _motivoChip(String label, String value) {
    final selected = _motivoParon == value;
    return GestureDetector(
      onTap: () => setState(() => _motivoParon = selected ? null : value),
      child: AnimatedContainer(
        duration: AppMotion.base,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.brand.withValues(alpha: 0.15)
              : AppColors.surface2Of(context),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: selected ? AppColors.brand : Colors.transparent,
            width: 2,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
            color: selected
                ? AppColors.brand
                : AppColors.textSecondary(context),
          ),
        ),
      ),
    );
  }

  Widget _suenoChip(String value, String label) {
    final selected = _sueno == value;
    return GestureDetector(
      onTap: () => setState(() => _sueno = value),
      child: AnimatedContainer(
        duration: AppMotion.base,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.brand.withValues(alpha: 0.15)
              : AppColors.surface2Of(context),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: selected ? AppColors.brand : Colors.transparent,
            width: 2,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
            color: selected
                ? AppColors.brand
                : AppColors.textSecondary(context),
          ),
        ),
      ),
    );
  }

  Widget _textField({
    required TextEditingController controller,
    required String hint,
    int maxLines = 1,
    int? maxLength,
  }) =>
      Container(
        decoration: BoxDecoration(
          color: AppColors.surface2Of(context),
          borderRadius: BorderRadius.circular(16),
        ),
        child: TextField(
          controller: controller,
          maxLines: maxLines,
          maxLength: maxLength,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: AppColors.textSecondary(context)),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.all(16),
          ),
        ),
      );
}
