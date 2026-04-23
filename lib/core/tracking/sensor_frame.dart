class SensorFrame {

    // GPS
    final double? latitude;
    final double? longitude;
    final double? altitude;
    final double? gpsAccuracy;   // metros
    final double? gpsSpeed;      // m/s

    // Movimiento — pasos
    final int stepsDelta;        // pasos desde el último tick

    // Acelerómetro (m/s²)
    final double accelerationX;
    final double accelerationY;
    final double accelerationZ;
    final double accelerationMagnitude;  // sqrt(x²+y²+z²)

    // Giroscopio (rad/s)
    final double gyroscopeZ;     // rotación sobre eje vertical

    // Tiempo
    final DateTime timestamp;

    SensorFrame({
      this.latitude,
      this.longitude,
      this.altitude,
      this.gpsAccuracy,
      this.gpsSpeed,
      required this.stepsDelta,
      required this.accelerationX,
      required this.accelerationY,
      required this.accelerationZ,
      required this.accelerationMagnitude,
      required this.gyroscopeZ,
      required this.timestamp,
    });
}
