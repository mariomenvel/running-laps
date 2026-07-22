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
- `lib/core/theme/theme_service.dart` — tema **forzado a claro** (jul 2026): el dark mode se reactivó para pruebas (d67c2e6) pero visualmente no convence todavía — se volvió a desactivar y el selector se retiró de Perfil/Ajustes. Para reactivar más adelante: `git show d67c2e6` (ThemeService con persistencia + selector en ambas vistas).
- `lib/main.dart` — Firebase init, App Check (Android + Web), Crashlytics (errores Flutter/Dart, guardado tras `!kIsWeb` — el plugin no soporta Web), `AuthWrapper` (StreamBuilder<User?>)
- `core/services/analytics_service.dart` — wrapper sobre `FirebaseAnalytics`; `logScreenView()` se llama manualmente desde `MainShell` (navegación por `IndexedStack`, no hay rutas de `Navigator` que un `NavigatorObserver` pueda instrumentar solo)
- `core/services/gps_service.dart` — GPS + Live Activity iOS + Kalman + Haversine
- `core/services/pb_celebration_service.dart` — detección/celebración de récords tras guardar (récords por serie + marcas 5K/10K/HM/M → perfil coach + notificación local). Punto único: lo llaman los 3 flujos de guardado (resumen, manual, completar manualmente) — no añadir checks de PB ad-hoc en vistas.
- `core/services/ios_live_activity_service.dart` — puente MethodChannel/EventChannel Swift↔Dart
- `firebase_options.dart` — generado por flutterfire CLI, **no editar a mano**

Features activas en `lib/features/`:
`auth` · `training` · `history` · `home` · `analytics` · `groups` · `templates` · `avatar` · `profile` · `admin` · `ai_coach` · `athlete` · `calendar`

---

## Componentes compartidos (`lib/core/widgets/`)

Widgets reutilizables — usar siempre estos, no reinventar:

| Widget | Archivo | Uso |
|---|---|---|
| `RpeBadge` | `rpe_badge.dart` | Badge RPE con color automático (verde→rojo). 3 tamaños: `text`, `chip`, `stat`. |
| `RpeSlider` | `rpe_slider.dart` | Slider RPE con track gradiente y thumb dinámico. |
| `IosPicker` | `ios_picker.dart` | Rueda CupertinoPicker estilo iOS. Usar via `NumberPickerField`. |
| `NumberPickerField` | `number_picker_field.dart` | Campo numérico — abre `IosPicker`. **Nunca usar teclado para números.** |
| `BlockPreviewTile` | `block_preview_tile.dart` | Preview de sesión/bloque. Estilos: `compact` (texto) o `card` (franja color). |
| `ModernSnackBar` | `modern_snackbar.dart` | `.showSuccess/showError/showWarning(context, msg)` — único snackbar permitido. |
| `AppHeader` | `app_header.dart` | Header global: logo izq + avatar dch (stream Firestore). **Nunca** poner flecha de volver en `leading` — la variante con `title:` centrado sí es válida. |
| `BackPill` | `back_pill.dart` | Pill "Volver" al inicio del contenido en vistas pusheadas — única affordance visible de volver (además del swipe iOS / botón Android). `color:` opcional para acento por contexto. Nunca usar `AppBar` ni flechas en el header. |
| `AppFooter` | `app_footer.dart` | BottomNav 5 tabs + FAB central (Entrenar). |
| `MainShell` | `main_shell.dart` | Shell principal IndexedStack: 5 visibles + ocultos. API: `.navigateTo(int, params)`. |
| `EmptyStateWidget` | `empty_state_widget.dart` | Estados vacíos: icono, título, subtítulo, botón opcional. |
| `KpiCardWithDelta` | `kpi_card_with_delta.dart` | Card KPI con delta coloreado (verde=mejora, rojo=empeora). |
| `SkeletonShimmer` | `skeleton_shimmer.dart` | Skeleton loader con shimmer para UI en carga. |
| `showAppDatePicker` | `app_date_picker.dart` | Selector de fecha estilo iOS (CupertinoDatePicker en BottomSheet). Usar siempre en lugar de `showDatePicker()` de Material. Parámetros: `initialDate`, `minimumDate`, `maximumDate`, `title`. |
| `showAppConfirmDialog` | `app_confirm_dialog.dart` | Diálogo de confirmación estilo iOS (CupertinoAlertDialog). Usar siempre en lugar de `showDialog()` + `AlertDialog`. `isDestructive: true` → botón rojo; `false` → morado brand. |
| `AppBottomSheetContainer` / `showAppBottomSheet` | `app_bottom_sheet.dart` | Contenedor estándar para BottomSheets (handle + radius 20 + color surface correcto dark/light). Usar para nuevos sheets. Los existentes con `backgroundColor: transparent` + decoración propia están bien. |

