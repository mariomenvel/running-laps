import 'package:firebase_auth/firebase_auth.dart';
import 'challenges_repository.dart';
import 'group_prefs_repository.dart';
import 'challenge_models.dart';

/// Service para auto-unir usuarios a retos automáticos
class AutoJoinService {
  final ChallengesRepository _challengesRepo;
  final GroupPrefsRepository _prefsRepo;
  final FirebaseAuth _auth;

  AutoJoinService({
    ChallengesRepository? challengesRepo,
    GroupPrefsRepository? prefsRepo,
    FirebaseAuth? auth,
  })  : _challengesRepo = challengesRepo ?? ChallengesRepository(),
        _prefsRepo = prefsRepo ?? GroupPrefsRepository(),
        _auth = auth ?? FirebaseAuth.instance;

  /// Auto-une al usuario actual a los retos automáticos si tiene autoJoinTemplates=true
  /// Retorna la cantidad de retos a los que se unió
  Future<int> ensureUserAutoJoinForAutoChallenges(
    String groupId,
    List<String> autoChallengeIds,
    DateTime now, {
    String? uid, // Opcional, si no se pasa usa el usuario actual
  }) async {
    try {
      // Obtener UID (usar el pasado o el usuario actual)
      final userId = uid ?? _auth.currentUser?.uid;
      if (userId == null) {
        throw Exception('No authenticated user found');
      }

      // Obtener preferencias del usuario
      final prefs = await _prefsRepo.getPrefs(groupId, userId);

      // Si no tiene auto-join habilitado, no hacer nada
      if (!prefs.autoJoinTemplates) {
        return 0;
      }

      // Auto-unirse a cada reto automático
      int joinedCount = 0;

      for (final challengeId in autoChallengeIds) {
        // Verificar si ya es participante
        final existingParticipant = await _challengesRepo.getParticipant(
          groupId,
          challengeId,
          userId,
        );

        if (existingParticipant == null) {
          // Crear participante nuevo
          final participant = ChallengeParticipant(
            uid: userId,
            joinedAt: now,
            lastUpdatedAt: now,
            score: 0,
            distanceM: 0,
            timeSec: 0,
            sessions: 0,
          );

          await _challengesRepo.upsertParticipant(
            groupId,
            challengeId,
            participant,
          );

          joinedCount++;
        }
      }

      return joinedCount;
    } catch (e) {
      throw Exception('Error auto-joining challenges: $e');
    }
  }

  /// Une manualmente a un usuario a un reto específico
  Future<void> joinChallenge(
    String groupId,
    String challengeId,
    String uid,
    DateTime now,
  ) async {
    try {
      // Verificar si ya es participante
      final existingParticipant = await _challengesRepo.getParticipant(
        groupId,
        challengeId,
        uid,
      );

      if (existingParticipant != null) {
        // Ya es participante, no hacer nada
        return;
      }

      // Crear participante
      final participant = ChallengeParticipant(
        uid: uid,
        joinedAt: now,
        lastUpdatedAt: now,
        score: 0,
        distanceM: 0,
        timeSec: 0,
        sessions: 0,
      );

      await _challengesRepo.upsertParticipant(
        groupId,
        challengeId,
        participant,
      );
    } catch (e) {
      throw Exception('Error joining challenge: $e');
    }
  }
}
