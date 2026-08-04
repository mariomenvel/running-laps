import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:running_laps/core/widgets/app_confirm_dialog.dart';
import 'package:running_laps/core/widgets/app_dialog.dart';

void main() {
  group('showAppConfirmDialog', () {
    Future<bool?> openDialog(
      WidgetTester tester, {
      bool isDestructive = false,
      String confirmLabel = 'Confirmar',
      String cancelLabel = 'Cancelar',
      String? message,
    }) async {
      bool? result;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (ctx) => TextButton(
              onPressed: () async {
                result = await showAppConfirmDialog(
                  context: ctx,
                  title: 'Título test',
                  message: message,
                  confirmLabel: confirmLabel,
                  cancelLabel: cancelLabel,
                  isDestructive: isDestructive,
                );
              },
              child: const Text('Abrir'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Abrir'));
      await tester.pumpAndSettle();
      return result;
    }

    testWidgets('muestra título y botones', (tester) async {
      await openDialog(tester);
      expect(find.text('Título test'), findsOneWidget);
      expect(find.text('Confirmar'), findsOneWidget);
      expect(find.text('Cancelar'), findsOneWidget);
    });

    testWidgets('muestra mensaje si se proporciona', (tester) async {
      await openDialog(tester, message: 'Mensaje de prueba');
      expect(find.text('Mensaje de prueba'), findsOneWidget);
    });

    testWidgets('no muestra mensaje si es null', (tester) async {
      await openDialog(tester);
      expect(find.text('Mensaje de prueba'), findsNothing);
    });

    testWidgets('Cancelar cierra el diálogo y devuelve false',
        (tester) async {
      bool? result;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (ctx) => TextButton(
              onPressed: () async {
                result = await showAppConfirmDialog(
                  context: ctx,
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
      expect(result, false);
    });

    testWidgets('Confirmar cierra el diálogo y devuelve true',
        (tester) async {
      bool? result;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (ctx) => TextButton(
              onPressed: () async {
                result = await showAppConfirmDialog(
                  context: ctx,
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
      expect(result, true);
    });

    testWidgets('labels personalizados se muestran', (tester) async {
      await openDialog(
        tester,
        confirmLabel: 'Salir',
        cancelLabel: 'Volver',
      );
      expect(find.text('Salir'), findsOneWidget);
      expect(find.text('Volver'), findsOneWidget);
    });

    testWidgets('es el diálogo propio, no uno de plataforma', (tester) async {
      // Una sola cara en Android e iOS: ni CupertinoAlertDialog (que se veía
      // como iOS 13) ni AlertDialog de Material.
      await openDialog(tester);
      expect(find.byType(AppDialog), findsOneWidget);
      expect(find.byType(CupertinoAlertDialog), findsNothing);
      expect(find.byType(AlertDialog), findsNothing);
    });

    testWidgets('isDestructive pinta el botón de acción en rojo',
        (tester) async {
      await openDialog(tester, isDestructive: true);
      final action = tester.widget<AppDialogPrimaryAction>(
        find.widgetWithText(AppDialogPrimaryAction, 'Confirmar'),
      );
      expect(action.isDestructive, isTrue);
    });

    testWidgets('sin isDestructive el botón va en color de marca',
        (tester) async {
      await openDialog(tester, isDestructive: false);
      final action = tester.widget<AppDialogPrimaryAction>(
        find.widgetWithText(AppDialogPrimaryAction, 'Confirmar'),
      );
      expect(action.isDestructive, isFalse);
    });

    testWidgets('cancelar y confirmar son botones distintos', (tester) async {
      // El que ejecuta la acción es el primario; el de cancelar, secundario.
      // Si se invirtieran, un toque distraído borraría datos.
      await openDialog(tester);
      expect(find.byType(AppDialogPrimaryAction), findsOneWidget);
      expect(find.byType(AppDialogSecondaryAction), findsOneWidget);
      expect(
        find.widgetWithText(AppDialogSecondaryAction, 'Cancelar'),
        findsOneWidget,
      );
    });
  });
}
