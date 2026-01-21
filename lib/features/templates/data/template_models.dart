
enum AlarmMode { bySeconds, byPace }

enum TemplateBlockType {
  distance,
  time, // Future proofing
  other
}

class TemplateAlerts {
  final bool enabled;
  final String mode; // 'time' | 'pace'
  
  // Params for Time mode
  final int timeMin;
  final double timeSec; // 0.0, 0.5... 59.5
  
  // Params for Pace mode
  final int paceMin;
  final int paceSec;
  final int segmentDistance; // e.g. 400m
  
  TemplateAlerts({
    required this.enabled,
    this.mode = 'time',
    this.timeMin = 0,
    this.timeSec = 0,
    this.paceMin = 4,
    this.paceSec = 0,
    this.segmentDistance = 300,
  });

  Map<String, dynamic> toMap() {
    return {
      'enabled': enabled,
      'mode': mode,
      'timeMin': timeMin,
      'timeSec': timeSec,
      'paceMin': paceMin,
      'paceSec': paceSec,
      'segmentDistance': segmentDistance,
    };
  }

  factory TemplateAlerts.fromMap(Map<String, dynamic> map) {
    return TemplateAlerts(
      enabled: map['enabled'] ?? false,
      mode: map['mode'] ?? 'time',
      timeMin: (map['timeMin'] as num?)?.toInt() ?? 0,
      timeSec: (map['timeSec'] as num?)?.toDouble() ?? 0.0,
      paceMin: (map['paceMin'] as num?)?.toInt() ?? 4,
      paceSec: (map['paceSec'] as num?)?.toInt() ?? 0,
      segmentDistance: (map['segmentDistance'] as num?)?.toInt() ?? 300,
    );
  }
}

class TemplateBlock {
  final String id;
  final int order;
  final TemplateBlockType type;
  final int value; // Meters for distance, Seconds for time
  final int restSeconds;
  final TemplateAlerts alerts;

  TemplateBlock({
    required this.id,
    required this.order,
    required this.type,
    required this.value,
    required this.restSeconds,
    required this.alerts,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'order': order,
      'type': type.name, // 'distance', 'time'
      'value': value,
      'restSeconds': restSeconds,
      'alerts': alerts.toMap(),
    };
  }

  factory TemplateBlock.fromMap(Map<String, dynamic> map) {
    return TemplateBlock(
      id: map['id'] ?? '',
      order: (map['order'] as num?)?.toInt() ?? 0,
      type: TemplateBlockType.values.firstWhere(
            (e) => e.name == map['type'],
        orElse: () => TemplateBlockType.distance,
      ),
      value: (map['value'] as num?)?.toInt() ?? 0,
      restSeconds: (map['restSeconds'] as num?)?.toInt() ?? 0,
      alerts: map['alerts'] != null
          ? TemplateAlerts.fromMap(map['alerts'])
          : TemplateAlerts(enabled: false),
    );
  }
}

class TrainingTemplate {
  final String id;
  final String name;
  final List<TemplateBlock> blocks;
  final DateTime createdAt;
  final DateTime updatedAt;

  TrainingTemplate({
    required this.id,
    required this.name,
    required this.blocks,
    required this.createdAt,
    required this.updatedAt,
  });

  TrainingTemplate copyWith({
    String? id,
    String? name,
    List<TemplateBlock>? blocks,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return TrainingTemplate(
      id: id ?? this.id,
      name: name ?? this.name,
      blocks: blocks ?? this.blocks,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'blocks': blocks.map((b) => b.toMap()).toList(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory TrainingTemplate.fromMap(Map<String, dynamic> map, {required String id}) {
    return TrainingTemplate(
      id: id,
      name: map['name'] ?? '',
      blocks: (map['blocks'] as List<dynamic>?)
          ?.map((e) => TemplateBlock.fromMap(e))
          .toList() ??
          [],
      createdAt: DateTime.tryParse(map['createdAt'] ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(map['updatedAt'] ?? '') ?? DateTime.now(),
    );
  }
}

class TemplateSource {
  final String type; // 'template' | 'free'
  final String? templateId;
  final TrainingTemplate? templateSnapshot;

  TemplateSource({
    required this.type,
    this.templateId,
    this.templateSnapshot,
  });

  Map<String, dynamic> toMap() {
    return {
      'type': type,
      'templateId': templateId,
      'templateSnapshot': templateSnapshot?.toMap(),
    };
  }

  factory TemplateSource.fromMap(Map<String, dynamic> map) {
    return TemplateSource(
      type: map['type'] ?? 'free',
      templateId: map['templateId'],
      templateSnapshot: map['templateSnapshot'] != null
          ? TrainingTemplate.fromMap(map['templateSnapshot'] as Map<String, dynamic>,
              id: map['templateId'] ?? 'snapshot')
          : null,
    );
  }
}
