import '../models/enums.dart';
import '../helpers/challenge_helpers.dart';

/// Template global para retos automáticos
class ChallengeTemplate {
  final String templateId;
  final String title;
  final ChallengePeriodicity periodicity;
  final ChallengeMetric metric;
  final ChallengeAggregation aggregation;
  final ChallengeFilters filters;
  final ChallengeGoal goal;
  final List<TieBreakerType> tieBreakers;
  final bool enabled;

  const ChallengeTemplate({
    required this.templateId,
    required this.title,
    required this.periodicity,
    required this.metric,
    required this.aggregation,
    required this.filters,
    required this.goal,
    required this.tieBreakers,
    this.enabled = true,
  });

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'periodicity': periodicity.toFirestore(),
      'metric': metric.toFirestore(),
      'aggregation': aggregation.toFirestore(),
      'filters': filters.toMap(),
      'goal': goal.toMap(),
      'tieBreakers': tieBreakers.map((e) => e.toFirestore()).toList(),
      'enabled': enabled,
    };
  }

  static ChallengeTemplate fromMap(Map<String, dynamic> map, {required String templateId}) {
    return ChallengeTemplate(
      templateId: templateId,
      title: map['title'] as String,
      periodicity: ChallengePeriodicity.fromFirestore(map['periodicity'] as String? ?? 'weekly'),
      metric: ChallengeMetric.fromFirestore(map['metric'] as String? ?? 'distance'),
      aggregation: ChallengeAggregation.fromFirestore(map['aggregation'] as String? ?? 'sum'),
      filters: ChallengeFilters.fromMap(map['filters'] as Map<String, dynamic>? ?? {}),
      goal: ChallengeGoal.fromMap(map['goal'] as Map<String, dynamic>),
      tieBreakers: (map['tieBreakers'] as List? ?? [])
          .map((e) => TieBreakerType.fromFirestore(e as String))
          .toList(),
      enabled: map['enabled'] as bool? ?? true,
    );
  }

  ChallengeTemplate copyWith({
    String? templateId,
    String? title,
    ChallengePeriodicity? periodicity,
    ChallengeMetric? metric,
    ChallengeAggregation? aggregation,
    ChallengeFilters? filters,
    ChallengeGoal? goal,
    List<TieBreakerType>? tieBreakers,
    bool? enabled,
  }) {
    return ChallengeTemplate(
      templateId: templateId ?? this.templateId,
      title: title ?? this.title,
      periodicity: periodicity ?? this.periodicity,
      metric: metric ?? this.metric,
      aggregation: aggregation ?? this.aggregation,
      filters: filters ?? this.filters,
      goal: goal ?? this.goal,
      tieBreakers: tieBreakers ?? this.tieBreakers,
      enabled: enabled ?? this.enabled,
    );
  }
}

/// Reto del grupo
class Challenge {
  final String id;
  final String title;
  final ChallengeOrigin origin;
  final String? templateId;
  final String periodKey;  // Ej: "2026-W01" o "2026-01"
  final DateTime startAt;
  final DateTime endAt;
  final ChallengeStatus status;
  final ChallengeMetric metric;
  final ChallengeAggregation aggregation;
  final ChallengeFilters filters;
  final ChallengeGoal goal;
  final List<TieBreakerType> tieBreakers;
  final bool awardsMedals;
  final bool awardsBadges;
  final bool medalsAwarded;
  final bool badgesAwarded;
  final DateTime createdAt;
  final String createdBy;

