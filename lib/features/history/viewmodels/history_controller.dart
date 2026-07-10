import 'dart:async';

import 'package:running_laps/core/theme/app_colors.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:running_laps/features/training/data/entrenamiento.dart';
import 'package:running_laps/features/training/data/training_repository.dart';
import 'package:running_laps/features/history/viewmodels/history_analytics_view_model.dart';
import 'package:running_laps/features/training/data/tag_manager.dart';
import 'package:running_laps/core/utils/tag_utils.dart';

enum TrainingFilter {
  all,
  last7Days,
  last30Days,
  thisMonth,
  longRuns,
  highIntensity,
}

class HistoryController {
  static final needsReload = ValueNotifier<int>(0);

  bool _disposed = false;

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

  // ── Pagination state ──────────────────────────────────────────────
  DocumentSnapshot? _lastDocument;
  bool _hasMore = true;
  bool _isLoadingMore = false;

  bool get hasMore => _hasMore;
  bool get isLoadingMore => _isLoadingMore;

  final TagManager _tagManager = TagManager();
  Map<String, Color> _tagColors = {};

  HistoryController({TrainingRepository? trainingRepo})
      : _trainingRepo = TrainingRepository() {
    if (trainingRepo != null) {
      _trainingRepo = trainingRepo;
    }
  }

  String? _resolveUid() => FirebaseAuth.instance.currentUser?.uid;

