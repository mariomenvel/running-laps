import 'package:flutter/foundation.dart';
import 'package:running_laps/features/athlete/data/athlete_session_model.dart';
import 'package:running_laps/features/athlete/data/athlete_session_repository.dart';
import 'package:running_laps/features/templates/data/template_models.dart';
import 'package:running_laps/features/templates/data/templates_repository.dart';

// ── State ─────────────────────────────────────────────────────────────────────

class SessionEditorState {
  final bool isLoading;
  final bool isSaving;
  final String? errorMessage;
  final List<TrainingTemplate> availableTemplates;

  const SessionEditorState({
    this.isLoading = false,
    this.isSaving  = false,
    this.errorMessage,
    this.availableTemplates = const [],
  });

  SessionEditorState copyWith({
    bool? isLoading,
    bool? isSaving,
    Object? errorMessage        = _s,
    List<TrainingTemplate>? availableTemplates,
  }) {
    return SessionEditorState(
      isLoading:          isLoading          ?? this.isLoading,
      isSaving:           isSaving           ?? this.isSaving,
      errorMessage:       errorMessage == _s  ? this.errorMessage : errorMessage as String?,
      availableTemplates: availableTemplates  ?? this.availableTemplates,
    );
  }
}

const Object _s = Object();

// ── ViewModel ─────────────────────────────────────────────────────────────────

class SessionEditorViewModel {
  SessionEditorViewModel({
    AthleteSessionRepository?  sessionRepository,
    TrainingTemplatesRepository? templatesRepository,
  })  : _sessionRepo   = sessionRepository   ?? AthleteSessionRepository(),
        _templatesRepo = templatesRepository ?? TrainingTemplatesRepository();

  final AthleteSessionRepository   _sessionRepo;
  final TrainingTemplatesRepository _templatesRepo;

  final ValueNotifier<SessionEditorState> state =
      ValueNotifier(const SessionEditorState());

  // ── Init ──────────────────────────────────────────────────────────────────

  Future<void> init(String uid) async {
    state.value = state.value.copyWith(isLoading: true, errorMessage: null);
    try {
      final all = await _templatesRepo.getUserTemplates();
      final main = all.where((t) => !t.isWarmupCooldown).toList();
      state.value = state.value.copyWith(
        isLoading:          false,
        availableTemplates: main,
      );
    } catch (e) {
      debugPrint('[SessionEditorViewModel] init error: $e');
      state.value = state.value.copyWith(isLoading: false);
    }
  }

  // ── Save ──────────────────────────────────────────────────────────────────

  /// Crea o actualiza según [session.id] vacío o no.
  /// Devuelve true si ok, false si error (errorMessage se actualiza).
  Future<bool> save({
    required String uid,
    required AthleteSession session,
  }) async {
    state.value = state.value.copyWith(isSaving: true, errorMessage: null);
    try {
      if (session.id.isEmpty) {
        await _sessionRepo.createSession(session);
      } else {
        await _sessionRepo.updateSession(session);
      }
      state.value = state.value.copyWith(isSaving: false);
      return true;
    } catch (e) {
      debugPrint('[SessionEditorViewModel] save error: $e');
      state.value = state.value.copyWith(
        isSaving:     false,
        errorMessage: e.toString(),
      );
      return false;
    }
  }

  // ── Delete ────────────────────────────────────────────────────────────────

  Future<bool> delete({
    required String uid,
    required String sessionId,
  }) async {
    state.value = state.value.copyWith(isSaving: true, errorMessage: null);
    try {
      await _sessionRepo.deleteSession(uid: uid, id: sessionId);
      state.value = state.value.copyWith(isSaving: false);
      return true;
    } catch (e) {
      debugPrint('[SessionEditorViewModel] delete error: $e');
      state.value = state.value.copyWith(
        isSaving:     false,
        errorMessage: e.toString(),
      );
      return false;
    }
  }

  void dispose() => state.dispose();
}
