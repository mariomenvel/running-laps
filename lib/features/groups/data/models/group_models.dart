import '../models/enums.dart';

/// Modelo para el grupo
class Group {
  final String id;
  final String name;
  final String ownerId;
  final DateTime createdAt;
  final GroupType type;
  final int memberCount;
  final String? activeChallengeId;

  const Group({
    required this.id,
    required this.name,
    required this.ownerId,
    required this.createdAt,
    required this.type,
    required this.memberCount,
    this.activeChallengeId,
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'ownerId': ownerId,
      'createdAt': createdAt.toIso8601String(),
      'type': type.toFirestore(),
      'memberCount': memberCount,
      if (activeChallengeId != null) 'activeChallengeId': activeChallengeId,
    };
  }

  static Group fromMap(Map<String, dynamic> map, {required String id}) {
    return Group(
      id: id,
      name: map['name'] as String,
      ownerId: map['ownerId'] as String,
      createdAt: _parseDateTime(map['createdAt']),
      type: GroupType.fromFirestore(map['type'] as String? ?? 'private'),
      memberCount: map['memberCount'] as int? ?? 0,
      activeChallengeId: map['activeChallengeId'] as String?,
    );
  }

  Group copyWith({
    String? id,
    String? name,
    String? ownerId,
    DateTime? createdAt,
    GroupType? type,
    int? memberCount,
    String? activeChallengeId,
  }) {
    return Group(
      id: id ?? this.id,
      name: name ?? this.name,
      ownerId: ownerId ?? this.ownerId,
      createdAt: createdAt ?? this.createdAt,
      type: type ?? this.type,
      memberCount: memberCount ?? this.memberCount,
      activeChallengeId: activeChallengeId ?? this.activeChallengeId,
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

/// Modelo para miembro del grupo
class GroupMember {
  final String uid;
  final MemberStatus status;
  final DateTime joinedAt;
  final DateTime? kickedAt;

  const GroupMember({
    required this.uid,
    required this.status,
    required this.joinedAt,
    this.kickedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'status': status.toFirestore(),
      'joinedAt': joinedAt.toIso8601String(),
      if (kickedAt != null) 'kickedAt': kickedAt!.toIso8601String(),
    };
  }

  static GroupMember fromMap(Map<String, dynamic> map, {required String uid}) {
    return GroupMember(
      uid: uid,
      status: MemberStatus.fromFirestore(map['status'] as String? ?? 'active'),
      joinedAt: _parseDateTime(map['joinedAt']),
      kickedAt: map['kickedAt'] != null ? _parseDateTime(map['kickedAt']) : null,
    );
  }

  GroupMember copyWith({
    String? uid,
    MemberStatus? status,
    DateTime? joinedAt,
    DateTime? kickedAt,
  }) {
    return GroupMember(
      uid: uid ?? this.uid,
      status: status ?? this.status,
      joinedAt: joinedAt ?? this.joinedAt,
      kickedAt: kickedAt ?? this.kickedAt,
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

/// Modelo para invitación a grupo
class Invite {
  final String inviteId;
  final DateTime createdAt;
  final String createdBy;
  final DateTime expiresAt;
  final int maxUses;
  final int uses;
  final bool revoked;
  final String tokenHash;
  final String? targetEmail;

  const Invite({
    required this.inviteId,
    required this.createdAt,
    required this.createdBy,
    required this.expiresAt,
    required this.maxUses,
    required this.uses,
    required this.revoked,
    required this.tokenHash,
    this.targetEmail,
  });

  Map<String, dynamic> toMap() {
    return {
      'createdAt': createdAt.toIso8601String(),
      'createdBy': createdBy,
      'expiresAt': expiresAt.toIso8601String(),
      'maxUses': maxUses,
      'uses': uses,
      'revoked': revoked,
      'tokenHash': tokenHash,
      if (targetEmail != null) 'targetEmail': targetEmail,
    };
  }

  static Invite fromMap(Map<String, dynamic> map, {required String inviteId}) {
    return Invite(
      inviteId: inviteId,
      createdAt: _parseDateTime(map['createdAt']),
      createdBy: map['createdBy'] as String,
      expiresAt: _parseDateTime(map['expiresAt']),
      maxUses: map['maxUses'] as int,
      uses: map['uses'] as int? ?? 0,
      revoked: map['revoked'] as bool? ?? false,
      tokenHash: map['tokenHash'] as String,
      targetEmail: map['targetEmail'] as String?,
    );
  }

  Invite copyWith({
    String? inviteId,
    DateTime? createdAt,
    String? createdBy,
    DateTime? expiresAt,
    int? maxUses,
    int? uses,
    bool? revoked,
    String? tokenHash,
    String? targetEmail,
  }) {
    return Invite(
      inviteId: inviteId ?? this.inviteId,
      createdAt: createdAt ?? this.createdAt,
      createdBy: createdBy ?? this.createdBy,
      expiresAt: expiresAt ?? this.expiresAt,
      maxUses: maxUses ?? this.maxUses,
      uses: uses ?? this.uses,
      revoked: revoked ?? this.revoked,
      tokenHash: tokenHash ?? this.tokenHash,
      targetEmail: targetEmail ?? this.targetEmail,
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


