import 'package:flutter/material.dart';
import 'package:running_laps/features/training/data/entrenamiento.dart';
import 'package:running_laps/features/training/data/training_repository.dart';

class ProfileController {
  TrainingRepository _trainingRepo;

  final ValueNotifier<List<Entrenamiento>> trainings =
      ValueNotifier<List<Entrenamiento>>(<Entrenamiento>[]);
  final ValueNotifier<bool> isLoading = ValueNotifier<bool>(false);
  final ValueNotifier<String?> error = ValueNotifier<String?>(null);

  ProfileController({TrainingRepository? trainingRepo})
      : _trainingRepo = TrainingRepository() {
    if (trainingRepo != null) {
      _trainingRepo = trainingRepo;
    }
  }

  Future<void> loadTrainings() async {
    if (isLoading.value) {
      return;
    }

    error.value = null;
    isLoading.value = true;

    try {
      final List<Entrenamiento> loaded =
          await _trainingRepo.getTrainings();
      trainings.value = loaded;
    } catch (e) {
      error.value = 'Error al cargar entrenamientos: ' + e.toString();
    } finally {
      isLoading.value = false;
    }
  }

  void dispose() {
    trainings.dispose();
    isLoading.dispose();
    error.dispose();
  }
}
