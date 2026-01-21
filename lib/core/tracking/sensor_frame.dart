class SensorFrame {

    // GPS
    final double? latitude;
    final double? longitude;
    final double? altitude;      // New: Altitude support
    final double? gpsAccuracy;   // metros
    final double? gpsSpeed;      // m/s

    // Movimiento
    final int stepsDelta;        // pasos desde el último tick
    final double acceleration;  // magnitud media (simplificada)

    // Tiempo
    final DateTime timestamp;

    SensorFrame({
      this.latitude,
      this.longitude,
      this.altitude,
      this.gpsAccuracy,
      this.gpsSpeed,
      required this.stepsDelta,
      required this.acceleration,
      required this.timestamp,
    });
}
