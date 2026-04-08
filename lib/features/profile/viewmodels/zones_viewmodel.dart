import 'package:flutter/foundation.dart';
import 'package:running_laps/core/services/zones_service.dart';
import 'package:running_laps/features/profile/data/user_profile_model.dart';
import 'package:running_laps/features/profile/data/zones_repository.dart';

/// Estado inmutable del ViewModel de zonas.
class ZonesViewModelState {
  final UserProfileModel? profile;
  final bool isSaving;
  final String? errorMessage;

  const ZonesViewModelState({
    this.profile,
    this.isSaving = false,
    this.errorMessage,
  });

  ZonesViewModelState copyWith({
    UserProfileModel? profile,
    bool? isSaving,
    Object? errorMessage = _sentinel,
  }) {
    return ZonesViewModelState(
      profile: profile ?? this.profile,
      isSaving: isSaving ?? this.isSaving,
      errorMessage: identical(errorMessage, _sentinel)
          ? this.errorMessage
          : errorMessage as String?,
    );
  }
}

const Object _sentinel = Object();

class ZonesViewModel {
  ZonesViewModel({ZonesRepository? repository})
      : _repo = repository ?? ZonesRepository();

  final ZonesRepository _repo;
  final _zonesService = ZonesService();

  final state = ValueNotifier<ZonesViewModelState>(
    const ZonesViewModelState(),
  );

  UserProfileModel? get _profile => state.value.profile;

  // ── Computed ───────────────────────────────────────────────────────

  bool get needsBirthDate => _profile?.birthDate == null;

  int? get effectiveFcMax =>
      _zonesService.fcMaxEffective(_profile?.fcMax, _profile?.birthDate);

  List<ZoneRange> get currentZones =>
      _zonesService.zonesFor(effectiveFcMax ?? 180);

  // ── Actions ────────────────────────────────────────────────────────

  Future<void> loadProfile(String uid) async {
    state.value = state.value.copyWith(errorMessage: null);
    try {
      final profile = await _repo.getUserProfile(uid);
      state.value = state.value.copyWith(profile: profile);
    } catch (e) {
      debugPrint('ZonesViewModel.loadProfile error: $e');
      state.value = state.value.copyWith(errorMessage: e.toString());
    }
  }

  Future<void> saveFcConfig({
    required String uid,
    int? fcMax,
    int? fcReposo,
    String? birthDate,
    String? sex,
  }) async {
    state.value = state.value.copyWith(isSaving: true, errorMessage: null);
    try {
      await _repo.saveFcConfig(
        uid: uid,
        fcMax: fcMax,
        fcReposo: fcReposo,
        birthDate: birthDate,
        sex: sex,
      );
      // Reload para reflejar los datos guardados
      await loadProfile(uid);
    } catch (e) {
      debugPrint('ZonesViewModel.saveFcConfig error: $e');
      state.value = state.value.copyWith(errorMessage: e.toString());
    } finally {
      state.value = state.value.copyWith(isSaving: false);
    }
  }

  void dispose() {
    state.dispose();
  }
}
