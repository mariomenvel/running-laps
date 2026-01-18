/// A standard 1D Kalman filter implementation for smoothing noisy data.
/// Optimized for real-time GPS position smoothing.
class KalmanFilter {
  /// Process noise covariance (Q)
  /// Very small: humans do not teleport.
  double _processNoise;

  /// Base measurement noise (R)
  double _baseMeasurementNoise;

  /// Estimated state (x)
  double? _stateEstimate;

  /// Estimation error covariance (P)
  double _errorCovariance = 1.0;

  KalmanFilter({
    double processNoise = 0.00001,
    double measurementNoise = 5.0,
  })  : _processNoise = processNoise,
        _baseMeasurementNoise = measurementNoise;

  /// Hard reset (call at start of training)
  void reset() {
    _stateEstimate = null;
    _errorCovariance = 1.0;
  }

  /// Updates the filter with a new measurement
  /// [accuracy] should be GPS accuracy in meters
  double filter(
    double measurement, {
    double? accuracy,
  }) {
    // 1️⃣ First measurement → trust it
    if (_stateEstimate == null) {
      _stateEstimate = measurement;
      return measurement;
    }

    // 2️⃣ Measurement noise (variance!)
    final double R = accuracy != null
        ? accuracy * accuracy
        : _baseMeasurementNoise;

    // --- Prediction ---
    final double predictedCovariance =
        _errorCovariance + _processNoise;

    // --- Kalman Gain ---
    final double kalmanGain =
        predictedCovariance / (predictedCovariance + R);

    // --- Correction ---
    _stateEstimate =
        _stateEstimate! +
        kalmanGain * (measurement - _stateEstimate!);

    _errorCovariance =
        (1 - kalmanGain) * predictedCovariance;

    return _stateEstimate!;
  }
}
