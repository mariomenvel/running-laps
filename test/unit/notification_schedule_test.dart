import 'package:flutter_test/flutter_test.dart';
import 'package:running_laps/core/services/notification_service.dart';

/// Cuándo se programan las notificaciones.
///
/// Equivocarse aquí no da un error: da una notificación a la hora que no toca,
/// o —peor— programada en el pasado, que en Android **salta inmediatamente**.
/// Es de las pocas cosas que el usuario percibe como "esta app me molesta".
void main() {
  group('nextWeekdayAt', () {
    test('desde un día anterior, cae en el próximo día pedido', () {
      // Lunes 20 de julio de 2026, 10:00 → sábado 25 a las 9:00.
      final result = NotificationService.nextWeekdayAt(
        DateTime(2026, 7, 20, 10),
        DateTime.saturday,
        hour: 9,
      );

      expect(result, DateTime(2026, 7, 25, 9));
    });

    test('si hoy es el día y aún no ha llegado la hora, es hoy', () {
      // Sábado 25 a las 7:00 → hoy a las 9:00.
      final result = NotificationService.nextWeekdayAt(
        DateTime(2026, 7, 25, 7),
        DateTime.saturday,
        hour: 9,
      );

      expect(result, DateTime(2026, 7, 25, 9));
    });

    test('si hoy es el día pero la hora ya pasó, salta a la semana siguiente',
        () {
      // Sábado 25 a las 10:00: programar hoy a las 9:00 sería en el pasado, y
      // en Android eso dispara la notificación al momento.
      final result = NotificationService.nextWeekdayAt(
        DateTime(2026, 7, 25, 10),
        DateTime.saturday,
        hour: 9,
      );

      expect(result, DateTime(2026, 8, 1, 9));
    });

    test('justo en la hora exacta cuenta como hoy', () {
      final result = NotificationService.nextWeekdayAt(
        DateTime(2026, 7, 25, 9),
        DateTime.saturday,
        hour: 9,
      );

      expect(result, DateTime(2026, 7, 25, 9));
    });

    test('el domingo a las 20:00 también sale bien (resumen semanal)', () {
      // Domingo 26 a las 12:00 → hoy a las 20:00.
      final result = NotificationService.nextWeekdayAt(
        DateTime(2026, 7, 26, 12),
        DateTime.sunday,
        hour: 20,
      );

      expect(result, DateTime(2026, 7, 26, 20));
    });
  });

  group('sessionReminderTime', () {
    test('avisa una hora antes de la sesión', () {
      final reminder = NotificationService.sessionReminderTime(
        DateTime(2026, 7, 25, 19, 30),
        now: DateTime(2026, 7, 25, 8),
      );

      expect(reminder, DateTime(2026, 7, 25, 18, 30));
    });

    test('no programa nada si la hora del aviso ya pasó', () {
      final reminder = NotificationService.sessionReminderTime(
        DateTime(2026, 7, 25, 8, 0),
        now: DateTime(2026, 7, 25, 7, 30), // faltan 30 min: el aviso era a las 7
      );

      expect(reminder, isNull,
          reason: 'mejor sin aviso que un aviso inmediato y absurdo');
    });

    test('una sesión de madrugada avisa el día anterior', () {
      final reminder = NotificationService.sessionReminderTime(
        DateTime(2026, 7, 25, 0, 30),
        now: DateTime(2026, 7, 24, 12),
      );

      expect(reminder, DateTime(2026, 7, 24, 23, 30));
    });
  });
}
