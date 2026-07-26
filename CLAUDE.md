# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

**Running Laps** — App Flutter para runners (entrenamiento fraccionado: series + RPE + GPS).
Plataformas: Android, iOS, Web. (Wear OS eliminado jul 2026 — ver deuda técnica resuelta.)

---

## Commands

```bash
flutter analyze 2>&1 | grep 'error:'   # errores tras cambios Dart
flutter analyze                         # lint completo
flutter test                            # todos los tests
flutter test test/unit/summary_stats_calculator_test.dart  # test individual
flutter run
flutter build apk --debug / --release
flutter build ios                       # requiere Mac + Xcode
```

---

## Arquitectura

Feature-First + MVVM. Cada feature en `lib/features/<name>/` con subcarpetas `views/`, `viewmodels/`, `data/`.

- **Estado:** siempre `ValueNotifier` + `ValueListenableBuilder`.
- **GetX:** el paquete `get` se eliminó del proyecto (jul 2026) — su último uso vivía en el editor de avatar legado ya borrado. Navegación con `Navigator` / `MainShell.navigateTo()`. No reintroducirlo.
- **Vistas:** sin lógica de negocio.
- **Firebase:** nunca instanciar `FirebaseFirestore.instance` ni `FirebaseAuth.instance` en vistas — usar repositorios. Estado (26 jul 2026): **cero vistas instancian Firestore** (`grep -rc "FirebaseFirestore.instance" lib/features/*/views/` debe seguir dando 0). Puntos de entrada por si falta algo:
  - `users/{uid}` (leer, escuchar, onboarding, avatar generativo, campos sueltos) y `users/{uid}/settings/bestMarkDistance` → `UserService` (`core/services/user_service.dart`)
  - `users/{uid}/trainings` → `TrainingRepository` (incluye `getTrainingById`, `overwriteTraining` — que sella `updatedAt` y usa `merge` — y `deleteTraining`)
  - ⚠️ **Las trazas GPS NO van en el documento del entrenamiento** (jul 2026): viven en `users/{uid}/trainings/{id}/track/data` (`trackPoints` de la sesión + `seriesGps` por índice de serie). El listado de entrenamientos arrastraba megas de coordenadas que calendario, analytics e historial no pintan. Guardar: `Entrenamiento.toMap(includeTrack: false)` + `_saveTrack` (lo hace `createTraining`). Leer para pintar un mapa: `TrainingRepository.withTrack(training)`. Los entrenamientos anteriores a jul 2026 llevan la traza embebida y siguen funcionando: `withTrack` los devuelve tal cual y `overwriteTraining` usa `merge` para no borrársela.
  - `users/{uid}/aiCoachFeedback` y demás docs del coach → `AiCoachRepository`
  - Generación de datos de prueba del panel admin → `TestDataService` (`core/services/test_data_service.dart`)

  - Uid del usuario → `UserService().currentUid`, o `await UserService().awaitCurrentUid()` cuando haya que esperar a que Firebase restaure la sesión en un arranque en frío (home, calendario y analytics lo necesitan). Resto de auth (stream de sesión, signOut, verificación de email) → `AuthRepository`.

  ✅ **La regla se cumple entera** (26 jul 2026): cero vistas instancian `FirebaseFirestore.instance` o `FirebaseAuth.instance`, y hay un test que lo vigila — `test/features/architecture_test.dart`. Si alguien lo reintroduce, la suite falla y dice a qué servicio llevarlo.
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
| `MainShell` | `main_shell.dart` | Shell principal IndexedStack: 5 visibles + ocultos + BottomNav 5 tabs + FAB central (Entrenar) montados **inline** aquí. API: `.navigateTo(int, params)`. |
| `EmptyStateWidget` | `empty_state_widget.dart` | Estados vacíos: icono, título, subtítulo, botón opcional. |
| `SkeletonShimmer` | `skeleton_shimmer.dart` | Skeleton loader con shimmer para UI en carga. |
| `showAppDatePicker` | `app_date_picker.dart` | Selector de fecha estilo iOS (CupertinoDatePicker en BottomSheet). Usar siempre en lugar de `showDatePicker()` de Material. Parámetros: `initialDate`, `minimumDate`, `maximumDate`, `title`. |
| `showAppConfirmDialog` | `app_confirm_dialog.dart` | Diálogo de confirmación estilo iOS (CupertinoAlertDialog). Usar siempre en lugar de `showDialog()` + `AlertDialog`. `isDestructive: true` → botón rojo; `false` → morado brand. |
| `AppBottomSheetContainer` / `showAppBottomSheet` | `app_bottom_sheet.dart` | Contenedor estándar para BottomSheets (handle + radius 20 + color surface correcto dark/light). Usar para nuevos sheets. Los existentes con `backgroundColor: transparent` + decoración propia están bien. |
| `AppChartStyle` | `chart_style.dart` | Tooltips e interacción táctil unificados para gráficas `fl_chart`: `lineTouch()`/`barTouch()` (fondo surface, borde, radio 8, `fitInside`, indicador de punto tocado) + `lineItem()`/`barItem()` (dato en negrita + contexto en gris). **Nunca** construir `LineTouchData`/`BarTouchData` a mano — el fondo negro por defecto es ilegible en claro. |

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
- `race_goal.dart` + `race_goal_repository.dart` — **competiciones objetivo** (`RaceGoal`) en `users/{uid}/raceGoals`: fecha + distancia (5K/10K/media/maratón/otra) + prioridad `high`/`medium`/`low`. Fuente única de la fecha objetivo: el context builder deriva el `targetDate`/taper de la próxima carrera de prioridad alta (`nextPrimaryFrom`) y pasa todas al LLM vía `coachSignals.upcomingRace(s)`. **No** es un tipo de sesión — la categoría `competicion` se retiró del vocabulario del Coach **y** del selector de tipos del editor activo (`WorkoutTypeSelector`; enums `WorkoutType.competition`/`SessionCategory.competicion` conservados por compat). UI: `ai_coach/views/race_goals_section.dart` (lista "Tus objetivos" + sheet crear/editar/eliminar) embebida en `AiCoachSettingsView` (tab 16, alcanzable desde Perfil → "Configurar IA"); marcador de bandera + entrada rápida "Marcar competición" en `calendar/views/calendar_view.dart` (tab 1, el calendario real de `MainShell`); y `home/widgets/home_race_countdown.dart` (cuenta atrás en Home solo si hay carrera de prioridad alta).

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

