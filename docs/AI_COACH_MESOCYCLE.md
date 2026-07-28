# Mesociclo del Coach IA — diseño

**Estado:** diseño pendiente de implementar (jul 2026).
**Objetivo:** convertir el Coach IA de un generador de semanas sueltas en un
entrenador con método explícito y progresión verificable.

---

## 1. El problema

Hoy `AiCoachWeeklyPlannerService.planNextWeek()` decide cada semana desde cero.
No hay estado de periodización entre semanas. Consecuencias medidas en el código:

| Síntoma | Dónde se ve |
|---|---|
| La "fase" solo existe si hay carrera objetivo | `ai_coach_prompt_builder.dart:342` — `planContext` es `null` entero cuando `profile.targetDate == null`. Sin carrera → el Coach no tiene ninguna noción de fase. |
| El volumen semanal es opinión del LLM | `ai_coach_decision_service.dart:105` lo parsea del JSON; línea 132 solo lo clampa a "no negativo". Nunca se compara con la semana anterior. |
| La regla del 10% es solo texto | `ai_coach_prompt_builder.dart:74-75` — instrucción en lenguaje natural, sin verificación. |
| El deload cada 3-4 semanas es solo texto | `ai_coach_prompt_builder.dart:76` — nada lleva la cuenta de cuántas semanas de carga van seguidas. |
| El quality gate no mira volumen | `ai_coach_weekly_planner_service.dart:367-406` — solo valida días disponibles, ≤2 calidades y deload con ≤1 calidad. |

El usuario ve sesiones razonables (los paces sí son deterministas vía VDOT), pero
no ve **un plan**. Y el sistema no puede garantizar que la carga progrese de forma
segura, porque nadie hace la aritmética.

---

## 2. Principio rector del diseño

> **El LLM escribe el lenguaje. El código decide los números.**

El bloque (estructura, volúmenes, semana de descarga) se calcula en Dart y es
determinista y testeable. El LLM aporta la narrativa (`focus`, `analysis`) y el
reparto cualitativo de sesiones, que es donde aporta valor real.

Corolario de seguridad:

> **El bloque solo se puede desobedecer hacia abajo.**

El mesociclo fija un **techo** de carga. La fatiga real (TSB, lesión, adherencia)
puede reducir por debajo de ese techo en cualquier momento, nunca superarlo. Así
la periodización no pelea con las guardas de recuperación que ya existen
(`ai_coach_session_generator.dart:350-377`).

---

## 3. Modelo de datos

### `AiCoachMesocycle` (en `ai_coach_models.dart`)

Persistido en `users/{uid}/settings/aiCoachMesocycle`, siguiendo el patrón
`_settingsDoc` que ya usan `aiCoachProfile`, `aiCoachState`, `aiCoachAthleteMemory`.

```dart
class AiCoachMesocycle {
  final String id;
  final DateTime startWeek;        // lunes de la semana 1 del bloque
  final int lengthWeeks;           // por defecto 4
  final AiCoachBlockPhase phase;   // base | specific | taper | race
  final List<AiCoachWeekType> weekPattern; // p.ej. [build, build, build, absorb]
  final double baselineVolumeKm;   // ancla: volumen al empezar el bloque
  final double volumeStepPct;      // progresión por semana (default 0.08, clamp 0–0.10)
  final double deloadVolumePct;    // fracción del pico en la semana de descarga (0.60)
  final String focus;              // narrativa del LLM: qué construye este bloque
  final String? raceGoalId;        // enlace opcional a RaceGoal
  final DateTime createdAt;
  final String sourceModel;
}
```

**Reutiliza `AiCoachWeekType`** (`ai_coach_models.dart:225`), que ya tiene
exactamente el vocabulario necesario: `build`, `absorb`, `recovery`, `taper`,
`race`, `restart`. No se inventa un enum nuevo.

