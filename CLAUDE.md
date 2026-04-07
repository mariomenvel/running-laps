# CLAUDE.md — Running Laps

> Guía de referencia rápida para Claude Code. Lee esto antes de tocar cualquier archivo.
> Documentación completa: `ARCHITECTURE.md` | Historial de cambios: `CHANGELOG.md`

---

## Identidad del proyecto

**Running Laps** — App Flutter multiplataforma para runners que practican entrenamiento fraccionado (series/intervalos). Enfoque diferencial: RPE (Rate of Perceived Exertion) + tracking GPS por serie individual.

- Paquete: `running_laps` | Versión: 1.0.0+1 | SDK: `^3.9.2`
- Branch principal: `main` | Branch activo: `login`
- Plataformas: Flutter (Android, iOS, Web) + Wear OS (Kotlin/Compose, app independiente)

---

## Estado actual por plataforma

| Plataforma | Estado | Notas |
|---|---|---|
| **Android** | ✅ Funciona | App Check Play Integrity (debug: debug token) |
| **iOS** | ⚠️ Parcial | Ver tabla abajo |
| **Web** | ✅ Funciona | App Check reCAPTCHA v3 |
| **Wear OS** | ⚠️ Bypass temporal | UID hardcodeado via código de 6 dígitos, sin Firebase Auth real |

### iOS — detalle de estado

| Funcionalidad | Estado | Notas |
|---|---|---|
| Auth email/contraseña | ✅ OK | |
| Google Sign-In | ❌ Crash al pulsar botón | `GoogleService-Info.plist` presente, crash sin logs. Pendiente Xcode/Mac |
| GPS tracking | ✅ OK | `UIBackgroundModes: location`, Kalman + Haversine |
| Live Activity (carrera) | ✅ Implementado | Lock Screen + Dynamic Island, gradiente púrpura |
| Live Activity (descanso) | ✅ Implementado | `phase: rest`, countdown, botón "Saltar", acción `skip_rest` |
| App Check | ❌ Omitido | Sin Apple Developer → DeviceCheck no disponible |
| Notificación persistente | ⚠️ Solo barra azul GPS | `flutter_foreground_task` no muestra notificación en iOS |

---

## ⚠️ ADVERTENCIAS CRÍTICAS — No tocar sin entender completamente

### 1. Autenticación Wear OS — UID hardcodeado (TEMPORAL)
El reloj usa código de sesión de 6 dígitos generado en `WearAuthService`. Las reglas de Firestore permiten leer `trainings`, `templates` y `settings` con `request.auth == null`. **No eliminar el bypass sin implementar el reemplazo** (Cloud Function + custom token).

### 2. `DEBUG_SIMULATE = true` — NUNCA en producción
Si existe esta flag en `SeriesTrainingService.kt`, **debe estar en `false` antes de cualquier build de release**.

### 3. App Check — tokens de debug
Tokens registrados en Firebase Console. Si se regeneran sin actualizar la consola, los builds de debug dejarán de funcionar.

### 4. Colección `entrenamientos` vs `trainings`
El nombre real es **`trainings`**. Código legado puede usar `"entrenamientos"`. Siempre usar `"trainings"`.

### 5. `HomeEstadisticaRepository` es singleton
No instanciar con `HomeEstadisticaRepository()` esperando instancia independiente. Caché de 5 min invalidada automáticamente al guardar entrenamiento via `clearCache()`.

### 6. iOS Live Activity — sincronía Dart ↔ Swift
Cualquier campo nuevo en `IOSLiveActivityPayload` requiere actualizar **tres sitios**:
- `IOSLiveActivityPayload` + `toMap()` en `ios_live_activity_service.dart`
- `ContentState` en `ios/Runner/RunningLapsActivityAttributes.swift`
- `contentState(from:)` en `ios/Runner/RunningLapsLiveActivityManager.swift`

---

## Arquitectura: Feature-First + MVVM