**1. Colección `trainings`, no `entrenamientos`**
Código legado usa `"entrenamientos"`. El nombre real es `"trainings"`. Siempre usar `"trainings"`.

**2. iOS Live Activity — tres archivos sincronizados**
Cualquier campo nuevo en `IOSLiveActivityPayload` requiere actualizar también:
- `ContentState` en `RunningLapsActivityAttributes.swift`
- `contentState(from:)` en `RunningLapsLiveActivityManager.swift`

**3. `HomeEstadisticaRepository` es singleton**
No instanciar con `HomeEstadisticaRepository()` esperando instancia independiente.

**4. Inputs numéricos — sin teclado**
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
2. ~~**Cargas masivas de `trainings`**~~ — ✅ cerrada (26 jul 2026). Home, calendario y analytics ya consultaban acotado desde jul 2026: `getTrainingsSince(since)` con bound UTC — home pide 5 recientes + semana actual, calendario y analytics 12 meses (analytics amplía la ventana si un rango custom pide más atrás). El último resto, `getAllEntrenamientos()` (500 docs de golpe con los gpsPoints dentro), sobrevivía solo por `home_view_legacy`; al eliminarse esa vista quedó sin un solo call site y se ha borrado del repositorio. Para listados nuevos: `getTrainings()` (paginado) o `getTrainingsSince()` (acotado por fecha) — no reintroducir una carga sin límite.
3. ~~**Refactor MVVM de `workout_editor_screen.dart`**~~ — ✅ hecho (26 jul 2026). La lógica vive en `templates/viewmodels/workout_editor_view_model.dart` (composición de la `WorkoutSession`, nombre automático, bloques por defecto, generación por IA y persistencia como sesión planificada); la vista solo renderiza, navega y muestra snackbars. El viewmodel no conoce `BuildContext`: devuelve `SaveResult`/`AiGenerationResult` y decide la vista. Cubierto por `test/features/templates/workout_editor_view_model_test.dart` (19 tests sobre la lógica pura). **No se mergeó la rama `refactor/workout-editor-mvvm`**: llevaba parada desde el 21 jun, main tocó ese fichero en 11 commits desde entonces y la rama reintroducía `initSpeech()` en el `initState` — justo lo que se quitó al pasar a permisos just-in-time. Se rehízo desde main usando la rama solo como referencia de diseño; puede borrarse (⚠️ es local, no está en origin). La colisión `WorkoutType.free` ↔ `continuous` que documentaba esa rama ya no existe: `free` mapea a `gimnasio_fuerza` y el round-trip funciona.
4. **Vistas huérfanas** — ✅ eliminadas (jul 2026). Se borraron con cero referencias verificadas: `session_editor_view.dart` (+ su `session_editor_viewmodel.dart`), `athlete_session_editor_view.dart` (+ su `athlete_session_editor_viewmodel.dart`), `home_view_legacy.dart`, `profile_menu_screen.dart` (huérfana de verdad, cero refs), `analytics_hub_screen_legacy.dart`, `analytics_hub_view.dart`, `edit_profile_picture_view.dart`, `session_planner_view.dart`, `global_challenge_card.dart`. Caso especial resuelto: `GroupRewardsBody` (+ sus widgets privados) se extrajo a `group_rewards_body.dart` y se eliminó el wrapper huérfano `GroupRewardsScreen`; `group_screen.dart` ahora importa el body. ~~Pendiente (header antiguo): `analytics_hub_screen.dart` y `avatar_customizer_view.dart` con `AppBar` de Material~~ — verificado jul 2026: **no queda ni un `AppBar(` en `lib/`**, ambas ya usan cabecera propia. Punto cerrado.

