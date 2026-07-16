import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'firebase_options.dart'; // Generado por flutterfire CLI
import 'core/theme/app_theme.dart';
import 'core/theme/theme_service.dart';
import 'features/auth/views/auth_wrapper.dart';
import 'core/services/heart_rate_service.dart';
import 'core/services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inicializar locale para el calendario en español
  await initializeDateFormatting('es_ES', null);

  // Inicializar Firebase para Web, Android e iOS
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  if (!kIsWeb) {
    FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
    PlatformDispatcher.instance.onError = (error, stack) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      return true;
    };
  }

  // Inicializar App Check — Android y Web activos. iOS omitido (sin credenciales Apple Developer).
  if (!kIsWeb) {
    if (defaultTargetPlatform == TargetPlatform.android) {
      await FirebaseAppCheck.instance.activate(
        providerAndroid: kDebugMode
            ? const AndroidDebugProvider()
            : const AndroidPlayIntegrityProvider(),
      );
    }
  } else {
    await FirebaseAppCheck.instance.activate(
      providerWeb: ReCaptchaV3Provider('6LcH2acsAAAAAGdH2Wi1X39xnD3EB6o40ZsVjnIo'),
    );
  }

  await ThemeService.init();

  // Intentar reconectar pulsómetro en background — solo en móvil (BLE no disponible en Web)
  if (!kIsWeb) {
    HeartRateService().autoReconnect().catchError(
      (e) => debugPrint('[main] HR autoReconnect: $e'),
    );
  }

  await NotificationService().init();
  NotificationService().scheduleWeeklySummary().catchError(
    (e) => debugPrint('[main] weekly summary: $e'),
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeService.themeMode,
      builder: (context, themeMode, _) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'Running Laps',
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          themeMode: themeMode,
          home: const AuthWrapper(),
        );
      },
    );
  }
}


