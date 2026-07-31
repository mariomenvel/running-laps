import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:running_laps/core/widgets/duration_picker_field.dart';
import 'package:running_laps/core/widgets/wheel_sheets.dart';
import 'package:running_laps/core/widgets/wheel_value_field.dart';

/// Campos y hojas de rueda que sustituyeron a los teclados numéricos
/// (deuda técnica #8). Lo que se protege aquí no es el aspecto, sino las dos
/// cosas que se rompen sin querer: el formato del valor y la posibilidad de
/// volver a "sin valor", que en estos campos significa algo distinto de cero.
void main() {
  group('DurationPickerField.format', () {
    test('rellena los segundos a dos dígitos', () {
      expect(DurationPickerField.format(65), '1:05');
      expect(DurationPickerField.format(600), '10:00');
    });

    test('un tiempo por debajo del minuto sigue mostrando el 0', () {
      expect(DurationPickerField.format(9), '0:09');
    });

    test('pasa de la hora sin envolver a formato h:mm', () {
      // Un maratón de 3 h 15 min se dice "195:00", no "3:15:00": el campo es
      // mm:ss y confundirlos cambiaría la marca por un factor de 60.
      expect(DurationPickerField.format(195 * 60), '195:00');
    });
  });

  group('DistancePickerField.format', () {
    test('por debajo del kilómetro habla en metros', () {
      expect(DistancePickerField.format(400), '400 m');
      expect(DistancePickerField.format(999), '999 m');
    });

    test('a partir del kilómetro habla en km', () {
      expect(DistancePickerField.format(1000), '1 km');
      expect(DistancePickerField.format(21000), '21 km');
    });

    test('usa coma decimal, no punto', () {
      expect(DistancePickerField.format(7500), '7,5 km');
    });

    test('un km redondo no arrastra el decimal', () {
      expect(DistancePickerField.format(5000), '5 km');
    });
  });

  group('WheelValueField', () {
    Future<void> montar(
      WidgetTester tester, {
      required bool hasValue,
      required String display,
      VoidCallback? onClear,
      VoidCallback? onTap,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WheelValueField(
              label: 'Ritmo',
              display: display,
              hasValue: hasValue,
              onTap: onTap ?? () {},
              onClear: onClear ?? () {},
            ),
          ),
        ),
      );
    }

    testWidgets('sin valor no ofrece el botón de limpiar', (tester) async {
      await montar(tester, hasValue: false, display: '--:--');
      expect(find.text('--:--'), findsOneWidget);
      expect(find.byIcon(Icons.backspace_outlined), findsNothing);
    });

    testWidgets('con valor sí lo ofrece', (tester) async {
      await montar(tester, hasValue: true, display: '4:30');
      expect(find.byIcon(Icons.backspace_outlined), findsOneWidget);
    });

    testWidgets('limpiar avisa al padre', (tester) async {
      var limpiado = false;
      await montar(
        tester,
        hasValue: true,
        display: '4:30',
        onClear: () => limpiado = true,
      );
      await tester.tap(find.byIcon(Icons.backspace_outlined));
      expect(limpiado, isTrue);
    });

    testWidgets('tocar el valor abre el selector', (tester) async {
      var abierto = false;
      await montar(
        tester,
        hasValue: true,
        display: '4:30',
        onTap: () => abierto = true,
      );
      await tester.tap(find.text('4:30'));
      expect(abierto, isTrue);
    });
  });

  group('hojas de rueda', () {
    // El valor solo llega cuando la hoja se cierra, así que no puede ser el
    // return de `abrir`: se lee de aquí después de pulsar Confirmar.
    int? resultado;
    late bool resuelto;

    Future<void> abrir(
      WidgetTester tester,
      Future<int?> Function(BuildContext ctx) abrirHoja,
    ) async {
      resultado = null;
      resuelto = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (ctx) => TextButton(
              onPressed: () async {
                resultado = await abrirHoja(ctx);
                resuelto = true;
              },
              child: const Text('Abrir'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Abrir'));
      await tester.pumpAndSettle();
    }

    testWidgets('la hoja de distancia confirma el valor inicial',
        (tester) async {
      await abrir(
        tester,
        (ctx) => showDistanceWheelSheet(context: ctx, initialMeters: 7500),
      );
      // Arranca en el valor pasado: 7 km + 500 m.
      expect(find.text('7'), findsWidgets);
      expect(find.text('500'), findsWidgets);
      expect(find.text('Confirmar'), findsOneWidget);
    });

    testWidgets('la hoja de duración arranca en el tiempo dado',
        (tester) async {
      await abrir(
        tester,
        (ctx) => showDurationWheelSheet(context: ctx, initialSeconds: 4 * 60 + 30),
      );
      expect(find.text('4'), findsWidgets);
      expect(find.text('30'), findsWidgets);
    });

    testWidgets('una distancia de 0 no se puede confirmar', (tester) async {
      await abrir(
        tester,
        (ctx) => showDistanceWheelSheet(context: ctx, initialMeters: 0),
      );
      final boton = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Confirmar'),
      );
      expect(boton.onPressed, isNull);
    });

    testWidgets('una duración de 0 tampoco, salvo que se permita',
        (tester) async {
      await abrir(
        tester,
        (ctx) => showDurationWheelSheet(context: ctx, initialSeconds: 0),
      );
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Confirmar'),
            )
            .onPressed,
        isNull,
      );
    });

    testWidgets('allowZero habilita el 0 (descanso de series encadenadas)',
        (tester) async {
      await abrir(
        tester,
        (ctx) => showDurationWheelSheet(
          context: ctx,
          initialSeconds: 0,
          allowZero: true,
        ),
      );
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Confirmar'),
            )
            .onPressed,
        isNotNull,
      );
    });

    testWidgets('confirmar devuelve los metros elegidos', (tester) async {
      await abrir(
        tester,
        (ctx) => showDistanceWheelSheet(context: ctx, initialMeters: 3200),
      );
      await tester.tap(find.text('Confirmar'));
      await tester.pumpAndSettle();
      expect(resuelto, isTrue);
      expect(resultado, 3200);
    });

    testWidgets('confirmar devuelve los segundos elegidos', (tester) async {
      await abrir(
        tester,
        (ctx) => showDurationWheelSheet(context: ctx, initialSeconds: 272),
      );
      await tester.tap(find.text('Confirmar'));
      await tester.pumpAndSettle();
      expect(resultado, 272);
    });

    testWidgets('cerrar sin confirmar no devuelve valor', (tester) async {
      await abrir(
        tester,
        (ctx) => showDurationWheelSheet(context: ctx, initialSeconds: 300),
      );
      // Tocar fuera de la hoja: gesto normal de descarte de un bottom sheet.
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();
      expect(resuelto, isTrue);
      expect(resultado, isNull);
    });
  });
}
