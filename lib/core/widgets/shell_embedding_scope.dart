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
