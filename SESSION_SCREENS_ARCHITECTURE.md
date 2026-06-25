# Pantallas de sesión por tipo — Arquitectura
> Estado: **implementada** (Fases 1-4 del roadmap original completadas)

---

## Visión general

El flujo de ejecución de un entrenamiento se adapta visualmente al tipo de sesión y al contexto del bloque actual. Cada tipo tiene su propia "personalidad visual" (paleta, tema, énfasis en métricas relevantes).

**Pantalla principal de ejecución:** `WorkoutExecutionScreen` (`workout_execution_screen.dart`)
- Recibe `WorkoutSession`, `AthleteSession?` (si viene del calendario), `gpsActivo`, `fcMax`
- Orquesta el flujo: PRE → TRANS → INTRA/REST → SUMMARY
- Usa `WorkoutExecutionController` para estado de ejecución

**`training_session_view.dart`** — sigue existiendo, se usa para entrenamientos libres / legacy sin `WorkoutSession` estructurada.

---

## Principio rector

La pantalla se decide por **el bloque actual + tipo de sesión padre**, no solo por el tipo de sesión:

- `warmup` / `cooldown` de cualquier sesión → estética `continuous` (rodaje)
- Bloque `main` → estética según `WorkoutType` de la sesión
- Segmento `recovery` → `RestScreen` unificada

---

## Decision tree — `SessionScreenRouter`

```dart
// session_screen_router.dart
SessionScreenKind get kind {
  if (currentSegment?.type == SegmentType.recovery) → rest
  if (block.role == warmup || cooldown)             → continuous
  switch (session.type):
    intervals   → interval
    fartlek     → fartlek
    hills       → hills
    competition → competition
    continuous  → continuous
    free        → free
}
```

---

## Etapas universales

| Etapa | Descripción | Estado |
|---|---|---|
| PRE | Preparación: GPS, BLE, ajustes, info del bloque | ✅ `pre_execution_screen.dart` (unificada) |
| TRANS | Transición entre bloques (warmup→main, etc.) | ✅ `block_transition_screen.dart` |
| INTRA | Durante el esfuerzo | ✅ 6 pantallas por tipo |
| REST | Descanso entre series | ✅ `rest_screen.dart` (unificada) |
| SUMMARY | Resumen final del entreno | ✅ `training_summary_screen.dart` + cards por tipo |

---

## Caracterización por tipo

### INTERVALS (Series)
- **Paleta:** ocre/terracota (tartán), acentos rojos
- **Métricas hero:** tiempo de serie + pace vs objetivo
- **REST:** sí — RestScreen unificada con cuenta atrás
- **Especial:** "Serie X/Y" siempre visible

### CONTINUOUS (Rodaje)
- **Paleta:** verde-azul suave (calma, constancia)
- **Métricas hero:** distancia + progreso
- **REST:** no
- **Especial:** % tiempo en zona objetivo en summary

### FARTLEK
- **Paleta DUAL:** modo rápido (naranja/rojo) ↔ modo suave (azul tranquilo)
- **Métricas hero:** tiempo del tramo + FC protagonista
- **REST:** no (los tramos suaves SON recuperación integrada en los segmentos)
- **Especial:** sin pace fijo, todo por FC y sensación

### HILLS (Cuestas)
- **Paleta:** marrón/tierra + verde montaña
- **Métricas hero:** tiempo de subida + FC + RPE (sin pace)
- **REST:** sí — bajada trotando (`RecoveryType.active`)
- **Especial:** botón "Listo para subir" como continuar

### COMPETITION
- **Paleta:** dorado/negro premium + rojo de meta
- **Métricas hero:** distancia + tiempo + proyección de tiempo final
- **REST:** no
- **Especial:** parciales por kilómetro visibles, detección de marca personal

### FREE (Libre)
- **Paleta:** neutra, minimalista
- **Métricas hero:** distancia + tiempo + pace, sin comparativas
- **REST:** no
- **Especial:** sin objetivos, sin badges, sin presión