---

## AI Coach — Estado actual

El Coach IA usa **Claude Sonnet** vía OpenRouter (cliente en `ai_coach/data/openrouter_client.dart`).

⚠️ **JSON Schemas para `callOpenRouter`:** los structured outputs de Anthropic **no soportan** `minimum`/`maximum`/`multipleOf` (numéricos), `minLength`/`maxLength` (strings) ni `minItems` (arrays) — la petición entera falla con 400 "Provider returned error". Indicar los rangos en el system prompt y aplicar clamps al parsear (ver `ai_coach_prompt_session_generator.dart`, corregido jul 2026). Sí se soportan `enum`, `required` y `additionalProperties: false`.

Arquitectura de servicios en `lib/features/ai_coach/data/`:
- `ai_coach_weekly_planner_service.dart` — genera plan semanal automático cada domingo
- `ai_coach_context_builder.dart` — extrae contexto de Firestore (perfil, 7 semanas historial, TRIMP, zonas FC)
- `ai_coach_prompt_builder.dart` — construye el prompt con contexto del atleta
- `ai_coach_chat_service.dart` — chat con Coach (límite 5 turnos/conversación, reset semanal)
- `ai_coach_automation_service.dart` — automatización: genera plan cada domingo
- `ai_coach_decision_service.dart` — decide qué acción tomar (generar / sugerir / custom)
- `pb_detector.dart` — detecta marcas personales (PB) en 5K/10K/HM/Maratón con interpolación ±3%
- `vdot_calculator.dart` — calcula VDOT desde PBs y edad
- `ai_coach_session_generator.dart` — genera sesión individual desde prompt
- `ai_coach_session_analysis_service.dart` — análisis post-sesión (planificado vs ejecutado), fire-and-forget al guardar; persiste `coachAnalysis` en el training
- `ai_coach_repository.dart` — CRUD Firestore: `users/{uid}/settings/aiCoachProfile` + `aiCoachUsage`
- `race_goal.dart` + `race_goal_repository.dart` — **competiciones objetivo** (`RaceGoal`) en `users/{uid}/raceGoals`: fecha + distancia (5K/10K/media/maratón/otra) + prioridad `high`/`medium`/`low`. Fuente única de la fecha objetivo: el context builder deriva el `targetDate`/taper de la próxima carrera de prioridad alta (`nextPrimaryFrom`) y pasa todas al LLM vía `coachSignals.upcomingRace(s)`. **No** es un tipo de sesión — sustituye a la categoría `competicion` del editor (migración pendiente). UI (sheet/lista/calendario/Home) pendiente.

Modelos principales (`ai_coach_models.dart`):
- `AiCoachProfile` — objetivo (7 tipos), nivel (3), días disponibles, PBs, limitaciones
- `AiCoachUsage` — cuotas: `generationQuotaThisMonth`, `chatTokensUsed`, `lastGenerationDate`
- `AiCoachGoalType` — `race_5k`, `race_10k`, `race_half_marathon`, `race_marathon`, `improve_base`, `lose_weight`, `general_fitness`

Vistas:
- `ai_coach_onboarding_view.dart` — wizard 4 pasos (objetivo → competición → disponibilidad → resumen)
- `ai_coach_settings_view.dart` — configuración del Coach
- `ai_coach_weekly_feedback_view.dart` — feedback semanal: análisis, sugerencias, trend

---

## ⚠️ Advertencias críticas

**1. Wear OS — bypass auth (TEMPORAL)**
El reloj se vincula con QR + código de 6 caracteres (`WearAuthService` escribe el ID token en `wear_sessions/{code}`; el custom token real requiere Cloud Function, pendiente). Las reglas Firestore actuales ya **no** permiten lecturas sin auth: el reloj solo puede **crear/actualizar** `trainings` sin sesión si el doc declara `source == "wear_os"` y `wear_uid == uid`. No endurecer esas reglas de create/update sin implementar el reemplazo (Cloud Function + custom token).

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

