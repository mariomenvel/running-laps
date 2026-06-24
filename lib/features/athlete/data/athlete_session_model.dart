import 'package:cloud_firestore/cloud_firestore.dart';

// ── SessionBlockType ──────────────────────────────────────────────────────────

enum SessionBlockType {
  series,            // reps × distanceM + restSeconds
  continuousTime,    // durationMinutes
  continuousDistance, // distanceM
}

extension SessionBlockTypeX on SessionBlockType {
  String get toValue {
    switch (this) {
      case SessionBlockType.series:            return 'series';
      case SessionBlockType.continuousTime:    return 'continuous_time';
      case SessionBlockType.continuousDistance: return 'continuous_distance';
    }
  }

  static SessionBlockType fromValue(String v) {
    switch (v) {
      case 'continuous_time':     return SessionBlockType.continuousTime;
      case 'continuous_distance': return SessionBlockType.continuousDistance;
      default:                    return SessionBlockType.series;
    }
  }
}

// ── SessionBlock ──────────────────────────────────────────────────────────────

const Object _sentinel = Object();

class SessionBlock {
  final String id;
  final int order;
  final SessionBlockType type;
  final String? notes;

  // series
  final int? reps;
  final int? distanceM;     // also used by continuousDistance
  final int? restSeconds;

  // continuousTime
  final int? durationMinutes;

  // Objetivos (todos opcionales)
  final int? targetPaceMinMin;  // rango pace mínimo — minutos
  final int? targetPaceMinSec;  // rango pace mínimo — segundos
  final int? targetPaceMaxMin;  // rango pace máximo — minutos
  final int? targetPaceMaxSec;  // rango pace máximo — segundos
  final double? targetRpe;      // 1.0–10.0
  final int? targetZone;        // 1–5
  final int? targetFcBpm;       // FC objetivo en bpm (punto medio de la zona)
  final Map<String, dynamic>? alertsMap;

  const SessionBlock({
    required this.id,
    required this.order,
    required this.type,
    this.notes,
    this.reps,
    this.distanceM,
    this.restSeconds,
    this.durationMinutes,
    this.targetPaceMinMin,
    this.targetPaceMinSec,
    this.targetPaceMaxMin,
    this.targetPaceMaxSec,
    this.targetRpe,
    this.targetZone,
    this.targetFcBpm,
    this.alertsMap,
  });

  factory SessionBlock.fromMap(Map<String, dynamic> map) {
    return SessionBlock(
      id:               map['id'] as String? ?? '',
      order:            map['order'] as int? ?? 0,
      type:             SessionBlockTypeX.fromValue(map['type'] as String? ?? ''),
      notes:            map['notes'] as String?,
      reps:             map['reps'] as int?,
      distanceM:        map['distanceM'] as int?,
      restSeconds:      map['restSeconds'] as int?,
      durationMinutes:  map['durationMinutes'] as int?,
      targetPaceMinMin: map['targetPaceMinMin'] as int?,
      targetPaceMinSec: map['targetPaceMinSec'] as int?,
      targetPaceMaxMin: map['targetPaceMaxMin'] as int?,
      targetPaceMaxSec: map['targetPaceMaxSec'] as int?,
      targetRpe:        (map['targetRpe'] as num?)?.toDouble(),
      targetZone:       map['targetZone'] as int?,
      targetFcBpm:      map['targetFcBpm'] as int?,
      alertsMap:        map['alerts'] != null
                          ? Map<String, dynamic>.from(map['alerts'] as Map)
                          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id':    id,
      'order': order,
      'type':  type.toValue,
      if (notes            != null) 'notes':            notes,
      if (reps             != null) 'reps':             reps,
      if (distanceM        != null) 'distanceM':        distanceM,
      if (restSeconds      != null) 'restSeconds':      restSeconds,
      if (durationMinutes  != null) 'durationMinutes':  durationMinutes,
      if (targetPaceMinMin != null) 'targetPaceMinMin': targetPaceMinMin,
      if (targetPaceMinSec != null) 'targetPaceMinSec': targetPaceMinSec,
      if (targetPaceMaxMin != null) 'targetPaceMaxMin': targetPaceMaxMin,
      if (targetPaceMaxSec != null) 'targetPaceMaxSec': targetPaceMaxSec,
      if (targetRpe        != null) 'targetRpe':        targetRpe,
      if (targetZone       != null) 'targetZone':       targetZone,
      if (targetFcBpm      != null) 'targetFcBpm':      targetFcBpm,
      if (alertsMap        != null) 'alerts':           alertsMap,
    };
  }

