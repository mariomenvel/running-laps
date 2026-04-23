# CHANGELOG — Running Laps

## [GPS — EKF2D + fusión IMU] — 2026-04-23

### Mejoras GPS
- EKF2D con estado 4D (lat, lon, velocidad, heading)
- Predicción sub-segundo cada 100ms con giroscopio y acelerómetro
- processNoise adaptativo: bajo en rectas (gravedad restada), alto en curvas
- Umbral accuracy: 25m → 35m con ponderación por accuracy²
- Micro-movement threshold inteligente con podómetro (iOS)
- RDP smoother: epsilon trackPoints 2.5 → 2.0 metros
- sensors_plus: acelerómetro + giroscopio a 50Hz (gameInterval)

### Pendiente de prueba en campo
- Validar trazas en ciudad con edificios
- Comparar con recorrido de referencia
- Ajustar epsilon RDP según resultados reales

## [Fase 5 — Métricas de progreso] — 2026-04-10

### Nueva feature: ProgressView (lib/features/athlete/)
Accesible desde AthleteHubView → "Ver análisis"
(reemplaza enlace a AnalyticsHubScreen para usuarios atleta)

### ProgressRepository
- `getPersonalRecords`: mejor pace por distancia estándar
  (400m/1km/5km/10km) con tolerancias por rango
- `getSeriesProgress`: grupos de series equivalentes (±10%
  distancia, mínimo 3) con historial temporal de pace
- `getWeeklyVolume`: km reales por semana, últimas 12 semanas,
  semanas vacías incluidas
- `getPlannedVsExecuted`: sesiones vinculadas con training
  ejecutado, indexado en memoria sin queries adicionales

### ProgressViewModel
- Carga en paralelo con Future.wait
- Media móvil de 4 semanas sobre volumen semanal
- `trendForGroup`: tendencia pace primera vs segunda mitad
- `paceDeviationSecPerKm`: delta objetivo vs ejecutado,
  usa punto medio del rango pace como referencia

### ProgressView — 4 secciones
- Récords personales: grid 2×2 con pace y fecha
- Progreso en series: mini gráfica CustomPaint por grupo,
  badge tendencia mejorando/a revisar
- Volumen semanal: barras + línea media móvil, CustomPaint
- Planificado vs ejecutado: delta con colores semáforo
  (verde ≤15s/km, ámbar ≤30, rojo >30)

### Enganches abiertos para FC
- TrainingLoadService acepta fcAvgBpm/fcMax/fcRest opcionales
- Sin FC: proxy categoría+RPE. Con FC: TRIMP de Banister
- Eficiencia aeróbica y cardiac decoupling pendientes

## [Fase 4 — Competiciones y macrociclo] — 2026-04-10

### Modelos
- `AthleteSession`: nuevos campos `raceName`, `raceDistanceM`,
  `targetTimeSeconds` para sesiones de tipo competición

### Servicios
- `TrainingLoadService` (singleton, lógica pura):
  cálculo de carga con TRIMP de Banister si hay FC,
  proxy categoría+RPE si no; `nextRace`, `daysUntilRace`,
  `isRaceWeek`, `daysUntil`. Enganches abiertos para FC.

### SessionEditorView
- Sección "Detalles de la competición" dinámica cuando
  category == competicion: nombre, distancia estándar/custom,
  tiempo objetivo h/m/s

### AthleteHubView
- `_RaceCountdownCard`: contador regresivo visible cuando
  hay competición en ≤21 días, con indicador de semana taper

### SeasonView (nueva pantalla)
- Accesible desde AthleteHubView → "Ver temporada"
- Gráfica de barras scrollable: carga semanal 16 semanas
  con colores por contexto (competición/taper/alta/normal)
- Próximas competiciones con badge de días restantes
- Estadísticas del período: km, sesiones, carga total
- Nota informativa: carga estimada, mejora con pulsómetro

