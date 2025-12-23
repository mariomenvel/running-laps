import 'dart:async';
import 'package:geolocator/geolocator.dart';

/// Modelo para almacenar puntos GPS
class GpsPoint {
  final double latitude;
  final double longitude;
  final DateTime timestamp;
  final double? accuracy; // Precisión en metros

  GpsPoint({
    required this.latitude,
    required this.longitude,
    required this.timestamp,
    this.accuracy,
  });

  Map<String, dynamic> toMap() {
    return {
      'latitude': latitude,
      'longitude': longitude,
      'timestamp': timestamp.toIso8601String(),
      'accuracy': accuracy,
    };
  }

  static GpsPoint fromMap(Map<String, dynamic> map) {
    return GpsPoint(
      latitude: (map['latitude'] as num).toDouble(),
      longitude: (map['longitude'] as num).toDouble(),
      timestamp: DateTime.parse(map['timestamp'] as String),
      accuracy: map['accuracy'] != null ? (map['accuracy'] as num).toDouble() : null,
    );
  }
}

/// Estados posibles del servicio GPS
enum GpsStatus {
  uninitialized,   // No inicializado
  permissionDenied, // Permisos denegados
  disabled,        // GPS desactivado en el dispositivo
  ready,           // Listo para usar
  active,          // Tracking activo
  paused,          // Tracking pausado
  error,           // Error general
}

/// Servicio para gestionar el tracking GPS durante entrenamientos
class GPSService {
  StreamSubscription<Position>? _positionStreamSubscription;
  
  // Historial completo para guardar en BD
  final List<GpsPoint> _points = [];
  
  // Ventana deslizante para cálculo de ritmo (últimos X segundos)
  final List<GpsPoint> _windowPoints = [];
  final Duration _windowDuration = const Duration(seconds: 15);
  
  // Última posición válida (filtrada)
  Position? _lastPosition;
  
  GpsStatus _status = GpsStatus.uninitialized;
  double _totalDistanceMeters = 0.0;
  
  DateTime? _startTime;
  DateTime? _pauseTime;
  
  // CONFIGURACIÓN AVANZADA
  static const double _minAccuracy = 15.0; // Descartar > 15m de error
  static const double _maxSpeedMps = 10.0; // ~36 km/h (Mundo récord Usain Bolt ~12m/s, maratón ~6m/s)
                                           // Usamos 10m/s para permitir sprints fuertes pero filtrar coches/teletransporte
  static const double _minDistAccumulate = 2.0; // Mínimo movimiento para sumar distancia

  // Getters
  GpsStatus get status => _status;
  List<GpsPoint> get points => List.unmodifiable(_points);
  double get totalDistanceMeters => _totalDistanceMeters;
  Position? get lastPosition => _lastPosition;

  // Tiempo total corriendo (excluyendo pausas)
  Duration get _runningDuration {
    if (_startTime == null) return Duration.zero;
    if (_status == GpsStatus.paused && _pauseTime != null) {
      return _pauseTime!.difference(_startTime!);
    }
    return DateTime.now().difference(_startTime!);
  }
  
  /// Ritmo suavizado usando ventana deslizante
  String get currentPace {
    // Si no tenemos suficientes puntos recientes, o estamos parados
    if (_windowPoints.length < 2) return "--:-- /km";

    final first = _windowPoints.first;
    final last = _windowPoints.last;

    final double distWindow = Geolocator.distanceBetween(
      first.latitude, first.longitude, 
      last.latitude, last.longitude
    );

    final int timeWindowMs = last.timestamp.difference(first.timestamp).inMilliseconds;

    // Si la distancia es despreciable o t=0
    if (distWindow < 5.0 || timeWindowMs < 1000) {
      // Si llevamos mucho sin movernos, devolvemos "--"
      // Check last point age
      if (DateTime.now().difference(last.timestamp).inSeconds > 5) {
        return "--:-- /km";
      }
      // Si es reciente, mantenemos el último ritmo conocido o mostramos -- 
      // Para ser reactivos, si casi no hay distancia en la ventana, es que paró.
      return "--:-- /km";
    }

    final double secondsPerKm = (timeWindowMs / 1000.0) / (distWindow / 1000.0);

    // Filtros visuales (igual que antes)
    if (secondsPerKm < 120) return "--:-- /km"; // < 2:00 min/km
    if (secondsPerKm > 6000) return "99:59 /km"; // > 100 min/km

    int minutes = secondsPerKm ~/ 60;
    int seconds = (secondsPerKm % 60).round();
    
    if (minutes > 99) {
      minutes = 99;
      seconds = 59;
    }

    return '${minutes}:${seconds.toString().padLeft(2, '0')} /km';
  }