  SessionBlock copyWith({
    String? id,
    int? order,
    SessionBlockType? type,
    Object? notes            = _sentinel,
    Object? reps             = _sentinel,
    Object? distanceM        = _sentinel,
    Object? restSeconds      = _sentinel,
    Object? durationMinutes  = _sentinel,
    Object? targetPaceMinMin = _sentinel,
    Object? targetPaceMinSec = _sentinel,
    Object? targetPaceMaxMin = _sentinel,
    Object? targetPaceMaxSec = _sentinel,
    Object? targetRpe        = _sentinel,
    Object? targetZone       = _sentinel,
    Object? targetFcBpm      = _sentinel,
    Object? alertsMap        = _sentinel,
  }) {
    return SessionBlock(
      id:               id               ?? this.id,
      order:            order            ?? this.order,
      type:             type             ?? this.type,
      notes:            notes            == _sentinel ? this.notes            : notes            as String?,
      reps:             reps             == _sentinel ? this.reps             : reps             as int?,
      distanceM:        distanceM        == _sentinel ? this.distanceM        : distanceM        as int?,
      restSeconds:      restSeconds      == _sentinel ? this.restSeconds      : restSeconds      as int?,
      durationMinutes:  durationMinutes  == _sentinel ? this.durationMinutes  : durationMinutes  as int?,
      targetPaceMinMin: targetPaceMinMin == _sentinel ? this.targetPaceMinMin : targetPaceMinMin as int?,
      targetPaceMinSec: targetPaceMinSec == _sentinel ? this.targetPaceMinSec : targetPaceMinSec as int?,
      targetPaceMaxMin: targetPaceMaxMin == _sentinel ? this.targetPaceMaxMin : targetPaceMaxMin as int?,
      targetPaceMaxSec: targetPaceMaxSec == _sentinel ? this.targetPaceMaxSec : targetPaceMaxSec as int?,
      targetRpe:        targetRpe        == _sentinel ? this.targetRpe        : targetRpe        as double?,
      targetZone:       targetZone       == _sentinel ? this.targetZone       : targetZone       as int?,
      targetFcBpm:      targetFcBpm      == _sentinel ? this.targetFcBpm      : targetFcBpm      as int?,
      alertsMap:        alertsMap        == _sentinel ? this.alertsMap        : alertsMap        as Map<String, dynamic>?,
    );
  }
}

// ── SessionWarmupCooldown ─────────────────────────────────────────────────────

class SessionWarmupCooldown {
  final String? description;
  final int? durationMinutes;
  final int? distanceM;

  const SessionWarmupCooldown({
    this.description,
    this.durationMinutes,
    this.distanceM,
  });

  factory SessionWarmupCooldown.fromMap(Map<String, dynamic> map) {
    return SessionWarmupCooldown(
      description:     map['description'] as String?,
      durationMinutes: map['durationMinutes'] as int?,
      distanceM:       map['distanceM'] as int?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (description     != null) 'description':     description,
      if (durationMinutes != null) 'durationMinutes': durationMinutes,
      if (distanceM       != null) 'distanceM':       distanceM,
    };
  }

  SessionWarmupCooldown copyWith({
    Object? description     = _sentinel,
    Object? durationMinutes = _sentinel,
    Object? distanceM       = _sentinel,
  }) {
    return SessionWarmupCooldown(
      description:     description     == _sentinel ? this.description     : description     as String?,
      durationMinutes: durationMinutes == _sentinel ? this.durationMinutes : durationMinutes as int?,
      distanceM:       distanceM       == _sentinel ? this.distanceM       : distanceM       as int?,
    );
  }
}

// ── AthleteSessionStatus ──────────────────────────────────────────────────────

enum AthleteSessionStatus { planned, completed, skipped }

extension AthleteSessionStatusX on AthleteSessionStatus {
  String get toValue {
    switch (this) {
      case AthleteSessionStatus.planned:   return 'planned';
      case AthleteSessionStatus.completed: return 'completed';
      case AthleteSessionStatus.skipped:   return 'skipped';
    }
  }

