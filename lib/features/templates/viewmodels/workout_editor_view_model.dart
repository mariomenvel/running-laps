import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show TimeOfDay;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:running_laps/core/services/notification_service.dart';
import 'package:running_laps/core/widgets/main_shell.dart';
import 'package:running_laps/features/ai_coach/data/ai_coach_prompt_session_generator.dart';
import 'package:running_laps/features/ai_coach/data/ai_coach_repository.dart';
import 'package:running_laps/features/athlete/data/athlete_session_repository.dart';
import 'package:running_laps/features/templates/data/athlete_session_mapper.dart';
import 'package:running_laps/features/templates/data/workout_block.dart';
import 'package:running_laps/features/templates/data/workout_segment.dart';
import 'package:running_laps/features/templates/data/workout_session.dart';
import 'package:uuid/uuid.dart';

/// Resultado de un intento de generación de sesión por IA. La View lee
/// [success]/[errorMessage] para decidir qué snackbar mostrar — el viewmodel
/// no dispara UI.
class AiGenerationResult {
  const AiGenerationResult({required this.success, this.errorMessage});

  final bool success;
  final String? errorMessage;
}

/// Resultado de un intento de guardado. [blocked] es true cuando la sesión no
/// cumple el mínimo para guardarse (sin tipo y sin bloques, fuera de
/// "inicio rápido").
class SaveResult {
  const SaveResult({this.session, this.blocked = false});

  final WorkoutSession? session;
  final bool blocked;
}

/// Estado y lógica de `WorkoutEditorScreen`: composición de la
/// [WorkoutSession] (tipo, bloques, nombre, hora, notas), generación por IA y
/// persistencia como sesión planificada.
///
/// La View solo renderiza este estado y llama a estos métodos desde callbacks:
/// no debe tocar repositorios ni mappers. A la inversa, el viewmodel no conoce
/// `BuildContext` — devuelve resultados y la View decide navegación y avisos.
class WorkoutEditorViewModel {
  WorkoutEditorViewModel({
    this.initialSession,
    this.scheduledDate,
    this.shellParams,
    this.isQuickStart = false,
  }) {
    final mapped = mapAthleteSessionToWorkout(shellParams?.session);
    // Punto de partida contra el que se comparan los cambios. Ojo: cuando la
    // pantalla se abre desde el calendario la sesión llega por
    // `shellParams.session`, no por `initialSession`; comparando solo contra
    // `initialSession` el editor creía que TODO era nuevo y preguntaba
    // "¿Salir sin guardar?" aunque no hubieras tocado nada.
    final s = initialSession ?? mapped;
    _baseline = s;

    effectiveScheduledDate = scheduledDate ??
        _parseShellDate(shellParams?.date) ??
        s?.scheduledDate;

    selectedType  = ValueNotifier(s?.type);
    title         = ValueNotifier(s?.title ?? '');
    blocks        = ValueNotifier(List.of(s?.blocks ?? []));
    scheduledTime = ValueNotifier(s?.scheduledTime);
    notes         = ValueNotifier(s?.notes ?? '');

    if (s != null && s.title.isNotEmpty) {
      _titleEdited = true;
      final autoTitle = generateTitle(s);
      _titleIsAuto = s.title == autoTitle || s.title == titleFromType(s.type);
    } else {
      _titleIsAuto = true;
    }
  }

  final WorkoutSession? initialSession;
  final DateTime? scheduledDate;
  final AthleteSessionShellParams? shellParams;
  final bool isQuickStart;

  late final DateTime? effectiveScheduledDate;

  /// Sesión de partida (la editada, venga por `initialSession` o por
  /// `shellParams`). `null` = sesión nueva desde cero.
  late final WorkoutSession? _baseline;

  late final ValueNotifier<WorkoutType?> selectedType;
  late final ValueNotifier<String> title;
  late final ValueNotifier<List<WorkoutBlock>> blocks;
  late final ValueNotifier<TimeOfDay?> scheduledTime;
  late final ValueNotifier<String> notes;
  final ValueNotifier<bool> aiGenerating = ValueNotifier(false);

