import 'package:flutter/material.dart';

// --- IMPORTS AÑADIDOS ---
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
// Este archivo lo genera 'flutterfire configure'
// Asegúrate de que existe en la carpeta 'lib'
import 'firebase_options.dart'; 
// --- FIN DE IMPORTS AÑADIDOS ---

import 'features/training/views/training_start_view.dart';

// 1. Convertimos main en 'async'
void main() async {

  // 2. Nos aseguramos de que Flutter esté listo
  WidgetsFlutterBinding.ensureInitialized();

  // 3. Inicializamos Firebase ANTES de 'runApp'
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // 4. Intentamos el login anónimo
  try {
    await FirebaseAuth.instance.signInAnonymously();
    print("Usuario anónimo logueado con éxito.");
  } catch (e) {
    print("Error en login anónimo: $e");
    // Opcional: podrías mostrar un error aquí si es crítico
  }

  // 5. Lanzamos la app (ahora ya estamos logueados)
  runApp(const MyApp());
}

// Tu clase MyApp no cambia
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Prueba TrainingStartView',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.purple,
      ),
      home: const TrainingStartView(),
    );
  }
}