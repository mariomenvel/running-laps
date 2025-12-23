import 'package:flutter/material.dart';
import 'package:running_laps/features/training/data/entrenamiento.dart';
import 'package:running_laps/features/training/data/training_repository.dart';
import 'package:running_laps/features/profile/viewmodels/analytics_view_model.dart';
import 'package:running_laps/features/training/data/tag_manager.dart';
import 'package:running_laps/features/training/data/tag_model.dart';
import 'package:running_laps/core/utils/tag_utils.dart';

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
  
  // NUEVO: Filtro por fechas
  final ValueNotifier<DateTime?> filterStartDate = ValueNotifier<DateTime?>(null);
  final ValueNotifier<DateTime?> filterEndDate = ValueNotifier<DateTime?>(null);

  // NUEVO: Filtro por distancia total (en metros)
  final ValueNotifier<double?> filterMinDist = ValueNotifier<double?>(null);
  final ValueNotifier<double?> filterMaxDist = ValueNotifier<double?>(null);

  // NUEVO: Filtro por series específicas (buscar entrenos que tengan al menos una serie de X distancia)
  final ValueNotifier<int?> filterSeriesDistance = ValueNotifier<int?>(null); // e.g., 400, 1000

  // NUEVO: Búsqueda por texto
  final ValueNotifier<String> searchQuery = ValueNotifier<String>('');
  
  // NUEVO: Filtro por etiquetas (Set para evitar duplicados)
  final ValueNotifier<Set<String>> selectedTags = ValueNotifier<Set<String>>({});

  final TagManager _tagManager = TagManager();
  Map<String, Color> _tagColors = {};

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
      // 1. Cargar entrenos
      final List<Entrenamiento> loaded =
          await _trainingRepo.getTrainings();
      _allTrainings.value = loaded;
      
      // 2. Cargar colores de etiquetas
      try {
        final tags = await _tagManager.getUserTags();
        _tagColors = {
          for (var t in tags) t.name: t.color
        };
      } catch (e) {
        print("Error cargando tags: $e");
        // No bloqueamos la app si fallan los tags
      }

      _applyFilter();
    } catch (e) {
      error.value = 'Error al cargar entrenamientos: ' + e.toString();
    } finally {
      isLoading.value = false;
    }
  }

  Color getColorForTag(String? tagName) {
    if (tagName == null) return Colors.grey.shade300;
    // Buscamos en tags definidos por usuario, si no, generamos uno determinista
    return _tagColors[tagName] ?? TagUtils.getColor(tagName);
  }

  void setFilter(TrainingFilter filter) {
    currentFilter.value = filter;
    // Al seleccionar un filtro rápido, limpiamos los personalizados para evitar confusión
    // O podríamos mantenerlos, pero simplifiquemos por ahora.
    _applyFilter();
  }

  void _applyFilter() {
    final now = DateTime.now();
    List<Entrenamiento> filtered = List.from(_allTrainings.value);

    // 1. FILTRO POR FECHA/TIPO (filtros predefinidos)
    // Solo aplicamos si NO hay rango de fechas personalizado
    if (filterStartDate.value == null && filterEndDate.value == null) {
      switch (currentFilter.value) {
        case TrainingFilter.all:
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
    }

    // 1.5 FILTRO PERSONALIZADO DE FECHAS
    if (filterStartDate.value != null) {
      // Inicio del día
      final start = DateTime(filterStartDate.value!.year, filterStartDate.value!.month, filterStartDate.value!.day);
      filtered = filtered.where((t) => t.fecha.isAfter(start) || t.fecha.isAtSameMomentAs(start)).toList();
    }
    if (filterEndDate.value != null) {
      // Fin del día
       final end = DateTime(filterEndDate.value!.year, filterEndDate.value!.month, filterEndDate.value!.day, 23, 59, 59);
       filtered = filtered.where((t) => t.fecha.isBefore(end) || t.fecha.isAtSameMomentAs(end)).toList();
    }


    // 2. FILTRO POR BÚSQUEDA DE TEXTO (case-insensitive)
    if (searchQuery.value.trim().isNotEmpty) {
      final query = searchQuery.value.trim().toLowerCase();
      filtered = filtered.where((t) {
        return t.titulo.toLowerCase().contains(query);
      }).toList();
    }

    // 3. FILTRO POR ETIQUETAS (mostrar si tiene AL MENOS una de las seleccionadas)
    if (selectedTags.value.isNotEmpty) {
      filtered = filtered.where((t) {
        if (t.tags == null || t.tags!.isEmpty) return false;
        // Retorna true si el entrenamiento tiene al menos una etiqueta seleccionada
        return t.tags!.any((tag) => selectedTags.value.contains(tag));
      }).toList();
    }

    // 4. FILTRO POR DISTANCIA TOTAL
    if (filterMinDist.value != null) {
      filtered = filtered.where((t) => t.distanciaTotalM() >= filterMinDist.value!).toList();
    }
    if (filterMaxDist.value != null) {
      filtered = filtered.where((t) => t.distanciaTotalM() <= filterMaxDist.value!).toList();
    }

    // 5. FILTRO POR DISTANCIA DE SERIES
    if (filterSeriesDistance.value != null) {
      final int targetDist = filterSeriesDistance.value!;
      // Permitimos un margen de error pequeño (e.g. +- 5 metros) por si el GPS no fue exacto
      // o búsqueda exacta. Para ser flexible, digamos +- 2% o exacto si es manual.
      // Asumamos búsqueda aproximada +-10m
      filtered = filtered.where((t) {
        return t.series.any((s) => (s.distanciaM - targetDist).abs() <= 10);
      }).toList();
    }

    trainings.value = filtered;
  }

  // CALENDAR SUPPORT
  
  /// Agrupa los entrenamientos por día (para mostar puntos en el calendario)
  Map<DateTime, List<Entrenamiento>> get eventsByDay {
    final Map<DateTime, List<Entrenamiento>> events = {};
    for (var t in _allTrainings.value) {
      // Normalizar fecha (solo año, mes, día)
      final date = DateTime(t.fecha.year, t.fecha.month, t.fecha.day);
      if (events[date] == null) {
        events[date] = [];
      }
      events[date]!.add(t);
    }
    return events;
  }

  /// Retorna los entrenamientos de un día específico
  List<Entrenamiento> getTrainingsForDay(DateTime day) {
    return _allTrainings.value.where((t) {
      return t.fecha.year == day.year && 
             t.fecha.month == day.month && 
             t.fecha.day == day.day;
    }).toList();
  }


  // CALENDAR SUPPORT ... (existing code)

  /// Data for Analytics
  AnalyticsViewModel get analytics => AnalyticsViewModel(_allTrainings.value, getColorForTag);

  // NUEVOS MÉTODOS PARA BÚSQUEDA Y FILTRO
  
  void setSearchQuery(String query) {
    searchQuery.value = query;
    _applyFilter();
  }

  void toggleTagFilter(String tag) {
    final Set<String> currentTags = Set.from(selectedTags.value);
    if (currentTags.contains(tag)) {
      currentTags.remove(tag);
    } else {
      currentTags.add(tag);
    }
    selectedTags.value = currentTags;
    _applyFilter();
  }

  void setDateRange(DateTime? start, DateTime? end) {
    filterStartDate.value = start;
    filterEndDate.value = end;
    _applyFilter();
  }

  void setDistanceRange(double? minMeters, double? maxMeters) {
    filterMinDist.value = minMeters;
    filterMaxDist.value = maxMeters;
    _applyFilter();
  }

  void setSeriesDistanceFilter(int? distanceMeters) {
    filterSeriesDistance.value = distanceMeters;
    _applyFilter();
  }

  void clearAllFilters() {
    currentFilter.value = TrainingFilter.all;
    searchQuery.value = '';
    selectedTags.value = {};
    filterStartDate.value = null;
    filterEndDate.value = null;
    filterMinDist.value = null;
    filterMaxDist.value = null;
    filterSeriesDistance.value = null;
    _applyFilter();
  }

  int get activeFiltersCount {
    int count = 0;
    if (currentFilter.value != TrainingFilter.all) count++;
    if (searchQuery.value.trim().isNotEmpty) count++;
    if (selectedTags.value.isNotEmpty) count += selectedTags.value.length;
    if (filterStartDate.value != null || filterEndDate.value != null) count++;
    if (filterMinDist.value != null || filterMaxDist.value != null) count++;
    if (filterSeriesDistance.value != null) count++;
    return count;
  }

  void dispose() {
    _allTrainings.dispose();
    trainings.dispose();
    isLoading.dispose();
    error.dispose();
    currentFilter.dispose();
    searchQuery.dispose();
    selectedTags.dispose();
    filterStartDate.dispose();
    filterEndDate.dispose();
    filterMinDist.dispose();
    filterMaxDist.dispose();
    filterSeriesDistance.dispose();
  }

}
