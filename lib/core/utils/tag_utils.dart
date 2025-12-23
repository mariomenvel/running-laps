import 'package:flutter/material.dart';

class TagUtils {
  static const List<Color> _palette = [
    Colors.red,
    Colors.pink,
    Colors.purple,
    Colors.deepPurple,
    Colors.indigo,
    Colors.blue,
    Colors.lightBlue,
    Colors.cyan,
    Colors.teal,
    Colors.green,
    Colors.lightGreen,
    Colors.lime,
    Colors.orange, // Skip yellow as it's hard to read? Maybe darker shade.
    Colors.deepOrange,
    Colors.brown,
    Colors.blueGrey,
  ];

  static Color getColor(String? tag) {
    if (tag == null || tag.trim().isEmpty) {
      return Colors.grey.shade300; // Gris clarito para sin etiqueta
    }
    
    // Deterministic color based on string content
    final int hash = tag.trim().toLowerCase().hashCode;
    final int index = hash.abs() % _palette.length;
    return _palette[index];
  }
}
