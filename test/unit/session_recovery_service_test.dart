import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:running_laps/core/services/session_recovery_service.dart';
import 'package:running_laps/features/training/data/serie.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const key = 'active_training_session';
  final service = SessionRecoveryService();

  Serie makeSerie() => Serie(
        tiempoSec: 120,
        distanciaM: 400,
        descansoSec: 60,
        rpe: 7,
      );

  group('SessionRecoveryService', () {
    test('guardar y recuperar una sesión activa', () async {
      SharedPreferences.setMockInitialValues({});
      final start = DateTime(2026, 7, 10, 9, 30);

      await service.saveSession(
        series: [makeSerie(), makeSerie()],
        gpsOn: true,
        startTime: start,
        templateName: 'Series 400',
      );

      final recovered = await service.loadSession();

      expect(recovered, isNotNull);
      expect(recovered!.series, hasLength(2));
      expect(recovered.series.first.distanciaM, 400);
      expect(recovered.gpsOn, isTrue);
      expect(recovered.startTime, start);
      expect(recovered.templateName, 'Series 400');
    });

    test('sin sesión guardada devuelve null', () async {
      SharedPreferences.setMockInitialValues({});
      expect(await service.loadSession(), isNull);
      expect(await service.hasActiveSession(), isFalse);
    });

    test('una sesión de hace más de 24h se descarta y se limpia', () async {
      final old = DateTime.now().subtract(const Duration(hours: 25));
      SharedPreferences.setMockInitialValues({
        key: jsonEncode({
          'series': [makeSerie().toMap()],
          'gpsOn': false,
          'startTime': old.toIso8601String(),
          'templateName': null,
          'savedAt': old.toIso8601String(),
        }),
      });

      expect(await service.loadSession(), isNull);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(key), isNull,
          reason: 'la sesión caducada debe eliminarse');
    });

    test('JSON corrupto devuelve null y limpia la clave', () async {
      SharedPreferences.setMockInitialValues({key: '{esto no es json'});

      expect(await service.loadSession(), isNull);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(key), isNull);
    });

    test('clearSession elimina la sesión activa', () async {
      SharedPreferences.setMockInitialValues({});
      await service.saveSession(
        series: [makeSerie()],
        gpsOn: false,
        startTime: DateTime.now(),
        templateName: null,
      );
      expect(await service.hasActiveSession(), isTrue);

      await service.clearSession();
      expect(await service.hasActiveSession(), isFalse);
    });
  });
}
