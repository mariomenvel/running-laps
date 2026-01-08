import 'enums.dart';

/// Filtros para determinar qué entrenamientos cuentan en un reto
class ChallengeFilters {
  final bool requireGps;
  final List<String>? tagIdsAny;  // Si no es null, al menos uno de estos tags debe estar presente
  final int? minDistanceM;
  final int? maxDistanceM;
  final double? minRpe;
  final double? maxRpe;

  const ChallengeFilters({
    this.requireGps = false,
    this.tagIdsAny,
    this.minDistanceM,
    this.maxDistanceM,
    this.minRpe,
    this.maxRpe,
  });

  Map<String, dynamic> toMap() {
    return {
      'requireGps': requireGps,
      if (tagIdsAny != null) 'tagIdsAny': tagIdsAny,
      if (minDistanceM != null) 'minDistanceM': minDistanceM,
      if (maxDistanceM != null) 'maxDistanceM': maxDistanceM,
      if (minRpe != null) 'minRpe': minRpe,
      if (maxRpe != null) 'maxRpe': maxRpe,
    };
  }

  static ChallengeFilters fromMap(Map<String, dynamic> map) {
    return ChallengeFilters(
      requireGps: map['requireGps'] as bool? ?? false,
      tagIdsAny: map['tagIdsAny'] != null 
          ? List<String>.from(map['tagIdsAny'] as List)
          : null,
      minDistanceM: map['minDistanceM'] as int?,
      maxDistanceM: map['maxDistanceM'] as int?,
      minRpe: (map['minRpe'] as num?)?.toDouble(),
      maxRpe: (map['maxRpe'] as num?)?.toDouble(),
    );
  }

  ChallengeFilters copyWith({
    bool? requireGps,
    List<String>? tagIdsAny,
    int? minDistanceM,
    int? maxDistanceM,
    double? minRpe,
    double? maxRpe,
  }) {
    return ChallengeFilters(
      requireGps: requireGps ?? this.requireGps,
      tagIdsAny: tagIdsAny ?? this.tagIdsAny,
      minDistanceM: minDistanceM ?? this.minDistanceM,
      maxDistanceM: maxDistanceM ?? this.maxDistanceM,
      minRpe: minRpe ?? this.minRpe,
      maxRpe: maxRpe ?? this.maxRpe,
    );
  }
}

/// Objetivo personal de un reto
class ChallengeGoal {
  final GoalKind kind;
  final double value;
  final String? displayLabel;  // Texto opcional para mostrar (ej: "30 km", "3 sesiones")

  const ChallengeGoal({
    required this.kind,
    required this.value,
    this.displayLabel,
  });

  Map<String, dynamic> toMap() {
    return {
      'kind': kind.toFirestore(),
      'value': value,
      if (displayLabel != null) 'displayLabel': displayLabel,
    };
  }

  static ChallengeGoal fromMap(Map<String, dynamic> map) {
    return ChallengeGoal(
      kind: GoalKind.fromFirestore(map['kind'] as String? ?? 'distance'),
      value: (map['value'] as num).toDouble(),
      displayLabel: map['displayLabel'] as String?,
    );
  }

  ChallengeGoal copyWith({
    GoalKind? kind,
    double? value,
    String? displayLabel,
  }) {
    return ChallengeGoal(
      kind: kind ?? this.kind,
      value: value ?? this.value,
      displayLabel: displayLabel ?? this.displayLabel,
    );
  }
}
