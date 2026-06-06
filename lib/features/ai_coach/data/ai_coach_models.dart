import 'package:running_laps/features/ai_coach/data/ai_coach_defaults.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

enum AiCoachGoalType {
  race5k,
  race10k,
  raceHalfMarathon,
  raceMarathon,
  improvePace,
  improveEndurance,
  returnToRunning,
}

extension AiCoachGoalTypeX on AiCoachGoalType {
  String get toValue {
    switch (this) {
      case AiCoachGoalType.race5k:
        return 'race_5k';
      case AiCoachGoalType.race10k:
        return 'race_10k';
      case AiCoachGoalType.raceHalfMarathon:
        return 'race_half_marathon';
      case AiCoachGoalType.raceMarathon:
        return 'race_marathon';
      case AiCoachGoalType.improvePace:
        return 'improve_pace';
      case AiCoachGoalType.improveEndurance:
        return 'improve_endurance';
      case AiCoachGoalType.returnToRunning:
        return 'return_to_running';
    }
  }

  static AiCoachGoalType fromValue(String value) {
    switch (value) {
      case 'race_5k':
        return AiCoachGoalType.race5k;
      case 'race_10k':
        return AiCoachGoalType.race10k;
      case 'race_half_marathon':
        return AiCoachGoalType.raceHalfMarathon;
      case 'race_marathon':
        return AiCoachGoalType.raceMarathon;
      case 'improve_pace':
        return AiCoachGoalType.improvePace;
      case 'return_to_running':
        return AiCoachGoalType.returnToRunning;
      default:
        return AiCoachGoalType.improveEndurance;
    }
  }
}

enum AiCoachAthleteLevel { beginner, intermediate, advanced }

extension AiCoachAthleteLevelX on AiCoachAthleteLevel {
  String get toValue {
    switch (this) {
      case AiCoachAthleteLevel.beginner:
        return 'beginner';
      case AiCoachAthleteLevel.intermediate:
        return 'intermediate';
      case AiCoachAthleteLevel.advanced:
        return 'advanced';
    }
  }

  static AiCoachAthleteLevel fromValue(String value) {
    switch (value) {
      case 'advanced':
        return AiCoachAthleteLevel.advanced;
      case 'intermediate':
        return AiCoachAthleteLevel.intermediate;
      default:
        return AiCoachAthleteLevel.beginner;
    }
  }
}

enum AiCoachConstraintType {
  strengthTraining,
  unavailable,
  preferredRest,
  injuryRisk,
  travel,
  custom,
}

extension AiCoachConstraintTypeX on AiCoachConstraintType {
  String get toValue {
    switch (this) {
      case AiCoachConstraintType.strengthTraining:
        return 'strength_training';
      case AiCoachConstraintType.unavailable:
        return 'unavailable';
      case AiCoachConstraintType.preferredRest:
        return 'preferred_rest';
      case AiCoachConstraintType.injuryRisk:
        return 'injury_risk';
      case AiCoachConstraintType.travel:
        return 'travel';
      case AiCoachConstraintType.custom:
        return 'custom';
    }
  }

  static AiCoachConstraintType fromValue(String value) {
    switch (value) {
      case 'strength_training':
        return AiCoachConstraintType.strengthTraining;
      case 'unavailable':
        return AiCoachConstraintType.unavailable;
      case 'preferred_rest':
        return AiCoachConstraintType.preferredRest;
      case 'injury_risk':
        return AiCoachConstraintType.injuryRisk;
      case 'travel':
        return AiCoachConstraintType.travel;
      default:
        return AiCoachConstraintType.custom;
    }
  }
}

enum AiCoachTemporaryStatusType {
  soreness,
  fatigue,
  injury,
  lowAvailability,
  highReadiness,
  raceWeek,
  custom,
}

