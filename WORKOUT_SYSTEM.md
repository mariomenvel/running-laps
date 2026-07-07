# WORKOUT_SYSTEM.md — Sistema de Tipos de Entrenamiento
> Running Laps · Versión 1.0 · Mayo 2026
> Referencia técnica para desarrolladores. Lee este documento antes de tocar cualquier archivo relacionado con sesiones, plantillas o el editor de bloques.

---

## 1. Visión general

El sistema tiene **dos modelos de sesión paralelos** con roles distintos:

```
AthleteSession + SessionBlock[]
  ← modelo de Firestore: lo que el Coach IA genera y el calendario almacena
  ← path: users/{uid}/athleteSessions/{id}
  ← archivo: lib/features/athlete/data/athlete_session_model.dart

WorkoutSession + WorkoutBlock[] + WorkoutSegment[] + TargetConfig
  ← modelo del editor: lo que WorkoutEditorScreen usa para editar/visualizar
  ← archivos: lib/features/templates/data/workout_*.dart, target_config.dart
```

`athlete_session_mapper.dart` convierte `AthleteSession → WorkoutSession` al abrir el editor. **Nunca al revés** — al guardar, el editor escribe directamente en `AthleteSession`.

⚠️ **Bug conocido (pendiente):** `_mapCategory()` en el mapper asigna `WorkoutType.free` a `gimnasio_fuerza` y `WorkoutType.continuous` a `regenerativo/rodaje_base/tempo` — categorías distintas que comparten el mismo `WorkoutType`. Ver deuda técnica en CLAUDE.md.

### Jerarquía del modelo editor (WorkoutSession)

```
WorkoutSession        ← la sesión completa
└── WorkoutBlock[]    ← bloques: calentamiento, principal, vuelta a la calma
    └── WorkoutSegment[]  ← esfuerzo + descanso dentro del bloque
        └── TargetConfig  ← objetivo fisiológico del segmento (opcional)
```

---

## 2. Tipos de entrenamiento — WorkoutType

```dart
enum WorkoutType {
  continuous,   // Rodaje, tempo, largo, regenerativo — sin pausas estructuradas
  intervals,    // Series clásicas N×distancia o N×tiempo con recuperación
  fartlek,      // Estructura variable: puede ser uniforme o piramidal
  hills,        // Cuestas — tiene parámetros específicos de pendiente
  competition,  // Carrera oficial o test cronometrado
  free,         // Sin estructura — el usuario corre libremente
}
```

### Parámetros específicos por tipo

| WorkoutType | Parámetros clave | Notas |
|---|---|---|
| `continuous` | duración o distancia, zona/pace objetivo | Sin recuperaciones estructuradas |
| `intervals` | N repeticiones, distancia o tiempo por serie, tipo y duración de recuperación | El bloque principal se repite N veces |
| `fartlek` | Bloques de esfuerzo+descanso no uniformes | `repetitions = 1` en el bloque main; los segmentos varían entre sí |
| `hills` | Longitud de cuesta, pendiente estimada, recuperación bajando | Recuperación es siempre `RecoveryType.active` (trotar bajando) |
| `competition` | Pace plan parcial, objetivo de tiempo, estrategia | Badge especial, color morado en calendario |
| `free` | Ninguno | Solo GPS + FC + RPE al acabar |

---

## 3. Modelo de datos completo

### 3.1 WorkoutSession

Modelo del editor (`WorkoutEditorScreen`). No se persiste directamente en Firestore — se convierte a/desde `AthleteSession` mediante el mapper.

```dart
class WorkoutSession {
  final String id;                    // UUID
  final String title;                 // "Series 5×1000m"
  final String? description;          // Texto libre opcional
  final WorkoutType type;
  final List<WorkoutBlock> blocks;
  final DateTime? scheduledDate;      // null si no está planificada
  final TimeOfDay? scheduledTime;     // hora de la sesión (opcional)
  final String? notes;                // notas de planificación
  final bool isTemplate;              // true = plantilla reutilizable
  final String? templateId;           // referencia si viene de plantilla
}
```

