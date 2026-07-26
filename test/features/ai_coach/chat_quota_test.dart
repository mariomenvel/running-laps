import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:running_laps/features/ai_coach/data/ai_coach_chat_service.dart';
import 'package:running_laps/features/ai_coach/data/ai_coach_models.dart';
import 'package:running_laps/features/ai_coach/data/ai_coach_repository.dart';

/// Cuota semanal del chat con el coach.
///
/// Esta lógica ha roto dos veces y las dos de forma silenciosa: una vez el
/// contador se quedaba pillado y el chat no dejaba escribir aunque hubiera
/// empezado una semana nueva, y otra el badge enseñaba el límite guardado (40)
/// en vez del canónico. Los tres caminos —crear, resetear y normalizar— quedan
/// fijados aquí.
void main() {
  const uid = 'test-uid-chat';
  const canonicalLimit = 3;

  late FakeFirebaseFirestore db;
  late AiCoachChatService service;
  late AiCoachRepository repo;

  DateTime mondayOf(DateTime d) {
    final day = DateTime(d.year, d.month, d.day);
    return day.subtract(Duration(days: day.weekday - 1));
  }

  setUp(() {
    db = FakeFirebaseFirestore();
    repo = AiCoachRepository(firestore: db);
    service = AiCoachChatService(repository: repo);
  });

  Future<void> seedUsage(AiCoachUsage usage) => repo.saveUsage(usage, uid: uid);

  test('sin cuota previa la crea para la semana en curso', () async {
    final usage = await service.prepareCurrentWeekUsage(uid);

    final expectedStart = mondayOf(DateTime.now());
    expect(usage.messagesUsed, 0);
    expect(usage.messagesLimit, canonicalLimit);
    expect(usage.periodStart, expectedStart);
    expect(usage.periodEnd.weekday, DateTime.sunday);
    expect(usage.periodEnd.hour, 23);

    // Y queda persistida, no solo devuelta.
    final stored = await repo.getUsage(uid: uid);
    expect(stored!.messagesLimit, canonicalLimit);
  });

  test('una cuota de una semana pasada resetea el contador', () async {
    final lastWeekStart = mondayOf(DateTime.now())
        .subtract(const Duration(days: 7));
    await seedUsage(AiCoachUsage(
      plan: 'athlete_chat_weekly',
      messagesUsed: 3,
      messagesLimit: canonicalLimit,
      periodStart: lastWeekStart,
      periodEnd: lastWeekStart.add(
        const Duration(days: 6, hours: 23, minutes: 59, seconds: 59),
      ),
    ));

    final usage = await service.prepareCurrentWeekUsage(uid);

    expect(usage.messagesUsed, 0, reason: 'semana nueva, contador a cero');
    expect(usage.periodStart, mondayOf(DateTime.now()));
  });

  test('una cuota de la semana en curso se respeta tal cual', () async {
    final weekStart = mondayOf(DateTime.now());
    await seedUsage(AiCoachUsage(
      plan: 'athlete_chat_weekly',
      messagesUsed: 2,
      messagesLimit: canonicalLimit,
      periodStart: weekStart,
      periodEnd: DateTime(
        weekStart.year, weekStart.month, weekStart.day + 6, 23, 59, 59,
      ),
    ));

    final usage = await service.prepareCurrentWeekUsage(uid);

    expect(usage.messagesUsed, 2,
        reason: 'no se puede regalar cuota a mitad de semana');
  });

  test('un límite guardado antiguo se normaliza sin perder los contadores',
      () async {
    // El bug real: el badge mostraba el límite guardado (40) en vez del
    // canónico. Al normalizarlo hay que conservar lo ya consumido, incluido
    // previewsGenerated, que es el contador anti-abuso.
    final weekStart = mondayOf(DateTime.now());
    await seedUsage(AiCoachUsage(
      plan: 'athlete_chat_weekly',
      messagesUsed: 2,
      previewsGenerated: 5,
      messagesLimit: 40,
      periodStart: weekStart,
      periodEnd: DateTime(
        weekStart.year, weekStart.month, weekStart.day + 6, 23, 59, 59,
      ),
    ));

    final usage = await service.prepareCurrentWeekUsage(uid);

    expect(usage.messagesLimit, canonicalLimit);
    expect(usage.messagesUsed, 2);
    expect(usage.previewsGenerated, 5,
        reason: 'normalizar el límite no puede resetear el anti-abuso');
  });

  test('una cuota con el periodo en el futuro se resetea', () async {
    // Reloj del dispositivo mal puesto en su día: sin esto, la cuota se
    // quedaría bloqueada hasta que llegara esa fecha.
    final future = mondayOf(DateTime.now()).add(const Duration(days: 14));
    await seedUsage(AiCoachUsage(
      plan: 'athlete_chat_weekly',
      messagesUsed: 3,
      messagesLimit: canonicalLimit,
      periodStart: future,
      periodEnd: future.add(const Duration(days: 6)),
    ));

    final usage = await service.prepareCurrentWeekUsage(uid);

    expect(usage.messagesUsed, 0);
    expect(usage.periodStart, mondayOf(DateTime.now()));
  });
}
