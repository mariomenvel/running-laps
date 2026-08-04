import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Cribado de seguridad previo al entrenamiento (PAR-Q abreviado).
///
/// Son las preguntas que cualquier entrenador hace antes de pautar. Aquí
/// cumplen dos funciones: ajustar el arranque del plan y dejar constancia de
/// que se preguntó y de que se avisó — que es lo que un disclaimer enterrado
/// en unos términos no demuestra.
///
/// **Ninguna respuesta bloquea el uso de la app.** Un "sí" solo cambia el
/// consejo que se da y hace que el plan arranque conservador.
enum HealthScreeningQuestion {
  medicalSupervision(
    'medicalSupervision',
    '¿Algún médico te ha dicho que solo hagas ejercicio bajo supervisión '
        'médica?',
  ),
  chestPain(
    'chestPain',
    '¿Has notado dolor en el pecho o mareos al hacer esfuerzo?',
  ),
  heartMedication(
    'heartMedication',
    '¿Tomas medicación para el corazón o la tensión?',
  ),
  activeInjury(
    'activeInjury',
    '¿Tienes ahora una lesión o molestia que empeore al correr?',
  );

  const HealthScreeningQuestion(this.key, this.label);

  /// Clave de persistencia. Fija: cambiarla invalidaría los cribados guardados.
  final String key;

  /// Texto que ve el atleta. En segunda persona y sin jerga clínica: se
  /// responde en diez segundos o no se responde con sinceridad.
  final String label;

  static HealthScreeningQuestion? fromKey(String key) {
    for (final q in HealthScreeningQuestion.values) {
      if (q.key == key) return q;
    }
    return null;
  }
}

/// Respuestas al cribado, con la fecha en que se dieron.
class HealthScreening {
  const HealthScreening({
    required this.answers,
    required this.version,
    this.completedAt,
  });

  final Map<HealthScreeningQuestion, bool> answers;

  /// Versión del cuestionario respondido. Si algún día cambian las preguntas,
  /// esto distingue un cribado hecho con otro texto.
  final String version;

  final DateTime? completedAt;

  /// Todo a "no": el caso mayoritario y el que no necesita ningún aviso.
  static const Map<HealthScreeningQuestion, bool> allNegative = {
    HealthScreeningQuestion.medicalSupervision: false,
    HealthScreeningQuestion.chestPain: false,
    HealthScreeningQuestion.heartMedication: false,
    HealthScreeningQuestion.activeInjury: false,
  };

  bool answer(HealthScreeningQuestion q) => answers[q] ?? false;

  /// Hay al menos un "sí" → se recomienda visto bueno médico y el plan
  /// arranca conservador.
  bool get anyPositive => answers.values.any((v) => v);

  /// Señales cardiovasculares. Se separan de la lesión musculoesquelética
  /// porque el consejo no es el mismo: una molestia en el gemelo se gestiona
  /// bajando carga, un dolor torácico no se gestiona con carga.
  bool get hasCardiacFlag =>
      answer(HealthScreeningQuestion.medicalSupervision) ||
      answer(HealthScreeningQuestion.chestPain) ||
      answer(HealthScreeningQuestion.heartMedication);

  Map<String, dynamic> toMap() => {
        'version': version,
        'anyPositive': anyPositive,
        'hasCardiacFlag': hasCardiacFlag,
        'answers': {
          for (final entry in answers.entries) entry.key.key: entry.value,
        },
      };

  factory HealthScreening.fromMap(Map<String, dynamic> map) {
    final rawAnswers = map['answers'];
    final parsed = <HealthScreeningQuestion, bool>{};
    if (rawAnswers is Map) {
      for (final entry in rawAnswers.entries) {
        final q = HealthScreeningQuestion.fromKey(entry.key.toString());
        if (q != null) parsed[q] = entry.value == true;
      }
    }
    return HealthScreening(
      answers: parsed,
      version: map['version'] as String? ?? 'desconocida',
      completedAt: (map['completedAt'] as Timestamp?)?.toDate(),
    );
  }
}

/// Persiste el cribado en `users/{uid}/settings/healthScreening`.
class HealthScreeningService {
  HealthScreeningService({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  /// Versión del cuestionario actual — subir si cambian las preguntas.
  static const String questionnaireVersion = '2026-08-04';

  String? get currentUserId => FirebaseAuth.instance.currentUser?.uid;

  DocumentReference<Map<String, dynamic>> _doc(String uid) => _db
      .collection('users')
      .doc(uid)
      .collection('settings')
      .doc('healthScreening');

  Future<void> save(Map<HealthScreeningQuestion, bool> answers) async {
    final uid = currentUserId;
    if (uid == null) return;

    final screening = HealthScreening(
      answers: answers,
      version: questionnaireVersion,
    );

    await _doc(uid).set({
      ...screening.toMap(),
      'completedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<HealthScreening?> load() async {
    final uid = currentUserId;
    if (uid == null) return null;
    try {
      final snap = await _doc(uid).get();
      final data = snap.data();
      if (data == null) return null;
      return HealthScreening.fromMap(data);
    } catch (e) {
      debugPrint('[HealthScreening] error leyendo cribado: $e');
      return null;
    }
  }

  Future<bool> hasCompleted() async => (await load()) != null;
}
