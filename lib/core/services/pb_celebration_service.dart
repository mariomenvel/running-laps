import 'package:flutter/foundation.dart';
import 'package:running_laps/core/services/notification_service.dart';
import 'package:running_laps/features/ai_coach/data/ai_coach_repository.dart';
import 'package:running_laps/features/ai_coach/data/pb_detector.dart';
import 'package:running_laps/features/athlete/data/progress_repository.dart';
import 'package:running_laps/features/training/data/entrenamiento.dart';

/// Detección y celebración de récords tras guardar un entrenamiento — punto
/// único para TODOS los flujos de guardado (resumen GPS/estructurado,
/// registro manual y completar sesión manualmente).
///
/// Dos niveles:
/// 1. **Récords por serie** en distancias estándar (400/1000/1500/5000/10000 m,
///    `ProgressRepository`): tras persistir el entreno se recalculan los
///    récords — los que apunten a este entreno son récords nuevos.
/// 2. **Marcas de sesión** 5K/10K/media/maratón (`PbDetector`, ±3%):
///    actualizan el perfil del coach (alimentan el VDOT).
///
/// Cada récord dispara una notificación local (llega aunque la vista ya haya
/// navegado). Llamar fire-and-forget tras el guardado; nunca lanza.
class PbCelebrationService {
  PbCelebrationService({
    ProgressRepository? progressRepo,
    AiCoachRepository? coachRepo,
  })  : _progressRepo = progressRepo ?? ProgressRepository(),
        _coachRepo = coachRepo ?? AiCoachRepository();

  final ProgressRepository _progressRepo;
  final AiCoachRepository _coachRepo;

  /// [training] debe estar ya persistido (id no nulo). Devuelve los mensajes
  /// de celebración por si el caller quiere además mostrarlos en la UI.
  Future<List<String>> checkAfterSave({
    required String uid,
    required Entrenamiento training,
  }) async {
    final messages = <String>[];
    final trainingId = training.id;
    if (trainingId == null) return messages;

    // ── 1. Récords por serie ──────────────────────────────────────────────
    try {
      final records = await _progressRepo.getPersonalRecords(uid);
      for (final record in records.values) {
        if (record.trainingId != trainingId) continue;
        final distLabel = record.distanceM < 1000
            ? '${record.distanceM}m'
            : record.distanceM == 1500
                ? '1.5km'
                : '${record.distanceM ~/ 1000}km';
        final pace = record.paceSecPerKm;
        final paceStr =
            '${pace ~/ 60}:${(pace % 60).round().toString().padLeft(2, '0')}';
        messages.add('¡Récord en $distLabel! $paceStr /km');
        NotificationService()
            .showPersonalRecord(distance: distLabel, pace: paceStr)
            .catchError((Object e) =>
                debugPrint('[PbCelebration] notif serie: $e'));
      }
    } catch (e) {
      debugPrint('[PbCelebration] récords por serie: $e');
    }

    // ── 2. Marca de sesión (5K/10K/HM/M) → perfil del coach ───────────────
    // GPS o manual: en manual el tiempo lo introduce el atleta (pista/cinta).
    try {
      if (training.gps || training.isManual) {
        final distanceM = training.distanciaTotalM();
        final timeSeconds = training.tiempoTotalSec().round();
        if (distanceM >= 1000) {
          final profile = await _coachRepo.getProfile(uid: uid);
          if (profile != null) {
            final pb = PbDetector.detect(
              distanceM: distanceM,
              timeSeconds: timeSeconds,
              profile: profile,
            );
            if (pb != null) {
              await _coachRepo.saveProfile(PbDetector.applyPb(
                profile: profile,
                field: pb.field,
                seconds: pb.seconds,
              ));
              final label = PbDetector.labelFor(pb.field);
              final formatted = PbDetector.format(pb.seconds);
              messages.add('¡Nueva marca en $label! $formatted');
              NotificationService()
                  .showSessionPb(label: label, time: formatted)
                  .catchError((Object e) =>
                      debugPrint('[PbCelebration] notif sesión: $e'));
            }
          }
        }
      }
    } catch (e) {
      debugPrint('[PbCelebration] marca de sesión: $e');
    }

    return messages;
  }
}
