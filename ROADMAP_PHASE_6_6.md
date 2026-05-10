
---

## PHASE 6.6: Sistema de Tipos de Entrenamiento (En desarrollo — Mayo 2026)

> Base para las Phases 9, 10, 11 y la capa Business. No iniciar Phase 9 sin esta phase completada.

### Documentación generada
- `WORKOUT_SYSTEM.md` — Referencia técnica completa (modelos, Firestore, retrocompatibilidad)
- `WORKOUT_SYSTEM_PRODUCT.md` — Documento de producto para clientes y entrenadores
- `WORKOUT_EDITOR_UX.md` — Especificación UX del editor de bloques
- `ROADMAP_UPDATED.md` — Este documento (actualizado)

### Rama Git
`feature/workout-types` (crear desde `main`)

### Modelos de datos

| Tarea | Status | Detalle |
|---|---|---|
| `WorkoutType` enum | ⏳ | continuous, intervals, fartlek, hills, competition, free |
| `WorkoutBlock` model | ⏳ | role, repetitions, segments |
| `WorkoutSegment` model | ⏳ | type, durationSec, distanceM, recoveryType, target |
| `TargetConfig` model | ⏳ | paceMin, paceMax, zone, rpe, fcMaxPercent |
| `BlockRole` enum | ⏳ | warmup, main, cooldown, custom |
| `SegmentType` enum | ⏳ | interval, recovery |
| `RecoveryType` enum | ⏳ | active, passive |
| `WorkoutModels.kt` (Wear OS) | ⏳ | Espejo Kotlin — requiere adaptación `SeriesTrainingService.kt` |

### Repositorios

| Tarea | Status | Detalle |
|---|---|---|
| `template_repository.dart` — actualizar a nuevo modelo | ⏳ | Retrocompatible con plantillas legacy |
| `planned_session_repository.dart` — soportar `WorkoutSession` | ⏳ | `plannedSessions/{id}` en Firestore |
| Validador `WorkoutSession` | ⏳ | Reglas en `WORKOUT_SYSTEM.md §8` |

### Editor de bloques (UI)

| Tarea | Status | Detalle |
|---|---|---|
| Paso 1: selector de `WorkoutType` (grid 2 cols) | ⏳ | AnimatedSwitcher, no navegación |
| Paso 2: nombre de sesión (TextField con default) | ⏳ | Max 60 chars |
| Paso 3: lista de bloques (warmup + main + cooldown) | ⏳ | Cards drag-reorder |
| Selector de repeticiones por bloque | ⏳ | NumberPickerField, solo en main/custom |
| Bottom sheet editor de segmento | ⏳ | interval / recovery, con TargetConfig |
| Selector de objetivo: pace rango | ⏳ | Dos NumberPickerField (min + seg) × 2 |
| Selector de objetivo: zona FC | ⏳ | Chips horizontales Z1-Z5 |
| Selector de objetivo: RPE | ⏳ | Slider con effortColor(rpe) |
| Vista resumen antes de guardar | ⏳ | Duración y distancia estimadas |
| Toggle "Guardar como plantilla" | ⏳ | Doble escritura plannedSessions + templates |
| AlertDialog al salir con cambios | ⏳ | "¿Salir sin guardar?" |
| Comportamiento específico por tipo | ⏳ | Ver `WORKOUT_EDITOR_UX.md §7` |

### Adaptaciones de plataforma

| Tarea | Status | Detalle |
|---|---|---|
| Wear OS: `WorkoutModels.kt` | ⏳ | Espejo de modelos Dart |
| Wear OS: `SeriesTrainingService.kt` adaptación | ⏳ | `applyBlock()` para iterar repetitions |
| iOS/Android: sin cambios en ejecución activa | ✅ | `TrainingSessionView` no se toca en esta phase |

### Criterios de éxito

- Un atleta puede crear una sesión "5×1000m con calentamiento y vuelta" en menos de 2 minutos.
- La misma sesión se puede guardar como plantilla y reutilizar desde el calendario y desde Wear OS.
- Los entrenamientos legacy (lista plana de series) siguen funcionando sin migración.
- El modelo JSON generado es legible por el Coach IA (Phase 11) sin transformación adicional.

### Dependencias

- **Requiere:** Phase 6.5 (BLE/FC) completada ✅
- **Desbloquea:** Phase 9 (test de umbral), Phase 11 (Coach IA), Phase 12 (Business)
- **No bloquea:** Phase 7 (Wear OS planning), Phase 8 (Apple Watch planning)