**Nota sobre Firestore:** `WorkoutSession` NO tiene path propio. Lo que se guarda en Firestore es `AthleteSession` (`users/{uid}/athleteSessions/{id}`). Las plantillas se guardan como `TrainingTemplate` en `users/{uid}/templates/{id}` via `TemplatesRepository`.

### 3.2 WorkoutBlock

Un bloque es la unidad de repetición dentro de una sesión.

```dart
class WorkoutBlock {
  final String id;                    // UUID local
  final BlockRole role;               // warmup | main | cooldown | custom
  final int repetitions;              // 1 para calentamiento/vuelta, N para series
  final List<WorkoutSegment> segments;
  final String? label;                // Nombre custom, ej: "Bloque A"
}

enum BlockRole {
  warmup,    // Calentamiento — siempre primero, repetitions siempre = 1
  main,      // Bloque principal — puede repetirse N veces
  cooldown,  // Vuelta a la calma — siempre último, repetitions siempre = 1
  custom,    // Bloque adicional libre (ej: segundo bloque de series)
}
```

**Constraints:**
- Un bloque `warmup` o `cooldown` SIEMPRE tiene `repetitions = 1`.
- Un bloque `main` puede tener `repetitions` de 1 a 99.
- La sesión puede tener 0 bloques `warmup`, 0 bloques `cooldown`, pero siempre al menos 1 bloque `main`.
- El orden de los bloques es significativo: `warmup → main(s) → cooldown`.

### 3.3 WorkoutSegment

Un segmento es cada pieza individual dentro de un bloque: el esfuerzo y su recuperación.

```dart
class WorkoutSegment {
  final String id;
  final SegmentType type;             // interval | recovery
  final int? durationSec;            // segundos — null si es por distancia
  final int? distanceM;              // metros — null si es por tiempo
  final RecoveryType? recoveryType;  // solo si type == recovery
  final TargetConfig? target;
}

enum SegmentType {
  interval,   // El esfuerzo principal
  recovery,   // El descanso entre esfuerzos
}

enum RecoveryType {
  passive,  // Parado o caminando
  active,   // Trotando (siempre en cuestas)
}
```

**Constraints:**
- Un segmento DEBE tener `durationSec` O `distanceM`, pero no ambos como null.
- Un segmento `recovery` puede tener target (ej: "Z1 trotando") o no tenerlo.
- Para `WorkoutType.fartlek`, el bloque main tiene `repetitions = 1` y los segmentos interval/recovery se alternan con duraciones distintas.

### 3.4 TargetConfig

El objetivo fisiológico de un segmento. Todos los campos son opcionales — el usuario puede configurar ninguno, uno o varios.

```dart
class TargetConfig {
  final int? paceMinSecPerKm;    // Límite inferior del rango de pace (seg/km)
  final int? paceMaxSecPerKm;    // Límite superior del rango de pace (seg/km)
  final HeartRateZone? zone;     // Z1 | Z2 | Z3 | Z4 | Z5
  final int? rpe;                // 1–10
  final int? fcMaxPercent;       // % de FCmáx (para usuarios sin zonas individualizadas)
}

enum HeartRateZone { z1, z2, z3, z4, z5 }
```

**Reglas de visualización:**
- Si hay `paceMinSecPerKm` y `paceMaxSecPerKm`, mostrar como rango: "3:55–4:05/km"
- Si solo hay `paceMinSecPerKm` (= `paceMaxSecPerKm`), mostrar como exacto: "4:00/km"
- Si hay `zone`, mostrar el color de zona correspondiente (ver COLOR_SYSTEM.md)
- Si hay `rpe`, usar `AppColors.effortColor(rpe)`
- La prioridad de visualización durante la sesión activa: pace > zone > rpe

---

## 4. Esquema Firestore

