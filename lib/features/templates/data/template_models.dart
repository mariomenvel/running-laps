
enum AlarmMode { bySeconds, byPace }

enum TemplateBlockType {
  distance,
  time, // Future proofing
  other
}

/// Taxonomía de tipos de sesión (11 categorías).
enum SessionCategory {
  regenerativo,
  rodajeBase,
  tempo,
  fartlek,
  seriesLargas,
  seriesCortas,
  seriesCuestas,
  seriesMixtas,
  competicion,
  test,
  gimnasiofuerza,
}

extension SessionCategoryX on SessionCategory {
  String get label {
    switch (this) {
      case SessionCategory.regenerativo:    return 'Regenerativo';
      case SessionCategory.rodajeBase:      return 'Rodaje base (Z2)';
      case SessionCategory.tempo:           return 'Tempo (Z3)';
      case SessionCategory.fartlek:         return 'Fartlek';
      case SessionCategory.seriesLargas:    return 'Series largas';
      case SessionCategory.seriesCortas:    return 'Series cortas';
      case SessionCategory.seriesCuestas:   return 'Series en cuestas';
      case SessionCategory.seriesMixtas:    return 'Series mixtas';
      case SessionCategory.competicion:     return 'Competición';
      case SessionCategory.test:            return 'Test';
      case SessionCategory.gimnasiofuerza:  return 'Gimnasio / fuerza';
    }
  }

  String get toValue {
    switch (this) {
      case SessionCategory.regenerativo:    return 'regenerativo';
      case SessionCategory.rodajeBase:      return 'rodaje_base';
      case SessionCategory.tempo:           return 'tempo';
      case SessionCategory.fartlek:         return 'fartlek';
      case SessionCategory.seriesLargas:    return 'series_largas';
      case SessionCategory.seriesCortas:    return 'series_cortas';
      case SessionCategory.seriesCuestas:   return 'series_cuestas';
      case SessionCategory.seriesMixtas:    return 'series_mixtas';
      case SessionCategory.competicion:     return 'competicion';
      case SessionCategory.test:            return 'test';
      case SessionCategory.gimnasiofuerza:  return 'gimnasio_fuerza';
    }
  }

  static SessionCategory fromValue(String v) {
    switch (v) {
      case 'regenerativo':    return SessionCategory.regenerativo;
      case 'rodaje_base':     return SessionCategory.rodajeBase;
      case 'tempo':           return SessionCategory.tempo;
      case 'fartlek':         return SessionCategory.fartlek;
      case 'series_largas':   return SessionCategory.seriesLargas;
      case 'series_cortas':   return SessionCategory.seriesCortas;
      case 'series_cuestas':  return SessionCategory.seriesCuestas;
      case 'series_mixtas':   return SessionCategory.seriesMixtas;
      case 'competicion':     return SessionCategory.competicion;
      case 'test':            return SessionCategory.test;
      case 'gimnasio_fuerza': return SessionCategory.gimnasiofuerza;
      default:                return SessionCategory.rodajeBase;
    }
  }
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

  // Objetivos por bloque (nullable — aditivos, no rompen documentos existentes)
  final int? targetPaceMin;
  final int? targetPaceSec;
  final double? targetRpe;   // 1.0–10.0
  final int? targetZone;     // 1–5

  TemplateBlock({
    required this.id,
    required this.order,
    required this.type,
    required this.value,
    required this.restSeconds,
    required this.alerts,
    this.targetPaceMin,
    this.targetPaceSec,
    this.targetRpe,
    this.targetZone,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'order': order,
      'type': type.name, // 'distance', 'time'
      'value': value,
      'restSeconds': restSeconds,
      'alerts': alerts.toMap(),
      if (targetPaceMin != null) 'targetPaceMin': targetPaceMin,
      if (targetPaceSec != null) 'targetPaceSec': targetPaceSec,
      if (targetRpe != null) 'targetRpe': targetRpe,
      if (targetZone != null) 'targetZone': targetZone,
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
      targetPaceMin: (map['targetPaceMin'] as num?)?.toInt(),
      targetPaceSec: (map['targetPaceSec'] as num?)?.toInt(),
      targetRpe:     (map['targetRpe'] as num?)?.toDouble(),
      targetZone:    (map['targetZone'] as num?)?.toInt(),
    );
  }