**6. Inputs numéricos — sin teclado**
Para cualquier campo numérico (tiempo, distancia, descanso, RPE) usar `NumberPickerField` o `IosPicker`. Nunca `TextField` con `keyboardType: numeric`.

---

## Mantenimiento de documentación

Cuando implementes algo que afecte a los specs de producto, actualiza el .md correspondiente **en el mismo commit**:

| Cambias... | Actualiza... |
|---|---|
| Pantallas, flujos, tabs | `NAVIGATION_ARCHITECTURE.md` |
| Lógica de bloques / tipos de sesión | `WORKOUT_SYSTEM.md` |
| Pantalla de sesión activa | `SESSION_SCREENS_ARCHITECTURE.md` |
| AI Coach (onboarding, límites, prompts) | `PREMIUM_AI_COACH.md` |
| Tokens de color, escala RPE | `COLOR_SYSTEM.md` |
| UX del editor de entrenamientos | `WORKOUT_EDITOR_UX.md` |
| Colecciones Firestore o reglas de acceso | `firestore_access_patterns.md` |
| Servicios Firebase en general (Auth, Functions, Storage, App Check, Crashlytics, Analytics) | `FIREBASE_OVERVIEW.md` |
| Tests (suites nuevas, patrón de repos simulados, ci.yml) | `TESTING.md` |
| Publicación en stores, permisos del manifest/Info.plist, legal/RGPD | `PUBLISHING.md` |
| Visión del producto / freemium | `DESIGN.md` |

Guías de trabajo (`CLAUDE.md`, `AI_CONTEXT.md`) — actualizar siempre que cambie arquitectura, modelos, servicios, advertencias o deuda técnica.

Arquitectura de monetización (3 niveles, Stripe, gates del coach) — diseño pendiente de implementar → `docs/MONETIZATION_ARCHITECTURE.md`

---

## Convenciones

- Snackbars: `ModernSnackBar.showSuccess/showError/showWarning(context, msg)`
- `debugPrint()` en lugar de `print()`
- `if (!mounted) return;` tras cualquier `await` en un `State`
- Imports Dart: `dart:` → `flutter/` → `firebase_*` → paquetes externos → locales
- Colores RPE: nunca hardcodear — usar escala automática de `RpeBadge` / `AppColors`
- Números siempre via `NumberPickerField` / `IosPicker`, nunca teclado
- Permisos runtime: solo bajo demanda, nunca en el arranque. No instanciar `FlutterReactiveBle` ni llamar a `SpeechToText.initialize()` al construir servicios/vistas — en iOS ambos disparan diálogos del sistema (Bluetooth / micrófono + voz). `HeartRateService` crea el BLE perezosamente y `SpeechToTextService.startListening()` inicializa (y pide permisos) en el primer uso; el botón de micro se muestra de forma optimista (`isAvailable` empieza en `true`).

## Espaciado y radios

- `AppSpacing` está definido en `lib/core/theme/app_theme.dart` — usar en código nuevo, no migrar el existente
- Colores de etiquetas de entrenamiento en `tag_utils.dart` son intencionales (paleta de datos, no UI) — no migrar a AppColors

---

## Estado iOS

