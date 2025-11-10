// ============================================================
// Clase: RunningLapsApp
// ------------------------------------------------------------
// Este es el núcleo visual de toda la aplicación.
// Envuelve todos los widgets dentro de un MaterialApp y define:
//
//   ✅ Título de la aplicación (visible en Android multitarea)
//   🎨 Tema global (colores, tipografía, estilo de botones...)
//   🧭 Sistema de rutas (navegación entre pantallas)
//   ⚙️ Configuraciones globales (como ocultar el banner debug)
//
// Este widget normalmente se lanza desde main.dart con:
//     void main() => runApp(const RunningLapsApp());
// ============================================================

import 'package:flutter/material.dart';
import 'router.dart'; // Define las rutas y sus pantallas asociadas
import 'theme.dart'; // Define el tema visual global (colores, fuentes, etc.)

class RunningLapsApp extends StatelessWidget {
  const RunningLapsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      // --------------------------------------------------------
      // 🏷️ TÍTULO GLOBAL
      // --------------------------------------------------------
      // Aparece en la vista de apps recientes o título del sistema.
      title: "Running Laps",

      // --------------------------------------------------------
      // 🎨 TEMA GLOBAL
      // --------------------------------------------------------
      // Importado desde theme.dart → centraliza los colores, tipografía,
      // estilo de botones, AppBars, etc.
      theme: buildAppTheme(),

      // --------------------------------------------------------
      // 🧭 ENRUTADOR
      // --------------------------------------------------------
      // Define cómo se generan las rutas (pantallas) dentro de la app.
      // AppRouter es una clase que implementa onGenerateRoute y define
      // initialRoute, para tener toda la navegación en un solo lugar.
      onGenerateRoute: AppRouter.onGenerateRoute,
      initialRoute: AppRouter.initialRoute,

      // --------------------------------------------------------
      // ⚙️ OPCIONES GLOBALES
      // --------------------------------------------------------
      // Oculta el banner de “DEBUG” en la esquina superior derecha.
      debugShowCheckedModeBanner: false,
    );
  }
}
