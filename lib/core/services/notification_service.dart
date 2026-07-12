import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:running_laps/features/athlete/data/athlete_session_model.dart';
import 'package:running_laps/features/athlete/data/athlete_session_repository.dart';

class NotificationService {
  static final NotificationService _instance =
      NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  static const int _sessionReminderId       = 1;
  static const int _personalRecordId        = 2;
  static const int _weeklySummaryId         = 3;
  static const int _weeklyFeedbackReminderId = 4;
  static const int _trainingReminderBaseId  = 100; // 101-107 = lun-dom

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
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
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
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
    );
    debugPrint(
        '[NotificationService] weekly summary scheduled for $nextSunday');
  }

  Future<void> scheduleWeeklyFeedbackReminder() async {
    await init();
    final now = DateTime.now();
    var nextSaturday = now;
    while (nextSaturday.weekday != DateTime.saturday) {
      nextSaturday = nextSaturday.add(const Duration(days: 1));
    }
    nextSaturday = DateTime(
        nextSaturday.year, nextSaturday.month, nextSaturday.day, 9, 0);
    if (nextSaturday.isBefore(now)) {
      nextSaturday = nextSaturday.add(const Duration(days: 7));
    }

    final tzTime = tz.TZDateTime.from(nextSaturday, tz.local);

    await _plugin.zonedSchedule(
      _weeklyFeedbackReminderId,
      '📋 ¿Cómo fue tu semana?',
      'Cuéntale a tu coach cómo te sientes para ajustar tu próximo plan',
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
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
    );
    debugPrint(
        '[NotificationService] feedback reminder scheduled for $nextSaturday');
  }

  Future<void> cancelTrainingReminders() async {
    for (var i = 1; i <= 7; i++) {
      await _plugin.cancel(_trainingReminderBaseId + i);
    }
  }

  Future<void> syncTrainingReminders(String uid) async {
    await init();
    await cancelTrainingReminders();

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final daysUntilSunday = 7 - today.weekday;
    final endOfWeek = today.add(Duration(days: daysUntilSunday));

    String fmt(DateTime d) =>
        '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

    final sessions = await AthleteSessionRepository().getSessionsInRange(
      uid: uid,
      startDate: fmt(today),
      endDate: fmt(endOfWeek),
    );

    for (final session in sessions) {
      if (session.status != AthleteSessionStatus.planned) continue;

      final date = DateTime.tryParse(session.date);
      if (date == null) continue;

      final reminderTime =
          DateTime(date.year, date.month, date.day, 8, 0);
      if (reminderTime.isBefore(now)) continue;

      final tzTime = tz.TZDateTime.from(reminderTime, tz.local);
      final categoryLabel = _friendlyCategoryName(session.category ?? '');

      await _plugin.zonedSchedule(
        _trainingReminderBaseId + date.weekday,
        '🏃 Hoy toca: $categoryLabel',
        '¡A por ello! Tu coach lo tiene preparado.',
        tzTime,
        NotificationDetails(
          android: AndroidNotificationDetails(
            _sessionChannel.id,
            _sessionChannel.name,
            channelDescription: _sessionChannel.description,
            importance: Importance.defaultImportance,
            icon: '@mipmap/ic_launcher',
          ),
          iOS: const DarwinNotificationDetails(
            presentAlert: true,
            presentSound: true,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
      debugPrint(
          '[NotificationService] training reminder for ${session.date} ($categoryLabel)');
    }
  }

  String _friendlyCategoryName(String category) {
    const labels = {
      'series_cortas':   'Series cortas',
      'series_medias':   'Series medias',
      'series_largas':   'Series largas',
      'series_cuestas':  'Cuestas',
      'series_mixtas':   'Series mixtas',
      'fartlek':         'Fartlek',
      'tempo':           'Tempo',
      'rodaje_base':     'Rodaje',
      'rodaje_largo':    'Rodaje largo',
      'regenerativo':    'Regenerativo',
      'gimnasio_fuerza': 'Gimnasio',
      'test':            'Test',
      'competicion':     'Competición',
    };
    return labels[category] ?? 'Entrenamiento';
  }

  Future<void> cancelAll() async {
    await _plugin.cancelAll();
  }
}