**Cuarta ronda (26 jul 2026) — código muerto *dentro* de ficheros vivos**: la alcanzabilidad por fichero ya estaba limpia (solo 3 muertos: el clúster del editor de avatar legado `avatar_editor_wraper_view` → `avatar_maker_screen` → `avatar_maker_controller`, eliminado; `lib/scripts/generate_test_workouts.dart` se conserva como tooling). El grueso fue lo que el analizador marca como `unused_element`/`unused_field` dentro de pantallas activas: **−920 líneas en `training_start_view.dart`** (el selector "¿Qué entrenamos hoy?" completo y las pestañas antiguas con sus toggles GPS/pulsómetro, superados por `_buildSensors()`), más `training_session_view.dart` y `training_summary_screen.dart`. Se retiraron 6 dependencias directas sin un solo import (`get`, `firebase_storage`, `http`, `image_picker`, `gal`, `path_provider`). Detalle y efectos observados en el CHANGELOG.

⚠️ **Trampa al calcular alcanzabilidad — leer antes del próximo barrido**: los imports relativos se resuelven en el espacio de URIs de `package:`, donde **`lib/` es la raíz y los `..` sobrantes se descartan** (RFC 3986 clampea en la autoridad). Es decir, `'../../../../config/app_theme.dart'` desde `lib/features/admin/views/` apunta a `lib/config/app_theme.dart`, **no** a `<repo>/config/...`. Hay 16 imports así en el repo. Un script que resuelva con `os.path.normpath` sin ese clamp descarta esas aristas y marca ficheros vivos como muertos — le pasó a este barrido con `premium_date_range_picker.dart` (que **sí** está vivo: lo usa `admin_dashboard_tab.dart`, pese a que la nota de la tercera ronda lo da por borrado).

