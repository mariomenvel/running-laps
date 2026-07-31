import 'package:flutter/material.dart';
import 'package:running_laps/core/theme/app_colors.dart';
import 'package:running_laps/core/widgets/ios_picker.dart';

/// Campo de duración **mm:ss** con rueda doble, para marcas personales y
/// cualquier tiempo objetivo. Contraparte de [NumberPickerField] cuando el
/// número es un tiempo y no una magnitud suelta.
///
/// Sustituye al par de `TextField` con `keyboardType: number` que había
/// duplicado en el onboarding y en los ajustes del Coach. Aquel par, además de
/// incumplir la convención de "ningún número se teclea", creaba dos
/// `TextEditingController` **dentro del `build`**: se recreaban en cada
/// reconstrucción y no los liberaba nadie.
///
/// El valor es nullable porque una marca en blanco significa "no la tengo",
/// que no es lo mismo que 00:00. Como la rueda no puede devolver "nada", el
/// botón de limpiar es la única vía de vuelta a ese estado.
class DurationPickerField extends StatelessWidget {
  const DurationPickerField({
    super.key,
    required this.label,
    required this.valueSeconds,
    required this.onChanged,
    this.maxMinutes = 359,
    this.fallbackSeconds = 25 * 60,
    this.labelWidth = 110,
  });

  final String label;

  /// Duración en segundos, o null si no está definida.
  final int? valueSeconds;

  final ValueChanged<int?> onChanged;

  /// Tope de la rueda de minutos. Por defecto 359 (5 h 59 min), de sobra para
  /// un maratón.
  final int maxMinutes;

  /// Dónde arranca la rueda la primera vez, sin valor previo.
  final int fallbackSeconds;

  final double labelWidth;

  static String format(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  Future<void> _openPicker(BuildContext context) async {
    final inicial = (valueSeconds ?? fallbackSeconds).clamp(0, maxMinutes * 60 + 59);
    final elegido = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _DurationSheet(
        title: label,
        initialSeconds: inicial,
        maxMinutes: maxMinutes,
      ),
    );
    if (elegido != null) onChanged(elegido);
  }

  @override
  Widget build(BuildContext context) {
    final tieneValor = valueSeconds != null;

    return Row(
      children: [
        SizedBox(
          width: labelWidth,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: AppColors.textPrimary(context),
            ),
          ),
        ),
        const Spacer(),
        InkWell(
          onTap: () => _openPicker(context),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: 92,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.surface2Of(context),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              tieneValor ? format(valueSeconds!) : '--:--',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: tieneValor ? FontWeight.w600 : FontWeight.normal,
                color: tieneValor
                    ? AppColors.textPrimary(context)
                    : AppColors.textSecondary(context),
              ),
            ),
          ),
        ),
        SizedBox(
          width: 40,
          child: tieneValor
              ? IconButton(
                  icon: const Icon(Icons.backspace_outlined, size: 18),
                  tooltip: 'Quitar $label',
                  color: AppColors.textSecondary(context),
                  onPressed: () => onChanged(null),
                )
              : null,
        ),
      ],
    );
  }
}

class _DurationSheet extends StatefulWidget {
  const _DurationSheet({
    required this.title,
    required this.initialSeconds,
    required this.maxMinutes,
  });

  final String title;
  final int initialSeconds;
  final int maxMinutes;

  @override
  State<_DurationSheet> createState() => _DurationSheetState();
}

class _DurationSheetState extends State<_DurationSheet> {
  late int _min;
  late int _sec;

  @override
  void initState() {
    super.initState();
    _min = (widget.initialSeconds ~/ 60).clamp(0, widget.maxMinutes);
    _sec = widget.initialSeconds % 60;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 300,
      margin: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceOf(context),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Text(
            widget.title,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary(context),
            ),
          ),
          Expanded(
            child: Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IosPicker(
                    itemCount: widget.maxMinutes + 1,
                    initialItem: _min,
                    onChanged: (i) => setState(() => _min = i),
                    textBuilder: (i) => '$i',
                    label: 'min',
                    itemExtent: 40,
                    width: 80,
                  ),
                  const SizedBox(width: 8),
                  IosPicker(
                    itemCount: 60,
                    initialItem: _sec,
                    onChanged: (i) => setState(() => _sec = i),
                    textBuilder: (i) => i.toString().padLeft(2, '0'),
                    label: 'seg',
                    itemExtent: 40,
                    width: 80,
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(backgroundColor: AppColors.brand),
                onPressed: () => Navigator.pop(context, _min * 60 + _sec),
                child: const Text('Confirmar'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
