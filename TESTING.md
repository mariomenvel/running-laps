# TESTING.md — Tests de Running Laps

> Estado: **186 tests en 27 archivos** (julio 2026). Suite completa: ~5 segundos.

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
├── unit/          # Lógica pura: cálculos, parsers, máquinas de estado (112 tests)
├── features/      # Modelos + repositorios contra Firestore simulado (52 tests)
└── widget/        # Pantallas/widgets montados en entorno simulado (22 tests)
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
| `templates/athlete_session_mapper_test` | 1 | Mapeo WorkoutSession ↔ AthleteSession |
| `training/training_repository_test` | 11 | **Ver sección Firestore simulado** |
| `avatar/avatar_field_consistency_test` | 3 | Config del avatar consistente entre escrituras |

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
- Las pantallas grandes (`training_start_view`, `athlete_hub_view`...) — solo
  indirectamente a través de la lógica extraída que sí está testeada.

---

## Pendientes

1. `AthleteSessionRepository` con inyección + suite (sesiones planificadas del coach).
2. Tests de widget para los componentes core restantes (`NumberPickerField`, `RpeSlider`).