  static AthleteSessionStatus fromValue(String v) {
    switch (v) {
      case 'completed': return AthleteSessionStatus.completed;
      case 'skipped':   return AthleteSessionStatus.skipped;
      default:          return AthleteSessionStatus.planned;
    }
  }
}

enum AthleteSessionOrigin { manual, ai }

extension AthleteSessionOriginX on AthleteSessionOrigin {
  String get toValue {
    switch (this) {
      case AthleteSessionOrigin.manual:
        return 'manual';
      case AthleteSessionOrigin.ai:
        return 'ai';
    }
  }

  static AthleteSessionOrigin fromValue(String v) {
    switch (v) {
      case 'ai':
        return AthleteSessionOrigin.ai;
      default:
        return AthleteSessionOrigin.manual;
    }
  }
}

enum AthleteSessionSuggestionStatus { suggested, accepted, edited, rejected }

extension AthleteSessionSuggestionStatusX on AthleteSessionSuggestionStatus {
  String get toValue {
    switch (this) {
      case AthleteSessionSuggestionStatus.suggested:
        return 'suggested';
      case AthleteSessionSuggestionStatus.accepted:
        return 'accepted';
      case AthleteSessionSuggestionStatus.edited:
        return 'edited';
      case AthleteSessionSuggestionStatus.rejected:
        return 'rejected';
    }
  }

  static AthleteSessionSuggestionStatus fromValue(String v) {
    switch (v) {
      case 'accepted':
        return AthleteSessionSuggestionStatus.accepted;
      case 'edited':
        return AthleteSessionSuggestionStatus.edited;
      case 'rejected':
        return AthleteSessionSuggestionStatus.rejected;
      default:
        return AthleteSessionSuggestionStatus.suggested;
    }
  }
}

class AthleteSessionSuggestion {
  final AthleteSessionOrigin origin;
  final AthleteSessionSuggestionStatus status;
  final String? decisionId;
  final String? cycleId;
  final String? rationale;
  final String? focus;
  final double? estimatedLoad;
  final String? sourceModel;
  final DateTime? generatedAt;
  final DateTime? respondedAt;
  final String? responseNote;

  const AthleteSessionSuggestion({
    required this.origin,
    required this.status,
    this.decisionId,
    this.cycleId,
    this.rationale,
    this.focus,
    this.estimatedLoad,
    this.sourceModel,
    this.generatedAt,
    this.respondedAt,
    this.responseNote,
  });

  factory AthleteSessionSuggestion.fromMap(Map<String, dynamic> map) {
    return AthleteSessionSuggestion(
      origin: AthleteSessionOriginX.fromValue(
        map['origin'] as String? ?? '',
      ),
      status: AthleteSessionSuggestionStatusX.fromValue(
        map['status'] as String? ?? '',
      ),
      decisionId: map['decisionId'] as String?,
      cycleId: map['cycleId'] as String?,
      rationale: map['rationale'] as String?,
      focus: map['focus'] as String?,
      estimatedLoad: (map['estimatedLoad'] as num?)?.toDouble(),
      sourceModel: map['sourceModel'] as String?,
      generatedAt: map['generatedAt'] != null
          ? _toDateTime(map['generatedAt'])
          : null,
      respondedAt: map['respondedAt'] != null
          ? _toDateTime(map['respondedAt'])
          : null,
      responseNote: map['responseNote'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'origin': origin.toValue,
      'status': status.toValue,
      if (decisionId != null) 'decisionId': decisionId,
      if (cycleId != null) 'cycleId': cycleId,
      if (rationale != null) 'rationale': rationale,
      if (focus != null) 'focus': focus,
      if (estimatedLoad != null) 'estimatedLoad': estimatedLoad,
      if (sourceModel != null) 'sourceModel': sourceModel,
      if (generatedAt != null) 'generatedAt': Timestamp.fromDate(generatedAt!),
      if (respondedAt != null) 'respondedAt': Timestamp.fromDate(respondedAt!),
      if (responseNote != null) 'responseNote': responseNote,
    };
  }

  AthleteSessionSuggestion copyWith({
    AthleteSessionOrigin? origin,
    AthleteSessionSuggestionStatus? status,
    Object? decisionId = _sentinel,
    Object? cycleId = _sentinel,
    Object? rationale = _sentinel,
    Object? focus = _sentinel,
    Object? estimatedLoad = _sentinel,
    Object? sourceModel = _sentinel,
    Object? generatedAt = _sentinel,
    Object? respondedAt = _sentinel,
    Object? responseNote = _sentinel,
  }) {
    return AthleteSessionSuggestion(
      origin: origin ?? this.origin,
      status: status ?? this.status,
      decisionId: decisionId == _sentinel ? this.decisionId : decisionId as String?,
      cycleId: cycleId == _sentinel ? this.cycleId : cycleId as String?,
      rationale: rationale == _sentinel ? this.rationale : rationale as String?,
      focus: focus == _sentinel ? this.focus : focus as String?,
      estimatedLoad: estimatedLoad == _sentinel
          ? this.estimatedLoad
          : estimatedLoad as double?,
      sourceModel: sourceModel == _sentinel ? this.sourceModel : sourceModel as String?,
      generatedAt: generatedAt == _sentinel ? this.generatedAt : generatedAt as DateTime?,
      respondedAt: respondedAt == _sentinel ? this.respondedAt : respondedAt as DateTime?,
      responseNote: responseNote == _sentinel ? this.responseNote : responseNote as String?,
    );
  }
}

// ── AthleteSession ────────────────────────────────────────────────────────────

class AthleteSession {
  final String id;
  final String uid;
  final String date;              // "YYYY-MM-DD"
  final String? time;             // "HH:mm" opcional
  final String? category;         // SessionCategory.toValue()
  final AthleteSessionStatus status;
  final String? completedTrainingId;
  final String? skippedReason;

