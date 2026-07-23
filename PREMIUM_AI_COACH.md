# AI Coach — Especificación
> Estado actual: implementado y disponible **Free durante beta**. La capa Premium (paywall, RevenueCat) está pendiente de activar.

---

## Visión general

Coach IA personal que actúa como entrenador real de atletismo: genera planes semanales adaptados, analiza rendimiento y fatiga, conversa con el atleta y ajusta el plan según evolución.

Modelo: Claude Sonnet vía **OpenRouter → Cloud Function** (`openrouter_client.dart` usa `FirebaseFunctions.httpsCallable`). Los datos sensibles nunca salen del cliente directamente — pasan por Cloud Function con Admin SDK.

---

## Modelo de negocio (diseño, pendiente activar)

- **Trial:** 30 días gratis al activar premium
- **Códigos creador:** +30 días gratis adicionales
- **Suscripción:** precio mensual TBD (estimado 5-10€/mes)
- **Plataforma:** RevenueCat (pendiente implementar)
- **Estado actual:** todo gratis durante beta, controlado por `weeklyPlanningEnabled` y `chatAdjustmentsEnabled` en `appConfig/aiCoachProvider` (Firestore)

---

## Cuotas y límites (diseño, pendiente activar paywall)

### Free (sin premium) — diseño futuro
- Generador por prompt: 8 generaciones/mes
- Sin Coach IA
- Sin chat

### Premium
- Generador por prompt: 60 generaciones/mes
- Coach IA completo
- Chat con coach (5 turnos/conversación)
- Regeneración de semana: 5/semana

---

## Habilitación actual (beta)

El Coach se habilita/deshabilita via Firestore en `appConfig/aiCoachProvider`:
- `provider`: `"openrouter"` — activa OpenRouter
- `weeklyPlanningEnabled`: `true` — activa generación de planes
- `chatAdjustmentsEnabled`: `true` — activa chat con coach

Si `provider != 'openrouter'` o los flags están en `false`, los servicios retornan error sin llamar a la API.

---

## Objetivos disponibles (`AiCoachGoalType`)

```dart
enum AiCoachGoalType {
  race5k,           // Competición 5K (+ fecha)
  race10k,          // Competición 10K (+ fecha)
  raceHalfMarathon, // Media Maratón (+ fecha)
  raceMarathon,     // Maratón (+ fecha)
  improvePace,      // Mejorar marca personal sin fecha fija
  improveEndurance, // Mejorar resistencia / base aeróbica
  returnToRunning,  // Volver a correr tras pausa o lesión
}
```

> Nota: Trail/Ultra y "Salud general" están en el roadmap pero **no implementados** aún.

---

## Competiciones objetivo (`raceGoals`) ✅ implementado (backend)

Las competiciones son una **entidad propia** (`RaceGoal`, `features/ai_coach/data/race_goal.dart`), no un tipo de sesión. Fuente única de verdad de la fecha objetivo del atleta.

- **Colección:** `users/{uid}/raceGoals` (privada al propietario). CRUD en `RaceGoalRepository`.
- **Campos:** `date` ('yyyy-MM-dd', igual que `AthleteSession.date`), `distance` (`RaceDistance`: 5K/10K/media/maratón/otra — metros idénticos a `raceDistanceM` del editor), `customDistanceM`, `name`, `targetTimeSeconds`, `priority` (`RaceGoalPriority`: `high`/`medium`/`low`).
- **Prioridad = periodización** (clásico A/B/C): `high` → taper completo; `medium` → mini-taper de 2-3 días; `low` → sin taper, se corre como entreno.

**Conexión con el Coach** (`ai_coach_context_builder.dart`):
- La **próxima carrera de prioridad alta** (`nextPrimaryFrom`) deriva el `targetDate` efectivo del perfil (vía `copyWith`), que alimenta `planContext.weeksRemaining`/`phase`/taper en el prompt. **Manda sobre** el `targetDate` heredado del perfil (el selector suelto de Ajustes queda obsoleto).
- Todas las carreras próximas se pasan al LLM en `coachSignals.upcomingRace` (la principal, con distancia) y `coachSignals.upcomingRaces` (lista, para el mini-taper de las secundarias). El system prompt tiene una instrucción explícita para respetarlas.
- `raceInNext14Days` (weeklyState) ahora considera también los `raceGoals`, no solo sesiones categoría `competicion`.

