/// Configuración de widgets en la pantalla Home
/// Permite al usuario personalizar qué widgets ver y en qué orden
class HomeLayoutConfig {
  final String userId;
  final List<HomeWidget> widgets;
  final DateTime lastUpdated;

  HomeLayoutConfig({
    required this.userId,
    required this.widgets,
    required this.lastUpdated,
  });

  /// Serialización a Firestore
  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'widgets': widgets.map((w) => w.toMap()).toList(),
      'lastUpdated': lastUpdated.toIso8601String(),
    };
  }

  /// Deserialización desde Firestore
  factory HomeLayoutConfig.fromMap(Map<String, dynamic> map) {
    return HomeLayoutConfig(
      userId: map['userId'] as String,
      widgets: (map['widgets'] as List<dynamic>)
          .map((w) => HomeWidget.fromMap(w as Map<String, dynamic>))
          .toList(),
      lastUpdated: DateTime.parse(map['lastUpdated'] as String),
    );
  }

  /// Configuración por defecto
  /// Widgets prioritarios: Consistency, Speed improvement, Distance progression
  factory HomeLayoutConfig.defaultConfig(String userId) {
    return HomeLayoutConfig(
      userId: userId,
      lastUpdated: DateTime.now(),
      widgets: [
        // Widget 1: Progresión de ritmo (mejora de velocidad)
        HomeWidget(
          id: 'pace_progression',
          type: WidgetType.lineChart,
          visible: true,
          order: 0,
          config: {
            'title': 'Progresión de Ritmo',
            'metric': 'pace',
            'aggregation': 'week',
            'showTrend': true,
          },
        ),

        // Widget 2: Progresión de distancia
        HomeWidget(
          id: 'distance_progression',
          type: WidgetType.barChart,
          visible: true,
          order: 1,
          config: {
            'title': 'Volumen Semanal',
            'metric': 'distance',
            'aggregation': 'week',
            'showTarget': false,
          },
        ),

        // Widget 3: Consistencia (entrenamientos por semana)
        HomeWidget(
          id: 'consistency_tracker',
          type: WidgetType.heatmap,
          visible: true,
          order: 2,
          config: {
            'title': 'Constancia',
            'showMonths': 3,
          },
        ),

        // Widget 4: Distribución por tags
        HomeWidget(
          id: 'tags_distribution',
          type: WidgetType.donutChart,
          visible: true,
          order: 3,
          config: {
            'title': 'Tipos de Entrenamiento',
            'metric': 'distance',
          },
        ),

        // Widget 5: Carga de entrenamiento
        HomeWidget(
          id: 'load_chart',
          type: WidgetType.barChart,
          visible: false,
          order: 4,
          config: {
            'title': 'Carga Semanal',
            'metric': 'load',
            'aggregation': 'week',
          },
        ),

        // Widget 6: RPE promedio
        HomeWidget(
          id: 'rpe_trend',
          type: WidgetType.lineChart,
          visible: false,
          order: 5,
          config: {
            'title': 'Evolución RPE',
            'metric': 'rpe',
            'aggregation': 'week',
          },
        ),

        // Widget 7: Progreso en patrones (400m, etc.)
        HomeWidget(
          id: 'pattern_progress',
          type: WidgetType.progressTracker,
          visible: false,
          order: 6,
          config: {
            'title': 'Progreso en Series',
            'patterns': ['400', '1000'],
          },
        ),

        // Widget 8: Últimos entrenamientos (carrusel)
        HomeWidget(
          id: 'recent_workouts',
          type: WidgetType.carousel,
          visible: true,
          order: 7,
          config: {
            'title': 'Últimos Entrenamientos',
            'count': 5,
          },
        ),
      ],
    );
  }

  /// Obtener widgets visibles ordenados
  List<HomeWidget> get visibleWidgets {
    return widgets.where((w) => w.visible).toList()
      ..sort((a, b) => a.order.compareTo(b.order));
  }

  /// Copiar con cambios
  HomeLayoutConfig copyWith({
    String? userId,
    List<HomeWidget>? widgets,
    DateTime? lastUpdated,
  }) {
    return HomeLayoutConfig(
      userId: userId ?? this.userId,
      widgets: widgets ?? this.widgets,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }
}

/// Widget individual configurable en Home
class HomeWidget {
  final String id;
  final WidgetType type;
  final bool visible;
  final int order;
  final Map<String, dynamic> config;

  HomeWidget({
    required this.id,
    required this.type,
    required this.visible,
    required this.order,
    required this.config,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type.toString().split('.').last,
      'visible': visible,
      'order': order,
      'config': config,
    };
  }

  factory HomeWidget.fromMap(Map<String, dynamic> map) {
    return HomeWidget(
      id: map['id'] as String,
      type: _parseWidgetType(map['type'] as String),
      visible: map['visible'] as bool,
      order: map['order'] as int,
      config: Map<String, dynamic>.from(map['config'] as Map),
    );
  }

  static WidgetType _parseWidgetType(String typeStr) {
    switch (typeStr) {
      case 'kpiCard':        return WidgetType.kpiCard;
      case 'lineChart':      return WidgetType.lineChart;
      case 'barChart':       return WidgetType.barChart;
      case 'donutChart':     return WidgetType.donutChart;
      case 'heatmap':        return WidgetType.heatmap;
      case 'carousel':       return WidgetType.carousel;
      case 'progressTracker': return WidgetType.progressTracker;
      default:               return WidgetType.kpiCard;
    }
  }

  HomeWidget copyWith({
    String? id,
    WidgetType? type,
    bool? visible,
    int? order,
    Map<String, dynamic>? config,
  }) {
    return HomeWidget(
      id: id ?? this.id,
      type: type ?? this.type,
      visible: visible ?? this.visible,
      order: order ?? this.order,
      config: config ?? this.config,
    );
  }
}

/// Tipos de widgets disponibles
enum WidgetType {
  kpiCard,
  lineChart,
  barChart,
  donutChart,
  heatmap,
  carousel,
  progressTracker,
}

extension WidgetTypeExtension on WidgetType {
  String get displayName {
    switch (this) {
      case WidgetType.kpiCard:          return 'KPI Card';
      case WidgetType.lineChart:        return 'Gráfica de Línea';
      case WidgetType.barChart:         return 'Gráfica de Barras';
      case WidgetType.donutChart:       return 'Gráfica Circular';
      case WidgetType.heatmap:          return 'Heatmap';
      case WidgetType.carousel:         return 'Carrusel';
      case WidgetType.progressTracker:  return 'Progreso';
    }
  }
}
