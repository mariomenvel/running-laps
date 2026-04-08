import 'package:flutter/foundation.dart';
import 'package:running_laps/features/home/data/home_config_repository.dart';
import 'package:running_laps/features/home/data/home_layout_config.dart';

class HomeConfigController {
  final String userId;
  final HomeConfigRepository _repository;
  
  final ValueNotifier<HomeLayoutConfig?> config = ValueNotifier(null);
  final ValueNotifier<bool> isLoading = ValueNotifier(false);
  final ValueNotifier<bool> isSaving = ValueNotifier(false);
  bool _isDisposed = false;
  
  HomeConfigController({
    required this.userId,
    HomeConfigRepository? repository,
  }) : _repository = repository ?? HomeConfigRepository();

  Future<void> initialize() async {
    await loadConfig();
  }

  Future<void> loadConfig() async {
    if (userId.isEmpty || _isDisposed) return;

    isLoading.value = true;
    try {
      final loadedConfig = await _repository.loadConfig(userId);
      config.value = _mergeWithDefaults(loadedConfig);
    } catch (e) {
      // Fallback to default if load fails
      config.value = HomeLayoutConfig.defaultConfig(userId);
    } finally {
      if (!_isDisposed) {
        isLoading.value = false;
      }
    }
  }

  /// Adds any widgets present in defaultConfig but missing from [loaded].
  /// This handles app updates that introduce new widget IDs: existing users
  /// whose Firestore configs were saved before the new widgets were added will
  /// automatically get the new entries appended at the end (hidden by default).
  HomeLayoutConfig _mergeWithDefaults(HomeLayoutConfig loaded) {
    final defaultWidgets = HomeLayoutConfig.defaultConfig(userId).widgets;
    final existingIds = {for (final w in loaded.widgets) w.id};

    final missing = defaultWidgets
        .where((w) => !existingIds.contains(w.id))
        .toList();

    if (missing.isEmpty) return loaded;

    int maxOrder = loaded.widgets.fold(
        0, (max, w) => w.order > max ? w.order : max);
    final appended =
        missing.map((w) => w.copyWith(order: ++maxOrder)).toList();

    return loaded.copyWith(
      widgets: [...loaded.widgets, ...appended],
    );
  }

  Future<void> saveConfig() async {
    if (config.value == null) return;
    
    isSaving.value = true;
    try {
      await _repository.saveConfig(config.value!);
    } catch (e) {
      rethrow;
    } finally {
      if (!_isDisposed) isSaving.value = false;
    }
  }

  void reorderWidgets(int oldIndex, int newIndex) {
    if (config.value == null) return;
    
    // Create a copy of the widgets list
    final currentWidgets = List<HomeWidget>.from(config.value!.widgets);
    
    // Sort by current order to ensure we're moving the right items physically
    currentWidgets.sort((a, b) => a.order.compareTo(b.order));
    
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    
    final item = currentWidgets.removeAt(oldIndex);
    currentWidgets.insert(newIndex, item);
    
    // Re-assign order indices
    final updatedWidgets = currentWidgets.asMap().entries.map((entry) {
      return entry.value.copyWith(order: entry.key);
    }).toList();
    
    // Update state locally
    config.value = config.value!.copyWith(
      widgets: updatedWidgets,
      lastUpdated: DateTime.now(),
    );
    
    // Save to backend (optionally debounce this)
    saveConfig();
  }

  void updateWidgetConfig(String widgetId, Map<String, dynamic> updatedConfig) {
    if (config.value == null) return;

    final updatedWidgets = config.value!.widgets.map((w) {
      if (w.id == widgetId) {
        return w.copyWith(config: {...w.config, ...updatedConfig});
      }
      return w;
    }).toList();

    config.value = config.value!.copyWith(
      widgets: updatedWidgets,
      lastUpdated: DateTime.now(),
    );

    saveConfig();
  }

  void toggleWidgetVisibility(String widgetId) {
    if (config.value == null) return;

    final updatedWidgets = config.value!.widgets.map((w) {
      if (w.id == widgetId) {
        return w.copyWith(visible: !w.visible);
      }
      return w;
    }).toList();

    config.value = config.value!.copyWith(
      widgets: updatedWidgets,
      lastUpdated: DateTime.now(),
    );

    saveConfig();
  }

  Future<void> resetToDefault() async {
    isLoading.value = true;
    try {
      await _repository.resetToDefault(userId);
      // Reload fresh default
      final defaultConfig = HomeLayoutConfig.defaultConfig(userId);
      config.value = defaultConfig;
    } catch (e) {
      // Error resetting
    } finally {
      if (!_isDisposed) {
        isLoading.value = false;
      }
    }
  }

  void dispose() {
    _isDisposed = true;
    config.dispose();
    isLoading.dispose();
    isSaving.dispose();
  }
}

