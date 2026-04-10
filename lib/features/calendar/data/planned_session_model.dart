import 'package:cloud_firestore/cloud_firestore.dart';

// ── Status ────────────────────────────────────────────────────────────────────

enum PlannedSessionStatus { planned, completed, skipped }

extension PlannedSessionStatusX on PlannedSessionStatus {
  String get toValue {
    switch (this) {
      case PlannedSessionStatus.planned:   return 'planned';
      case PlannedSessionStatus.completed: return 'completed';
      case PlannedSessionStatus.skipped:   return 'skipped';
    }
  }

  static PlannedSessionStatus fromValue(String v) {
    switch (v) {
      case 'completed': return PlannedSessionStatus.completed;
      case 'skipped':   return PlannedSessionStatus.skipped;
      default:          return PlannedSessionStatus.planned;
    }
  }
}

// ── Model ─────────────────────────────────────────────────────────────────────

const Object _sentinel = Object();

class PlannedSession {
  final String id;
  final String uid;

  /// ISO8601 date-only string: "2026-04-10"
  final String date;

  /// Optional time string: "09:30", null if not set
  final String? time;

  /// SessionCategory.toValue() string
  final String category;

  final String? templateId;
  final String? notes;
  final PlannedSessionStatus status;

  /// id of the Entrenamiento that fulfilled this session
  final String? completedTrainingId;

  /// Reason provided when status == skipped
  final String? skippedReason;

  final DateTime createdAt;
  final DateTime updatedAt;

  const PlannedSession({
    required this.id,
    required this.uid,
    required this.date,
    this.time,
    required this.category,
    this.templateId,
    this.notes,
    required this.status,
    this.completedTrainingId,
    this.skippedReason,
    required this.createdAt,
    required this.updatedAt,
  });

  factory PlannedSession.fromMap(String docId, Map<String, dynamic> map) {
    return PlannedSession(
      id:                   docId,
      uid:                  map['uid'] as String? ?? '',
      date:                 map['date'] as String? ?? '',
      time:                 map['time'] as String?,
      category:             map['category'] as String? ?? 'rodaje_base',
      templateId:           map['templateId'] as String?,
      notes:                map['notes'] as String?,
      status:               PlannedSessionStatusX.fromValue(
                              map['status'] as String? ?? '',
                            ),
      completedTrainingId:  map['completedTrainingId'] as String?,
      skippedReason:        map['skippedReason'] as String?,
      createdAt:            _toDateTime(map['createdAt']),
      updatedAt:            _toDateTime(map['updatedAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid':                  uid,
      'date':                 date,
      'time':                 time,
      'category':             category,
      'templateId':           templateId,
      'notes':                notes,
      'status':               status.toValue,
      'completedTrainingId':  completedTrainingId,
      'skippedReason':        skippedReason,
      'createdAt':            Timestamp.fromDate(createdAt),
      'updatedAt':            Timestamp.fromDate(updatedAt),
    };
  }

  PlannedSession copyWith({
    String? id,
    String? uid,
    String? date,
    Object? time = _sentinel,
    String? category,
    Object? templateId = _sentinel,
    Object? notes = _sentinel,
    PlannedSessionStatus? status,
    Object? completedTrainingId = _sentinel,
    Object? skippedReason = _sentinel,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return PlannedSession(
      id:                  id ?? this.id,
      uid:                 uid ?? this.uid,
      date:                date ?? this.date,
      time:                time == _sentinel ? this.time : time as String?,
      category:            category ?? this.category,
      templateId:          templateId == _sentinel ? this.templateId : templateId as String?,
      notes:               notes == _sentinel ? this.notes : notes as String?,
      status:              status ?? this.status,
      completedTrainingId: completedTrainingId == _sentinel
          ? this.completedTrainingId
          : completedTrainingId as String?,
      skippedReason:       skippedReason == _sentinel
          ? this.skippedReason
          : skippedReason as String?,
      createdAt:           createdAt ?? this.createdAt,
      updatedAt:           updatedAt ?? this.updatedAt,
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

DateTime _toDateTime(dynamic value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  return DateTime.now();
}
