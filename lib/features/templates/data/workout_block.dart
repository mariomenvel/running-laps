import 'package:uuid/uuid.dart';

import 'workout_segment.dart';

enum BlockRole { warmup, main, cooldown, custom }

class WorkoutBlock {
  final String id;
  final BlockRole role;
  final int repetitions;
  final List<WorkoutSegment> segments;
  final String? label;

  WorkoutBlock({
    String? id,
    required this.role,
    required this.repetitions,
    required this.segments,
    this.label,
  }) : id = id ?? const Uuid().v4(),
       assert(
         (role == BlockRole.warmup || role == BlockRole.cooldown)
             ? repetitions == 1
             : repetitions >= 1,
         'warmup and cooldown must have repetitions == 1',
       );

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'role': role.name,
      'repetitions': repetitions,
      'segments': segments.map((s) => s.toMap()).toList(),
      if (label != null) 'label': label,
    };
  }

  factory WorkoutBlock.fromMap(Map<String, dynamic> map) {
    return WorkoutBlock(
      id: map['id'] as String,
      role: BlockRole.values.byName(map['role'] as String),
      repetitions: map['repetitions'] as int,
      segments: (map['segments'] as List)
          .map((e) => WorkoutSegment.fromMap(Map<String, dynamic>.from(e as Map)))
          .toList(),
      label: map['label'] as String?,
    );
  }

  WorkoutBlock copyWith({
    BlockRole? role,
    int? repetitions,
    List<WorkoutSegment>? segments,
    Object? label = _sentinel,
  }) {
    return WorkoutBlock(
      id: id,
      role: role ?? this.role,
      repetitions: repetitions ?? this.repetitions,
      segments: segments ?? this.segments,
      label: label == _sentinel ? this.label : label as String?,
    );
  }
}

const Object _sentinel = Object();