## [Fase 3 — Modo atleta y planificación] — 2026-04-10

### Feature athlete (nueva, reemplaza feature calendar)
- `AthleteSession` — modelo completo con warmup/cooldown texto
  libre, bloques tipados (series/continuousTime/continuousDistance),
  objetivos por bloque (pace rango, RPE, zona FC), dos notas
  separadas (planificación y ejecución)
- `AthleteSessionRepository` — stream por rango, CRUD completo,
  markAsCompleted, getSessionsForDate
- `AthleteHubView` — hub de entrada desde Perfil → "Modo atleta":
  estado vacío explicativo, resumen semanal con datos, próximo
  entreno, acceso a calendario y analytics
- `AthleteCalendarView` — StandardTableCalendar con marcadores
  por categoría de sesión
- `SessionEditorView` — editor completo: fecha/hora, categoría,
  calentamiento/cooldown texto libre, bloques, dos notas,
  partir de plantilla existente, guardar como plantilla
- `SessionBlockEditor` — ReorderableListView de bloques,
  _BlockEditorSheet con campos por tipo y sección objetivos
  colapsable (pace rango, RPE slider, zona FC)
- `SaveAsTemplateSheet` — opciones granulares: calentamiento,
  vuelta a la calma, bloque sin/con objetivos, parte principal
  sin/con objetivos, sesión completa

### Limpieza
- Feature calendar eliminada (PlannedSession, CalendarView,
  CalendarViewModel, PlannedSessionEditorView)
- Icono calendario eliminado de HomeView
- Referencias a PlannedSession eliminadas de training_start_view

### Perfil
- Nuevo tile "Modo atleta" en ProfileMenuScreen

### Pendiente
- Vinculación entreno ejecutado con sesión planificada
  (reemplazar _LinkSessionSheet eliminada — ticket para Fase 3.1)
- Notificación recordatorio cuando hay hora en la sesión

---

## [Decisiones de diseño — Modo atleta] — 2026-04-10

### Diseño aprobado
- Modo atleta accesible desde Perfil (no desde HomeView)
- AthleteHubView como pantalla de entrada con resumen semanal
- SessionEditorView: calentamiento/cooldown texto libre,
  bloques tipados, objetivos por bloque, dos notas separadas
- Pace objetivo como rango min-max
- Reps explícitas con registro individual por rep al ejecutar
- Guardar como plantilla con opciones granulares
- Feature calendar anterior (PlannedSession) se reemplaza
  completamente por feature athlete (AthleteSession)

### Analytics — decisión
- Hub existente se enlaza desde Modo atleta hasta Fase 5
- Fase 5 rediseñada: métricas con narrativa, no números aislados
- Métricas prioritarias sin FC: récords, progreso pace series,
  volumen media móvil, planificado vs ejecutado, RPE vs pace
- Métricas con FC (post pulsómetro BLE): eficiencia aeróbica,
  cardiac decoupling, ATL/CTL/TSB

---

## [Fase 1 — Zonas de entrenamiento] — 2026-04-08

### Nuevos archivos
- `lib/features/profile/data/user_profile_model.dart` — modelo completo
  de usuario con fromMap/toMap/copyWith (sentinel para nullable)
- `lib/core/services/zones_service.dart` — singleton, lógica pura:
  fcMaxEffective, zonesFor, zoneFor. ZoneRange con color incluido
- `lib/features/profile/data/zones_repository.dart` — getUserProfile,
  saveFcConfig con update parcial (no sobreescribe campos no enviados)
- `lib/features/profile/viewmodels/zones_viewmodel.dart` — 
  ZonesViewModelState inmutable + ZonesViewModel con ValueNotifier
- `lib/features/profile/views/zones_config_screen.dart` — pantalla
  completa con onboarding contextual (birthDate/sex), tabla de zonas
  en tiempo real, validación FCmáx 100-220 y FC reposo 30-100

