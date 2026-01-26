import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../data/models/group_models.dart';
import '../data/models/challenge_models.dart';
import '../data/models/enums.dart';
import '../data/repositories/groups_repository.dart';
import '../data/repositories/challenges_repository.dart';
import '../data/repositories/group_prefs_repository.dart';
import '../data/repositories/rewards_repository.dart';
import '../data/services/ensure_auto_challenges_service.dart';
import '../data/services/auto_join_service.dart';
import '../data/services/challenge_finalize_service.dart';
import '../data/repositories/group_detail_repository.dart';
import '../data/models/group_stats_model.dart';

/// ViewModel para la pantalla de retos del grupo
class GroupChallengesController {
  final String groupId;
  final GroupsRepository _groupsRepo;
  final ChallengesRepository _challengesRepo;
  final GroupPrefsRepository _prefsRepo;
  final RewardsRepository _rewardsRepo;
  final EnsureAutoChallengesService _ensureService;
  final AutoJoinService _autoJoinService;
  final ChallengeFinalizeService _finalizeService;
  final GroupDetailRepository _detailRepo;
  final FirebaseAuth _auth;

  // ============================================
  // STATE (ValueNotifiers)
  // ============================================

  final ValueNotifier<bool> isLoading = ValueNotifier(false);
  final ValueNotifier<Group?> group = ValueNotifier(null);
  final ValueNotifier<List<Challenge>> activeChallenges = ValueNotifier([]);
  final ValueNotifier<GroupPrefs?> prefs = ValueNotifier(null);
  final ValueNotifier<bool> showAutoJoinPrompt = ValueNotifier(false);
  final ValueNotifier<String?> error = ValueNotifier(null);
  final ValueNotifier<List<GroupMemberStats>> members = ValueNotifier([]);

  // Map de participantes por challenge (para saber si el usuario está unido)
  final ValueNotifier<Map<String, ChallengeParticipant?>> myParticipations =
      ValueNotifier({});

  // Set de IDs de challenges donde se ha obtenido el badge "Objetivo logrado"
  final ValueNotifier<Set<String>> myCompletedChallengeIds = ValueNotifier({});

  GroupChallengesController({
    required this.groupId,
    GroupsRepository? groupsRepo,
    ChallengesRepository? challengesRepo,
    GroupPrefsRepository? prefsRepo,
    RewardsRepository? rewardsRepo,
    EnsureAutoChallengesService? ensureService,
    AutoJoinService? autoJoinService,
    ChallengeFinalizeService? finalizeService,
    FirebaseAuth? auth,
  })  : _groupsRepo = groupsRepo ?? GroupsRepository(),
        _challengesRepo = challengesRepo ?? ChallengesRepository(),
        _prefsRepo = prefsRepo ?? GroupPrefsRepository(),
        _rewardsRepo = rewardsRepo ?? RewardsRepository(),
        _ensureService = ensureService ?? EnsureAutoChallengesService(),
        _autoJoinService = autoJoinService ?? AutoJoinService(),
        _finalizeService = finalizeService ?? ChallengeFinalizeService(),
        _detailRepo = GroupDetailRepository(),
        _auth = auth ?? FirebaseAuth.instance;

  // ============================================
  // INITIALIZATION
  // ============================================

