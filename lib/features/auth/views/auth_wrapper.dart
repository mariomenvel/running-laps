import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:running_laps/features/auth/views/auth_page.dart';
import 'package:running_laps/core/widgets/main_shell.dart';

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasData) return MainShell(key: MainShell.shellKey);
        return const AuthPage();
      },
    );
  }
}
