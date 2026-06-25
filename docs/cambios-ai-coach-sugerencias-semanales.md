# Cambios IA Coach - Sugerencias semanales en calendario

Fecha: 2026-05-27

## Resumen

- Se integra el flujo IA semanal en Calendario.
- La IA decide parametros (`AiCoachWeeklyDecision`) y el plan final se genera por codigo (`AiCoachSessionGenerator`).
- Se mantiene gestion por sugerencias: generar, listar, aceptar, editar, rechazar.

## Cambios funcionales clave

- Boton manual `Generar semana IA` en `Calendario`.
- El boton manual ahora genera en la semana visible en calendario (semana de `selectedDay`), no siempre en la siguiente.
- Regla minima de disponibilidad: si el perfil tiene 3 dias disponibles, el planner completa objetivos hasta ese minimo aunque la IA devuelva menos targets.
- Regla minima ajustada: el minimo solo aplica sobre huecos factibles (dias disponibles y no pasados). Si no hay huecos suficientes, no fuerza sesiones imposibles.
- Refresco de calendario sin perder el mes enfocado tras aceptar/rechazar/generar.
- Restriccion dura de disponibilidad (`availableWeekdays`) en todo el pipeline.
- Restriccion temporal: no generar sesiones en fechas anteriores al dia actual.
- Quality gate antes de guardar:
  - cero sesiones fuera de disponibilidad;
  - limite de carga de calidad;
  - ajuste automatico si falla el gate.

## Fase 2 - Memoria del atleta

- Nuevo modelo `AiCoachAthleteMemory` en `users/{uid}/settings/aiCoachAthleteMemory`.
- Rebuild automatico desde 90 dias de historial si no existe.
- Senales calculadas:
  - aceptacion por categoria IA;
  - cumplimiento por categoria;
  - adherencia por dia;
  - estilo dominante (`continuous_dominant`, `interval_dominant`, `mixed`).
- La planificacion adapta decision con esa memoria:
  - suaviza calidad con baja tolerancia;
  - refuerza estilo dominante;
  - aplica preferencia de dias por adherencia.

## Fase 3 - Automatizacion resiliente

- Nuevo estado `aiCoachAutomation` en `users/{uid}/settings/aiCoachAutomation`.
- Idempotencia por ciclo semanal:
  - si ya se genero el ciclo de semana siguiente, no repite.
- Si ya existe plan para esa semana, marca ciclo como resuelto para evitar duplicados.
- Guarda metadatos de ejecucion:
  - `lastGeneratedCycleId`
  - `lastGeneratedAt`
  - `lastGenerationSource`

## Fase 4 (parcial) - Complejidad premium del generador

- Se mejora `AiCoachSessionGenerator` para escalar complejidad por:
  - nivel atleta (`beginner/intermediate/advanced`);
  - tipo de semana (`build/absorb/recovery/taper/restart/race`).
- Ajustes incorporados:
  - series cortas/largas con distancias, reps y recuperaciones segun tier;
  - tempo avanzado por bloques multiples;
  - fartlek y mixtas con mas estructura en tiers altos;
  - tirada progresiva con bloque final mas exigente en tiers altos.

## Fase 4 - KPIs y transparencia (completado)

- Nuevo snapshot de KPIs `AiCoachKpiSnapshot` persistido en:
  - `users/{uid}/settings/aiCoachKpiLatest`.
- KPIs recalculados sobre ventana reciente (90 dias):
  - `acceptanceRate` (aceptadas+editadas / sugeridas IA),
  - `completionRate` (completadas / planificadas),
  - volumen de sugeridas/aceptadas/editadas/rechazadas,
  - `replansCount` (ediciones del usuario).
- Tras cada `weekly_planner_generated`:
  - se recalcula snapshot KPI;
  - se registra evento `ai_coach_kpi_snapshot`.
- Transparencia en UI:
  - cada sugerencia IA en calendario muestra un "Por que" corto
    usando `focus`, `rationale` o `planningNotes`.

## Archivos tocados

- `lib/features/ai_coach/data/ai_coach_models.dart`
- `lib/features/ai_coach/data/ai_coach_repository.dart`
- `lib/features/ai_coach/data/ai_coach_context_builder.dart`
- `lib/features/ai_coach/data/ai_coach_weekly_planner_service.dart`
- `lib/features/ai_coach/data/ai_coach_automation_service.dart`
- `lib/features/ai_coach/data/ai_coach_session_generator.dart`
- `lib/features/calendar/views/calendar_view.dart`

## Riesgos y limitaciones

- La automatizacion semanal frontend depende de que el usuario abra la app en la ventana de ejecucion.
- Para ejecucion garantizada 24/7, mover automatizacion a backend scheduler.