---

## Archivos implementados

```
lib/features/training/views/
├── workout_execution_screen.dart         ← pantalla principal de ejecución ✅
├── training_session_view.dart            ← legacy / entrenamientos libres ✅
├── training_start_view.dart              ← pre-inicio (GPS, tipo, plantilla) ✅
├── pre_execution_screen.dart             ← PRE unificada para todos los tipos ✅
├── block_transition_screen.dart          ← TRANS entre bloques ✅
├── training_summary_screen.dart          ← SUMMARY con cards por tipo ✅
├── manual_training_view.dart             ← entrada manual sin GPS ✅
│
└── session_screens/
    ├── session_screen_router.dart        ← decisor de pantalla ✅
    │
    ├── shared/
    │   ├── session_theme.dart            ← SessionTheme + 6 subclases ✅
    │   ├── session_layout.dart           ← layout base reutilizable ✅
    │   └── metrics/
    │       ├── pace_widget.dart          ✅
    │       ├── fc_widget.dart            ✅
    │       ├── distance_widget.dart      ✅
    │       ├── time_widget.dart          ✅
    │       ├── progress_bar.dart         ✅
    │       └── target_comparison.dart    ✅
    │
    ├── intra/                            ← pantallas INTRA por tipo
    │   ├── interval_screen.dart          ✅
    │   ├── continuous_screen.dart        ✅
    │   ├── fartlek_screen.dart           ✅
    │   ├── hills_screen.dart             ✅
    │   ├── competition_screen.dart       ✅
    │   └── free_screen.dart              ✅
    │
    ├── rest/
    │   └── rest_screen.dart              ← REST unificada (todos los tipos) ✅
    │
    └── summary_cards/                    ← cards de stats por tipo (dentro de training_summary_screen)
        ├── interval_stats_card.dart      ✅
        ├── continuous_stats_card.dart    ✅
        ├── fartlek_stats_card.dart       ✅
        ├── hills_stats_card.dart         ✅
        ├── competition_stats_card.dart   ✅
        └── free_stats_card.dart          ✅
```

---

## Diferencias respecto al spec original

| Spec | Realidad | Notas |
|---|---|---|
| 2 pantallas REST (interval + hills) | 1 `rest_screen.dart` unificada | Más simple, funciona igual |
| 6 pantallas PRE por tipo | 1 `pre_execution_screen.dart` unificada | PRE no necesita tema visual específico |
| 6 pantallas SUMMARY completas | `training_summary_screen.dart` + 6 `*_stats_card.dart` | Pattern de cards, más modular |

---

## Flujo de datos

```
WorkoutExecutionController (workout_execution_controller.dart)
│
└─→ WorkoutExecutionState { currentBlock, currentSegment, sessionType, ... }
│
└─→ WorkoutExecutionScreen
    │
    ├─→ SessionScreenRouter → kind (interval/continuous/rest/...)
    ├─→ SessionTheme.forType(sessionType) → paleta + decoración
    │
    ├─→ PRE  → PreExecutionScreen
    ├─→ TRANS → BlockTransitionScreen
    ├─→ INTRA → IntervalScreen / ContinuousScreen / FartlekScreen / ...
    ├─→ REST  → RestScreen
    └─→ SUMMARY → TrainingSummaryScreen + *StatsCard
```

---

## Pendiente

- Animaciones de transición entre tipos
- Modo bajo consumo (deshabilitar animaciones en gama baja)
- Sonidos específicos por tipo (campana en pista, etc.)
- Vibraciones contextuales diferenciadas
- PRE con tema visual específico por tipo (actualmente unificada)

---

## Notas técnicas

- Decoraciones de fondo (pista, montaña): SVG o CustomPaint, no imágenes — 60fps en gama media
- `training_session_view.dart` sigue activo para entrenamientos sin `WorkoutSession` (free-form). No eliminar hasta migración completa.
