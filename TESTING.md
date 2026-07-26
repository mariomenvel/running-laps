# TESTING.md — Tests de Running Laps

> Estado: **318 tests en 40 archivos** (26 jul 2026). Suite completa: ~20 segundos.

---

## Qué es un test aquí

Cada test ejecuta una función de la app **con datos inventados** y comprueba que el
resultado es el esperado. Ejemplo real de la suite: *"2 series de 1000 m en 300 s →
el ritmo medio debe ser exactamente 5:00/km"*. Si un cambio futuro rompe ese
cálculo, el test falla y lo delata antes de llegar a ningún usuario.

Los tests **no** abren la app, **no** usan GPS real y **no** tocan el Firebase real.
Son código puro corriendo en memoria.

---

## Cómo ejecutarlos

```bash
flutter test                                        # toda la suite (~5 s)
flutter test test/unit/vdot_calculator_test.dart    # un archivo
flutter test --name "RDP"                           # tests cuyo nombre contenga "RDP"
```

## Cuándo se ejecutan

Solo en dos momentos — nunca solos, nunca en el móvil, nunca en producción:

1. **En local**, al lanzar `flutter test` (obligatorio antes de commitear cambios de lógica).
2. **En GitHub, en cada push o PR a `main`** — el CI ([.github/workflows/ci.yml](.github/workflows/ci.yml))
   monta un runner limpio con Flutter 3.41.1 y ejecuta en orden:
   `flutter pub get` → `flutter analyze` → `test/unit/` → `test/features/` → `test/widget/`.
   El ✅/❌ junto a cada commit en GitHub es el resultado de esto.

⚠️ Si se crea una carpeta de tests nueva fuera de `unit/`, `features/` o `widget/`,
añadir su paso correspondiente al ci.yml — si no, solo correrá en local.

---

## Estructura

```
test/
├── unit/          # Lógica pura: cálculos, parsers, máquinas de estado (128 tests)
├── features/      # Modelos + repositorios contra Firestore simulado (86 tests)
└── widget/        # Pantallas/widgets montados en entorno simulado (28 tests)
```

---

## Inventario de suites

### Lógica del Coach IA (`test/unit/`)

| Archivo | Tests | Qué protege |
|---|---|---|
| `vdot_calculator_test` | 10 | VDOT desde marcas (5K/10K...), paces por zona coherentes, clamps 30-85 |
| `pb_detector_test` | 8 | Detección de marcas personales con interpolación ±3% |
| `session_generator_test` | 5 | Sesiones generadas con reps/distancias sensatas por nivel, tope de 12 reps |
| `ai_coach_prompt_builder_test` | 4 | El prompt del plan semanal incluye el contexto del atleta |
| `ai_coach/weekly_planner_days_test` (en `test/features/`) | 12 | El reparto del plan por días, que es la promesa concreta del Coach ("solo te planifico los días que dijiste"): normalización 0..6 → 1..7 (perfiles antiguos con 0 = domingo), días factibles descartando los ya pasados, reparto por defecto si el perfil no dice días, reubicación de sesiones a días permitidos sin duplicar día, respeto de los días ya ocupados, y descarte de la sesión sobrante cuando no quedan días |
| `ai_coach/weekly_state_test` (en `test/features/`) | 8 | Lo que el Coach ve de tu semana: filtrado por semana con límites inclusivos, adherencia (y 1.0 sin sesiones planificadas, no división por cero), volumen, RPE medio ignorando entrenos sin series, ATL/CTL/TSB (una semana dura deja TSB negativo) y el centinela 999 de "nunca ha entrenado" |
| `ai_coach/chat_quota_test` (en `test/features/`) | 5 | Cuota semanal del chat: la crea si no existe, resetea el contador al cambiar de semana, respeta la de la semana en curso, normaliza un límite antiguo **sin perder** `messagesUsed` ni `previewsGenerated`, y resetea si el periodo guardado está en el futuro (reloj mal puesto) |

### Cálculos de entrenamiento (`test/unit/`)

