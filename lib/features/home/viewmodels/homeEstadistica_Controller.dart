// Archivo: lib/features/home/viewmodels/homeEstadistica_Controller.dart

import 'package:flutter/material.dart';
import '../data/homeEstadistica_repository.dart';

class HomeEstadisticaController {
  final HomeEstadisticaRepository _repository;

  HomeEstadisticaController({HomeEstadisticaRepository? repository})
    : _repository = repository ?? HomeEstadisticaRepository() {
    selectedMetric.addListener(_loadData);
    selectedRange.addListener(_loadData);
    _loadData();
  }

  final ValueNotifier<HomeMetric> selectedMetric = ValueNotifier<HomeMetric>(
    HomeMetric.ritmoMedio,
  );

  final ValueNotifier<TimeRange> selectedRange = ValueNotifier<TimeRange>(
    TimeRange.oneWeek,
  );

  final ValueNotifier<List<DailyMetric>> graphData =
      ValueNotifier<List<DailyMetric>>([]);

  final ValueNotifier<bool> isLoading = ValueNotifier<bool>(false);
  final ValueNotifier<String?> error = ValueNotifier<String?>(null);

  Future<void> _loadData() async {
    error.value = null;
    if (isLoading.value) return;
    isLoading.value = true;

    try {
      final List<DailyMetric> data = await _repository.getMetricsForGraph(
        range: selectedRange.value,
        metric: selectedMetric.value,
      );
      graphData.value = data;
    } catch (e) {
      String errorMessage = e.toString();
      if (errorMessage.contains('Exception:')) {
        errorMessage = errorMessage.split('Exception:')[1].trim();
      }
      error.value = errorMessage;
    } finally {
      isLoading.value = false;
    }
  }

  void setMetric(HomeMetric metric) {
    if (selectedMetric.value != metric) {
      selectedMetric.value = metric;
    }
  }

  void setRange(TimeRange range) {
    if (selectedRange.value != range) {
      selectedRange.value = range;
    }
  }

  void dispose() {
    selectedMetric.removeListener(_loadData);
    selectedRange.removeListener(_loadData);
    selectedMetric.dispose();
    selectedRange.dispose();
    graphData.dispose();
    isLoading.dispose();
    error.dispose();
  }
}
