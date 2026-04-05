# ARCHITECTURE.md — Running Laps

> Documento de referencia técnica. Describe la estructura del proyecto, los servicios Firebase, el modelo de datos, el flujo de autenticación y el modelo de seguridad.

---

## 1. Estructura del proyecto

```
running_laps/
├── android/                        ← App Android nativa (Flutter host)
│   └── app/build.gradle.kts        ← Dependencias nativas (App Check, etc.)
├── ios/                            ← App iOS nativa (Flutter host)
├── wear_os/                        ← App Wear OS independiente (Kotlin/Compose)
│   └── app/src/main/kotlin/com/runninglaps/wear/
│       ├── MainActivity.kt         ← Entry point, navegación Compose, App Check
│       ├── HomeScreen.kt           ← Dashboard con stats desde Firestore
│       ├── SeriesPageScreen.kt     ← Configuración de serie antes de entrenar
│       ├── SeriesActiveScreen.kt   ← Pantalla activa durante la serie
│       ├── SeriesTrainingService.kt ← Foreground service: timer, GPS, alarmas
│       ├── TemplatePickerScreen.kt ← Selector de plantilla desde Firestore
│       └── TemplateModels.kt       ← Modelos de datos para plantillas
├── lib/                            ← App Flutter
│   ├── main.dart                   ← Entry point: Firebase init, App Check, ThemeService
│   ├── firebase_options.dart       ← Generado por flutterfire CLI
│   ├── config/
│   │   └── app_theme.dart          ← Tema global, AvatarHelper
│   ├── core/
│   │   ├── services/               ← GPSService, SensorService, PDFGeneratorService,
│   │   │                              SettingsService, UserService, WearAuthService
│   │   ├── tracking/               ← tracking_state, tracking_types, sensor_frame
│   │   ├── utils/                  ← kalman_filter, tag_utils, stub_html
│   │   └── widgets/                ← Widgets compartidos (ModernSnackBar, etc.)
│   └── features/
│       ├── auth/                   ← Login, registro, recuperación, verificación email
│       ├── training/               ← Sesión de entrenamiento, GPS por serie, tags
│       ├── history/                ← Historial, filtros, calendario, mapa, PDF
│       ├── home/                   ← Dashboard con widgets configurables
│       ├── analytics/              ← Overview, trends, patterns, coach insights
│       ├── groups/                 ← Grupos sociales, desafíos, ranking, recompensas
│       ├── templates/              ← Plantillas de entrenamiento con bloques y alarmas
│       ├── avatar/                 ← Constructor de avatares SVG por capas
│       ├── profile/                ← Menú perfil, foto, configuración de cuenta
│       └── admin/                  ← Panel admin (solo usuarios con isAdmin=true)
├── firestore.rules                 ← Reglas de seguridad Firestore
├── pubspec.yaml
├── CHANGELOG.md
└── ARCHITECTURE.md
```

### Patrón arquitectónico: Feature-First + MVVM

Cada feature sigue la estructura:
```
features/{nombre}/
├── data/           ← Repositorios, modelos, servicios de datos
├── viewmodels/     ← Lógica de presentación con ValueNotifier
└── views/          ← Widgets UI puros (sin lógica de negocio)
```

**Reglas estrictas:**
- `views/` — solo UI. Nunca lógica de negocio ni llamadas directas a Firebase
- `viewmodels/` — estado con `ValueNotifier` + `ValueListenableBuilder`. **Nunca GetX para estado**
- `data/` — fuente de verdad. Repositorios delegan en remotes o servicios
- GetX permitido únicamente para navegación/utilidades puntuales

---

## 2. Servicios Firebase utilizados

| Servicio | Uso |
|---|---|
| **Firebase Auth** | Autenticación email/password y Google Sign-In |
| **Firestore** | Base de datos principal: usuarios, entrenamientos, grupos, plantillas |
| **Firebase Storage** | Fotos de perfil subidas por el usuario |
| **Firebase App Check** | Protección de las APIs Firebase contra acceso no autorizado |

### App Check por plataforma

| Plataforma | Release | Debug |
|---|---|---|
| Android | Play Integrity | Debug token |
| iOS | DeviceCheck | Debug token |
| Web | reCAPTCHA v3 (`6LcH2acsAAAAAGdH2Wi1X39xnD3EB6o40ZsVjnIo`) | reCAPTCHA v3 (misma clave) |
| Wear OS (Android) | Play Integrity | Debug token (`BuildConfig.DEBUG`) |

---

## 3. Flujo de autenticación

### Inicialización de la app

```
main()
  ├── Firebase.initializeApp()
  ├── FirebaseAppCheck.instance.activate()   ← todas las plataformas
  ├── ThemeService.init()                    ← carga tema desde SharedPreferences
  └── runApp(MyApp)
        └── MaterialApp(home: SplashScreen)
              └── animación 2s → Navigator.pushReplacement(AuthWrapper)
```

