import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:running_laps/core/widgets/app_date_picker.dart';

void main() {
  group('showAppDatePicker', () {
    Future<void> openPicker(WidgetTester tester,
        {DateTime? initialDate}) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (ctx) => TextButton(
              onPressed: () => showAppDatePicker(
                context: ctx,
                initialDate: initialDate ?? DateTime(1990, 6, 15),
                minimumDate: DateTime(1940),
                maximumDate: DateTime(2010),
                title: 'Fecha test',
              ),
              child: const Text('Abrir'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Abrir'));
      await tester.pumpAndSettle();
    }

    testWidgets('muestra el sheet con título', (tester) async {
      await openPicker(tester);
      expect(find.text('Fecha test'), findsOneWidget);
    });

    testWidgets('muestra botones Cancelar y Confirmar', (tester) async {
      await openPicker(tester);
      expect(find.text('Cancelar'), findsOneWidget);
      expect(find.text('Confirmar'), findsOneWidget);
    });

    testWidgets('muestra CupertinoDatePicker', (tester) async {
      await openPicker(tester);
      expect(find.byType(CupertinoDatePicker), findsOneWidget);
    });

    testWidgets('Cancelar cierra el sheet y devuelve null',
        (tester) async {
      DateTime? result;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (ctx) => TextButton(
              onPressed: () async {
                result = await showAppDatePicker(
                  context: ctx,
                  initialDate: DateTime(1990),
                  title: 'Test',
                );
              },
              child: const Text('Abrir'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Abrir'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      expect(result, isNull);
    });

    testWidgets('Confirmar cierra el sheet y devuelve fecha',
        (tester) async {
      DateTime? result;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (ctx) => TextButton(
              onPressed: () async {
                result = await showAppDatePicker(
                  context: ctx,
                  initialDate: DateTime(1990, 6, 15),
                  title: 'Test',
                );
              },
              child: const Text('Abrir'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Abrir'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Confirmar'));
      await tester.pumpAndSettle();
      expect(result, isNotNull);
      expect(result?.year, 1990);
    });

    testWidgets('clampea initialDate dentro del rango', (tester) async {
      await openPicker(tester, initialDate: DateTime(1900));
      expect(find.byType(CupertinoDatePicker), findsOneWidget);
    });
  });
}