  /// Todo lo que [hasChanges] compara, para que el botón de guardar refleje en
  /// vivo si hay algo que guardar.
  Listenable get formFields =>
      Listenable.merge([selectedType, title, blocks, scheduledTime, notes]);

  bool _titleEdited = false;
  bool _titleIsAuto = true;

  static DateTime? _parseShellDate(String? date) =>
      date == null ? null : DateTime.tryParse(date);

  // ── Tipo y bloques ──────────────────────────────────────────────────────

  @visibleForTesting
  List<WorkoutBlock> defaultBlocksForType(WorkoutType type) {
    switch (type) {
      case WorkoutType.continuous:
        return [
          WorkoutBlock(role: BlockRole.warmup, repetitions: 1,
            segments: [WorkoutSegment(type: SegmentType.interval, durationSec: 600)]),
          WorkoutBlock(role: BlockRole.main, repetitions: 1,
            segments: [WorkoutSegment(type: SegmentType.interval, durationSec: 2700)]),
          WorkoutBlock(role: BlockRole.cooldown, repetitions: 1,
            segments: [WorkoutSegment(type: SegmentType.interval, durationSec: 600)]),
        ];

      case WorkoutType.intervals:
        return [
          WorkoutBlock(role: BlockRole.warmup, repetitions: 1,
            segments: [WorkoutSegment(type: SegmentType.interval, durationSec: 600)]),
          WorkoutBlock(role: BlockRole.main, repetitions: 5,
            segments: [
              WorkoutSegment(type: SegmentType.interval, distanceM: 1000),
              WorkoutSegment(type: SegmentType.recovery, durationSec: 90),
            ]),
          WorkoutBlock(role: BlockRole.cooldown, repetitions: 1,
            segments: [WorkoutSegment(type: SegmentType.interval, durationSec: 600)]),
        ];

      case WorkoutType.fartlek:
        return [
          WorkoutBlock(role: BlockRole.warmup, repetitions: 1,
            segments: [WorkoutSegment(type: SegmentType.interval, durationSec: 600)]),
          WorkoutBlock(role: BlockRole.main, repetitions: 4,
            segments: [
              WorkoutSegment(type: SegmentType.interval, durationSec: 180),
              WorkoutSegment(type: SegmentType.recovery, durationSec: 120),
            ]),
          WorkoutBlock(role: BlockRole.cooldown, repetitions: 1,
            segments: [WorkoutSegment(type: SegmentType.interval, durationSec: 600)]),
        ];

      case WorkoutType.hills:
        return [
          WorkoutBlock(role: BlockRole.warmup, repetitions: 1,
            segments: [WorkoutSegment(type: SegmentType.interval, durationSec: 600)]),
          WorkoutBlock(role: BlockRole.main, repetitions: 8,
            segments: [
              WorkoutSegment(type: SegmentType.interval, durationSec: 60),
              WorkoutSegment(type: SegmentType.recovery, durationSec: 90),
            ]),
          WorkoutBlock(role: BlockRole.cooldown, repetitions: 1,
            segments: [WorkoutSegment(type: SegmentType.interval, durationSec: 600)]),
        ];

      case WorkoutType.competition:
        return [
          WorkoutBlock(role: BlockRole.warmup, repetitions: 1,
            segments: [WorkoutSegment(type: SegmentType.interval, durationSec: 900)]),
          WorkoutBlock(role: BlockRole.main, repetitions: 1,
            segments: [WorkoutSegment(type: SegmentType.interval, distanceM: 5000)]),
          WorkoutBlock(role: BlockRole.cooldown, repetitions: 1,
            segments: [WorkoutSegment(type: SegmentType.interval, durationSec: 600)]),
        ];

      case WorkoutType.free:
        return [
          WorkoutBlock(role: BlockRole.main, repetitions: 1,
            segments: [WorkoutSegment(type: SegmentType.interval, durationSec: 3600)]),
        ];
    }
  }

