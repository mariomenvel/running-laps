
Todos los proyectos
RunningLaps



¿Cómo puedo ayudarle hoy?

Has usado 75 % de tu límite semanal
Obtener más uso
Zonas de entrenamiento: plan de implementación Fase 1
Último mensaje hace 21 segundos
Ayuda 2
Último mensaje hace 1 día
Rediseño de tracking
Último mensaje hace 1 día
Identidad visual y significado de colores
Último mensaje hace 2 días
Ayuda 1
Último mensaje hace 2 días
Modo Programar entrenamiento
Último mensaje hace 2 días
Instrucciones
Eres un asistente de desarrollo senior especializado en Flutter, Kotlin/Jetpack Compose y Firebase. Trabajas en el proyecto Running Laps — una app móvil multiplataforma para runners que practican entrenamiento fraccionado (series/intervalos). Reglas de comportamiento: - Siempre lees CLAUDE.md antes de proponer cualquier cambio - Propones cambios mediante prompts para Claude Code, no los haces tú directamente - Antes de cualquier cambio significativo verificas el impacto en iOS, Android y Wear OS - Documentas cambios importantes en CHANGELOG.md - Usas debugPrint() nunca print() - Respetas la arquitectura Feature-First + MVVM estrictamente - Cuando detectas deuda técnica la mencionas pero no la atacas sin confirmación - Eres directo y conciso, no repites información obvia - Cuando algo requiere Xcode o Mac y no está disponible, lo documentas como pendiente - Propones commits cuando hay cambios significativos acumulados Stack técnico: - Flutter/Dart — app móvil (Android + iOS + Web) - Kotlin/Jetpack Compose — app Wear OS independiente - Firebase (Auth, Firestore, Storage, App Check) - ValueNotifier + ValueListenableBuilder para estado (nunca GetX para estado) - feature-first architecture en lib/features/

Archivos
2% de la capacidad del proyecto utilizada

COLOR_SYSTEM.md
212 líneas

md



DESIGN.md
410 líneas

md



ROADMAP.md
376 líneas

md



GPS_Plan_RunningLaps.docx
358 líneas

docx



CHANGELOG.md
244 líneas

md



ARCHITECTURE.md
608 líneas

md



AI_CONTEXT.md
120 líneas

md



CLAUDE.md
270 líneas

md



RunningLaps_Design.pdf
pdf



running_laps_color_system.pdf
pdf



ROADMAP.md
14.15 KB •376 líneas
•
El formato puede ser inconsistente con respecto al original

# Running Laps — Roadmap de desarrollo
> Versión 1.0 · Abril 2026 · Guía de construcción del módulo atleta por fases. Cada fase entrega algo coherente, testeable y sin deuda técnica.

---

## Principios de este roadmap

- **Módulo completo antes de pasar al siguiente** — menos deuda técnica, más fácil de testear
- **Primero los cimientos** — lo que más cosas dependen de ello, primero
- **Free antes que Premium** — construir la base sólida antes de añadir capas avanzadas
- **No romper lo existente** — cada fase es aditiva, nunca destructiva

---

## Fase 0 — Preparación y deuda técnica
> Antes de construir nada nuevo, dejar la base limpia.

### 0.1 Auditoría del analytics hub existente
- Revisar qué estadísticas hay, cuáles tienen valor real y cuáles eliminar
- Rediseñar la organización según el nuevo diseño (ver DESIGN.md §12)
- Objetivo: Analytics que responde preguntas, no que muestra números a lo loco

### 0.2 Mejorar el comparador de entrenamientos equivalentes
- Extender el comparador existente (ya compara series similares)
- Añadir comparativa de métricas: pace real vs objetivo, FC, RPE
- Base para el futuro módulo de progreso

### 0.3 Refactor del creador de plantillas de series
- Añadir campos: pace objetivo, RPE objetivo, zona FC objetivo por serie
- El atleta elige qué métrica(s) activa para cada plantilla
- Base para todo el módulo de planificación

### 0.4 Modelo de datos — nuevas entidades en Firestore
Definir y crear las colecciones necesarias antes de construir las features:
```
users/{uid}/zones           → configuración de zonas del atleta
users/{uid}/plannedSessions → sesiones planificadas en el calendario
users/{uid}/sessionTemplates → plantillas de calentamiento y vuelta a la calma
competitions/{uid}          → competiciones marcadas
weeklyStats/{uid}/{weekId}  → resumen semanal precalculado
```

---

## Fase 1 — Zonas de entrenamiento (Free)
> Cimientos de todo el módulo atleta. Sin zonas, nada más funciona.

### 1.1 Configuración de zonas en Perfil
- Campo FCmáx (manual o detectada automáticamente del primer entreno con FC alta)
- Campo FC reposo (opcional)
- Cálculo automático de 5 zonas por % FCmáx
- Pantalla de resumen de zonas con rangos en ppm

