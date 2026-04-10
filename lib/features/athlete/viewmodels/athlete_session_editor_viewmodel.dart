import 'package:flutter/foundation.dart';
import 'package:running_laps/features/athlete/data/athlete_session_model.dart';
import 'package:running_laps/features/athlete/data/athlete_session_repository.dart';

// ── State ─────────────────────────────────────────────────────────────────────

class SessionEditorState {
  final bool isSaving;
  final String? error;

  final String date;
  final String? time;
  final String? category;

  final SessionWarmupCooldown? warmup;
  final List<SessionBlock> blocks;
  final SessionWarmupCooldown? cooldown;

  final String? planningNotes;

  const SessionEditorState({
    this.isSaving = false,
    this.error,
    required this.date,
    this.time,
    this.category,
    this.warmup,
    this.blocks = const [],
    this.cooldown,
    this.planningNotes,
  });

  SessionEditorState copyWith({
    bool? isSaving,
    Object? error = _s,
    String? date,
    Object? time = _s,
    Object? category = _s,
    Object? warmup = _s,
    List<SessionBlock>? blocks,
    Object? cooldown = _s,
    Object? planningNotes = _s,
  }) {
    return SessionEditorState(
      isSaving:      isSaving      ?? this.isSaving,
      error:         error         == _s ? this.error         : error         as String?,
      date:          date          ?? this.date,
      time:          time          == _s ? this.time          : time          as String?,
      category:      category      == _s ? this.category      : category      as String?,
      warmup:        warmup        == _s ? this.warmup        : warmup        as SessionWarmupCooldown?,
      blocks:        blocks        ?? this.blocks,
      cooldown:      cooldown      == _s ? this.cooldown      : cooldown      as SessionWarmupCooldown?,
      planningNotes: planningNotes == _s ? this.planningNotes : planningNotes as String?,
    );
  }
}

const Object _s = Object(); // sentinel

// ── ViewModel ─────────────────────────────────────────────────────────────────

class SessionEditorViewModel {
  SessionEditorViewModel({
    required this.uid,
    required String initialDate,
    this.existingSession,
    AthleteSessionRepository? repository,
  })  : _repository = repository ?? AthleteSessionRepository(),
        state = ValueNotifier(
          existingSession != null
              ? SessionEditorState(
                  date:          existingSession.date,
                  time:          existingSession.time,
                  category:      existingSession.category,
                  warmup:        existingSession.warmup,
                  blocks:        List.of(existingSession.blocks),
                  cooldown:      existingSession.cooldown,
                  planningNotes: existingSession.planningNotes,
                )
              : SessionEditorState(date: initialDate),
        );

  final String uid;
  final AthleteSession? existingSession;
  final AthleteSessionRepository _repository;
  final ValueNotifier<SessionEditorState> state;

  // ── Mutators ───────────────────────────────────────────────────────────────

  void updateDate(String date)             => _patch(state.value.copyWith(date: date));
  void updateTime(String? time)            => _patch(state.value.copyWith(time: time));
  void updateCategory(String? category)    => _patch(state.value.copyWith(category: category));
  void updateWarmup(SessionWarmupCooldown? w) => _patch(state.value.copyWith(warmup: w));
  void updateCooldown(SessionWarmupCooldown? c) => _patch(state.value.copyWith(cooldown: c));
  void updatePlanningNotes(String? notes)  => _patch(state.value.copyWith(planningNotes: notes));

  void addBlock() {
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    final newBlock = SessionBlock(
      id:    id,
      order: state.value.blocks.length,
      type:  SessionBlockType.series,
      reps:  1,
    );
    _patch(state.value.copyWith(
      blocks: [...state.value.blocks, newBlock],
    ));
  }

  void updateBlock(SessionBlock updated) {
    final blocks = state.value.blocks.map((b) => b.id == updated.id ? updated : b).toList();
    _patch(state.value.copyWith(blocks: blocks));
  }

  void removeBlock(String id) {
    final blocks = state.value.blocks.where((b) => b.id != id).toList();
    // reorder
    final reordered = [
      for (int i = 0; i < blocks.length; i++) blocks[i].copyWith(order: i),
    ];
    _patch(state.value.copyWith(blocks: reordered));
  }

  void reorderBlocks(int oldIndex, int newIndex) {
    final blocks = List.of(state.value.blocks);
    if (newIndex > oldIndex) newIndex--;
    final item = blocks.removeAt(oldIndex);
    blocks.insert(newIndex, item);
    final reordered = [
      for (int i = 0; i < blocks.length; i++) blocks[i].copyWith(order: i),
    ];
    _patch(state.value.copyWith(blocks: reordered));
  }

  // ── Save ───────────────────────────────────────────────────────────────────

  /// Returns true on success.
  Future<bool> save() async {
    _patch(state.value.copyWith(isSaving: true, error: null));
    try {
      final s = state.value;
      final now = DateTime.now();

      if (existingSession != null) {
        final updated = existingSession!.copyWith(
          date:          s.date,
          time:          s.time,
          category:      s.category,
          warmup:        s.warmup,
          blocks:        s.blocks,
          cooldown:      s.cooldown,
          planningNotes: s.planningNotes,
          updatedAt:     now,
        );
        await _repository.updateSession(updated);
      } else {
        final session = AthleteSession(
          id:        '',
          uid:       uid,
          date:      s.date,
          time:      s.time,
          category:  s.category,
          status:    AthleteSessionStatus.planned,
          warmup:    s.warmup,
          blocks:    s.blocks,
          cooldown:  s.cooldown,
          planningNotes: s.planningNotes,
          createdAt: now,
          updatedAt: now,
        );
        await _repository.createSession(session);
      }

      _patch(state.value.copyWith(isSaving: false));
      return true;
    } catch (e) {
      _patch(state.value.copyWith(isSaving: false, error: e.toString()));
      return false;
    }
  }

  void dispose() => state.dispose();

  void _patch(SessionEditorState s) => state.value = s;
}