### AuthWrapper

`StreamBuilder<User?>` sobre `FirebaseAuth.instance.authStateChanges()`:
- `waiting` → `CircularProgressIndicator`
- `hasData` → `HomeView(user: snapshot.data!)` — usuario pasado explícitamente para evitar race condition en web
- sin datos → `AuthPage`

### Flujo email/password

```
AuthPage → registro:
  AuthRepository.signUp(email, password, nombre)
    ├── createUserWithEmailAndPassword()
    ├── saveUserDoc(uid, {nombre, email, createdAt})
    └── sendEmailVerification()

AuthPage → login:
  AuthRepository.signIn(email, password)
    └── signInWithEmailAndPassword()
        └── verifica emailVerified antes de permitir acceso a HomeView
```

### Flujo Google Sign-In

**Móvil:**
```
GoogleSignIn().signIn()
  └── signInWithCredential(GoogleAuthProvider.credential(...))
        └── AuthRepository comprueba getUserName()
              └── si null → saveUserDoc()
```

**Web:**
```
_auth.signInWithPopup(GoogleAuthProvider())
  ├── user.getIdToken(true)          ← fuerza refresco de token
  ├── _db.collection("users").doc(uid).get()
  │     └── si !doc.exists → saveUserDoc()   ← creación antes de cualquier listener
  └── return UserCredential
```

La creación del documento en web ocurre en `auth_remote.dart` (antes de retornar), no en `auth_repository.dart`, para garantizar que el documento existe antes de que los listeners de Firestore se activen.

### Wear OS — bypass de autenticación

El reloj no implementa flujo de login propio. Accede a Firestore mediante un código de sesión de 6 caracteres generado en la app móvil (`WearAuthService`):

```
App móvil:
  WearAuthService.generateSession()
    └── wear_sessions/{código} = {uid, status: 'pending', createdAt}

Wear OS:
  Usuario introduce código de 6 dígitos
    └── lee wear_sessions/{código}
          └── obtiene uid → usa como identidad para leer trainings/templates/settings
```

Las reglas de Firestore permiten leer `trainings`, `templates` y `settings` con `request.auth == null` para soportar este flujo. La sesión expira (regla de lectura: `createdAt > now - 10 minutos`).

---

## 4. Modelo de datos Firestore

### Colecciones principales

```
users/{uid}
  ├── nombre: String
  ├── email: String
  ├── photoUrl: String?
  ├── profilePicType: String?       ← 'photo' | 'avatar'
  ├── avatarConfig: Map?            ← configuración del avatar SVG
  ├── isAdmin: bool?
  └── createdAt: Timestamp

users/{uid}/entrenamientos/{id}     ← OBSOLETO (nombre antiguo)
users/{uid}/trainings/{id}
  ├── titulo: String
  ├── fecha: String                 ← ISO8601, usado para queries de rango
  ├── distanciaTotalM: int          ← metros totales
  ├── tiempoTotalSec: double        ← segundos totales
  ├── ritmoMedioSecKm: int          ← pace pre-calculado (seg/km)
  ├── rpePromedio: double           ← 1-10
  ├── gps: bool
  ├── tags: List<String>?
  ├── series: List<Map>             ← array de series
  │   ├── distanciaM: int
  │   ├── tiempoSec: double
  │   ├── descansoSec: double
  │   ├── rpe: double
  │   ├── usedGps: bool
  │   └── gpsPoints: List<Map>?    ← {lat, lng, accuracy, timestamp}
  ├── trackPoints: List<Map>?       ← trazado GPS completo
  ├── createdAt: Timestamp
  └── updatedAt: Timestamp

users/{uid}/tags/{nombre}
  ├── name: String
  ├── color: int                    ← ARGB como int
  └── createdAt: Timestamp

users/{uid}/templates/{id}
  ├── name: String
  ├── colorValue: int
  ├── enabled: bool
  ├── periodicity: String?
  └── blocks: List<Map>
      ├── id: int
      ├── order: int
      ├── type: String              ← 'distance' | 'time'
      ├── value: int                ← metros o segundos
      ├── restSeconds: int
      └── alerts: Map
          ├── enabled: bool
          ├── mode: String          ← 'time' | 'pace'
          ├── timeMin: int
          ├── timeSec: double
          ├── paceMin: int
          ├── paceSec: int
          └── segmentDistance: int

users/{uid}/settings/homeLayoutConfig
  ├── userId: String
  ├── widgets: List<Map>
  └── lastUpdated: String

groups/{groupId}
  ├── name: String
  ├── description: String
  ├── adminUid: String
  ├── memberCount: int
  ├── createdAt: Timestamp
  └── members: List<Map>

groups/{groupId}/challenges/{id}
  ├── title: String
  ├── type: String
  ├── status: String                ← 'active' | 'finished'
  ├── startDate: String
  ├── endDate: String
  └── goal: Map

groups/{groupId}/participations/{uid}
  ├── userId: String
  ├── score: double
  └── updatedAt: Timestamp

wear_sessions/{código}              ← código de 6 dígitos como document ID
  ├── uid: String
  ├── status: String                ← 'pending' | 'used'
  └── createdAt: Timestamp

invite_codes/{código}
  ├── groupId: String
  ├── createdBy: String
  ├── uses: int
  └── maxUses: int?

global_challenges/{id}
  ├── title: String
  ├── status: String
  └── ...

result_notifications/{uid}/...
  └── notificaciones de resultados de desafíos
```