### Sesión planificada
```json
{
  "id": "uuid",
  "title": "Series 5×1000m",
  "description": "VO2max en pista",
  "type": "intervals",
  "scheduledDate": "2026-05-15T00:00:00.000Z",
  "isTemplate": false,
  "blocks": [
    {
      "id": "uuid",
      "role": "warmup",
      "repetitions": 1,
      "label": null,
      "segments": [
        {
          "id": "uuid",
          "type": "interval",
          "durationSec": 900,
          "distanceM": null,
          "recoveryType": null,
          "target": { "zone": "z1" }
        }
      ]
    },
    {
      "id": "uuid",
      "role": "main",
      "repetitions": 5,
      "label": null,
      "segments": [
        {
          "id": "uuid",
          "type": "interval",
          "durationSec": null,
          "distanceM": 1000,
          "recoveryType": null,
          "target": {
            "paceMinSecPerKm": 280,
            "paceMaxSecPerKm": 290,
            "zone": "z4",
            "rpe": 8,
            "fcMaxPercent": null
          }
        },
        {
          "id": "uuid",
          "type": "recovery",
          "durationSec": 90,
          "distanceM": null,
          "recoveryType": "active",
          "target": { "zone": "z1" }
        }
      ]
    },
    {
      "id": "uuid",
      "role": "cooldown",
      "repetitions": 1,
      "label": null,
      "segments": [
        {
          "id": "uuid",
          "type": "interval",
          "durationSec": 600,
          "distanceM": null,
          "recoveryType": null,
          "target": { "zone": "z1" }
        }
      ]
    }
  ]
}
```

---

## 5. Ejemplos de sesiones reales en el modelo

### 5.1 Rodaje base 45 minutos (continuous)

```
WorkoutSession(type: continuous)
└── WorkoutBlock(role: main, repetitions: 1)
    └── WorkoutSegment(type: interval, durationSec: 2700, target: TargetConfig(zone: z2))
```

Sin calentamiento ni vuelta estructurada — el usuario corre 45 minutos en Z2.

### 5.2 Series 5×1000m (intervals)

```
WorkoutSession(type: intervals)
├── WorkoutBlock(role: warmup, repetitions: 1)
│   └── WorkoutSegment(type: interval, durationSec: 900, target: TargetConfig(zone: z1))
│
├── WorkoutBlock(role: main, repetitions: 5)
│   ├── WorkoutSegment(type: interval, distanceM: 1000, target: TargetConfig(paceMin: 280, paceMax: 290, zone: z4))
│   └── WorkoutSegment(type: recovery, durationSec: 90, recoveryType: active, target: TargetConfig(zone: z1))
│
└── WorkoutBlock(role: cooldown, repetitions: 1)
    └── WorkoutSegment(type: interval, durationSec: 600, target: TargetConfig(zone: z1))
```

El bloque main se repite 5 veces: 1000m esfuerzo + 90s trote.

### 5.3 Fartlek piramidal 5'-4'-3'-2'-1' (fartlek)

```
WorkoutSession(type: fartlek)
├── WorkoutBlock(role: warmup, repetitions: 1)
│   └── WorkoutSegment(type: interval, durationSec: 600, target: TargetConfig(zone: z1))
│
├── WorkoutBlock(role: main, repetitions: 1)   ← no se repite como bloque
│   ├── WorkoutSegment(type: interval, durationSec: 300, target: TargetConfig(rpe: 7))
│   ├── WorkoutSegment(type: recovery, durationSec: 120, recoveryType: active)
│   ├── WorkoutSegment(type: interval, durationSec: 240, target: TargetConfig(rpe: 7))
│   ├── WorkoutSegment(type: recovery, durationSec: 120, recoveryType: active)
│   ├── WorkoutSegment(type: interval, durationSec: 180, target: TargetConfig(rpe: 7))
│   ├── WorkoutSegment(type: recovery, durationSec: 90, recoveryType: active)
│   ├── WorkoutSegment(type: interval, durationSec: 120, target: TargetConfig(rpe: 8))
│   ├── WorkoutSegment(type: recovery, durationSec: 60, recoveryType: active)
│   ├── WorkoutSegment(type: interval, durationSec: 60, target: TargetConfig(rpe: 9))
│   └── WorkoutSegment(type: recovery, durationSec: 60, recoveryType: active)
│
└── WorkoutBlock(role: cooldown, repetitions: 1)
    └── WorkoutSegment(type: interval, durationSec: 600, target: TargetConfig(zone: z1))
```

