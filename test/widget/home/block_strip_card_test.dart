import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:running_laps/features/ai_coach/data/ai_coach_models.dart';
import 'package:running_laps/features/ai_coach/views/coach_philosophy_view.dart';
import 'package:running_laps/features/home/widgets/home_block_strip.dart';

/// Tarjeta del mesociclo en Home (docs/AI_COACH_MESOCYCLE.md fase 3).
///
/// Es la parte que el atleta ve, así que lo que se prueba aquí es que diga la
/// verdad: la posición dentro del bloque y que la semana de descarga se nombre
/// como tal en vez de disfrazarse de semana normal.
void main() {
  AiCoachMesocycle blockWith({
    List<AiCoachWeekType>? pattern,
    AiCoachBlockPhase phase = AiCoachBlockPhase.base,
    String focus = 'Construyendo base aerobica',
  }) {
    final weeks = pattern ??
        const [
          AiCoachWeekType.build,
          AiCoachWeekType.build,
          AiCoachWeekType.build,
          AiCoachWeekType.absorb,
        ];
    return AiCoachMesocycle(
      id: 'meso-1',
      startWeek: DateTime(2026, 8, 3),
      lengthWeeks: weeks.length,
      phase: phase,
      weekPattern: weeks,
      baselineVolumeKm: 30,
      volumeCeilingKm: 45,
      volumeStepPct: 0.08,
      deloadVolumePct: 0.60,
      focus: focus,
      createdAt: DateTime(2026, 7, 28),
    );
  }

  Future<void> pump(WidgetTester tester, Widget child) {
    return tester.pumpWidget(
      MaterialApp(home: Scaffold(body: SingleChildScrollView(child: child))),
    );
  }

  testWidgets('muestra la posición dentro del bloque', (tester) async {
    await pump(tester, BlockStripCard(block: blockWith(), weekIndex: 1));
    expect(find.text('BLOQUE BASE · Semana 2 de 4'), findsOneWidget);
  });

  testWidgets('muestra el foco del bloque', (tester) async {
    await pump(
      tester,
      BlockStripCard(block: blockWith(focus: 'Trabajo de umbral'), weekIndex: 0),
    );
    expect(find.text('Trabajo de umbral'), findsOneWidget);
  });

  testWidgets('la semana de descarga se nombra explícitamente', (tester) async {
    await pump(tester, BlockStripCard(block: blockWith(), weekIndex: 3));
    expect(find.text('Descarga'), findsOneWidget);
  });

  testWidgets('una semana de carga no lleva etiqueta', (tester) async {
    await pump(tester, BlockStripCard(block: blockWith(), weekIndex: 0));
    expect(find.text('Descarga'), findsNothing);
    expect(find.text('Taper'), findsNothing);
  });

  testWidgets('el bloque de novato muestra 3 semanas, no 4', (tester) async {
    final block = blockWith(
      pattern: const [
        AiCoachWeekType.build,
        AiCoachWeekType.build,
        AiCoachWeekType.absorb,
      ],
    );
    await pump(tester, BlockStripCard(block: block, weekIndex: 0));
    expect(find.text('BLOQUE BASE · Semana 1 de 3'), findsOneWidget);
  });

  testWidgets('el taper se etiqueta y cambia la fase', (tester) async {
    final block = blockWith(
      pattern: const [
        AiCoachWeekType.taper,
        AiCoachWeekType.taper,
        AiCoachWeekType.race,
      ],
      phase: AiCoachBlockPhase.taper,
    );
    await pump(tester, BlockStripCard(block: block, weekIndex: 0));
    expect(find.textContaining('AFINANDO'), findsOneWidget);
    expect(find.text('Taper'), findsOneWidget);
  });

  testWidgets('la vuelta tras parón se nombra como tal', (tester) async {
    final block = blockWith(
      pattern: const [
        AiCoachWeekType.restart,
        AiCoachWeekType.build,
        AiCoachWeekType.build,
        AiCoachWeekType.absorb,
      ],
    );
    await pump(tester, BlockStripCard(block: block, weekIndex: 0));
    expect(find.text('Vuelta'), findsOneWidget);
  });

  _curveTests();

  test('isEasyWeek clasifica las semanas de respiro', () {
    expect(BlockStripCard.isEasyWeek(AiCoachWeekType.absorb), isTrue);
    expect(BlockStripCard.isEasyWeek(AiCoachWeekType.recovery), isTrue);
    expect(BlockStripCard.isEasyWeek(AiCoachWeekType.taper), isTrue);
    expect(BlockStripCard.isEasyWeek(AiCoachWeekType.restart), isTrue);
    expect(BlockStripCard.isEasyWeek(AiCoachWeekType.build), isFalse);
    expect(BlockStripCard.isEasyWeek(AiCoachWeekType.race), isFalse);
  });
}

/// Curva de volumen del bloque en "Cómo entrena tu coach".
void _curveTests() {
  AiCoachMesocycle block() => AiCoachMesocycle(
        id: 'meso-1',
        startWeek: DateTime(2026, 8, 3),
        lengthWeeks: 4,
        phase: AiCoachBlockPhase.base,
        weekPattern: const [
          AiCoachWeekType.build,
          AiCoachWeekType.build,
          AiCoachWeekType.build,
          AiCoachWeekType.absorb,
        ],
        baselineVolumeKm: 30,
        volumeCeilingKm: 45,
        volumeStepPct: 0.08,
        deloadVolumePct: 0.60,
        focus: 'Construyendo base aerobica',
        createdAt: DateTime(2026, 7, 28),
      );

  testWidgets('dibuja una barra por semana del bloque', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: BlockVolumeCurve(block: block(), today: DateTime(2026, 8, 5)),
      ),
    ));
    expect(find.text('S1'), findsOneWidget);
    expect(find.text('S4'), findsOneWidget);
    expect(find.text('Tu bloque ahora'), findsOneWidget);
  });

  testWidgets('la descarga se dibuja por debajo del pico', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: BlockVolumeCurve(block: block(), today: DateTime(2026, 8, 5)),
      ),
    ));
    // Semana 3 es el pico (32 km) y la 4 la descarga (19 km).
    expect(find.text('32'), findsOneWidget);
    expect(find.text('19'), findsOneWidget);
  });
}
