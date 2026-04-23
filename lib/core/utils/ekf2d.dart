import 'dart:math' as math;
import 'package:flutter/foundation.dart';

/// Extended Kalman Filter 2D para tracking GPS de running.
/// Estado: [latitud, longitud, velocidad (m/s), heading (rad)]
/// Fusiona GPS con acelerómetro y giroscopio para trazas precisas.
class EKF2D {
  // ── Process noise (tunable at runtime) ──────────────────────────────────
  double processNoisePosition; // variance for lat/lon state (degrees²)
  double processNoiseVelocity; // variance for velocity state (m/s)²
  double processNoiseHeading;  // variance for heading state (rad)²

  // ── State vector: [lat, lon, vel, heading] ───────────────────────────────
  final List<double> _state = [0.0, 0.0, 0.0, 0.0];

  // ── Error covariance matrix (4×4) ────────────────────────────────────────
  final List<List<double>> _P = [
    [1.0, 0.0, 0.0, 0.0],
    [0.0, 1.0, 0.0, 0.0],
    [0.0, 0.0, 1.0, 0.0],
    [0.0, 0.0, 0.0, 1.0],
  ];

  bool _initialized = false;

  // ── Constants ────────────────────────────────────────────────────────────
  static const double earthRadius    = 6371000.0; // metres
  static const double earthRadiusDeg = 111111.0;  // metres per degree (latitude)

  EKF2D({
    this.processNoisePosition = 1e-5,
    this.processNoiseVelocity = 0.1,
    this.processNoiseHeading  = 0.01,
  });

  // ── Public getters ────────────────────────────────────────────────────────
  double get latitude     => _state[0];
  double get longitude    => _state[1];
  double get velocity     => _state[2];
  double get speed        => _state[2].clamp(0.0, 12.0); // alias con clamp
  double get heading      => _state[3];
  bool   get isInitialized => _initialized;

