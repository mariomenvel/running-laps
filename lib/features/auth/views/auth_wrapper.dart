import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:running_laps/core/services/notification_service.dart';
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
  bool _notificationsSynced = false;
  Timer? _verificationTimer;

  @override
  void dispose() {
    _verificationTimer?.cancel();
    super.dispose();
  }

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
          _verificationTimer ??= Timer.periodic(
            const Duration(seconds: 3),
            (_) async {
              await FirebaseAuth.instance.currentUser?.reload();
              final verified =
                  FirebaseAuth.instance.currentUser?.emailVerified ?? false;
              if (verified && mounted) setState(() {});
            },
          );
          return EmailVerificationPendingView(
            onVerified: () => setState(() {}),
          );
        } else {
          _verificationTimer?.cancel();
          _verificationTimer = null;
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

            if (!_notificationsSynced) {
              _notificationsSynced = true;
              final isAthlete =
                  userSnap.data?.data()?['isAthleteMode'] as bool? ?? false;
              if (isAthlete) {
                NotificationService()
                    .scheduleWeeklyFeedbackReminder()
                    .catchError((Object e) =>
                        debugPrint('[Notifications] feedback reminder: $e'));
                NotificationService()
                    .syncTrainingReminders(user.uid)
                    .catchError((Object e) =>
                        debugPrint('[Notifications] training reminders: $e'));
              }
            }

            return MainShell(key: MainShell.shellKey);
          },
        );
      },
    );
  }
}