```
lib/
├── main.dart                   ← Firebase init, App Check (Android+Web), ThemeService → SplashScreen
├── config/app_theme.dart       ← Color brandPurple = 0xFF8E24AA, AvatarHelper
├── core/
│   ├── services/
│   │   ├── gps_service.dart                ← GPS + Live Activity iOS + Kalman + Haversine
│   │   ├── ios_live_activity_service.dart  ← MethodChannel/EventChannel puente Swift↔Dart
│   │   ├── wear_auth_service.dart          ← Códigos de sesión Wear OS
│   │   ├── settings_service.dart           ← SharedPreferences: alarm, GPS defaults
│   │   └── user_service.dart               ← nombre, contraseña, borrar cuenta
│   └── utils/app_transitions.dart          ← AppRoute (CupertinoPageRoute), AppModalRoute
├── features/                   ← auth, training, history, home, analytics, groups, templates, avatar, profile, admin
└── firebase_options.dart       ← Generado por flutterfire CLI. NO editar a mano.

ios/Runner/
├── AppDelegate.swift                        ← Google Sign-In URL, Live Activity channels, handleCustomURL()
├── RunningLapsActivityAttributes.swift      ← Struct ActivityKit: ContentState (phase, restCountdown, etc.)
├── RunningLapsLiveActivityManager.swift     ← start/update/stop Activity<RunningLapsActivityAttributes>
└── Info.plist                               ← CFBundleURLTypes (REVERSED_CLIENT_ID), UIBackgroundModes

ios/RunningLapsLiveActivityExtension/
└── RunningLapsLiveActivityWidget.swift      ← Lock Screen + Dynamic Island (gradiente púrpura, phase-aware)

wear_os/app/src/main/kotlin/com/runninglaps/wear/
├── MainActivity.kt             ← Entry point, navegación, App Check
└── SeriesTrainingService.kt    ← Foreground service: timer, GPS, alarmas, plantillas
```

**Reglas estrictas:**
- `views/` → solo UI, sin lógica de negocio
- `viewmodels/` → **SIEMPRE** `ValueNotifier` / `ValueListenableBuilder`. **NUNCA GetX para estado**
- `data/` → repositorios + modelos (fuente de verdad)
- GetX solo para navegación/utilidades puntuales

---

## Features implementadas

| Feature | Carpeta | Descripción |
|---|---|---|
| Auth | `features/auth/` | Login email/pass + Google, registro, verificación email, recuperar contraseña |
| Training | `features/training/` | Sesión de entrenamiento, GPS por serie, tags |
| History | `features/history/` | Historial, filtros, calendario, mapa GPS, exportar PDF |
| Home | `features/home/` | Dashboard configurable con widgets arrastrables |
| Profile | `features/profile/` | Menú perfil, foto/avatar, configuración de cuenta |
| Analytics | `features/analytics/` | Overview, trends, distribution, patterns, coach insights |
| Groups | `features/groups/` | Grupos sociales, desafíos, ranking, recompensas, invitaciones |
| Templates | `features/templates/` | Plantillas con bloques (distancia/tiempo) y alarmas de ritmo |
| Avatar | `features/avatar/` | Constructor de avatares SVG por capas |
| Admin | `features/admin/` | Panel admin — solo si `isAdmin == true` en Firestore |

---

## App Check — estado actual

```dart
// main.dart — lógica actual
if (!kIsWeb) {
  if (defaultTargetPlatform == TargetPlatform.android) {
    await FirebaseAppCheck.instance.activate(
      androidProvider: kDebugMode ? AndroidProvider.debug : AndroidProvider.playIntegrity,
    );
  }
  // iOS omitido — sin Apple Developer credentials para DeviceCheck
} else {
  await FirebaseAppCheck.instance.activate(
    webProvider: ReCaptchaV3Provider('6LcH2acsAAAAAGdH2Wi1X39xnD3EB6o40ZsVjnIo'),
  );
}
```

---

## iOS Live Activity — arquitectura

```
Flutter (Dart)                              iOS (Swift)
──────────────────────────────────────────────────────────────
IOSLiveActivityService.instance
  .start(IOSLiveActivityPayload)   →  RunningLapsLiveActivityManager.start()
  .update(IOSLiveActivityPayload)  →  RunningLapsLiveActivityManager.update()
  .stop()                          →  RunningLapsLiveActivityManager.stop()
  .actions Stream<String>          ←  LiveActivityActionStreamHandler
                                         ← AppDelegate.handleCustomURL()
                                             ← runninglaps://training?action=X

IOSLiveActivityPayload.phase:
  "continuous" → carrera libre
  "running"    → serie activa (intervalos)
  "rest"       → descanso — usar IOSLiveActivityPayload.rest(restCountdown, serie)

Actions recibidas:
  "finish_run"  → GPSService.notificationAction → training_session_view._finishSeries()
  "end_serie"   → ídem
  "skip_rest"   → training_start_view._skipRest()
  "open"        → solo abre la app, no emite acción (filtrado en AppDelegate)

GPS updates en background (iOS):
  _handlePosition() → _sendNotificationUpdate() directamente (sin Timer)
  Timer.periodic solo existe en Android (FlutterForegroundTask)
```

---

## Flujo de autenticación