  // ─────────────────────────────────────────────────────────────────────────
  // Initialize with the first reliable GPS fix
  // accuracy: GPS horizontal accuracy in metres (optional — scales P init)
  // ─────────────────────────────────────────────────────────────────────────
  void initialize(
    double lat,
    double lon,
    double vel,
    double hdg, {
    double accuracy = 10.0,
  }) {
    _state[0] = lat;
    _state[1] = lon;
    _state[2] = vel.clamp(0.0, 12.0);
    _state[3] = _normalizeAngle(hdg);

    // Covarianza inicial basada en accuracy del GPS
    final posVar = (accuracy / earthRadiusDeg) * (accuracy / earthRadiusDeg);
    for (int i = 0; i < 4; i++) {
      for (int j = 0; j < 4; j++) {
        _P[i][j] = i == j
            ? (i < 2 ? posVar : (i == 2 ? 4.0 : 1.0))
            : 0.0;
      }
    }

    _initialized = true;
    debugPrint('[EKF2D] initialized at ($lat, $lon) accuracy=${accuracy}m');
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Predict step — constant-velocity model with IMU fusion
  // dt: segundos desde última actualización
  // gyroZ: velocidad angular del giroscopio (rad/s) — actualiza heading
  // accelMagnitude: magnitud lateral de aceleración — escala ruido de proceso
  // ─────────────────────────────────────────────────────────────────────────
  void predict(double dt, {double gyroZ = 0.0, double accelMagnitude = 0.0}) {
    if (!_initialized || dt <= 0 || dt > 2.0) return;

    final lat = _state[0];
    final vel = _state[2];
    final hdg = _state[3];

    // Position update (degrees)
    final cosLat = math.cos(lat * math.pi / 180.0);
    final dLat   = (vel * math.cos(hdg) * dt) / earthRadiusDeg;
    final dLon   = cosLat.abs() > 1e-10
        ? (vel * math.sin(hdg) * dt) / (earthRadiusDeg * cosLat)
        : 0.0;

    _state[0] = lat + dLat;
    _state[1] = _state[1] + dLon;
    // heading update via giroscopio
    _state[3] = _normalizeAngle(hdg + gyroZ * dt);
    // velocity unchanged (constant model)

    // ── Jacobian F of the motion model (4×4) ────────────────────────────
    final dLon_dLat = cosLat.abs() > 1e-10
        ? (vel * math.sin(hdg) * dt * math.tan(lat * math.pi / 180.0)) /
          (earthRadiusDeg * cosLat)
        : 0.0;
    final safecos = cosLat.abs() > 1e-10 ? cosLat : 1.0;

    final F = [
      [1.0, 0.0,  math.cos(hdg) * dt / earthRadiusDeg, -vel * math.sin(hdg) * dt / earthRadiusDeg],
      [dLon_dLat, 1.0, math.sin(hdg) * dt / (earthRadiusDeg * safecos), vel * math.cos(hdg) * dt / (earthRadiusDeg * safecos)],
      [0.0, 0.0, 1.0, 0.0],
      [0.0, 0.0, 0.0, 1.0],
    ];

    // ── Q adaptativo: más ruido si hay aceleración lateral brusca ───────
    // Restar gravedad para obtener solo aceleración dinámica
    // En recta: ~0.2-0.5 m/s². En curva: ~1-3 m/s²
    final dynamicAccel = (accelMagnitude - 9.81).abs();
    final qScale = 1.0 + (dynamicAccel * 3.0).clamp(0.0, 9.0);
    final Q = [
      [processNoisePosition * qScale, 0.0, 0.0, 0.0],
      [0.0, processNoisePosition * qScale, 0.0, 0.0],
      [0.0, 0.0, processNoiseVelocity * qScale, 0.0],
      [0.0, 0.0, 0.0, processNoiseHeading * qScale],
    ];

    // P = F * P * F^T + Q
    final FP   = _matMul(F, _P);
    final FPFt = _matMul(FP, _transpose(F));
    for (int i = 0; i < 4; i++) {
      for (int j = 0; j < 4; j++) {
        _P[i][j] = FPFt[i][j] + Q[i][j];
      }
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // GPS measurement update — returns corrected [lat, lon]
  // accuracy: GPS horizontal accuracy in metres
  // ─────────────────────────────────────────────────────────────────────────
  List<double> updateGPS(double lat, double lon, double accuracy) {
    if (!_initialized) {
      initialize(lat, lon, 0.0, 0.0);
      return [lat, lon];
    }

    // Measurement noise R (2×2): convert accuracy (m) → degrees²
    final accDeg = accuracy / earthRadiusDeg;
    final R = [
      [accDeg * accDeg, 0.0],
      [0.0,             accDeg * accDeg],
    ];

    // Observation matrix H (2×4): observe lat and lon only
    // H = [[1,0,0,0],[0,1,0,0]]
    final H = [
      [1.0, 0.0, 0.0, 0.0],
      [0.0, 1.0, 0.0, 0.0],
    ];

    // Innovation: y = z - H*x
    final y = [lat - _state[0], lon - _state[1]];

    // S = H*P*H^T + R  (2×2)
    final HP   = _matMul(H, _P);
    final HPHt = _matMul(HP, _transpose(H));
    final S = [
      [HPHt[0][0] + R[0][0], HPHt[0][1] + R[0][1]],
      [HPHt[1][0] + R[1][0], HPHt[1][1] + R[1][1]],
    ];

    // Kalman gain: K = P*H^T * S^-1  (4×2)
    final PHt   = _matMul(_P, _transpose(H));
    final Sinv  = _invert2x2(S);
    final K     = _matMul(PHt, Sinv);

    // State update: x = x + K*y
    for (int i = 0; i < 4; i++) {
      _state[i] += K[i][0] * y[0] + K[i][1] * y[1];
    }
    _state[2] = _state[2].clamp(0.0, 12.0);
    _state[3] = _normalizeAngle(_state[3]);

    // Covariance update: P = (I - K*H) * P
    final KH = _matMul(K, H);
    final IKH = List.generate(4, (i) => List.generate(4, (j) {
      return (i == j ? 1.0 : 0.0) - KH[i][j];
    }));
    final newP = _matMul(IKH, _P);
    for (int i = 0; i < 4; i++) {
      for (int j = 0; j < 4; j++) {
        _P[i][j] = newP[i][j];
      }
    }

    return [_state[0], _state[1]];
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Heading update from GPS speed vector — only when moving (speed > 0.5 m/s)
  // newHeading: radians, 0 = North, clockwise positive
  // ─────────────────────────────────────────────────────────────────────────
  void updateHeading(double newHeading) {
    if (!_initialized) return;

    // Simple scalar Kalman update for heading component only
    final R = processNoiseHeading * 10.0; // measurement noise for heading
    final pHdg = _P[3][3];
    final K = pHdg / (pHdg + R);
    final innovation = _normalizeAngle(newHeading - _state[3]);
    _state[3] = _normalizeAngle(_state[3] + K * innovation);
    _P[3][3] = (1.0 - K) * pHdg;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // update — atajo que combina updateGPS + updateHeading + velocidad GPS
  // Equivalente al método update del spec: fusiona lat, lon, speed, heading
  // ─────────────────────────────────────────────────────────────────────────
  void update({
    required double latitude,
    required double longitude,
    required double speed,
    required double heading,
    required double accuracy,
  }) {
    if (!_initialized) {
      initialize(latitude, longitude, speed, heading, accuracy: accuracy);
      return;
    }
    updateGPS(latitude, longitude, accuracy);
    if (speed > 0.5) {
      updateHeading(heading);
      // Actualizar velocidad con ganancia simple
      final pVel = _P[2][2];
      final R = 1.0; // ±1 m/s medición GPS
      final K = pVel / (pVel + R);
      _state[2] = (_state[2] + K * (speed.clamp(0.0, 12.0) - _state[2]))
          .clamp(0.0, 12.0);
      _P[2][2] = (1.0 - K) * pVel;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Adaptive process noise — mirrors logic in GPSService._processTick()
  // ─────────────────────────────────────────────────────────────────────────
  void setAdaptiveNoise(double gpsAccuracy, double velocityDelta) {
    final accuracyFactor  = (gpsAccuracy / 10.0).clamp(0.5, 5.0);
    final movementFactor  = velocityDelta > 1.0 ? 3.0 : 1.0;
    processNoisePosition  = (1e-5 * accuracyFactor * movementFactor).clamp(1e-7, 1e-3);
    processNoiseVelocity  = (0.1  * movementFactor).clamp(0.01, 1.0);
    processNoiseHeading   = (0.01 * movementFactor).clamp(0.001, 0.1);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Reset — call at the start of each training session
  // ─────────────────────────────────────────────────────────────────────────
  void reset() {
    _state[0] = 0.0;
    _state[1] = 0.0;
    _state[2] = 0.0;
    _state[3] = 0.0;
    for (int i = 0; i < 4; i++) {
      for (int j = 0; j < 4; j++) {
        _P[i][j] = i == j ? 1.0 : 0.0;
      }
    }
    _initialized = false;
    processNoisePosition = 1e-5;
    processNoiseVelocity = 0.1;
    processNoiseHeading  = 0.01;
  }

  // ── Matrix helpers (operate on List<List<double>>) ────────────────────────

  List<List<double>> _matMul(List<List<double>> A, List<List<double>> B) {
    final rows = A.length;
    final cols = B[0].length;
    final inner = B.length;
    return List.generate(rows, (i) => List.generate(cols, (j) {
      double sum = 0.0;
      for (int k = 0; k < inner; k++) sum += A[i][k] * B[k][j];
      return sum;
    }));
  }

  List<List<double>> _transpose(List<List<double>> M) {
    final rows = M.length;
    final cols = M[0].length;
    return List.generate(cols, (i) => List.generate(rows, (j) => M[j][i]));
  }

  /// Invert a 2×2 matrix. Returns identity on singular matrices.
  List<List<double>> _invert2x2(List<List<double>> M) {
    final det = M[0][0] * M[1][1] - M[0][1] * M[1][0];
    if (det.abs() < 1e-20) {
      return [[1.0, 0.0], [0.0, 1.0]]; // fallback: identity
    }
    final invDet = 1.0 / det;
    return [
      [ M[1][1] * invDet, -M[0][1] * invDet],
      [-M[1][0] * invDet,  M[0][0] * invDet],
    ];
  }

  /// Wrap angle to [-π, π]
  double _normalizeAngle(double angle) {
    while (angle >  math.pi) angle -= 2 * math.pi;
    while (angle < -math.pi) angle += 2 * math.pi;
    return angle;
  }
}
