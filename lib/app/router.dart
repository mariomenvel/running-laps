import 'package:flutter/material.dart';
import 'package:running_laps/features/home/views/home_view.dart';

// Auth
import '../features/auth/views/login_view.dart';
import '../features/auth/views/register_view.dart';

// Training
import '../features/training/views/training_start_view.dart';
import '../features/training/views/training_session_view.dart';
import '../features/training/views/training_pause_view.dart';

class AppRouter {
  // 🔹 Ruta inicial al arrancar la app
  static String get initialRoute {
    return "/login";
  }

  // 🔹 Definición de todas las rutas
  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      // ------------------ AUTH ------------------
      case "/login":
        return MaterialPageRoute(builder: (_) => const HomeView());
      case "/register":
        return MaterialPageRoute(builder: (_) => const HomeView());

      // ----------------- TRAINING ----------------
      case "/training/start":
        return MaterialPageRoute(builder: (_) => const TrainingStartView());
      case "/training/running":
        return MaterialPageRoute(builder: (_) => const TrainingSessionView());
      case "/training/pause":
        return MaterialPageRoute(builder: (_) => const TrainingStartView());

      // ------------- RUTA POR DEFECTO ------------
      default:
        return MaterialPageRoute(builder: (_) => const HomeView());
    }
  }
}