`AiCoachBlockPhase` sí es nuevo, pero se puede derivar del `_phaseForWeeksRemaining`
existente cuando hay carrera (ver §5).

### Repositorio

Dos métodos en `AiCoachRepository`, calcados de `getWeeklyState`/`saveWeeklyState`:

```dart
Future<AiCoachMesocycle?> getMesocycle({String? uid});
Future<void> saveMesocycle(AiCoachMesocycle block, {String? uid});
```

---

## 4. El motor de bloque (lógica pura, sin Firebase)

Fichero nuevo: `ai_coach/data/ai_coach_mesocycle_engine.dart`. Sin dependencias de
Firestore → testeable directo.

### 4.1 Volumen objetivo de la semana N

⚠️ **Progresión con techo, no compuesta.** Un `baseline × (1+step)^n` encadenado entre
bloques da ~19× de volumen en un año — absurdo. El volumen real asintota hacia un
límite que marcan nivel, objetivo y disponibilidad. La progresión desacelera al
acercarse a ese techo:

```dart
double targetVolumeForWeek(AiCoachMesocycle b, int weekIndex) {
  final type = b.weekPattern[weekIndex];
  if (type == AiCoachWeekType.absorb || type == AiCoachWeekType.recovery) {
    // La descarga se calcula sobre el pico alcanzado, no sobre el baseline
    return _progressed(b, weekIndex - 1) * b.deloadVolumePct;
  }
  return _progressed(b, weekIndex);
}

double _progressed(AiCoachMesocycle b, int i) {
  var v = b.baselineVolumeKm;
  for (var w = 0; w < i; w++) {
    // Paso proporcional al margen que queda hasta el techo → curva logística
    final headroom = ((b.volumeCeilingKm - v) / b.volumeCeilingKm).clamp(0.0, 1.0);
    v += v * b.volumeStepPct * headroom;
  }
  return math.min(v, b.volumeCeilingKm);
}
```

Propiedades garantizadas por construcción: monótona no decreciente en semanas `build`,
acotada por `volumeCeilingKm`, y **nunca supera +10% semana a semana** (con
`volumeStepPct` clampado a 0.10). La regla del 10% deja de ser una frase en un prompt
y pasa a ser aritméticamente imposible de violar.

Cuando el volumen se aplana contra el techo, la progresión se traslada a la calidad
(más específica, no más larga) — que es lo que hace un entrenador real cuando el
atleta llega a su volumen sostenible.

### 4.1.b `volumeCeilingKm` — el techo

```
ceiling = min(techoPorObjetivo × factorNivel, sesiones × kmMediosPorSesion)
```

| Objetivo | Techo base (km/sem) |
|---|---|
| `returnToRunning` | 30 |
| `race5k` / `improvePace` | 50 |
| `race10k` / `improveEndurance` | 60 |
| `raceHalfMarathon` | 70 |
| `raceMarathon` | 85 |

Factor por nivel: `beginner` 0.5 · `intermediate` 0.75 · `advanced` 1.0.
Km medios por sesión: `beginner` 9 · `intermediate` 15 · `advanced` 22.

El segundo término hace que la disponibilidad real mande: un intermedio con 3 días
queda en 45 km/sem aunque su objetivo (media) permita 52. **Son defaults de práctica
de entrenamiento, no constantes derivadas** — por eso son candidatos a config remota
(§10.3).

### 4.2 Composición del `weekPattern`

| Situación | Patrón | Longitud | `step` | `deloadPct` |
|---|---|---|---|---|
| Bloque normal | `[build, build, build, absorb]` | 4 | 0.08 | 0.60 |
| Atleta novato (`level == beginner`) | `[build, build, absorb]` | 3 | 0.05 | 0.70 |
| Vuelta tras parón (`consecutiveMissedWeeks >= 2`) | `[restart, build, build, absorb]` | 4 | 0.05 | 0.60 |
| Taper (carrera en ≤3 semanas) | `[taper, taper, race]` | según `weeksRemaining` | — | — |