### Archivos modificados
- `lib/features/auth/data/auth_repository.dart` — fcMax, fcReposo,
  birthDate, sex inicializados a null en registro email/password
  y Google Sign-In móvil
- `lib/features/auth/data/auth_remote.dart` — ídem para Google
  Sign-In web
- `lib/core/theme/app_colors.dart` — añadidos tokens de zonas:
  rest, rpeLow, rpeMid, effort, rpeMax
- `lib/features/profile/views/profile_menu_screen.dart` — entrada
  "Zonas de entrenamiento" en sección Personal

### Aparcado (requiere integración BLE pulsómetros)
- T5: distribución de tiempo por zona en detalle de entreno
- T7: onboarding momento 2 (detección de FC alta post-entreno)

### Deuda técnica registrada
- AppColors vive en core/theme/app_colors.dart, no en
  config/app_theme.dart — referencias en CLAUDE.md y COLOR_SYSTEM.md
  desactualizadas (baja prioridad)
- _OnboardingSheetState usa setState para estado local de formulario
  — aceptable en widget efímero sin ViewModel asociado

## [GPS Fase 4 - RDP Smoothing + Stride Persistido] — 2026-04-08

### GPS - Post-proceso y calibración personal
- Nuevo archivo lib/core/utils/rdp_smoother.dart — algoritmo Ramer-Douglas-Peucker
  - Simplifica trazas GPS antes de guardar en Firestore
  - Epsilon 2.5m: preserva curvas, elimina puntos redundantes en rectas
  - Distancia perpendicular cross-track esférica (precisa para cualquier distancia)
  - Aplicado a trackPoints (traza completa) y gpsPoints de cada serie
  - Solo si hay más de 10 puntos (evita procesar trazas triviales)
- Stride length persistido en Firestore:
  - Guardado en users/{uid}/settings/gpsCalibration al finalizar sesión
  - Solo si _gpsStableSeconds >= 30 (calibración suficiente)
  - Cargado antes de startTracking() para que el primer tick use el valor calibrado
  - Rango válido: 0.3m - 2.0m (descarta valores incoherentes)
  - Campo sessions: incremento atómico para rastrear número de calibraciones

### Referencia
Ver GPS_Plan_RunningLaps.docx — Fase 4 completada.
Plan GPS completo implementado (Fases 1-4).

## [GPS Fase 3 - UserTrackingState + Dead Reckoning] — 2026-04-08

### GPS - Máquina de estados y dead reckoning
- UserTrackingState activado en el pipeline (era dead code)
- Nuevo campo userState en TrackingState
- Máquina de estados en _processTick():
  - movingGps: GPS usable + movimiento detectado
  - movingNoGps: sin GPS >5s pero hay pasos del podómetro
  - stopped: sin pasos + velocidad <0.3 m/s durante >3s
  - uncertain: transición entre estados
- Dead reckoning en estado movingNoGps: usa podómetro exclusivamente
  cuando el GPS se pierde (túneles, edificios, sombras)
- Contadores _noGpsSeconds y _stoppedSeconds para transiciones suaves
- Reset de contadores en startTracking()

### Referencia  
Ver GPS_Plan_RunningLaps.docx — Fase 3 completada.
Fase 4 (RDP smoothing + stride persistido) es el siguiente paso.

## [GPS Fase 2 - EKF 2D] — 2026-04-08

### GPS - Extended Kalman Filter 2D
- Nuevo archivo lib/core/utils/ekf2d.dart — EKF con vector de estado [lat, lon, vel, heading]
- Reemplaza los dos KalmanFilter 1D independientes (lat y lon separados)
- Ventajas vs Kalman 1D:
  - Modela la correlación entre latitud y longitud via heading
  - Predicción cinemática: propaga posición usando velocidad + heading entre ticks GPS
  - Corrección GPS con ruido adaptativo (accuracy → R matrix)
  - updateHeading() cuando speed > 0.5 m/s para mantener heading actualizado
