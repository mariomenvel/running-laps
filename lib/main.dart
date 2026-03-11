import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'firebase_options.dart'; // Generado por flutterfire CLI
import 'package:firebase_auth/firebase_auth.dart';
import 'features/home/views/home_view.dart';
import 'features/auth/views/auth_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inicializar locale para el calendario en español
  await initializeDateFormatting('es_ES', null);

  // Inicializar Firebase para Web, Android e iOS
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Running Laps',
      theme: ThemeData(
        primarySwatch: Colors.purple,
        visualDensity: VisualDensity.adaptivePlatformDensity,
        pageTransitionsTheme: const PageTransitionsTheme(
          builders: {
            TargetPlatform.android: CupertinoPageTransitionsBuilder(),
            TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          },
        ),
      ),
      home: const AuthWrapper(),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // Esperar a que Firebase determine el estado inicial
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }
        
        // Si hay datos, el usuario está logueado
        if (snapshot.hasData) {
          return const HomeView();
        }
        
        // Si no hay datos, mostrar página de login
        return const AuthPage();
      },
    );
  }
}

