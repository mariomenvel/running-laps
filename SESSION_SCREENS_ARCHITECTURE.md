# Pantallas de sesión por tipo — Arquitectura

## Visión general

El flujo de ejecución de un entrenamiento se adapta visualmente
al tipo de sesión y al contexto del bloque actual. Cada tipo
tiene su propia "personalidad visual" (paleta, tema, énfasis
en métricas relevantes) en 5 etapas: PRE, TRANS, INTRA, REST, SUMMARY.

## Principio rector

La pantalla se decide por **el bloque actual + tipo de sesión padre**,
no solo por el tipo de sesión:

- Warmup/cooldown de cualquier sesión → estética continuous (rodaje)
- Bloque main → estética según tipo de sesión (intervals, fartlek, etc.)
- Segmento rest → pantalla de descanso tematizada según sesión

## Decision tree (decidir qué pantalla mostrar)
function pickScreen(block, segment, sessionType):
if segment.type == 'rest':
return RestScreen(theme: sessionType)
if block.role == 'warmup' or block.role == 'cooldown':
return ContinuousScreen(role: block.role)
if block.role == 'main':
switch sessionType:
case intervals    → IntervalScreen
case fartlek      → FartlekScreen
case hills        → HillsScreen
case competition  → CompetitionScreen
case continuous   → ContinuousScreen
case free         → FreeScreen

## Etapas universales

Cada tipo recorre estas 5 etapas (las que apliquen):

| Etapa   | Descripción                                  |
|---------|----------------------------------------------|
| PRE     | Preparación: GPS, BLE, ajustes, info       |
| TRANS   | Transición entre bloques (warmup→main, etc.)|
| INTRA   | Durante el esfuerzo                          |
| REST    | Descanso (solo si aplica)                    |
| SUMMARY | Resumen final del entreno                    |

## Caracterización por tipo

### INTERVALS (Series)
- **Paleta:** ocre/terracota (tartán), acentos rojos
- **Tema:** pista oval, marcador de progreso
- **Métricas hero:** tiempo de serie + pace vs objetivo
- **REST:** sí — cuenta atrás + recuperación FC
- **Especial:** muestra "Serie X/Y" siempre visible

### CONTINUOUS (Rodaje)
- **Paleta:** verde-azul suave (calma, constancia)
- **Tema:** camino/horizonte, minimalista
- **Métricas hero:** distancia + progreso
- **REST:** no
- **Especial:** % tiempo en zona objetivo en summary

### FARTLEK
- **Paleta DUAL:**
  - Modo rápido: naranja/rojo intenso
  - Modo suave: azul tranquilo
- **Tema:** ondas pulsando según ritmo
- **Métricas hero:** tiempo del tramo + FC PROTAGONISTA
- **REST:** no (los tramos suaves SON recuperación)
- **Especial:** sin pace fijo, todo por FC y sensación

### HILLS (Cuestas)
- **Paleta:** marrón/tierra + verde montaña
- **Tema:** silueta de cuesta, gradient si hay pendiente
- **Métricas hero:** tiempo de subida + FC + RPE (sin pace)
- **REST:** sí — bajada trotando
- **Especial:** "Estoy abajo, listo" como botón de continuar

### COMPETITION
- **Paleta:** dorado/negro premium + rojo de meta
- **Tema:** línea de meta, dorsales
- **Métricas hero:** distancia + tiempo + PROYECCIÓN de tiempo final
- **REST:** no (durante la carrera)
- **Especial:**
  - Cuenta atrás de 5 segundos (más tensión)
  - Detecta marca personal automática
  - Parciales por kilómetro visibles

### FREE (Libre)
- **Paleta:** neutra, minimalista
- **Tema:** ninguno
- **Métricas hero:** distancia + tiempo + pace, sin comparativas
- **REST:** no
- **Especial:** sin objetivos, sin badges, sin presión

## Arquitectura técnica

### Capa de datos
WorkoutSession
├── type: WorkoutType
├── blocks: List<WorkoutBlock>
└── ...
WorkoutBlock
├── role: BlockRole (warmup/main/cooldown/custom)
├── repetitions: int
└── segments: List<WorkoutSegment>
WorkoutSegment
├── type: SegmentType (interval/rest)
├── target: TargetConfig?
├── alerts: SegmentAlerts?
└── ...

### Capa de presentación

