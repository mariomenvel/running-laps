# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

**Running Laps** — App Flutter para runners (entrenamiento fraccionado: series + RPE + GPS).
Plataformas: Android, iOS, Web + Wear OS (Kotlin/Compose, app independiente).

---

## Commands

```bash
flutter analyze 2>&1 | grep 'error:'   # errores tras cambios Dart
flutter analyze                         # lint completo
flutter test                            # todos los tests
flutter test test/unit/pattern_detector_test.dart  # test individual
flutter run
flutter build apk --debug / --release
flutter build ios                       # requiere Mac + Xcode
cd wear_os && ./gradlew assembleDebug
```

---

## Arquitectura

Feature-First + MVVM. Cada feature en `lib/features/<name>/` con subcarpetas `views/`, `viewmodels/`, `data/`.

- **Estado:** siempre `ValueNotifier` + `ValueListenableBuilder`. Nunca GetX para estado.
- **GetX:** solo para navegación puntual.
- **Vistas:** sin lógica de negocio.
- **Firebase:** nunca instanciar `FirebaseFirestore.instance` ni `FirebaseAuth.instance` en vistas — usar repositorios.
- **No** importar `dart:html` directamente — usar `kIsWeb` de `foundation.dart`.

Paths clave:
- `lib/config/app_theme.dart` — `Tema.brandPurple = Color(0xFF8E24AA)`, `AvatarHelper` (alias legado)
- `lib/core/theme/app_colors.dart` — sistema de colores actual (`AppColors.brand`, tokens semánticos)
- `lib/core/theme/theme_service.dart` — tema claro/oscuro, persistido en SharedPreferences
- `lib/main.dart` — Firebase init, App Check (Android + Web), `AuthWrapper` (StreamBuilder<User?>)
- `core/services/gps_service.dart` — GPS + Live Activity iOS + Kalman + Haversine
- `core/services/ios_live_activity_service.dart` — puente MethodChannel/EventChannel Swift↔Dart
- `firebase_options.dart` — generado por flutterfire CLI, **no editar a mano**

Features activas en `lib/features/`:
`auth` · `training` · `history` · `home` · `analytics` · `groups` · `templates` · `avatar` · `profile` · `admin` · `ai_coach` · `athlete` · `calendar`

---

## ⚠️ Advertencias críticas

**1. Wear OS — bypass auth (TEMPORAL)**
El reloj usa código de sesión de 6 dígitos (`WearAuthService`). Las reglas Firestore permiten leer `trainings`, `templates`, `settings` y `tags` con `request.auth == null`. No eliminar sin implementar el reemplazo (Cloud Function + custom token).

**2. `DEBUG_SIMULATE` en Wear OS**
`SeriesTrainingService.kt` tiene flag `DEBUG_SIMULATE`. Debe estar en `false` antes de cualquier release.

**3. Colección `trainings`, no `entrenamientos`**
Código legado usa `"entrenamientos"`. El nombre real es `"trainings"`. Siempre usar `"trainings"`.

**4. iOS Live Activity — tres archivos sincronizados**
Cualquier campo nuevo en `IOSLiveActivityPayload` requiere actualizar también:
- `ContentState` en `RunningLapsActivityAttributes.swift`
- `contentState(from:)` en `RunningLapsLiveActivityManager.swift`

**5. `HomeEstadisticaRepository` es singleton**
No instanciar con `HomeEstadisticaRepository()` esperando instancia independiente.

---

## Convenciones

- Snackbars: `ModernSnackBar.showSuccess/showError/showWarning(context, msg)`
- `debugPrint()` en lugar de `print()`
- `if (!mounted) return;` tras cualquier `await` en un `State`
- Imports Dart: `dart:` → `flutter/` → `firebase_*` → paquetes externos → locales

---

## Estado iOS

| Funcionalidad | Estado |
|---|---|
| Auth email/contraseña | ✅ OK |
| Google Sign-In | ❌ Crash — pendiente Xcode/logs |
| GPS + Live Activity | ✅ OK |
| App Check | ❌ Omitido (sin Apple Developer) |
| Notificación persistente | ⚠️ Solo barra GPS — `flutter_foreground_task` no funciona en iOS |

---

## Deuda técnica prioritaria

1. **Google Sign-In iOS** — `assertionFailure` en `AppDelegate.configureGoogleSignIn()`
2. **Auth Wear OS** — reemplazar bypass con Cloud Function + custom token
3. **Historial** — limitado a 100 entradas, implementar paginación con cursor
4. `getAllEntrenamientos(uid)` en `TrainingRepository` ignora el uid recibido
5. `getAllEntrenamientos(uid)` en `TrainingRepository` — alias de `getTrainings()` que ignora el uid; confuso para futuros devs
6. **Refactor MVVM de `workout_editor_screen.dart`** — iniciado y pausado en rama `refactor/workout-editor-mvvm` (sin mergear). Reveló bug real: colisión `WorkoutType.free`/`continuous` en `athlete_session_mapper.dart` (mismo valor de categoría Firestore para ambos). Retomar el refactor cuando haya tiempo; el bug del mapper es independiente y de mayor prioridad.
7. **`GPSService.updateSerie()` — método muerto.** Definido en `gps_service.dart:191-194` pero sin ninguna llamada en todo el código. Investigado: no es un bug, `GPSService` se reinstancia por serie (no es singleton), así que el número de serie ya llega correcto vía constructor en `startTracking()`. Candidato a eliminar en una limpieza futura, o documentar su propósito si se planea usar para algo distinto.