| Archivo | Tests | Qué protege |
|---|---|---|
| `summary_stats_calculator_test` | 10 | Consistencia de series (desviación estándar, no varianza — regresión jul 2026), mejor serie, % en objetivo con segmentos sin target, fartlek/cuestas |
| `temporal_data_extractor_test` | 5 | Pace por tramo desde GPS, splits por km que cruzan series (regresión jul 2026) |
| `training_analysis_service_test` | 4 | Mejores parciales (1K, 2K...) por ventana deslizante; no muta la lista del caller |
| `training_load_service_test` | 9 | TRIMP (Banister) vs proxy por categoría, ajuste por RPE, nextRace tolera fechas corruptas (regresión) |
| `zones_service_test` | 7 | FCmáx efectiva (manual / 220-edad), límites contiguos de las 5 zonas |
| `ritmo_null_test` | 7 | Series/entrenos sin distancia devuelven ritmo null en vez de crashear (regresión) |

### GPS (`test/unit/`)

| Archivo | Tests | Qué protege |
|---|---|---|
| `gps_ekf_test` | 6 | Escalera de inicialización del EKF (15 m → 35 m tras 10 s — el fix del GPS en series, jul 2026), convergencia del filtro, clamps de velocidad |
| `rdp_smoother_test` | 4 | El suavizado de trazas conserva extremos y curvas, colapsa rectas |

### Ejecución de sesión (`test/unit/`)

| Archivo | Tests | Qué protege |
|---|---|---|
| `workout_execution_controller_test` | 6 | Máquina de estados warmup→main→cooldown→done, reps por bloque, finishEarly, params de la rep actual |
| `notification_schedule_test` | 8 | Cuándo se programa cada aviso: próxima ocurrencia de un día de la semana a una hora (hoy si aún no ha llegado, semana siguiente si ya pasó — programar en el pasado hace que Android la dispare al instante), y el aviso "entreno en 1 hora", que devuelve null si esa hora ya pasó y cruza bien la medianoche en sesiones de madrugada |
| `session_recovery_service_test` | 5 | Recuperar sesión interrumpida, descartar >24 h, JSON corrupto limpia la clave |

### Retos de grupos (`test/unit/`)

| Archivo | Tests | Qué protege |
|---|---|---|
| `challenge_ranking_helper_test` | 5 | Orden de ranking por métrica (menor pace gana, etc.) |
| `earliest_completion_test` | 4 | ChallengeCalculator: momento exacto de completar el objetivo |
| `period_helper_test` | 8 | Claves de periodo (semana ISO, mes) de los retos |

### Modelos y repositorios (`test/features/`)