  final SessionWarmupCooldown? warmup;
  final List<SessionBlock> blocks;
  final SessionWarmupCooldown? cooldown;

  final String? title;

  final String? planningNotes;
  final String? executionNotes;
  final AthleteSessionSuggestion? suggestion;

  // Campos de competición (solo relevantes si category == 'competicion')
  final String? raceName;          // p.ej. "10K Valencia"
  final int?    raceDistanceM;     // distancia oficial en metros
  final int?    targetTimeSeconds; // tiempo objetivo en segundos

  final String? athleteNote;       // nota libre del atleta (ej: ajuste de intensidad)

  // Fecha original de planificación — se fija al crear, nunca se modifica.
  // Si date != originalDate, el atleta movió la sesión.
  final String? originalDate;

  final DateTime createdAt;
  final DateTime updatedAt;

  const AthleteSession({
    required this.id,
    required this.uid,
    required this.date,
    this.time,
    this.category,
    required this.status,
    this.completedTrainingId,
    this.skippedReason,
    this.warmup,
    this.blocks = const [],
    this.cooldown,
    this.title,
    this.planningNotes,
    this.executionNotes,
    this.suggestion,
    this.raceName,
    this.raceDistanceM,
    this.targetTimeSeconds,
    this.athleteNote,
    this.originalDate,
    required this.createdAt,
    required this.updatedAt,
  });

