import 'package:flutter/foundation.dart';
import 'package:running_laps/features/analytics/data/home_config_repository.dart';
import 'package:running_laps/features/analytics/data/home_layout_config.dart';

class HomeConfigController {
  final String userId;
  final HomeConfigRepository _repository;
  
  final ValueNotifier<HomeLayoutConfig?> config = ValueNotifier(null);
  final ValueNotifier<bool> isLoading = ValueNotifier(false);
  final ValueNotifier<bool> isSaving = ValueNotifier(false);
  
  HomeConfigController({
    required this.userId,
    HomeConfigRepository? repository,
  }) : _repository = repository ?? HomeConfigRepository();

  Future<void> initialize() async {
    await loadConfig();
  }

  Future<void> loadConfig() async {
    if (userId.isEmpty) return;
    
    isLoading.value = true;
    try {
      final loadedConfig = await _repository.loadConfig(userId);
      config.value = loadedConfig;
    } catch (e) {
      debugPrint('Error loading home config: $e');
      // Fallback to default if load fails
      config.value = HomeLayoutConfig.defaultConfig(userId);
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> saveConfig() async {
    if (config.value == null) return;
    
    isSaving.value = true;
    try {
      await _repository.saveConfig(config.value!);
    } catch (e) {
      debugPrint('Error saving home config: $e');
      rethrow;
    } finally {
      isSaving.value = false;
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
      debugPrint('Error resetting config: $e');
    } finally {
      isLoading.value = false;
    }
  }

  void dispose() {
    config.dispose();
    isLoading.dispose();
    isSaving.dispose();
  }
}
