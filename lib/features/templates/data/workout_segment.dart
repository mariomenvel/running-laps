import 'package:uuid/uuid.dart';

import 'target_config.dart';

enum SegmentType { interval, recovery }

enum RecoveryType { active, passive }

class WorkoutSegment {
  final String id;
  final SegmentType type;
  final int? durationSec;
  final int? distanceM;
  final RecoveryType? recoveryType;
  final TargetConfig? target;

  WorkoutSegment({
    String? id,
    required this.type,
    this.durationSec,
    this.distanceM,
    this.recoveryType,
    this.target,
  }) : id = id ?? const Uuid().v4(),
       assert(
         durationSec != null || distanceM != null,
         'durationSec or distanceM must be provided',
       );

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type.name,
      if (durationSec != null) 'durationSec': durationSec,
      if (distanceM != null) 'distanceM': distanceM,
      if (recoveryType != null) 'recoveryType': recoveryType!.name,
      if (target != null) 'target': target!.toMap(),
    };
  }

  factory WorkoutSegment.fromMap(Map<String, dynamic> map) {
    return WorkoutSegment(
      id: map['id'] as String,
      type: SegmentType.values.byName(map['type'] as String),
      durationSec: map['durationSec'] as int?,
      distanceM: map['distanceM'] as int?,
      recoveryType: map['recoveryType'] != null
          ? RecoveryType.values.byName(map['recoveryType'] as String)
          : null,
      target: map['target'] != null
          ? TargetConfig.fromMap(Map<String, dynamic>.from(map['target'] as Map))
          : null,
    );
  }

  WorkoutSegment copyWith({
    SegmentType? type,
    Object? durationSec = _sentinel,
    Object? distanceM = _sentinel,
    Object? recoveryType = _sentinel,
    Object? target = _sentinel,
  }) {
    return WorkoutSegment(
      id: id,
      type: type ?? this.type,
      durationSec:
          durationSec == _sentinel ? this.durationSec : durationSec as int?,
      distanceM: distanceM == _sentinel ? this.distanceM : distanceM as int?,
      recoveryType: recoveryType == _sentinel
          ? this.recoveryType
          : recoveryType as RecoveryType?,
      target: target == _sentinel ? this.target : target as TargetConfig?,
    );
  }
}

const Object _sentinel = Object();