### 1.2 Onboarding progresivo — Momento 1 y 2
- Al registrarse: nombre, fecha nacimiento, sexo biológico (si no está ya)
- Al terminar primer entreno con FC: pedir confirmación de FCmáx

### 1.3 Etiquetado de zonas en entrenamientos existentes
- Al ver el detalle de un entreno pasado, mostrar distribución de tiempo por zona
- Retroactivo: recalcular zona de cada punto GPS con la FCmáx configurada

### Criterio de éxito
El atleta puede configurar su FCmáx y ver su distribución de zonas en cualquier entreno pasado.

---

## Fase 2 — Plantillas de sesión completas ✅
> Extiende el creador de plantillas existente con calentamiento y vuelta a la calma.

### 2.1 Plantillas de calentamiento y vuelta a la calma
- Crear / editar / eliminar plantillas propias
- Plantillas predefinidas de la app (ej: "Calentamiento estándar 15 min")
- Campos: duración, descripción, notas

### 2.2 Sesión completa = calentamiento + principal + vuelta a la calma
- En el creador de plantillas de series, poder asociar calentamiento y vuelta a la calma
- La sesión completa se guarda como una unidad

### 2.3 Métricas de intensidad por serie
- Añadir al creador: pace objetivo (min/km), RPE objetivo (1-10), zona FC objetivo
- El atleta activa las que quiere para esa sesión
- Validación: el pace objetivo debe ser coherente con la zona (warning si no)

### Criterio de éxito
El atleta puede crear una sesión completa con calentamiento, 6×1000m con pace objetivo por serie, y vuelta a la calma.

---

## Fase 3 — Modo atleta y planificación de sesiones

### Descripción
Hub central del atleta. Reemplaza el CalendarView simple
implementado anteriormente. Accesible desde Perfil → "Modo atleta".

### AthleteHubView — pantalla de entrada
- Header explicativo (solo sin datos)
- Resumen semanal cuando hay datos: km · sesiones · % Z1-Z2
- Próximo entrenamiento planificado
- Botón principal "Programar entrenamiento" → AthleteCalendarView
- Botón secundario "Ver análisis" → AnalyticsHubScreen (existente)

### AthleteCalendarView
- StandardTableCalendar reutilizado
- Marcadores por categoría de sesión
- Panel inferior con sesiones del día seleccionado

### SessionEditorView — editor completo de sesión
Estructura de una sesión:
  Calentamiento: texto libre (descripción + duración opcional)
  Parte principal: bloques
  Vuelta a la calma: texto libre (descripción + duración opcional)
  Notas de planificación: texto libre
  Notas de ejecución: texto libre (se rellena al terminar)
  Hora opcional: dispara notificación recordatorio

Tipos de bloque:
  series: reps × distancia, con descanso entre reps
  continuousTime: duración en minutos
  continuousDistance: distancia en metros
  Los bloques mixtos se crean combinando bloques del mismo tipo

Objetivos por bloque (todos opcionales):
  Pace objetivo: rango min-max (ej. 3:45-3:55 /km)
  RPE objetivo: valor único, feedback de proximidad no pass/fail
  Zona FC objetivo: Z1-Z5, solo visible si fcMax configurado

Reps explícitas con registro individual por repetición al ejecutar.

Guardar como plantilla — opciones granulares:
  - Solo calentamiento
  - Solo vuelta a la calma
  - Bloque individual (con o sin objetivos)
  - Todos los bloques (parte principal completa)
  - Sesión completa (calentamiento + principal + vuelta a la calma)

### Tickets
- T1: Modelo AthleteSession + AthleteSessionRepository
      (reemplaza PlannedSession — borrar feature calendar anterior)
- T2: AthleteHubView
- T3: AthleteCalendarView
- T4: SessionEditorView (estructura + campos base)
- T5: SessionBlockEditor (editor de bloques embebido)
- T6: SaveAsTemplateSheet (opciones granulares)
- T7: Limpieza — quitar icono calendario de HomeView,
      añadir "Modo atleta" en ProfileMenuScreen,
      eliminar feature calendar implementada anteriormente

### Dependencias
Fase 1 (zonas) ✅, Fase 2 (plantillas) ✅

---

## Fase 4 — Competiciones y macrociclo (Free)
> La vista larga. Da sentido a todo lo que el atleta ha planificado.

### 4.1 Tipo de sesión "Competición" en el calendario
- Campos adicionales: distancia, nombre de la carrera, objetivo de tiempo (opcional)
- Visualización destacada (color rojo, icono especial)

### 4.2 Comportamiento automático con competiciones
- Contador regresivo en Inicio y Calendario cuando quedan <3 semanas
- Semana previa marcada visualmente como "semana de taper"
- Semana post-competición: sugerencia de recuperación (no invasiva)

