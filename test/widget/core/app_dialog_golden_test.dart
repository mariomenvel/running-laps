import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:running_laps/core/theme/app_colors.dart';
import 'package:running_laps/core/widgets/app_dialog.dart';

/// Renderiza el diálogo a PNG para poder mirarlo sin dispositivo.
///
/// Regenerar: `flutter test --update-goldens test/widget/core/app_dialog_golden_test.dart`
/// Las imágenes quedan en `test/widget/core/goldens/`.
void main() {
  Widget marco(Widget dialogo) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(brightness: Brightness.light, useMaterial3: true),
      home: Scaffold(
        backgroundColor: const Color(0xFFE9E9EE),
        body: Center(child: dialogo),
      ),
    );
  }

  Future<void> render(WidgetTester tester, Widget dialogo, String nombre) async {
    tester.view.physicalSize = const Size(900, 1300);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(marco(dialogo));
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/$nombre.png'),
    );
  }

  testWidgets('confirmacion normal', (tester) async {
    await render(
      tester,
      AppDialog(
        title: 'Union automatica',
        message: 'Quieres unirte automaticamente a todos los retos semanales '
            'y mensuales de este grupo?',
        actions: [
          AppDialogSecondaryAction(label: 'Cancelar', onPressed: () {}),
          AppDialogPrimaryAction(label: 'Activar', onPressed: () {}),
        ],
      ),
      'dialog_confirm',
    );
  });

  testWidgets('confirmacion destructiva', (tester) async {
    await render(
      tester,
      AppDialog(
        title: 'Descartar entrenamiento?',
        message: 'Esta accion no se puede deshacer.',
        actions: [
          AppDialogSecondaryAction(label: 'Cancelar', onPressed: () {}),
          AppDialogPrimaryAction(
            label: 'Descartar',
            isDestructive: true,
            onPressed: () {},
          ),
        ],
      ),
      'dialog_destructive',
    );
  });

  testWidgets('con campo de texto', (tester) async {
    await render(
      tester,
      AppDialog(
        title: 'Guardar bloque',
        content: TextField(
          controller: TextEditingController(text: 'Series 400m'),
          decoration: InputDecoration(
            filled: true,
            fillColor: const Color(0xFFF2F2F7),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xFFDDDDE3)),
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        actions: [
          AppDialogSecondaryAction(label: 'Cancelar', onPressed: () {}),
          AppDialogPrimaryAction(label: 'Guardar', onPressed: () {}),
        ],
      ),
      'dialog_prompt',
    );
  });

  testWidgets('boton deshabilitado y etiquetas largas', (tester) async {
    // El caso que rompia la fila: "No, preguntar siempre" no cabe al lado de
    // otro boton en pantalla estrecha, asi que se apilan.
    await render(
      tester,
      AppDialog(
        title: 'Generar datos de prueba',
        message: 'Esto borrara TODOS tus entrenamientos actuales y creara '
            'unas 55 sesiones realistas de los ultimos 90 dias.',
        actions: [
          AppDialogSecondaryAction(
            label: 'No, preguntar siempre',
            onPressed: () {},
          ),
          const AppDialogPrimaryAction(
            label: 'Borrar y generar',
            isDestructive: true,
            onPressed: null,
          ),
        ],
      ),
      'dialog_largo',
    );
  });

  test('los tokens del diseno son los de la app', () {
    // El diálogo no inventa colores: si alguien cambia la marca, cambia aquí.
    expect(AppColors.brand, const Color(0xFF8E24AA));
    expect(AppColors.rpeMax, const Color(0xFFE24B4A));
  });
}
