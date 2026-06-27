import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:running_laps/core/utils/app_transitions.dart';
import 'package:running_laps/core/widgets/modern_snackbar.dart';
import 'package:running_laps/features/ai_coach/data/ai_coach_automation_service.dart';
import 'package:running_laps/features/ai_coach/data/ai_coach_repository.dart';
import 'package:running_laps/features/ai_coach/views/ai_coach_onboarding_view.dart';
import 'package:running_laps/core/widgets/main_shell.dart';

/// Lanza el onboarding si el atleta no tiene perfil IA, o los settings si ya lo tiene.
/// Si weeklyPlanningEnabled está desactivado, muestra error y no navega.
Future<void> launchAiCoachOnboarding(
  BuildContext context, {
  Future<void> Function()? onCompleted,
}) async {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) return;

  final repo = AiCoachRepository();
  final providerConfig = await repo.getProviderConfig(uid: uid);

  if (!context.mounted) return;

  if (!providerConfig.weeklyPlanningEnabled) {
    ModernSnackBar.showError(
      context,
      'El entrenador IA está temporalmente desactivado.',
    );
    return;
  }

  final existingProfile = await repo.getProfile(uid: uid);

  if (!context.mounted) return;

  if (existingProfile != null) {
    MainShell.shellKey.currentState?.navigateTo(16);
    onCompleted?.call();
    return;
  }

  await Navigator.of(context).push(
    AppRoute(
      page: AiCoachOnboardingView(
        uid: uid,
        onCompleted: () async {
          if (context.mounted) {
            Navigator.of(context).pop();
          }
          await onCompleted?.call();
          await Future.delayed(const Duration(milliseconds: 500));
          try {
            await AiCoachAutomationService()
                .forceGenerateCurrentWeekPlan(uid);
          } catch (e) {
            debugPrint('[Onboarding] error generando plan: $e');
          }
        },
      ),
    ),
  );
}
