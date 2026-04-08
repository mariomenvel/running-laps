import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'user_profile_model.dart';

class ZonesRepository {
  FirebaseFirestore get _db => FirebaseFirestore.instance;

  /// Lee fcMax, fcReposo, birthDate, sex (y resto de campos) del documento
  /// users/{uid}. Devuelve null si el documento no existe.
  Future<UserProfileModel?> getUserProfile(String uid) async {
    try {
      final doc = await _db.collection('users').doc(uid).get();
      if (!doc.exists) return null;
      final data = doc.data();
      if (data == null) return null;
      return UserProfileModel.fromMap(uid, data);
    } catch (e) {
      debugPrint('ZonesRepository.getUserProfile error: $e');
      rethrow;
    }
  }

  /// Escribe solo los campos de configuración de zonas que no sean null.
  /// Usa update() — el documento users/{uid} debe existir previamente.
  /// Campos null en los parámetros se omiten del update para no borrar
  /// valores existentes accidentalmente.
  Future<void> saveFcConfig({
    required String uid,
    int? fcMax,
    int? fcReposo,
    String? birthDate,
    String? sex,
  }) async {
    final Map<String, dynamic> fields = {};
    if (fcMax != null)     fields['fcMax']     = fcMax;
    if (fcReposo != null)  fields['fcReposo']  = fcReposo;
    if (birthDate != null) fields['birthDate'] = birthDate;
    if (sex != null)       fields['sex']       = sex;

    if (fields.isEmpty) return;

    try {
      await _db.collection('users').doc(uid).update(fields);
    } catch (e) {
      debugPrint('ZonesRepository.saveFcConfig error: $e');
      rethrow;
    }
  }
}
