//Es el núcleo visual que envuelve toda la app. Define el MaterialApp:

//ítulo de la app.

//Tema global (lo importas desde theme.dart).

//Enrutador (lo importas desde router.dart).

//lags globales (banner debug, etc.).

import 'package:flutter/material.dart';
import 'router.dart';
import 'theme.dart';

class RunningLapsApp extends StatelessWidget {
  const RunningLapsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: "Running Laps",
      theme: buildAppTheme(),
      onGenerateRoute: AppRouter.onGenerateRoute,
      initialRoute: AppRouter.initialRoute,
      debugShowCheckedModeBanner: false,
    );
  }
}
