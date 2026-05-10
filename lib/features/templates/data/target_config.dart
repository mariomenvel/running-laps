enum HeartRateZone { z1, z2, z3, z4, z5 }

class TargetConfig {
  final int? paceMinSecPerKm;
  final int? paceMaxSecPerKm;
  final HeartRateZone? zone;
  final int? rpe;
  final int? fcMaxPercent;

  const TargetConfig({
    this.paceMinSecPerKm,
    this.paceMaxSecPerKm,
    this.zone,
    this.rpe,
    this.fcMaxPercent,
  }) : assert(
          paceMinSecPerKm == null ||
              paceMaxSecPerKm == null ||
              paceMinSecPerKm <= paceMaxSecPerKm,
          'paceMin must be <= paceMax',
        ),
       assert(rpe == null || (rpe >= 1 && rpe <= 10), 'rpe must be 1–10'),
       assert(
         fcMaxPercent == null || (fcMaxPercent >= 1 && fcMaxPercent <= 100),
         'fcMaxPercent must be 1–100',
       );

  Map<String, dynamic> toMap() {
    return {
      if (paceMinSecPerKm != null) 'paceMinSecPerKm': paceMinSecPerKm,
      if (paceMaxSecPerKm != null) 'paceMaxSecPerKm': paceMaxSecPerKm,
      if (zone != null) 'zone': zone!.name,
      if (rpe != null) 'rpe': rpe,
      if (fcMaxPercent != null) 'fcMaxPercent': fcMaxPercent,
    };
  }

  factory TargetConfig.fromMap(Map<String, dynamic> map) {
    return TargetConfig(
      paceMinSecPerKm: map['paceMinSecPerKm'] as int?,
      paceMaxSecPerKm: map['paceMaxSecPerKm'] as int?,
      zone: map['zone'] != null
          ? HeartRateZone.values.byName(map['zone'] as String)
          : null,
      rpe: map['rpe'] as int?,
      fcMaxPercent: map['fcMaxPercent'] as int?,
    );
  }

  TargetConfig copyWith({
    Object? paceMinSecPerKm = _sentinel,
    Object? paceMaxSecPerKm = _sentinel,
    Object? zone = _sentinel,
    Object? rpe = _sentinel,
    Object? fcMaxPercent = _sentinel,
  }) {
    return TargetConfig(
      paceMinSecPerKm: paceMinSecPerKm == _sentinel
          ? this.paceMinSecPerKm
          : paceMinSecPerKm as int?,
      paceMaxSecPerKm: paceMaxSecPerKm == _sentinel
          ? this.paceMaxSecPerKm
          : paceMaxSecPerKm as int?,
      zone: zone == _sentinel ? this.zone : zone as HeartRateZone?,
      rpe: rpe == _sentinel ? this.rpe : rpe as int?,
      fcMaxPercent: fcMaxPercent == _sentinel
          ? this.fcMaxPercent
          : fcMaxPercent as int?,
    );
  }
}

const Object _sentinel = Object();