| Funcionalidad | Estado |
|---|---|
| Auth email/contraseña | ✅ OK |
| Google Sign-In | ✅ OK en dispositivo (el "crash" era assertionFailure solo-debug sin CLIENT_ID en el plist) |
| Sign in with Apple | ⚠️ Código listo — pendiente capability Xcode + Firebase Console + TestFlight (deuda #1) |
| GPS + Live Activity | ✅ OK |
| App Check | ❌ Omitido (sin Apple Developer) |
| Notificación persistente | ⚠️ Solo barra GPS — `flutter_foreground_task` no funciona en iOS |
| Code signing / Development Team | ❌ No configurado — build falla en Codemagic con "requires a selected Development Team with a Provisioning Profile". Requiere cuenta Apple Developer Program activa + configuración de firma en Codemagic. Bloquea TestFlight. |

---

## Deuda técnica prioritaria

1. **Sign in with Apple** — código Dart completo (login, doc inicial, reauth, botón solo-iOS en AuthPage). Pendiente de 3 pasos manuales con la cuenta de Apple Developer: capability "Sign In with Apple" en Xcode (target Runner), habilitar el proveedor Apple en Firebase Console → Authentication, y probar en TestFlight. Nota: el antiguo "crash de Google Sign-In iOS" era un `assertionFailure` solo-debug cuando el plist no tenía CLIENT_ID — Google Sign-In funciona en dispositivo (verificado jul 2026).
2. **Auth Wear OS** — reemplazar bypass con Cloud Function + custom token
3. **Cargas masivas de `trainings`** — home, calendario y analytics ya consultan acotado (jul 2026): `getTrainingsSince(since)` con bound UTC — home pide 5 recientes + semana actual, calendario y analytics 12 meses (analytics amplía la ventana si un rango custom pide más atrás). `getAllEntrenamientos()` (500 docs de golpe, con gpsPoints dentro) queda solo en `home_view_legacy` (huérfana). **Pendiente**: `ProgressRepository.getPersonalRecords()` sigue escaneando 500 docs en cada carga (home recreativo + hub atleta) — los PBs necesitan historial completo, así que la solución es un rollup cacheado (p. ej. en el doc del usuario actualizado al guardar cada entreno), no acotar.
4. **Refactor MVVM de `workout_editor_screen.dart`** — iniciado y pausado en rama `refactor/workout-editor-mvvm` (sin mergear).
5. **Vistas huérfanas** — 10 archivos marcados con `⚠️ HUÉRFANO` en su cabecera pendientes de eliminar tras testing manual. Verificado (jul 2026) que tienen **cero referencias**: `session_editor_view.dart`, `athlete_session_editor_view.dart`, `home_view_legacy.dart`, `profile_menu_screen.dart` (ojo: la versión **sin** `_legacy` es la huérfana; la activa es `profile_menu_screen_legacy.dart`), `analytics_hub_screen_legacy.dart`, `analytics_hub_view.dart`, `edit_profile_picture_view.dart`, `session_planner_view.dart`. Casos especiales: `global_challenge_card.dart` solo lo referencia `home_view_legacy.dart` (otra huérfana — cae con ella); `group_rewards_screen.dart` **NO es borrable entera**: `group_screen.dart` (activo) usa `GroupRewardsBody`, definido dentro de ese archivo — extraer `GroupRewardsBody` (y sus widgets privados) a su propio archivo antes de eliminar la clase `GroupRewardsScreen`.
6. **Templates de sesión completa** — `TrainingTemplatesRepository` implementado pero sin UI (pantalla "crear desde plantilla"). No es MVP — solo las plantillas de segmento son MVP actualmente. El switch "Guardar como plantilla" fue eliminado del editor hasta que exista la UI de carga.
7. **`_getWeekNumber()` en `home_flagship_chart.dart`** — aproximación de semana ISO que puede dar "Sem 0"/"Sem 53" en el cambio de año (solo etiquetas del gráfico 6M, no double-counting).
8. **Convención `fecha` (string ISO UTC)** — el esquema se mantiene (migrar a `Timestamp` requeriría backfill + actualizar Wear OS). Regla: cualquier query sobre `fecha` debe construir sus bounds con `.toUtc().toIso8601String()`, y cualquier bucketing por día/mes debe hacer `.toLocal()` tras el parse (ver `home_estadistica_repository.dart`).

### ✅ Resuelto (jul 2026) — revisión profunda
- ~~`Firebase.initializeApp()` crasheaba en arranque en Android~~ — descubierto al probar Crashlytics/Analytics en dispositivo real (no lo cubre `flutter analyze`/`flutter test`, solo se ve en runtime). Causa: `firebase_core` 4.10.0 declara `firebase_core_platform_interface: ^7.0.1`, pero ese caret deja que `pub` resuelva la 7.1.0 — que añadió el campo `recaptchaSiteKey` a `CoreFirebaseOptions` (15 campos) sin que el código Java nativo embebido en `firebase_core` 4.10.0 (`GeneratedAndroidFirebaseCore.java`, que sigue serializando solo 14) lo sepa. Resultado: `RangeError: Not in inclusive range 0..13: 14` nada más arrancar, en **todas** las plataformas Android — bug preexistente, no introducido por Crashlytics/Analytics (verificado con A/B: el crash persistía incluso sin esos paquetes). Fix: pin exacto `firebase_core_platform_interface: 7.0.1` en `pubspec.yaml`. Moraleja: los paquetes de Firebase deben resolverse siempre en conjunto — un caret suelto en cualquiera de ellos puede desincronizar el esquema pigeon nativo/Dart sin que el análisis estático lo detecte.
- ~~GPS sin funcionar en entrenos por series~~ — el flujo de series crea un `GPSService` **nuevo por cada serie** (TrainingSessionView se pushea y destruye por serie) y `_processTick` descartaba el tick entero (`return state`) hasta conseguir un fix ≤15 m: con accuracy típica de 15-35 m en el warm-up, series cortas terminaban con distancia ≈ 0 (en continua el warm-up se paga una vez y no se nota). Fix triple en `gps_service.dart`: (1) escalera de inicialización del EKF — fix fino ≤15 m durante los primeros 10 s, luego se acepta ≤35 m (el EKF pondera por accuracy², un anclaje grueso no lo desestabiliza); (2) durante el warm-up ya no se descartan ticks: el podómetro mide distancia y velocidad como dead reckoning (usa la zancada calibrada persistida); (3) `dispose()` ahora libera el `SensorService` — antes se fugaban las suscripciones de acelerómetro/giroscopio/podómetro en cada serie.
- ~~`deleteAccount()` dejaba subcolecciones huérfanas~~ — nueva Cloud Function `deleteUserData` (Admin SDK): `recursiveDelete` de `users/{uid}`, limpieza de artefactos en grupos y retos globales, borrado del Auth user y verificación de sesión reciente (`auth_time` < 10 min). **Desplegada en producción (us-central1, jul 2026).** El cliente (`UserService.deleteAccount`) la llama; conserva fallback al borrado parcial por si la función no estuviera disponible.
- ~~Queries de `fecha` con bounds locales~~ — `home_estadistica_repository`, `group_detail_repository.calculateChallengeProgress` y `training_challenge_sync_service._getTrainingsInPeriod` comparaban strings locales contra valores UTC: los entrenos entre la medianoche local y la UTC quedaban fuera. Bounds ahora en UTC y bucketing con `.toLocal()` (→ convención en deuda #9).
- ~~`TagManager.createTag()` forzaba refresh de token~~ — eliminado el `getIdToken(true)` y los debugPrints; era un workaround de debugging sin efecto en las reglas actuales.
- ~~`TrainingRepository.createTraining()` perdía `fcMedia`/`fcReadings`~~ — el suavizado RDP reconstruía la `Serie` a mano omitiendo los campos de pulsómetro; ahora usa `serie.copyWith(gpsPoints:)`.
- ~~Reset de contraseña roto~~ — `AuthRemote.sendPasswordResetEmail` consultaba `users` por email **sin sesión** (las reglas exigen `isSignedIn()`) → siempre permission-denied. Además era enumeración de cuentas. Eliminada la query previa.
- ~~`SummaryStatsCalculator` usaba la varianza como desviación estándar~~ — faltaba `sqrt()`; el % de consistencia salía ~10× inflado. También se corrigió la desalineación de índices en `percentInTarget` con segmentos sin objetivo.
- ~~`TemporalDataExtractor.sessionPacePerKm` desplazaba splits entre series~~ — restaba `serie.tiempoSec` de un acumulado que aún no lo incluía.
- ~~`AiCoachChatService` reseteaba `previewsGenerated` al normalizar la cuota~~ — ahora usa `copyWith`.
- ~~`GPSService._formatPace` podía renderizar `04:60 /km`~~ — redondeo de segundos antes de descomponer.
- ~~`GPSService.updateSerie()` (deuda #7 anterior)~~ — eliminado junto con más código muerto: `kalman_filter.dart` (el filtro real es `EKF2D`), `exponential_backoff.dart`, `rate_limit_decorator.dart`, `core/utils.dart` (vacío), `entrenamiento_utils.dart` (incluía un cálculo de semana ISO defectuoso sin usar) y `test/widget_test.dart` (vacío, rompía la suite).
- ~~`getAllEntrenamientos(uid)` ignoraba el uid~~ — verificado: pasa `uid` correctamente a `getTrainings(uid: uid)` (training_repository.dart:163)
