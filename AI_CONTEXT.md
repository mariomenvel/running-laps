# AI_CONTEXT.md — Running Laps

> Fuente de verdad técnica para cualquier agente de IA trabajando en este proyecto.
> Define reglas arquitectónicas estrictas, modelos de datos reales y restricciones operativas.
> Para specs de producto ver `DESIGN.md`, `WORKOUT_SYSTEM.md`, `PREMIUM_AI_COACH.md`.

---

## 1. Identidad del proyecto

- **Nombre**: Running Laps
- **Tipo**: Flutter app multiplataforma (Android, iOS, Web) + Wear OS (Kotlin/Compose, app independiente)
- **Core**: entrenamiento fraccionado — Series + RPE + GPS
- **Stack**: Flutter (Dart 3.9.2), Firebase (Auth, Firestore, Storage, Analytics, Functions), OpenRouter (Claude Sonnet para AI Coach)
- **Brand color**: `Tema.brandPurple = Color(0xFF8E24AA)` / `AppColors.brand`

---

## 2. Reglas arquitectónicas estrictas

### Feature-First + MVVM

Estructura obligatoria para toda feature:

```
lib/features/<name>/
├── data/
│   ├── <name>_model.dart          # clases de datos inmutables con fromMap/toMap
│   └── <name>_repository.dart     # toda la lógica Firestore/API
├── viewmodels/
│   └── <name>_controller.dart     # ValueNotifier, lógica de negocio
├── views/
│   ├── <name>_screen.dart         # pantalla principal
│   └── widgets/                   # widgets específicos de la feature
```

### Reglas irrompibles

| Regla | Detalle |
|---|---|
| Estado | **Siempre** `ValueNotifier` + `ValueListenableBuilder`. Nunca GetX para estado. |
| GetX | Solo navegación puntual si hace falta. Nunca para estado. |
| Vistas | Sin lógica de negocio. Solo UI. |
| Firebase en vistas | **Prohibido** instanciar `FirebaseFirestore.instance` / `FirebaseAuth.instance` en views. Usar repositorios. |
| `dart:html` | No importar directamente. Usar `kIsWeb` de `foundation.dart`. |
| Inputs numéricos | Siempre `NumberPickerField` / `IosPicker`. Nunca `TextField` numérico. |
| Snackbars | Siempre `ModernSnackBar.showSuccess/showError/showWarning(context, msg)`. |
| Logs | `debugPrint()`, nunca `print()`. |
| Async en State | `if (!mounted) return;` tras todo `await`. |
| Colores RPE | Nunca hardcodear. Usar escala automática de `RpeBadge` / `AppColors`. |
| Colección Firestore | Siempre `"trainings"`, nunca `"entrenamientos"` (nombre legado, obsoleto). |

---

## 3. Features activas

`lib/features/` contiene 13 features:

| Feature | Descripción |
|---|---|
| `auth` | Email/contraseña + Google Sign-In, verificación email, registro con validación (≥8 chars, 1 mayús, 1 dígito) |
| `training` | Modelos `Entrenamiento`+`Serie`, repositorio Firestore, servicios de análisis y ejecución de sesión |
| `history` | Historial paginado (máx 100 entradas, pendiente cursor), búsqueda, filtros, análisis por sesión |
| `home` | Dashboard: sesión de hoy, últimos entrenamientos, stats, retos activos, progreso semanal |
| `analytics` | 3 tabs: Rendimiento (PBs, ritmo), Entrenamiento (volumen, distribución), Forma (CTL/ATL/TSB) |
| `groups` | Grupos sociales: miembros, retos (distancia/tiempo/RPE), ranking, medals, badges |
| `templates` | Plantillas con `TemplateBlock`: bloques por distancia o tiempo + alarmas de ritmo/tiempo |
| `avatar` | Avatar SVG customizable con 11 secciones generadas en Dart puro |
| `profile` | Perfil: avatar, zonas FC, pulsómetro BLE, plantillas, grupos, configuración, cerrar sesión |
| `admin` | Panel admin (gestión usuarios, challenges globales, estadísticas) |
| `ai_coach` | Coach IA: generación semanal automática, chat, PB detection, TSB, zonas FC (ver sección 7) |
| `athlete` | Hub atleta: calendario de sesiones planificadas, editor, progreso y forma, timeline temporada |
| `calendar` | Vistas semanal/mensual/temporada. Colores por carga TRIMP. Planificación de sesiones. |

---

## 4. Modelos de datos

