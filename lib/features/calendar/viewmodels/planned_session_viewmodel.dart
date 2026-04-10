import 'package:flutter/foundation.dart';
import 'package:running_laps/features/calendar/data/planned_session_model.dart';
import 'package:running_laps/features/calendar/data/planned_session_repository.dart';
import 'package:running_laps/features/templates/data/template_models.dart';
import 'package:running_laps/features/templates/data/templates_repository.dart';

// ── State ─────────────────────────────────────────────────────────────────────

class PlannedSessionEditorState {
  final bool isLoading;
  final bool isSaving;
  final String? errorMessage;
  final List<TrainingTemplate> availableTemplates;

  const PlannedSessionEditorState({
    this.isLoading = false,
    this.isSaving = false,
    this.errorMessage,
    this.availableTemplates = const [],
  });

  PlannedSessionEditorState copyWith({
    bool? isLoading,
    bool? isSaving,
    Object? errorMessage = _sentinel,
    List<TrainingTemplate>? availableTemplates,
  }) {
    return PlannedSessionEditorState(
      isLoading:          isLoading          ?? this.isLoading,
      isSaving:           isSaving           ?? this.isSaving,
      errorMessage:       errorMessage == _sentinel ? this.errorMessage : errorMessage as String?,
      availableTemplates: availableTemplates ?? this.availableTemplates,
    );
  }
}

const Object _sentinel = Object();

// ── ViewModel ─────────────────────────────────────────────────────────────────

class PlannedSessionViewModel {
  PlannedSessionViewModel({
    PlannedSessionRepository? sessionRepository,
    TrainingTemplatesRepository? templatesRepository,
  })  : _sessionRepository   = sessionRepository   ?? PlannedSessionRepository(),
        _templatesRepository = templatesRepository ?? TrainingTemplatesRepository();

  final PlannedSessionRepository   _sessionRepository;
  final TrainingTemplatesRepository _templatesRepository;

  final ValueNotifier<PlannedSessionEditorState> state =
      ValueNotifier(const PlannedSessionEditorState());

  // ── Public API ─────────────────────────────────────────────────────────────

  Future<void> init(String uid) async {
    state.value = state.value.copyWith(isLoading: true, errorMessage: null);
    try {
      final all = await _templatesRepository.getUserTemplates();
      final main = all.where((t) => !t.isWarmupCooldown).toList();
      state.value = state.value.copyWith(
        isLoading: false,
        availableTemplates: main,
      );
    } catch (e) {
      debugPrint('[PlannedSessionViewModel] init error: $e');
      state.value = state.value.copyWith(
        isLoading: false,
        availableTemplates: [],
      );
    }
  }

  /// Creates or updates a session.
  /// Returns true on success, false on error (errorMessage updated in state).
  Future<bool> save({
    required String uid,
    required PlannedSession session,
  }) async {
    state.value = state.value.copyWith(isSaving: true, errorMessage: null);
    try {
      final isNew = session.id.isEmpty;
      final now = DateTime.now();
      final toSave = isNew
          ? session.copyWith(
              id:        DateTime.now().millisecondsSinceEpoch.toString(),
              uid:       uid,
              createdAt: now,
              updatedAt: now,
            )
          : session.copyWith(updatedAt: now);

      if (isNew) {
        await _sessionRepository.createSession(toSave);
      } else {
        await _sessionRepository.updateSession(toSave);
      }

      state.value = state.value.copyWith(isSaving: false);
      return true;
    } catch (e) {
      debugPrint('[PlannedSessionViewModel] save error: $e');
      state.value = state.value.copyWith(
        isSaving: false,
        errorMessage: 'No se pudo guardar la sesión',
      );
      return false;
    }
  }

  /// Deletes a session.
  /// Returns true on success, false on error.
  Future<bool> delete({
    required String uid,
    required String sessionId,
  }) async {
    state.value = state.value.copyWith(isSaving: true, errorMessage: null);
    try {
      await _sessionRepository.deleteSession(uid: uid, id: sessionId);
      state.value = state.value.copyWith(isSaving: false);
      return true;
    } catch (e) {
      debugPrint('[PlannedSessionViewModel] delete error: $e');
      state.value = state.value.copyWith(
        isSaving: false,
        errorMessage: 'No se pudo eliminar la sesión',
      );
      return false;
    }
  }

  void dispose() {
    state.dispose();
  }
}
