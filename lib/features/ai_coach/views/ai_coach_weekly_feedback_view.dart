import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../data/ai_coach_models.dart';
import '../data/ai_coach_repository.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/modern_snackbar.dart';
import 'package:flutter_svg/flutter_svg.dart';

class AiCoachWeeklyFeedbackView extends StatefulWidget {
  final String weekStart;
  final VoidCallback? onCompleted;
  final bool generatePlanAfter;

  const AiCoachWeeklyFeedbackView({
    super.key,
    required this.weekStart,
    this.onCompleted,
    this.generatePlanAfter = true,
  });

  @override
  State<AiCoachWeeklyFeedbackView> createState() =>
      _AiCoachWeeklyFeedbackViewState();
}

class _AiCoachWeeklyFeedbackViewState
    extends State<AiCoachWeeklyFeedbackView> {

  int _sensaciones = 3;
  String _sueno = 'bien';
  final _molestiaController = TextEditingController();
  final _observacionesController = TextEditingController();
  bool _isSaving = false;

  @override
  void dispose() {
    _molestiaController.dispose();
    _observacionesController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

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
      createdAt: DateTime.now(),
    );

    try {
      await AiCoachRepository().saveWeeklyFeedback(feedback);
      if (!mounted) return;
      ModernSnackBar.showSuccess(context, '¡Gracias! Tu coach lo tendrá en cuenta');
      widget.onCompleted?.call();
      Navigator.of(context).pop();
    } catch (e) {
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
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(
            'Saltar',
            style: TextStyle(color: AppColors.textSecondary(context)),
          ),
        ),
        leadingWidth: 80,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
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

                    _sectionLabel('¿Cómo te has sentido entrenando?'),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: List.generate(5, (i) {
                        final val = i + 1;
                        final selected = _sensaciones == val;
                        return GestureDetector(
                          onTap: () => setState(() => _sensaciones = val),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
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
                    const SizedBox(height: 32),

                    _sectionLabel('¿Has dormido bien?'),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _suenoChip('bien', '😴 Bien'),
                        _suenoChip('regular', '🌙 Regular'),
                        _suenoChip('mal', '😵 Mal'),
                        _suenoChip('no_medido', '🤷 No medido'),
                      ],
                    ),
                    const SizedBox(height: 32),

                    _sectionLabel('¿Algún dolor o molestia? (opcional)'),
                    const SizedBox(height: 12),
                    _textField(
                      controller: _molestiaController,
                      hint: 'Ej: Molestia en el talón izquierdo...',
                    ),
                    const SizedBox(height: 24),

                    _sectionLabel('¿Algo más para tu coach? (opcional)'),
                    const SizedBox(height: 12),
                    _textField(
                      controller: _observacionesController,
                      hint: 'Ej: Esta semana viajé y no pude entrenar como quería...',
                      maxLines: 3,
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
                  child: _isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Enviar al coach',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
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

  Widget _suenoChip(String value, String label) {
    final selected = _sueno == value;
    return GestureDetector(
      onTap: () => setState(() => _sueno = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
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
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
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
  }) =>
      Container(
        decoration: BoxDecoration(
          color: AppColors.surface2Of(context),
          borderRadius: BorderRadius.circular(16),
        ),
        child: TextField(
          controller: controller,
          maxLines: maxLines,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: AppColors.textSecondary(context)),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.all(16),
          ),
        ),
      );
}