  void onTypeSelected(WorkoutType type) {
    selectedType.value = type;
    if (!_titleEdited) {
      // La View mantiene su TextEditingController sincronizado escuchando
      // [title]; aquí no se toca ningún controlador.
      title.value = titleFromType(type);
      _titleIsAuto = true;
    }

    final current = blocks.value;
    final isEmpty = current.isEmpty ||
        (current.length == 1 &&
         current.first.role == BlockRole.main &&
         current.first.segments.isEmpty);

    if (isEmpty) {
      blocks.value = defaultBlocksForType(type);
    }
  }

  void onBlocksChanged(List<WorkoutBlock> updated) => blocks.value = updated;

  /// El usuario escribió el nombre a mano: deja de autogenerarse al guardar.
  void onTitleEdited(String value) {
    title.value = value;
    _titleEdited = true;
    _titleIsAuto = false;
  }

  void onNotesChanged(String value) => notes.value = value;

  void setScheduledTime(TimeOfDay time) => scheduledTime.value = time;

  // ── Cambios sin guardar ─────────────────────────────────────────────────

  bool hasChanges() {
    final s = _baseline;
    if (s == null) {
      return selectedType.value != null ||
          title.value.isNotEmpty ||
          blocks.value.isNotEmpty ||
          scheduledTime.value != null ||
          notes.value.isNotEmpty;
    }
    return selectedType.value != s.type ||
        title.value != s.title ||
        blocks.value.length != s.blocks.length ||
        scheduledTime.value != s.scheduledTime ||
        notes.value != (s.notes ?? '');
  }

  // ── Generación por IA ───────────────────────────────────────────────────

  Future<AiGenerationResult> generateFromAi(String prompt) async {
    final text = prompt.trim();
    if (text.isEmpty) return const AiGenerationResult(success: false);

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const AiGenerationResult(success: false);

    aiGenerating.value = true;
    try {
      final profile = await AiCoachRepository().getProfile(uid: uid);

      const generator = AiCoachPromptSessionGenerator();
      final session = await generator.generate(prompt: text, profile: profile);

      blocks.value = List.of(session.blocks);
      _titleEdited = true;
      _titleIsAuto = false;
      onTypeSelected(session.type);
      title.value = session.title;

      return const AiGenerationResult(success: true);
    } catch (e) {
      debugPrint('[WorkoutEditorViewModel] generateFromAi: $e');
      return const AiGenerationResult(
        success: false,
        errorMessage: 'Error al generar',
      );
    } finally {
      aiGenerating.value = false;
    }
  }

  // ── Guardado ────────────────────────────────────────────────────────────

  /// Nombre final de la sesión: respeta el que escribió el usuario y, si es
  /// automático o está vacío, lo deriva del bloque principal (5×1km, 8×1',
  /// Rodaje 10km…).
  @visibleForTesting
  String resolveTitle(WorkoutType type, List<WorkoutBlock> blocks) {
    final userTitle = title.value.trim();
    if (userTitle.isNotEmpty && !_titleIsAuto) return userTitle;

    final mainBlock = blocks.where((b) => b.role == BlockRole.main).firstOrNull;
    final firstSeg = mainBlock?.segments
        .where((s) => s.type == SegmentType.interval)
        .firstOrNull;
    final reps = mainBlock?.repetitions ?? 1;
    final distM = firstSeg?.distanceM;
    final durSec = firstSeg?.durationSec;
    final isRepeated = type == WorkoutType.intervals || type == WorkoutType.hills;

    if (isRepeated && distM != null && distM > 0) {
      final distLabel = distM >= 1000
          ? '${(distM / 1000).toStringAsFixed(distM % 1000 == 0 ? 0 : 1)}km'
          : '${distM}m';
      return reps > 1 ? '$reps×$distLabel' : distLabel;
    }
    if (isRepeated && durSec != null && durSec > 0) {
      final min = durSec ~/ 60;
      final sec = durSec % 60;
      final timeLabel = sec == 0 ? '$min min' : "$min'$sec\"";
      return reps > 1 ? '$reps×$timeLabel' : timeLabel;
    }
    if (type == WorkoutType.continuous && distM != null) {
      final km = distM / 1000;
      return 'Rodaje ${km.toStringAsFixed(km % 1 == 0 ? 0 : 1)}km';
    }
    if (type == WorkoutType.continuous && durSec != null) {
      return 'Rodaje ${durSec ~/ 60} min';
    }
    return titleFromType(type);
  }