extension AiCoachTemporaryStatusTypeX on AiCoachTemporaryStatusType {
  String get toValue {
    switch (this) {
      case AiCoachTemporaryStatusType.soreness:
        return 'soreness';
      case AiCoachTemporaryStatusType.fatigue:
        return 'fatigue';
      case AiCoachTemporaryStatusType.injury:
        return 'injury';
      case AiCoachTemporaryStatusType.lowAvailability:
        return 'low_availability';
      case AiCoachTemporaryStatusType.highReadiness:
        return 'high_readiness';
      case AiCoachTemporaryStatusType.raceWeek:
        return 'race_week';
      case AiCoachTemporaryStatusType.custom:
        return 'custom';
    }
  }

  static AiCoachTemporaryStatusType fromValue(String value) {
    switch (value) {
      case 'soreness':
        return AiCoachTemporaryStatusType.soreness;
      case 'fatigue':
        return AiCoachTemporaryStatusType.fatigue;
      case 'injury':
        return AiCoachTemporaryStatusType.injury;
      case 'low_availability':
        return AiCoachTemporaryStatusType.lowAvailability;
      case 'high_readiness':
        return AiCoachTemporaryStatusType.highReadiness;
      case 'race_week':
        return AiCoachTemporaryStatusType.raceWeek;
      default:
        return AiCoachTemporaryStatusType.custom;
    }
  }
}

enum AiCoachAdjustmentType {
  progress,
  maintain,
  reduce,
  deload,
  taper,
  restart,
  recover,
}

extension AiCoachAdjustmentTypeX on AiCoachAdjustmentType {
  String get toValue {
    switch (this) {
      case AiCoachAdjustmentType.progress:
        return 'progress';
      case AiCoachAdjustmentType.maintain:
        return 'maintain';
      case AiCoachAdjustmentType.reduce:
        return 'reduce';
      case AiCoachAdjustmentType.deload:
        return 'deload';
      case AiCoachAdjustmentType.taper:
        return 'taper';
      case AiCoachAdjustmentType.restart:
        return 'restart';
      case AiCoachAdjustmentType.recover:
        return 'recover';
    }
  }

  static AiCoachAdjustmentType fromValue(String value) {
    switch (value) {
      case 'maintain':
        return AiCoachAdjustmentType.maintain;
      case 'reduce':
        return AiCoachAdjustmentType.reduce;
      case 'deload':
        return AiCoachAdjustmentType.deload;
      case 'taper':
        return AiCoachAdjustmentType.taper;
      case 'restart':
        return AiCoachAdjustmentType.restart;
      case 'recover':
        return AiCoachAdjustmentType.recover;
      default:
        return AiCoachAdjustmentType.progress;
    }
  }
}

enum AiCoachWeekType { build, absorb, recovery, taper, race, restart }

extension AiCoachWeekTypeX on AiCoachWeekType {
  String get toValue {
    switch (this) {
      case AiCoachWeekType.build:
        return 'build';
      case AiCoachWeekType.absorb:
        return 'absorb';
      case AiCoachWeekType.recovery:
        return 'recovery';
      case AiCoachWeekType.taper:
        return 'taper';
      case AiCoachWeekType.race:
        return 'race';
      case AiCoachWeekType.restart:
        return 'restart';
    }
  }

  static AiCoachWeekType fromValue(String value) {
    switch (value) {
      case 'absorb':
        return AiCoachWeekType.absorb;
      case 'recovery':
        return AiCoachWeekType.recovery;
      case 'taper':
        return AiCoachWeekType.taper;
      case 'race':
        return AiCoachWeekType.race;
      case 'restart':
        return AiCoachWeekType.restart;
      default:
        return AiCoachWeekType.build;
    }
  }
}

class AiCoachRecurringConstraint {
  final String id;
  final AiCoachConstraintType type;
  final String label;
  final List<int> weekdays;
  final int? priority;
  final String? notes;

  const AiCoachRecurringConstraint({
    required this.id,
    required this.type,
    required this.label,
    this.weekdays = const [],
    this.priority,
    this.notes,
  });