Estructura propuesta de archivos:
lib/features/training/views/session_screens/
├── shared/
│   ├── session_theme.dart        // SessionTheme: paleta, fondo, acentos
│   ├── session_layout.dart       // Layout base reutilizable
│   ├── metrics/
│   │   ├── pace_widget.dart      // Métrica de pace (color por target)
│   │   ├── fc_widget.dart        // Métrica de FC (color por zona)
│   │   ├── distance_widget.dart
│   │   ├── time_widget.dart
│   │   └── progress_bar.dart
│   └── decorations/
│       ├── track_oval.dart        // Para intervals (pista)
│       ├── mountain_silhouette.dart // Para hills
│       ├── finish_line.dart       // Para competition
│       └── fartlek_waves.dart     // Para fartlek
│
├── intra/
│   ├── interval_screen.dart
│   ├── continuous_screen.dart
│   ├── fartlek_screen.dart       // dual mode
│   ├── hills_screen.dart
│   ├── competition_screen.dart
│   └── free_screen.dart
│
├── rest/
│   ├── interval_rest_screen.dart
│   └── hills_rest_screen.dart    // bajada trotando
│
├── trans/
│   └── block_transition_screen.dart  // ya existe, themed
│
├── pre/
│   ├── intervals_pre.dart
│   ├── continuous_pre.dart
│   ├── fartlek_pre.dart
│   ├── hills_pre.dart
│   ├── competition_pre.dart
│   └── free_pre.dart
│
├── summary/
│   ├── intervals_summary.dart
│   ├── continuous_summary.dart
│   ├── fartlek_summary.dart
│   ├── hills_summary.dart
│   ├── competition_summary.dart  // con detección MP
│   └── free_summary.dart
│
└── session_screen_router.dart    // Decisor de pantalla

### SessionTheme (clase central)

```dart
class SessionTheme {
  final WorkoutType sessionType;
  
  // Paleta
  Color get primary;
  Color get accent;
  Color get background;
  Gradient? get backgroundGradient;
  
  // Decoración
  Widget? get backgroundDecoration;  // pista, montaña, etc.
  
  // Estilos específicos
  TextStyle get heroMetricStyle;
  
  // Modos especiales (fartlek)
  bool get hasDualMode;
  SessionTheme dualMode(bool isHighIntensity);
  
  factory SessionTheme.forType(WorkoutType type) {
    switch (type) {
      case WorkoutType.intervals:   return _IntervalsTheme();
      case WorkoutType.continuous:  return _ContinuousTheme();
      case WorkoutType.fartlek:     return _FartlekTheme();
      case WorkoutType.hills:       return _HillsTheme();
      case WorkoutType.competition: return _CompetitionTheme();
      case WorkoutType.free:        return _FreeTheme();
    }
  }
}
```

### Reutilización

Widgets compartidos entre tipos:
- `PaceWidget` — usado en intervals, continuous, competition
- `FcWidget` — usado en TODOS
- `DistanceWidget` — hero en continuous/competition/free
- `TimeWidget` — hero en intervals
- `ProgressBar` — usado en TODOS
- `TargetComparison` — pace/RPE/zona objetivo vs real

Cada pantalla compone estos widgets con el `SessionTheme` correspondiente.

### Flujo de datos
WorkoutExecutionController (existente)
│
└─→ State { currentBlock, currentSegment, sessionType }
│
└─→ SessionScreenRouter
│
├─→ SessionTheme.forType(sessionType)
├─→ pickScreen(block, segment) → INTRA / REST / TRANS
└─→ Renderiza pantalla con theme aplicado

## Roadmap de implementación

Por orden de prioridad:

### Fase 1 — Infraestructura compartida
- SessionTheme + 6 subclases
- Widgets shared/metrics/*
- SessionScreenRouter
- Migrar TrainingSessionView actual → IntervalScreen (mantiene comportamiento)

### Fase 2 — INTRA por tipo (uno por uno)
- IntervalScreen (refactor del actual)
- ContinuousScreen
- FartlekScreen (con dual mode)
- HillsScreen
- CompetitionScreen
- FreeScreen

### Fase 3 — REST tematizada
- IntervalRestScreen
- HillsRestScreen

### Fase 4 — PRE por tipo
- 6 pantallas PRE con tema visual

### Fase 5 — SUMMARY por tipo
- 6 pantallas SUMMARY con tema visual
- Detección de marca personal en competition

### Fase 6 — TRANS themed
- BlockTransitionScreen con tema según sesión destino

### Fase 7 — Pulir
- Animaciones de transición entre tipos
- Sonidos específicos por tipo (campana en pista, etc.)
- Vibraciones contextuales

## Notas técnicas

### Performance
- Las decoraciones de fondo (pista, montaña, etc.) deben ser
  SVG o Custom Paint, no imágenes grandes
- Animaciones suaves a 60fps en Android medio
- Modo bajo consumo: deshabilita animaciones

### Accesibilidad
- Todas las pantallas con contraste WCAG AA mínimo
- Modo daltónico: añadir iconos a los códigos de color
- Tamaño de texto hero ajustable

### Modo oscuro
- Todas las paletas tienen variante dark
- El modo dark conserva la "personalidad" del tipo