```
main() → SplashScreen (2s) → AuthWrapper
  AuthWrapper (StreamBuilder<User?>)
    ├── hasData  → HomeView(user: snapshot.data!)   ← evita race condition en web
    └── sin data → AuthPage

Google Sign-In web:  signInWithPopup → getIdToken(true) → saveUserDoc (en auth_remote)
Google Sign-In móvil: GoogleSignIn().signIn() → signInWithCredential → saveUserDoc
Email/pass: requiere emailVerified antes de permitir acceso
```

---

## Firebase / Firestore — colecciones reales

```
users/{uid}                           totalSessions, totalKm, totalTimeMinutes, lastTrainingDate
                                        (actualizados atómicamente con FieldValue.increment en createTraining)
users/{uid}/trainings/{id}            fecha(ISO8601), distanciaTotalM, tiempoTotalSec, series[], trackPoints[]
users/{uid}/tags/{nombre}             etiquetas personalizadas
users/{uid}/templates/{id}            plantillas con blocks[] y alerts
users/{uid}/settings/homeLayoutConfig configuración de widgets del home
groups/{groupId}                      grupos sociales
groups/{groupId}/challenges/{id}      desafíos del grupo
groups/{groupId}/participations/{uid} progreso de cada participante
wear_sessions/{código6}               sesiones temporales Wear OS (expiran en 10 min)
invite_codes/{código}                 códigos de invitación a grupos
global_challenges/{id}                desafíos globales
```

---

## Seguridad — resumen

- **App Check**: Android (Play Integrity) + Web (reCAPTCHA v3). iOS omitido temporalmente.
- **Reglas Firestore**: usuario solo lee/escribe sus propios documentos.
  - Wear OS bypass: `trainings`, `templates`, `settings`, `tags` legibles sin auth. TEMPORAL.
  - Todas las creates tienen límites de tamaño (`keys().size() < N`, `toString().size() < N`).
- **Límites en queries**: `.limit(100)` historial personal, `.limit(500)` gráficas/grupos, `.limit(50)` streams de rewards.
- **`result_notifications`**: cualquier usuario autenticado puede crear (TEMP). En producción: solo Admin SDK.

---

## Deuda técnica — priorizada

**Alta:**
1. **Google Sign-In iOS crash** — crash al pulsar botón. Requiere Xcode + logs. `assertionFailure` en `AppDelegate.configureGoogleSignIn()` si `GoogleService-Info.plist` no tiene `CLIENT_ID` válido
2. **Auth Wear OS** — reemplazar bypass Firestore con Cloud Function + custom token Firebase Auth
3. **Historial limitado a 100** — implementar paginación con cursor

**Media:**
4. **Backfill agregados** — usuarios existentes tienen `totalKm/totalSessions = 0`. Requiere admin script o Cloud Function
5. **App Check iOS** — activar `AppleProvider.deviceCheck` cuando haya Apple Developer credentials
6. `PatternCache` invalida por longitud, no por contenido real
7. `getAllEntrenamientos(uid)` en `TrainingRepository` ignora el uid recibido

**Baja:**
8. `stub_html.dart` en `core/utils/` — sin imports, borrar
9. `TimeRange.max` hardcodeado desde 2020
10. Sin tests automatizados

---

## Antes de hacer cualquier cambio — checklist

1. **Leer** el archivo completo antes de editar
2. **Ejecutar** `flutter analyze 2>&1 | grep 'error:'` tras cambios en Dart
3. **Verificar** que no se rompen los call sites si se cambia una firma de función
4. **Documentar** el cambio en `CHANGELOG.md` si es significativo
5. **No añadir** imports de `dart:html` directamente — usar `kIsWeb` de `foundation.dart`
6. **No instanciar** `FirebaseFirestore.instance` ni `FirebaseAuth.instance` en vistas — usar repositorios

---

## Convenciones de código

- **Dart:** `PascalCase` clases, `snake_case` archivos, `camelCase` variables/métodos
- **Kotlin:** igual; `companion object` para estado compartido entre Service y UI
- **Imports Dart:** `dart:` → `flutter/` → `firebase_*` → paquetes externos → locales
- `if (!mounted) return;` obligatorio tras cualquier `await` en un `State`
- Snackbars: **siempre** `ModernSnackBar.showSuccess/showError/showWarning(context, msg)`
- Estado en ViewModels: **siempre** `ValueNotifier` + `ValueListenableBuilder`
- `debugPrint()` en lugar de `print()` — se elimina automáticamente en release

---

## Assets

```
assets/images/logo.png           → logo app
assets/images/Icon.png           → icono splash/login
assets/images/fondo.png          → fondo login screen
assets/images/icono_launcher.png → icono launcher (4252×4252, RGBA, generado con flutter_launcher_icons)
assets/avatar/**                 → SVGs por categoría (body, eyes, hair/long, hair/short, etc.)
```