  factory AiCoachRecurringConstraint.fromMap(Map<String, dynamic> map) {
    return AiCoachRecurringConstraint(
      id: map['id'] as String? ?? '',
      type: AiCoachConstraintTypeX.fromValue(map['type'] as String? ?? ''),
      label: map['label'] as String? ?? '',
      weekdays: List<int>.from(map['weekdays'] as List? ?? const []),
      priority: (map['priority'] as num?)?.toInt(),
      notes: map['notes'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type.toValue,
      'label': label,
      'weekdays': weekdays,
      if (priority != null) 'priority': priority,
      if (notes != null) 'notes': notes,
    };
  }
}

class AiCoachTemporaryStatus {
  final String id;
  final AiCoachTemporaryStatusType type;
  final String message;
  final DateTime createdAt;
  final DateTime? validUntil;
  final bool active;

  const AiCoachTemporaryStatus({
    required this.id,
    required this.type,
    required this.message,
    required this.createdAt,
    this.validUntil,
    this.active = true,
  });

  factory AiCoachTemporaryStatus.fromMap(Map<String, dynamic> map) {
    return AiCoachTemporaryStatus(
      id: map['id'] as String? ?? '',
      type: AiCoachTemporaryStatusTypeX.fromValue(
        map['type'] as String? ?? '',
      ),
      message: map['message'] as String? ?? '',
      createdAt: _toDateTime(map['createdAt']),
      validUntil: map['validUntil'] != null ? _toDateTime(map['validUntil']) : null,
      active: map['active'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type.toValue,
      'message': message,
      'createdAt': Timestamp.fromDate(createdAt),
      'active': active,
      if (validUntil != null) 'validUntil': Timestamp.fromDate(validUntil!),
    };
  }
}

class AiCoachProfile {
  final String uid;
  final AiCoachGoalType goal;
  final String goalDescription;
  final DateTime? targetDate;
  final AiCoachAthleteLevel level;
  final List<int> availableWeekdays;
  final int preferredWeeklySessions;
  final int? preferredLongRunWeekday;
  final List<AiCoachRecurringConstraint> recurringConstraints;
  final List<AiCoachTemporaryStatus> temporaryStatuses;
  final String? coachNotes;
  final int? fcMax;
  final DateTime createdAt;
  final DateTime updatedAt;

  const AiCoachProfile({
    required this.uid,
    required this.goal,
    required this.goalDescription,
    this.targetDate,
    required this.level,
    this.availableWeekdays = const [],
    required this.preferredWeeklySessions,
    this.preferredLongRunWeekday,
    this.recurringConstraints = const [],
    this.temporaryStatuses = const [],
    this.coachNotes,
    this.fcMax,
    required this.createdAt,
    required this.updatedAt,
  });

  factory AiCoachProfile.fromMap(String uid, Map<String, dynamic> map) {
    return AiCoachProfile(
      uid: uid,
      goal: AiCoachGoalTypeX.fromValue(map['goal'] as String? ?? ''),
      goalDescription: map['goalDescription'] as String? ?? '',
      targetDate: map['targetDate'] != null ? _toDateTime(map['targetDate']) : null,
      level: AiCoachAthleteLevelX.fromValue(map['level'] as String? ?? ''),
      availableWeekdays: List<int>.from(
        map['availableWeekdays'] as List? ?? const [],
      ),
      preferredWeeklySessions:
          (map['preferredWeeklySessions'] as num?)?.toInt() ?? 3,
      preferredLongRunWeekday:
          (map['preferredLongRunWeekday'] as num?)?.toInt(),
      recurringConstraints: (map['recurringConstraints'] as List? ?? const [])
          .map((item) => AiCoachRecurringConstraint.fromMap(
              Map<String, dynamic>.from(item as Map)))
          .toList(),
      temporaryStatuses: (map['temporaryStatuses'] as List? ?? const [])
          .map((item) => AiCoachTemporaryStatus.fromMap(
              Map<String, dynamic>.from(item as Map)))
          .toList(),
      coachNotes: map['coachNotes'] as String?,
      fcMax: (map['fcMax'] as num?)?.toInt(),
      createdAt: _toDateTime(map['createdAt']),
      updatedAt: _toDateTime(map['updatedAt']),
    );
  }