**Tercera ronda (jul 2026) — barrido exhaustivo por grafo de imports**: en vez de auditar a mano se calculó la alcanzabilidad transitiva real desde `main.dart` (BFS sobre el grafo import/export de los 271 `.dart`; sin `part`/`part of` ni imports condicionales en el repo, y Dart no usa reflexión → no alcanzable = código muerto garantizado). Resultado: **44 archivos de `lib/` + 1 test** eliminados, dos subsistemas enteros que nunca se engancharon a `MainShell`: (a) rediseño "Analytics v2" (`analytics/views/tabs/*`, carruseles y detalles de patrones, `pattern_detector`/`series_pattern`/`workout_pattern`, `coach_insight_*`, `pattern_cache`, `analytics_range_selector`), y (b) "dashboard configurable de Home" (`edit_home_view`, `home_config_controller`/`repository`, `home_layout_config`, `configurable_widget_renderer`, `home_flagship_chart`, `stats_carousel`, `history_carousel`, `legacy_bar_chart`), más widgets sueltos muertos (`app_footer` ⚠️ la doc lo daba por activo pero MainShell monta el nav inline, `kpi_card_with_delta`, `group_skeleton_card`, `premium_date_range_picker`, `constants.dart`, `session_block_editor`, `save_as_template_sheet`, `avatar_color_picker`, `avatar_text_styles`, `challenge_result_dialog`, `training_no_gps_detail_view`, filtros/barras de history, `global_challenges_repository`, `home_estadistica_controller`, `target_comparison`, `training_start_view_helpers`). Se conservó `lib/scripts/generate_test_workouts.dart` (tooling manual). **Para futuros barridos, repetir la alcanzabilidad desde `main.dart`, no confiar en greps sueltos ni en esta doc**: `python scripts/dead_code_audit.py` (ficheros no alcanzables + dependencias sin importar; incluye ya el clamp de URIs descrito arriba y avisa si aparece un `part` o un import condicional, que invalidarían la garantía). El código muerto *dentro* de ficheros vivos no lo ve ese script — eso son los `unused_element`/`unused_field` de `flutter analyze`.

**Segunda ronda (jul 2026) — clúster fantasma `AthleteHubView`**: `athlete_hub_view.dart`, `progress_view.dart`, `season_view.dart` (+ sus 4 viewmodels: `athlete_calendar_viewmodel.dart`, `progress_viewmodel.dart`, `season_viewmodel.dart`, `athlete_hub_viewmodel.dart` — este último huérfano incluso dentro del propio clúster) **no estaban enganchados a `MainShell`** — se referenciaban solo entre sí. No era una feature out-of-MVP sin construir: su contenido (récords personales, distribución de intensidad, generar plan IA, calendario/sesiones de la semana) ya estaba **duplicado y superado** por las pantallas reales (`AnalyticsHubScreen`, `HomeView`, `CalendarView`), así que se eliminó el clúster completo en vez de conservarlo. Lección: verificar SIEMPRE una pantalla contra `MainShell._screens` (alcanzable transitivamente) antes de construir o dar por buena una UI ahí.
5. **Pantalla de ajustes** — ✅ rehecha (26 jul 2026). `AccountSettingsView` (1.231 líneas) se sustituyó por `profile/views/settings_view.dart`, con **solo las tres funciones que van a producto**: cambiar nombre, borrar cuenta y GPS por defecto. Se retiraron por decisión de producto: estilo de tarjetas, alarmas por defecto, distancia de marca destacada y **cambiar contraseña** (⚠️ consecuencia: una cuenta de email/contraseña ya no puede cambiarla desde dentro de la app; queda el "olvidé mi contraseña" por email desde el login). Es la pantalla donde vivirá la **gestión de la suscripción** (`docs/MONETIZATION_ARCHITECTURE.md`).

   **Pendiente relacionado — panel de admin** (decidido 26 jul 2026): `admin/views/admin_panel_screen.dart` y sus tabs son legacy; la intención es **sacar esas métricas de la app a un panel web**. No invertir en su UI mientras tanto (por ejemplo, su `GradientBanner` con `accentColor: surfaceOf` sigue el mismo patrón que hacía invisible el de ajustes — arreglado en el widget, pero la pantalla en sí está para irse).

6. **Templates de sesión completa** — `TrainingTemplatesRepository` implementado pero sin UI (pantalla "crear desde plantilla"). No es MVP — solo las plantillas de segmento son MVP actualmente. El switch "Guardar como plantilla" fue eliminado del editor hasta que exista la UI de carga.
7. ~~`_getWeekNumber()` en `home_flagship_chart.dart`~~ — resuelto por borrado: `home_flagship_chart.dart` era parte del "dashboard configurable de Home" nunca enganchado, eliminado en la tercera ronda de purga (ver arriba).
8. **Convención `fecha` (string ISO UTC)** — el esquema se mantiene (migrar a `Timestamp` requeriría backfill). Regla: cualquier query sobre `fecha` debe construir sus bounds con `.toUtc().toIso8601String()`, y cualquier bucketing por día/mes debe hacer `.toLocal()` tras el parse (ver `home_estadistica_repository.dart`).

