// ============================================================
// Clase: TrainingController
// ------------------------------------------------------------
// Controlador que gestiona la lógica de creación de entrenamientos.
//
// Su papel dentro de la arquitectura (MVVM / MVC adaptado):
//   - Recibir los datos desde la interfaz (UI).
//   - Validar que la información sea coherente (por ejemplo, que haya series).
//   - Delegar la persistencia de datos al TrainingRepository.
//   - Devolver el ID del entrenamiento creado (para futuras operaciones).
// ------------------------------------------------------------
// No se comunica directamente con Firebase ni con Firestore.
// ============================================================

import '../data/entrenamiento.dart'; // Modelo de dominio (datos del entrenamiento)
import '../data/training_repository.dart'; // Acceso a Firestore

class TrainingController {
  // Instancia privada del repositorio
  final TrainingRepository _repo = TrainingRepository();

  // ------------------------------------------------------------
  // Método: guardarEntrenamiento
  // ------------------------------------------------------------
  // Guarda un nuevo entrenamiento en Firestore.
  //
  // Parámetros:
  //   entrenamiento → objeto Entrenamiento completo con sus Series.
  //
  // Flujo:
  //   1️⃣ Valida que el entrenamiento contenga al menos una serie.
  //   2️⃣ Llama al repositorio para guardar los datos en Firestore.
  //   3️⃣ Devuelve el ID del documento creado (útil para navegación o confirmación).
  //
  // En caso de error, lanza una Exception (por ejemplo, si no hay usuario o no hay series).
  Future<String> guardarEntrenamiento(Entrenamiento entrenamiento) async {
    // --- Validación básica ---
    if (entrenamiento.series.isEmpty) {
      throw Exception('El entrenamiento debe tener al menos una serie.');
    }

    // --- Guardado en Firestore a través del repositorio ---
    final String entrenamientoId = await _repo.createTraining(entrenamiento);

    // Devuelve el ID autogenerado
    return entrenamientoId;
  }
}
