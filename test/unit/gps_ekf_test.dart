import 'package:flutter_test/flutter_test.dart';
import 'package:running_laps/core/services/gps_service.dart';
import 'package:running_laps/core/utils/ekf2d.dart';

void main() {
  group('GPSService.ekfInitThresholdFor', () {
    test('exige fix fino (15 m) durante la ventana estricta inicial', () {
      expect(GPSService.ekfInitThresholdFor(Duration.zero), 15.0);
      expect(GPSService.ekfInitThresholdFor(const Duration(seconds: 5)), 15.0);
      expect(GPSService.ekfInitThresholdFor(const Duration(seconds: 9)), 15.0);
    });

    test('se relaja a accuracy usable (35 m) pasada la ventana', () {
      // Regresión del bug de GPS en series: cada serie crea un GPSService
      // nuevo y con el umbral fijo de 15 m una serie corta podía terminar
      // sin que el EKF llegara a inicializarse (distancia = 0).
      expect(GPSService.ekfInitThresholdFor(const Duration(seconds: 10)), 35.0);
      expect(GPSService.ekfInitThresholdFor(const Duration(seconds: 30)), 35.0);
      expect(GPSService.ekfInitThresholdFor(const Duration(minutes: 5)), 35.0);
    });
  });

  group('EKF2D', () {
    test('sin inicializar no está listo; initialize lo ancla', () {
      final ekf = EKF2D();
      expect(ekf.isInitialized, isFalse);

      ekf.initialize(40.0, -3.7, 3.0, 0.0, accuracy: 10.0);

      expect(ekf.isInitialized, isTrue);
      expect(ekf.latitude, 40.0);
      expect(ekf.longitude, -3.7);
      expect(ekf.velocity, 3.0);
    });

    test('updateGPS corrige la posición hacia las mediciones', () {
      final ekf = EKF2D();
      // Anclaje grueso (35 m) — el caso que ahora permite la escalera
      ekf.initialize(40.0, -3.7, 0.0, 0.0, accuracy: 35.0);

      // Mediciones precisas y consistentes un poco al norte
      for (var i = 0; i < 10; i++) {
        ekf.predict(1.0);
        ekf.updateGPS(40.0005, -3.7, 5.0);
      }

      // Con covarianza inicial grande (accuracy 35) y mediciones finas,
      // el filtro debe converger claramente hacia la medición.
      expect((ekf.latitude - 40.0005).abs(), lessThan(0.0001));
    });

    test('la velocidad queda acotada a rangos plausibles', () {
      final ekf = EKF2D();
      ekf.initialize(40.0, -3.7, 50.0, 0.0, accuracy: 10.0);
      expect(ekf.velocity, lessThanOrEqualTo(12.0));

      ekf.update(
        latitude: 40.0001,
        longitude: -3.7,
        speed: 99.0,
        heading: 0.0,
        accuracy: 5.0,
      );
      expect(ekf.speed, lessThanOrEqualTo(12.0));
    });

    test('reset devuelve el filtro a no inicializado', () {
      final ekf = EKF2D();
      ekf.initialize(40.0, -3.7, 3.0, 0.0, accuracy: 10.0);
      ekf.reset();

      expect(ekf.isInitialized, isFalse);
      expect(ekf.latitude, 0.0);
      expect(ekf.velocity, 0.0);
    });
  });
}