  AiCoachProfile copyWith({
    AiCoachGoalType? goal,
    String? goalDescription,
    DateTime? targetDate,
    AiCoachAthleteLevel? level,
    List<int>? availableWeekdays,
    int? preferredWeeklySessions,
    int? preferredLongRunWeekday,
    List<AiCoachRecurringConstraint>? recurringConstraints,
    List<AiCoachTemporaryStatus>? temporaryStatuses,
    String? coachNotes,
    int? fcMax,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return AiCoachProfile(
      uid: uid,
      goal: goal ?? this.goal,
      goalDescription: goalDescription ?? this.goalDescription,
      targetDate: targetDate ?? this.targetDate,
      level: level ?? this.level,
      availableWeekdays: availableWeekdays ?? this.availableWeekdays,
      preferredWeeklySessions:
          preferredWeeklySessions ?? this.preferredWeeklySessions,
      preferredLongRunWeekday:
          preferredLongRunWeekday ?? this.preferredLongRunWeekday,
      recurringConstraints: recurringConstraints ?? this.recurringConstraints,
      temporaryStatuses: temporaryStatuses ?? this.temporaryStatuses,
      coachNotes: coachNotes ?? this.coachNotes,
      fcMax: fcMax ?? this.fcMax,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'goal': goal.toValue,
      'goalDescription': goalDescription,
      'level': level.toValue,
      'availableWeekdays': availableWeekdays,
      'preferredWeeklySessions': preferredWeeklySessions,
      'recurringConstraints':
          recurringConstraints.map((item) => item.toMap()).toList(),
      'temporaryStatuses':
          temporaryStatuses.map((item) => item.toMap()).toList(),
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      if (targetDate != null) 'targetDate': Timestamp.fromDate(targetDate!),
      if (preferredLongRunWeekday != null)
        'preferredLongRunWeekday': preferredLongRunWeekday,
      if (coachNotes != null) 'coachNotes': coachNotes,
      if (fcMax != null) 'fcMax': fcMax,
    };
  }
}

class AiCoachUsage {
  final String plan;
  final int messagesUsed;
  final int? messagesLimit;
  final DateTime periodStart;
  final DateTime periodEnd;

  const AiCoachUsage({
    required this.plan,
    required this.messagesUsed,
    this.messagesLimit,
    required this.periodStart,
    required this.periodEnd,
  });

  factory AiCoachUsage.fromMap(Map<String, dynamic> map) {
    return AiCoachUsage(
      plan: map['plan'] as String? ?? 'basic',
      messagesUsed: (map['messagesUsed'] as num?)?.toInt() ?? 0,
      messagesLimit: (map['messagesLimit'] as num?)?.toInt(),
      periodStart: _toDateTime(map['periodStart']),
      periodEnd: _toDateTime(map['periodEnd']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'plan': plan,
      'messagesUsed': messagesUsed,
      'periodStart': Timestamp.fromDate(periodStart),
      'periodEnd': Timestamp.fromDate(periodEnd),
      if (messagesLimit != null) 'messagesLimit': messagesLimit,
    };
  }
}

class AiCoachProviderConfig {
  final String provider;
  final String model;
  final String? apiKey;
  final bool weeklyPlanningEnabled;
  final bool chatAdjustmentsEnabled;
  final DateTime? updatedAt;

  const AiCoachProviderConfig({
    required this.provider,
    required this.model,
    this.apiKey,
    this.weeklyPlanningEnabled = false,
    this.chatAdjustmentsEnabled = false,
    this.updatedAt,
  });

