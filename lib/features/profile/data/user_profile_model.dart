import 'package:cloud_firestore/cloud_firestore.dart';

/// Modelo del documento users/{uid} en Firestore.
/// Campos opcionales nullable para compatibilidad con documentos existentes.
class UserProfileModel {
  final String uid;
  final String nombre;
  final String email;
  final String? photoUrl;
  final String? profilePicType; // 'photo' | 'avatar'
  final Map<String, dynamic>? avatarConfig;
  final bool? isAdmin;
  final DateTime? createdAt;

  // Contadores agregados
  final int totalSessions;
  final double totalKm;
  final double totalTimeMinutes;
  final String? lastTrainingDate;

  // Zonas de entrenamiento (FCmáx, FC reposo, datos biométricos)
  final int? fcMax;       // FCmáx manual (lpm)
  final int? fcReposo;    // FC en reposo (lpm)
  final String? birthDate; // Fecha de nacimiento ISO8601 solo-fecha: "1990-05-15"
  final String? sex;      // 'M' | 'F' | 'X'

  const UserProfileModel({
    required this.uid,
    required this.nombre,
    required this.email,
    this.photoUrl,
    this.profilePicType,
    this.avatarConfig,
    this.isAdmin,
    this.createdAt,
    this.totalSessions = 0,
    this.totalKm = 0.0,
    this.totalTimeMinutes = 0.0,
    this.lastTrainingDate,
    this.fcMax,
    this.fcReposo,
    this.birthDate,
    this.sex,
  });

  factory UserProfileModel.fromMap(String uid, Map<String, dynamic> map) {
    return UserProfileModel(
      uid: uid,
      nombre: map['nombre'] as String? ?? '',
      email: map['email'] as String? ?? '',
      photoUrl: map['photoUrl'] as String?,
      profilePicType: map['profilePicType'] as String?,
      avatarConfig: map['avatarConfig'] as Map<String, dynamic>?,
      isAdmin: map['isAdmin'] as bool?,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate(),
      totalSessions: (map['totalSessions'] as num?)?.toInt() ?? 0,
      totalKm: (map['totalKm'] as num?)?.toDouble() ?? 0.0,
      totalTimeMinutes: (map['totalTimeMinutes'] as num?)?.toDouble() ?? 0.0,
      lastTrainingDate: map['lastTrainingDate'] as String?,
      fcMax: (map['fcMax'] as num?)?.toInt(),
      fcReposo: (map['fcReposo'] as num?)?.toInt(),
      birthDate: map['birthDate'] as String?,
      sex: map['sex'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'nombre': nombre,
      'email': email,
      'photoUrl': photoUrl,
      'profilePicType': profilePicType,
      'avatarConfig': avatarConfig,
      'isAdmin': isAdmin,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : null,
      'totalSessions': totalSessions,
      'totalKm': totalKm,
      'totalTimeMinutes': totalTimeMinutes,
      'lastTrainingDate': lastTrainingDate,
      'fcMax': fcMax,
      'fcReposo': fcReposo,
      'birthDate': birthDate,
      'sex': sex,
    };
  }

  UserProfileModel copyWith({
    String? nombre,
    String? email,
    String? photoUrl,
    String? profilePicType,
    Map<String, dynamic>? avatarConfig,
    bool? isAdmin,
    DateTime? createdAt,
    int? totalSessions,
    double? totalKm,
    double? totalTimeMinutes,
    String? lastTrainingDate,
    Object? fcMax = _sentinel,
    Object? fcReposo = _sentinel,
    Object? birthDate = _sentinel,
    Object? sex = _sentinel,
  }) {
    return UserProfileModel(
      uid: uid,
      nombre: nombre ?? this.nombre,
      email: email ?? this.email,
      photoUrl: photoUrl ?? this.photoUrl,
      profilePicType: profilePicType ?? this.profilePicType,
      avatarConfig: avatarConfig ?? this.avatarConfig,
      isAdmin: isAdmin ?? this.isAdmin,
      createdAt: createdAt ?? this.createdAt,
      totalSessions: totalSessions ?? this.totalSessions,
      totalKm: totalKm ?? this.totalKm,
      totalTimeMinutes: totalTimeMinutes ?? this.totalTimeMinutes,
      lastTrainingDate: lastTrainingDate ?? this.lastTrainingDate,
      fcMax: identical(fcMax, _sentinel) ? this.fcMax : fcMax as int?,
      fcReposo: identical(fcReposo, _sentinel) ? this.fcReposo : fcReposo as int?,
      birthDate: identical(birthDate, _sentinel) ? this.birthDate : birthDate as String?,
      sex: identical(sex, _sentinel) ? this.sex : sex as String?,
    );
  }
}

// Sentinel para distinguir null explícito de "no pasado" en copyWith
const Object _sentinel = Object();