- Matrices: F (Jacobiano del modelo), P (covarianza 4x4), R (ruido medición), Q (ruido proceso)
- Sin dependencias externas — solo dart:math
- _accuracyToDegrees() eliminado (ya no necesario)
- _ekf.reset() en startTracking(), stopTracking() y dispose()

### Referencia
Ver GPS_Plan_RunningLaps.docx — Fase 2 completada.
Fase 3 (UserTrackingState + dead reckoning) es el siguiente paso.

## [GPS Fase 1 - processNoise adaptativo] — 2026-04-08

### GPS - Mejoras Kalman filter
- processNoise baseline aumentado de 1e-6 a 1e-5 (reducía demasiado las curvas)
- processNoise adaptativo en _processTick():
  - Sube cuando GPS accuracy es pobre (señal débil)
  - Sube x3 cuando hay cambio brusco de velocidad (curvas/aceleraciones)
  - Rango: 5e-6 (señal perfecta) a 1.5e-4 (señal pobre + curva)
- Nuevo método setProcessNoise() en KalmanFilter con clamp [1e-7, 1e-3]

### Referencia
Ver GPS_Plan_RunningLaps.docx — Fase 1 completada.
Fase 2 (EKF 2D) pendiente de validar resultados de Fase 1 en campo.

## [Optimización de consultas y agregados] — 2026-04-05

### Límites de consultas añadidos
- `group_detail_repository.dart`: `.limit(500)` en fetches de trainings para rankings de grupo
- `training_repository.dart`: `.limit(100)` en `getTrainings()`
- `rewards_repository.dart`: `.limit(50)` en streams de medals y badges
- `home_view.dart`: `.limit(20)` en stream de `result_notifications`

### HomeEstadisticaRepository
- Convertido a singleton para persistir caché entre navegaciones
- Caché en memoria de 5 minutos por combinación rango+métrica (clave: `"${range.name}_${metric.name}"`)
- `.limit(500)` en queries de gráficas (`_getRawData`)
- `clearCache()` llamado automáticamente desde `TrainingRepository.createTraining()` al guardar un entrenamiento

### Agregados en `users/{uid}`
- Nuevos campos: `totalKm` (double), `totalSessions` (int), `totalTimeMinutes` (double), `lastTrainingDate` (String ISO8601)
- Se actualizan atómicamente con `FieldValue.increment()` en `createTraining()` — seguro ante escrituras concurrentes
- Inicializados a 0 en el registro de nuevos usuarios (email/password y Google Sign-In, en los tres puntos de creación de documento)
- KPI cards de la home leen estos campos directamente con fallback a cálculo local sobre `_entrenamientos` para usuarios sin los campos (compatibilidad con cuentas existentes)
- Documento `users/{uid}` cargado en paralelo con `getAllEntrenamientos()` usando `Future.wait` — sin coste adicional de latencia

### Correcciones de race condition web
- `AuthWrapper` pasa el objeto `User` directamente a `HomeView(user: snapshot.data!)` para evitar `currentUser == null` en `initState` en web
- `_loadEntrenamientos()` usa `widget.user?.uid ?? FirebaseAuth.instance.currentUser?.uid` como fuente primaria de uid
- Stream `result_notifications` limitado a `.limit(20)`

### iOS — Limitaciones conocidas
- Live Activities no implementado (requiere Xcode + Swift extension target)
- No hay notificación persistente en iOS como en Android — el foreground task muestra la barra azul de ubicación del sistema
- GPS en segundo plano funciona correctamente vía `UIBackgroundModes: location`
- Botones de control (Terminar / Fin de serie) no disponibles en notificación iOS — `NotificationButtons` son Android-only
- Workaround: control desde la app o desde Wear OS

### iOS — Live Activity fixes adicionales
- Fix datos de distancia/ritmo no actualizaban en background:
  eliminado `Timer.periodic` en iOS, updates ahora se disparan desde `_handlePosition()`
  directamente al recibir posición GPS (iOS entrega eventos GPS en background
  via `UIBackgroundModes: location` aunque el isolate Dart esté suspendido)