  factory AiCoachProviderConfig.fromMap(Map<String, dynamic> map) {
    return AiCoachProviderConfig(
      provider: map['provider'] as String? ?? 'openrouter',
      model: map['model'] as String? ?? kAiCoachDefaultOpenRouterModel,
      apiKey: map['apiKey'] as String? ?? kAiCoachDefaultOpenRouterApiKey,
      weeklyPlanningEnabled: map['weeklyPlanningEnabled'] as bool? ?? true,
      chatAdjustmentsEnabled: map['chatAdjustmentsEnabled'] as bool? ?? true,
      updatedAt: map['updatedAt'] != null ? _toDateTime(map['updatedAt']) : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'provider': provider,
      'model': model,
      'weeklyPlanningEnabled': weeklyPlanningEnabled,
      'chatAdjustmentsEnabled': chatAdjustmentsEnabled,
      if (apiKey != null) 'apiKey': apiKey,
      if (updatedAt != null) 'updatedAt': Timestamp.fromDate(updatedAt!),
    };
  }
}

class AiCoachWeeklyState {
  final DateTime weekStart;
  final int plannedSessions;
  final int completedSessions;
  final int skippedSessions;
  final double adherenceRatio;
  final double weeklyKm;
  final double weeklyLoad;
  final double weeklyRpeAverage;
  final double atl;
  final double ctl;
  final double tsb;
  final int daysSinceLastTraining;
  final int consecutiveMissedWeeks;
  final bool raceInNext14Days;
  final bool needsDeload;
  final String trend;

  const AiCoachWeeklyState({
    required this.weekStart,
    required this.plannedSessions,
    required this.completedSessions,
    required this.skippedSessions,
    required this.adherenceRatio,
    required this.weeklyKm,
    required this.weeklyLoad,
    required this.weeklyRpeAverage,
    required this.atl,
    required this.ctl,
    required this.tsb,
    required this.daysSinceLastTraining,
    required this.consecutiveMissedWeeks,
    required this.raceInNext14Days,
    required this.needsDeload,
    required this.trend,
  });

  factory AiCoachWeeklyState.fromMap(Map<String, dynamic> map) {
    return AiCoachWeeklyState(
      weekStart: _toDateTime(map['weekStart']),
      plannedSessions: (map['plannedSessions'] as num?)?.toInt() ?? 0,
      completedSessions: (map['completedSessions'] as num?)?.toInt() ?? 0,
      skippedSessions: (map['skippedSessions'] as num?)?.toInt() ?? 0,
      adherenceRatio: (map['adherenceRatio'] as num?)?.toDouble() ?? 0,
      weeklyKm: (map['weeklyKm'] as num?)?.toDouble() ?? 0,
      weeklyLoad: (map['weeklyLoad'] as num?)?.toDouble() ?? 0,
      weeklyRpeAverage: (map['weeklyRpeAverage'] as num?)?.toDouble() ?? 0,
      atl: (map['atl'] as num?)?.toDouble() ?? 0,
      ctl: (map['ctl'] as num?)?.toDouble() ?? 0,
      tsb: (map['tsb'] as num?)?.toDouble() ?? 0,
      daysSinceLastTraining: (map['daysSinceLastTraining'] as num?)?.toInt() ?? 999,
      consecutiveMissedWeeks:
          (map['consecutiveMissedWeeks'] as num?)?.toInt() ?? 0,
      raceInNext14Days: map['raceInNext14Days'] as bool? ?? false,
      needsDeload: map['needsDeload'] as bool? ?? false,
      trend: map['trend'] as String? ?? 'stable',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'weekStart': Timestamp.fromDate(weekStart),
      'plannedSessions': plannedSessions,
      'completedSessions': completedSessions,
      'skippedSessions': skippedSessions,
      'adherenceRatio': adherenceRatio,
      'weeklyKm': weeklyKm,
      'weeklyLoad': weeklyLoad,
      'weeklyRpeAverage': weeklyRpeAverage,
      'atl': atl,
      'ctl': ctl,
      'tsb': tsb,
      'daysSinceLastTraining': daysSinceLastTraining,
      'consecutiveMissedWeeks': consecutiveMissedWeeks,
      'raceInNext14Days': raceInNext14Days,
      'needsDeload': needsDeload,
      'trend': trend,
    };
  }
}

class AiCoachTrainingSummary {
  final String trainingId;
  final DateTime date;
  final String title;
  final String category;
  final double distanceKm;
  final double durationMinutes;
  final double? paceSecPerKm;
  final double? rpe;
  final double? load;
  final double? fcAvg;
  final String? note;