### 5.4 Cuestas 8×100m (hills)

```
WorkoutSession(type: hills)
├── WorkoutBlock(role: warmup, repetitions: 1)
│   └── WorkoutSegment(type: interval, durationSec: 900, target: TargetConfig(zone: z1))
│
├── WorkoutBlock(role: main, repetitions: 8)
│   ├── WorkoutSegment(type: interval, distanceM: 100, target: TargetConfig(rpe: 8, zone: z4))
│   └── WorkoutSegment(type: recovery, distanceM: 100, recoveryType: active)  ← bajando
│
└── WorkoutBlock(role: cooldown, repetitions: 1)
    └── WorkoutSegment(type: interval, durationSec: 600, target: TargetConfig(zone: z1))
```

---

## 6. Retrocompatibilidad — mapeo de legacy

Los entrenamientos guardados antes de este modelo (lista plana de series en `Entrenamiento.series`) se mapean así para visualización:

```dart
WorkoutSession(
  type: WorkoutType.intervals,
  blocks: [
    WorkoutBlock(
      role: BlockRole.main,
      repetitions: entrenamiento.series.length,
      segments: [
        WorkoutSegment(
          type: SegmentType.interval,
          durationSec: serie.tiempoSec.toInt(),
          distanceM: serie.distanciaM,
        ),
        if (serie.descansoSec > 0)
          WorkoutSegment(
            type: SegmentType.recovery,
            durationSec: serie.descansoSec,
          ),
      ],
    ),
  ],
)
```

**Importante:** Este mapeo es solo para visualización. No migrar datos legacy en Firestore — conviven los dos modelos.

---

## 7. Impacto en plataformas

| Cambio | Android | iOS | Web | Wear OS |
|---|---|---|---|---|
| Modelos Dart nuevos | ✅ Automático | ✅ Automático | ✅ Automático | ⚠️ Requiere modelos Kotlin espejo en `TemplateModels.kt` |
| Editor de bloques | ✅ | ✅ | ✅ | ❌ No aplica (solo ejecución) |
| Ejecución sesión estructurada | ✅ | ✅ | ❌ Sin GPS/BLE | ✅ `SeriesTrainingService.kt` requiere adaptación |
| Visualización en historial | ✅ | ✅ | ✅ | ❌ No aplica |

**Wear OS — deuda técnica conocida:**
`SeriesTrainingService.kt` actualmente ejecuta bloques como lista plana. Al implementar el nuevo modelo habrá que adaptar `applyBlock()` para iterar `WorkoutBlock.repetitions` y alternar `interval`/`recovery` dentro del bloque. Documentar como tarea en el momento de implementar.

---

## 8. Reglas de validación

Antes de guardar cualquier `WorkoutSession` en Firestore, validar:

- `blocks` no puede estar vacío
- Al menos un bloque con `role == main`
- Cada `WorkoutSegment` tiene `durationSec != null || distanceM != null`
- `repetitions >= 1` en todos los bloques
- `warmup` y `cooldown` tienen `repetitions == 1`
- `paceMinSecPerKm <= paceMaxSecPerKm` si ambos existen en `TargetConfig`
- `rpe` entre 1 y 10 si existe
- `fcMaxPercent` entre 1 y 100 si existe

---

## 9. Archivos implementados ✅

```
lib/features/templates/data/
├── workout_session.dart        ← WorkoutSession, WorkoutType ✅
├── workout_block.dart          ← WorkoutBlock, BlockRole ✅
├── workout_segment.dart        ← WorkoutSegment, SegmentType, RecoveryType ✅
├── target_config.dart          ← TargetConfig, HeartRateZone ✅
├── athlete_session_mapper.dart ← AthleteSession ↔ WorkoutSession ✅
├── template_models.dart        ← TrainingTemplate, TemplateBlock (modelo legacy plantillas)
├── saved_block.dart            ← bloques guardados reutilizables
├── saved_blocks_repository.dart
└── templates_repository.dart

lib/features/athlete/data/
├── athlete_session_model.dart  ← AthleteSession, SessionBlock, SessionBlockType ✅
└── athlete_session_repository.dart ← CRUD Firestore athleteSessions ✅
```

