import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart'; // for debugPrint
import '../../../training/data/entrenamiento.dart';
import '../models/challenge_models.dart';
import '../helpers/challenge_helpers.dart';
import '../services/challenge_calculator.dart';
import '../repositories/challenges_repository.dart';
import '../models/enums.dart';

/// Service para sincronizar entrenamientos con el progreso de retos
class TrainingChallengeSyncService {
  final FirebaseFirestore _firestore;
  final ChallengesRepository _challengesRepo;
  final FirebaseAuth _auth;

  TrainingChallengeSyncService({
    FirebaseFirestore? firestore,
    ChallengesRepository? challengesRepo,
    FirebaseAuth? auth,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _challengesRepo = challengesRepo ?? ChallengesRepository(),
        _auth = auth ?? FirebaseAuth.instance;

  // ============================================
  // PUBLIC API
  // ============================================

  /// Callback cuando se guarda un entrenamiento
  /// Actualiza todos los challenges activos del usuario en sus grupos
  Future<void> onTrainingSaved({
    required String uid,
    required Entrenamiento entrenamiento,
    required String trainingId,
    required bool isUpdate,
  }) async {
    final startTime = DateTime.now();
    int challengesProcessedCount = 0;
    
    try {
      // 1. Obtener grupos del usuario
      final groupIds = await _getUserGroupIds(uid);

      if (groupIds.isEmpty) {
        debugPrint('[Sync] No groups for user $uid. Skipped.');
        return;
      }

      // 2. Para cada grupo, procesar challenges
      for (final groupId in groupIds) {
        challengesProcessedCount += await _processGroupChallenges(
          groupId: groupId,
          uid: uid,
          entrenamiento: entrenamiento,
          isUpdate: isUpdate,
        );
      }
      
      final duration = DateTime.now().difference(startTime);
      debugPrint('[Sync] onTrainingSaved: uid=$uid, tid=$trainingId, update=$isUpdate, '
          'groups=${groupIds.length}, challenges=$challengesProcessedCount, '
          'duration=${duration.inMilliseconds}ms');
          
    } catch (e) {
      // Log error but don't fail the training save
      debugPrint('[Sync] ERROR: $e');
      throw Exception('Error syncing training to challenges: $e');
    }
  }

  // ============================================
  // HELPERS - FILTERING
  // ============================================

  /// Verifica si un entrenamiento cumple los filtros de un reto
  bool trainingMatchesFilters(
    Entrenamiento entrenamiento,
    ChallengeFilters filters,
  ) {
    // GPS requirement
    if (filters.requireGps && !entrenamiento.gps) {
      return false;
    }

    // Tags (any of)
    if (filters.tagIdsAny != null && filters.tagIdsAny!.isNotEmpty) {
      if (entrenamiento.tags == null || entrenamiento.tags!.isEmpty) {
        return false;
      }
      // Check intersection
      final hasMatchingTag = filters.tagIdsAny!.any(
        (filterTag) => entrenamiento.tags!.contains(filterTag),
      );
      if (!hasMatchingTag) {
        return false;
      }
    }

    // Distance range
    final distanceM = entrenamiento.distanciaTotalM();
    if (filters.minDistanceM != null && distanceM < filters.minDistanceM!) {
      return false;
    }
    if (filters.maxDistanceM != null && distanceM > filters.maxDistanceM!) {
      return false;
    }

    // RPE range
    final rpe = entrenamiento.rpePromedio();
    if (filters.minRpe != null && rpe < filters.minRpe!) {
      return false;
    }
    if (filters.maxRpe != null && rpe > filters.maxRpe!) {
      return false;
    }

    return true;
  }

  /// Verifica si un entrenamiento está dentro del periodo del reto
  /// endAt es EXCLUSIVO
  bool trainingInPeriod(Entrenamiento entrenamiento, Challenge challenge) {
    final fecha = entrenamiento.fecha;
    return !fecha.isBefore(challenge.startAt) && fecha.isBefore(challenge.endAt);
  }

  /// Calcula el pace (segundos por km) de un entrenamiento
  /// Retorna 0 si la distancia es 0 o muy pequeña
  double computePaceSecPerKm(Entrenamiento entrenamiento) {
    final distanceM = entrenamiento.distanciaTotalM();
    if (distanceM <= 0) return 0;

    final timeSec = entrenamiento.tiempoTotalSec();
    final km = distanceM / 1000.0;
    return timeSec / km;
  }

  // ============================================
  // CORE LOGIC
  // ============================================

  /// Procesa todos los challenges activos de un grupo
  /// Returns number of challenges processed
  Future<int> _processGroupChallenges({
    required String groupId,
    required String uid,
    required Entrenamiento entrenamiento,
    required bool isUpdate,
  }) async {
    int count = 0;
    try {
      // Obtener challenges activos del grupo
      final activeChallenges = await _getActiveChallenges(groupId);

      for (final challenge in activeChallenges) {
        // Verificar si el usuario es participant
        final participant = await _challengesRepo.getParticipant(
          groupId,
          challenge.id,
          uid,
        );

        if (participant == null) {
          // No está opt-in, skip
          continue;
        }

        // Si es update, recomputar desde cero para evitar doble conteo
        // (MVP simple, asumible para ~4 challenges)
        await _recomputeParticipantForChallenge(
          groupId: groupId,
          challengeId: challenge.id,
          uid: uid,
          challenge: challenge,
        );
        count++;
      }
      return count;
    } catch (e) {
      // Continue processing other groups even if one fails
      rethrow;
    }
  }

  /// Recomputa el participant desde cero para un challenge
  /// Consulta todos los entrenamientos del periodo y calcula score
  Future<void> _recomputeParticipantForChallenge({
    required String groupId,
    required String challengeId,
    required String uid,
    required Challenge challenge,
  }) async {
    try {
      debugPrint('[Sync] Recomputing for challenge ${challenge.title} (${challenge.metric})');
      
      // 1. Obtener todos los entrenamientos del usuario en el periodo
      final trainings = await _getTrainingsInPeriod(uid, challenge);
      debugPrint('[Sync]   Found ${trainings.length} trainings in period ${challenge.startAt} to ${challenge.endAt}');

      // 2. Filtrar los que cumplan con los filtros del challenge
      final validTrainings = trainings.where((t) {
        final matches = trainingMatchesFilters(t, challenge.filters);
        if (!matches) {
          debugPrint('[Sync]   Training ${t.id} (${t.fecha}) REJECTED by filters');
        }
        return matches;
      }).toList();
      
      debugPrint('[Sync]   ${validTrainings.length} trainings passed filters');

      // 3. Ordenar por fecha ASC para cálculo correcto de earliestCompletion
      validTrainings.sort((a, b) => a.fecha.compareTo(b.fecha));

      // 4. Obtener participant actual
      var currentParticipant = await _challengesRepo.getParticipant(
        groupId,
        challengeId,
        uid,
      );

      // Si no existe (raro), crearlo placeholder o return
      if (currentParticipant == null) {
        debugPrint('[Sync]   No participant found, skipping');
        return; 
      }

      // 5. Calcular nuevo estado usando lógica pura
      final updatedParticipant = ChallengeCalculator.computeState(
        currentParticipant: currentParticipant,
        validTrainings: validTrainings,
        challenge: challenge,
      );
      
      debugPrint('[Sync]   Computed score: ${updatedParticipant.score}, sessions: ${updatedParticipant.sessions}');

      // 6. Guardar
      await _challengesRepo.upsertParticipant(
        groupId,
        challengeId,
        updatedParticipant,
      );
      
      debugPrint('[Sync]   ✅ Participant updated successfully');
    } catch (e) {
      debugPrint('[Sync]   ❌ ERROR: $e');
      throw Exception('Error recomputing participant: $e');
    }
  }

  // ============================================
  // METRICS COMPUTATION
  // ============================================

  // ============================================
  // DATA ACCESS
  // ============================================

  /// Obtiene los IDs de grupos del usuario
  Future<List<String>> _getUserGroupIds(String uid) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(uid)
          .collection('groups')
          .get();

      return snapshot.docs.map((doc) => doc.id).toList();
    } catch (e) {
      return [];
    }
  }

