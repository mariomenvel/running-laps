import 'package:flutter/material.dart';
import 'package:running_laps/core/services/health_consent_service.dart';
import 'package:running_laps/core/services/health_screening_service.dart';
import 'package:running_laps/core/theme/app_colors.dart';
import 'package:running_laps/core/widgets/app_bottom_sheet.dart';
import 'package:running_laps/features/ai_coach/views/health_safety_form.dart';

/// Se asegura de que el atleta ha pasado el cribado y ha dado el
/// consentimiento del art. 9 antes de que sus datos de salud viajen al
/// proveedor de IA.
///
/// Los atletas nuevos lo resuelven en el último paso del onboarding. Este
/// sheet existe para los que ya tenían perfil creado cuando se añadió el
/// consentimiento: se ve una sola vez.
///
/// Devuelve `true` si ya había consentimiento o si el atleta acaba de darlo.
Future<bool> ensureAiCoachHealthConsent(BuildContext context) async {
  final consent = HealthConsentService();
  if (await consent.hasConsent(HealthConsentScope.aiCoach)) return true;
  if (!context.mounted) return false;

  final accepted = await showAppBottomSheet<bool>(
    context: context,
    builder: (_) => const _HealthGateSheet(),
  );
  return accepted == true;
}

class _HealthGateSheet extends StatefulWidget {
  const _HealthGateSheet();

  @override
  State<_HealthGateSheet> createState() => _HealthGateSheetState();
}

class _HealthGateSheetState extends State<_HealthGateSheet> {
  final Map<HealthScreeningQuestion, bool> _answers = {
    ...HealthScreening.allNegative,
  };
  bool _consent = false;
  bool _saving = false;

  Future<void> _confirm() async {
    setState(() => _saving = true);
    try {
      // El cribado primero: si la escritura del consentimiento fallara, no
      // queremos un consentimiento sin el cribado que lo acompaña.
      await HealthScreeningService().save(_answers);
      await HealthConsentService().grant(HealthConsentScope.aiCoach);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      debugPrint('[AiCoachHealthGate] error guardando: $e');
      if (!mounted) return;
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Antes de seguir planificando',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary(context),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Cuatro preguntas rápidas y un permiso. Una sola vez.',
              style: TextStyle(
                fontSize: 14,
                height: 1.4,
                color: AppColors.textSecondary(context),
              ),
            ),
            const SizedBox(height: 20),
            HealthSafetyForm(
              answers: _answers,
              consentGranted: _consent,
              showHeading: false,
              onAnswerChanged: (q, v) => setState(() => _answers[q] = v),
              onConsentChanged: (v) => setState(() => _consent = v),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _consent && !_saving ? _confirm : null,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.brand,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: AppColors.brandDisabledColor(),
                  disabledForegroundColor: Colors.white70,
                  minimumSize: const Size.fromHeight(52),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Text(
                  _saving ? 'Guardando...' : 'Continuar',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
