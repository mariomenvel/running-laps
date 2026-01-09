import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../data/models/rewards_models.dart';
import '../data/repositories/rewards_repository.dart';

/// ViewModel para la pantalla de recompensas del grupo
class GroupRewardsController {
  final String groupId;
  final RewardsRepository _rewardsRepo;
  final FirebaseAuth _auth;

  // ============================================
  // STATE
  // ============================================

  final ValueNotifier<bool> isLoading = ValueNotifier(true);
  final ValueNotifier<String?> error = ValueNotifier(null);

  final ValueNotifier<List<GroupMedals>> medalsTable = ValueNotifier([]);
  final ValueNotifier<List<GroupBadges>> badgesTable = ValueNotifier([]);
  final ValueNotifier<List<MedalHistoryEntry>> myMedalHistory = ValueNotifier([]);
  final ValueNotifier<List<BadgeHistoryEntry>> myBadgeHistory = ValueNotifier([]);

  GroupRewardsController({
    required this.groupId,
    RewardsRepository? rewardsRepo,
    FirebaseAuth? auth,
  })  : _rewardsRepo = rewardsRepo ?? RewardsRepository(),
        _auth = auth ?? FirebaseAuth.instance;

  // ============================================
  // INITIALIZATION
  // ============================================

  Future<void> init() async {
    isLoading.value = true;
    error.value = null;

    try {
      final uid = _auth.currentUser?.uid;
      if (uid == null) throw Exception('User not authenticated');

      // 1. Stream Medallero Global
      _rewardsRepo.streamGroupMedals(groupId).listen((list) async {
        final enriched = await _enrichMedals(list);
        medalsTable.value = enriched;
      });

      // 2. Stream Badges Table
      _rewardsRepo.streamGroupBadges(groupId).listen((list) async {
        final enriched = await _enrichBadges(list);
        badgesTable.value = enriched;
      });

      // 3. Stream My History
      _rewardsRepo.streamMyMedalHistory(groupId, uid).listen((list) {
        myMedalHistory.value = list;
      });

      _rewardsRepo.streamMyBadgeHistory(groupId, uid).listen((list) {
        myBadgeHistory.value = list;
      });

    } catch (e) {
      error.value = e.toString();
    } finally {
      isLoading.value = false;
    }
  }

  Future<List<GroupMedals>> _enrichMedals(List<GroupMedals> list) async {
    final List<Future<GroupMedals>> futures = list.map((m) async {
      try {
        final userDoc = await FirebaseFirestore.instance.collection('users').doc(m.uid).get();
        if (!userDoc.exists) return m;

        final userData = userDoc.data()!;
        return m.copyWith(
          displayName: userData['nombre'] as String? ?? userData['displayName'] as String?,
          photoUrl: (userData['photoUrl'] as String?) ?? (userData['profileImageUrl'] as String?),
          profilePicType: userData['profilePicType'] as String?,
          avatarConfig: userData['avatarConfig'] as Map<String, dynamic>?,
        );
      } catch (e) {
        return m;
      }
    }).toList();

    return await Future.wait(futures);
  }

  Future<List<GroupBadges>> _enrichBadges(List<GroupBadges> list) async {
    final List<Future<GroupBadges>> futures = list.map((b) async {
      try {
        final userDoc = await FirebaseFirestore.instance.collection('users').doc(b.uid).get();
        if (!userDoc.exists) return b;

        final userData = userDoc.data()!;
        return b.copyWith(
          displayName: userData['nombre'] as String? ?? userData['displayName'] as String?,
          photoUrl: (userData['photoUrl'] as String?) ?? (userData['profileImageUrl'] as String?),
          profilePicType: userData['profilePicType'] as String?,
          avatarConfig: userData['avatarConfig'] as Map<String, dynamic>?,
        );
      } catch (e) {
        return b;
      }
    }).toList();

    return await Future.wait(futures);
  }

  void dispose() {
    isLoading.dispose();
    error.dispose();
    medalsTable.dispose();
    badgesTable.dispose();
    myMedalHistory.dispose();
    myBadgeHistory.dispose();
  }
}


