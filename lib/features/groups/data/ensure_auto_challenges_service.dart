import 'package:cloud_firestore/cloud_firestore.dart';
import 'challenge_models.dart';
import 'templates_repository.dart';
import 'challenges_repository.dart';
import 'period_helper.dart';
import 'enums.dart';

/// Service para asegurar que existan retos automáticos para el periodo actual
class EnsureAutoChallengesService {
  final TemplatesRepository _templatesRepo;
  final ChallengesRepository _challengesRepo;

  EnsureAutoChallengesService({
    TemplatesRepository? templatesRepo,
    ChallengesRepository? challengesRepo,
  })  : _templatesRepo = templatesRepo ?? TemplatesRepository(),
        _challengesRepo = challengesRepo ?? ChallengesRepository();

  /// Asegura que existan 4 retos automáticos activos (2 weekly + 2 monthly)
  /// Retorna la lista de IDs de los challenges creados/asegurados
  Future<List<String>> ensureAutoChallengesForGroup(
    String groupId,
    DateTime now,
  ) async {
    try {
      // 1. Cargar todos los templates habilitados
      final allTemplates = await _templatesRepo.listEnabledTemplates();

      // 2. Filtrar y seleccionar EXACTAMENTE 2 weekly + 2 monthly
      final weeklyTemplates = allTemplates
          .where((t) => t.periodicity == ChallengePeriodicity.weekly)
          .toList();
      final monthlyTemplates = allTemplates
          .where((t) => t.periodicity == ChallengePeriodicity.monthly)
          .toList();

      // Ordenar por templateId para selección estable
      weeklyTemplates.sort((a, b) => a.templateId.compareTo(b.templateId));
      monthlyTemplates.sort((a, b) => a.templateId.compareTo(b.templateId));

      // Tomar los primeros 2 de cada tipo
      final selectedWeekly = weeklyTemplates.take(2).toList();
      final selectedMonthly = monthlyTemplates.take(2).toList();

      final selectedTemplates = [...selectedWeekly, ...selectedMonthly];

      // 3. Para cada template seleccionado, crear/asegurar el challenge
      final createdChallengeIds = <String>[];

      for (final template in selectedTemplates) {
        final challengeId = await _ensureChallengeForTemplate(
          groupId,
          template,
          now,
        );
        if (challengeId != null) {
          createdChallengeIds.add(challengeId);
        }
      }

      return createdChallengeIds;
    } catch (e) {
      throw Exception('Error ensuring auto challenges: $e');
    }
  }

  /// Crea/asegura un challenge para un template específico
  /// Retorna el challengeId si se creó/ya existe, null si hubo error
  Future<String?> _ensureChallengeForTemplate(
    String groupId,
    ChallengeTemplate template,
    DateTime now,
  ) async {
    try {
      // Calcular period key y fechas según periodicidad
      final String periodKey;
      final DateTime startAt;
      final DateTime endAt;

      if (template.periodicity == ChallengePeriodicity.weekly) {
        periodKey = PeriodHelper.currentWeekPeriodKey(now);
        startAt = PeriodHelper.getWeekStart(now);
        endAt = PeriodHelper.getWeekEnd(now);
      } else {
        // monthly
        periodKey = PeriodHelper.currentMonthPeriodKey(now);
        startAt = PeriodHelper.getMonthStart(now);
        endAt = PeriodHelper.getMonthEnd(now);
      }

      // Generar docId determinista
      final challengeId = PeriodHelper.generateChallengeDeterministicId(
        template.templateId,
        periodKey,
      );

      // Construir Challenge desde template
      final challenge = Challenge(
        id: challengeId,
        title: template.title,
        origin: ChallengeOrigin.template,
        templateId: template.templateId,
        periodKey: periodKey,
        startAt: startAt,
        endAt: endAt,
        status: ChallengeStatus.active,
        metric: template.metric,
        aggregation: template.aggregation,
        filters: template.filters,
        goal: template.goal,
        tieBreakers: template.tieBreakers,
        awardsMedals: true,
        awardsBadges: true,
        medalsAwarded: false,
        badgesAwarded: false,
        createdAt: now,
        createdBy: 'system',
      );

      // Crear si no existe (idempotente)
      await _challengesRepo.createChallengeWithId(
        groupId,
        challengeId,
        challenge,
      );

      return challengeId;
    } catch (e) {
      return null;
    }
  }
}