### 4.1 `Entrenamiento` (`lib/features/training/data/entrenamiento.dart`)

```dart
class Entrenamiento {
  String? id;
  String titulo;
  DateTime fecha;
  bool gps;
  List<Serie> series;           // obligatorio ≥1
  List<String>? tags;           // IDs de etiquetas
  double? loadScore;            // carga TRIMP
  DateTime? createdAt, updatedAt;
  TemplateSource? source;       // si viene de plantilla
  List<GpsPoint> trackPoints;   // traza GPS completa
  AnalysisResult? analysis;
  bool isManual;
  String? notas;
  double? fcMediaSesion;        // FC media en bpm
  Map? plannedComparison;       // planificado vs ejecutado
}

// Métodos:
distanciaTotalM() → int    // suma series[].distanciaM
tiempoTotalSec() → double  // suma series[].tiempoSec + descansoSec
```

### 4.2 `Serie` (`lib/features/training/data/serie.dart`)

```dart
class Serie {
  double tiempoSec;
  int distanciaM;              // metros, ≥0 (0 = solo tiempo)
  int descansoSec;
  double rpe;                  // 1-10
  bool? usedGps;
  bool? usedGpsDistance;       // distancia calculada desde GPS
  List<Map>? gpsPoints;        // [{lat, lng, ts, acc}]
  DateTime? finishedAt;
  double? fcMedia;             // FC media en bpm
  List<FcReading>? fcReadings; // FC punto a punto
}

// Métodos:
ritmoSecPorKm() → int      // throws si distanciaM ≤ 0
ritmoTexto() → String      // "4:30 /km"
```

### 4.3 `TemplateBlock` / `SessionBlock` (`lib/features/templates/data/template_models.dart`)

```dart
enum SessionBlockType { series, freeRun, easy, tempo, ... }  // 11 valores

class TemplateBlock {
  SessionBlockType type;
  int series;           // nº repeticiones
  int distance;         // metros
  int time;             // segundos (si type=time)
  Map pace;             // {min, sec} — ritmo objetivo
  double? rpeTarget;
  int recovery;         // descanso entre series en segundos
  TemplateAlerts alerts; // {enabled, mode (time|pace), params}
}

enum SessionCategory {
  regenerativo, rodajeBase, tempo, fartlek,
  seriesLargas, seriesCortas, seriesCuestas, seriesMixtas,
  competicion, test, gimnasiofuerza
}
```

### 4.4 `AiCoachProfile` (`lib/features/ai_coach/data/ai_coach_models.dart`)

```dart
class AiCoachProfile {
  String uid;
  AiCoachGoalType objetivo;      // race_5k | race_10k | race_half_marathon | race_marathon | improve_base | lose_weight | general_fitness
  AiCoachAthleteLevel nivel;     // beginner | intermediate | advanced
  DateTime? fechaObjetivo;
  int diasDisponibles;           // 1-7
  List<int> diasEspecificos;     // 0=lun, 6=dom
  int tiempoPorSesion;           // minutos
  int? pb5kSeconds;
  int? pb10kSeconds;
  int? pbHalfMarathonSeconds;
  int? pbMarathonSeconds;
  String limitaciones;
  String preferencias;
}

class AiCoachUsage {
  int generationQuotaThisMonth;
  int chatTokensUsed;
  DateTime? lastGenerationDate;
}
```

---

## 5. Firestore — colecciones reales

**CRÍTICO: usar `"trainings"`, NO `"entrenamientos"`**

```
users/{uid}                         ← doc con campos: uid, nombre, email, photoUrl,
                                      isAdmin, isAthleteMode, fcMax, fcReposo,
                                      birthDate, sex, totalKm, totalSessions,
                                      totalTimeMinutes, lastTrainingDate,
                                      generativeAvatarConfig
  ├── trainings/{id}              ← sesiones guardadas
  ├── tags/{id}                   ← etiquetas del usuario
  ├── athleteSessions/{id}        ← sesiones planificadas por el Coach IA
  ├── aiCoachEvents/{id}          ← sugerencias, feedback semanal, cambios de fase
  ├── result_notifications/{id}   ← notificaciones de retos completados
  ├── savedBlocks/{id}            ← bloques guardados por el usuario (máx 30)
  ├── templates/{id}              ← plantillas de sesión completa (backend listo, sin UI aún)
  └── settings/
        ├── aiCoachProfile        ← perfil AI Coach (doc único)
        ├── aiCoachUsage          ← cuotas de uso (doc único)
        ├── aiCoachAthleteMemory  ← memoria de preferencias/adherencia del atleta (doc único)
        ├── aiCoachKpiLatest      ← snapshot de KPIs aceptación/cumplimiento (doc único)
        ├── aiCoachAutomation     ← estado idempotencia generación semanal (doc único)
        └── gpsCalibration        ← stride length calibrado del atleta (doc único)

groups/{id}
  ├── members/{uid}
  ├── challenges/{id}
  ├── medals/{uid}
  ├── badges/{uid}
  ├── medal_history/{id}
  └── badge_history/{id}

global_challenges/{id}            ← retos globales sin grupo
appConfig/aiCoachProvider         ← config global: proveedor IA, claves, límites
waitlist/{email}                  ← emails recogidos en la landing web (joinWaitlist Cloud Function)
```

