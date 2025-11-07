//Este codigo mueve entre pantallas de la app

import 'package:flutter/material.dart';
import '../features/auth/views/login_view.dart';
import '../features/training/views/training_list_view.dart';

import 'package:flutter/material.dart';
import '../features/auth/views/login_view.dart';
import '../features/training/views/training_list_view.dart';

class AppRouter {
  static String get initialRoute {
    return "/login";
  }

  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    if (settings.name == "/login") {
      return MaterialPageRoute(builder: (_) => const LoginView());
    }
    if (settings.name == "/trainings") {
      return MaterialPageRoute(builder: (_) => const TrainingListView());
    }
    return MaterialPageRoute(builder: (_) => const LoginView());
  }
}
