class InvitationModel {
  final String id;
  final String groupId;
  final String groupName;
  final String invitedBy; // Nombre de quien te invitó

  InvitationModel({
    required this.id,
    required this.groupId,
    required this.groupName,
    required this.invitedBy,
  });

  factory InvitationModel.fromFirestore(Map<String, dynamic> data, String id) {
    return InvitationModel(
      id: id,
      groupId: data['groupId'] ?? '',
      groupName: data['groupName'] ?? 'Grupo',
      invitedBy: data['invitedBy'] ?? 'Alguien',
    );
  }
}