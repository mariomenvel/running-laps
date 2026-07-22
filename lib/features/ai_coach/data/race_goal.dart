import 'package:cloud_firestore/cloud_firestore.dart';

/// Distancia oficial de una competición. Los metros coinciden con los
/// del editor de sesiones (`raceDistanceM`) para que la migración sea directa.
enum RaceDistance { k5, k10, halfMarathon, marathon, other }

extension RaceDistanceX on RaceDistance {
  /// Metros de la distancia estándar. `null` para [RaceDistance.other]
  /// (la distancia real vive en `RaceGoal.customDistanceM`).
  int? get standardMeters {
    switch (this) {
      case RaceDistance.k5:
        return 5000;
      case RaceDistance.k10:
        return 10000;
      case RaceDistance.halfMarathon:
        return 21097;
      case RaceDistance.marathon:
        return 42195;
      case RaceDistance.other:
        return null;
    }
  }

  String get label {
    switch (this) {
      case RaceDistance.k5:
        return '5K';
      case RaceDistance.k10:
        return '10K';
      case RaceDistance.halfMarathon:
        return 'Media maratón';
      case RaceDistance.marathon:
        return 'Maratón';
      case RaceDistance.other:
        return 'Otra';
    }
  }

  String get toValue {
    switch (this) {
      case RaceDistance.k5:
        return '5k';
      case RaceDistance.k10:
        return '10k';
      case RaceDistance.halfMarathon:
        return 'half_marathon';
      case RaceDistance.marathon:
        return 'marathon';
      case RaceDistance.other:
        return 'other';
    }
  }

  static RaceDistance fromValue(String value) {
    switch (value) {
      case '5k':
        return RaceDistance.k5;
      case '10k':
        return RaceDistance.k10;
      case 'half_marathon':
        return RaceDistance.halfMarathon;
      case 'marathon':
        return RaceDistance.marathon;
      default:
        return RaceDistance.other;
    }
  }

  /// Deduce la distancia a partir de metros (para migrar `raceDistanceM`).
  static RaceDistance fromMeters(int? meters) {
    switch (meters) {
      case 5000:
        return RaceDistance.k5;
      case 10000:
        return RaceDistance.k10;
      case 21097:
        return RaceDistance.halfMarathon;
      case 42195:
        return RaceDistance.marathon;
      default:
        return RaceDistance.other;
    }
  }
}

/// Prioridad de la competición — determina cuánto adapta el plan el Coach.
/// Equivale al clásico A/B/C de periodización: alta = taper completo,
/// media = taper corto, baja = sin taper (se corre como un entreno).
enum RaceGoalPriority { high, medium, low }

extension RaceGoalPriorityX on RaceGoalPriority {
  String get label {
    switch (this) {
      case RaceGoalPriority.high:
        return 'Alta';
      case RaceGoalPriority.medium:
        return 'Media';
      case RaceGoalPriority.low:
        return 'Baja';
    }
  }

  String get toValue {
    switch (this) {
      case RaceGoalPriority.high:
        return 'high';
      case RaceGoalPriority.medium:
        return 'medium';
      case RaceGoalPriority.low:
        return 'low';
    }
  }

  static RaceGoalPriority fromValue(String value) {
    switch (value) {
      case 'high':
        return RaceGoalPriority.high;
      case 'low':
        return RaceGoalPriority.low;
      default:
        return RaceGoalPriority.medium;
    }
  }
}

/// Una competición objetivo del atleta: fecha, distancia y prioridad.
///
/// No es una sesión de entreno — es la fecha hacia la que se orienta la
/// periodización. `date` se guarda como clave 'yyyy-MM-dd' (igual que
/// `AthleteSession.date`) para casar con el calendario y permitir queries
/// por rango sin problemas de zona horaria.
class RaceGoal {
  final String id;
  final String date;
  final RaceDistance distance;
  final int? customDistanceM;
  final String? name;
  final int? targetTimeSeconds;
  final RaceGoalPriority priority;
  final DateTime createdAt;
  final DateTime updatedAt;

