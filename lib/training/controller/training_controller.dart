import '../domain/entrenamiento.dart';
import '../data/training_repository.dart';

class TrainingController {
  final TrainingRepository _repo = TrainingRepository();

  Future<String> guardarEntrenamiento(Entrenamiento entrenamiento) async {
    //Validar los datos del entrenamiento
    if (entrenamiento.series.isEmpty) {
      throw Exception('El entrenamiento debe tener al menos una serie.');
    }
    //Guardar el entrenamiento usando el repositorio
    final String entrenamientoId =
        await _repo.createTraining(entrenamiento);
    return entrenamientoId;
  }
}