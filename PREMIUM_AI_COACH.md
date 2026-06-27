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
- Traducción a otros idiomas