---

## 5. Modelo de seguridad

### App Check

Todas las llamadas a Firebase pasan por App Check. En release, solo dispositivos con Play Integrity (Android) o DeviceCheck (iOS) verificados pueden acceder. En web se requiere token reCAPTCHA v3 válido. El Wear OS usa Play Integrity en release y debug token en desarrollo.

### Firestore Rules — resumen por colección

| Colección | Lectura | Escritura |
|---|---|---|
| `users/{uid}` | Solo el propio usuario | Solo el propio usuario |
| `users/{uid}/trainings` | Propio usuario **o sin auth** (Wear OS) | Solo el propio usuario |
| `users/{uid}/templates` | Propio usuario **o sin auth** (Wear OS) | Solo el propio usuario |
| `users/{uid}/settings` | Propio usuario **o sin auth** (Wear OS) | Solo el propio usuario |
| `users/{uid}/tags` | Solo el propio usuario | Solo el propio usuario |
| `groups` | Miembro del grupo | Validado con `isSafeWrite()` |
| `groups/.../challenges` | Miembro del grupo | Admin del grupo |
| `groups/.../participations` | Miembro del grupo | Propio usuario |
| `wear_sessions` | Sin restricción de auth, ventana de 10 min | Solo usuario autenticado, campos validados |
| `invite_codes` | Cualquier usuario autenticado | Admin del grupo para update/delete |
| `result_notifications` | Solo el destinatario (`uid`) | Solo el remitente autenticado, `toUid == uid` |
| `global_challenges` | Cualquier usuario autenticado | Solo admins |

### Helpers de seguridad en reglas

```javascript
function isSignedIn() { return request.auth != null; }
function isOwner(uid) { return request.auth.uid == uid; }
function isGroupAdmin(groupId) { ... comprueba groups/{groupId}.adminUid }
function isSafeWrite() { /* valida campos mínimos y tamaño del documento */ }
function isReasonableDocument() { /* limita tamaño de documentos entrantes */ }
```

### Límites de consulta

Todas las consultas Firestore principales tienen `.limit()` para acotar el coste:

| Consulta | Límite |
|---|---|
| `getTrainings()` (historial personal) | 100 |
| `_getRawData()` (gráficas home) | 500 |
| `fetchUserTrainings()` (stats de grupo) | 500 |
| `collectionGroup('trainings')` (admin) | 1000 |
| `collectionGroup('participations')` (admin) | 500 |
| Streams `medal_history` / `badge_history` | 50 |
| Búsquedas por email | 1 |

---

## 6. Caché y rendimiento

### HomeEstadisticaRepository (singleton + caché)

- Instancia única en toda la app (patrón singleton)
- Caché en memoria por combinación `rango_métrica` (ej. `"oneWeek_ritmoMedio"`)
- Expiración: 5 minutos
- Invalidación automática al guardar un entrenamiento (`TrainingRepository.createTraining()` llama `clearCache()`)
- Impacto: reduce de ~20 consultas Firestore por sesión Home a máximo 20 en los primeros 5 minutos

### HistoryController (carga única + filtrado en memoria)

- `loadTrainings()` carga hasta 100 entrenamientos una sola vez en `initState`
- Todos los filtros (fecha, distancia, tags, texto, series) operan en memoria sobre `_allTrainings`
- Re-fetch solo en: error retry, botón de refresh manual, o tras editar/borrar un entrenamiento

### PatternCache (singleton, 5 minutos)

- Caché de patrones de series y entrenamientos detectados
- Validación por longitud de lista (débil — no detecta borrado+inserción con mismo count)

---

## 7. Tracking GPS — arquitectura

