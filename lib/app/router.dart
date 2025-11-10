import 'package:flutter/material.dart';

class AppRouter {
  static const String login = '/login';
  static const String register = '/register';
  static const String trainingStart = '/training/start';
  static const String trainingRunning = '/training/running';
  static const String trainingPause = '/training/pause';

  static String get initialRoute => login;

  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    Widget page;
    switch (settings.name) {
      case login:
        page = const _Placeholder(title: 'Login (placeholder)');
        break;
      case register:
        page = const _Placeholder(title: 'Register (placeholder)');
        break;
      case trainingStart:
        page = const _Placeholder(title: 'Training Start (placeholder)');
        break;
      case trainingRunning:
        page = const _Placeholder(title: 'Training Running (placeholder)');
        break;
      case trainingPause:
        page = const _Placeholder(title: 'Training Pause (placeholder)');
        break;
      default:
        page = const _Placeholder(title: 'Ruta no encontrada');
    }
    return MaterialPageRoute(builder: (_) => page);
  }
}

// Pantalla temporal para no romper compilación mientras creas las Views reales
class _Placeholder extends StatelessWidget {
  final String title;
  const _Placeholder({required this.title, super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(child: Text(title)),
    );
  }
}
