import 'package:flutter/widgets.dart';

/// Marca que un widget está dentro del shell global.
/// AppHeader y otros widgets verifican esto para omitir su propio header
/// cuando el shell ya lo provee.
class ShellEmbeddingScope extends InheritedWidget {
  const ShellEmbeddingScope({super.key, required super.child});

  static bool isEmbedded(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ShellEmbeddingScope>() !=
      null;

  @override
  bool updateShouldNotify(ShellEmbeddingScope _) => false;
}

/// Marca si la pestaña que envuelve es la **visible** del `IndexedStack` del
/// shell.
///
/// ⚠️ Por qué existe: el `IndexedStack` mantiene montadas *todas* sus
/// pestañas, solo pinta una. Un `PopScope` declarado dentro de una pestaña
/// oculta sigue registrado en la ruta, así que **intercepta el botón atrás
/// del sistema desde cualquier otra pantalla del shell**. Eso hacía que, con
/// un entreno a medias en la pestaña 15, cualquier "atrás" sacara
/// "¿Abandonar entrenamiento?" encima de la pantalla en la que estuvieras
/// (y lo mismo con "¿Salir sin guardar?" del editor, pestaña 13).
///
/// Regla: toda pestaña del shell con `PopScope` debe condicionarlo a
/// [isVisible]. Fuera del shell (pantalla pusheada como ruta propia) no hay
/// scope y devuelve `true`, que es el comportamiento correcto ahí.
class ShellSlotScope extends InheritedWidget {
  const ShellSlotScope({
    super.key,
    required this.isActive,
    required super.child,
  });

  final bool isActive;

  static bool isVisible(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ShellSlotScope>()?.isActive ??
      true;

  @override
  bool updateShouldNotify(ShellSlotScope old) => old.isActive != isActive;
}
