import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;

class NotificationService {
  static final NotificationService _instance =
      NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  static const int _sessionReminderId = 1;
  static const int _personalRecordId  = 2;
  static const int _weeklySummaryId   = 3;

  static const _sessionChannel = AndroidNotificationChannel(
    'session_reminder',
    'Recordatorios de sesión',
    description: 'Recordatorio antes de tu sesión planificada',
    importance: Importance.high,
  );
  static const _recordChannel = AndroidNotificationChannel(
    'personal_records',
    'Récords personales',
    description: 'Nuevo récord personal detectado',
    importance: Importance.high,
  );
  static const _summaryChannel = AndroidNotificationChannel(
    'weekly_summary',
    'Resumen semanal',
    description: 'Resumen de tu semana de entrenamiento',
    importance: Importance.defaultImportance,
  );

  Future<void> init() async {
    if (_initialized) return;
    tz_data.initializeTimeZones();

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    await _plugin.initialize(
      const InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      ),
    );

    final androidImpl = _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    await androidImpl?.createNotificationChannel(_sessionChannel);
    await androidImpl?.createNotificationChannel(_recordChannel);
    await androidImpl?.createNotificationChannel(_summaryChannel);

    _initialized = true;
  }

  Future<bool> requestPermissions() async {
    if (Platform.isIOS) {
      final ios = _plugin
          .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>();
      final granted = await ios?.requestPermissions(
        alert: true, badge: true, sound: true);
      return granted ?? false;
    }
    if (Platform.isAndroid) {
      final android = _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      final granted = await android?.requestNotificationsPermission();
      return granted ?? false;
    }
    return false;
  }

  Future<void> scheduleSessionReminder({
    required String sessionId,
    required DateTime sessionDateTime,
    required String sessionTitle,
  }) async {
    await init();
    final reminderTime =
        sessionDateTime.subtract(const Duration(hours: 1));
    if (reminderTime.isBefore(DateTime.now())) return;

    final tzTime = tz.TZDateTime.from(reminderTime, tz.local);

    await _plugin.zonedSchedule(
      _sessionReminderId,
      '¡Entreno en 1 hora!',
      sessionTitle,
      tzTime,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _sessionChannel.id,
          _sessionChannel.name,
          channelDescription: _sessionChannel.description,
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentSound: true,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
    debugPrint(
        '[NotificationService] session reminder scheduled for $reminderTime');
  }

  Future<void> cancelSessionReminder() async {
    await _plugin.cancel(_sessionReminderId);
  }

  Future<void> showPersonalRecord({
    required String distance,
    required String pace,
  }) async {
    await init();
    await _plugin.show(
      _personalRecordId,
      '🏆 ¡Nuevo récord personal!',
      '$distance en $pace /km',
      NotificationDetails(
        android: AndroidNotificationDetails(
          _recordChannel.id,
          _recordChannel.name,
          channelDescription: _recordChannel.description,
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentSound: true,
        ),
      ),
    );
  }

  Future<void> scheduleWeeklySummary() async {
    await init();
    final now = DateTime.now();
    var nextSunday = now;
    while (nextSunday.weekday != DateTime.sunday) {
      nextSunday = nextSunday.add(const Duration(days: 1));
    }
    nextSunday = DateTime(
      nextSunday.year, nextSunday.month, nextSunday.day, 20, 0);
    if (nextSunday.isBefore(now)) {
      nextSunday = nextSunday.add(const Duration(days: 7));
    }

    final tzTime = tz.TZDateTime.from(nextSunday, tz.local);

    await _plugin.zonedSchedule(
      _weeklySummaryId,
      'Resumen semanal 📊',
      'Revisa cómo ha ido tu semana de entrenamiento',
      tzTime,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _summaryChannel.id,
          _summaryChannel.name,
          channelDescription: _summaryChannel.description,
          importance: Importance.defaultImportance,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentSound: true,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
    );
    debugPrint(
        '[NotificationService] weekly summary scheduled for $nextSunday');
  }

  Future<void> cancelAll() async {
    await _plugin.cancelAll();
  }
}
