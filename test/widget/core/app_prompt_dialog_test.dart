import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:running_laps/core/widgets/app_prompt_dialog.dart';

void main() {
  group('showAppPromptDialog', () {
    /// Abre el diálogo y devuelve un getter del resultado. Se usa un getter
    /// porque el `await` de showAppPromptDialog solo se resuelve cuando el
    /// diálogo se cierra, ya bien entrado el test.
    late String? result;
    late bool resolved;

    Future<void> openDialog(
      WidgetTester tester, {
      String? initialValue,
      String? hintText,
      int? maxLength,
      String confirmLabel = 'Guardar',
    }) async {
      result = null;
      resolved = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (ctx) => TextButton(
              onPressed: () async {
                result = await showAppPromptDialog(
                  context: ctx,
                  title: 'Guardar bloque',
                  hintText: hintText,
                  initialValue: initialValue,
                  maxLength: maxLength,
                  confirmLabel: confirmLabel,
                );
                resolved = true;
              },
              child: const Text('Abrir'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Abrir'));
      await tester.pumpAndSettle();
    }

    testWidgets('es un diálogo Cupertino, no Material', (tester) async {
      await openDialog(tester);
      expect(find.byType(CupertinoAlertDialog), findsOneWidget);
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.byType(CupertinoTextField), findsOneWidget);
    });

    testWidgets('muestra título, placeholder y botones', (tester) async {
      await openDialog(tester, hintText: 'Nombre del bloque');
      expect(find.text('Guardar bloque'), findsOneWidget);
      expect(find.text('Nombre del bloque'), findsOneWidget);
      expect(find.text('Guardar'), findsOneWidget);
      expect(find.text('Cancelar'), findsOneWidget);
    });

    testWidgets('precarga initialValue y lo deja seleccionado', (tester) async {
      await openDialog(tester, initialValue: 'Series 400m');
      final field = tester.widget<CupertinoTextField>(
        find.byType(CupertinoTextField),
      );
      expect(field.controller!.text, 'Series 400m');
      // Seleccionado entero: escribir encima reemplaza el nombre por defecto
      // en vez de concatenarse.
      expect(field.controller!.selection.baseOffset, 0);
      expect(field.controller!.selection.extentOffset, 'Series 400m'.length);
    });

    testWidgets('devuelve el texto al confirmar', (tester) async {
      await openDialog(tester);
      await tester.enterText(find.byType(CupertinoTextField), 'Mi bloque');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Guardar'));
      await tester.pumpAndSettle();
      expect(result, 'Mi bloque');
    });

    testWidgets('recorta los espacios del texto devuelto', (tester) async {
      await openDialog(tester);
      await tester.enterText(find.byType(CupertinoTextField), '  Rodaje  ');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Guardar'));
      await tester.pumpAndSettle();
      expect(result, 'Rodaje');
    });

    testWidgets('devuelve null al cancelar', (tester) async {
      await openDialog(tester, initialValue: 'Algo');
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      expect(resolved, isTrue);
      expect(result, isNull);
    });

    testWidgets('el botón de confirmar está deshabilitado si está vacío',
        (tester) async {
      await openDialog(tester);
      final accion = tester.widget<CupertinoDialogAction>(
        find.widgetWithText(CupertinoDialogAction, 'Guardar'),
      );
      expect(accion.onPressed, isNull);
    });

    testWidgets('un texto de solo espacios tampoco habilita el botón',
        (tester) async {
      await openDialog(tester);
      await tester.enterText(find.byType(CupertinoTextField), '   ');
      await tester.pumpAndSettle();
      final accion = tester.widget<CupertinoDialogAction>(
        find.widgetWithText(CupertinoDialogAction, 'Guardar'),
      );
      expect(accion.onPressed, isNull);
    });

    testWidgets('el botón se habilita al escribir', (tester) async {
      await openDialog(tester);
      await tester.enterText(find.byType(CupertinoTextField), 'x');
      await tester.pumpAndSettle();
      final accion = tester.widget<CupertinoDialogAction>(
        find.widgetWithText(CupertinoDialogAction, 'Guardar'),
      );
      expect(accion.onPressed, isNotNull);
    });

    testWidgets('respeta maxLength', (tester) async {
      await openDialog(tester, maxLength: 5);
      final field = tester.widget<CupertinoTextField>(
        find.byType(CupertinoTextField),
      );
      expect(field.maxLength, 5);
    });

    testWidgets('el label del botón de confirmar es configurable',
        (tester) async {
      await openDialog(tester, confirmLabel: 'Crear');
      expect(find.text('Crear'), findsOneWidget);
      expect(find.text('Guardar'), findsNothing);
    });
  });
}