### Schema `trainings/{id}`

```json
{
  "id": "string (UUID)",
  "titulo": "string",
  "fecha": "timestamp",
  "gps": "boolean",
  "distanciaTotalM": "integer",
  "tiempoTotalSec": "double",
  "rpePromedio": "double",
  "fcMediaSesion": "double?",
  "loadScore": "double?",
  "tags": ["tagId"],
  "isManual": "boolean",
  "notas": "string?",
  "series": [{
    "tiempoSec": "double",
    "distanciaM": "integer",
    "descansoSec": "integer",
    "rpe": "double",
    "usedGps": "boolean?",
    "usedGpsDistance": "boolean?",
    "fcMedia": "double?",
    "gpsPoints": [{"lat": "double", "lng": "double", "ts": "string", "acc": "double"}]
  }],
  "trackPoints": [{"lat": "double", "lng": "double", "ts": "string"}],
  "createdAt": "timestamp",
  "updatedAt": "timestamp"
}
```

---

## 6. Servicios core (`lib/core/services/`)

| Servicio | Responsabilidad |
|---|---|
| `gps_service.dart` | GPS en tiempo real: Haversine, Kalman filter, descarta accuracy >20m, ventana 5 puntos para pace suavizado. Live Activity iOS. **No es singleton — se reinstancia por serie.** |
| `ios_live_activity_service.dart` | Puente MethodChannel/EventChannel Swift↔Dart para Live Activity (pantalla bloqueada). |
| `heart_rate_service.dart` | FC desde pulsómetro BLE o Wear OS. Stream de lecturas. |
| `settings_service.dart` | SharedPreferences: alarm defaults, GPS defaults, tema, FCmax. |
| `user_service.dart` | Gestión usuario: nombre, contraseña, borrar cuenta, reauth, `isGoogleUser()`. |
| `training_load_service.dart` | Cálculo TRIMP: duración × factor zona (Z1=1 … Z5=5). |
| `zones_service.dart` | Zonas FC: 5 zonas por %FCmáx (Z1<60%, Z2 60-70%, Z3 70-80%, Z4 80-90%, Z5>90%). |
| `notification_service.dart` | Push: recordatorios, logros, resumen semanal. Máx 2/día. |
| `wear_auth_service.dart` | Auth Wear OS: código 6 dígitos (bypass temporal — ver advertencias). |
| `session_recovery_service.dart` | Recupera sesión si app crashea: caché local + resincronización. |
| `rate_limit_service.dart` | Limita llamadas Firestore (training:save cada 3s, groups:create cada 5s). |
| `foreground_tracking_handler.dart` | Mantiene servicio de tracking vivo en foreground, notificación persistente. |
| `pdf_generator_service.dart` | Genera PDFs: resumen entrenamiento, historial. |
| `speech_to_text_service.dart` | STT singleton. Integrado en `WorkoutAiPanelViewModel` (editor) y `CalendarViewModel`, pero el botón micrófono no está expuesto en la UI todavía — código pendiente de conectar. |

---

## 7. AI Coach — arquitectura completa

**Proveedor**: Claude Sonnet vía OpenRouter (`ai_coach/data/openrouter_client.dart`).

### Servicios (`lib/features/ai_coach/data/`)

