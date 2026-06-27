import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Selector de fecha estilo iOS.
/// Reemplaza showDatePicker() de Material en toda la app.
///
/// Parámetros:
/// - [initialDate] — fecha inicial seleccionada
/// - [minimumDate] — fecha mínima permitida
/// - [maximumDate] — fecha máxima permitida
/// - [title] — título opcional del sheet (ej: "Fecha de nacimiento")
///
/// Devuelve [DateTime] si el usuario confirma, null si cancela.
Future<DateTime?> showAppDatePicker({
  required BuildContext context,
  DateTime? initialDate,
  DateTime? minimumDate,
  DateTime? maximumDate,
  String? title,
}) async {
  final now = DateTime.now();
  DateTime selected = initialDate ?? now;

  // Clamp initialDate dentro del rango permitido
  if (minimumDate != null && selected.isBefore(minimumDate)) {
    selected = minimumDate;
  }
  if (maximumDate != null && selected.isAfter(maximumDate)) {
    selected = maximumDate;
  }

  return await showModalBottomSheet<DateTime>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: false,
    builder: (ctx) {
      return _AppDatePickerSheet(
        initialDate: selected,
        minimumDate: minimumDate,
        maximumDate: maximumDate,
        title: title,
      );
    },
  );
}

class _AppDatePickerSheet extends StatefulWidget {
  final DateTime initialDate;
  final DateTime? minimumDate;
  final DateTime? maximumDate;
  final String? title;

  const _AppDatePickerSheet({
    required this.initialDate,
    this.minimumDate,
    this.maximumDate,
    this.title,
  });

  @override
  State<_AppDatePickerSheet> createState() => _AppDatePickerSheetState();
}

class _AppDatePickerSheetState extends State<_AppDatePickerSheet> {
  late DateTime _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.initialDate;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C1C1E) : const Color(0xFFF2F2F7),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Container(
              margin: const EdgeInsets.only(top: 8),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? Colors.white24 : Colors.black26,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Header con título + botones
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  CupertinoButton(
                    onPressed: () => Navigator.of(context).pop(null),
                    child: Text(
                      'Cancelar',
                      style: TextStyle(
                        color: AppColors.textSecondary(context),
                        fontSize: 16,
                      ),
                    ),
                  ),
                  if (widget.title != null)
                    Text(
                      widget.title!,
                      style: TextStyle(
                        color: AppColors.textPrimary(context),
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  CupertinoButton(
                    onPressed: () => Navigator.of(context).pop(_selected),
                    child: const Text(
                      'Confirmar',
                      style: TextStyle(
                        color: AppColors.brand,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Divider
            Divider(
              height: 1,
              color: isDark ? Colors.white12 : Colors.black12,
            ),
            // Cupertino date picker
            SizedBox(
              height: 216,
              child: CupertinoDatePicker(
                mode: CupertinoDatePickerMode.date,
                initialDateTime: widget.initialDate,
                minimumDate: widget.minimumDate,
                maximumDate: widget.maximumDate,
                onDateTimeChanged: (dt) => setState(() => _selected = dt),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
