import 'package:flutter/foundation.dart';
import '../data/admin_repository.dart';
import '../../groups/data/models/challenge_models.dart';
import '../../groups/data/helpers/challenge_helpers.dart';
import 'package:uuid/uuid.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../groups/data/models/enums.dart';

class AdminController extends ChangeNotifier {
  final AdminRepository _repository;
  
  bool _isLoading = false;
  bool get isLoading => _isLoading;

  Map<String, dynamic> _stats = {};
  Map<String, dynamic> get stats => _stats;

  AdminController({AdminRepository? repository})
      : _repository = repository ?? AdminRepository();

  /// Cargar estadísticas del dashboard
  Future<void> loadDashboardStats() async {
    _setLoading(true);
    try {
      _stats = await _repository.getGlobalStats();
    } catch (e) {
      print("Error loading admin stats: $e");
    } finally {
      _setLoading(false);
    }
  }

  /// Crear un nuevo reto global
  Future<bool> createGlobalChallenge({
    required String title,
    required String description, // No usado en modelo actual pero útil para futuro
    required DateTime startAt,
    required DateTime endAt,
    required ChallengeMetric metric,
    required double goalValue,
  }) async {
    _setLoading(true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception("No authenticated user");

      final challengeId = const Uuid().v4();
      
      // Crear objeto Challenge
      // Asumimos valores por defecto sensatos para un reto global simple
      final challenge = Challenge(
        id: challengeId,
        title: title,
        origin: ChallengeOrigin.global, // Importante
        periodKey: "${startAt.year}-${startAt.month}", // Clave simple
        startAt: startAt,
        endAt: endAt,
        status: ChallengeStatus.draft, // Inicia como draft o active según lógica, pongamos draft
        metric: metric,
        aggregation: _getDefaultAggregationForMetric(metric),
        filters: ChallengeFilters(minDistanceM: 0), // Sin filtros extra
        goal: ChallengeGoal(
          kind: _getGoalKindForMetric(metric),
          value: goalValue,
        ),
        tieBreakers: [TieBreakerType.distance, TieBreakerType.time],
        awardsMedals: true,
        awardsBadges: true,
        createdAt: DateTime.now(),
        createdBy: user.uid,
      );

      await _repository.createGlobalChallenge(challenge);
      return true;
    } catch (e) {
      print("Error creating global challenge: $e");
      return false;
    } finally {
      _setLoading(false);
    }
  }

    Stream<List<Challenge>> get globalChallengesStream => _repository.getGlobalChallenges();


  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  ChallengeAggregation _getDefaultAggregationForMetric(ChallengeMetric metric) {
    switch (metric) {
      case ChallengeMetric.distance:
      case ChallengeMetric.time:
      case ChallengeMetric.sessions:
        return ChallengeAggregation.sum;
      case ChallengeMetric.avgPace:
      case ChallengeMetric.bestPace:
        return ChallengeAggregation.best; // O avg
    }
  }

  GoalKind _getGoalKindForMetric(ChallengeMetric metric) {
    switch (metric) {
      case ChallengeMetric.distance: return GoalKind.distance;
      case ChallengeMetric.time: return GoalKind.time;
      case ChallengeMetric.sessions: return GoalKind.sessions;
      case ChallengeMetric.avgPace: return GoalKind.avgPace;
      case ChallengeMetric.bestPace: return GoalKind.bestPace;
    }
  }
}
