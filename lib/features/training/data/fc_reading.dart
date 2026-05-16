class FcReading {
  final int bpm;
  final DateTime timestamp;

  const FcReading({
    required this.bpm,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() => {
        'bpm': bpm,
        'ts': timestamp.toIso8601String(),
      };

  factory FcReading.fromMap(Map<String, dynamic> m) => FcReading(
        bpm: (m['bpm'] as num).toInt(),
        timestamp: DateTime.parse(m['ts'] as String),
      );
}
