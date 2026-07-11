import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Consentimiento explícito para el tratamiento de datos de salud
/// (frecuencia cardíaca — categoría especial, art. 9 RGPD).
///
/// La app lo exige antes de conectar un pulsómetro por primera vez
/// (heart_rate_monitor_view) y el usuario puede retirarlo desde la misma
/// pantalla. Se persiste en users/{uid}/settings/healthConsent para que
/// sea auditable y sobreviva a reinstalaciones.
class HealthConsentService {
  // Inyección opcional para tests (fake_cloud_firestore); el default es
  // el comportamiento de producción.
  HealthConsentService({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  /// Versión de la política aceptada — actualizar si cambia el texto del
  /// consentimiento de forma sustancial (obligaría a re-consentir).
  static const String policyVersion = '2026-07-11';

  /// Estado reactivo compartido: null = aún no cargado de Firestore.
  static final ValueNotifier<bool?> consentGranted = ValueNotifier(null);

  /// Uid del usuario autenticado. Sobrescribible en tests.
  String? get currentUserId => FirebaseAuth.instance.currentUser?.uid;

  DocumentReference<Map<String, dynamic>> _doc(String uid) => _db
      .collection('users')
      .doc(uid)
      .collection('settings')
      .doc('healthConsent');

  /// Lee el consentimiento persistido y actualiza [consentGranted].
  Future<bool> hasConsent() async {
    final uid = currentUserId;
    if (uid == null) return false;
    try {
      final snap = await _doc(uid).get();
      final granted = snap.data()?['granted'] == true;
      consentGranted.value = granted;
      return granted;
    } catch (e) {
      debugPrint('[HealthConsent] error leyendo consentimiento: $e');
      return consentGranted.value ?? false;
    }
  }

  /// Registra el consentimiento explícito del usuario.
  Future<void> grant() async {
    final uid = currentUserId;
    if (uid == null) return;
    await _doc(uid).set({
      'granted': true,
      'grantedAt': FieldValue.serverTimestamp(),
      'policyVersion': policyVersion,
    }, SetOptions(merge: true));
    consentGranted.value = true;
  }

  /// Retira el consentimiento. El caller debe además desconectar/olvidar el
  /// pulsómetro para que deje de recogerse FC (ver heart_rate_monitor_view).
  Future<void> revoke() async {
    final uid = currentUserId;
    if (uid == null) return;
    await _doc(uid).set({
      'granted': false,
      'revokedAt': FieldValue.serverTimestamp(),
      'policyVersion': policyVersion,
    }, SetOptions(merge: true));
    consentGranted.value = false;
  }
}
