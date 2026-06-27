import 'package:flutter/material.dart';

/// Muestra un BottomSheet con el estilo estándar de Running Laps
/// (iOS-style: handle + bordes redondeados + color surface correcto).
///
/// Usar para nuevos BottomSheets. Los existentes con Patrón A
/// (backgroundColor: transparent + decoración propia) están bien.
Future<T?> showAppBottomSheet<T>({
  required BuildContext context,
  required Widget Function(BuildContext) builder,
  bool isScrollControlled = true,
  bool showHandle = true,
  bool useSafeArea = true,
}) {
  return showModalBottomSheet<T>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: isScrollControlled,
    useSafeArea: useSafeArea,
    builder: (ctx) => AppBottomSheetContainer(
      showHandle: showHandle,
      child: builder(ctx),
    ),
  );
}

/// Contenedor estándar para el contenido de un BottomSheet.
/// Puede usarse directamente en showModalBottomSheet existentes
/// sin necesidad de migrar la llamada completa.
class AppBottomSheetContainer extends StatelessWidget {
  final Widget child;
  final bool showHandle;

  const AppBottomSheetContainer({
    super.key,
    required this.child,
    this.showHandle = true,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showHandle)
            Container(
              margin: const EdgeInsets.only(top: 8, bottom: 4),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? Colors.white24 : Colors.black26,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          child,
        ],
      ),
    );
  }
}
