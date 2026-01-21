import '../data/entrenamiento.dart';
import '../data/serie.dart';
import '../data/training_repository.dart';
import '../../templates/data/template_models.dart';

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

  Future<String> guardarEntrenamiento(String titulo, {List<String>? tags}) async {
    if (_series.isEmpty) {
      throw Exception('El entrenamiento debe tener al menos una serie.');
    }

    final Entrenamiento entrenamiento = Entrenamiento(
      titulo: titulo,
      fecha: DateTime.now(),
      gps: _gpsOn,
      series: List<Serie>.from(_series),
      tags: tags,
      source: _source,
    );

    final String entrenamientoId = await _repo.createTraining(entrenamiento);
    return entrenamientoId;
  }
}

