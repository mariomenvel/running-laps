// main.dart
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'features/auth/views/login_view.dart';
import 'features/auth/data/auth_repository.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'features/training/data/entrenamiento.dart';
import 'features/training/data/serie.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    final auth = AuthRepository();
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Running Laps',
      home: StreamBuilder<User?>(
        stream: auth.authStateChanges(),
        builder: (context, snap) {
          final user = snap.data;
          // Aquí luego pondremos Home si hay sesión
          return const LoginPage();
        },
      ),
    );
  }
}