  const Challenge({
    required this.id,
    required this.title,
    required this.origin,
    this.templateId,
    required this.periodKey,
    required this.startAt,
    required this.endAt,
    required this.status,
    required this.metric,
    required this.aggregation,
    required this.filters,
    required this.goal,
    required this.tieBreakers,
    required this.awardsMedals,
    required this.awardsBadges,
    this.medalsAwarded = false,
    this.badgesAwarded = false,
    required this.createdAt,
    required this.createdBy,
  });

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'origin': origin.toFirestore(),
      if (templateId != null) 'templateId': templateId,
      'periodKey': periodKey,
      'startAt': startAt.toIso8601String(),
      'endAt': endAt.toIso8601String(),
      'status': status.toFirestore(),
      'metric': metric.toFirestore(),
      'aggregation': aggregation.toFirestore(),
      'filters': filters.toMap(),
      'goal': goal.toMap(),
      'tieBreakers': tieBreakers.map((e) => e.toFirestore()).toList(),
      'awardsMedals': awardsMedals,
      'awardsBadges': awardsBadges,
      'medalsAwarded': medalsAwarded,
      'badgesAwarded': badgesAwarded,
      'createdAt': createdAt.toIso8601String(),
      'createdBy': createdBy,
    };
  }

  static Challenge fromMap(Map<String, dynamic> map, {required String id}) {
    return Challenge(
      id: id,
      title: map['title'] as String,
      origin: ChallengeOrigin.fromFirestore(map['origin'] as String? ?? 'owner'),
      templateId: map['templateId'] as String?,
      periodKey: map['periodKey'] as String,
      startAt: _parseDateTime(map['startAt']),
      endAt: _parseDateTime(map['endAt']),
      status: ChallengeStatus.fromFirestore(map['status'] as String? ?? 'draft'),
      metric: ChallengeMetric.fromFirestore(map['metric'] as String? ?? 'distance'),
      aggregation: ChallengeAggregation.fromFirestore(map['aggregation'] as String? ?? 'sum'),
      filters: ChallengeFilters.fromMap(map['filters'] as Map<String, dynamic>? ?? {}),
      goal: ChallengeGoal.fromMap(map['goal'] as Map<String, dynamic>),
      tieBreakers: (map['tieBreakers'] as List? ?? [])
          .map((e) => TieBreakerType.fromFirestore(e as String))
          .toList(),
      awardsMedals: map['awardsMedals'] as bool? ?? true,
      awardsBadges: map['awardsBadges'] as bool? ?? true,
      medalsAwarded: map['medalsAwarded'] as bool? ?? false,
      badgesAwarded: map['badgesAwarded'] as bool? ?? false,
      createdAt: _parseDateTime(map['createdAt']),
      createdBy: map['createdBy'] as String,
    );
  }

  Challenge copyWith({
    String? id,
    String? title,
    ChallengeOrigin? origin,
    String? templateId,
    String? periodKey,
    DateTime? startAt,
    DateTime? endAt,
    ChallengeStatus? status,
    ChallengeMetric? metric,
    ChallengeAggregation? aggregation,
    ChallengeFilters? filters,
    ChallengeGoal? goal,
    List<TieBreakerType>? tieBreakers,
    bool? awardsMedals,
    bool? awardsBadges,
    bool? medalsAwarded,
    bool? badgesAwarded,
    DateTime? createdAt,
    String? createdBy,
  }) {
    return Challenge(
      id: id ?? this.id,
      title: title ?? this.title,
      origin: origin ?? this.origin,
      templateId: templateId ?? this.templateId,
      periodKey: periodKey ?? this.periodKey,
      startAt: startAt ?? this.startAt,
      endAt: endAt ?? this.endAt,
      status: status ?? this.status,
      metric: metric ?? this.metric,
      aggregation: aggregation ?? this.aggregation,
      filters: filters ?? this.filters,
      goal: goal ?? this.goal,
      tieBreakers: tieBreakers ?? this.tieBreakers,
      awardsMedals: awardsMedals ?? this.awardsMedals,
      awardsBadges: awardsBadges ?? this.awardsBadges,
      medalsAwarded: medalsAwarded ?? this.medalsAwarded,
      badgesAwarded: badgesAwarded ?? this.badgesAwarded,
      createdAt: createdAt ?? this.createdAt,
      createdBy: createdBy ?? this.createdBy,
    );
  }

  static DateTime _parseDateTime(dynamic value) {
    if (value is String) {
      return DateTime.parse(value);
    }
    if (value is int) {
      return DateTime.fromMillisecondsSinceEpoch(value);
    }
    return DateTime.now();
  }
}

/// Participante en un reto
class ChallengeParticipant {
  final String uid;
  final DateTime joinedAt;
  final DateTime lastUpdatedAt;
  final DateTime? reachedGoalAt; // Fecha en que se alcanzó el objetivo (para desempate)
  final double score;
  
  // Breakdown fields (métricas detalladas)
  final int distanceM;
  final double timeSec;
  final int sessions;
  final double? bestPaceSecPerKm;
  final DateTime? lastTrainingAt;

  // UI fields (not stored in participants subcollection, enriched at runtime)
  final String? displayName;
  final String? photoUrl;
  final String? profilePicType;
  final Map<String, dynamic>? avatarConfig;

  const ChallengeParticipant({
    required this.uid,
    required this.joinedAt,
    required this.lastUpdatedAt,
    this.reachedGoalAt,
    required this.score,
    this.distanceM = 0,
    this.timeSec = 0.0,
    this.sessions = 0,
    this.bestPaceSecPerKm,
    this.lastTrainingAt,
    this.displayName,
    this.photoUrl,
    this.profilePicType,
    this.avatarConfig,
  });