  Future<bool> initialize() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _status = GpsStatus.disabled;
        return false;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _status = GpsStatus.permissionDenied;
          return false;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        _status = GpsStatus.permissionDenied;
        return false;
      }

      _status = GpsStatus.ready;
      return true;
    } catch (e) {
      _status = GpsStatus.error;
      return false;
    }
  }

  Future<void> startTracking() async {
    if (_status != GpsStatus.ready && _status != GpsStatus.paused) {
      throw StateError('GPS must be initialized');
    }

    _status = GpsStatus.active;
    _startTime ??= DateTime.now();
    
    // Pedimos alta precisión
    const LocationSettings locationSettings = LocationSettings(
      accuracy: LocationAccuracy.bestForNavigation, 
      distanceFilter: 0, 
    );

    _positionStreamSubscription = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen(
      _onPositionUpdate,
      onError: (error) {
        print('GPS Error: $error');
        _status = GpsStatus.error;
      },
      cancelOnError: false,
    );
  }

  void _onPositionUpdate(Position position) {
    if (_status == GpsStatus.paused) return;

    // 1. FILTRO DE PRECISIÓN
    // Si la precisión es mala (> 15-20m), descartar
    if (position.accuracy > _minAccuracy) return;

    // 2. FILTRO DE PICOS DE VELOCIDAD
    if (_lastPosition != null) {
      final double dist = Geolocator.distanceBetween(
        _lastPosition!.latitude, _lastPosition!.longitude,
        position.latitude, position.longitude
      );
      
      final int timeDiffMs = position.timestamp!.difference(_lastPosition!.timestamp!).inMilliseconds.abs();
      
      // Si el tiempo es muy pequeño, ignorar para evitar división por cero o ruido extremo
      if (timeDiffMs < 500) return;

      final double speedMps = dist / (timeDiffMs / 1000.0);

      if (speedMps > _maxSpeedMps) {
        // Pico irreal, descartar punto
        return; 
      }
      
      // 3. ACUMULACIÓN DE DISTANCIA (con umbral mínimo)
      // Solo sumamos si nos movimos una distancia "real" para evitar sumar ruido estático
      if (dist >= _minDistAccumulate) {
        _totalDistanceMeters += dist;
      }
    }

    // ACEPTAR PUNTO
    _lastPosition = position;
    
    final newPoint = GpsPoint(
      latitude: position.latitude,
      longitude: position.longitude,
      timestamp: position.timestamp ?? DateTime.now(),
      accuracy: position.accuracy,
    );

    _points.add(newPoint);
    _addToWindow(newPoint);
  }

  void _addToWindow(GpsPoint point) {
    _windowPoints.add(point);

    // Limpiar puntos antiguos (> 15s)
    final DateTime threshold = point.timestamp.subtract(_windowDuration);
    _windowPoints.removeWhere((p) => p.timestamp.isBefore(threshold));
  }

  void pause() {
    if (_status != GpsStatus.active) return;
    _pauseTime = DateTime.now();
    _status = GpsStatus.paused;
  }

  void resume() {
    if (_status != GpsStatus.paused) return;
    if (_pauseTime != null && _startTime != null) {
      final Duration pauseDuration = DateTime.now().difference(_pauseTime!);
      _startTime = _startTime!.add(pauseDuration);
      
      // Limpiar ventana al reanudar para no calcular ritmo con salto de tiempo
      _windowPoints.clear();
      _lastPosition = null; // Reiniciar referencia inmediata
    }
    _pauseTime = null;
    _status = GpsStatus.active;
  }

  Future<void> stopTracking() async {
    await _positionStreamSubscription?.cancel();
    _positionStreamSubscription = null;
    _status = GpsStatus.ready;
  }

  void reset() {
    _points.clear();
    _windowPoints.clear();
    _lastPosition = null;
    _totalDistanceMeters = 0.0;
    _startTime = null;
    _pauseTime = null;
  }

  Future<void> dispose() async {
    await stopTracking();
    reset();
    _status = GpsStatus.uninitialized;
  }
}