- Timer de notificación solo activo en Android
- `pause()`/`resume()` solo gestionan el timer en Android

### iOS — Pendiente con logs
- Google Sign In: app se cierra al pulsar el botón.
  Cambios aplicados: `REVERSED_CLIENT_ID` en `Info.plist`, `GoogleService-Info.plist` añadido,
  `GIDSignIn.sharedInstance.handle(url)` en `AppDelegate.swift`.
  Requiere logs para diagnosticar el crash. Pendiente para cuando haya acceso a Xcode/Mac.

### Documentación
- Creados `CHANGELOG.md`, `ARCHITECTURE.md` y `CLAUDE.md` en raíz del proyecto

---

## [Unreleased] — 2026-04-05

### Seguridad — Firebase App Check

#### Flutter (móvil)
- Añadida dependencia `firebase_app_check: ^0.4.1+1` en `pubspec.yaml`
- Añadidas dependencias nativas en `android/app/build.gradle.kts`:
  - `firebase-appcheck-playintegrity`
  - `firebase-appcheck-debug`
- Implementada activación en `lib/main.dart`:
  - Android release: `AndroidProvider.playIntegrity`
  - Android debug: `AndroidProvider.debug`
  - iOS release: `AppleProvider.deviceCheck`
  - iOS debug: `AppleProvider.debug`
  - Web: `ReCaptchaV3Provider('6LcH2acsAAAAAGdH2Wi1X39xnD3EB6o40ZsVjnIo')`
- Eliminado el guard `if (!kIsWeb)` — App Check activo en todas las plataformas

#### Wear OS (Kotlin)
- Añadidas dependencias App Check en `wear_os/app/build.gradle.kts`:
  - `firebase-appcheck-playintegrity`
  - `firebase-appcheck-debug`
- Habilitado `buildConfig = true` en el bloque `buildFeatures`
- Implementada activación en `MainActivity.kt`:
  - Release: `PlayIntegrityAppCheckProviderFactory`
  - Debug: `DebugAppCheckProviderFactory` (via `BuildConfig.DEBUG`)

---

### Seguridad — Reglas de Firestore

Auditoría completa de `firestore.rules`. Cambios aplicados:

#### Helpers añadidos
- `isReasonableDocument()` — limita tamaño de documentos entrantes
- `isSafeWrite()` — valida campos mínimos y tamaño en escrituras de grupos

#### Colecciones endurecidas

| Colección | Cambio |
|---|---|
| `trainings` | `allow read` ampliado a `request.auth == null` para lecturas desde Wear OS sin sesión |
| `templates` | `allow read` ampliado a `request.auth == null` para lecturas desde Wear OS |
| `settings` | `allow read` ampliado a `request.auth == null` para lecturas desde Wear OS |
| `result_notifications` | Añadida validación de tamaño + comprobación `toUid == uid` |
| `groups` (create) | Envuelto en `isSafeWrite()` |
| `groups` (memberCount) | Delta bloqueado a +1 para evitar manipulación del contador |
| `invite_codes` | Validación de campos obligatorios en create; update/delete restringido a admin del grupo |
| `wear_sessions` (create) | Validación de campos requeridos, `status == 'pending'`, tipo timestamp, cota futura ≤ +10 minutos |
| `wear_sessions` (read) | Sustituido `allow read: if true` por ventana temporal: `createdAt > now - 10 minutos` |
| `invites` (uses) | Delta bloqueado a +1 |

#### Correcciones específicas
- Eliminada validación `code.size() == 6` en `wear_sessions` — el código es el ID del documento, no un campo interno
- Corregida comprobación `result_notifications`: cambiado `request.auth.uid` por `uid` (wildcard del path) para permitir escrituras entre usuarios distintos desde `ChallengeFinalizationService`

