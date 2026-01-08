import 'enums.dart';

/// Medallero agregado del usuario en el grupo
class GroupMedals {
  final String uid;
  final int gold;
  final int silver;
  final int bronze;
  final DateTime? lastMedalAt;
  
  // UI fields (enriched at runtime)
  final String? displayName;
  final String? photoUrl;
  final String? profilePicType;
  final Map<String, dynamic>? avatarConfig;

  const GroupMedals({
    required this.uid,
    this.gold = 0,
    this.silver = 0,
    this.bronze = 0,
    this.lastMedalAt,
    this.displayName,
    this.photoUrl,
    this.profilePicType,
    this.avatarConfig,
  });

  int get total => gold + silver + bronze;

  Map<String, dynamic> toMap() {
    return {
      'gold': gold,
      'silver': silver,
      'bronze': bronze,
      if (lastMedalAt != null) 'lastMedalAt': lastMedalAt!.toIso8601String(),
    };
  }

  static GroupMedals fromMap(Map<String, dynamic> map, {required String uid}) {
    return GroupMedals(
      uid: uid,
      gold: map['gold'] as int? ?? 0,
      silver: map['silver'] as int? ?? 0,
      bronze: map['bronze'] as int? ?? 0,
      lastMedalAt: map['lastMedalAt'] != null 
          ? _parseDateTime(map['lastMedalAt']) 
          : null,
    );
  }