  const AiCoachTrainingSummary({
    required this.trainingId,
    required this.date,
    required this.title,
    required this.category,
    required this.distanceKm,
    required this.durationMinutes,
    this.paceSecPerKm,
    this.rpe,
    this.load,
    this.fcAvg,
    this.note,
  });

  Map<String, dynamic> toMap() {
    return {
      'trainingId': trainingId,
      'date': date.toIso8601String(),
      'title': title,
      'category': category,
      'distanceKm': distanceKm,
      'durationMinutes': durationMinutes,
      if (paceSecPerKm != null) 'paceSecPerKm': paceSecPerKm,
      if (rpe != null) 'rpe': rpe,
      if (load != null) 'load': load,
      if (fcAvg != null) 'fcAvg': fcAvg,
      if (note != null) 'note': note,
    };
  }
}

class AiCoachPlannedSessionSummary {
  final String sessionId;
  final String date;
  final String? category;
  final String status;
  final bool isAiSuggested;
  final String? suggestionStatus;

  const AiCoachPlannedSessionSummary({
    required this.sessionId,
    required this.date,
    required this.category,
    required this.status,
    required this.isAiSuggested,
    this.suggestionStatus,
  });

  Map<String, dynamic> toMap() {
    return {
      'sessionId': sessionId,
      'date': date,
      if (category != null) 'category': category,
      'status': status,
      'isAiSuggested': isAiSuggested,
      if (suggestionStatus != null) 'suggestionStatus': suggestionStatus,
    };
  }
}

class AiCoachWeeklyContext {
  final AiCoachProfile? profile;
  final AiCoachWeeklyState weeklyState;
  final List<AiCoachTrainingSummary> recentTrainings;
  final List<AiCoachPlannedSessionSummary> recentPlannedSessions;
  final List<Map<String, dynamic>> recentWeekHistory;
  final Map<String, dynamic> coachSignals;
  final DateTime generatedAt;

  const AiCoachWeeklyContext({
    required this.profile,
    required this.weeklyState,
    required this.recentTrainings,
    required this.recentPlannedSessions,
    this.recentWeekHistory = const [],
    this.coachSignals = const {},
    required this.generatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'generatedAt': generatedAt.toIso8601String(),
      'profile': profile?.toMap(),
      'weeklyState': weeklyState.toMap(),
      'recentTrainings': recentTrainings.map((item) => item.toMap()).toList(),
      'recentPlannedSessions':
          recentPlannedSessions.map((item) => item.toMap()).toList(),
      'recentWeekHistory': recentWeekHistory,
      'coachSignals': coachSignals,
    };
  }
}

class AiCoachAthleteMemory {
  final String preferredStyle;
  final Map<String, double> categoryAcceptance;
  final Map<String, double> categoryCompletion;
  final Map<int, double> weekdayAdherence;
  final DateTime updatedAt;

  const AiCoachAthleteMemory({
    required this.preferredStyle,
    this.categoryAcceptance = const {},
    this.categoryCompletion = const {},
    this.weekdayAdherence = const {},
    required this.updatedAt,
  });

