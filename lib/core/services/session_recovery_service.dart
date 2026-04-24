import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../features/training/data/serie.dart';

class SessionRecoveryService {
  static final SessionRecoveryService _instance =
      SessionRecoveryService._internal();
  factory SessionRecoveryService() => _instance;
  SessionRecoveryService._internal();

  static const _key = 'active_training_session';

  Future<void> saveSession({
    required List<Serie> series,
    required bool gpsOn,
    required DateTime startTime,
    required String? templateName,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = {
        'series': series.map((s) => s.toMap()).toList(),
        'gpsOn': gpsOn,
        'startTime': startTime.toIso8601String(),
        'templateName': templateName,
        'savedAt': DateTime.now().toIso8601String(),
      };
      await prefs.setString(_key, jsonEncode(data));
      debugPrint('[SessionRecovery] session saved (${series.length} series)');
    } catch (e) {
      debugPrint('[SessionRecovery] save error: $e');
    }
  }

  Future<RecoveredSession?> loadSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw == null) return null;

      final data = jsonDecode(raw) as Map<String, dynamic>;
      final savedAt = DateTime.parse(data['savedAt'] as String);

      if (DateTime.now().difference(savedAt).inHours > 24) {
        await clearSession();
        return null;
      }

      final series = (data['series'] as List)
          .map((s) => Serie.fromMap(s as Map<String, dynamic>))
          .toList();

      return RecoveredSession(
        series: series,
        gpsOn: data['gpsOn'] as bool? ?? false,
        startTime: DateTime.parse(data['startTime'] as String),
        templateName: data['templateName'] as String?,
        savedAt: savedAt,
      );
    } catch (e) {
      debugPrint('[SessionRecovery] load error: $e');
      await clearSession();
      return null;
    }
  }

  Future<void> clearSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_key);
      debugPrint('[SessionRecovery] session cleared');
    } catch (e) {
      debugPrint('[SessionRecovery] clear error: $e');
    }
  }

  Future<bool> hasActiveSession() async {
    final session = await loadSession();
    return session != null;
  }
}

class RecoveredSession {
  final List<Serie> series;
  final bool gpsOn;
  final DateTime startTime;
  final String? templateName;
  final DateTime savedAt;

  RecoveredSession({
    required this.series,
    required this.gpsOn,
    required this.startTime,
    required this.templateName,
    required this.savedAt,
  });

  Duration get elapsed => DateTime.now().difference(startTime);

  String get elapsedFormatted {
    final h = elapsed.inHours;
    final m = elapsed.inMinutes % 60;
    if (h > 0) return '${h}h ${m}min';
    return '${m}min';
  }
}