  GroupMedals copyWith({
    String? uid,
    int? gold,
    int? silver,
    int? bronze,
    DateTime? lastMedalAt,
    String? displayName,
    String? photoUrl,
    String? profilePicType,
    Map<String, dynamic>? avatarConfig,
  }) {
    return GroupMedals(
      uid: uid ?? this.uid,
      gold: gold ?? this.gold,
      silver: silver ?? this.silver,
      bronze: bronze ?? this.bronze,
      lastMedalAt: lastMedalAt ?? this.lastMedalAt,
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

/// Entrada del historial de medallas
class MedalHistoryEntry {
  final String id;
  final String uid;
  final String challengeId;
  final String challengeTitle;
  final String periodKey;
  final String origin;  // ChallengeOrigin en string
  final MedalType medal;
  final int rank;
  final double score;
  final DateTime awardedAt;

  const MedalHistoryEntry({
    required this.id,
    required this.uid,
    required this.challengeId,
    required this.challengeTitle,
    required this.periodKey,
    required this.origin,
    required this.medal,
    required this.rank,
    required this.score,
    required this.awardedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'challengeId': challengeId,
      'challengeTitle': challengeTitle,
      'periodKey': periodKey,
      'origin': origin,
      'medal': medal.toFirestore(),
      'rank': rank,
      'score': score,
      'awardedAt': awardedAt.toIso8601String(),
    };
  }

  static MedalHistoryEntry fromMap(Map<String, dynamic> map, {required String id}) {
    return MedalHistoryEntry(
      id: id,
      uid: map['uid'] as String,
      challengeId: map['challengeId'] as String,
      challengeTitle: map['challengeTitle'] as String,
      periodKey: map['periodKey'] as String,
      origin: map['origin'] as String,
      medal: MedalType.fromFirestore(map['medal'] as String? ?? 'bronze'),
      rank: map['rank'] as int,
      score: (map['score'] as num).toDouble(),
      awardedAt: _parseDateTime(map['awardedAt']),
    );
  }

  MedalHistoryEntry copyWith({
    String? id,
    String? uid,
    String? challengeId,
    String? challengeTitle,
    String? periodKey,
    String? origin,
    MedalType? medal,
    int? rank,
    double? score,
    DateTime? awardedAt,
  }) {
    return MedalHistoryEntry(
      id: id ?? this.id,
      uid: uid ?? this.uid,
      challengeId: challengeId ?? this.challengeId,
      challengeTitle: challengeTitle ?? this.challengeTitle,
      periodKey: periodKey ?? this.periodKey,
      origin: origin ?? this.origin,
      medal: medal ?? this.medal,
      rank: rank ?? this.rank,
      score: score ?? this.score,
      awardedAt: awardedAt ?? this.awardedAt,
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

/// Badges agregados del usuario en el grupo
class GroupBadges {
  final String uid;
  final int completedCount;
  final int weeklyCompleted;
  final int monthlyCompleted;
  final DateTime? lastCompletedAt;

  // UI fields (enriched at runtime)
  final String? displayName;
  final String? photoUrl;
  final String? profilePicType;
  final Map<String, dynamic>? avatarConfig;

  const GroupBadges({
    required this.uid,
    this.completedCount = 0,
    this.weeklyCompleted = 0,
    this.monthlyCompleted = 0,
    this.lastCompletedAt,
    this.displayName,
    this.photoUrl,
    this.profilePicType,
    this.avatarConfig,
  });

  Map<String, dynamic> toMap() {
    return {
      'completedCount': completedCount,
      'weeklyCompleted': weeklyCompleted,
      'monthlyCompleted': monthlyCompleted,
      if (lastCompletedAt != null) 'lastCompletedAt': lastCompletedAt!.toIso8601String(),
    };
  }

  static GroupBadges fromMap(Map<String, dynamic> map, {required String uid}) {
    return GroupBadges(
      uid: uid,
      completedCount: map['completedCount'] as int? ?? 0,
      weeklyCompleted: map['weeklyCompleted'] as int? ?? 0,
      monthlyCompleted: map['monthlyCompleted'] as int? ?? 0,
      lastCompletedAt: map['lastCompletedAt'] != null 
          ? _parseDateTime(map['lastCompletedAt']) 
          : null,
    );
  }

  GroupBadges copyWith({
    String? uid,
    int? completedCount,
    int? weeklyCompleted,
    int? monthlyCompleted,
    DateTime? lastCompletedAt,
    String? displayName,
    String? photoUrl,
    String? profilePicType,
    Map<String, dynamic>? avatarConfig,
  }) {
    return GroupBadges(
      uid: uid ?? this.uid,
      completedCount: completedCount ?? this.completedCount,
      weeklyCompleted: weeklyCompleted ?? this.weeklyCompleted,
      monthlyCompleted: monthlyCompleted ?? this.monthlyCompleted,
      lastCompletedAt: lastCompletedAt ?? this.lastCompletedAt,
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

/// Entrada del historial de badges
class BadgeHistoryEntry {
  final String id;
  final String uid;
  final String challengeId;
  final String challengeTitle;
  final String periodKey;
  final String origin;  // ChallengeOrigin en string
  final BadgeType badge;
  final double scoreAtEnd;
  final double goalValue;
  final DateTime awardedAt;

  const BadgeHistoryEntry({
    required this.id,
    required this.uid,
    required this.challengeId,
    required this.challengeTitle,
    required this.periodKey,
    required this.origin,
    required this.badge,
    required this.scoreAtEnd,
    required this.goalValue,
    required this.awardedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'challengeId': challengeId,
      'challengeTitle': challengeTitle,
      'periodKey': periodKey,
      'origin': origin,
      'badge': badge.toFirestore(),
      'scoreAtEnd': scoreAtEnd,
      'goalValue': goalValue,
      'awardedAt': awardedAt.toIso8601String(),
    };
  }

  static BadgeHistoryEntry fromMap(Map<String, dynamic> map, {required String id}) {
    return BadgeHistoryEntry(
      id: id,
      uid: map['uid'] as String,
      challengeId: map['challengeId'] as String,
      challengeTitle: map['challengeTitle'] as String,
      periodKey: map['periodKey'] as String,
      origin: map['origin'] as String,
      badge: BadgeType.fromFirestore(map['badge'] as String? ?? 'goalCompleted'),
      scoreAtEnd: (map['scoreAtEnd'] as num).toDouble(),
      goalValue: (map['goalValue'] as num).toDouble(),
      awardedAt: _parseDateTime(map['awardedAt']),
    );
  }

  BadgeHistoryEntry copyWith({
    String? id,
    String? uid,
    String? challengeId,
    String? challengeTitle,
    String? periodKey,
    String? origin,
    BadgeType? badge,
    double? scoreAtEnd,
    double? goalValue,
    DateTime? awardedAt,
  }) {
    return BadgeHistoryEntry(
      id: id ?? this.id,
      uid: uid ?? this.uid,
      challengeId: challengeId ?? this.challengeId,
      challengeTitle: challengeTitle ?? this.challengeTitle,
      periodKey: periodKey ?? this.periodKey,
      origin: origin ?? this.origin,
      badge: badge ?? this.badge,
      scoreAtEnd: scoreAtEnd ?? this.scoreAtEnd,
      goalValue: goalValue ?? this.goalValue,
      awardedAt: awardedAt ?? this.awardedAt,
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