## Como probar

1. Configurar IA en Perfil -> Entrenador IA.
2. En Calendario, pulsar `Generar semana IA`.
3. Verificar:
   - si estas viendo una semana concreta, se generan en esa semana;
   - sesiones en dias disponibles;
   - sugerencias visibles y accionables;
   - aceptacion/edicion reflejada al instante.
4. Repetir varias semanas:
   - rechazo recurrente de calidad reduce calidad futura;
   - adherencia por dias desplaza propuestas a dias con mejor cumplimiento.

## Ajuste adicional (2026-05-27) - Bloqueos por modo atleta y limite semanal de chat

- Se anade bloqueo duro en servicios IA para exigir `isAthleteMode=true`:
  - `AiCoachWeeklyPlannerService.planNextWeek` (manual y cualquier llamada interna).
  - `AiCoachAutomationService.ensureNextWeekPlanIfDue` (automatico semanal).
  - `AiCoachChatService.adjustNextWeekPlan` (Entrenador IA por chat).
- Si el usuario no esta en modo atleta:
  - la automatizacion se omite sin generar plan;
  - manual/chat lanzan error funcional claro.
- Se implementa limite de `3` consultas de chat por semana en `AiCoachChatService`:
  - se usa `settings/aiCoachUsage` con ventana semanal actual (lunes-domingo);
  - al empezar una nueva semana, reinicia contador;
  - al superar el limite, devuelve error controlado.
- En `AiCoachSettingsView`:
  - se valida modo atleta al abrir (si no, mensaje y salida);
  - se muestra contador `Consultas restantes esta semana: X/3`.

### Archivos tocados en este ajuste

- `lib/features/ai_coach/data/ai_coach_weekly_planner_service.dart`
- `lib/features/ai_coach/data/ai_coach_automation_service.dart`
- `lib/features/ai_coach/data/ai_coach_chat_service.dart`
- `lib/features/ai_coach/views/ai_coach_settings_view.dart`
- `docs/cambios-ai-coach-sugerencias-semanales.md`

## Ajuste adicional (2026-05-27) - Provider IA solo desde Firebase

- La app deja de tomar `apiKey/model` desde `users/{uid}/settings/aiCoachProvider`.
- Ahora los lee desde una coleccion global:
  - `appConfig/aiCoachProvider`
- `AiCoachRepository.getProviderConfig()` pasa a leer exclusivamente ese documento.
- Se elimina el fallback con API key hardcodeada en cliente:
  - `kAiCoachDefaultOpenRouterApiKey = ''`
  - `kAiCoachForceFrontendTesting = false`
- En `Entrenador IA` ya no se guarda configuracion de provider al pulsar guardar.
- La tarjeta OpenRouter se elimina de uso en `Entrenador IA` (queda desactivada en render).
- Se crea/actualiza el documento global en Firestore:
  - `appConfig/aiCoachProvider`
  - `provider=openrouter`
  - `model=nvidia/nemotron-3-super-120b-a12b:free`
  - `apiKey` configurada
  - `weeklyPlanningEnabled=true`
  - `chatAdjustmentsEnabled=true`

### Documento esperado en Firestore

`appConfig/aiCoachProvider`:
- `provider`: `'openrouter'`
- `model`: `'nvidia/nemotron-3-super-120b-a12b:free'` (o el que quieras)
- `apiKey`: `'sk-or-...'`
- `weeklyPlanningEnabled`: `true/false`
- `chatAdjustmentsEnabled`: `true/false`

## Ajuste adicional (2026-06-25) - IDs de modelos OpenRouter

- Se corrigen los IDs hardcodeados usados por las llamadas actuales a OpenRouter:
  - `anthropic/claude-sonnet-4-5` -> `anthropic/claude-sonnet-4.5`
  - `anthropic/claude-haiku-4-5` -> `anthropic/claude-haiku-4.5`
- Archivo modificado:
  - `lib/features/ai_coach/data/ai_coach_models_config.dart`
- Nota tecnica:
  - En el estado actual de `main`, `appConfig/aiCoachProvider` se usa para habilitar/deshabilitar el proveedor, pero las llamadas principales usan `AiCoachModels`.
  - Si se quiere que el modelo de Firestore controle realmente todas las llamadas, hay que cambiar el contrato de `AiCoachDecisionService`, `AiCoachChatService`, onboarding y generador por prompt.
- Riesgo pendiente:
  - Si OpenRouter/Anthropic sigue fallando tras corregir los IDs, revisar el JSON Schema enviado a `response_format`. Los logs previos indicaban rechazo por `minimum`/`maximum` en campos `integer`.
