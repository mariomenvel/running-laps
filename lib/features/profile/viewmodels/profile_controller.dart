import 'package:flutter/material.dart';
import 'package:running_laps/features/training/data/entrenamiento.dart';
import 'package:running_laps/features/training/data/training_repository.dart';

enum TrainingFilter {
  all,
  last7Days,
  last30Days,
  thisMonth,
  longRuns,
  highIntensity,
}

class ProfileController {
  TrainingRepository _trainingRepo;

  final ValueNotifier<List<Entrenamiento>> _allTrainings =
      ValueNotifier<List<Entrenamiento>>(<Entrenamiento>[]);
  final ValueNotifier<List<Entrenamiento>> trainings =
      ValueNotifier<List<Entrenamiento>>(<Entrenamiento>[]);
  final ValueNotifier<bool> isLoading = ValueNotifier<bool>(false);
  final ValueNotifier<String?> error = ValueNotifier<String?>(null);
  final ValueNotifier<TrainingFilter> currentFilter =
      ValueNotifier<TrainingFilter>(TrainingFilter.all);

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
      _allTrainings.value = loaded;
      _applyFilter();
    } catch (e) {
      error.value = 'Error al cargar entrenamientos: ' + e.toString();
    } finally {
      isLoading.value = false;
    }
  }

  void setFilter(TrainingFilter filter) {
    currentFilter.value = filter;
    _applyFilter();
  }

  void _applyFilter() {
    final now = DateTime.now();
    List<Entrenamiento> filtered = List.from(_allTrainings.value);

    switch (currentFilter.value) {
      case TrainingFilter.all:
        // No filter
        break;
      case TrainingFilter.last7Days:
        final cutoff = now.subtract(const Duration(days: 7));
        filtered = filtered.where((t) => t.fecha.isAfter(cutoff)).toList();
        break;
      case TrainingFilter.last30Days:
        final cutoff = now.subtract(const Duration(days: 30));
        filtered = filtered.where((t) => t.fecha.isAfter(cutoff)).toList();
        break;
      case TrainingFilter.thisMonth:
        filtered = filtered
            .where((t) => t.fecha.year == now.year && t.fecha.month == now.month)
            .toList();
        break;
      case TrainingFilter.longRuns:
        filtered = filtered.where((t) => t.distanciaTotalM() > 10000).toList();
        break;
      case TrainingFilter.highIntensity:
        filtered = filtered.where((t) => t.rpePromedio() > 7.0).toList();
        break;
    }

    trainings.value = filtered;
  }

  void dispose() {
    _allTrainings.dispose();
    trainings.dispose();
    isLoading.dispose();
    error.dispose();
    currentFilter.dispose();
  }
}
