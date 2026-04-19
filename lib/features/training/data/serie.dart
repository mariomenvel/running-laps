import 'package:cloud_firestore/cloud_firestore.dart';

class Serie {
  final double tiempoSec;   // tiempo activo de la serie (Secundos)
  final int distanciaM;     // distancia recorrida en metros (>= 1 para ritmo)
  final int descansoSec;    // descanso en Secundos (obligatorio; si no hay, 0)
  final double rpe;         // escala 1..10 (puede ser decimal)
  
  // Campos GPS opcionales
  final bool? usedGps;           // ¿Se activó GPS para esta serie?
  final bool? usedGpsDistance;   // ¿Se eligió la distancia GPS al guardar?
  final List<Map<String, dynamic>>? gpsPoints;  // Puntos GPS del recorrido
  
  // New: timestamp for when series finished
  final DateTime? finishedAt;

  // FC media durante la serie (bpm), null si no hay pulsómetro
  final double? fcMedia;

  Serie({
    required this.tiempoSec,
    required this.distanciaM,
    required this.descansoSec,
    required this.rpe,
    this.usedGps,
    this.usedGpsDistance,
    this.gpsPoints,
    this.finishedAt,
    this.fcMedia,
  }):assert(tiempoSec >= 0),
     assert(distanciaM >= 0),
     assert(descansoSec >= 0),
     assert(rpe >= 1 && rpe <= 10);


  /// Secundos por kilómetro (ritmo) como entero.
  /// Lanza excepción si distancia es 0 o negativa.
  int ritmoSecPorKm() {
    if (distanciaM <= 0) {
      throw StateError('distanciaM debe ser > 0 para calcular ritmo');
    }
    final double km = distanciaM / 1000.0;
    final double secPerKm = tiempoSec / km;
    return secPerKm.round(); // o .toInt() si prefieres truncar
  }


  /// Ritmo formateado "mm:ss /km"
  String ritmoTexto() {
    final int secKm = ritmoSecPorKm();
    final int mm = secKm ~/ 60;
    final int ss = secKm % 60;
    final String ss2 = ss < 10 ? '0' + ss.toString() : ss.toString();
    return mm.toString() + ':' + ss2 + ' /km';
  }


  Map<String, dynamic> toMap() {
    // Por defecto NO guardo el ritmo; es derivado.
    // Si quieres guardarlo también para consultas rápidas:
    // 'ritmoSecKm': ritmoSecPorKm(),
    return <String, dynamic>{
      'tiempoSec': tiempoSec,
      'distanciaM': distanciaM,
      'descansoSec': descansoSec,
      'rpe': rpe,
      if (usedGps != null) 'usedGps': usedGps,
      if (usedGpsDistance != null) 'usedGpsDistance': usedGpsDistance,
      if (gpsPoints != null) 'gpsPoints': gpsPoints,
      if (finishedAt != null) 'finishedAt': finishedAt!.toIso8601String(),
      if (fcMedia != null) 'fcMedia': fcMedia,
    };
  }


  static Serie fromMap(Map<String, dynamic> map) {
    return Serie(
      tiempoSec: (map['tiempoSec'] as num).toDouble(),
      distanciaM: (map['distanciaM'] as num).toInt(),
      descansoSec: (map['descansoSec'] as num).toInt(),
      rpe: (map['rpe'] as num).toDouble(),
      usedGps: map['usedGps'] as bool?,
      usedGpsDistance: map['usedGpsDistance'] as bool?,
      gpsPoints: map['gpsPoints'] != null 
        ? List<Map<String, dynamic>>.from(map['gpsPoints'] as List)
        : null,
      finishedAt: () {
        final rawFinished = map['finishedAt'];
        DateTime? finishedAt;
        if (rawFinished is String) {
          finishedAt = DateTime.tryParse(rawFinished);
        } else if (rawFinished is Timestamp) {
          finishedAt = rawFinished.toDate();
        } else if (rawFinished is int) {
          finishedAt = DateTime.fromMillisecondsSinceEpoch(rawFinished);
        }
        return finishedAt;
      }(),
      fcMedia: (map['fcMedia'] as num?)?.toDouble(),
    );
  }

  Serie copyWith({
    double? tiempoSec,
    int? distanciaM,
    int? descansoSec,
    double? rpe,
    Object? usedGps         = _sentinel,
    Object? usedGpsDistance = _sentinel,
    Object? gpsPoints       = _sentinel,
    Object? finishedAt      = _sentinel,
    Object? fcMedia         = _sentinel,
  }) {
    return Serie(
      tiempoSec:       tiempoSec       ?? this.tiempoSec,
      distanciaM:      distanciaM      ?? this.distanciaM,
      descansoSec:     descansoSec     ?? this.descansoSec,
      rpe:             rpe             ?? this.rpe,
      usedGps:         identical(usedGps, _sentinel)
          ? this.usedGps         : usedGps as bool?,
      usedGpsDistance: identical(usedGpsDistance, _sentinel)
          ? this.usedGpsDistance : usedGpsDistance as bool?,
      gpsPoints:       identical(gpsPoints, _sentinel)
          ? this.gpsPoints       : gpsPoints as List<Map<String, dynamic>>?,
      finishedAt:      identical(finishedAt, _sentinel)
          ? this.finishedAt      : finishedAt as DateTime?,
      fcMedia:         identical(fcMedia, _sentinel)
          ? this.fcMedia         : fcMedia as double?,
    );
  }
}

const Object _sentinel = Object();




