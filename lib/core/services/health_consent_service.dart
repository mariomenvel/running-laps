import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Finalidad concreta para la que el usuario autoriza el tratamiento de sus
/// datos de salud.
///
/// El art. 9 RGPD exige consentimiento explícito **para fines determinados**,
/// no un "sí" genérico a todo. Por eso el consentimiento se pide por ámbito y
/// se puede retirar por ámbito: quien quiere que el Coach IA le planifique no
/// tiene por qué querer, además, que la app guarde su pulso.
enum HealthConsentScope {
  /// Frecuencia cardíaca del pulsómetro: zonas, medias por serie, recuperación.
  /// Se pide en `heart_rate_monitor_view` antes del primer escaneo.
  heartRate('heartRate'),

  /// Datos de salud que el Coach IA envía a OpenRouter para generar el plan:
  /// molestias y lesiones en texto libre, FCmáx/FCrep, edad y sexo biológico.
  /// Se pide en el último paso del onboarding del Coach.
  aiCoach('aiCoach');

  const HealthConsentScope(this.key);

  /// Clave con la que se persiste en Firestore. Fija: cambiarla borraría de
  /// facto el consentimiento de todo el mundo.
  final String key;
}

/// Se intentó tratar datos de salud sin el consentimiento del ámbito.
///
/// Es un tipo propio para que la UI pueda distinguirlo de un fallo de red y
/// ofrecer el consentimiento en vez de un "error al generar el plan".
class HealthConsentRequiredException implements Exception {
  const HealthConsentRequiredException(this.scope);

  final HealthConsentScope scope;

  @override
  String toString() =>
      'Falta el consentimiento de datos de salud (${scope.key}).';
}

/// Consentimiento explícito para el tratamiento de datos de salud
/// (categoría especial, art. 9 RGPD).
///
/// Se persiste en `users/{uid}/settings/healthConsent` para que sea auditable
/// y sobreviva a reinstalaciones. Cada ámbito guarda su propia marca de tiempo
/// y la versión de política aceptada.
class HealthConsentService {
  // Inyección opcional para tests (fake_cloud_firestore); el default es
  // el comportamiento de producción.
  HealthConsentService({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  /// Versión de la política aceptada — actualizar si cambia el texto del
  /// consentimiento de forma sustancial (obligaría a re-consentir).
  ///
  /// 2026-08-04: se añade el ámbito `aiCoach`. El texto del pulsómetro no
  /// cambió, así que a quien ya lo aceptó no se le vuelve a preguntar.
  static const String policyVersion = '2026-08-04';

  /// Estado reactivo por ámbito: null = aún no cargado de Firestore.
  static final Map<HealthConsentScope, ValueNotifier<bool?>> _notifiers = {
    for (final scope in HealthConsentScope.values)
      scope: ValueNotifier<bool?>(null),
  };

  /// Notificador del ámbito, para pintar el estado sin volver a Firestore.
  static ValueNotifier<bool?> grantedNotifier(HealthConsentScope scope) =>
      _notifiers[scope]!;

  /// Uid del usuario autenticado. Sobrescribible en tests.
  String? get currentUserId => FirebaseAuth.instance.currentUser?.uid;

  DocumentReference<Map<String, dynamic>> _doc(String uid) => _db
      .collection('users')
      .doc(uid)
      .collection('settings')
      .doc('healthConsent');

  /// Lee el consentimiento persistido de [scope] y actualiza su notificador.
  ///
  /// [uid] permite consultarlo para un usuario concreto (lo necesita el
  /// planificador semanal, que recibe el uid por parámetro en vez de leerlo de
  /// la sesión). El notificador solo se toca si es el usuario en sesión.
  Future<bool> hasConsent(HealthConsentScope scope, {String? uid}) async {
    final userId = uid ?? currentUserId;
    if (userId == null) return false;
    try {
      final snap = await _doc(userId).get();
      final granted = _readScope(snap.data(), scope);
      if (userId == currentUserId) grantedNotifier(scope).value = granted;
      return granted;
    } catch (e) {
      debugPrint('[HealthConsent] error leyendo consentimiento: $e');
      // Fail-closed: ante un error de lectura no se asume consentimiento que
      // no consta. Solo vale lo que ya se hubiera leído en esta sesión.
      if (userId != currentUserId) return false;
      return grantedNotifier(scope).value ?? false;
    }
  }

  bool _readScope(Map<String, dynamic>? data, HealthConsentScope scope) {
    if (data == null) return false;

    final scopes = data['scopes'];
    if (scopes is Map) {
      final entry = scopes[scope.key];
      if (entry is Map) return entry['granted'] == true;
    }

    // Compat: hasta el 4 ago 2026 solo existía el consentimiento del
    // pulsómetro y se guardaba como un booleano suelto en la raíz del
    // documento. Quien ya lo dio no debe volver a ver el diálogo.
    if (scope == HealthConsentScope.heartRate) return data['granted'] == true;

    return false;
  }

  /// Registra el consentimiento explícito del usuario para [scope].
  Future<void> grant(HealthConsentScope scope) => _write(scope, true);

  /// Retira el consentimiento de [scope]. El caller debe además cortar la
  /// recogida de datos correspondiente (p. ej. olvidar el pulsómetro).
  Future<void> revoke(HealthConsentScope scope) => _write(scope, false);

  Future<void> _write(HealthConsentScope scope, bool granted) async {
    final uid = currentUserId;
    if (uid == null) return;

    final entry = <String, dynamic>{
      'granted': granted,
      'policyVersion': policyVersion,
    };
    // Se conservan ambas marcas: para una reclamación importa tanto cuándo lo
    // dio como cuándo lo retiró, y `merge` no borra la que no se toca.
    entry[granted ? 'grantedAt' : 'revokedAt'] = FieldValue.serverTimestamp();

    await _doc(uid).set({
      'scopes': {scope.key: entry},
      // El booleano de la raíz se mantiene sincronizado para el pulsómetro:
      // si esta versión se revierte, la anterior sigue leyendo el
      // consentimiento en vez de volver a pedirlo.
      if (scope == HealthConsentScope.heartRate) 'granted': granted,
    }, SetOptions(merge: true));

    grantedNotifier(scope).value = granted;
  }
}
