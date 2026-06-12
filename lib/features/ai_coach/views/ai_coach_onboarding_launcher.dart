import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:running_laps/core/utils/app_transitions.dart';
import 'package:running_laps/core/widgets/modern_snackbar.dart';
import 'package:running_laps/features/ai_coach/data/ai_coach_automation_service.dart';
import 'package:running_laps/features/ai_coach/data/ai_coach_repository.dart';
import 'package:running_laps/features/ai_coach/views/ai_coach_onboarding_view.dart';
import 'package:running_laps/features/ai_coach/views/ai_coach_settings_view.dart';

/// Lanza el onboarding si el atleta no tiene perfil IA, o los settings si ya lo tiene.
/// Si no hay apiKey configurada, muestra error y no navega.
Future<void> launchAiCoachOnboarding(
  BuildContext context, {
  VoidCallback? onCompleted,
}) async {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) return;

  final repo = AiCoachRepository();
  final providerConfig = await repo.getProviderConfig();

  if (!context.mounted) return;

  final apiKey = providerConfig?.apiKey?.trim() ?? '';
  if (apiKey.isEmpty) {
    ModernSnackBar.showError(
      context,
      'Configura tu API key en Perfil → Entrenador IA antes de continuar',
    );
    return;
  }

  final existingProfile = await repo.getProfile(uid: uid);

  if (!context.mounted) return;

  if (existingProfile != null) {
    await Navigator.of(context).push(
      AppRoute(page: AiCoachSettingsView(uid: uid)),
    );
    onCompleted?.call();
    return;
  }

  await Navigator.of(context).push(
    AppRoute(
      page: AiCoachOnboardingView(
        uid: uid,
        apiKey: apiKey,
        model: providerConfig!.model,
        onCompleted: () async {
          Navigator.of(context).pop();
          try {
            await AiCoachAutomationService()
                .forceGenerateCurrentWeekPlan(uid);
          } catch (e) {
            debugPrint('[Onboarding] error generando plan: $e');
          }
          onCompleted?.call();
        },
      ),
    ),
  );
}
