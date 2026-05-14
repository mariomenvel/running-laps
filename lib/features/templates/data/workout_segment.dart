import 'package:uuid/uuid.dart';

import 'target_config.dart';

enum SegmentType { interval, recovery }

enum RecoveryType { active, passive }

class SegmentAlerts {
  final bool enabled;
  final String mode; // 'time' | 'pace'
  final int timeMin;
  final double timeSec; // pasos de 0.5s
  final int paceMin;
  final int paceSec;
  final int segmentDistanceM; // metros (ej: 100, 200, 400)

  const SegmentAlerts({
    this.enabled = false,
    this.mode = 'time',
    this.timeMin = 0,
    this.timeSec = 30,
    this.paceMin = 5,
    this.paceSec = 0,
    this.segmentDistanceM = 400,
  });

  factory SegmentAlerts.fromMap(Map<String, dynamic> m) => SegmentAlerts(
    enabled: m['enabled'] as bool? ?? false,
    mode: m['mode'] as String? ?? 'time',
    timeMin: (m['timeMin'] as num?)?.toInt() ?? 0,
    timeSec: (m['timeSec'] as num?)?.toDouble() ?? 30,
    paceMin: (m['paceMin'] as num?)?.toInt() ?? 5,
    paceSec: (m['paceSec'] as num?)?.toInt() ?? 0,
    segmentDistanceM: (m['segmentDistanceM'] as num?)?.toInt() ?? 400,
  );

  Map<String, dynamic> toMap() => {
    'enabled': enabled,
    'mode': mode,
    'timeMin': timeMin,
    'timeSec': timeSec,
    'paceMin': paceMin,
    'paceSec': paceSec,
    'segmentDistanceM': segmentDistanceM,
  };

  int toAlarmIntervalMs() {
    if (!enabled) return 0;
    if (mode == 'time') {
      return ((timeMin * 60 + timeSec) * 1000).round();
    } else {
      // pace mode: segundos para recorrer segmentDistanceM al pace dado
      final totalPaceSec = paceMin * 60 + paceSec; // seg/km
      final intervalSec = totalPaceSec * segmentDistanceM / 1000;
      return (intervalSec * 1000).round();
    }
  }

  SegmentAlerts copyWith({
    bool? enabled,
    String? mode,
    int? timeMin,
    double? timeSec,
    int? paceMin,
    int? paceSec,
    int? segmentDistanceM,
  }) => SegmentAlerts(
    enabled: enabled ?? this.enabled,
    mode: mode ?? this.mode,
    timeMin: timeMin ?? this.timeMin,
    timeSec: timeSec ?? this.timeSec,
    paceMin: paceMin ?? this.paceMin,
    paceSec: paceSec ?? this.paceSec,
    segmentDistanceM: segmentDistanceM ?? this.segmentDistanceM,
  );
}

class WorkoutSegment {
  final String id;
  final SegmentType type;
  final int? durationSec;
  final int? distanceM;
  final RecoveryType? recoveryType;
  final TargetConfig? target;
  final SegmentAlerts? alerts;

  WorkoutSegment({
    String? id,
    required this.type,
    this.durationSec,
    this.distanceM,
    this.recoveryType,
    this.target,
    this.alerts,
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
      if (alerts != null) 'alerts': alerts!.toMap(),
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
      alerts: map['alerts'] != null
          ? SegmentAlerts.fromMap(Map<String, dynamic>.from(map['alerts'] as Map))
          : null,
    );
  }

  WorkoutSegment copyWith({
    SegmentType? type,
    Object? durationSec = _sentinel,
    Object? distanceM = _sentinel,
    Object? recoveryType = _sentinel,
    Object? target = _sentinel,
    Object? alerts = _sentinel,
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
      alerts: alerts == _sentinel ? this.alerts : alerts as SegmentAlerts?,
    );
  }
}

const Object _sentinel = Object();
