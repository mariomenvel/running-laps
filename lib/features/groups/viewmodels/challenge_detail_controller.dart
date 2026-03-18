import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../data/models/challenge_models.dart';
import '../data/repositories/challenges_repository.dart';
import '../data/repositories/rewards_repository.dart';
import '../data/helpers/challenge_ranking_helper.dart';
import 'package:cloud_firestore/cloud_firestore.dart';


/// ViewModel para la pantalla de detalle del reto
class ChallengeDetailController {
  final String groupId;
  final String challengeId;
  
  final ChallengesRepository _challengesRepo;
  final RewardsRepository _rewardsRepo;
  final FirebaseAuth _auth;

  // ============================================
  // STATE
  // ============================================

  final ValueNotifier<bool> isLoading = ValueNotifier(true);
  final ValueNotifier<String?> error = ValueNotifier(null);
  
  final ValueNotifier<Challenge?> challenge = ValueNotifier(null);
  final ValueNotifier<ChallengeParticipant?> myParticipant = ValueNotifier(null);
  final ValueNotifier<List<ChallengeParticipant>> participants = ValueNotifier([]);
  final ValueNotifier<bool> hasGoalBadge = ValueNotifier(false);

  ChallengeDetailController({
    required this.groupId,
    required this.challengeId,
    ChallengesRepository? challengesRepo,
    RewardsRepository? rewardsRepo,
    FirebaseAuth? auth,
  })  : _challengesRepo = challengesRepo ?? ChallengesRepository(),
        _rewardsRepo = rewardsRepo ?? RewardsRepository(),
        _auth = auth ?? FirebaseAuth.instance;

  // ============================================
  // INITIALIZATION
  // ============================================

  Future<void> init() async {
    isLoading.value = true;
    error.value = null;

    try {
      final uid = _auth.currentUser?.uid;
      if (uid == null) throw Exception('User not authenticated');

      // 1. Cargar challenge
      final c = await _challengesRepo.getChallenge(groupId, challengeId);
      if (c == null) {
        throw Exception('Challenge not found');
      }
      challenge.value = c;

      // 2. Stream My Participant
      _challengesRepo.streamMyParticipant(groupId, challengeId, uid).listen((p) {
        myParticipant.value = p;
      });

      // 3. Stream All Participants & Sort
      _challengesRepo.streamChallengeParticipants(groupId, challengeId).listen((list) async {
        // Enriquecer con perfiles de usuario
        final enriched = await _enrichParticipants(list);
        // Ordenar usando el helper
        final sorted = ChallengeRankingHelper.sortParticipants(enriched, c);
        participants.value = sorted;
      });

      // 4. Stream Badge Status (not applicable for global challenges —
      // they have no badge_history under the groups collection)
      if (groupId != ChallengesRepository.globalSentinel) {
        _rewardsRepo.streamHasGoalCompletedBadge(groupId, uid, challengeId).listen((hasBadge) {
          hasGoalBadge.value = hasBadge;
        });
      }

    } catch (e) {
      error.value = e.toString();
    } finally {
      isLoading.value = false;
    }
  }

  // ============================================
  // HELPERS (UI Logic)
  // ============================================

  /// Calcula el progreso (0.0 a 1.0) hacia el objetivo
  double getProgress() {
    final p = myParticipant.value;
    final c = challenge.value;

    if (p == null || c == null) return 0.0;
    
    // Si el score es 0, no hay progreso (salvo que goal sea 0)
    if (p.score == 0 && c.goal.value > 0) return 0.0;

    final current = p.score;
    final target = c.goal.value;
    
    // Determinar si "menos es mejor" (Pace)
    final lowerIsBetter = ChallengeRankingHelper.isLowerScoreBetter(c.metric);

    if (lowerIsBetter) {
      // Pace: meta es bajar de X.
      // Progreso visual es difícil de representar linealmente si empezamos de infinito.
      // Estrategia MVP: Si cumplió meta -> 1.0. Si no -> 0.5 (o algo intermedio).
      // Mejor: Si tiene score (p.e. 5:00) y meta es 4:30.
      // Podríamos mostrar invertido, pero complejo.
      // Simplificación: Si cumple -> 1.0. Si no cumple -> 0.0 (o proporcional inverso?)
      if (current <= target) return 1.0;
      return 0.0; // Opcional: calcular % cercanía
    } else {
      // Normal (Distancia/Tiempo): current / target
      if (target == 0) return 1.0;
      return (current / target).clamp(0.0, 1.0);
    }
  }

  /// Enriquece la lista de participantes con datos de perfil de la colección 'users'
  Future<List<ChallengeParticipant>> _enrichParticipants(List<ChallengeParticipant> list) async {
    if (list.isEmpty) return [];

    try {
      final List<Future<ChallengeParticipant>> futures = list.map((p) async {
        final userDoc = await FirebaseFirestore.instance.collection('users').doc(p.uid).get();
        if (!userDoc.exists) return p;

        final data = userDoc.data()!;
        return p.copyWith(
          displayName: data['nombre'] ?? 'Usuario',
          photoUrl: data['photoUrl'] ?? data['profileImageUrl'],
          profilePicType: data['profilePicType'] ?? 'none',
          avatarConfig: data['avatarConfig'] as Map<String, dynamic>?,
        );
      }).toList();

      return await Future.wait(futures);
    } catch (e) {
      return list;
    }
  }
  
  bool get isParticipating => myParticipant.value != null;

  void dispose() {
    isLoading.dispose();
    error.dispose();
    challenge.dispose();
    myParticipant.dispose();
    participants.dispose();
    hasGoalBadge.dispose();
  }
}


