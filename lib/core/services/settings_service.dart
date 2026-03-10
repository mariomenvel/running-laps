import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsService {
  static const String _keyAlarmEnabled = 'pref_alarm_enabled';
  static const String _keyGpsDefault = 'pref_gps_default';
  static const String _keyCardStyle = 'home_card_style';

  // Reactive notifier: true = white/Moderno, false = colored/Clásico.
  // Initialized to true (white) until initCardStyle() loads the saved value.
  static final ValueNotifier<bool> cardStyleNotifier = ValueNotifier<bool>(true);
  
  // Alarm Details
  static const String _keyAlarmMode = 'pref_alarm_mode'; // 'time' or 'pace'
  static const String _keyAlarmTimeMin = 'pref_alarm_time_min';
  static const String _keyAlarmTimeSec = 'pref_alarm_time_sec';
  static const String _keyAlarmPaceMin = 'pref_alarm_pace_min';
  static const String _keyAlarmPaceSec = 'pref_alarm_pace_sec';
  static const String _keyAlarmSegment = 'pref_alarm_segment';

  SettingsService();

  Future<bool> getAlarmEnabled() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_keyAlarmEnabled) ?? false;
    } catch (e) {
      return false;
    }
  }

  Future<void> setAlarmEnabled(bool value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyAlarmEnabled, value);
    } catch (e) {}
  }

  Future<bool> getGpsDefault() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_keyGpsDefault) ?? false;
    } catch (e) {
      return false;
    }
  }

  Future<void> setGpsDefault(bool value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyGpsDefault, value);
    } catch (e) {}
  }

  // --- Card Style ---

  /// Returns true when the user prefers the white/Moderno style (default).
  Future<bool> getCardStyle() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return (prefs.getString(_keyCardStyle) ?? 'white') == 'white';
    } catch (e) {
      return true;
    }
  }

  /// Persists the choice and updates [cardStyleNotifier] so listeners rebuild.
  Future<void> setCardStyle(bool isWhite) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyCardStyle, isWhite ? 'white' : 'colored');
      cardStyleNotifier.value = isWhite;
    } catch (e) {}
  }

  /// Loads the saved value into [cardStyleNotifier]. Call once on app start.
  Future<void> initCardStyle() async {
    cardStyleNotifier.value = await getCardStyle();
  }

  // --- Alarm Configuration ---

  Future<Map<String, dynamic>> getAlarmConfig() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return {
        'mode': prefs.getString(_keyAlarmMode) ?? 'time',
        'timeMin': prefs.getInt(_keyAlarmTimeMin) ?? 1,
        'timeSec': prefs.getDouble(_keyAlarmTimeSec) ?? 30.0,
        'paceMin': prefs.getInt(_keyAlarmPaceMin) ?? 5,
        'paceSec': prefs.getInt(_keyAlarmPaceSec) ?? 0,
        'segment': prefs.getInt(_keyAlarmSegment) ?? 400,
      };
    } catch (e) {
      return {
        'mode': 'time',
        'timeMin': 1,
        'timeSec': 30.0,
        'paceMin': 5,
        'paceSec': 0,
        'segment': 400,
      };
    }
  }

  Future<void> saveAlarmConfig({
    required String mode,
    required int timeMin,
    required double timeSec,
    required int paceMin,
    required int paceSec,
    required int segment,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyAlarmMode, mode);
      await prefs.setInt(_keyAlarmTimeMin, timeMin);
      await prefs.setDouble(_keyAlarmTimeSec, timeSec);
      await prefs.setInt(_keyAlarmPaceMin, paceMin);
      await prefs.setInt(_keyAlarmPaceSec, paceSec);
      await prefs.setInt(_keyAlarmSegment, segment);
    } catch (e) {}
  }
}