**UI** ✅ (corregido jul 2026 — ver nota de alcanzabilidad abajo): lista "Tus objetivos" + sheet crear/editar/eliminar (`race_goals_section.dart`) embebida en `ai_coach_settings_view.dart` (`AiCoachSettingsView`, tab 16 de `MainShell`, alcanzable desde Perfil → "Configurar IA"), reemplazando el antiguo picker suelto de `targetDate`. Marcador de bandera + entrada rápida "Marcar competición" en `calendar/views/calendar_view.dart` (tab 1, el calendario real que ve el usuario) — extiende `_weekHasCompetition` para que las semanas con `RaceGoal` también resalten. Cuenta atrás en Home (`home_race_countdown.dart`, solo si hay carrera de prioridad alta).

> ⚠️ **Nota de alcanzabilidad (jul 2026):** la primera versión de esta UI se embebió por error en `athlete_hub_view.dart` (pestaña Planificación), que **no está enganchada a `MainShell`** — junto con `progress_view.dart` y `season_view.dart` forma un clúster de pantallas que solo se referencian entre sí, inalcanzable desde la navegación real. Se corrigió moviendo la UI a las pantallas reales de arriba. Al añadir UI nueva, verificar SIEMPRE que la pantalla destino esté en la lista `_screens` de `main_shell.dart` (o sea alcanzable transitivamente desde ahí) antes de darla por "hecha".