```
core/tracking/
├── tracking_state.dart     ← GpsStatus: uninitialized → ready → active → paused → error
├── tracking_types.dart     ← enums y tipos
└── sensor_frame.dart       ← frame combinado GPS + pedómetro

core/services/
├── gps_service.dart        ← Haversine + KalmanFilter, ventana 5 puntos, descarta accuracy >20m
└── sensor_service.dart     ← Pedómetro (pedometer package)

core/utils/
└── kalman_filter.dart      ← Filtro Kalman para suavizado de coordenadas GPS
```

El servicio GPS descarta automáticamente puntos con `accuracy > 20m` y aplica un filtro Kalman sobre una ventana deslizante de 5 puntos para suavizar la trayectoria.

---

## 8. Wear OS — arquitectura interna

```
MainActivity.kt
  └── SwipeDismissableNavHost
        ├── "home"            → HomeScreen (stats Firestore)
        ├── "series_page"     → SeriesPageScreen (config serie + picker plantilla)
        ├── "series_active"   → SeriesActiveScreen (entrenamiento activo)
        └── "template_picker" → TemplatePickerScreen (selector plantilla)

SeriesTrainingService.kt (Foreground Service)
  ├── companion.instance          ← referencia singleton para comunicación con UI
  ├── companion.pendingTemplate   ← plantilla seleccionada antes de iniciar
  ├── companion.templateFinished  ← StateFlow<Boolean> para overlay de completado
  ├── timer interno por serie
  ├── alarmas de ritmo/tiempo via computeAlarmIntervalMs()
  └── confirmRpe() → avanza bloque de plantilla o finaliza
```

La comunicación entre la UI Compose y el servicio usa `StateFlow` en el companion object, colectado con `collectAsState()` en los Composables.

---

## 9. Deuda técnica conocida

### Prioridad alta

| Ítem | Descripción |
|---|---|
| Prints de debug en producción | `auth_remote.dart` tiene prints `WEB LOGIN: ...` temporales que deben eliminarse una vez confirmado el fix de Google Sign In en web |
| `stub_html.dart` sin uso | `lib/core/utils/stub_html.dart` existe pero ya no es importado en ningún archivo (el import condicional de `dart:html` fue eliminado de `auth_repository.dart`). Puede borrarse |
| Paginación en historial | `getTrainings()` carga máximo 100 entrenamientos. Usuarios con más de 100 no ven el historial completo. Requiere implementar cursor-based pagination con `startAfterDocument` |

### Prioridad media

| Ítem | Descripción |
|---|---|
| `TrainingRepository` instanciado ad-hoc | `training_summary_screen.dart:144` crea `TrainingRepository()` directamente para buscar un entrenamiento similar. Al ser el repositorio no singleton, no comparte ningún estado |
| Invalidación débil de `PatternCache` | La caché de patrones usa `_cachedData.length == data.length` para detectar cambios. No detecta borrado + inserción con mismo número de entrenamientos |
| Duplicación de creación de documento Google (web) | `auth_remote.dart` (web path) y `auth_repository.dart` (mobile path) ambos intentan crear el documento Firestore del usuario. El segundo es redundante en web pero inocuo |
| `getAllEntrenamientos(uid)` es alias inútil | `TrainingRepository.getAllEntrenamientos()` solo llama a `getTrainings()` ignorando el `uid` recibido. Confuso para futuros desarrolladores |

### Prioridad baja

| Ítem | Descripción |
|---|---|
| `TimeRange.max` desde 2020 hardcodeado | `HomeEstadisticaRepository` usa `DateTime(2020, 1, 1)` como inicio. Un usuario que tenga datos antes de esa fecha no los verá |
| No hay tests automatizados | El proyecto no tiene tests unitarios ni de integración |
| Versión de `firebase_app_check` fijada a `^0.4.1+1` | Versión algo antigua. Migrar a la última cuando haya estabilidad en la API |

---

## 10. Variables de entorno y configuración

| Variable | Dónde | Valor |
|---|---|---|
| `google-services.json` | `android/app/` | Configuración Firebase Android (no en repo) |
| `GoogleService-Info.plist` | `ios/Runner/` | Configuración Firebase iOS (no en repo) |
| `firebase_options.dart` | `lib/` | Generado por `flutterfire configure` |
| reCAPTCHA v3 site key | `lib/main.dart` | `6LcH2acsAAAAAGdH2Wi1X39xnD3EB6o40ZsVjnIo` |
| Brand color | `lib/config/app_theme.dart` | `Tema.brandPurple = Color(0xFF8E24AA)` |

---

## 11. Comandos útiles

```bash
# Configurar Firebase para una nueva plataforma
flutterfire configure

# Analizar errores de compilación
flutter analyze 2>&1 | grep 'error:'

# Publicar reglas de Firestore
firebase deploy --only firestore:rules

# Build Android release
flutter build apk --release

# Build Wear OS
cd wear_os && ./gradlew assembleRelease
```