---

### Autenticación — Google Sign In en Web

**Problema:** `GoogleSignIn().signIn()` devuelve `null` en plataforma web.

**Solución aplicada en `lib/features/auth/data/auth_remote.dart`:**
- Añadido branch `if (kIsWeb)` en `signInWithGoogle()`
- Web usa `_auth.signInWithPopup(GoogleAuthProvider())` directamente
- Tras `signInWithPopup`, se fuerza refresco del token: `await user.getIdToken(true)`
- Creación del documento Firestore del usuario en el propio branch web, antes de retornar el `UserCredential`:
  - Si `doc.exists == false` → `_db.collection("users").doc(uid).set({...})`
  - Esto evita condiciones de carrera con listeners que se abren antes de que `AuthRepository` pueda crear el documento
- Añadidos prints de debug temporales para diagnóstico (`WEB LOGIN: user=...`, `WEB LOGIN: token refreshed`, etc.)

**Por qué en `auth_remote` y no en `auth_repository`:**
En web, los listeners de Firestore se activan antes de que el flujo de `AuthRepository.signInWithGoogle()` llegue a su comprobación `getUserName()`. Crear el documento directamente en `auth_remote`, inmediatamente tras el `signInWithPopup` y con token ya refrescado, garantiza que el documento existe cuando los primeros listeners lo necesitan.

---

### Autenticación — Race condition en HomeView (web)

**Problema:** `FirebaseAuth.instance.currentUser` puede ser `null` en `HomeView.initState()` en web, porque el SDK de Firebase web inicializa el estado de auth de forma asíncrona.

**Solución:**
- `AuthWrapper` pasa el objeto `User` del stream directamente a `HomeView`:
  ```dart
  if (snapshot.hasData) return HomeView(user: snapshot.data!);
  ```
- `HomeView` recibe `User? user` como parámetro opcional
- En `initState`: `_currentUserId = widget.user?.uid ?? FirebaseAuth.instance.currentUser?.uid ?? ''`
- El parámetro es opcional (no required) para no romper otros puntos de navegación que no disponen del objeto `User`

---

### Rendimiento — Límites en consultas Firestore

Se añadió `.limit()` a todas las consultas sin cota de documentos identificadas en la auditoría:

| Archivo | Consulta | Límite añadido |
|---|---|---|
| `training_repository.dart:56` | `getTrainings()` ordenado por `createdAt` | `.limit(100)` |
| `group_detail_repository.dart:59` | `trainings` sin filtro de fecha (para stats de grupo) | `.limit(500)` |
| `group_detail_repository.dart:154` | `fetchUserTrainings()` ordenado por `fecha` | `.limit(500)` |
| `rewards_repository.dart:150` | Stream `medal_history` con `.where('uid')` | `.limit(50)` |
| `rewards_repository.dart:169` | Stream `badge_history` con `.where('uid')` | `.limit(50)` |
| `home_estadistica_repository.dart` | `_getRawData()` con filtro de fecha | `.limit(500)` |

Consultas ya protegidas (sin cambio necesario):
- `auth_remote.dart:122` — `.limit(1)` ya existía
- `user_lookup_service.dart:17` — `.limit(1)` ya existía
- `admin_repository.dart:47,52` — `.limit(1000)` ya existía
- `admin_repository.dart:177` — `.limit(500)` ya existía

---

### Rendimiento — HomeEstadisticaRepository: singleton + caché

**Problema:** `HomeEstadisticaRepository` se instanciaba de nuevo cada vez que el controlador se creaba (por re-mount del widget Home), perdiendo cualquier caché. Cada cambio de métrica o rango temporal disparaba una consulta Firestore nueva sin ningún control.

**Cambios en `lib/features/home/data/home_estadistica_repository.dart`:**

1. **Patrón singleton:**
   ```dart
   static final HomeEstadisticaRepository _instance =
       HomeEstadisticaRepository._internal();
   factory HomeEstadisticaRepository() => _instance;
   HomeEstadisticaRepository._internal();
   ```