**Categoría `competicion` retirada**: (1) del prompt del Coach — ya no genera "sesiones de competición"; (2) del editor activo — se quitó la opción "Competición" de `WorkoutTypeSelector` (`WorkoutType.competition`), que se mapeaba a categoría `competicion` en `athlete_session_mapper`. Los valores de enum (`WorkoutType.competition`, `SessionCategory.competicion`) se conservan por compatibilidad con sesiones antiguas y sus `switch`. Los editores huérfanos (`session_editor_view.dart`, `athlete_session_editor_view.dart`, deuda técnica #5) también la exponían pero son código muerto. Migración de sesiones `competicion` antiguas → `RaceGoal`: tarea de datos pendiente (one-off), no bloqueante.

---

## Onboarding del Coach ✅ implementado

Archivos: `ai_coach_onboarding_view.dart` + `ai_coach_onboarding_launcher.dart`

### Cuestionario inicial (wizard multi-paso)

1. **Objetivo** — selección de `AiCoachGoalType` (7 opciones)
2. **Competición** — fecha objetivo (opcional según tipo)
3. **Disponibilidad** — días/semana (1-7), días concretos (L-D multi-select), tiempo por sesión (min)
4. **Estado actual** — marcas opcionales (5K, 10K, HM, Maratón en segundos), lesiones/limitaciones (texto libre), preferencias (texto libre)

Al completar: `isAthleteMode = true` + `onboardingCompleted = true` en Firestore (escritura atómica en un solo `update()`) → `AuthWrapper` reacciona automáticamente al stream.

El launcher (`launchAiCoachOnboarding()`) verifica si ya existe perfil; si existe, va directamente a settings (tab 16).

### Flujo de navegación al completar

1. `AiCoachOnboardingView` llama `widget.onCompleted()` (tipo `VoidCallback`)
2. El launcher ejecuta `onCompleted?.call()` (escribe Firestore) y luego `forceGenerateCurrentWeekPlan()` con 500 ms de delay para respetar el orden
3. Si el widget sigue montado tras `onCompleted`, `popUntil(isFirst)` limpia el stack completo
4. `AuthWrapper` detecta el cambio en Firestore y muestra `MainShell`

### Timeout y cancelación

- La llamada al LLM tiene timeout de **30 segundos** (`.timeout(Duration(seconds: 30))`)
- Si supera el tiempo: `ModernSnackBar.showError` con mensaje de conexión
- Botón **Cancelar** disponible durante el procesamiento; resetea al paso 0

### Schema de extracción de perfil

El LLM recibe un JSON schema con constraint `enum` estricto para el campo `goal` (7 valores exactos de `AiCoachGoalType`). Esto evita que el modelo hallucine valores no reconocidos por el parser Dart.

---

## Generación de planes

### Frecuencia
- Generación automática: cada domingo para la semana siguiente (`ai_coach_automation_service.dart`)
- Regeneración manual: límite 5/semana
- Solo semana siguiente (no plan completo de meses)
- **Fallback mid-week**: si se genera en mitad de semana y no quedan días disponibles (`feasibleWeekdays` vacío), el planner salta automáticamente a la semana siguiente en lugar de no generar nada

### Modelos de IA
- **Claude Sonnet 4.6** — Coach principal (razonamiento complejo, planes semanales)
- **Claude Haiku 4.5** — generador por prompt (parsing simple de sesión individual)

### Contexto que se envía a Claude

```json
{
  "athleteProfile": {
    "goal": "race_marathon",
    "fechaObjetivo": "2026-10-15",
    "diasDisponibles": ["L","M","J","S","D"],
    "tiempoPorSesion": 60,
    "marcas": { "5k": 1245, "10k": 2630, "hm": 5820 },
    "limitaciones": "Texto libre",
    "preferencias": "..."
  },
  "currentWeek": 8,
  "totalWeeksToGoal": 24,
  "phase": "base_3",
  "recentHistory": [
    {
      "weekNumber": 7,
      "totalKm": 42,
      "sessionsCompleted": 4,
      "sessionsPlanned": 5,
      "sessions": [
        {
          "type": "intervals",
          "planned": { "totalKm": 8, "avgPace": "4:30", "rpe": 8 },
          "executed": { "totalKm": 8, "avgPace": "4:35", "rpe": 9,
                        "completed": true, "notes": "..." }
        }
      ]
    }
  ],
  "trends": {
    "weeklyKmTrend": "increasing|stable|decreasing",
    "paceImprovement": "+15s/km en 3 meses",
    "rpeAverage": 6.5,
    "fatigueLevel": "low|medium|high"
  },
  "weeklyFeedback": {
    "sensaciones": 3,
    "sueno": "bien|regular|mal|no_medido",
    "molestias": "Texto opcional",
    "motivoParon": "lesion|viaje|trabajo|otro (opcional)",
    "observaciones": "Texto opcional"
  }
}
```

### Análisis de fatiga automático
- RPE alto en sesiones que deberían ser fáciles
- Pace muy por debajo del objetivo en varias sesiones
- FC alta en zona Z2 (signo clásico de fatiga)
- Sesiones no completadas
- Aumento brusco de carga semanal
- Patrones del cuestionario semanal (sensaciones ≤2 o molestias recurrentes)

---

## Cuestionario semanal ✅ implementado

Vista: `ai_coach_weekly_feedback_view.dart`. Modelo: `AiCoachWeeklyFeedback`.

Cada domingo, opcional (saltable):
1. **¿Cómo te has sentido esta semana?** — escala 1-5 (`sensaciones`)
2. **¿Has dormido bien?** — `bien / regular / mal / no_medido` (`sueno`)
3. **¿Algún dolor o molestia?** — texto libre opcional (`molestias`)
4. **¿Alguna observación para el coach?** — texto libre opcional (`observaciones`)
5. **Motivo de parada** (si aplica) — `lesion / viaje / trabajo / otro` (`motivoParon`)

El `ai_coach_prompt_builder.dart` usa el feedback para ajustar instrucciones al modelo:
- `sensaciones ≤ 2` o `molestias != null` → reduce carga e intensidad
- `sensaciones ≥ 4` y `sueno == 'bien'` → puede aumentar carga
- Molestias recurrentes en historial → alerta explícita al modelo

---

## Detección de marcas personales (PbDetector) ✅ implementado

`pb_detector.dart` — detecta PBs automáticamente tras entrenamientos con GPS:
- Distancias estándar: 5K, 10K, HM (21.097m), Maratón (42.195m)
- Interpolación si distancia dentro ±3% del estándar
- Solo válido si entrenamiento tiene GPS activo
- Actualiza `AiCoachProfile.pb*Seconds` en Firestore

---

## Chat con el Coach ✅ implementado

`ai_coach_chat_service.dart`:
- Límite: **3 consultas por semana** (ventana lunes-domingo)
- Contador en `settings/aiCoachUsage` con ventana semanal; al cambiar semana reinicia
- Historial en memoria durante la sesión
- Reset semanal automático (`resetWeeklyChatUsage` Cloud Function)
- Solo disponible si `isAthleteMode == true` y `chatAdjustmentsEnabled == true`
- Si se supera el límite → error controlado, mensaje al usuario
- `AiCoachSettingsView` muestra "Consultas restantes esta semana: X/3"

---

## Memoria del atleta y KPIs ✅ implementado

### `AiCoachAthleteMemory` — `users/{uid}/settings/aiCoachAthleteMemory`
Memoria personalizada construida desde 90 días de historial:
- Tasa de aceptación por categoría IA
- Cumplimiento por categoría
- Adherencia por día de semana
- Estilo dominante: `continuous_dominant` / `interval_dominant` / `mixed`

La planificación usa esta memoria para adaptar propuestas: suaviza carga con baja tolerancia, refuerza el estilo dominante, aplica preferencia de días por adherencia.

### `AiCoachKpiSnapshot` — `users/{uid}/settings/aiCoachKpiLatest`
KPIs recalculados tras cada `weekly_planner_generated` (ventana 90 días):
- `acceptanceRate` — (aceptadas+editadas) / sugeridas
- `completionRate` — completadas / planificadas
- Volumen: sugeridas / aceptadas / editadas / rechazadas
- `replansCount` — ediciones del usuario

### `aiCoachAutomation` — `users/{uid}/settings/aiCoachAutomation`
Control de idempotencia para la automatización semanal:
- `lastGeneratedCycleId`, `lastGeneratedAt`, `lastGenerationSource`
- Si ya existe plan para esa semana → marca ciclo como resuelto sin duplicar

### Transparencia en UI
Cada sugerencia IA en el calendario muestra un "Por qué" corto usando `focus`, `rationale` o `planningNotes` del plan generado.

---

## Modelos OpenRouter usados

Configurados en `ai_coach_models_config.dart`:
- Coach principal: `anthropic/claude-sonnet-4.5` (`.` no `-`)
- Generador por prompt: `anthropic/claude-haiku-4.5`

> **Nota:** La API de `appConfig/aiCoachProvider` controla habilitación, pero los modelos reales provienen de `AiCoachModels` (hardcoded). Si se quiere que Firestore controle el modelo activo, hay que cambiar el contrato de `AiCoachDecisionService`, `AiCoachChatService`, onboarding y generador por prompt.

---

## Filosofía y enfoque

### Vista "Cómo entrena tu coach" ✅ implementado
`coach_philosophy_view.dart` — vista estática (sin ViewModel) accesible desde `AiCoachSettingsView` (tile inicial). Comunica 4 principios fijos: base aeróbica primero (70-80% volumen suave), intensidad con criterio (VDOT, no tablas genéricas), tu fatiga manda (TSB) y progresión sostenible. Sin CTA — puramente informativa.

### `AiCoachProfile.trainingFocus` ✅ implementado
Campo opcional `String? trainingFocus` — `'volume' | 'balanced' | 'quality'`, `null`/`'balanced'` = comportamiento actual sin cambios. Seleccionable en `AiCoachSettingsView`, sección "ENFOQUE DE ENTRENAMIENTO". No se pide en el onboarding (el wizard ya tiene 6 pasos); el atleta lo descubre en settings.

Efecto en `ai_coach_prompt_builder.dart` (`_buildDecisionSystemPrompt`):
- `volume`: reduce sesiones de calidad a 1/semana salvo semana de test, alarga rodajes en el rango seguro del nivel.
- `quality`: hasta 2 sesiones de intensidad/semana si el TSB lo permite, rodajes en el rango bajo del volumen.
- `balanced`/`null`: no añade instrucción — plan generado igual que antes de este campo.

El bloque se inserta **después** de todas las reglas de seguridad del prompt (TSB, protocolo de atleta nuevo, restricciones recurrentes, día disponibles) y declara explícitamente que nunca anula esos guards — el LLM prioriza siempre lesión/TSB bajo/needsBaselineAssessment sobre la preferencia de enfoque.

---

## Progresión intra-sesión

Las `athleteSessions` generadas incluyen `targetReps` y `targetSegmentDistanceM` para que la pantalla de entrenamiento compare planificado vs ejecutado en tiempo real.

---

## Casos especiales

### Cambio de objetivo a mitad de plan
- Solo cambia la siguiente semana generada (no regenera todo)
- Contexto del coach se actualiza automáticamente

### Lesión declarada en cuestionario o chat
- `motivoParon == 'lesion'` o `molestias` recurrentes → coach reduce carga
- Puede generar sesiones de recuperación
- Notifica los cambios al usuario

### Inactividad prolongada
- 2+ semanas sin completar sesiones: mensaje del coach
- A las X semanas (TBD) deja de generar automáticamente
- Botón "He vuelto" reactiva la generación

### Fin del plan (objetivo alcanzado)
- No se generan más semanas automáticamente
- Si crea nuevo perfil: nuevo plan con nuevo objetivo

---

## Privacidad

- Datos sensibles (FC, RPE, marcas, lesiones) se envían a Claude **vía Cloud Function** (nunca directamente desde el cliente)
- Anthropic no usa datos de API para entrenamiento (política API)
- Cláusula en T&C de Premium explicando el flujo (pendiente redactar para lanzamiento)
- Usuario puede pedir borrado de su contexto en cualquier momento

---

## Idiomas

- App en español
- Prompts internos a Claude en español (suficiente calidad con Sonnet)
- Al traducir la app: detección automática del idioma del dispositivo

---

## Pendiente implementar

- Paywall + RevenueCat (toda la capa de monetización)
- Objetivos: Trail/Ultra, "Salud general"
- Test de umbral individualizado (zonas Premium)
- "He vuelto" button tras inactividad prolongada

---

## Análisis post-sesión ✅ implementado (Fase 1)

Archivo: `ai_coach/data/ai_coach_session_analysis_service.dart`

- **Trigger:** al guardar un entrenamiento vinculado a una sesión planificada, fire-and-forget (sin `await`) tras el guardado exitoso. Dos puntos de disparo: `training_summary_screen.dart` → `_saveTraining()` (flujo GPS) y `complete_session_manually_view.dart` (completar manualmente).
- **Contexto:** perfil resumido (nivel, objetivo), bloques de la sesión planificada con targets, series ejecutadas (distancia, tiempo, pace, RPE, FC), próximas sesiones planificadas de la semana. No reutiliza el builder semanal completo.
- **Modelo:** `AiCoachModels.decision` (Claude Sonnet), respuesta JSON con campo `analysis`, 3-5 frases en español.
- **Persistencia:** `users/{uid}/trainings/{id}.coachAnalysis = {text, generatedAt}` vía `update()`. Es inmutable — no se regenera.
- **Gate:** mismo check que el chat (`isAthleteMode` + `providerConfig.provider == 'openrouter'`). Cualquier error → `debugPrint` + `null`, nunca rompe el guardado.
- **No consume cuota de chat** (no usa `AiCoachUsage`).
- **Superficies:**
  - Detalle del historial (`training_detail_view.dart`) — card "ANÁLISIS DEL COACH" tras notas.
  - Home (`home_view.dart`) — primera frase bajo la card de sesión completada de hoy (`HomeViewModel.completedTodayCoachAnalysis`, un read extra puntual del training vinculado).
  - Resumen de sesión: no se muestra (llega en background, ~5-10s después de guardar).
- **Estado de carga (UI de 3 estados):** como el análisis llega en background, ambas superficies distinguen:
  1. `coachAnalysis` con texto → mostrar análisis.
  2. Sin `coachAnalysis` pero "generándose" → detalle: card con `CupertinoActivityIndicator` + "Tu coach está analizando esta sesión..."; Home: texto "Analizando tu sesión...".
  3. Sin `coachAnalysis` y no generándose → detalle omite la sección; Home muestra el texto genérico de buen trabajo.
  - Heurística de "generándose": `plannedComparison != null` (no existe campo persistido que vincule el training a la AthleteSession) **y** menos de 2 min desde `createdAt`/`fecha`. Limitación conocida: el flujo "completar manualmente" no escribe `plannedComparison`, así que ese caso no muestra el estado de carga.
  - El detalle además hace polling ligero vía `TrainingRepository.getTrainingById()`: cada 5 s durante máx. 30 s mientras está en estado "generándose"; si llega el análisis hace `setState`. Un timer adicional oculta el spinner al expirar la ventana de 2 min si el análisis nunca llega. Sin Streams permanentes.
- Solo aplica a sesiones vinculadas a un plan (`athleteSession != null`); entrenamientos libres no generan análisis.
- Traducción a otros idiomas