### 4.3 Vista de temporada (macrociclo)
- Accesible desde la cabecera del calendario
- Gráfica de carga semanal últimas 16 semanas (coloreada por nivel)
- Barras de distribución de zonas por mes
- Lista de próximas competiciones con contador

### 4.4 Onboarding progresivo — Momento 4
- Al abrir por primera vez la vista de temporada: km objetivo semanales, días/semana

### Criterio de éxito
El atleta puede marcar una competición y ver cómo la app refleja la proximidad de la carrera en todo el calendario.

---

## Fase 5 — Métricas de progreso (Free)
> La respuesta a "¿estoy mejorando?". Requiere historial de las fases anteriores.

### 5.1 Récords personales
- Detección automática en cada entreno con GPS
- Distancias: 400m, 1K, 1 milla, 5K, 10K
- Validación: distancia del entreno ≥ distancia del récord + 10%
- Notificación inmediata al detectar un RP
- Vista en Análisis: tabla de RPs con fecha y delta vs anterior

### 5.2 Mejor pace por zona
- Calculado sobre los últimos 90 días
- Vista en Análisis: barra por cada zona con el mejor pace

### 5.3 Progreso aeróbico
- Pace en Z2: tendencia de las últimas 8 semanas (mínimo 4 sesiones Z2)
- FC en esfuerzo fijo: comparativa mes a mes
- Ratio pace/FC: tendencia 8 semanas (mínimo 4 semanas de histórico)
- Si no hay datos suficientes → ocultar métrica limpiamente, no mostrar error

### 5.4 Resumen semanal en Análisis
- Distribución de zonas histórica (mensual)
- Volumen por semana (gráfica de barras)
- Comparativa con semana anterior y media del último mes

### 5.5 Notificación de mejora aeróbica
- Una vez al mes si hay mejora ≥5ppm en FC o ≥5 seg/km en pace Z2

### Criterio de éxito
El atleta puede responder "¿estoy mejorando aeróbicamente?" mirando la app.

---

## Fase 6 — Notificaciones (Free)
> Ahora que hay datos reales, las notificaciones tienen sentido.

### 6.1 Sistema de notificaciones
- Recordatorio de entreno planificado (1h antes si hay hora)
- Entreno sin completar (22:00)
- Competición próxima (7 días y 1 día antes)
- Récord personal (inmediato)
- Resumen semanal (domingo 20:00)
- Mejora aeróbica detectada (mensual)

### 6.2 Configuración en Perfil → Notificaciones
- Toggle individual para cada notificación
- Todas activadas por defecto

### 6.3 Lógica de límite diario
- Máximo 2 notificaciones por día
- Prioridad: competición > fatiga > logro > recordatorio

### Criterio de éxito
El atleta recibe notificaciones útiles sin sentirse bombardeado.

---

## Fase 7 — Grupos atleta (Free)
> Extiende el componente social con métricas de rendimiento real.

### 7.1 Tipo de grupo en la creación
- Al crear un grupo: elegir "Recreativo" o "Atleta"
- El tipo es permanente (no se puede cambiar después)
- Los grupos existentes se convierten automáticamente en "Recreativos"

### 7.2 Feed y ranking del grupo atleta
- Ranking por volumen semanal (km reales)
- Ranking por progreso aeróbico (ratio pace/FC, variación mensual)
- Comparativa de entrenos equivalentes entre miembros (extender comparador existente)
- Feed con detalle de sesión: tipo, distancia, zonas, pace medio
- RPs del grupo destacados en el feed

### 7.3 Configuración de privacidad por atleta
- En ajustes del grupo: toggles para cada métrica compartida
  - Volumen semanal
  - Distribución de zonas
  - Pace en series
  - Progreso aeróbico
  - Récords personales
  - FC media

### Criterio de éxito
Un grupo de atletas de club puede comparar su progreso real semana a semana.

---

## Fase 8 — Wear OS mejorado (Free)
> Lleva la planificación al reloj. Requiere que las fases 2 y 3 estén completas.

### 8.1 Sincronización de sesión planificada al reloj
- Al abrir el reloj, si hay sesión planificada hoy → sincronizar plantilla completa via Wearable Data Layer API
- El reloj puede iniciar el entreno planificado sin necesidad del móvil

### 8.2 Pantalla de guía durante series
- Serie actual / total
- Distancia de la serie
- Pace objetivo (del atleta) vs pace actual (color: verde / ámbar / rojo)
- FC actual
- Distancia recorrida en la serie
- Vibración al completar la distancia de la serie

### 8.3 Pantalla de descanso
- Cuenta atrás del descanso planificado
- FC recuperando
- Resumen serie recién completada: pace real vs objetivo
- Vibración al terminar el descanso

### 8.4 RPE desde el reloj
- Al terminar el entreno: pantalla de RPE (1-10) directamente en el reloj
- Se sincroniza con el móvil