| Archivo | Responsabilidad |
|---|---|
| `ai_coach_context_builder.dart` | Extrae contexto de Firestore: perfil atleta, 7 semanas historial, trends, TRIMP, zonas FC |
| `ai_coach_prompt_builder.dart` | Construye prompt con contexto del atleta para enviarlo a Claude |
| `ai_coach_weekly_planner_service.dart` | Genera plan semanal: construye contexto → llama Claude → parsea respuesta |
| `ai_coach_automation_service.dart` | Genera plan automáticamente cada domingo |
| `ai_coach_chat_service.dart` | Chat con Coach: límite 5 turnos/conversación, historial en memoria, reset semanal automático |
| `ai_coach_decision_service.dart` | Decide qué acción tomar: generar plan / sugerir / respuesta custom |
| `ai_coach_session_generator.dart` | Genera sesión individual desde prompt del usuario |
| `ai_coach_prompt_session_generator.dart` | Variante del generador usando prompt libre |
| `pb_detector.dart` | Detecta PBs en 5K/10K/HM/Maratón. Interpola si distancia dentro ±3% de estándar. Auto-guarda desde entrenamientos con GPS. |
| `vdot_calculator.dart` | Calcula VDOT (potencial aeróbico) desde PBs y edad |
| `ai_coach_repository.dart` | CRUD Firestore: `aiCoachProfile`, `aiCoachUsage`, `athleteSessions`, `aiCoachEvents`, `aiCoachAthleteMemory`, `aiCoachKpiLatest`, `aiCoachAutomation` |

### Vistas (`lib/features/ai_coach/views/`)

- `ai_coach_onboarding_view.dart` — wizard 4 pasos: objetivo → competición → disponibilidad → resumen
- `ai_coach_onboarding_launcher.dart` — trigger para mostrar onboarding si no completado
- `ai_coach_settings_view.dart` — editar perfil Coach post-onboarding
- `ai_coach_weekly_feedback_view.dart` — análisis de semana, sugerencias, trend de forma

### Progresión intra-sesión

Las `athleteSessions` generadas por el Coach incluyen `targetReps` y `targetSegmentDistanceM` para que la pantalla de entrenamiento sepa qué se esperaba de cada bloque y pueda comparar al finalizar.

---

## 8. Componentes compartidos (`lib/core/widgets/`)

19 widgets reutilizables. Los más importantes:

| Widget | Descripción |
|---|---|
| `RpeBadge` | Badge RPE con color automático (verde→coral→rojo). Tamaños: `text`, `chip`, `stat`. |
| `RpeSlider` | Slider RPE con track gradiente verde→rojo y thumb dinámico. |
| `IosPicker` | Rueda CupertinoPicker: pill central, fade superior/inferior, `textBuilder` flexible. |
| `NumberPickerField` | Campo numérico que abre `IosPicker`. Usar siempre para inputs numéricos. |
| `BlockPreviewTile` | Preview de sesión/bloque. Estilo `compact` (texto) o `card` (franja color). |
| `ModernSnackBar` | `.showSuccess/showError/showWarning(context, msg)` — único snackbar del proyecto. |
| `MainShell` | IndexedStack con 5 tabs visibles + ocultos. API: `.navigateTo(int, params)`. |
| `AppHeader` | Logo 22px izq + avatar Firestore 20px dch. |
| `AppFooter` | BottomNav 5 tabs + FAB central. |
| `EmptyStateWidget` | Estado vacío estándar: icono, título, subtítulo, botón opcional. |
| `KpiCardWithDelta` | KPI con delta coloreado (verde=mejora, rojo=empeora). |
| `SkeletonShimmer` | Shimmer loader para UI en carga. |
| `StandardTableCalendar` | Calendario con colores por carga semanal TRIMP. |

---

## 9. GPS y tracking

- **Filtro de precisión**: descarta puntos con `accuracy > 20m`
- **Distancia**: Haversine entre puntos aceptados
- **Pace**: ventana deslizante de últimos 5 puntos para suavizado
- **Kalman filter**: `lib/core/utils/kalman_filter.dart`
- **GPSService**: no es singleton — se reinstancia por serie. El número de serie llega por constructor en `startTracking()`.
- **Tracking state**: `lib/core/tracking/` — `tracking_state.dart`, `tracking_types.dart`, `sensor_frame.dart`

---

## 10. Advertencias críticas

**Wear OS — bypass auth (TEMPORAL)**
`WearAuthService` usa código de 6 dígitos. Reglas Firestore permiten leer `trainings`/`templates`/`settings`/`tags` con `request.auth == null`. No eliminar sin implementar Cloud Function + custom token.

**`DEBUG_SIMULATE` en Wear OS**
`SeriesTrainingService.kt` tiene flag `DEBUG_SIMULATE`. Debe ser `false` antes de release.

