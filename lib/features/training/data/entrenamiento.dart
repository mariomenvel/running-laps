import 'serie.dart';
import '../../templates/data/template_models.dart';
import '../../../../core/services/gps_service.dart';
import '../services/training_analysis_service.dart';

class Entrenamiento {
  final String? id;  // ID del documento en Firestore (opcional para compatibilidad)
  final String titulo;
  final DateTime fecha;
  final bool gps;
  final List<Serie> series;
  final List<String>? tags; // Etiquetas del entrenamiento
  final TemplateSource? source;
  
  // Campos para analytics
  final String? weekKey;  // Semana ISO: "2025-W52"
  final double? load;     // Carga de entrenamiento: RPE * duración_min
  final DateTime? createdAt;
  final DateTime? updatedAt;
  
  // Campos para persistencia de GPS y Análisis
  final List<GpsPoint> trackPoints;
  final AnalysisResult? analysis;

  // Entrenamiento manual (sin GPS)
  final bool isManual;
  final String? notas;

  // FC media de toda la sesión (media de fcMedia de las series)
  final double? fcMediaSesion;

  Entrenamiento({
    this.id,
    required this.titulo,
    required this.fecha,
    required this.gps,
    required this.series,
    this.tags,
    this.weekKey,
    this.load,
    this.createdAt,
    this.updatedAt,
    this.source,
    this.trackPoints = const [],
    this.analysis,
    this.isManual = false,
    this.notas,
    this.fcMediaSesion,
  });

  Entrenamiento copyWith({
    String? id,
    String? titulo,
    DateTime? fecha,
    bool? gps,
    List<Serie>? series,
    List<String>? tags,
    String? weekKey,
    double? load,
    DateTime? createdAt,
    DateTime? updatedAt,
    TemplateSource? source,
    List<GpsPoint>? trackPoints,
    AnalysisResult? analysis,
    bool? isManual,
    String? notas,
    Object? fcMediaSesion = _entrSentinel,
  }) {
    return Entrenamiento(
      id: id ?? this.id,
      titulo: titulo ?? this.titulo,
      fecha: fecha ?? this.fecha,
      gps: gps ?? this.gps,
      series: series ?? this.series,
      tags: tags ?? this.tags,
      weekKey: weekKey ?? this.weekKey,
      load: load ?? this.load,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      source: source ?? this.source,
      trackPoints: trackPoints ?? this.trackPoints,
      analysis: analysis ?? this.analysis,
      isManual: isManual ?? this.isManual,
      notas: notas ?? this.notas,
      fcMediaSesion: identical(fcMediaSesion, _entrSentinel)
          ? this.fcMediaSesion : fcMediaSesion as double?,
    );
  }

  int distanciaTotalM() {
    int total = 0;
    for (var serie in series) {
      total += serie.distanciaM;
    }
    return total;
  }

  double tiempoTotalSec() {
    double total = 0;
    for (var serie in series) {
      total += serie.tiempoSec;
    }
    return total;
  }

  double rpePromedio() {
    if (series.isEmpty) return 0;
    double total = 0;
    for (var serie in series) {
      total += serie.rpe;
    }
    return total / series.length;
  }

  int ritmoMedioSecPorKm() {
    final int distanciaM = distanciaTotalM();
    final double tiempoSec = tiempoTotalSec();
    if (distanciaM <= 0) {
      throw StateError('distanciaTotalM debe ser > 0 para calcular ritmo');
    }
    final double km = distanciaM / 1000.0;
    final double secPerKm = tiempoSec / km;
    return secPerKm.round();
  }

  String ritmoMedioTexto() {
    final int secKm = ritmoMedioSecPorKm();
    final int mm = secKm ~/ 60;
    final int ss = secKm % 60;
    final String ss2 = ss < 10 ? '0' + ss.toString() : ss.toString();
    return mm.toString() + ':' + ss2 + ' /km';
  }

