// Enumeraciones y constantes para el sistema de Grupos, Retos y Recompensas

// ============================================
// GRUPO
// ============================================

/// Tipo de grupo
enum GroupType {
  private,
  support,
  opositores;

  String toFirestore() {
    return name;
  }

  static GroupType fromFirestore(String value) {
    return GroupType.values.firstWhere(
      (e) => e.name == value,
      orElse: () => GroupType.private,
    );
  }
}

/// Estado del miembro en el grupo
enum MemberStatus {
  active,
  pending,
  kicked;

  String toFirestore() {
    return name;
  }

  static MemberStatus fromFirestore(String value) {
    return MemberStatus.values.firstWhere(
      (e) => e.name == value,
      orElse: () => MemberStatus.active,
    );
  }
}

// ============================================
// RETOS
// ============================================

/// Periodicidad del reto
enum ChallengePeriodicity {
  weekly,
  monthly;

  String toFirestore() {
    return name;
  }

  static ChallengePeriodicity fromFirestore(String value) {
    return ChallengePeriodicity.values.firstWhere(
      (e) => e.name == value,
      orElse: () => ChallengePeriodicity.weekly,
    );
  }
}

/// Métrica del reto (qué se mide)
enum ChallengeMetric {
  distance,      // Distancia total
  time,          // Tiempo total
  sessions,      // Número de sesiones
  avgPace,       // Ritmo medio
  bestPace;      // Mejor ritmo

  String toFirestore() {
    return name;
  }

  static ChallengeMetric fromFirestore(String value) {
    return ChallengeMetric.values.firstWhere(
      (e) => e.name == value,
      orElse: () => ChallengeMetric.distance,
    );
  }
}

/// Agregación de la métrica (cómo se calcula el score)
enum ChallengeAggregation {
  sum,      // Suma (para distancia, tiempo, sesiones)
  avg,      // Promedio (para ritmos)
  best,     // Mejor valor (para ritmos)
  count;    // Conteo (para sesiones)

  String toFirestore() {
    return name;
  }

  static ChallengeAggregation fromFirestore(String value) {
    return ChallengeAggregation.values.firstWhere(
      (e) => e.name == value,
      orElse: () => ChallengeAggregation.sum,
    );
  }
}

/// Origen del reto
enum ChallengeOrigin {
  template,  // Creado automáticamente desde template
  owner,     // Creado manualmente por el dueño
  global;    // Creado por un administrador para todos

  String toFirestore() {
    return name;
  }

  static ChallengeOrigin fromFirestore(String value) {
    return ChallengeOrigin.values.firstWhere(
      (e) => e.name == value,
      orElse: () => ChallengeOrigin.owner,
    );
  }
}

/// Estado del reto
enum ChallengeStatus {
  draft,     // Borrador (aún no inicia)
  active,    // Activo (en progreso)
  finished;  // Finalizado

  String toFirestore() {
    return name;
  }

  static ChallengeStatus fromFirestore(String value) {
    return ChallengeStatus.values.firstWhere(
      (e) => e.name == value,
      orElse: () => ChallengeStatus.draft,
    );
  }
}

/// Tipo de criterio de desempate
enum TieBreakerType {
  sessions,    // Número de sesiones
  distance,
  time,
  consistency, // Consistencia (días con entrenamiento)
  earliestJoin, // Quien se unió primero
  earliestCompletion; // Quien terminó primero

  String toFirestore() {
    return name;
  }

  static TieBreakerType fromFirestore(String value) {
    return TieBreakerType.values.firstWhere(
      (e) => e.name == value,
      orElse: () => TieBreakerType.sessions,
    );
  }
}

// ============================================
// RECOMPENSAS
// ============================================

/// Tipo de medalla
enum MedalType {
  gold,
  silver,
  bronze;

  String toFirestore() {
    return name;
  }

  static MedalType fromFirestore(String value) {
    return MedalType.values.firstWhere(
      (e) => e.name == value,
      orElse: () => MedalType.bronze,
    );
  }
}

/// Tipo de badge
enum BadgeType {
  goalCompleted; // Objetivo completado

  String toFirestore() {
    return name;
  }

  static BadgeType fromFirestore(String value) {
    return BadgeType.values.firstWhere(
      (e) => e.name == value,
      orElse: () => BadgeType.goalCompleted,
    );
  }
}

/// Tipo de objetivo (para Goal)
enum GoalKind {
  distance,
  time,
  sessions,
  avgPace,
  bestPace;

  String toFirestore() {
    return name;
  }

  static GoalKind fromFirestore(String value) {
    return GoalKind.values.firstWhere(
      (e) => e.name == value,
      orElse: () => GoalKind.distance,
    );
  }
}

