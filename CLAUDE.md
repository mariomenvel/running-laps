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

## ⚠️ ADVERTENCIAS CRÍTICAS — No tocar sin entender completamente

### 1. Autenticación Wear OS — UID hardcodeado (TEMPORAL)
El reloj no tiene flujo de login propio. Actualmente usa un código de sesión de 6 dígitos generado desde la app móvil (`WearAuthService`) para obtener el `uid` del usuario. Las reglas de Firestore permiten leer `trainings`, `templates` y `settings` con `request.auth == null` para soportar esto.

**Esto es una solución temporal.** La arquitectura correcta es una Cloud Function que verifique el código y devuelva un custom token de Firebase Auth. No eliminar el bypass de reglas sin haber implementado el reemplazo.

### 2. `DEBUG_SIMULATE = true` — NUNCA en producción
Si existe esta flag en `SeriesTrainingService.kt` o en el equivalente Flutter, **debe estar en `false` antes de cualquier build de release**. En modo simulación el GPS y los timers usan datos falsos.

### 3. App Check — tokens de debug
Los tokens de debug de App Check están registrados en Firebase Console (proyecto → App Check → Apps → Manage debug tokens). Si se regeneran sin actualizar la consola, los builds de debug dejarán de funcionar. No regenerar sin coordinación.

### 4. Colección `entrenamientos` vs `trainings`
El nombre real de la colección en Firestore es **`trainings`**. Existe código legado que usa `"entrenamientos"` — ya corregido en Wear OS HomeScreen.kt, pero puede aparecer en otros sitios. Siempre usar `"trainings"`.

### 5. `HomeEstadisticaRepository` es singleton
No instanciar con `HomeEstadisticaRepository()` esperando una instancia independiente — siempre devuelve la misma instancia. El caché (5 min) se invalida automáticamente al guardar un entrenamiento. Si se necesita forzar refresco, llamar `HomeEstadisticaRepository().clearCache()`.

---

## Arquitectura: Feature-First + MVVM

```
lib/
├── main.dart                   ← Firebase init, App Check, ThemeService → SplashScreen
├── config/app_theme.dart       ← Tema global (brandPurple = 0xFF8E24AA), AvatarHelper
├── core/                       ← Servicios transversales, widgets compartidos, utils
├── features/                   ← Módulos funcionales (ver lista abajo)
└── firebase_options.dart       ← Generado por flutterfire CLI. No editar a mano.

wear_os/app/src/main/kotlin/com/runninglaps/wear/
├── MainActivity.kt             ← Entry point, navegación, App Check
├── SeriesTrainingService.kt    ← Foreground service: timer, GPS, alarmas, plantillas
├── SeriesActiveScreen.kt       ← UI activa durante la serie
├── SeriesPageScreen.kt         ← Config de serie + picker de plantilla
├── TemplatePickerScreen.kt     ← Selector de plantilla desde Firestore
├── TemplateModels.kt           ← Modelos de datos para plantillas
└── HomeScreen.kt               ← Dashboard con stats (usa colección "trainings")
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

## Flujo de autenticación

```
main() → SplashScreen (2s) → AuthWrapper
  AuthWrapper (StreamBuilder<User?>)
    ├── hasData  → HomeView(user: snapshot.data!)   ← user pasado explícitamente (evita race condition web)
    └── sin data → AuthPage

Google Sign-In web:  signInWithPopup → getIdToken(true) → saveUserDoc (en auth_remote, no en auth_repository)
Google Sign-In móvil: GoogleSignIn().signIn() → signInWithCredential → saveUserDoc (en auth_repository)
Email/pass: requiere emailVerified antes de permitir acceso
```

---

## Firebase / Firestore — colecciones reales

```
users/{uid}                           perfil: nombre, email, photoUrl, avatarConfig, isAdmin
users/{uid}/trainings/{id}            entrenamientos: fecha(ISO8601), distanciaTotalM, tiempoTotalSec,
                                        ritmoMedioSecKm, rpePromedio, series[], trackPoints[]
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

## Servicios Core

