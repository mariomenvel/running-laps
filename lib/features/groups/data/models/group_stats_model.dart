import '../models/enums.dart';

class GroupModel {
  final String id;
  final String name;
  final List<String> memberIds;
  final List<GroupMemberStats>? topRunners;

  GroupModel({
    required this.id,
    required this.name,
    required this.memberIds,
    this.topRunners,
  });

  factory GroupModel.fromFirestore(Map<String, dynamic> data, String id) {
    return GroupModel(
      id: id,
      name: data['name'] ?? 'Grupo sin nombre',
      memberIds: List<String>.from(data['members'] ?? []),
    );
  }
}

class GroupMemberStats {
  final String uid;
  final String name;
  final double totalKm;
  final String? photoUrl;
  final String? profilePicType;
  final Map<String, dynamic>? avatarConfig;
  final MemberStatus status;

  GroupMemberStats({
    required this.uid,
    required this.name,
    required this.totalKm,
    this.photoUrl,
    this.profilePicType,
    this.avatarConfig,
    this.status = MemberStatus.active,
  });
}


