import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:running_laps/core/widgets/app_bottom_sheet.dart';

void main() {
  group('AppBottomSheetContainer', () {
    Widget buildSubject({
      bool showHandle = true,
      Widget child = const Text('Contenido'),
    }) {
      return MaterialApp(
        home: Scaffold(
          body: AppBottomSheetContainer(
            showHandle: showHandle,
            child: child,
          ),
        ),
      );
    }

    testWidgets('renderiza el contenido hijo', (tester) async {
      await tester.pumpWidget(buildSubject());
      expect(find.text('Contenido'), findsOneWidget);
    });

    testWidgets('muestra handle cuando showHandle es true',
        (tester) async {
      await tester.pumpWidget(buildSubject(showHandle: true));
      final containers = tester.widgetList<Container>(
        find.byType(Container),
      );
      final handle = containers.where((c) {
        final decoration = c.decoration as BoxDecoration?;
        return decoration?.borderRadius != null &&
            c.constraints?.maxWidth == 36;
      });
      expect(handle, isNotEmpty);
    });

    testWidgets('oculta handle cuando showHandle es false',
        (tester) async {
      await tester.pumpWidget(buildSubject(showHandle: false));
      final containers = tester.widgetList<Container>(
        find.byType(Container),
      );
      final handle = containers.where((c) {
        return c.constraints?.maxWidth == 36;
      });
      expect(handle, isEmpty);
    });

    testWidgets('tiene bordes superiores redondeados', (tester) async {
      await tester.pumpWidget(buildSubject());
      final container = tester.widget<Container>(
        find.byType(Container).first,
      );
      final decoration = container.decoration as BoxDecoration;
      final radius = decoration.borderRadius as BorderRadius?;
      expect(radius?.topLeft, const Radius.circular(20));
      expect(radius?.topRight, const Radius.circular(20));
    });
  });

  group('showAppBottomSheet', () {
    testWidgets('muestra el contenido en un sheet', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (ctx) => TextButton(
              onPressed: () => showAppBottomSheet(
                context: ctx,
                builder: (_) => const Text('Contenido sheet'),
              ),
              child: const Text('Abrir'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Abrir'));
      await tester.pumpAndSettle();
      expect(find.text('Contenido sheet'), findsOneWidget);
    });
  });
}