| Servicio | Ruta | Función |
|---|---|---|
| `GPSService` | `core/services/gps_service.dart` | Haversine + KalmanFilter, ventana 5 puntos, descarta acc >20m |
| `SensorService` | `core/services/sensor_service.dart` | Pedómetro |
| `PDFGeneratorService` | `core/services/pdf_generator_service.dart` | Exportar PDF de historial |
| `SettingsService` | `core/services/settings_service.dart` | SharedPreferences: alarma, GPS default |
| `UserService` | `core/services/user_service.dart` | updateNombre, reauth, updatePassword, deleteAccount, isGoogleUser |
| `WearAuthService` | `core/services/wear_auth_service.dart` | Genera/valida códigos de sesión Wear OS |

---

## Modelos clave

**`Entrenamiento`** (`features/training/data/entrenamiento.dart`)
- `distanciaTotalM` → int (metros) | `tiempoTotalSec` → double (segundos)
- `rpePromedio()` → calculado desde series | `ritmoMedioSecPorKm()` → calculado
- Debe tener ≥1 serie válida (distanciaM > 0 salvo drill estático)

**`Serie`** (`features/training/data/serie.dart`)
- `tiempoSec`, `distanciaM`, `descansoSec`, `rpe` (1-10)
- `usedGps`, `gpsPoints` → opcionales

**`TemplateBlock`** (`features/templates/data/template_models.dart`)
- `type`: `distance` | `time` | `value`: metros o segundos
- `alerts`: `TemplateAlerts` con modo `time` o `pace`

---

## Seguridad — resumen

- **App Check** activo en todas las plataformas (Android/iOS/Web/Wear OS)
- **Reglas Firestore**: usuario solo lee/escribe sus propios documentos. Wear OS puede leer `trainings`, `templates`, `settings` sin auth (bypass temporal). Ver `firestore.rules` para detalles completos.
- **Límites en todas las queries principales**: `.limit(100)` en historial personal, `.limit(500)` en gráficas home y stats de grupo, `.limit(50)` en streams de rewards.

---

## Deuda técnica — priorizada

**Alta:**
1. Prints `WEB LOGIN: ...` en `auth_remote.dart` — eliminar cuando el fix de Google Sign In web esté confirmado
2. `stub_html.dart` en `core/utils/` — ya no se importa, borrar
3. Historial limitado a 100 entrenamientos — implementar paginación con cursor

**Media:**
4. Auth Wear OS — reemplazar bypass de reglas con Cloud Function + custom token
5. `PatternCache` invalida por longitud de lista, no por contenido real
6. `getAllEntrenamientos(uid)` en `TrainingRepository` es alias inútil — ignora el uid recibido

**Baja:**
7. `TimeRange.max` hardcodeado desde 2020 — configurable
8. Sin tests automatizados
9. iOS Live Activities: requiere Xcode + Swift ActivityKit extension. Sin Xcode es inviable.

---

## Antes de hacer cualquier cambio — checklist

1. **Leer** el archivo que se va a modificar completo antes de editar
2. **Ejecutar** `flutter analyze 2>&1 | grep 'error:'` tras cambios en Dart
3. **Verificar** que no se rompen los call sites si se cambia una firma de función
4. **Documentar** el cambio en `CHANGELOG.md` si es significativo
5. **No añadir** imports de `dart:html` directamente — usar `kIsWeb` de `foundation.dart`
6. **No instanciar** `FirebaseFirestore.instance` ni `FirebaseAuth.instance` en vistas — usar repositorios

---

## Convenciones de código

- **Dart:** `PascalCase` clases, `snake_case` archivos, `camelCase` variables/métodos, `lowerCamelCase` constantes
- **Kotlin:** igual que Dart para nombres; `companion object` para estado compartido entre Service y UI
- **Imports Dart:** `dart:` → `flutter/` → `firebase_*` → paquetes externos → locales (`package:running_laps/...`)
- `if (!mounted) return;` obligatorio tras cualquier `await` en un `State`
- Snackbars: **siempre** `ModernSnackBar.showSuccess/showError/showWarning(context, msg)`
- Estado en ViewModels: **siempre** `ValueNotifier` + `ValueListenableBuilder`

---

## Assets

```
assets/images/logo.png     → logo app
assets/images/Icon.png     → icono splash/login
assets/images/fondo.png    → fondo login screen
assets/avatar/**           → SVGs por categoría (body, eyes, hair/long, hair/short, etc.)
```