  Future<void> loadWhenReady() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await loadTrainings();
      return;
    }

    // Timeout de 5s para evitar espera indefinida
    // si Firebase Auth no emite en iOS
    try {
      await FirebaseAuth.instance
          .authStateChanges()
          .firstWhere((u) => u != null)
          .timeout(const Duration(seconds: 5));
    } on TimeoutException {
      debugPrint('[HistoryController] '
          'loadWhenReady timeout — '
          'usuario no disponible');
      if (!_disposed) {
        error.value =
            'No se pudo conectar. '
            'Comprueba tu conexión.';
      }
      return;
    }
    await loadTrainings();
  }

  Future<void> loadTrainings() async {
    if (isLoading.value) return;

    // Reset pagination
    _lastDocument = null;
    _hasMore = true;
    error.value = null;
    isLoading.value = true;

    try {
      final uid = _resolveUid();
      if (uid == null) {
        error.value = 'No hay usuario autenticado';
        return;
      }

      final page = await _trainingRepo
          .getTrainings(uid: uid, pageSize: 20)
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () => throw TimeoutException(
                'Tiempo de espera agotado'),
          );
      if (_disposed) return;
      _allTrainings.value = page.trainings;
      _lastDocument = page.lastDocument;
      _hasMore = page.hasMore;

      // Cargar colores de etiquetas
      try {
        final tags = await _tagManager.getUserTags();
        _tagColors = {for (var t in tags) t.name: t.color};
      } catch (_) {}

      applyFilters();
    } catch (e) {
      if (!_disposed) error.value = 'Error al cargar entrenamientos: $e';
    }
    if (!_disposed) isLoading.value = false;
  }

  Future<void> loadMore() async {
    if (!_hasMore || _isLoadingMore || _lastDocument == null) return;

    final uid = _resolveUid();
    if (uid == null) return;

    _isLoadingMore = true;

    try {
      final page = await _trainingRepo.getTrainings(
        uid: uid,
        startAfter: _lastDocument,
        pageSize: 20,
      );

      if (_disposed) return;
      _allTrainings.value = [..._allTrainings.value, ...page.trainings];
      _lastDocument = page.lastDocument;
      _hasMore = page.hasMore;

      applyFilters();
    } catch (e) {
      debugPrint('[HistoryController] loadMore error: $e');
    } finally {
      _isLoadingMore = false;
    }
  }

  Color getColorForTag(String? tagName) {
    if (tagName == null) return AppColors.iconMuted;
    // Buscamos en tags definidos por usuario, si no, generamos uno determinista
    return _tagColors[tagName] ?? TagUtils.getColor(tagName);
  }

  void setFilter(TrainingFilter filter) {
    currentFilter.value = filter;
    // Al seleccionar un filtro rápido, limpiamos los personalizados para evitar confusión
    // O podríamos mantenerlos, pero simplifiquemos por ahora.
    applyFilters();
  }

  void applyFilters() {
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
  HistoryAnalyticsViewModel get analytics => HistoryAnalyticsViewModel(_allTrainings.value, getColorForTag);

  // NUEVOS MÉTODOS PARA BÚSQUEDA Y FILTRO
  
  void setSearchQuery(String query) {
    searchQuery.value = query;
    applyFilters();
  }

  void toggleTagFilter(String tag) {
    final Set<String> currentTags = Set.from(selectedTags.value);
    if (currentTags.contains(tag)) {
      currentTags.remove(tag);
    } else {
      currentTags.add(tag);
    }
    selectedTags.value = currentTags;
    applyFilters();
  }

  void setDateRange(DateTime? start, DateTime? end) {
    filterStartDate.value = start;
    filterEndDate.value = end;
    applyFilters();
  }

  void setDistanceRange(double? minMeters, double? maxMeters) {
    filterMinDist.value = minMeters;
    filterMaxDist.value = maxMeters;
    applyFilters();
  }

  void setSeriesDistanceFilter(int? distanceMeters) {
    filterSeriesDistance.value = distanceMeters;
    applyFilters();
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
    applyFilters();
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
  
  /// Genera descripción legible del filtro activo (para Analytics banner)
  String get filterDescription {
    List<String> parts = [];
    
    // Rango de fechas
    if (filterStartDate.value != null || filterEndDate.value != null) {
      if (filterStartDate.value != null && filterEndDate.value != null) {
        final start = filterStartDate.value!;
        final end = filterEndDate.value!;
        if (start.year == end.year && start.month == end.month && start.day == end.day) {
          // Mismo día
          parts.add('${start.day}/${start.month}/${start.year}');
        } else {
          parts.add('${start.day}/${start.month} - ${end.day}/${end.month}');
        }
      } else if (filterStartDate.value != null) {
        final date = filterStartDate.value!;
        parts.add('Desde ${date.day}/${date.month}/${date.year}');
      } else {
        final date = filterEndDate.value!;
        parts.add('Hasta ${date.day}/${date.month}/${date.year}');
      }
    }
    
    // Tags
    if (selectedTags.value.isNotEmpty) {
      if (selectedTags.value.length == 1) {
        parts.add('Tag: ${selectedTags.value.first}');
      } else {
        parts.add('Tags: ${selectedTags.value.take(2).join(', ')}${selectedTags.value.length > 2 ? '...' : ''}');
      }
    }
    
    // Distancia
    if (filterMinDist.value != null || filterMaxDist.value != null) {
      if (filterMinDist.value != null && filterMaxDist.value != null) {
        parts.add('${(filterMinDist.value!/1000).toStringAsFixed(1)}-${(filterMaxDist.value!/1000).toStringAsFixed(1)} km');
      } else if (filterMinDist.value != null) {
        parts.add('> ${(filterMinDist.value!/1000).toStringAsFixed(1)} km');
      } else {
        parts.add('< ${(filterMaxDist.value!/1000).toStringAsFixed(1)} km');
      }
    }
    
    // Series
    if (filterSeriesDistance.value != null) {
      parts.add('Series ${filterSeriesDistance.value}m');
    }
    
    // Búsqueda
    if (searchQuery.value.trim().isNotEmpty) {
      parts.add('"${searchQuery.value.trim()}"');
    }
    
    if (parts.isEmpty) return 'Todos los entrenos';
    return parts.join(' • ');
  }

  void dispose() {
    _disposed = true;
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

