import 'package:cloud_firestore/cloud_firestore.dart';

class ChallengeModel {
  final String id;
  final String title;
  final String description;
  final double targetKm;
  final DateTime endDate;
  final int participantsCount;

  ChallengeModel({
    required this.id,
    required this.title,
    required this.description,
    required this.targetKm,
    required this.endDate,
    required this.participantsCount,
  });

  factory ChallengeModel.fromFirestore(Map<String, dynamic> data, String id) {
    return ChallengeModel(
      id: id,
      title: data['title'] ?? 'Reto sin nombre',
      description: data['description'] ?? '',
      targetKm: (data['targetKm'] ?? 0).toDouble(),
      endDate: (data['endDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      participantsCount: data['participantsCount'] ?? 0,
    );
  }
}