### ✅ Resuelto (jul 2026) — revisión profunda
- ~~`profile_menu_screen_legacy.dart` duplicaba el menú de perfil~~ — sobrevivía solo porque, a diferencia de `ProfileView` (el tab real), navegaba a sus sub-pantallas con `Navigator.push()` directo en vez de `MainShell.shellKey.navigateTo()` — lo único que funciona al abrirse pusheado encima de Admin/Templates/Grupos. `ProfileView` ahora usa `ShellEmbeddingScope.isEmbedded(context)` (mismo patrón que `templates_list_view.dart`/`avatar_customizer_view.dart`) para elegir `navigateTo()` o `Navigator.push()` según esté embebida en el shell o pusheada standalone. Los 6 call sites repuntados a `ProfileView`; el duplicado eliminado (ver CHANGELOG).
- ~~`ProgressRepository.getPersonalRecords()` escaneaba 500 docs en cada carga~~ (home recreativo + hub atleta). Ahora usa un rollup cacheado en `users/{uid}/settings/personalRecordsRollup`: `PbCelebrationService.checkAfterSave()` llama a `ProgressRepository.updateRollupAfterSave(uid, training)`, que compara solo las series del entreno recién guardado contra el rollup cacheado (sin reescanear el historial) y persiste únicamente si mejora algún récord. La primera lectura de un usuario sin rollup aún hace el escaneo completo una vez y lo guarda; las siguientes son una lectura de un solo doc. No hay borrado de entrenos en la app, así que no hace falta invalidar el rollup por ese lado.
- ~~**Wear OS eliminado**~~ — la app independiente (`wear_os/`, Kotlin/Compose) se retiró del repo por decisión de producto (no era MVP, `DEBUG_SIMULATE` seguía en `true`, y el bypass de auth via `source == "wear_os"` era deuda abierta). También se eliminó `WearAuthService` + `_WearQRScannerPage`, el hook "Conectar reloj" en `account_settings_view.dart`, la dependencia `mobile_scanner` de `pubspec.yaml`, y en `firestore.rules`: el bloque `wear_sessions/{code}` y el bypass de create/update en `trainings` para `source == "wear_os"`. Si se retoma soporte para reloj en el futuro, empezar de cero con Cloud Function + custom token real desde el principio (el bypass nunca llegó a producción segura).
- ~~`firestore.rules` — crear grupos y unirse a retos estaba roto para todo el mundo~~ (bug presente desde el commit `cb7ea42` de abril 2026, descubierto jul 2026). `isSafeWrite()` y dos copias inline usaban `request.resource.data.toString().size() < N` — `.toString()` no existe en el lenguaje de reglas de Firestore; al evaluar una función inexistente, Firestore denegaba la escritura (fail-closed). Verificado con una prueba real (usuario de Auth genuino, no Admin SDK): `create` en `users/{uid}` (sin `.toString()`) → 200 OK; `create` en `groups/{groupId}` (con `.toString()`) → 403 `PERMISSION_DENIED`. Bloqueaba 3 operaciones para el 100% de los usuarios: crear grupo, unirse a un reto de grupo, unirse a un reto global. Fix: se quitó la cláusula `.toString().size() < N` en las 3 reglas, dejando solo el `keys().size() < N` que sí funciona.
- ~~`Firebase.initializeApp()` crasheaba en arranque en Android~~ — descubierto al probar Crashlytics/Analytics en dispositivo real (no lo cubre `flutter analyze`/`flutter test`, solo se ve en runtime). Causa: `firebase_core` 4.10.0 declara `firebase_core_platform_interface: ^7.0.1`, pero ese caret deja que `pub` resuelva la 7.1.0 — que añadió el campo `recaptchaSiteKey` a `CoreFirebaseOptions` (15 campos) sin que el código Java nativo embebido en `firebase_core` 4.10.0 (`GeneratedAndroidFirebaseCore.java`, que sigue serializando solo 14) lo sepa. Resultado: `RangeError: Not in inclusive range 0..13: 14` nada más arrancar, en **todas** las plataformas Android — bug preexistente, no introducido por Crashlytics/Analytics (verificado con A/B: el crash persistía incluso sin esos paquetes). Fix: pin exacto `firebase_core_platform_interface: 7.0.1` en `pubspec.yaml`. Moraleja: los paquetes de Firebase deben resolverse siempre en conjunto — un caret suelto en cualquiera de ellos puede desincronizar el esquema pigeon nativo/Dart sin que el análisis estático lo detecte.
- ~~GPS sin funcionar en entrenos por series~~ — el flujo de series crea un `GPSService` **nuevo por cada serie** (TrainingSessionView se pushea y destruye por serie) y `_processTick` descartaba el tick entero (`return state`) hasta conseguir un fix ≤15 m: con accuracy típica de 15-35 m en el warm-up, series cortas terminaban con distancia ≈ 0 (en continua el warm-up se paga una vez y no se nota). Fix triple en `gps_service.dart`: (1) escalera de inicialización del EKF — fix fino ≤15 m durante los primeros 10 s, luego se acepta ≤35 m (el EKF pondera por accuracy², un anclaje grueso no lo desestabiliza); (2) durante el warm-up ya no se descartan ticks: el podómetro mide distancia y velocidad como dead reckoning (usa la zancada calibrada persistida); (3) `dispose()` ahora libera el `SensorService` — antes se fugaban las suscripciones de acelerómetro/giroscopio/podómetro en cada serie.
- ~~`deleteAccount()` dejaba subcolecciones huérfanas~~ — nueva Cloud Function `deleteUserData` (Admin SDK): `recursiveDelete` de `users/{uid}`, limpieza de artefactos en grupos y retos globales, borrado del Auth user y verificación de sesión reciente (`auth_time` < 10 min). **Desplegada en producción (us-central1, jul 2026).** El cliente (`UserService.deleteAccount`) la llama; conserva fallback al borrado parcial por si la función no estuviera disponible.
- ~~Queries de `fecha` con bounds locales~~ — `home_estadistica_repository`, `group_detail_repository.calculateChallengeProgress` y `training_challenge_sync_service._getTrainingsInPeriod` comparaban strings locales contra valores UTC: los entrenos entre la medianoche local y la UTC quedaban fuera. Bounds ahora en UTC y bucketing con `.toLocal()` (→ convención en deuda #7).
- ~~`TagManager.createTag()` forzaba refresh de token~~ — eliminado el `getIdToken(true)` y los debugPrints; era un workaround de debugging sin efecto en las reglas actuales.
- ~~`TrainingRepository.createTraining()` perdía `fcMedia`/`fcReadings`~~ — el suavizado RDP reconstruía la `Serie` a mano omitiendo los campos de pulsómetro; ahora usa `serie.copyWith(gpsPoints:)`.
- ~~Reset de contraseña roto~~ — `AuthRemote.sendPasswordResetEmail` consultaba `users` por email **sin sesión** (las reglas exigen `isSignedIn()`) → siempre permission-denied. Además era enumeración de cuentas. Eliminada la query previa.
- ~~`SummaryStatsCalculator` usaba la varianza como desviación estándar~~ — faltaba `sqrt()`; el % de consistencia salía ~10× inflado. También se corrigió la desalineación de índices en `percentInTarget` con segmentos sin objetivo.
- ~~`TemporalDataExtractor.sessionPacePerKm` desplazaba splits entre series~~ — restaba `serie.tiempoSec` de un acumulado que aún no lo incluía.
- ~~`AiCoachChatService` reseteaba `previewsGenerated` al normalizar la cuota~~ — ahora usa `copyWith`.
- ~~`GPSService._formatPace` podía renderizar `04:60 /km`~~ — redondeo de segundos antes de descomponer.
- ~~`GPSService.updateSerie()` (deuda #7 anterior)~~ — eliminado junto con más código muerto: `kalman_filter.dart` (el filtro real es `EKF2D`), `exponential_backoff.dart`, `rate_limit_decorator.dart`, `core/utils.dart` (vacío), `entrenamiento_utils.dart` (incluía un cálculo de semana ISO defectuoso sin usar) y `test/widget_test.dart` (vacío, rompía la suite).
- ~~`getAllEntrenamientos(uid)` ignoraba el uid~~ — verificado: pasa `uid` correctamente a `getTrainings(uid: uid)` (training_repository.dart:163)
