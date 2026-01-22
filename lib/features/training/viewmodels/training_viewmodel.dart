import '../data/entrenamiento.dart';
import '../data/serie.dart';
import '../data/training_repository.dart';
import '../../templates/data/template_models.dart';
import '../../../../core/services/gps_service.dart';
import '../services/training_analysis_service.dart';

class TrainingViewModel {
  TrainingRepository _repo;

  // Estado de dominio
  final List<Serie> _series = <Serie>[];
  bool _gpsOn = false;
  
  // Template info
  TemplateSource? _source;
  List<TemplateBlock> _plannedBlocks = [];

  TrainingViewModel({TrainingRepository? repo}) : _repo = TrainingRepository() {
    if (repo != null) {
      _repo = repo;
    }
  }

  // ------- GETTERS -------

  List<Serie> get series {
    return List<Serie>.unmodifiable(_series);
  }

  bool get gpsOn {
    return _gpsOn;
  }
  
  TemplateSource? get source => _source;
  List<TemplateBlock> get plannedBlocks => List.unmodifiable(_plannedBlocks);

  bool get tieneSeries {
    return _series.isNotEmpty;
  }

  // ------- MUTADORES DE ESTADO -------

  void setGpsOn(bool value) {
    _gpsOn = value;
  }
  
  void loadTemplate(TrainingTemplate template) {
    _source = TemplateSource(
      type: 'template',
      templateId: template.id,
      templateSnapshot: template, // Snapshot at start
    );
    _plannedBlocks = List.from(template.blocks);
  }
  
  void clearTemplate() {
    _source = null;
    _plannedBlocks = [];
  }

  void addSerie(Serie serie) {
    _series.add(serie);
  }

  void clearSeries() {
    _series.clear();
  }

  void removeSerieAt(int index) {
    if (index >= 0 && index < _series.length) {
      _series.removeAt(index);
    }
  }

  // ------- VALIDACIONES -------

  /// Devuelve un mensaje de error o null si todo está correcto.
  String? validarDistanciaYDescanso(String distanciaStr, String descansoStr) {
    final String d = distanciaStr.trim();
    final String r = descansoStr.trim();

    if (d.isEmpty || r.isEmpty) {
      return 'Por favor, introduce distancia y descanso.';
    }

    int distanciaNum;
    int descansoNum;
    try {
      distanciaNum = int.parse(d);
      descansoNum = int.parse(r);
    } on FormatException {
      return 'Usa solo números en distancia y descanso.';
    }

    if (distanciaNum <= 0 || descansoNum < 0) {
      return 'La distancia debe ser > 0 y el descanso ≥ 0.';
    }

    return null; // todo OK
  }

  // ------- GUARDAR ENTRENAMIENTO -------

  // ------- CONTROL DE SESIÓN (Continuous & Structured) -------

  void startContinuousSession() {
    clearSeries();
    clearTemplate();
    _source = TemplateSource(type: 'continuous');
    _gpsOn = true; 
    // No añadimos serie inicial, se generará al finalizar
  }
  
  // Wrapper para guardar con lógica de negocio adicional (análisis, GPS points)
  Future<String> finishSession(String titulo, {
      required double elapsedSeconds, 
      required double totalDistanceMeters,
      int? rpe,
      List<GpsPoint>? recordedPoints, 
      List<String>? tags
  }) async {
    
    List<Serie> finalSeries = List.from(_series);
    List<GpsPoint> finalPoints = recordedPoints ?? [];
    AnalysisResult? analysisResult;

    // 1. Si es carrera continua, generamos la serie única
    if (_source?.type == 'continuous') {
      final serie = Serie(
        distanciaM: totalDistanceMeters.round(),
        tiempoSec: elapsedSeconds,
        descansoSec: 0,
        rpe: (rpe ?? 5.0).toDouble(), // Default to 5.0 (neutral) instead of 0
      );
      finalSeries = [serie];
    }

    // 2. Si hubo GPS y puntos, analizamos
    if (_gpsOn && finalPoints.isNotEmpty) {
      // Calcular Best Splits si hubo suficiente distancia
      if (totalDistanceMeters >= 1000) {
         analysisResult = TrainingAnalysisService.calculateBestSplits(finalPoints);
      }
    }

    if (finalSeries.isEmpty) {
      throw Exception('El entrenamiento debe tener al menos una serie (o ser carrera continua).');
    }

    final Entrenamiento entrenamiento = Entrenamiento(
      titulo: titulo,
      fecha: DateTime.now(),
      gps: _gpsOn,
      series: finalSeries,
      tags: tags,
      source: _source,
      trackPoints: finalPoints,
      analysis: analysisResult,
    );

    final String entrenamientoId = await _repo.createTraining(entrenamiento);
    return entrenamientoId;
  }

  // ------- GUARDAR ENTRENAMIENTO (Legacy / Manual) -------

  Future<String> guardarEntrenamiento(String titulo, {List<String>? tags, List<GpsPoint>? recordedPoints}) async {
    // Redirige a finishSession con valores por defecto para mantener compatibilidad
    // For continuous runs, we often already have a serie in _series with the correct RPE
    int? detectedRpe;
    if (_series.isNotEmpty) {
      detectedRpe = _series.first.rpe.round();
    }

    return finishSession(
        titulo, 
        elapsedSeconds: tiempoTotalSeries(), 
        totalDistanceMeters: distanciaTotalSeries().toDouble(),
        rpe: detectedRpe,
        tags: tags,
        recordedPoints: recordedPoints,
    );
  }
  
  // Helpers para legacy calls
  double tiempoTotalSeries() => _series.fold(0, (sum, s) => sum + s.tiempoSec);
  int distanciaTotalSeries() => _series.fold(0, (sum, s) => sum + s.distanciaM);
}

