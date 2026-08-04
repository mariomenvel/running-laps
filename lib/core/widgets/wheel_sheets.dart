import 'package:flutter/material.dart';
import 'package:running_laps/core/widgets/picker_sheet_header.dart';
import 'package:running_laps/core/theme/app_colors.dart';
import 'package:running_laps/core/widgets/ios_picker.dart';

/// Hojas de rueda para los dos valores que la app pide una y otra vez:
/// una **distancia** y una **duración**. Son el escape para valores que no
/// están en una rueda de valores comunes, sustituyendo al teclado numérico
/// (ver CLAUDE.md § "Inputs numéricos — sin teclado").
///
/// Viven aquí y no en cada pantalla porque llegaron a existir tres copias
/// casi idénticas: el entreno manual, el campo de marcas del Coach y el
/// escape del selector de series.

/// Rueda doble de distancia: kilómetros + hectómetros (pasos de 100 m).
/// Devuelve los metros, o null si se cancela.
Future<int?> showDistanceWheelSheet({
  required BuildContext context,
  required int initialMeters,
  String title = 'Distancia personalizada',
  int maxKm = 99,
}) {
  return showModalBottomSheet<int>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (_) => _WheelSheet(
      title: title,
      wheels: [
        _WheelSpec(
          count: maxKm + 1,
          initial: (initialMeters ~/ 1000).clamp(0, maxKm),
          label: 'km',
          text: (i) => '$i',
          width: 70,
        ),
        _WheelSpec(
          count: 10,
          initial: (initialMeters % 1000) ~/ 100,
          label: 'm',
          text: (i) => '${i}00',
          width: 80,
        ),
      ],
      compute: (v) => v[0] * 1000 + v[1] * 100,
      // 0 m no es una distancia válida para nada de lo que pide la app.
      isValid: (metros) => metros > 0,
    ),
  );
}

/// Rueda doble de duración: minutos + segundos.
/// Devuelve los segundos, o null si se cancela.
Future<int?> showDurationWheelSheet({
  required BuildContext context,
  required int initialSeconds,
  String title = 'Duración',
  int maxMinutes = 359,
  bool allowZero = false,
}) {
  return showModalBottomSheet<int>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (_) => _WheelSheet(
      title: title,
      wheels: [
        _WheelSpec(
          count: maxMinutes + 1,
          initial: (initialSeconds ~/ 60).clamp(0, maxMinutes),
          label: 'min',
          text: (i) => '$i',
          width: 80,
        ),
        _WheelSpec(
          count: 60,
          initial: initialSeconds % 60,
          label: 'seg',
          text: (i) => i.toString().padLeft(2, '0'),
          width: 80,
        ),
      ],
      compute: (v) => v[0] * 60 + v[1],
      isValid: (segundos) => allowZero || segundos > 0,
    ),
  );
}

class _WheelSpec {
  const _WheelSpec({
    required this.count,
    required this.initial,
    required this.label,
    required this.text,
    required this.width,
  });

  final int count;
  final int initial;
  final String label;
  final String Function(int index) text;
  final double width;
}

class _WheelSheet extends StatefulWidget {
  const _WheelSheet({
    required this.title,
    required this.wheels,
    required this.compute,
    required this.isValid,
  });

  final String title;
  final List<_WheelSpec> wheels;
  final int Function(List<int> selections) compute;
  final bool Function(int value) isValid;

  @override
  State<_WheelSheet> createState() => _WheelSheetState();
}

class _WheelSheetState extends State<_WheelSheet> {
  late List<int> _sel;

  @override
  void initState() {
    super.initState();
    _sel = widget.wheels.map((w) => w.initial).toList();
  }

  @override
  Widget build(BuildContext context) {
    final valor = widget.compute(_sel);
    final valido = widget.isValid(valor);

    return Container(
      height: 300,
      margin: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceOf(context),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          PickerSheetHeader(
            title: widget.title,
            onCancel: () => Navigator.pop(context),
            onConfirm: valido ? () => Navigator.pop(context, valor) : null,
          ),
          Expanded(
            child: Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < widget.wheels.length; i++) ...[
                    if (i > 0) const SizedBox(width: 8),
                    IosPicker(
                      itemCount: widget.wheels[i].count,
                      initialItem: widget.wheels[i].initial,
                      onChanged: (v) => setState(() => _sel[i] = v),
                      textBuilder: widget.wheels[i].text,
                      label: widget.wheels[i].label,
                      itemExtent: 40,
                      width: widget.wheels[i].width,
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}
