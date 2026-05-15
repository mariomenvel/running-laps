import 'package:running_laps/features/templates/data/workout_session.dart';
import 'package:running_laps/features/templates/data/workout_block.dart';
import 'package:running_laps/features/templates/data/workout_segment.dart';

import 'shared/session_theme.dart';

/// Decide qué pantalla mostrar según bloque + segmento + tipo de sesión.
///
/// Esto NO renderiza nada todavía — solo expone la decisión.
/// Las pantallas INTRA/REST específicas se crearán en pasos siguientes.
class SessionScreenRouter {
  final WorkoutSession session;
  final WorkoutBlock currentBlock;
  final WorkoutSegment? currentSegment;

  const SessionScreenRouter({
    required this.session,
    required this.currentBlock,
    this.currentSegment,
  });

  /// Tipo de pantalla a renderizar
  SessionScreenKind get kind {
    // Segmento recovery → pantalla de descanso
    if (currentSegment?.type == SegmentType.recovery) {
      return SessionScreenKind.rest;
    }

    // Warmup o cooldown → siempre estética continuous
    if (currentBlock.role == BlockRole.warmup ||
        currentBlock.role == BlockRole.cooldown) {
      return SessionScreenKind.continuous;
    }

    // Bloque main → según tipo de sesión
    switch (session.type) {
      case WorkoutType.intervals:
        return SessionScreenKind.interval;
      case WorkoutType.fartlek:
        return SessionScreenKind.fartlek;
      case WorkoutType.hills:
        return SessionScreenKind.hills;
      case WorkoutType.competition:
        return SessionScreenKind.competition;
      case WorkoutType.continuous:
        return SessionScreenKind.continuous;
      case WorkoutType.free:
        return SessionScreenKind.free;
    }
  }

  /// Theme correspondiente al tipo de sesión (no al bloque)
  SessionTheme get theme => SessionTheme.forType(session.type);

  /// Theme contextual:
  /// - Warmup/cooldown → siempre continuous theme
  /// - Resto → theme del tipo de sesión
  SessionTheme get contextualTheme {
    if (currentBlock.role == BlockRole.warmup ||
        currentBlock.role == BlockRole.cooldown) {
      return SessionTheme.forType(WorkoutType.continuous);
    }
    return theme;
  }
}

enum SessionScreenKind {
  interval,     // series en pista
  continuous,   // rodaje (también warmup/cooldown)
  fartlek,      // dos zonas dinámicas
  hills,        // cuestas
  competition,  // carrera
  free,         // libre
  rest,         // descanso (tematizado por sessionType)
}