2. **Caché en memoria por combinación rango+métrica:**
   - Clave: `"${range.name}_${metric.name}"` (ej. `"oneWeek_ritmoMedio"`)
   - Expiración: 5 minutos desde la última petición
   - Almacenamiento: `Map<String, List<DailyMetric>>` + `Map<String, DateTime>` de timestamps
   - `clearCache()` limpia ambos mapas

3. **Invalidación del caché tras guardar:**
   - `lib/features/training/data/training_repository.dart`: añadido import y llamada `HomeEstadisticaRepository().clearCache()` en `createTraining()`, inmediatamente tras obtener el `trainingId`
   - Al ser singleton, la llamada siempre impacta la misma instancia que usa el widget Home

**Impacto:** De hasta 20 consultas Firestore por sesión en la pantalla Home (5 rangos × 4 métricas), se reduce a máximo 20 consultas en las primeras 5 minutos y 0 adicionales mientras el caché sea válido.

---

### Eliminación de código muerto

- **Eliminado:** `lib/features/training/views/training_start_view_helper.dart`
  - Archivo con métodos sueltos sin clase contenedora
  - Referencias a variables no definidas en el archivo
  - Sin imports, sin ningún caller en el resto del proyecto
  - Confirmado con `flutter analyze` tras la eliminación

---

### Wear OS — Soporte de plantillas (5 partes)

#### PART 1 — TemplateModels.kt (nuevo)
- Modelos Kotlin espejo de `template_models.dart`:
  - `WearTemplateAlerts`, `WearTemplateBlock`, `WearTemplate`
- Función `parseTemplateFromFirestore(id, data)` para deserializar desde Firestore

#### PART 2 — TemplatePickerScreen.kt (nuevo)
- Pantalla Wear OS Compose para seleccionar plantilla
- Carga desde `users/{uid}/templates/` en Firestore
- Estados: spinner → "Sin plantillas" → lista con chips de color
- Callback `onTemplateSelected: (WearTemplate) -> Unit`

#### PART 3 — SeriesTrainingService.kt (modificado)
- Añadidos en companion object: `instance`, `pendingTemplate`, `_templateFinished`, `templateFinished`
- `reset()` limpia `_templateFinished`
- `onCreate()` / `onDestroy()` gestionan `instance`
- `onStartCommand()` aplica `pendingTemplate` si existe
- Nuevos métodos: `loadTemplate()`, `applyBlock()`, `computeAlarmIntervalMs()`
- `confirmRpe()`: descarta serie vacía (`distanciaM <= 0f && tiempoSec <= 2s`), avanza bloque de plantilla, emite `_templateFinished = true` al agotar bloques

#### PART 4 — SeriesActiveScreen.kt (modificado)
- Recoge `templateFinished` como estado Compose
- Overlay "¡Plantilla completada!" con degradado radial brandPurple al completar
- Auto-stop tras 2 segundos con `LaunchedEffect` + `delay`

#### PART 5 — SeriesPageScreen.kt + MainActivity.kt (modificados)
- `SeriesPage` acepta `initialTemplate: WearTemplate?` para pre-selección
- `metersToDistStr()` y `secondsToDescStr()` como helpers internos
- `MainActivity`: estado `activeTemplate` con `remember { mutableStateOf<WearTemplate?>(null) }`
- Ruta `template_picker` → `TemplatePickerScreen` con callback de selección
- Ruta `series_page` pasa `initialTemplate = activeTemplate`

---

### Wear OS — HomeScreen.kt (correcciones)

- Colección corregida: `"entrenamientos"` → `"trainings"` (nombre real en Firestore)
- Añadido `.addOnFailureListener` con logging de errores
- Parsing defensivo: lee `distanciaTotalM` del nivel superior o, si no existe, suma `series[].distanciaM` manualmente