  Map<String, dynamic> toMap() {
    return {
      'joinedAt': joinedAt.toIso8601String(),
      'lastUpdatedAt': lastUpdatedAt.toIso8601String(),
      if (reachedGoalAt != null) 'reachedGoalAt': reachedGoalAt!.toIso8601String(),
      'score': score,
      'distanceM': distanceM,
      'timeSec': timeSec,
      'sessions': sessions,
      if (bestPaceSecPerKm != null) 'bestPaceSecPerKm': bestPaceSecPerKm,
      if (lastTrainingAt != null) 'lastTrainingAt': lastTrainingAt!.toIso8601String(),
    };
  }

  static ChallengeParticipant fromMap(Map<String, dynamic> map, {required String uid}) {
    return ChallengeParticipant(
      uid: uid,
      joinedAt: _parseDateTime(map['joinedAt']),
      lastUpdatedAt: _parseDateTime(map['lastUpdatedAt'] ?? DateTime.now().toIso8601String()),
      reachedGoalAt: map['reachedGoalAt'] != null 
          ? _parseDateTime(map['reachedGoalAt']) 
          : null,
      score: (map['score'] as num?)?.toDouble() ?? 0.0,
      distanceM: map['distanceM'] as int? ?? 0,
      timeSec: (map['timeSec'] as num?)?.toDouble() ?? 0.0,
      sessions: map['sessions'] as int? ?? 0,
      bestPaceSecPerKm: (map['bestPaceSecPerKm'] as num?)?.toDouble(),
      lastTrainingAt: map['lastTrainingAt'] != null 
          ? _parseDateTime(map['lastTrainingAt']) 
          : null,
    );
  }

  ChallengeParticipant copyWith({
    String? uid,
    DateTime? joinedAt,
    DateTime? lastUpdatedAt,
    DateTime? reachedGoalAt,
    double? score,
    int? distanceM,
    double? timeSec,
    int? sessions,
    double? bestPaceSecPerKm,
    DateTime? lastTrainingAt,
    String? displayName,
    String? photoUrl,
    String? profilePicType,
    Map<String, dynamic>? avatarConfig,
  }) {
    return ChallengeParticipant(
      uid: uid ?? this.uid,
      joinedAt: joinedAt ?? this.joinedAt,
      lastUpdatedAt: lastUpdatedAt ?? this.lastUpdatedAt,
      reachedGoalAt: reachedGoalAt ?? this.reachedGoalAt,
      score: score ?? this.score,
      distanceM: distanceM ?? this.distanceM,
      timeSec: timeSec ?? this.timeSec,
      sessions: sessions ?? this.sessions,
      bestPaceSecPerKm: bestPaceSecPerKm ?? this.bestPaceSecPerKm,
      lastTrainingAt: lastTrainingAt ?? this.lastTrainingAt,
      displayName: displayName ?? this.displayName,
      photoUrl: photoUrl ?? this.photoUrl,
      profilePicType: profilePicType ?? this.profilePicType,
      avatarConfig: avatarConfig ?? this.avatarConfig,
    );
  }

  static DateTime _parseDateTime(dynamic value) {
    if (value is String) {
      return DateTime.parse(value);
    }
    if (value is int) {
      return DateTime.fromMillisecondsSinceEpoch(value);
    }
    return DateTime.now();
  }
}

/// Preferencias del usuario en el grupo
class GroupPrefs {
  final String uid;
  final bool askedAutoJoin;
  final bool autoJoinTemplates;

  const GroupPrefs({
    required this.uid,
    this.askedAutoJoin = false,
    this.autoJoinTemplates = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'askedAutoJoin': askedAutoJoin,
      'autoJoinTemplates': autoJoinTemplates,
    };
  }

  static GroupPrefs fromMap(Map<String, dynamic> map, {required String uid}) {
    return GroupPrefs(
      uid: uid,
      askedAutoJoin: map['askedAutoJoin'] as bool? ?? false,
      autoJoinTemplates: map['autoJoinTemplates'] as bool? ?? false,
    );
  }

  GroupPrefs copyWith({
    String? uid,
    bool? askedAutoJoin,
    bool? autoJoinTemplates,
  }) {
    return GroupPrefs(
      uid: uid ?? this.uid,
      askedAutoJoin: askedAutoJoin ?? this.askedAutoJoin,
      autoJoinTemplates: autoJoinTemplates ?? this.autoJoinTemplates,
    );
  }
}


