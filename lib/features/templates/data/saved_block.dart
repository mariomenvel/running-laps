import 'package:cloud_firestore/cloud_firestore.dart';

import 'workout_block.dart';

class SavedBlock {
  final String id;
  final String name;
  final BlockRole role;
  final WorkoutBlock block;
  final DateTime createdAt;
  final int usageCount;

  const SavedBlock({
    required this.id,
    required this.name,
    required this.role,
    required this.block,
    required this.createdAt,
    this.usageCount = 0,
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'role': role.name,
      'block': block.toMap(),
      'createdAt': Timestamp.fromDate(createdAt),
      'usageCount': usageCount,
    };
  }

  factory SavedBlock.fromMap(String docId, Map<String, dynamic> map) {
    return SavedBlock(
      id: docId,
      name: map['name'] as String,
      role: BlockRole.values.byName(map['role'] as String),
      block: WorkoutBlock.fromMap(Map<String, dynamic>.from(map['block'] as Map)),
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      usageCount: (map['usageCount'] as int?) ?? 0,
    );
  }

  SavedBlock copyWith({
    String? id,
    String? name,
    BlockRole? role,
    WorkoutBlock? block,
    DateTime? createdAt,
    int? usageCount,
  }) {
    return SavedBlock(
      id: id ?? this.id,
      name: name ?? this.name,
      role: role ?? this.role,
      block: block ?? this.block,
      createdAt: createdAt ?? this.createdAt,
      usageCount: usageCount ?? this.usageCount,
    );
  }
}
