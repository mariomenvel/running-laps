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
  final ValueNotifier<List<GroupHistoryItem>> groupHistory = ValueNotifier([]);

  // Raw lists used to rebuild the merged group timeline
  List<MedalHistoryEntry> _groupMedalHistory = [];
  List<BadgeHistoryEntry> _groupBadgeHistory = [];
  // Cache of user profile data keyed by uid to avoid repeated Firestore reads
  final Map<String, Map<String, dynamic>?> _userCache = {};

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

      // 5. Stream Group History (all members combined, latest 50)
      _rewardsRepo.streamGroupMedalHistory(groupId).listen((list) async {
        _groupMedalHistory = list;
        await _rebuildGroupHistory();
      });

      _rewardsRepo.streamGroupBadgeHistory(groupId).listen((list) async {
        _groupBadgeHistory = list;
        await _rebuildGroupHistory();
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

  /// Merges medal and badge history for all members, enriches with user data,
  /// sorts by awardedAt descending, and caps at 50 entries.
  Future<void> _rebuildGroupHistory() async {
    // Collect uids not yet in cache
    final uids = {
      ..._groupMedalHistory.map((e) => e.uid),
      ..._groupBadgeHistory.map((e) => e.uid),
    };
    for (final uid in uids) {
      if (!_userCache.containsKey(uid)) {
        try {
          final doc = await FirebaseFirestore.instance
              .collection('users')
              .doc(uid)
              .get();
          _userCache[uid] = doc.exists ? doc.data() : null;
        } catch (_) {
          _userCache[uid] = null;
        }
      }
    }

    final items = <GroupHistoryItem>[];

    for (final m in _groupMedalHistory) {
      final data = _userCache[m.uid];
      items.add(GroupHistoryItem(
        uid: m.uid,
        awardedAt: m.awardedAt,
        medal: m,
        displayName:
            data?['nombre'] as String? ?? data?['displayName'] as String?,
        photoUrl:
            data?['photoUrl'] as String? ?? data?['profileImageUrl'] as String?,
        profilePicType: data?['profilePicType'] as String?,
        avatarConfig: data?['avatarConfig'] as Map<String, dynamic>?,
      ));
    }

    for (final b in _groupBadgeHistory) {
      final data = _userCache[b.uid];
      items.add(GroupHistoryItem(
        uid: b.uid,
        awardedAt: b.awardedAt,
        badge: b,
        displayName:
            data?['nombre'] as String? ?? data?['displayName'] as String?,
        photoUrl:
            data?['photoUrl'] as String? ?? data?['profileImageUrl'] as String?,
        profilePicType: data?['profilePicType'] as String?,
        avatarConfig: data?['avatarConfig'] as Map<String, dynamic>?,
      ));
    }

    items.sort((a, b) => b.awardedAt.compareTo(a.awardedAt));
    groupHistory.value = items.take(50).toList();
  }

  void dispose() {
    isLoading.dispose();
    error.dispose();
    medalsTable.dispose();
    badgesTable.dispose();
    myMedalHistory.dispose();
    myBadgeHistory.dispose();
    groupHistory.dispose();
  }
}


