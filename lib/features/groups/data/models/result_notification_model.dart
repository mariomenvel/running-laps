import '../models/enums.dart';

/// Notificación interna para informar al usuario de que un reto ha terminado y ha ganado algo.
/// Se almacena en users/{uid}/result_notifications/{id}
class GroupResultNotification {
  final String id;
  final String groupId;
  final String groupName;
  final String challengeId;
  final String challengeTitle;
  final MedalType? medal; // null si no ganó medalla
  final int? rank;        // null si no hay ranking (solo badge)
  final bool hasBadge;
  final GroupNotificationType type;
  final DateTime createdAt;

  const GroupResultNotification({
    required this.id,
    required this.groupId,
    required this.groupName,
    required this.challengeId,
    required this.challengeTitle,
    this.medal,
    this.rank,
    this.hasBadge = false,
    this.type = GroupNotificationType.challengeFinished,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'groupId': groupId,
      'groupName': groupName,
      'challengeId': challengeId,
      'challengeTitle': challengeTitle,
      'medal': medal?.toFirestore(),
      'rank': rank,
      'hasBadge': hasBadge,
      'type': type.toFirestore(),
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory GroupResultNotification.fromMap(Map<String, dynamic> map, String id) {
    return GroupResultNotification(
      id: id,
      groupId: map['groupId'] as String? ?? '',
      groupName: map['groupName'] as String? ?? '',
      challengeId: map['challengeId'] as String? ?? '',
      challengeTitle: map['challengeTitle'] as String? ?? '',
      medal: map['medal'] != null ? MedalType.fromFirestore(map['medal'] as String) : null,
      rank: map['rank'] as int?,
      hasBadge: map['hasBadge'] as bool? ?? false,
      type: map['type'] != null 
          ? GroupNotificationType.fromFirestore(map['type'] as String)
          : GroupNotificationType.challengeFinished,
      createdAt: map['createdAt'] != null 
          ? DateTime.parse(map['createdAt'] as String) 
          : DateTime.now(),
    );
  }
}