| Archivo | Tests | Qué protege |
|---|---|---|
| `templates/workout_models_test` | 27 | Serialización toMap/fromMap de WorkoutSession/Block/Segment sin perder campos, asserts de integridad |
| `templates/workout_repository_test` | 10 | CRUD de plantillas contra Firestore simulado |
| `templates/athlete_session_mapper_test` | 1 | Round-trip del **tipo** de sesión (WorkoutType ↔ category) |
| `templates/athlete_session_blocks_test` | 9 | Round-trip del **contenido**: repeticiones, distancia y descanso de un bloque de series; minutos → segundos en bloques por tiempo; calentamiento y vuelta a la calma como bloques propios con `repetitions: 1`; sin descanso no se inventa recuperación; una sesión sin bloques sigue cumpliendo el invariante de "al menos un main"; y el viaje completo editor → Firestore → editor de un 6×1km |
| `templates/workout_editor_view_model_test` | 19 | Lógica del editor tras el refactor MVVM: bloques por defecto por tipo, nombre automático (5×1km, 8×400m, 6×1'30", Rodaje 10km) vs. nombre escrito a mano, `buildSession` (id/plantilla conservados, notas en blanco → null, sin tipo → sesión libre), `hasChanges` y el guardado bloqueado sin tipo ni bloques. Solo cubre lo que no toca Firebase — la persistencia de `save()` queda fuera |
| `training/training_repository_test` | 16 | **Ver sección Firestore simulado**. Incluye 5 tests del reparto de trazas GPS: el documento del entrenamiento no las lleva, `track/data` sí (con `seriesGps` indexado), `withTrack()` las recupera, y compatibilidad con el formato antiguo (traza embebida) tanto al leer como al guardar con `overwriteTraining` |
| `avatar/avatar_field_consistency_test` | 3 | Config del avatar consistente entre escrituras |
| `analytics/analytics_view_model_test` | 9 | Los números que se leen en Analytics: corte de intensidad en RPE 7, récord por distancia (se queda el mejor, uno peor no lo pisa), semanas activas ≠ nº de entrenos, media de sesiones sobre las semanas del rango, carga aguda solo de los últimos 7 días, ACWR finito sin crónica, y ritmo medio **ponderado por distancia** (no la media de los ritmos) |
| `history/history_filters_test` | 9 | Filtros del historial: últimos 7 días, tiradas largas (>10 km, los 10 km exactos NO cuentan), alta intensidad (RPE>7), rango personalizado con extremos completos y con prioridad sobre el predefinido, búsqueda sin distinguir mayúsculas, etiquetas que suman, y combinación de varios filtros |
| `athlete/progress_rollup_test` | 7 | Récords personales: `updateRollupAfterSave` mejora el récord solo si el ritmo es mejor, no toca el rollup si es peor, respeta las ventanas de distancia estándar (950 m cuenta como 1000, 700 m no cuenta), ignora series sin distancia o sin tiempo, no hace nada con un entreno sin id, y crea el rollup escaneando el historial la primera vez |
| `architecture_test` | 9 | **Reglas de CLAUDE.md, no comportamiento**: ninguna vista instancia `FirebaseFirestore` ni `FirebaseAuth`, nadie importa `dart:html`, los snackbars son siempre `ModernSnackBar`, nadie usa `AppBar`, `showDatePicker` ni colores de Material sueltos, y no queda ningún `print()` en `lib/`. Escanea los ficheros de `lib/features/**/views/` y falla diciendo qué fichero y a qué servicio llevar el acceso. Incluye un test de cordura (que la lista de vistas no esté vacía) para que un cambio de carpetas no lo deje pasando en falso |

### Pantallas (`test/widget/`)

| Archivo | Tests | Qué protege |
|---|---|---|
| `core/app_confirm_dialog_test` | 8 | El diálogo estándar renderiza, confirma/cancela, variante destructiva |
| `core/app_date_picker_test` | 6 | El selector de fecha clampea el rango, devuelve fecha o null |
| `core/app_bottom_sheet_test` | 5 | El contenedor estándar de sheets renderiza su contenido |
| `auth/auth_navigation_test` | 3 | Contratos de navegación del flujo de verificación de email |

---

## Tests contra Firestore simulado (`fake_cloud_firestore`)

Los tests de repositorio necesitan una base de datos. En vez de tocar el Firebase
real (imposible y peligroso en tests), usan **`fake_cloud_firestore`**: una
imitación de Firestore que vive en la RAM del test. Cada test arranca con una BD
vacía, el repositorio escribe/lee contra ella con la misma API que en producción,
y al terminar desaparece. **Cero conexión con el Firebase real, cero coste.**

### El patrón (usarlo para cualquier repo nuevo)

```dart
// 1. El repo debe aceptar inyección con defaults de producción:
class TrainingRepository {
  TrainingRepository({FirebaseFirestore? firestore, ...})
      : _db = firestore ?? FirebaseFirestore.instance;

  /// Sobrescribible en tests — evita necesitar Firebase Auth real.
  String? get currentUserId => FirebaseAuth.instance.currentUser?.uid;
}

// 2. En el test, subclase con fake + uid fijo:
class _TestableRepo extends TrainingRepository {
  _TestableRepo({required FakeFirebaseFirestore firestore})
      : super(firestore: firestore);

  @override
  String? get currentUserId => 'test-uid-123';
}
```

Colaboradores perezosos: `AiCoachChatService` y `AiCoachRepository` construyen
sus dependencias la primera vez que se usan, no en el constructor. Sin eso,
instanciar el servicio en un test levantaba media app y pedía Firebase real.
Mismo criterio que `HomeEstadisticaRepository`. **Al añadir un servicio nuevo,
seguirlo**: un constructor no debería exigir Firebase inicializado.

Repos ya adaptados: `TrainingTemplatesRepository`, `TrainingRepository`,
`ChallengesRepository`, `TrainingChallengeSyncService`, `ChallengeFinalizeService`,
`InvitesRepository`, `AuthRemote`. Pendientes de inyección: `AthleteSessionRepository`
(usa getter fijo), `HomeEstadisticaRepository` (singleton), `TagManager`, `AiCoachRepository`.

### Qué cubre `training_repository_test` (el repo principal)

- `createTraining` persiste el doc con campos derivados y **fecha en UTC** (convención del proyecto).
- Los contadores agregados del usuario (`totalSessions`, `totalKm`, `totalTimeMinutes`) se incrementan.
- **Regresión jul 2026**: una serie con >10 puntos GPS conserva `fcMedia`/`fcReadings`
  tras el suavizado RDP (el bug perdía los datos del pulsómetro al guardar).
- El rate limit de guardado (3 s) bloquea el segundo guardado inmediato.
- Paginación: páginas de `pageSize`, `hasMore`, sin duplicados, orden desc por fecha.
- `updateTrainingTags`, `getTrainingById`, `updateTrainingAnalysis`.

### Peculiaridades del fake (aprendidas a base de golpes)

- **El orden de encadenado importa**: `query.limit(n).startAfterDocument(doc)` ignora
  el cursor en el fake (en Firestore real da igual). Aplicar siempre `limit()` DESPUÉS
  del cursor — así está escrito `getTrainings`.
- **`RateLimitService` es singleton** y sobrevive entre tests: limpiar en `setUp` con
  `RateLimitService().clearKey('training:save')`.
- El fake **no valida las reglas de seguridad** (`firestore.rules`) — un test verde no
  garantiza que las reglas permitan la operación en producción.
- `FieldValue.increment` y `serverTimestamp` funcionan; queries complejas exóticas
  pueden diferir del real — ante un comportamiento raro, sospechar del fake primero.

---

## Convenciones para escribir tests nuevos

- **Nombres en español** describiendo el comportamiento: `'el suavizado RDP conserva fcMedia'`,
  no `'test1'`.
- Un test de **regresión** por cada bug corregido, con un comentario que explique el bug
  original (`// Regresión: antes se restaba serie.tiempoSec de un acumulado...`).
- Lógica pura → `test/unit/`. Repos con Firestore → `test/features/<feature>/`.
  Widgets → `test/widget/`.
- Helpers de construcción arriba del archivo (`makeSerie(...)`, `makeTraining(...)`)
  con defaults razonables y solo los campos relevantes como parámetros.
- `SharedPreferences.setMockInitialValues({})` para servicios que usan prefs
  (ver `session_recovery_service_test`).
- Para GPS sintético: pasos de `0.0009°` de latitud ≈ 100 m (patrón usado en
  `temporal_data_extractor_test`, `training_analysis_service_test`, `rdp_smoother_test`).

---

## Qué NO cubren los tests

Para calibrar la confianza — un CI verde **no** valida:

- La app corriendo de verdad: GPS con satélites, sensores, permisos, la UI completa.
  → **La prueba manual en dispositivo es insustituible** (flujo FAB → series → guardar → historial).
- El Firebase real: reglas de seguridad, Cloud Functions desplegadas (`deleteUserData`,
  `callOpenRouter`), App Check.
- Las llamadas reales al LLM (OpenRouter) — los tests del coach validan la construcción
  de prompts y el parseo, no las respuestas del modelo.
- Las pantallas grandes (`training_start_view`, `analytics_hub_screen`...) — solo
  indirectamente a través de la lógica extraída que sí está testeada.

---

## Pendientes

1. `AthleteSessionRepository` con inyección + suite (sesiones planificadas del coach).
2. Tests de widget para los componentes core restantes (`NumberPickerField`, `RpeSlider`).
