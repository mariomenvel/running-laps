import 'package:flutter/material.dart';
import 'package:running_laps/core/theme/app_colors.dart';

/// Rango de una zona de entrenamiento por FC.
class ZoneRange {
  final int zone;    // 1-5
  final String name; // nombre descriptivo
  final int minBpm;  // inclusive
  final int maxBpm;  // exclusive (Z5: sin techo real, se usa 999)
  final Color color;

  const ZoneRange({
    required this.zone,
    required this.name,
    required this.minBpm,
    required this.maxBpm,
    required this.color,
  });
}

/// Servicio de lógica pura para el cálculo de zonas de entrenamiento por FC.
///
/// Sin estado mutable — todos los métodos son funciones puras.
/// Sin dependencias de Firebase.
class ZonesService {
  static final ZonesService _instance = ZonesService._internal();
  factory ZonesService() => _instance;
  ZonesService._internal();

  // ── Nombres de zona ────────────────────────────────────────────────
  static const List<String> _names = [
    'Regenerativo',
    'Base aeróbica',
    'Umbral',
    'VO2max',
    'Máximo',
  ];

  static const List<Color> _colors = [
    AppColors.rest,
    AppColors.rpeLow,
    AppColors.rpeMid,
    AppColors.effort,
    AppColors.rpeMax,
  ];

  // Límites inferiores por zona (porcentaje de FCmáx, inclusive).
  // Z1: 0%, Z2: 60%, Z3: 70%, Z4: 80%, Z5: 90%
  static const List<double> _lowerBounds = [0.0, 0.60, 0.70, 0.80, 0.90];

  /// FCmáx efectiva.
  ///
  /// Usa [fcMax] manual si no es null.
  /// Si es null, intenta calcular `220 - edad` a partir de [birthDate]
  /// (formato ISO8601 date-only: "1990-05-15").
  /// Devuelve null si no hay datos suficientes para calcular.
  int? fcMaxEffective(int? fcMax, String? birthDate) {
    if (fcMax != null) return fcMax;
    if (birthDate == null) return null;

    final birth = DateTime.tryParse(birthDate);
    if (birth == null) return null;

    final today = DateTime.now();
    int age = today.year - birth.year;
    if (today.month < birth.month ||
        (today.month == birth.month && today.day < birth.day)) {
      age--;
    }
    if (age <= 0) return null;

    return 220 - age;
  }

  /// Lista de 5 [ZoneRange] calculados para el [fcMax] dado.
  ///
  /// Precondición: [fcMax] > 0.
  List<ZoneRange> zonesFor(int fcMax) {
    assert(fcMax > 0, 'fcMax debe ser mayor que 0');

    return List.generate(5, (i) {
      final min = (fcMax * _lowerBounds[i]).round();
      // El límite superior de esta zona es el límite inferior de la siguiente,
      // excepto Z5 que no tiene techo real (representado como 999).
      final max = i < 4 ? (fcMax * _lowerBounds[i + 1]).round() : 999;

      return ZoneRange(
        zone: i + 1,
        name: _names[i],
        minBpm: min,
        maxBpm: max,
        color: _colors[i],
      );
    });
  }

  /// Zona (1-5) a la que pertenece [fc] para la [fcMax] dada.
  int? zoneFor(int fc, int fcMax) {
    final zones = zonesFor(fcMax);
    for (final zone in zones.reversed) {
      if (fc >= zone.minBpm) return zone.zone;
    }
    return 1; // por debajo de Z1 mínimo → Z1
  }
}