  const RaceGoal({
    required this.id,
    required this.date,
    required this.distance,
    this.customDistanceM,
    this.name,
    this.targetTimeSeconds,
    this.priority = RaceGoalPriority.high,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Metros efectivos de la carrera (estándar o personalizada).
  int? get distanceMeters => distance.standardMeters ?? customDistanceM;

  /// La fecha parseada a medianoche local, o `null` si no es válida.
  DateTime? get parsedDate => DateTime.tryParse(date);

  /// Etiqueta corta para mostrar (ej: "5K", "Trail 15K").
  String get displayTitle {
    final base = distance == RaceDistance.other && customDistanceM != null
        ? '${(customDistanceM! / 1000).toStringAsFixed(customDistanceM! % 1000 == 0 ? 0 : 1)}K'
        : distance.label;
    if (name != null && name!.trim().isNotEmpty) {
      return '$base · ${name!.trim()}';
    }
    return base;
  }

  factory RaceGoal.fromMap(String id, Map<String, dynamic> map) {
    return RaceGoal(
      id: id,
      date: map['date'] as String? ?? '',
      distance: RaceDistanceX.fromValue(map['distance'] as String? ?? 'other'),
      customDistanceM: (map['customDistanceM'] as num?)?.toInt(),
      name: map['name'] as String?,
      targetTimeSeconds: (map['targetTimeSeconds'] as num?)?.toInt(),
      priority: RaceGoalPriorityX.fromValue(map['priority'] as String? ?? 'high'),
      createdAt: _toDateTime(map['createdAt']),
      updatedAt: _toDateTime(map['updatedAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'date': date,
      'distance': distance.toValue,
      'priority': priority.toValue,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      if (customDistanceM != null) 'customDistanceM': customDistanceM,
      if (name != null) 'name': name,
      if (targetTimeSeconds != null) 'targetTimeSeconds': targetTimeSeconds,
    };
  }

  RaceGoal copyWith({
    String? date,
    RaceDistance? distance,
    Object? customDistanceM = _sentinel,
    Object? name = _sentinel,
    Object? targetTimeSeconds = _sentinel,
    RaceGoalPriority? priority,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return RaceGoal(
      id: id,
      date: date ?? this.date,
      distance: distance ?? this.distance,
      customDistanceM: customDistanceM == _sentinel
          ? this.customDistanceM
          : customDistanceM as int?,
      name: name == _sentinel ? this.name : name as String?,
      targetTimeSeconds: targetTimeSeconds == _sentinel
          ? this.targetTimeSeconds
          : targetTimeSeconds as int?,
      priority: priority ?? this.priority,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  static const Object _sentinel = Object();
}

DateTime _toDateTime(dynamic value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  if (value is String) {
    final parsed = DateTime.tryParse(value);
    if (parsed != null) return parsed;
  }
  return DateTime.now();
}

/// Clave 'yyyy-MM-dd' de un día (para `RaceGoal.date`).
String raceGoalDateKey(DateTime value) {
  final date = DateTime(value.year, value.month, value.day);
  return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}

/// Selección de objetivos: qué carrera ancla el taper, cuál mostrar, etc.
extension RaceGoalListX on List<RaceGoal> {
  /// Objetivos de hoy en adelante, ordenados por fecha ascendente.
  List<RaceGoal> upcomingFrom(DateTime now) {
    final todayKey = raceGoalDateKey(now);
    final list = where((g) => g.date.compareTo(todayKey) >= 0).toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    return list;
  }

  /// La próxima carrera de prioridad alta — la que marca la periodización.
  RaceGoal? nextPrimaryFrom(DateTime now) {
    for (final goal in upcomingFrom(now)) {
      if (goal.priority == RaceGoalPriority.high) return goal;
    }
    return null;
  }

  /// La próxima carrera de cualquier prioridad.
  RaceGoal? nextAnyFrom(DateTime now) {
    final upcoming = upcomingFrom(now);
    return upcoming.isEmpty ? null : upcoming.first;
  }
}
