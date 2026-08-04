import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:running_laps/core/services/health_screening_service.dart';
import 'package:running_laps/core/theme/app_colors.dart';

/// Cribado de seguridad + consentimiento de datos de salud del Coach IA.
///
/// Lo comparten dos sitios para que el texto sea literalmente el mismo en los
/// dos —si divergen, el consentimiento deja de ser demostrable—:
/// el último paso del onboarding (atletas nuevos) y el sheet de
/// `ensureAiCoachHealthConsent` (atletas que ya tenían perfil).
///
/// Criterio de diseño: esto no es un muro legal. Cuatro interruptores que casi
/// todo el mundo deja en "no", una casilla y una línea de letra pequeña.
class HealthSafetyForm extends StatelessWidget {
  const HealthSafetyForm({
    super.key,
    required this.answers,
    required this.consentGranted,
    required this.onAnswerChanged,
    required this.onConsentChanged,
    this.showHeading = true,
  });

  final Map<HealthScreeningQuestion, bool> answers;
  final bool consentGranted;
  final void Function(HealthScreeningQuestion, bool) onAnswerChanged;
  final ValueChanged<bool> onConsentChanged;

  /// El onboarding pinta su propio encabezado con el estilo del wizard.
  final bool showHeading;

  bool get _anyPositive => answers.values.any((v) => v);

  bool get _hasCardiacFlag =>
      (answers[HealthScreeningQuestion.medicalSupervision] ?? false) ||
      (answers[HealthScreeningQuestion.chestPain] ?? false) ||
      (answers[HealthScreeningQuestion.heartMedication] ?? false);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showHeading) ...[
          Text(
            'Última cosa y empezamos.',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w600,
              height: 1.3,
              color: AppColors.textPrimary(context),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Cuatro preguntas rápidas para que el plan empiece por donde te '
            'toca. La mayoría responde "no" a las cuatro.',
            style: TextStyle(
              fontSize: 15,
              height: 1.4,
              color: AppColors.textSecondary(context),
            ),
          ),
          const SizedBox(height: 24),
        ],
        for (final question in HealthScreeningQuestion.values)
          _QuestionRow(
            question: question,
            value: answers[question] ?? false,
            onChanged: (v) => onAnswerChanged(question, v),
          ),
        if (_anyPositive) ...[
          const SizedBox(height: 8),
          _AdviceNote(cardiac: _hasCardiacFlag),
        ],
        const SizedBox(height: 24),
        _ConsentTile(
          granted: consentGranted,
          onChanged: onConsentChanged,
        ),
        const SizedBox(height: 16),
        Text(
          'Running Laps no es un servicio médico. Los planes son sugerencias '
          'generadas automáticamente y no sustituyen el criterio de un médico '
          'o un entrenador.',
          style: TextStyle(
            fontSize: 12,
            height: 1.4,
            color: AppColors.textSecondary(context),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _QuestionRow extends StatelessWidget {
  const _QuestionRow({
    required this.question,
    required this.value,
    required this.onChanged,
  });

  final HealthScreeningQuestion question;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Text(
              question.label,
              style: TextStyle(
                fontSize: 15,
                height: 1.35,
                color: AppColors.textPrimary(context),
              ),
            ),
          ),
          const SizedBox(width: 16),
          CupertinoSwitch(
            value: value,
            onChanged: onChanged,
            activeTrackColor: AppColors.brand,
          ),
        ],
      ),
    );
  }
}

/// Aviso que aparece solo si hay algún "sí". Deliberadamente en tono
/// informativo y no de alarma: no bloquea nada, y decirlo así evita que el
/// atleta responda "no" a todo para quitárselo de encima.
class _AdviceNote extends StatelessWidget {
  const _AdviceNote({required this.cardiac});

  final bool cardiac;

  @override
  Widget build(BuildContext context) {
    final message = cardiac
        ? 'Puedes usar Running Laps con normalidad, pero en tu caso conviene '
            'que un médico te dé el visto bueno antes de subir la intensidad. '
            'Tu plan empezará suave.'
        : 'Puedes usar Running Laps con normalidad. Tu plan empezará suave y '
            'el Coach te irá preguntando por esa molestia hasta que se te '
            'pase.';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.feedbackInfo.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.feedbackInfo.withValues(alpha: 0.30),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.info_outline,
            size: 18,
            color: AppColors.feedbackInfo,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: 13,
                height: 1.4,
                color: AppColors.textPrimary(context),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Consentimiento explícito del art. 9 RGPD: casilla desmarcada por defecto y
/// acción afirmativa del usuario. No se puede premarcar ni dar por aceptada
/// junto con los términos — por eso vive aquí y no en el registro.
class _ConsentTile extends StatelessWidget {
  const _ConsentTile({required this.granted, required this.onChanged});

  final bool granted;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => onChanged(!granted),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface2Of(context),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: granted
                ? AppColors.brand.withValues(alpha: 0.50)
                : AppColors.borderOf(context),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Checkbox(checked: granted),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Autorizo el uso de mis datos de salud para generar mis '
                    'planes',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      height: 1.35,
                      color: AppColors.textPrimary(context),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Molestias y lesiones que me cuentes, pulso, edad y sexo. '
                    'Se procesan con nuestro proveedor de IA, no se usan para '
                    'entrenar modelos y puedes retirar el permiso cuando '
                    'quieras desde los ajustes del Coach.',
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.4,
                      color: AppColors.textSecondary(context),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Checkbox extends StatelessWidget {
  const _Checkbox({required this.checked});

  final bool checked;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        color: checked ? AppColors.brand : Colors.transparent,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: checked ? AppColors.brand : AppColors.borderOf(context),
          width: 2,
        ),
      ),
      child: checked
          ? const Icon(Icons.check, size: 15, color: Colors.white)
          : null,
    );
  }
}