### Criterio de éxito
El atleta puede salir a correr series dejando el móvil en casa, con el reloj guiándole serie a serie.

---

## Fase 9 — Premium: test de umbral y zonas individualizadas
> Primera feature de pago. Alto valor percibido.

### 9.1 Paywall y gestión de suscripción
- Pantalla de Premium con beneficios claros
- Integración con RevenueCat (o similar) para iOS y Android
- 30 días de prueba gratuita al activar
- Mensual + anual con descuento 20-30%

### 9.2 Test de umbral guiado
- Protocolo: 30 min al máximo esfuerzo sostenible con FC activa
- La app guía al atleta paso a paso durante el test
- Al terminar: calcula FCumbral (media de los últimos 20 min)
- Recalibra automáticamente las 5 zonas con la FCumbral real
- Repetible desde Perfil → Zonas → "Repetir test"

### 9.3 Onboarding progresivo — Momento 5
- Al activar Premium: ofrecer hacer el test (no obligatorio)
- Si lo pospone, recordatorio suave en Perfil

### Criterio de éxito
Un atleta Premium tiene zonas de entrenamiento calibradas con su fisiología real, no con fórmulas genéricas.

---

## Fase 10 — Premium: ATL/CTL/TSB y fatiga
> La joya del módulo atleta. Requiere mínimo 6 semanas de datos.

### 10.1 Cálculo de carga diaria con TRIMP simplificado
- `Carga = duración (min) × factor de zona`
- Factores: Z1=1, Z2=2, Z3=3, Z4=4, Z5=5
- Calculado automáticamente al cerrar cada entreno
- Guardado en `weeklyStats` para eficiencia de lectura

### 10.2 CTL, ATL y TSB
- CTL: media exponencial ponderada 42 días
- ATL: media exponencial ponderada 7 días
- TSB: CTL − ATL
- No mostrar hasta tener mínimo 6 semanas de datos

### 10.3 Vista en Análisis (Premium)
- Gráfica de CTL/ATL/TSB en el tiempo
- Indicador de estado actual: fresco / en forma / cargado / sobreentrenamiento
- Referencia: TSB ideal para competir (+5 a +25)

### 10.4 Notificaciones de fatiga (Premium)
- Carga alta 3 semanas consecutivas → sugerencia de descarga
- TSB < −20 con competición en 14 días → aviso
- Semana <40% del objetivo el jueves → aviso

### Criterio de éxito
El atleta puede saber objetivamente si está en condiciones de competir o si necesita descansar.

---

## Fase 11 — Apple Watch
> Misma experiencia que Wear OS, stack técnico diferente.

### 11.1 App nativa en Swift con WatchKit / SwiftUI
- Mismas pantallas y flujo que Wear OS (ver DESIGN.md §15)
- Comunicación con móvil via WatchConnectivity
- FC y GPS via HealthKit

### 11.2 Paridad de features con Wear OS
- Guía serie a serie con plantilla sincronizada
- Descanso con cuenta atrás y vibración
- RPE al terminar desde el reloj

### Criterio de éxito
Un usuario iOS tiene exactamente la misma experiencia en el reloj que un usuario Android.

---

## Fase 12 — Entrenador IA (Premium — futuro)
> La siguiente gran apuesta del producto. Diseño detallado pendiente.

### Visión general
- La IA analiza el historial del atleta (zonas, carga, progreso, RPE, estado subjetivo)
- Propone la semana de entrenamiento completa adaptada al atleta
- El atleta confirma, ajusta o rechaza cada sesión
- La IA aprende de las respuestas y ajusta futuras propuestas

### Dependencias
- Fases 1-10 completadas (necesita todos los datos)
- Integración con modelo de lenguaje (Claude API)
- Diseño detallado pendiente en sesión específica

---

## Resumen de fases

| Fase | Nombre | Plan | Dependencias |
|------|--------|------|--------------|
| 0 | Preparación y deuda técnica | — | Ninguna |
| 1 | Zonas de entrenamiento | Free | Fase 0 |
| 2 | Plantillas de sesión completas | Free | Fase 0 |
| 3 | Calendario y planificación | Free | Fases 1, 2 |
| 4 | Competiciones y macrociclo | Free | Fase 3 |
| 5 | Métricas de progreso | Free | Fases 1, 3, 4 |
| 6 | Notificaciones | Free | Fases 3, 5 |
| 7 | Grupos atleta | Free | Fase 5 |
| 8 | Wear OS mejorado | Free | Fases 2, 3 |
| 9 | Test de umbral (Premium) | Premium | Fase 1 |
| 10 | ATL/CTL/TSB (Premium) | Premium | Fases 1, 3, 5 |
| 11 | Apple Watch | Free/Premium | Fase 8 |
| 12 | Entrenador IA | Premium | Fases 1-10 |