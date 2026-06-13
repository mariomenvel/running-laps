import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:running_laps/core/widgets/main_shell.dart';
import 'package:running_laps/features/auth/views/auth_page.dart';
import 'package:running_laps/features/auth/views/email_verification_pending_view.dart';
import 'package:running_laps/features/auth/views/welcome_view.dart';

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, authSnap) {
        if (authSnap.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final user = authSnap.data;
        if (user == null) return const AuthPage();

        if (!user.emailVerified) {
          return EmailVerificationPendingView(
            onVerified: () => setState(() {}),
          );
        }

        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .snapshots(),
          builder: (context, userSnap) {
            if (userSnap.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            // Usuarios existentes sin el campo → true (ya hicieron onboarding)
            final onboardingCompleted =
                userSnap.data?.data()?['onboardingCompleted'] as bool? ?? true;

            if (!onboardingCompleted) {
              return const WelcomeView();
            }

            return MainShell(key: MainShell.shellKey);
          },
        );
      },
    );
  }
}
