# Premium AI Coach — Especificación

## Visión general
Coach IA personal que actúa como entrenador real de atletismo:
genera planes semanales adaptados, analiza rendimiento y fatiga,
conversa con el atleta y ajusta el plan según evolución.

## Modelo de negocio
- Trial: 30 días gratis al activar premium
- Códigos creador: +30 días gratis adicionales
- Suscripción: precio mensual TBD (estimado 5-10€/mes)
- Ofertas puntuales en momentos clave
- Activación automática al recibir pago

## Cuotas y límites

### Free (sin premium)
- Generador por prompt: 8 generaciones/mes
- Sin Coach IA
- Sin chat

### Premium
- Generador por prompt: 60 generaciones/mes
- Coach IA completo
- Chat con coach (5 turnos por conversación, X conversaciones/mes TBD)
- Regeneración de semana: 5/semana

## Onboarding del Coach

### Cuestionario inicial
1. Objetivo:
   - Salud general
   - Competición 5K/10K (+ fecha)
   - Media Maratón (+ fecha)
   - Maratón (+ fecha)
   - Trail/Ultra (+ fecha + desnivel)
   - Mejora de marca personal sin fecha

2. Disponibilidad:
   - Días/semana (1-7)
   - Días concretos (L-D multi-select)
   - Tiempo por sesión (30/45/60/90/120 min)

3. Estado actual:
   - Km actuales/semana
   - Marcas opcionales: 5K, 10K, HM, M
   - Lesiones/limitaciones (texto libre)
   - Preferencias (asfalto/montaña/pista, intervalos/continuos)

### Conversación post-cuestionario
- Máximo 5 turnos
- IA pregunta dudas: experiencia previa, dolor específico,
  acceso a instalaciones, etc.

## Generación de planes

### Frecuencia
- Modo D (mixto): semanal automático + manual on-demand
- Generación automática: cada domingo para la semana siguiente
- Regeneración manual: límite 5/semana
- Solo se genera semana siguiente (no plan completo de meses)

### Modelo de IA
- Claude Sonnet 4.6 para el Coach (razonamiento complejo)
- Claude Haiku 4.5 para generador por prompt (parsing simple)

### Contexto que se envía a Claude

```json
{
  "athleteProfile": {
    "objetivo": "maraton",
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
    "sueño": "regular",
    "molestias": "Texto opcional",
    "observaciones": "Texto opcional"
  }
}
```

### Análisis de fatiga
El coach detecta automáticamente:
- RPE alto en sesiones que deberían ser fáciles
- Pace muy por debajo del objetivo en varias sesiones
- FC alta en zonas Z2 (signo clásico)
- Sesiones no completadas
- Aumento brusco de carga semanal
- Patrones de cuestionario semanal (sueño, molestias)

## Cuestionario semanal opcional

Cada domingo, opcional (saltable):
1. ¿Cómo te has sentido esta semana? (1-5)
2. ¿Has dormido bien? (sí / regular / mal / no medido)
3. ¿Algún dolor o molestia? (texto opcional)
4. ¿Alguna observación para el coach? (texto opcional)

## Interacción usuario-coach

### Edición de sesiones generadas
- Usuario PUEDE editar/borrar/añadir sesiones del plan
- El coach se "entera" silenciosamente (sin toast inmediato)
- En el siguiente mensaje del coach, comenta el cambio si es relevante
- Se considera feedback implícito para futuras generaciones

### Mensajes del coach
Aparecen en:
- Pantalla de Coaching (antigua Analytics, renombrada)
- Notificación push (importantes)

Momentos:
- Al generar nueva semana (resumen + razones)
- Al detectar feedback relevante
- Al detectar fatiga
- Al final de semana (si cuestionario activado)
- Si usuario inactivo 2+ semanas: "¿Sigues por aquí?"

## Casos especiales

### Cambio de objetivo a mitad de plan
- Solo cambia la siguiente semana (no regenera todo)
- Sin coste adicional al usuario
- Contexto del coach se actualiza

### Lesión declarada en chat
- Coach modifica y adapta el plan automáticamente
- Genera sesiones de recuperación si necesario
- Notifica los cambios al usuario

### Inactividad prolongada
- 2+ semanas sin completar sesiones: mensaje del coach
- El plan sigue generándose mientras se pague
- A las X semanas (TBD) deja de generar automáticamente
- Botón "He vuelto" reactiva la generación

### Fin del plan (objetivo alcanzado)
- No se generan más semanas
- Se quitan todas las ventajas del plan
- No puede chatear ni cuestionario
- Si renueva premium: crea nuevo plan con nuevo objetivo

## Privacidad
- Datos de salud sensibles (FC, RPE, marcas, lesiones) se mandan
  a Claude API vía Cloud Function
- Anthropic no usa estos datos para entrenamiento (política API)
- Cláusula clara en T&C de Premium explicando el flujo
- Usuario puede pedir borrado de su contexto en cualquier momento

## Idiomas
- Empezamos en español
- Detección automática del idioma de la app cuando se traduzca
- Prompts internos a Claude en inglés (mejor calidad)
- Respuesta final en idioma del usuario