La detección de "vuelta tras parón" ya tiene datos: `AiCoachWeeklyState`
(`ai_coach_models.dart:634`) expone `consecutiveMissedWeeks`.

**Por qué el novato lleva bloque corto *y* paso reducido** (decisión jul 2026): el
mecanismo de lesión del corredor novato no es fatiga aguda sino adaptación desacoplada
de tejidos — el sistema cardiovascular mejora en semanas, tendón/fascia/hueso tardan
meses. El daño acumulado depende de dos variables distintas: la **velocidad** de
incremento y el **tiempo sostenido** en carga elevada sin descarga. El bloque corto
ataca la segunda, el paso reducido la primera. Tocar solo la longitud deja media causa
sin cubrir.

**La descarga del novato recorta volumen, nunca frecuencia.** Para un principiante el
predictor nº1 de éxito a largo plazo es el hábito, y el hábito es frágil justo en las
primeras semanas: bajarle de 3 sesiones a 2 en la semana de descarga rompe la rutina en
el peor momento. Tres sesiones más cortas, todas suaves. `targetSessions` lo sigue
fijando `_ensureMinimumTargetsFromProfile` (línea 499) a partir del perfil — el bloque
no lo toca. Su `deloadVolumePct` es 0.70 (no 0.60) porque a volúmenes bajos una descarga
profunda no aporta recuperación relevante y sí rompe el ritmo.

### 4.3 `baselineVolumeKm` — de dónde sale

Orden de preferencia:
1. `weeklyState.weeklyKm` de la semana anterior, si hubo actividad real.
2. `ctl * 7` como proxy si hay historial pero la última semana fue anómala.
3. Default conservador por `profile.level` si el atleta es nuevo — encaja con el
   protocolo de baseline que ya existe en `ai_coach_prompt_builder.dart:136-161`.

Nunca se toma el volumen de una semana de descarga como baseline del siguiente
bloque (produciría una caída escalonada); se usa el pico del bloque anterior.

---

## 5. Fase sin carrera objetivo — el hueco que se cierra

Hoy sin `targetDate` no hay fase (`prompt_builder.dart:342`). Diseño:

- **Con carrera**: la fase sale de `_phaseForWeeksRemaining` (que ya funciona) y el
  bloque se recorta para que el taper caiga donde toca.
- **Sin carrera**: se entra en un ciclo de bloques con énfasis rotatorio, de forma
  que sigue habiendo narrativa y progresión:

  | Bloque | Fase | Énfasis |
  |---|---|---|
  | 1 | `base` | Volumen aeróbico, calidad = fartlek suave |
  | 2 | `base` | Volumen + introducción de tempo |
  | 3 | `specific` | Umbral (tempo / series largas) |
  | 4 | `base` | Consolidación, vuelta a volumen |

  Se repite. Cada bloque sube el `baselineVolumeKm` desde el pico del anterior, así
  que hay progresión de largo plazo aunque no haya carrera.

Resultado: **`planContext` deja de ser `null` nunca**. Todo usuario tiene fase,
bloque y posición dentro del bloque.

---

## 6. Integración en `planNextWeek()`

Puntos de inserción concretos en `ai_coach_weekly_planner_service.dart`:

```
línea 78   profile = await _aiCoachRepository.getProfile(...)
       ▼   [NUEVO] block = await _resolveActiveMesocycle(uid, nextWeekStart, profile, context)
línea 82   rawDecision = await _decisionService.generateWeeklyDecision(uid)
                          └─ el prompt ahora incluye planContext con el bloque
línea 108  diversified = _ensureTargetDiversity(...)
       ▼   [NUEVO] aligned = _alignDecisionToMesocycle(decision, block, weekIndex)
línea 195  gate = _runQualityGate(...)   ← [NUEVO] recibe block, añade check de volumen
```