  factory AthleteSession.fromMap(String docId, Map<String, dynamic> map) {
    return AthleteSession(
      id:                   docId,
      uid:                  map['uid'] as String? ?? '',
      date:                 map['date'] as String? ?? '',
      time:                 map['time'] as String?,
      category:             map['category'] as String?,
      status:               AthleteSessionStatusX.fromValue(
                              map['status'] as String? ?? '',
                            ),
      completedTrainingId:  map['completedTrainingId'] as String?,
      skippedReason:        map['skippedReason'] as String?,
      warmup:               map['warmup'] != null
                              ? SessionWarmupCooldown.fromMap(
                                  map['warmup'] as Map<String, dynamic>)
                              : null,
      blocks:               (map['blocks'] as List<dynamic>? ?? [])
                              .map((b) => SessionBlock.fromMap(
                                  b as Map<String, dynamic>))
                              .toList(),
      cooldown:             map['cooldown'] != null
                              ? SessionWarmupCooldown.fromMap(
                                  map['cooldown'] as Map<String, dynamic>)
                              : null,
      title:                map['title'] as String?,
      planningNotes:        map['planningNotes'] as String?,
      executionNotes:       map['executionNotes'] as String?,
      suggestion:           map['suggestion'] != null
                              ? AthleteSessionSuggestion.fromMap(
                                  map['suggestion'] as Map<String, dynamic>)
                              : null,
      raceName:             map['raceName']          as String?,
      raceDistanceM:        map['raceDistanceM']     as int?,
      targetTimeSeconds:    map['targetTimeSeconds'] as int?,
      athleteNote:          map['athleteNote']       as String?,
      originalDate:         map['originalDate']      as String?,
      createdAt:            _toDateTime(map['createdAt']),
      updatedAt:            _toDateTime(map['updatedAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid':    uid,
      'date':   date,
      'status': status.toValue,
      'blocks': blocks.map((b) => b.toMap()).toList(),
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      if (time                 != null) 'time':                 time,
      if (category             != null) 'category':             category,
      if (completedTrainingId  != null) 'completedTrainingId':  completedTrainingId,
      if (skippedReason        != null) 'skippedReason':        skippedReason,
      if (warmup               != null) 'warmup':               warmup!.toMap(),
      if (cooldown             != null) 'cooldown':             cooldown!.toMap(),
      if (title                != null) 'title':                title,
      if (planningNotes        != null) 'planningNotes':        planningNotes,
      if (executionNotes       != null) 'executionNotes':       executionNotes,
      if (suggestion          != null) 'suggestion':            suggestion!.toMap(),
      if (raceName             != null) 'raceName':             raceName,
      if (raceDistanceM        != null) 'raceDistanceM':        raceDistanceM,
      if (targetTimeSeconds    != null) 'targetTimeSeconds':    targetTimeSeconds,
      if (athleteNote          != null) 'athleteNote':          athleteNote,
      if (originalDate         != null) 'originalDate':         originalDate,
    };
  }

  AthleteSession copyWith({
    String? id,
    String? uid,
    String? date,
    Object? time                = _sentinel,
    Object? category            = _sentinel,
    AthleteSessionStatus? status,
    Object? completedTrainingId = _sentinel,
    Object? skippedReason       = _sentinel,
    Object? warmup              = _sentinel,
    List<SessionBlock>? blocks,
    Object? cooldown            = _sentinel,
    Object? title               = _sentinel,
    Object? planningNotes       = _sentinel,
    Object? executionNotes      = _sentinel,
    Object? suggestion          = _sentinel,
    Object? raceName            = _sentinel,
    Object? raceDistanceM       = _sentinel,
    Object? targetTimeSeconds   = _sentinel,
    Object? athleteNote         = _sentinel,
    Object? originalDate        = _sentinel,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return AthleteSession(
      id:                  id                  ?? this.id,
      uid:                 uid                 ?? this.uid,
      date:                date                ?? this.date,
      time:                time                == _sentinel ? this.time                : time                as String?,
      category:            category            == _sentinel ? this.category            : category            as String?,
      status:              status              ?? this.status,
      completedTrainingId: completedTrainingId == _sentinel ? this.completedTrainingId : completedTrainingId as String?,
      skippedReason:       skippedReason       == _sentinel ? this.skippedReason       : skippedReason       as String?,
      warmup:              warmup              == _sentinel ? this.warmup              : warmup              as SessionWarmupCooldown?,
      blocks:              blocks              ?? this.blocks,
      cooldown:            cooldown            == _sentinel ? this.cooldown            : cooldown            as SessionWarmupCooldown?,
      title:               title               == _sentinel ? this.title               : title               as String?,
      planningNotes:       planningNotes       == _sentinel ? this.planningNotes       : planningNotes       as String?,
      executionNotes:      executionNotes      == _sentinel ? this.executionNotes      : executionNotes      as String?,
      suggestion:          suggestion          == _sentinel ? this.suggestion          : suggestion          as AthleteSessionSuggestion?,
      raceName:            raceName            == _sentinel ? this.raceName            : raceName            as String?,
      raceDistanceM:       raceDistanceM       == _sentinel ? this.raceDistanceM       : raceDistanceM       as int?,
      targetTimeSeconds:   targetTimeSeconds   == _sentinel ? this.targetTimeSeconds   : targetTimeSeconds   as int?,
      athleteNote:         athleteNote         == _sentinel ? this.athleteNote         : athleteNote         as String?,
      originalDate:        originalDate        == _sentinel ? this.originalDate        : originalDate        as String?,
      createdAt:           createdAt           ?? this.createdAt,
      updatedAt:           updatedAt           ?? this.updatedAt,
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

DateTime _toDateTime(dynamic value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  if (value is String) {
    try { return DateTime.parse(value); } catch (_) {}
  }
  return DateTime.now();
}
