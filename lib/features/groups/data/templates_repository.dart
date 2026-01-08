import 'package:cloud_firestore/cloud_firestore.dart';
import 'challenge_models.dart';
import 'enums.dart';

/// Repository para gestión de templates globales de retos
class TemplatesRepository {
  final FirebaseFirestore _firestore;

  TemplatesRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  // ============================================
  // READ
  // ============================================

  /// Lista todos los templates habilitados
  /// Opcionalmente filtra por periodicidad (weekly/monthly)
  Future<List<ChallengeTemplate>> listEnabledTemplates({
    ChallengePeriodicity? periodicity,
  }) async {
    try {
      Query query = _firestore
          .collection('challenge_templates')
          .where('enabled', isEqualTo: true);

      if (periodicity != null) {
        query = query.where('periodicity', isEqualTo: periodicity.toFirestore());
      }

      final snapshot = await query.get();
      
      return snapshot.docs
          .map((doc) => ChallengeTemplate.fromMap(doc.data() as Map<String, dynamic>, templateId: doc.id))
          .toList();
    } catch (e) {
      throw Exception('Error listing enabled templates: $e');
    }
  }

  /// Obtiene un template específico por ID
  Future<ChallengeTemplate?> getTemplate(String templateId) async {
    try {
      final doc = await _firestore
          .collection('challenge_templates')
          .doc(templateId)
          .get();

      if (!doc.exists) return null;

      return ChallengeTemplate.fromMap(doc.data()!, templateId: doc.id);
    } catch (e) {
      throw Exception('Error fetching template: $e');
    }
  }

  // ============================================
  // CREATE (opcional, para admin)
  // ============================================

  /// Crea un nuevo template (útil para testing o admin)
  Future<String> createTemplate(ChallengeTemplate template) async {
    try {
      final docRef = await _firestore
          .collection('challenge_templates')
          .add(template.toMap());
      return docRef.id;
    } catch (e) {
      throw Exception('Error creating template: $e');
    }
  }
}
