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
  // Stream subscription para escuchar posiciones GPS
  StreamSubscription<Position>? _positionStreamSubscription;
  
  // Lista de puntos GPS registrados
  final List<GpsPoint> _points = [];
  
  // Última posición conocida
  Position? _lastPosition;
  
  // Estado del servicio
  GpsStatus _status = GpsStatus.uninitialized;
  
  // Distancia total acumulada en metros
  double _totalDistanceMeters = 0.0;
  
  // Tiempo de inicio del tracking
  DateTime? _startTime;
  
  // Tiempo total corriendo (excluyendo pausas)
  Duration _runningDuration = Duration.zero;
  
  // Tiempo de la última pausa
  DateTime? _pauseTime;
  
  // Configuración: precisión mínima aceptable (metros)
  // Subida a 30m para facilitar pruebas urbanas/caminar
  static const double _minAccuracy = 35.0; 
  
  // Configuración: distancia mínima entre puntos para reducir ruido (metros)
  static const double _minDistanceBetweenPoints = 2.0;

  // Getters públicos
  GpsStatus get status => _status;
  List<GpsPoint> get points => List.unmodifiable(_points);
  double get totalDistanceMeters => _totalDistanceMeters;
  Position? get lastPosition => _lastPosition;
  
  /// Ritmo promedio en formato "mm:ss /km"
  String get currentPace {
    if (_totalDistanceMeters < 10) {
      // No suficiente distancia para calcular
      return "--:-- /km";
    }
    
    final Duration totalTime = _runningDuration;
    if (totalTime.inSeconds < 1) {
      return "--:-- /km";
    }
    
    // Ritmo = tiempo / distancia_en_km
    final double km = _totalDistanceMeters / 1000.0;
    final double secondsPerKm = totalTime.inSeconds / km;
    
    // Validar ritmo razonable:
    // Mínimo: 2:00 min/km (record mundial es ~2:30)
    // Máximo: 35:00 min/km (ritmo de paseo muy lento para pruebas)
    if (secondsPerKm < 120 || secondsPerKm > 2100) {
      return "--:-- /km";
    }
    
    final int minutes = secondsPerKm ~/ 60;
    final int seconds = (secondsPerKm % 60).round();
    
    return '${minutes}:${seconds.toString().padLeft(2, '0')} /km';
  }

  /// Inicializa el servicio GPS y solicita permisos
  Future<bool> initialize() async {
    try {
      // 1. Verificar si el servicio de ubicación está habilitado
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _status = GpsStatus.disabled;
        return false;
      }

      // 2. Verificar permisos
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

  /// Inicia el tracking GPS
  Future<void> startTracking() async {
    if (_status != GpsStatus.ready && _status != GpsStatus.paused) {
      throw StateError('GPS must be initialized and ready before starting tracking');
    }

    _status = GpsStatus.active;
    _startTime ??= DateTime.now(); // Solo set la primera vez
    
    // Configuración de ubicación
    const LocationSettings locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 0, // Recibir todas las actualizaciones
    );

    // Suscribirse al stream de posiciones
    _positionStreamSubscription = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen(
      _onPositionUpdate,
      onError: (error) {
        print('GPS Error: $error');
        _status = GpsStatus.error;
      },
    );
  }

  /// Callback cuando se recibe una nueva posición GPS
  void _onPositionUpdate(Position position) {
    // Ignorar si está pausado
    if (_status == GpsStatus.paused) return;

    // Filtrar por precisión
    if (position.accuracy > _minAccuracy) {
      return; // Posición no suficientemente precisa
    }

    // Si hay una posición anterior, calcular distancia
    if (_lastPosition != null) {
      final double distance = Geolocator.distanceBetween(
        _lastPosition!.latitude,
        _lastPosition!.longitude,
        position.latitude,
        position.longitude,
      );

      // Filtrar actualizaciones muy pequeñas (ruido GPS)
      if (distance < _minDistanceBetweenPoints) {
        return;
      }

      // Acumular distancia
      _totalDistanceMeters += distance;
    }

    // Guardar punto
    _points.add(GpsPoint(
      latitude: position.latitude,
      longitude: position.longitude,
      timestamp: position.timestamp ?? DateTime.now(),
      accuracy: position.accuracy,
    ));

    _lastPosition = position;

    // Actualizar duración de corrida
    if (_startTime != null && _pauseTime == null) {
      _runningDuration = DateTime.now().difference(_startTime!);
    }
  }

  /// Pausa el tracking GPS
  void pause() {
    if (_status != GpsStatus.active) return;
    
    _pauseTime = DateTime.now();
    _status = GpsStatus.paused;
    
    // No cancelamos la suscripción, solo ignoramos updates en _onPositionUpdate
  }

  /// Reanuda el tracking GPS
  void resume() {
    if (_status != GpsStatus.paused) return;
    
    // Ajustar el tiempo de inicio para descontar la pausa
    if (_pauseTime != null && _startTime != null) {
      final Duration pauseDuration = DateTime.now().difference(_pauseTime!);
      _startTime = _startTime!.add(pauseDuration);
    }
    
    _pauseTime = null;
    _status = GpsStatus.active;
  }

  /// Detiene el tracking GPS completamente
  Future<void> stopTracking() async {
    await _positionStreamSubscription?.cancel();
    _positionStreamSubscription = null;
    _status = GpsStatus.ready;
  }

  /// Resetea todos los datos del tracking
  void reset() {
    _points.clear();
    _lastPosition = null;
    _totalDistanceMeters = 0.0;
    _startTime = null;
    _runningDuration = Duration.zero;
    _pauseTime = null;
  }

  /// Dispose del servicio
  Future<void> dispose() async {
    await stopTracking();
    reset();
    _status = GpsStatus.uninitialized;
  }
}
