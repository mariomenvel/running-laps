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
| `AppHeader` | `app_header.dart` | Header global: logo izq + avatar dch (stream Firestore). |
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
- `ai_coach_repository.dart` — CRUD Firestore: `users/{uid}/settings/aiCoachProfile` + `aiCoachUsage`

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
| Visión del producto / freemium | `DESIGN.md` |

Guías de trabajo (`CLAUDE.md`, `AI_CONTEXT.md`) — actualizar siempre que cambie arquitectura, modelos, servicios, advertencias o deuda técnica.

---

## Convenciones

- Snackbars: `ModernSnackBar.showSuccess/showError/showWarning(context, msg)`
- `debugPrint()` en lugar de `print()`
- `if (!mounted) return;` tras cualquier `await` en un `State`
- Imports Dart: `dart:` → `flutter/` → `firebase_*` → paquetes externos → locales
- Colores RPE: nunca hardcodear — usar escala automática de `RpeBadge` / `AppColors`
- Números siempre via `NumberPickerField` / `IosPicker`, nunca teclado

---

## Estado iOS

| Funcionalidad | Estado |
|---|---|
| Auth email/contraseña | ✅ OK |
| Google Sign-In | ❌ Crash — pendiente Xcode/logs |
| GPS + Live Activity | ✅ OK |
| App Check | ❌ Omitido (sin Apple Developer) |
| Notificación persistente | ⚠️ Solo barra GPS — `flutter_foreground_task` no funciona en iOS |
| Code signing / Development Team | ❌ No configurado — build falla en Codemagic con "requires a selected Development Team with a Provisioning Profile". Requiere cuenta Apple Developer Program activa + configuración de firma en Codemagic. Bloquea TestFlight. |

---

## Deuda técnica prioritaria

1. **Google Sign-In iOS** — `assertionFailure` en `AppDelegate.configureGoogleSignIn()`
2. **Auth Wear OS** — reemplazar bypass con Cloud Function + custom token
3. **Historial** — limitado a 100 entradas, implementar paginación con cursor
4. **Refactor MVVM de `workout_editor_screen.dart`** — iniciado y pausado en rama `refactor/workout-editor-mvvm` (sin mergear).
5. **Vistas huérfanas** — 10 archivos marcados con `⚠️ HUÉRFANO` en su cabecera pendientes de eliminar tras testing manual: `session_editor_view.dart`, `athlete_session_editor_view.dart`, `home_view_legacy.dart`, `profile_menu_screen.dart` (ojo: la versión **sin** `_legacy` es la huérfana; la activa es `profile_menu_screen_legacy.dart`), `analytics_hub_screen_legacy.dart`, `analytics_hub_view.dart`, `group_rewards_screen.dart`, `edit_profile_picture_view.dart`, `session_planner_view.dart`, `global_challenge_card.dart`.
6. **Templates de sesión completa** — `TrainingTemplatesRepository` implementado pero sin UI (pantalla "crear desde plantilla"). No es MVP — solo las plantillas de segmento son MVP actualmente. El switch "Guardar como plantilla" fue eliminado del editor hasta que exista la UI de carga.
7. **`GPSService.updateSerie()`** — método muerto (`gps_service.dart:191-194`), sin llamadas. `GPSService` se reinstancia por serie (no singleton), así que el número llega correcto vía constructor. Candidato a eliminar.

### ✅ Resuelto (jun 2026)
- ~~`getAllEntrenamientos(uid)` ignoraba el uid~~ — verificado: pasa `uid` correctamente a `getTrainings(uid: uid)` (training_repository.dart:163)
