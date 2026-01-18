class TrackingState {

    double? latitude;
    double? longitude;

    double velocity;        // m/s
    double heading;         // grados (0–360), -1 si desconocido

    double distanceTotal;   // metros
    double strideLength;    // metros

    DateTime lastTimestamp;

    TrackingState({
        this.latitude,
        this.longitude,
        required this.velocity,
        required this.heading,
        required this.distanceTotal,
        required this.strideLength,
        required this.lastTimestamp,
    });
}

TrackingState createInitialTrackingState() {
    return TrackingState(
        latitude: null,
        longitude: null,
        velocity: 0.0,
        heading: -1.0,
        distanceTotal: 0.0,
        strideLength: 0.75, // conservador
        lastTimestamp: DateTime.now(),
    );
}