### 6.1 `_resolveActiveMesocycle`

Devuelve el bloque activo, creándolo si:
- no existe ninguno,
- el actual ya terminó (`weekStart >= startWeek + lengthWeeks`),
- cambió materialmente el objetivo (nueva carrera de prioridad alta, o `targetDate` movida),
- hubo un parón largo → se cierra el bloque y se abre uno de tipo `restart`.

### 6.2 `_alignDecisionToMesocycle`

Sigue el patrón de los `_alignDecisionToProfile` / `_ensureTargetDiversity` que ya
existen (líneas 448 y 567):

```dart
final ceiling = engine.targetVolumeForWeek(block, weekIndex);
// El bloque es un TECHO: el LLM puede pedir menos (fatiga), nunca más.
final volume = math.min(decision.targetVolumeKm, ceiling);
// El weekType lo manda el patrón del bloque, no el LLM.
final weekType = block.weekPattern[weekIndex];
```

Si el patrón dice `absorb`, se fuerza además `adjustment = deload`, con lo que se
activa la guarda que ya existe en el generador de sesiones
(`session_generator.dart:350-377`) y el check `deload_with_excess_quality` del gate.
**La semana de descarga pasa a estar garantizada por construcción.**

### 6.3 Quality gate ampliado

Dos issues nuevos en `_runQualityGate`:

- `volume_progression_exceeded` — el volumen resultante supera el techo del bloque
  (defensa en profundidad: no debería pasar tras el align, pero se registra).
- `missing_deload` — han pasado >4 semanas de `build` consecutivas sin `absorb`.

Ambos se loguean en el evento `weekly_planner_generated` (línea 211), que ya emite
`qualityGateIssues` — la observabilidad sale gratis.

---

## 7. Hacer visible el método

Sin esto, el trabajo anterior es invisible y no se paga.

### 7.1 Tira de bloque en Home

Widget nuevo `home/widgets/home_block_strip.dart`, junto a `home_race_countdown.dart`:

```
┌────────────────────────────────────────────┐
│  BLOQUE BASE · Semana 2 de 4               │
│  ●━━●━━○━━○                                │
│  Construyendo base aeróbica                │
│  Esta semana: 32 km · 3 sesiones           │
└────────────────────────────────────────────┘
```

Cuarto punto marcado visualmente como descarga (color distinto), para que el
usuario **vea que el descanso está planificado**, no improvisado. Es el mensaje que
más confianza genera: alguien está llevando la cuenta.

### 7.2 Conectar con `CoachPhilosophyView`

Ya existe (tab 17, montada en `main_shell.dart:179`) y promete cuatro principios:
*base aeróbica primero · intensidad con criterio · tu fatiga manda · progresión
sostenible*. Hoy son texto estático. Con el bloque, cada principio puede mostrar su
evidencia viva:

| Principio | Evidencia que se puede mostrar |
|---|---|
| Base aeróbica primero | % real de volumen en Z1–Z2 de las últimas 4 semanas |
| Intensidad con criterio | nº de sesiones de calidad esta semana (máx 2, forzado por el gate) |
| Tu fatiga manda | TSB actual y si recortó el techo del bloque |
| Progresión sostenible | curva de volumen del bloque, con la descarga marcada |

Tocar la tira de Home lleva a esta vista. La promesa deja de ser marketing y pasa a
ser un informe.

### 7.3 Feedback semanal

`ai_coach_weekly_feedback_view.dart` gana el encabezado del bloque, para que el
resumen del domingo se lea como "cierre de la semana 2 de 4", no como un hecho suelto.

---

## 8. Tests

Todo el motor es lógica pura → `test/features/ai_coach/mesocycle_engine_test.dart`,
sin Firebase, siguiendo el patrón de
`test/features/templates/workout_editor_view_model_test.dart`:

- la curva de volumen nunca supera +10% semana a semana;
- la semana de descarga cae al `deloadVolumePct` del pico, no del baseline;
- un bloque de novato mete descarga cada 3 semanas;
- `targetVolumeForWeek` es monótona creciente dentro de las semanas `build`;
- el align nunca sube el volumen que pidió el LLM, solo lo baja;
- `consecutiveMissedWeeks >= 2` produce un bloque que empieza en `restart`;
- con `targetDate` a 2 semanas, el patrón es taper y no `build`.

Además, un test de propiedad sobre perfiles sintéticos (novato 3 días / avanzado con
maratón a 12 semanas / vuelta de lesión): generar 8 bloques encadenados y afirmar que
la progresión total es sostenible y que hay una descarga cada ≤4 semanas.

---

## 9. Fases de entrega

| Fase | Alcance | Valor |
|---|---|---|
| **1** | Modelo + `mesocycle_engine.dart` + repositorio + tests | Progresión garantizada por aritmética |
| **2** | Integración en `planNextWeek` + quality gate + `planContext` siempre presente | El plan obedece al bloque; se cierra el hueco de "sin carrera no hay fase" |
| **3** | Tira de Home + `CoachPhilosophyView` viva + feedback semanal | El método se **ve** — es lo que convierte en pago |

Las fases 1 y 2 no cambian nada visible; la 3 es la que el usuario percibe. No tiene
sentido entregar la 3 sin las anteriores (sería una tira que miente), ni las 1–2 sin
la 3 (mejora real que nadie nota).

---

## 10. Riesgos y decisiones abiertas

1. **Rigidez vs adaptación.** Resuelto por el principio "solo hacia abajo": el bloque
   es techo, no suelo. Si el TSB se hunde en la semana 3, el Coach recorta y el bloque
   no protesta.
2. ~~**¿Se le enseña el bloque al LLM o se le oculta?**~~ ✅ **Decidido: se le enseña.**
   El modo de fallo lo decide. Oculto: el LLM propone 45 km, el código clampa a 32, y su
   `analysis` — que el usuario **lee** — dice "esta semana subimos a 45 km". Una
   contradicción visible entre lo que el coach dice y lo que el plan hace destruye la
   confianza más rápido que cualquier defecto metodológico sutil, porque el usuario la
   detecta sin ser experto. Visible: el riesgo es que repita el bloque sin aportar, pero
   ese fallo es aceptable — los números ya son deterministas, repetirlos es correcto; su
   valor está en la composición cualitativa y la narrativa. El prompt debe decir
   explícitamente que `targetVolumeKm` y `weekType` vienen dados y no se negocian.
   **No hace falta un campo para que discrepe**: el `min(LLM, techo)` ya es la válvula
   — pedir menos siempre funciona, pedir más nunca.
3. ~~**Bloques de 3 vs 4 semanas.**~~ ✅ **Decidido: 3 para `beginner`, 4 para el resto**,
   con paso y profundidad de descarga distintos (ver §4.2). Los valores concretos siguen
   siendo defaults de práctica, no constantes derivadas — candidatos a config remota vía
   `appConfig/aiCoachProvider`, que ya existe.
4. **Qué pasa si el usuario edita sus sesiones a mano.** El bloque mide intención, no
   ejecución; el volumen real ya lo recoge `weeklyState.weeklyKm` y alimenta el
   baseline del bloque siguiente. No se intenta "corregir" al usuario dentro del bloque.

---

## 11. Fuera de alcance (deliberadamente)

- **VDOT auto-actualizado desde entrenos** — mejora grande e independiente
  (hoy `bestVdotFromProfile` promedia VDOTs de distintas distancias, cuando Daniels
  dice usar el mejor/más reciente). Merece su propio diseño.
- **Bucle de feedback post-sesión** — `ai_coach_session_analysis_service.dart` sigue
  siendo texto informativo. Con el mesociclo ya hay una estructura a la que engancharlo,
  que es justo lo que hoy falta; se aborda después.
