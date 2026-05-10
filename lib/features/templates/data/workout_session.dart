import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';

import 'workout_block.dart';

enum WorkoutType { continuous, intervals, fartlek, hills, competition, free }

class WorkoutSession {
  final String id;
  final String title;
  final String? description;
  final WorkoutType type;
  final List<WorkoutBlock> blocks;
  final DateTime? scheduledDate;
  final bool isTemplate;
  final String? templateId;

  WorkoutSession({
    String? id,
    required this.title,
    this.description,
    required this.type,
    required this.blocks,
    this.scheduledDate,
    this.isTemplate = false,
    this.templateId,
  }) : id = id ?? const Uuid().v4(),
       assert(blocks.isNotEmpty, 'blocks must not be empty'),
       assert(
         blocks.any((b) => b.role == BlockRole.main),
         'at least one block with role == main is required',
       ),
       assert(
         blocks
             .where(
               (b) => b.role == BlockRole.warmup || b.role == BlockRole.cooldown,
             )
             .every((b) => b.repetitions == 1),
         'warmup and cooldown blocks must have repetitions == 1',
       );

  WorkoutBlock? get warmupBlock =>
      blocks.where((b) => b.role == BlockRole.warmup).firstOrNull;

  List<WorkoutBlock> get mainBlocks =>
      blocks.where((b) => b.role == BlockRole.main).toList();

  WorkoutBlock? get cooldownBlock =>
      blocks.where((b) => b.role == BlockRole.cooldown).firstOrNull;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      if (description != null) 'description': description,
      'type': type.name,
      'blocks': blocks.map((b) => b.toMap()).toList(),
      if (scheduledDate != null)
        'scheduledDate': Timestamp.fromDate(scheduledDate!),
      'isTemplate': isTemplate,
      if (templateId != null) 'templateId': templateId,
    };
  }

  factory WorkoutSession.fromMap(Map<String, dynamic> map) {
    return WorkoutSession(
      id: map['id'] as String,
      title: map['title'] as String,
      description: map['description'] as String?,
      type: WorkoutType.values.byName(map['type'] as String),
      blocks: (map['blocks'] as List)
          .map((e) => WorkoutBlock.fromMap(Map<String, dynamic>.from(e as Map)))
          .toList(),
      scheduledDate: map['scheduledDate'] != null
          ? (map['scheduledDate'] as Timestamp).toDate()
          : null,
      isTemplate: map['isTemplate'] as bool? ?? false,
      templateId: map['templateId'] as String?,
    );
  }

  WorkoutSession copyWith({
    String? title,
    Object? description = _sentinel,
    WorkoutType? type,
    List<WorkoutBlock>? blocks,
    Object? scheduledDate = _sentinel,
    bool? isTemplate,
    Object? templateId = _sentinel,
  }) {
    return WorkoutSession(
      id: id,
      title: title ?? this.title,
      description:
          description == _sentinel ? this.description : description as String?,
      type: type ?? this.type,
      blocks: blocks ?? this.blocks,
      scheduledDate: scheduledDate == _sentinel
          ? this.scheduledDate
          : scheduledDate as DateTime?,
      isTemplate: isTemplate ?? this.isTemplate,
      templateId:
          templateId == _sentinel ? this.templateId : templateId as String?,
    );
  }
}

const Object _sentinel = Object();
