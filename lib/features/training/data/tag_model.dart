import 'package:flutter/material.dart';

/// Modelo para representar una etiqueta personalizada de entrenamiento
class TrainingTag {
  final String name;    // Nombre único de la etiqueta
  final int colorValue; // Color en formato ARGB (0xFFRRGGBB)

  TrainingTag({
    required this.name,
    required this.colorValue,
  });

  // Convertir a Color de Flutter
  Color get color => Color(colorValue);

  /// Serializar para guardar en Firestore
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'color': colorValue,
    };
  }

  /// Deserializar desde Firestore
  static TrainingTag fromMap(Map<String, dynamic> map) {
    return TrainingTag(
      name: map['name'] as String,
      colorValue: (map['color'] as num).toInt(),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TrainingTag &&
          runtimeType == other.runtimeType &&
          name == other.name;

  @override
  int get hashCode => name.hashCode;
}

/// Colores predefinidos para selección de etiquetas
class TagColors {
  static const List<Color> palette = [
    Color(0xFF8E24AA),  // Morado (brand)
    Color(0xFF1976D2),  // Azul
    Color(0xFF43A047),  // Verde
    Color(0xFFFDD835),  // Amarillo
    Color(0xFFFF6F00),  // Naranja
    Color(0xFFE53935),  // Rojo
    Color(0xFF546E7A),  // Gris azulado
    Color(0xFFD81B60),  // Rosa
    Color(0xFF00897B),  // Teal
    Color(0xFF3949AB),  // Indigo
  ];

  static Color fromIndex(int index) {
    return palette[index % palette.length];
  }

  static int indexOf(Color color) {
    return palette.indexOf(color);
  }
}

