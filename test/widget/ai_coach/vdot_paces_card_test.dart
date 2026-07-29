import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:running_laps/features/ai_coach/data/ai_coach_models.dart';
import 'package:running_laps/features/ai_coach/views/vdot_paces_card.dart';

/// Tarjeta de ritmos en "Cómo entrena tu coach".
///
/// La pantalla ya prometía que los ritmos salen de las marcas reales del
/// atleta. Lo que se prueba aquí es que esa promesa sea comprobable: que se
/// vean los ritmos, que se vea la variación, y que se explique por qué cambió.
void main() {
  AiCoachVdotEstimate estimateWith({
    double vdot = 50,
    String reason = '',
    List<double> history = const [],
  }) =>
      AiCoachVdotEstimate(
        vdot: vdot,
        source: 'training_evidence',
        updatedAt: DateTime(2026, 7, 28),
        lastReason: reason,
        history: [
          for (var i = 0; i < history.length; i++)
            AiCoachVdotPoint(
              vdot: history[i],
              date: DateTime(2026, 7, 1).add(Duration(days: 7 * i)),
            ),
        ],
      );

  Future<void> pump(WidgetTester tester, AiCoachVdotEstimate estimate) {
    return tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: VdotPacesCard(estimate: estimate),
          ),
        ),
      ),
    );
  }

  testWidgets('muestra los tres rangos de ritmo derivados del VDOT',
      (tester) async {
    await pump(tester, estimateWith(vdot: 50));
    expect(find.text('Rodaje suave'), findsOneWidget);
    expect(find.text('5:07 – 5:54 /km'), findsOneWidget);
    expect(find.text('Umbral'), findsOneWidget);
    expect(find.text('3:50 – 4:02 /km'), findsOneWidget);
    expect(find.text('Series'), findsOneWidget);
    expect(find.text('3:29 – 3:39 /km'), findsOneWidget);
  });

  testWidgets('muestra el VDOT del que salen', (tester) async {
    await pump(tester, estimateWith(vdot: 49.5));
    expect(find.text('VDOT 49.5'), findsOneWidget);
  });

  testWidgets('explica por qué cambiaron los ritmos', (tester) async {
    await pump(
      tester,
      estimateWith(reason: 'Vas por delante de tus ritmos objetivo.'),
    );
    expect(
      find.text('Vas por delante de tus ritmos objetivo.'),
      findsOneWidget,
    );
  });

  testWidgets('sin motivo no pinta el bloque de explicación', (tester) async {
    await pump(tester, estimateWith());
    expect(find.textContaining('ritmos objetivo'), findsNothing);
  });

  group('variación respecto a la revisión anterior', () {
    testWidgets('una subida se marca con flecha arriba', (tester) async {
      await pump(tester, estimateWith(vdot: 50.5, history: [50.0, 50.5]));
      expect(find.byIcon(Icons.arrow_upward_rounded), findsOneWidget);
      expect(find.text('0.5'), findsOneWidget);
    });

    testWidgets('una bajada se marca con flecha abajo', (tester) async {
      await pump(tester, estimateWith(vdot: 49.5, history: [50.0, 49.5]));
      expect(find.byIcon(Icons.arrow_downward_rounded), findsOneWidget);
    });

    testWidgets('sin historial previo no se marca variación', (tester) async {
      await pump(tester, estimateWith(vdot: 50, history: [50.0]));
      expect(find.byIcon(Icons.arrow_upward_rounded), findsNothing);
      expect(find.byIcon(Icons.arrow_downward_rounded), findsNothing);
    });
  });

  testWidgets('sin VDOT válido la tarjeta se colapsa', (tester) async {
    await pump(tester, estimateWith(vdot: 0));
    expect(find.text('Tus ritmos ahora'), findsNothing);
  });

  test('formatPace rellena los segundos a dos dígitos', () {
    expect(VdotPacesCard.formatPace(307), '5:07');
    expect(VdotPacesCard.formatPace(240), '4:00');
    expect(VdotPacesCard.formatPace(209), '3:29');
  });
}