  /// Obtiene challenges activos de un grupo (snapshot único, no stream)
  Future<List<Challenge>> _getActiveChallenges(String groupId) async {
    try {
      final snapshot = await _firestore
          .collection('groups')
          .doc(groupId)
          .collection('challenges')
          .where('status', isEqualTo: ChallengeStatus.active.toFirestore())
          .get();

      return snapshot.docs
          .map((doc) => Challenge.fromMap(doc.data(), id: doc.id))
          .toList();
    } catch (e) {
      return [];
    }
  }

  /// Obtiene entrenamientos del usuario en el periodo del challenge
  Future<List<Entrenamiento>> _getTrainingsInPeriod(
    String uid,
    Challenge challenge,
  ) async {
    try {
      // Query trainings by date range
      // fecha is stored as ISO string, so we need to compare strings
      final startStr = challenge.startAt.toIso8601String();
      final endStr = challenge.endAt.toIso8601String();

      final snapshot = await _firestore
          .collection('users')
          .doc(uid)
          .collection('trainings')
          .where('fecha', isGreaterThanOrEqualTo: startStr)
          .where('fecha', isLessThan: endStr)
          .get();

      return snapshot.docs
          .map((doc) => Entrenamiento.fromMap(doc.data(), id: doc.id))
          .toList();
    } catch (e) {
      return [];
    }
  }
}