  /// Compone la [WorkoutSession] a partir del estado actual. Sin efectos:
  /// no persiste ni navega.
  @visibleForTesting
  WorkoutSession buildSession() {
    final resolvedType = selectedType.value ?? WorkoutType.free;

    final resolvedBlocks = blocks.value.isNotEmpty
        ? blocks.value
        : [WorkoutBlock(role: BlockRole.main, repetitions: 1, segments: [])];

    final notesValue = notes.value.trim().isEmpty ? null : notes.value.trim();

    return WorkoutSession(
      id:            initialSession?.id ?? const Uuid().v4(),
      title:         resolveTitle(resolvedType, resolvedBlocks),
      type:          resolvedType,
      blocks:        resolvedBlocks,
      scheduledDate: effectiveScheduledDate,
      scheduledTime: scheduledTime.value,
      notes:         notesValue,
      isTemplate:    initialSession?.isTemplate ?? false,
      templateId:    initialSession?.templateId,
    );
  }

  /// Compone la sesión y, si viene del calendario, la persiste como sesión
  /// planificada y programa el recordatorio. Devuelve la sesión para que la
  /// View invoque su `onSave` y navegue.
  Future<SaveResult> save() async {
    if (selectedType.value == null && blocks.value.isEmpty && !isQuickStart) {
      return const SaveResult(blocked: true);
    }

    final session = buildSession();

    if (shellParams != null || scheduledDate != null) {
      await _persistAsAthleteSession(session);
    }

    return SaveResult(session: session);
  }

  Future<void> _persistAsAthleteSession(WorkoutSession session) async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;

      final repo = AthleteSessionRepository();
      final existing = shellParams?.session;

      if (existing != null) {
        // Conserva el id original: es una edición, no una sesión nueva.
        // `copyWith` no permite cambiar el id (identidad del modelo), así que
        // se reconstruye a mano.
        final sessionWithId = WorkoutSession(
          id:            existing.id,
          title:         session.title,
          description:   session.description,
          type:          session.type,
          blocks:        session.blocks,
          scheduledDate: session.scheduledDate,
          scheduledTime: session.scheduledTime,
          notes:         session.notes,
          isTemplate:    session.isTemplate,
          templateId:    session.templateId,
        );
        await repo.updateSession(
          mapWorkoutSessionToAthlete(sessionWithId, uid: uid),
        );
      } else {
        final athleteSession = mapWorkoutSessionToAthlete(session, uid: uid);
        await repo.createSession(athleteSession);
        shellParams?.onSaved?.call(athleteSession);
      }

      _scheduleReminder(session);
    } catch (e) {
      debugPrint('[WorkoutEditorViewModel] persistAthleteSession error: $e');
    }
  }

  /// Recordatorio "¡Entreno en 1 hora!" — solo si la sesión tiene fecha y hora
  /// concretas. Fire-and-forget: que falle la notificación no debe tumbar el
  /// guardado.
  void _scheduleReminder(WorkoutSession session) {
    final schedDate = session.scheduledDate;
    final schedTime = session.scheduledTime;
    if (schedDate == null || schedTime == null) return;

    final sessionDateTime = DateTime(
      schedDate.year, schedDate.month, schedDate.day,
      schedTime.hour, schedTime.minute,
    );

    NotificationService()
        .scheduleSessionReminder(
          sessionId: session.id,
          sessionDateTime: sessionDateTime,
          sessionTitle: session.title,
        )
        .catchError((Object e) =>
            debugPrint('[WorkoutEditorViewModel] session reminder: $e'));
  }

  void dispose() {
    selectedType.dispose();
    title.dispose();
    blocks.dispose();
    scheduledTime.dispose();
    notes.dispose();
    aiGenerating.dispose();
  }
}