  Map<String, dynamic> toMap() {
    final List<Map<String, dynamic>> listaSeries = <Map<String, dynamic>>[];
    for (int i = 0; i < series.length; i = i + 1) {
      listaSeries.add(series[i].toMap());
    }

    final Map<String, dynamic> base = <String, dynamic>{
      'titulo': titulo,
      'fecha': fecha.toIso8601String(),
      'gps': gps,
      'series': listaSeries,
      // Derivadas (opcional pero útil para consultas rápidas):
      'distanciaTotalM': distanciaTotalM(),
      'tiempoTotalSec': tiempoTotalSec(),
      'rpePromedio': rpePromedio(),
    };

    // Si quieres guardar también el ritmo medio (opcional):
    try {
      base['ritmoMedioSecKm'] = ritmoMedioSecPorKm();
    } catch (_) {
      base['ritmoMedioSecKm'] = null; // sin distancia no hay ritmo
    }

    // Guardar tags si existen
    if (tags != null) {
      base['tags'] = tags;
    }
    
    // Guardar campos de analytics
    if (weekKey != null) {
      base['weekKey'] = weekKey;
    }
    if (load != null) {
      base['load'] = load;
    }
    if (createdAt != null) {
      base['createdAt'] = createdAt!.toIso8601String();
    }
    if (updatedAt != null) {
      base['updatedAt'] = updatedAt!.toIso8601String();
    }
    if (source != null) {
      base['source'] = source!.toMap();
    }

    // Guardar trackPoints y analysis
    if (trackPoints.isNotEmpty) {
      base['trackPoints'] = trackPoints.map((p) => p.toMap()).toList();
    }
    if (analysis != null) {
      base['analysis'] = analysis!.toMap();
    }
    if (isManual) {
      base['isManual'] = true;
    }
    if (notas != null) {
      base['notas'] = notas;
    }
    if (fcMediaSesion != null) {
      base['fcMediaSesion'] = fcMediaSesion;
    }

    return base;
  }

  static Entrenamiento fromMap(Map<String, dynamic> map, {String? id}) {
    final List<dynamic> rawSeries = map['series'] as List<dynamic>;
    final List<Serie> cargadas = <Serie>[];
    for (int i = 0; i < rawSeries.length; i = i + 1) {
      final Map<String, dynamic> m = rawSeries[i] as Map<String, dynamic>;
      cargadas.add(Serie.fromMap(m));
    }

    final dynamic f = map['fecha'];
    final DateTime fechaParsed = _parseFechaFlexible(f);

    // Leer tags si existen (compatibilidad con entrenamientos antiguos)
    List<String>? tagsList;
    if (map.containsKey('tags') && map['tags'] != null) {
      tagsList = List<String>.from(map['tags'] as List);
    }
    
    // Leer campos de analytics (compatibilidad)
    String? weekKeyValue;
    if (map.containsKey('weekKey')) {
      weekKeyValue = map['weekKey'] as String?;
    }
    
    double? loadValue;
    if (map.containsKey('load')) {
      loadValue = (map['load'] as num?)?.toDouble();
    }
    
    DateTime? createdAtValue;
    if (map.containsKey('createdAt') && map['createdAt'] != null) {
      createdAtValue = _parseFechaFlexible(map['createdAt']);
    }
    
    DateTime? updatedAtValue;
    if (map.containsKey('updatedAt') && map['updatedAt'] != null) {
      updatedAtValue = _parseFechaFlexible(map['updatedAt']);
    }

    // Parse trackPoints
    List<GpsPoint> loadedPoints = [];
    if (map['trackPoints'] != null) {
      final tpList = map['trackPoints'] as List;
      loadedPoints = tpList.map((e) => GpsPoint.fromMap(e)).toList();
    }

    // Parse analysis
    AnalysisResult? loadedAnalysis;
    if (map['analysis'] != null) {
      loadedAnalysis = AnalysisResult.fromMap(map['analysis']);
    }

    return Entrenamiento(
      id: id,  // Asignar el ID del documento
      titulo: map['titulo'] as String,
      fecha: fechaParsed,
      gps: map['gps'] as bool,
      series: cargadas,
      tags: tagsList,
      weekKey: weekKeyValue,
      load: loadValue,
      createdAt: createdAtValue,
      updatedAt: updatedAtValue,
      source: map['source'] is Map ? TemplateSource.fromMap(map['source'] as Map<String, dynamic>) : null,
      trackPoints: loadedPoints,
      analysis: loadedAnalysis,
      isManual: map['isManual'] as bool? ?? false,
      notas: map['notas'] as String?,
      fcMediaSesion: (map['fcMediaSesion'] as num?)?.toDouble(),
    );
  }

  static const Object _entrSentinel = Object();

  // Acepta ISO-8601 (String) o miliSecundos epoch (int).
  static DateTime _parseFechaFlexible(dynamic v) {
    if (v is String) {
      return DateTime.parse(v);
    }
    if (v is int) {
      return DateTime.fromMillisecondsSinceEpoch(v);
    }
    // Si más adelante usas Timestamp de Firestore, adapta aquí.
    // Por ahora, fallback:
    return DateTime.now();
  }
}

