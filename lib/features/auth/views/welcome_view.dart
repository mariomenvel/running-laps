import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:running_laps/core/theme/app_colors.dart';
import 'package:running_laps/features/ai_coach/views/ai_coach_onboarding_launcher.dart';

class WelcomeView extends StatelessWidget {
  const WelcomeView({super.key});

  Future<void> _completeOnboarding() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .update({'onboardingCompleted': true});
    // AuthWrapper reacciona automáticamente al stream de Firestore
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Container(
        decoration: isDark
            ? const BoxDecoration(color: AppColors.backgroundDark)
            : const BoxDecoration(
                color: Colors.white,
                image: DecorationImage(
                  image: AssetImage('assets/images/fondo.png'),
                  fit: BoxFit.cover,
                  opacity: 0.6,
                ),
              ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Image.asset(
                    'assets/images/icono_launcher.png',
                    height: 100,
                    fit: BoxFit.contain,
                  ),
                ),
                const SizedBox(height: 40),
                Text(
                  '¡Bienvenido a Running Laps!',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : const Color(0xFF1C1C1E),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                Text(
                  'Running Laps es tu compañero de entrenamiento. Puedes empezar a registrar tus carreras ahora mismo, o activar tu entrenador personal con IA — gratis durante la beta — para recibir un plan semanal adaptado a ti.',
                  style: TextStyle(
                    fontSize: 15,
                    height: 1.6,
                    color: AppColors.textSecondary(context),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 48),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: FilledButton(
                    onPressed: () {
                      launchAiCoachOnboarding(
                        context,
                        onCompleted: () async {
                          try {
                            final uid =
                                FirebaseAuth.instance.currentUser?.uid;
                            if (uid == null) return;
                            await FirebaseFirestore.instance
                                .collection('users')
                                .doc(uid)
                                .update({
                              'onboardingCompleted': true,
                              'isAthleteMode': true,
                            });
                            debugPrint(
                                '[WelcomeView] onboardingCompleted: true ✓');
                          } catch (e) {
                            debugPrint(
                                '[WelcomeView] error escribiendo onboardingCompleted: $e');
                          }
                        },
                      );
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.brand,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Text(
                      'Activar entrenador IA (gratis)',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: _completeOnboarding,
                  child: Text(
                    'Empezar sin entrenador',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary(context),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