  TemplateBlock copyWith({
    String? id,
    int? order,
    TemplateBlockType? type,
    int? value,
    int? restSeconds,
    TemplateAlerts? alerts,
    Object? targetPaceMin = _sentinel,
    Object? targetPaceSec = _sentinel,
    Object? targetRpe     = _sentinel,
    Object? targetZone    = _sentinel,
  }) {
    return TemplateBlock(
      id:           id           ?? this.id,
      order:        order        ?? this.order,
      type:         type         ?? this.type,
      value:        value        ?? this.value,
      restSeconds:  restSeconds  ?? this.restSeconds,
      alerts:       alerts       ?? this.alerts,
      targetPaceMin: identical(targetPaceMin, _sentinel) ? this.targetPaceMin : targetPaceMin as int?,
      targetPaceSec: identical(targetPaceSec, _sentinel) ? this.targetPaceSec : targetPaceSec as int?,
      targetRpe:     identical(targetRpe,     _sentinel) ? this.targetRpe     : targetRpe     as double?,
      targetZone:    identical(targetZone,    _sentinel) ? this.targetZone    : targetZone    as int?,
    );
  }
}

class TrainingTemplate {
  final String id;
  final String name;
  final List<TemplateBlock> blocks;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int colorValue;

  // Estructura de sesión completa (nullable — aditivos)
  final String? warmupTemplateId;    // referencia a plantilla isWarmupCooldown: true
  final String? cooldownTemplateId;  // ídem
  final String? category;            // SessionCategory.toValue()
  final bool isWarmupCooldown;       // true si esta plantilla es calentamiento/vuelta a la calma

  TrainingTemplate({
    required this.id,
    required this.name,
    required this.blocks,
    required this.createdAt,
    required this.updatedAt,
    this.colorValue = 0xFF9C27B0, // Default Tema.brandPurple
    this.warmupTemplateId,
    this.cooldownTemplateId,
    this.category,
    this.isWarmupCooldown = false,
  });

  TrainingTemplate copyWith({
    String? id,
    String? name,
    List<TemplateBlock>? blocks,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? colorValue,
    bool? isWarmupCooldown,
    Object? warmupTemplateId   = _sentinel,
    Object? cooldownTemplateId = _sentinel,
    Object? category           = _sentinel,
  }) {
    return TrainingTemplate(
      id:           id          ?? this.id,
      name:         name        ?? this.name,
      blocks:       blocks      ?? this.blocks,
      createdAt:    createdAt   ?? this.createdAt,
      updatedAt:    updatedAt   ?? this.updatedAt,
      colorValue:   colorValue  ?? this.colorValue,
      isWarmupCooldown: isWarmupCooldown ?? this.isWarmupCooldown,
      warmupTemplateId:   identical(warmupTemplateId,   _sentinel) ? this.warmupTemplateId   : warmupTemplateId   as String?,
      cooldownTemplateId: identical(cooldownTemplateId, _sentinel) ? this.cooldownTemplateId : cooldownTemplateId as String?,
      category:           identical(category,           _sentinel) ? this.category           : category           as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'blocks': blocks.map((b) => b.toMap()).toList(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'colorValue': colorValue,
      'isWarmupCooldown': isWarmupCooldown,
      if (warmupTemplateId != null)   'warmupTemplateId':   warmupTemplateId,
      if (cooldownTemplateId != null) 'cooldownTemplateId': cooldownTemplateId,
      if (category != null)           'category':           category,
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
      colorValue: map['colorValue'] as int? ?? 0xFF9C27B0,
      isWarmupCooldown:   map['isWarmupCooldown']   as bool?   ?? false,
      warmupTemplateId:   map['warmupTemplateId']   as String?,
      cooldownTemplateId: map['cooldownTemplateId'] as String?,
      category:           map['category']           as String?,
    );
  }
}

class TemplateSource {
  final String type; // 'template' | 'free' | 'continuous'
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

// Sentinel para distinguir null explícito de "no pasado" en copyWith
const Object _sentinel = Object();
