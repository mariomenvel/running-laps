import 'package:flutter/material.dart';
// Force reload
import '../data/admin_repository.dart';
import '../../groups/data/models/challenge_models.dart';
import '../../groups/data/helpers/challenge_helpers.dart';
import 'package:uuid/uuid.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../groups/data/models/enums.dart';
import '../../../core/services/pdf_generator_service.dart';
import 'package:printing/printing.dart';


enum AdminDateFilter { week, month, year, all, custom }

class AdminController extends ChangeNotifier {
  final AdminRepository _repository;
  
  bool _isLoading = false;
  bool get isLoading => _isLoading;

  Map<String, dynamic> _stats = {};
  Map<String, dynamic> get stats => _stats;

  AdminDateFilter _currentFilter = AdminDateFilter.all;
  AdminDateFilter get currentFilter => _currentFilter;

  DateTimeRange? _customRange;
  DateTimeRange? get customRange => _customRange;

  AdminController({AdminRepository? repository})
      : _repository = repository ?? AdminRepository();

  /// Cambiar filtro de fecha y recargar
  void setDateFilter(AdminDateFilter filter) {
    if (filter != AdminDateFilter.custom) {
      _currentFilter = filter;
      _customRange = null; 
      loadDashboardStats();
    } else {
      _currentFilter = filter;
    }
  }

  /// Establecer rango personalizado
  void setCustomDateRange(DateTimeRange range) {
    _currentFilter = AdminDateFilter.custom;
    _customRange = range;
    loadDashboardStats();
  }

  /// Cargar estadísticas del dashboard
  Future<void> loadDashboardStats() async {
    _setLoading(true);
    try {
      DateTime? startDate;
      DateTime? endDate;
      final now = DateTime.now();
      
      switch (_currentFilter) {
        case AdminDateFilter.week:
          startDate = now.subtract(const Duration(days: 7));
          break;
        case AdminDateFilter.month:
          startDate = now.subtract(const Duration(days: 30));
          break;
        case AdminDateFilter.year:
          startDate = now.subtract(const Duration(days: 365));
          break;
        case AdminDateFilter.all:
          startDate = null;
          break;
        case AdminDateFilter.custom:
           if (_customRange != null) {
             startDate = _customRange!.start;
             endDate = _customRange!.end;
             // Ajustar fin del día para endDate
             endDate = DateTime(endDate.year, endDate.month, endDate.day, 23, 59, 59);
           }
          break;
      }
      
      _stats = await _repository.getGlobalStats(startDate: startDate, endDate: endDate);
    } catch (e) {
      // Error
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
        filters: const ChallengeFilters(requireGps: true),
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
      return false;
    } finally {
      _setLoading(false);
    }
  }

    Stream<List<Challenge>> get globalChallengesStream => _repository.getGlobalChallenges();

  /// Publica un reto (draft → active)
  Future<bool> publishGlobalChallenge(String challengeId) async {
    try {
      await _repository.publishChallenge(challengeId);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Elimina un reto global
  Future<bool> deleteChallenge(String challengeId) async {
    try {
      await _repository.deleteGlobalChallenge(challengeId);
      return true;
    } catch (e) {
      return false;
    }
  }


  /// Exportar estadísticas actuales a PDF
  Future<void> exportToPdf({
    required List<String> selectedMetrics,
    required DateTimeRange range,
  }) async {
    _setLoading(true);
    try {
      final pdfData = await PdfGeneratorService.generateAdminReportPdf(
        stats: _stats,
        selectedMetrics: selectedMetrics,
        range: range,
      );

      final fileName = 'Reporte_Admin_${DateTime.now().millisecondsSinceEpoch}.pdf';
      
      await Printing.sharePdf(
        bytes: pdfData,
        filename: fileName,
      );
    } catch (e) {
      // Error
    } finally {
      _setLoading(false);
    }
  }

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
