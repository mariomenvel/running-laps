//Contiene el look global
//Colores, tipografías, estilos de botones, etc.

import 'package:flutter/material.dart';

ThemeData buildAppTheme() {
  // Paleta base a partir de un color semilla (Material 3)
  final ThemeData base = ThemeData(
    useMaterial3: true,
    colorSchemeSeed: const Color(0xFF2E7D32), // Verde Running Laps
    brightness: Brightness.light,
  );

  // Ajustes comunes para móviles: AppBar, botones, campos de texto
  return base.copyWith(
    appBarTheme: const AppBarTheme(centerTitle: true, elevation: 0.0),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ButtonStyle(
        minimumSize: WidgetStatePropertyAll<Size>(Size(140.0, 44.0)),
        shape: WidgetStatePropertyAll<OutlinedBorder>(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(12.0)),
          ),
        ),
      ),
    ),
    inputDecorationTheme: const InputDecorationTheme(
      border: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(12.0)),
      ),
      contentPadding: EdgeInsets.symmetric(horizontal: 12.0, vertical: 10.0),
    ),
  );
}