**Pendiente (Wear OS):**
`SeriesTrainingService.kt` ejecuta bloques como lista plana. Al implementar sesiones estructuradas hay que adaptar `applyBlock()` para iterar `WorkoutBlock.repetitions` y alternar interval/recovery.

---

## 10. Relación con el Coach IA (Premium)

La IA genera sesiones en formato `AthleteSession` con `SessionBlock[]` y las escribe en `users/{uid}/athleteSessions/`. El atleta las ve en el calendario sin diferencia visual respecto a las planificadas manualmente. Cuando el usuario abre el editor, el mapper convierte `AthleteSession → WorkoutSession` para edición.

Ver `PREMIUM_AI_COACH.md` para el detalle del sistema IA.

---

## 11. Completar sesión planificada manualmente ✅ implementado

Archivo: `lib/features/training/views/complete_session_manually_view.dart` (`CompleteSessionManuallyView`).

Caso de uso: el atleta ejecuta la sesión fuera de la app (pista con cronómetro, cinta, etc.) y quiere registrarla contra el plan sin usar GPS en vivo.

- **Formulario pre-estructurado** desde `AthleteSession.blocks` — nunca un formulario en blanco. Por cada `SessionBlock`:
  - `SessionBlockType.series` → una fila por repetición (`reps`), pre-rellenada con `distanceM` del bloque; tiempo y RPE se introducen a mano.
  - `continuousTime` / `continuousDistance` → una única fila (mismo patrón).
  - Calentamiento/vuelta a la calma: toggle on/off (default ON) que usa la duración/distancia del plan tal cual — no son editables campo a campo.
- **Filas sin tiempo introducido (tiempoSec == 0) se descartan** al guardar — no se crean como `Serie`. El coach ve la desviación real (menos series de las planificadas), no un dato falso.
- **RPE**: opcional por fila; si ninguna fila tiene RPE, el campo "RPE global" pasa a ser obligatorio. Si alguna fila sí lo tiene, se calcula la media automáticamente como valor inicial del RPE global (editable).
- **Pipeline de guardado — idéntico al flujo GPS** (`training_summary_screen.dart`): `TrainingRepository().createTraining()` → `AthleteSessionRepository().markAsCompleted(uid, sessionId, trainingId)` → `HomeViewModel.needsReload++` / `HistoryController.needsReload++` → `AiCoachSessionAnalysisService().generateAnalysis(...)` fire-and-forget (sin `await`).
- `plannedComparison` se omite intencionadamente: hoy solo lo calcula el flujo GPS (`workout_execution_screen.dart` → consumido en `training_summary_screen.dart`), y no existe un builder reutilizable en el modelo. El training queda igualmente vinculado a la `AthleteSession`, así que el coach recibe contexto planificado vs ejecutado en su propio análisis post-sesión.
- Tags: mapeo local `_tagForCategory()` (categoría → tag predefinida más cercana). No existe una función de mapeo compartida en el flujo GPS — allí el usuario elige las etiquetas manualmente via chips en `TrainingSummaryScreen`.
- **Guard de fecha**: solo se ofrece la entrada si `status == planned` y la fecha es hoy o anterior (`athleteSessionCanCompleteManually()`, ignora la hora). Nunca aparece para sesiones futuras.
- **Puntos de entrada — un único camino unificado**: card "SESIÓN DE HOY" del Home (`home_view.dart`), detalle de sesión del calendario (`calendar_view.dart` → `_buildSessionCard`), y el botón "Rellenar manual" de `TrainingStartView` (`_buildTodaySessionCard`, sesión de hoy detectada automáticamente) — los tres navegan a `CompleteSessionManuallyView`. Ya no existen dos conceptos distintos de "completar manual": el botón de `TrainingStartView` dejó de abrir el diálogo de nombre+tags con `_vm.series` (normalmente vacío en ese punto) y ahora abre el mismo formulario pre-estructurado desde los bloques planificados.

---

*Documento creado: Mayo 2026. Actualizar al añadir nuevos WorkoutType o campos en los modelos.*
