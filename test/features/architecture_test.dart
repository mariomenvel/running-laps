import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Tests de arquitectura: en vez de comprobar comportamiento, comprueban que
/// el código sigue las reglas de CLAUDE.md. Son baratos y pillan lo que ningún
/// test funcional pilla — que alguien (persona o IA) reintroduzca en una vista
/// algo que debe vivir en la capa de datos.
///
/// Si uno de estos falla, la respuesta casi nunca es relajar el test: es mover
/// el acceso a su repositorio o servicio.
void main() {
  final viewFiles = Directory('lib/features')
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) {
        final path = f.path.replaceAll(r'\', '/');
        return path.endsWith('.dart') && path.contains('/views/');
      })
      .toList();

  test('hay vistas que analizar (el propio test no se queda vacío)', () {
    // Sin esto, un cambio de estructura de carpetas dejaría los tests de abajo
    // pasando sobre una lista vacía y sin proteger nada.
    expect(viewFiles.length, greaterThan(30));
  });

  group('las vistas no hablan directamente con Firebase', () {
    // Regla de CLAUDE.md § Arquitectura. El acceso va por repositorios y
    // servicios: así la query se reutiliza, se testea con Firestore simulado y
    // un cambio de esquema se toca en un sitio, no en veinte pantallas.

    test('ninguna vista instancia FirebaseFirestore', () {
      final offenders = <String>[];
      for (final file in viewFiles) {
        if (file.readAsStringSync().contains('FirebaseFirestore.instance')) {
          offenders.add(file.path);
        }
      }
      expect(offenders, isEmpty,
          reason: 'Usa un repositorio (TrainingRepository, UserService, '
              'AiCoachRepository...) en vez de consultar Firestore desde la '
              'vista:\n${offenders.join('\n')}');
    });

    test('ninguna vista instancia FirebaseAuth', () {
      final offenders = <String>[];
      for (final file in viewFiles) {
        if (file.readAsStringSync().contains('FirebaseAuth.instance')) {
          offenders.add(file.path);
        }
      }
      expect(offenders, isEmpty,
          reason: 'Para el uid usa `UserService().currentUid` (o '
              '`awaitCurrentUid()` si hay que esperar a que Firebase restaure '
              'la sesión); para el resto, AuthRepository:\n'
              '${offenders.join('\n')}');
    });
  });

  test('ninguna vista importa dart:html', () {
    // Rompería la compilación en móvil. La comprobación de plataforma se hace
    // con `kIsWeb` de foundation.dart.
    final offenders = <String>[];
    for (final file in viewFiles) {
      if (file.readAsStringSync().contains("import 'dart:html'")) {
        offenders.add(file.path);
      }
    }
    expect(offenders, isEmpty, reason: offenders.join('\n'));
  });

  test('los snackbars son siempre ModernSnackBar', () {
    // CLAUDE.md § Convenciones: `ModernSnackBar` es el único permitido, para
    // que el aviso se vea igual en toda la app.
    final offenders = <String>[];
    for (final file in viewFiles) {
      final src = file.readAsStringSync();
      if (src.contains('ScaffoldMessenger.of(context).showSnackBar')) {
        offenders.add(file.path);
      }
    }
    expect(offenders, isEmpty,
        reason: 'Usa ModernSnackBar.showSuccess/showError/showWarning:\n'
            '${offenders.join('\n')}');
  });
}
