import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:running_laps/features/home/data/home_layout_config.dart';

/// Repositorio para la configuración de widgets del Home
class HomeConfigRepository {
  final FirebaseFirestore _firestore;

  HomeConfigRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  /// Carga la configuración del usuario desde Firestore
  /// Si no existe, retorna la configuración por defecto
  Future<HomeLayoutConfig> loadConfig(String userId) async {
    try {
      final doc = await _firestore
          .collection('users')
          .doc(userId)
          .collection('settings')
          .doc('homeLayoutConfig')
          .get();

      if (!doc.exists || doc.data() == null) {
        return HomeLayoutConfig.defaultConfig(userId);
      }

      return HomeLayoutConfig.fromMap(doc.data()!);
    } catch (e) {
      return HomeLayoutConfig.defaultConfig(userId);
    }
  }

  /// Guarda la configuración del usuario en Firestore
  Future<void> saveConfig(HomeLayoutConfig config) async {
    try {
      await _firestore
          .collection('users')
          .doc(config.userId)
          .collection('settings')
          .doc('homeLayoutConfig')
          .set(config.toMap(), SetOptions(merge: true));
    } catch (e) {
      throw Exception('No se pudo guardar la configuración');
    }
  }

  /// Actualiza un widget específico
  Future<void> updateWidget(
    String userId,
    String widgetId,
    Map<String, dynamic> updates,
  ) async {
    try {
      final config = await loadConfig(userId);

      final updatedWidgets = config.widgets.map((w) {
        if (w.id == widgetId) {
          return w.copyWith(
            visible: updates['visible'] as bool? ?? w.visible,
            order: updates['order'] as int? ?? w.order,
            config: updates['config'] as Map<String, dynamic>? ?? w.config,
          );
        }
        return w;
      }).toList();

      final updatedConfig = config.copyWith(
        widgets: updatedWidgets,
        lastUpdated: DateTime.now(),
      );

      await saveConfig(updatedConfig);
    } catch (e) {
      throw Exception('No se pudo actualizar el widget');
    }
  }

  /// Reordena los widgets
  Future<void> reorderWidgets(String userId, List<String> widgetIds) async {
    try {
      final config = await loadConfig(userId);
      final widgetsMap = {for (var w in config.widgets) w.id: w};

      final reorderedWidgets = <HomeWidget>[];
      for (int i = 0; i < widgetIds.length; i++) {
        final widget = widgetsMap[widgetIds[i]];
        if (widget != null) {
          reorderedWidgets.add(widget.copyWith(order: i));
        }
      }

      for (var widget in config.widgets) {
        if (!widgetIds.contains(widget.id)) {
          reorderedWidgets.add(widget);
        }
      }

      await saveConfig(config.copyWith(
        widgets: reorderedWidgets,
        lastUpdated: DateTime.now(),
      ));
    } catch (e) {
      throw Exception('No se pudo reordenar los widgets');
    }
  }

  /// Resetea la configuración a los valores por defecto
  Future<void> resetToDefault(String userId) async {
    try {
      await saveConfig(HomeLayoutConfig.defaultConfig(userId));
    } catch (e) {
      throw Exception('No se pudo resetear la configuración');
    }
  }

  /// Alterna la visibilidad de un widget
  Future<void> toggleWidgetVisibility(String userId, String widgetId) async {
    try {
      final config = await loadConfig(userId);
      final widget = config.widgets.firstWhere((w) => w.id == widgetId);
      await updateWidget(userId, widgetId, {'visible': !widget.visible});
    } catch (e) {
      throw Exception('No se pudo cambiar la visibilidad del widget');
    }
  }
}
