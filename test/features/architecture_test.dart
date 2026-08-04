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

  group('convenciones de UI (CLAUDE.md § Componentes compartidos)', () {
    // Cada una de estas reglas existe porque el componente compartido resuelve
    // algo que a mano se hace mal: contraste, estilo iOS, coherencia entre
    // pantallas. Se comprueban las que hoy se cumplen al 100%; las que aún
    // tienen infracciones vivas están en la deuda técnica de CLAUDE.md, sin
    // test, porque un test que falla desde el primer día se acaba ignorando.

    String? offender(bool Function(String src) violates) {
      final bad = viewFiles
          .where((f) => violates(f.readAsStringSync()))
          .map((f) => f.path)
          .toList();
      return bad.isEmpty ? null : bad.join('\n');
    }

    test('ninguna vista usa AppBar de Material', () {
      // La cabecera global es AppHeader; para volver, BackPill o el gesto del
      // sistema.
      expect(offender((src) => src.contains('AppBar(')), isNull);
    });

    test('ninguna vista usa showDatePicker de Material', () {
      // showAppDatePicker: rueda estilo iOS en un sheet, con el rango clampeado.
      expect(offender((src) => src.contains('showDatePicker(')), isNull);
    });

    test('ninguna vista usa AlertDialog de Material', () {
      // Confirmaciones → showAppConfirmDialog; pedir un nombre →
      // showAppPromptDialog. Ambos son CupertinoAlertDialog, coherentes con
      // el resto de la app (fecha, números, sheets).
      //
      // showDialog() a secas SÍ es válido: lo usan las cuentas atrás
      // (CountdownDialog), que son un overlay propio, no un diálogo Material.
      expect(
        offender((src) =>
            RegExp(r'(?<!Cupertino)AlertDialog\(').hasMatch(src)),
        isNull,
      );
    });

    test('ninguna vista usa colores de Material sueltos', () {
      // COLOR_SYSTEM.md: el color comunica estado, y sale de AppColors.
      expect(
        offender((src) =>
            src.contains('Colors.orange') ||
            src.contains('Colors.green') ||
            src.contains('Colors.blue')),
        isNull,
      );
    });
  });

  test('nadie usa print() en lib/', () {
    // Convención: debugPrint(), que el framework recorta y silencia en release.
    final offenders = <String>[];
    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final src = entity.readAsStringSync();
      if (RegExp(r'(?<![.\w])print\(').hasMatch(src)) {
        offenders.add(entity.path);
      }
    }
    expect(offenders, isEmpty, reason: offenders.join('\n'));
  });

  test('ningún número se teclea en lib/', () {
    // CLAUDE.md § "Inputs numéricos — sin teclado": tiempo, distancia,
    // descanso, RPE y pulsaciones van por NumberPickerField / IosPicker /
    // DurationPickerField / DistancePickerField. Un teclado numérico en
    // pantalla, corriendo y con el móvil en la mano, no se acierta.
    //
    // El barrido es sobre lib/ entero, no solo /views/: los tres últimos
    // infractores vivían en carpetas widgets/ (filtros de historial, editor de
    // bloques, modal de retos) y un escaneo limitado a las vistas no los veía.
    final offenders = <String>[];
    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final src = entity.readAsStringSync();
      if (RegExp(r'keyboardType:\s*(const\s+)?TextInputType\.'
              r'(number|numberWithOptions|phone)')
          .hasMatch(src)) {
        offenders.add(entity.path);
      }
    }
    expect(offenders, isEmpty, reason: offenders.join('\n'));
  });

  test('nadie se construye su propio diálogo de confirmación', () {
    // Los diálogos van por showAppConfirmDialog / showAppPromptDialog. Un
    // `showModalBottomSheet<bool>` es la firma de una confirmación hecha a
    // mano: templates_list_view tenía una de 90 líneas que hacía lo mismo que
    // el helper, con otro aspecto y con un icono invisible (papelera roja
    // sobre círculo rojo). Esta regla encontró otras tres que no aparecían
    // buscando por texto.
    //
    // Excepciones: devolver bool no convierte un sheet en un diálogo. Estos
    // dos son formularios cuyo bool significa "se guardó", no "aceptó".
    const formulariosQueDevuelvenBool = [
      'premium_training_card.dart',   // TagSelectorSheet: editar etiquetas
      'training_session_view.dart',   // _showRpePicker: elegir el RPE
    ];

    final offenders = <String>[];
    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      if (formulariosQueDevuelvenBool.any(entity.path.endsWith)) continue;
      if (entity.readAsStringSync().contains('showModalBottomSheet<bool>')) {
        offenders.add(entity.path);
      }
    }
    expect(offenders, isEmpty,
        reason: 'Usa showAppConfirmDialog: ' + offenders.join(', '));
  });

  test('los selectores comparten la misma cabecera', () {
    // Había tres patrones y tres palabras distintas para lo mismo: "Hecho" en
    // number_picker_field, "Confirmar" en app_date_picker y un botón relleno
    // abajo en wheel_sheets. Ahora los tres usan PickerSheetHeader.
    const selectores = [
      'lib/core/widgets/number_picker_field.dart',
      'lib/core/widgets/app_date_picker.dart',
      'lib/core/widgets/wheel_sheets.dart',
    ];
    for (final ruta in selectores) {
      final src = File(ruta).readAsStringSync();
      expect(src.contains('PickerSheetHeader'), isTrue,
          reason: '$ruta no usa la cabecera común');
      expect(src.contains("'Hecho'"), isFalse,
          reason: '$ruta vuelve a decir "Hecho" en vez de "Confirmar"');
    }
  });

  test('nadie usa AlertDialog de Material en lib/', () {
    // Confirmaciones → showAppConfirmDialog; pedir un nombre →
    // showAppPromptDialog. Se repite fuera del grupo de vistas por la misma
    // razón que la regla de arriba: hay diálogos en carpetas widgets/.
    final offenders = <String>[];
    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final src = entity.readAsStringSync();
      if (RegExp(r'(?<!Cupertino)AlertDialog\(').hasMatch(src)) {
        offenders.add(entity.path);
      }
    }
    expect(offenders, isEmpty, reason: offenders.join('\n'));
  });
}