**iOS Live Activity — tres archivos sincronizados**
Campo nuevo en `IOSLiveActivityPayload` → actualizar también:
- `ContentState` en `RunningLapsActivityAttributes.swift`
- `contentState(from:)` en `RunningLapsLiveActivityManager.swift`

**`HomeEstadisticaRepository` es singleton**
No instanciar con `HomeEstadisticaRepository()` esperando instancia independiente.

**Bug mapper (pendiente)**
Colisión `WorkoutType.free`/`continuous` en `athlete_session_mapper.dart`: ambos usan el mismo valor de categoría en Firestore. Prioridad alta — antes del refactor MVVM de `workout_editor_screen.dart`.

---

## 11. Estado de plataformas

| Plataforma | Funcionalidad | Estado |
|---|---|---|
| Android | Build + run | ✅ OK |
| iOS | Auth email/contraseña | ✅ OK |
| iOS | Google Sign-In | ❌ Crash en `AppDelegate.configureGoogleSignIn()` |
| iOS | GPS + Live Activity | ✅ OK |
| iOS | App Check | ❌ Omitido (sin Apple Developer) |
| iOS | Code signing | ❌ No configurado — bloquea TestFlight |
| Wear OS | Build + run | ✅ OK |
| Wear OS | Auth | ⚠️ Bypass temporal (código 6 dígitos) |
| Web | Build | ⚠️ Parcial |

---

## 12. Deuda técnica priorizada

1. **Bug mapper** — colisión `WorkoutType.free`/`continuous` en `athlete_session_mapper.dart`
2. **Google Sign-In iOS** — `assertionFailure` en `AppDelegate.configureGoogleSignIn()`
3. **Auth Wear OS** — reemplazar bypass con Cloud Function + custom token
4. **Historial paginación** — limitado a 100 entradas, implementar cursor-based pagination
5. `getAllEntrenamientos(uid)` — ignora el uid recibido (alias de `getTrainings()`)
6. **Refactor MVVM** `workout_editor_screen.dart` — rama `refactor/workout-editor-mvvm` pausada
7. **`GPSService.updateSerie()`** — método muerto en `gps_service.dart:191-194`, candidato a eliminar

---

## 13. Mantenimiento de documentación

**Regla:** cuando implementes algo que afecte a specs de producto, actualiza el .md correspondiente en el mismo commit. No dejar para después.

| Si cambias... | Actualiza... |
|---|---|
| Pantallas, flujos, tabs, `MainShell` | `NAVIGATION_ARCHITECTURE.md` |
| Lógica de bloques, tipos de sesión, categorías | `WORKOUT_SYSTEM.md` |
| Pantalla de sesión activa o su flujo | `SESSION_SCREENS_ARCHITECTURE.md` |
| AI Coach (onboarding, límites, prompts, modelos) | `PREMIUM_AI_COACH.md` |
| Tokens de color, escala RPE, colores carga | `COLOR_SYSTEM.md` |
| UX del editor de entrenamientos | `WORKOUT_EDITOR_UX.md` |
| Colecciones Firestore o reglas de acceso | `firestore_access_patterns.md` |
| Visión del producto, freemium, pantallas principales | `DESIGN.md` |

**Guías de trabajo** (`CLAUDE.md`, `AI_CONTEXT.md`) — actualizar siempre que cambie arquitectura, modelos de datos, servicios, advertencias críticas o deuda técnica.

---

## 14. Otros documentos de referencia

| Archivo | Contenido |
|---|---|
| `CLAUDE.md` | Guía rápida: comandos, convenciones, advertencias críticas |
| `DESIGN.md` | Visión de producto: freemium, 8 pantallas, taxonomía de sesiones |
| `COLOR_SYSTEM.md` | Sistema de colores: 3 capas, escala RPE, calendar TRIMP |
| `NAVIGATION_ARCHITECTURE.md` | MainShell: 5 tabs visibles + 8 ocultos, API `.navigateTo()` |
| `PREMIUM_AI_COACH.md` | Especificación Coach IA: onboarding, planes, límites de uso |
| `WORKOUT_SYSTEM.md` | Sistema de entrenamientos: bloques, categorías, templates |
| `SESSION_SCREENS_ARCHITECTURE.md` | Arquitectura de pantallas de sesión activa |
| `firestore_access_patterns.md` | Patrones de acceso y consultas Firestore |
| `ROADMAP_PHASE_6_6.md` | Roadmap actual de funcionalidades |