  factory AiCoachAthleteMemory.fromMap(Map<String, dynamic> map) {
    return AiCoachAthleteMemory(
      preferredStyle: map['preferredStyle'] as String? ?? 'mixed',
      categoryAcceptance: (map['categoryAcceptance'] as Map? ?? const {})
          .map((k, v) => MapEntry(k.toString(), (v as num).toDouble())),
      categoryCompletion: (map['categoryCompletion'] as Map? ?? const {})
          .map((k, v) => MapEntry(k.toString(), (v as num).toDouble())),
      weekdayAdherence: (map['weekdayAdherence'] as Map? ?? const {}).map(
        (k, v) => MapEntry(int.tryParse(k.toString()) ?? 1, (v as num).toDouble()),
      ),
      updatedAt: _toDateTime(map['updatedAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'preferredStyle': preferredStyle,
      'categoryAcceptance': categoryAcceptance,
      'categoryCompletion': categoryCompletion,
      'weekdayAdherence':
          weekdayAdherence.map((k, v) => MapEntry(k.toString(), v)),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }
}

class AiCoachWorkoutTarget {
  final String category;
  final String purpose;
  final int priority;
  final String? preferredDay;
  final double? targetLoad;
  final double? targetDistanceKm;
  final int? targetDurationMinutes;
  final String? notes;

  const AiCoachWorkoutTarget({
    required this.category,
    required this.purpose,
    required this.priority,
    this.preferredDay,
    this.targetLoad,
    this.targetDistanceKm,
    this.targetDurationMinutes,
    this.notes,
  });

  factory AiCoachWorkoutTarget.fromMap(Map<String, dynamic> map) {
    return AiCoachWorkoutTarget(
      category: map['category'] as String? ?? '',
      purpose: map['purpose'] as String? ?? '',
      priority: (map['priority'] as num?)?.toInt() ?? 0,
      preferredDay: map['preferredDay'] as String?,
      targetLoad: (map['targetLoad'] as num?)?.toDouble(),
      targetDistanceKm: (map['targetDistanceKm'] as num?)?.toDouble(),
      targetDurationMinutes: (map['targetDurationMinutes'] as num?)?.toInt(),
      notes: map['notes'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'category': category,
      'purpose': purpose,
      'priority': priority,
      if (preferredDay != null) 'preferredDay': preferredDay,
      if (targetLoad != null) 'targetLoad': targetLoad,
      if (targetDistanceKm != null) 'targetDistanceKm': targetDistanceKm,
      if (targetDurationMinutes != null)
        'targetDurationMinutes': targetDurationMinutes,
      if (notes != null) 'notes': notes,
    };
  }
}

class AiCoachWeeklyDecision {
  final String id;
  final DateTime generatedAt;
  final String sourceModel;
  final String analysis;
  final AiCoachAdjustmentType adjustment;
  final AiCoachWeekType weekType;
  final int targetSessions;
  final double targetVolumeKm;
  final double targetLoad;
  final String primaryFocus;
  final List<String> restrictions;
  final List<AiCoachWorkoutTarget> workoutTargets;

  const AiCoachWeeklyDecision({
    required this.id,
    required this.generatedAt,
    required this.sourceModel,
    required this.analysis,
    required this.adjustment,
    required this.weekType,
    required this.targetSessions,
    required this.targetVolumeKm,
    required this.targetLoad,
    required this.primaryFocus,
    this.restrictions = const [],
    this.workoutTargets = const [],
  });

  factory AiCoachWeeklyDecision.fromMap(Map<String, dynamic> map) {
    return AiCoachWeeklyDecision(
      id: map['id'] as String? ?? '',
      generatedAt: _toDateTime(map['generatedAt']),
      sourceModel: map['sourceModel'] as String? ?? '',
      analysis: map['analysis'] as String? ?? '',
      adjustment:
          AiCoachAdjustmentTypeX.fromValue(map['adjustment'] as String? ?? ''),
      weekType: AiCoachWeekTypeX.fromValue(map['weekType'] as String? ?? ''),
      targetSessions: (map['targetSessions'] as num?)?.toInt() ?? 0,
      targetVolumeKm: (map['targetVolumeKm'] as num?)?.toDouble() ?? 0,
      targetLoad: (map['targetLoad'] as num?)?.toDouble() ?? 0,
      primaryFocus: map['primaryFocus'] as String? ?? '',
      restrictions: List<String>.from(map['restrictions'] as List? ?? const []),
      workoutTargets: (map['workoutTargets'] as List? ?? const [])
          .map((item) =>
              AiCoachWorkoutTarget.fromMap(Map<String, dynamic>.from(item as Map)))
          .toList(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'generatedAt': Timestamp.fromDate(generatedAt),
      'sourceModel': sourceModel,
      'analysis': analysis,
      'adjustment': adjustment.toValue,
      'weekType': weekType.toValue,
      'targetSessions': targetSessions,
      'targetVolumeKm': targetVolumeKm,
      'targetLoad': targetLoad,
      'primaryFocus': primaryFocus,
      'restrictions': restrictions,
      'workoutTargets': workoutTargets.map((item) => item.toMap()).toList(),
    };
  }
}

class AiCoachChatAdjustmentResult {
  final String response;
  final AiCoachWeeklyDecision? decisionOverride;

  const AiCoachChatAdjustmentResult({
    required this.response,
    this.decisionOverride,
  });

  factory AiCoachChatAdjustmentResult.fromMap(Map<String, dynamic> map) {
    return AiCoachChatAdjustmentResult(
      response: map['response'] as String? ?? '',
      decisionOverride: map['decisionOverride'] is Map<String, dynamic>
          ? AiCoachWeeklyDecision.fromMap(
              map['decisionOverride'] as Map<String, dynamic>,
            )
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'response': response,
      if (decisionOverride != null) 'decisionOverride': decisionOverride!.toMap(),
    };
  }
}

class AiCoachAutomationState {
  final String? lastGeneratedCycleId;
  final DateTime? lastGeneratedAt;
  final String? lastGenerationSource;

  const AiCoachAutomationState({
    this.lastGeneratedCycleId,
    this.lastGeneratedAt,
    this.lastGenerationSource,
  });

  factory AiCoachAutomationState.fromMap(Map<String, dynamic> map) {
    return AiCoachAutomationState(
      lastGeneratedCycleId: map['lastGeneratedCycleId'] as String?,
      lastGeneratedAt: map['lastGeneratedAt'] != null
          ? _toDateTime(map['lastGeneratedAt'])
          : null,
      lastGenerationSource: map['lastGenerationSource'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (lastGeneratedCycleId != null)
        'lastGeneratedCycleId': lastGeneratedCycleId,
      if (lastGeneratedAt != null)
        'lastGeneratedAt': Timestamp.fromDate(lastGeneratedAt!),
      if (lastGenerationSource != null)
        'lastGenerationSource': lastGenerationSource,
    };
  }
}

class AiCoachKpiSnapshot {
  final DateTime computedAt;
  final int suggestedCount;
  final int acceptedCount;
  final int editedCount;
  final int rejectedCount;
  final int completedCount;
  final int plannedCount;
  final double acceptanceRate;
  final double completionRate;
  final int replansCount;

  const AiCoachKpiSnapshot({
    required this.computedAt,
    required this.suggestedCount,
    required this.acceptedCount,
    required this.editedCount,
    required this.rejectedCount,
    required this.completedCount,
    required this.plannedCount,
    required this.acceptanceRate,
    required this.completionRate,
    required this.replansCount,
  });

  factory AiCoachKpiSnapshot.fromMap(Map<String, dynamic> map) {
    return AiCoachKpiSnapshot(
      computedAt: _toDateTime(map['computedAt']),
      suggestedCount: (map['suggestedCount'] as num?)?.toInt() ?? 0,
      acceptedCount: (map['acceptedCount'] as num?)?.toInt() ?? 0,
      editedCount: (map['editedCount'] as num?)?.toInt() ?? 0,
      rejectedCount: (map['rejectedCount'] as num?)?.toInt() ?? 0,
      completedCount: (map['completedCount'] as num?)?.toInt() ?? 0,
      plannedCount: (map['plannedCount'] as num?)?.toInt() ?? 0,
      acceptanceRate: (map['acceptanceRate'] as num?)?.toDouble() ?? 0,
      completionRate: (map['completionRate'] as num?)?.toDouble() ?? 0,
      replansCount: (map['replansCount'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'computedAt': Timestamp.fromDate(computedAt),
      'suggestedCount': suggestedCount,
      'acceptedCount': acceptedCount,
      'editedCount': editedCount,
      'rejectedCount': rejectedCount,
      'completedCount': completedCount,
      'plannedCount': plannedCount,
      'acceptanceRate': acceptanceRate,
      'completionRate': completionRate,
      'replansCount': replansCount,
    };
  }
}

DateTime _toDateTime(dynamic value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  if (value is String) {
    final parsed = DateTime.tryParse(value);
    if (parsed != null) return parsed;
  }
  return DateTime.now();
}