  /// Inicializa el controller
  Future<void> init() async {
    isLoading.value = true;
    error.value = null;

    try {
      final uid = _auth.currentUser?.uid;
      if (uid == null) {
        throw Exception('User not authenticated');
      }

      // 1. Cargar grupo
      _groupsRepo.streamGroup(groupId).listen((g) {
        group.value = g;
      });

      // 2. Cargar preferencias
      final userPrefs = await _prefsRepo.getPrefs(groupId, uid);
      prefs.value = userPrefs;

      if (!userPrefs.askedAutoJoin) {
        showAutoJoinPrompt.value = true;
      }

      // 4. Finalizar retos expirados y otorgar recompensas (async fire-and-forget)
      _finalizeService
          .finalizeExpiredChallengesForGroup(groupId)
          .catchError((e) {

      });

      // 5. Asegurar retos automáticos del periodo actual
      final autoChallengeIds = await _ensureService.ensureAutoChallengesForGroup(
        groupId,
        DateTime.now(),
      );

      // 5. Si tiene auto-join habilitado, unirse automáticamente
      if (userPrefs.autoJoinTemplates) {
        await _autoJoinService.ensureUserAutoJoinForAutoChallenges(
          groupId,
          autoChallengeIds,
          DateTime.now(),
          uid: uid,
        );
      }

      // 6. Stream de retos activos
      _challengesRepo.streamActiveChallenges(groupId).listen((challenges) {
        activeChallenges.value = challenges;
        _loadMyParticipations(uid, challenges);
      });

      // 7. Stream de mis badges para saber cuáles he completado
      _rewardsRepo.streamMyBadgeHistory(groupId, uid).listen((history) {
        final completedIds = history
            .where((entry) => entry.badge == BadgeType.goalCompleted)
            .map((entry) => entry.challengeId)
            .toSet();
        myCompletedChallengeIds.value = completedIds;
      });

      // 8. Cargar miembros (Async)
      _loadMembers();
    } catch (e) {
      error.value = e.toString();
    } finally {
      isLoading.value = false;
    }
  }

  /// Carga las participaciones del usuario en los retos activos
  Future<void> _loadMyParticipations(
    String uid,
    List<Challenge> challenges,
  ) async {
    try {
      final participationsMap = <String, ChallengeParticipant?>{};

      for (final challenge in challenges) {
        final participant = await _challengesRepo.getParticipant(
          groupId,
          challenge.id,
          uid,
        );
        participationsMap[challenge.id] = participant;
      }

      myParticipations.value = participationsMap;
    } catch (e) {
    }
  }

  // ============================================
  // ACTIONS
  // ============================================

  /// Guarda la elección del usuario sobre auto-join
  Future<void> setAutoJoinChoice(bool enabled) async {
    try {
      final uid = _auth.currentUser?.uid;
      if (uid == null) return;

      isLoading.value = true;

      // Guardar preferencias
      final newPrefs = GroupPrefs(
        uid: uid,
        askedAutoJoin: true,
        autoJoinTemplates: enabled,
      );

      await _prefsRepo.upsertPrefs(groupId, newPrefs);
      prefs.value = newPrefs;

      // Ocultar prompt
      showAutoJoinPrompt.value = false;

      // Si habilitó auto-join, unirse ahora a los retos automáticos actuales
      if (enabled) {
        // Obtener IDs de retos automáticos actuales
        final autoChallengeIds = activeChallenges.value
            .where((c) => c.origin == ChallengeOrigin.template)
            .map((c) => c.id)
            .toList();

        await _autoJoinService.ensureUserAutoJoinForAutoChallenges(
          groupId,
          autoChallengeIds,
          DateTime.now(),
          uid: uid,
        );

        // Recargar participaciones
        await _loadMyParticipations(uid, activeChallenges.value);
      }
    } catch (e) {
      error.value = e.toString();
    } finally {
      isLoading.value = false;
    }
  }

  /// Une al usuario a un reto específico
  Future<void> joinChallenge(String challengeId) async {
    try {
      final uid = _auth.currentUser?.uid;
      if (uid == null) return;

      isLoading.value = true;

      await _autoJoinService.joinChallenge(
        groupId,
        challengeId,
        uid,
        DateTime.now(),
      );

      // Recargar participaciones
      await _loadMyParticipations(uid, activeChallenges.value);
    } catch (e) {
      error.value = e.toString();
    } finally {
      isLoading.value = false;
    }
  }

  // ============================================
  // HELPERS
  // ============================================

  /// Verifica si el usuario actual está participando en un reto
  bool isParticipating(String challengeId) {
    return myParticipations.value[challengeId] != null;
  }

  // ============================================
  // CLEANUP
  // ============================================

  void dispose() {
    isLoading.dispose();
    group.dispose();
    activeChallenges.dispose();
    prefs.dispose();
    showAutoJoinPrompt.dispose();
    myCompletedChallengeIds.dispose();
    members.dispose();
  }

  Future<void> _loadMembers() async {
    try {
      final stats = await _detailRepo.fetchMemberStats(groupId, onlyThisMonth: false);
      members.value = stats;
    } catch (e) {

    }
  }
}



