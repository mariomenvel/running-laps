# Running Laps — Documento de Diseño
> Versión 1.0 · Abril 2026 · Este documento recoge todas las decisiones de diseño del módulo atleta y la evolución general de la app.

---

## 1. Visión del producto

Running Laps evoluciona de app social de running a herramienta seria para atletas que entrenan de verdad (2-3 días de pista + 2-3 días de carrera continua), sin abandonar su modo recreativo original.

**Principio central:** Una sola app, sin modos ni decisiones forzadas. Cada usuario usa lo que necesita. El recreativo no ve nada raro. El atleta serio tiene todo lo que necesita.

---

## 2. Modelo de producto — 3 capas

### Capa 1 — Free (ahora)
El atleta se autoplanifica. Zonas genéricas. Métricas básicas de progreso.

### Capa 2 — Premium (siguiente gran feature)
Entrenador IA que ayuda a planificar. Test de umbral individualizado. Modelo ATL/CTL/TSB de fatiga.

### Capa 3 — Business (futuro)
Interfaz web para entrenadores reales con sus atletas. La vista del atleta en móvil es la misma desde el principio — solo cambia quién programa los entrenos.

---

## 3. Monetización

- **Modelo:** Freemium puro — Free para siempre, Premium de pago
- **Prueba:** 30 días de Premium gratis al registrarse
- **Ciclos:** Mensual + anual con descuento del 20-30%
- **Precio:** A definir antes del lanzamiento según mercado

---

## 4. Datos disponibles

| Dato | Estado |
|------|--------|
| Ritmo (pace) via GPS | Disponible |
| Distancia | Disponible |
| Descansos entre series | Disponible |
| FC via Wear OS | Disponible |
| FC via pulsómetro BLE en móvil | Próximamente |

---

## 5. Tipos de sesión — taxonomía completa

### Carrera continua
| Tipo | Zona | Descripción | Referencia |
|------|------|-------------|------------|
| Regenerativo | Z1 | Recuperación activa muy suave | 20-40 min post-competición |
| Rodaje base (Z2) | Z2 | El entreno más importante. 70-80% del volumen total | 40-90 min, 2-3 veces/semana |
| Tempo / umbral | Z3 | Esfuerzo sostenido en el umbral láctico | 20-40 min, máx 1 vez/semana |
| Fartlek | Mixto | Cambios de ritmo no estructurados | 30-60 min |

### Series (pista / calle)
| Tipo | Zona | Descripción | Referencia |
|------|------|-------------|------------|
| Series largas | Z4 | VO2max y resistencia a ritmo de competición | 4-8×1000m, 3-5×2000m |
| Series cortas | Z5 | Velocidad pura y potencia neuromuscular | 8-16×200m, 6-10×400m |
| Series en cuestas | Z4 | Fuerza específica sin impacto de velocidad | 8-12×80-150m |
| Series mixtas / progresivas | Mixto | Combinación de distancias o progresión de ritmo | Pirámides, progresivos |

### Especiales
| Tipo | Descripción |
|------|-------------|
| Competición | Carrera oficial. No computa como carga normal. Genera fatiga especial. |
| Test / control | Entreno cronometrado para medir forma y calibrar zonas |
| Gimnasio / fuerza | Sin GPS. Se registra para completar la carga semanal real |

---

## 6. Estructura de una sesión planificada

```
[ Calentamiento ] + [ Parte principal ] + [ Vuelta a la calma ]
```

- Cada bloque es **opcional e independiente**
- Calentamiento y vuelta a la calma: plantilla predefinida de la app o creada por el atleta
- Parte principal: plantilla de series existente con objetivos por serie

### Métricas de intensidad por serie
El atleta elige qué métrica activa para cada sesión:
- **Pace objetivo** (min/km)
- **RPE objetivo** (1-10)
- **Zona de FC objetivo**

Se pueden activar 1, 2 o las 3 simultáneamente. Las no activas quedan como referencia al comparar con lo ejecutado.

### Al terminar la sesión
- Comparativa planificado vs ejecutado (pace, FC, distancia)
- Desglose serie a serie: pace real vs objetivo
- **RPE post-entreno** (1-10)
- **Estado de forma subjetivo:** piernas, energía, sueño
- Opción de marcar como no completado con motivo (lesión, viaje...)

> Los datos de RPE y estado subjetivo se recogen en Free pero se aprovechan en Premium para el modelo ATL/CTL. El usuario Free acumula historial desde el primer día.

---

## 7. Zonas de entrenamiento

### Free — Zonas genéricas por % FCmáx (5 zonas)
| Zona | Nombre | % FCmáx | Uso |
|------|--------|---------|-----|
| Z1 | Regenerativo | <60% | Recuperación activa |
| Z2 | Base aeróbica | 60-70% | Volumen y base |
| Z3 | Umbral | 70-80% | Tempo, resistencia |
| Z4 | VO2max | 80-90% | Series largas |
| Z5 | Máximo | >90% | Series cortas, velocidad |

- FCmáx: el atleta la introduce o la app usa **220 − edad** como fallback
- FC en reposo: opcional, mejora la precisión

### Premium — Zonas individualizadas
- Test de umbral guiado en la app (protocolo de 30 min al máximo esfuerzo sostenible)
- Calcula FCumbral real y recalibra las 5 zonas individualmente
- Repetible desde ajustes cuando el atleta quiera

---

## 8. Calendario y planificación

### Vista principal
- **Semanal por defecto** (lunes a domingo)
- Cambio a **vista mensual** opcional
- **Vista de temporada** (macrociclo) accesible desde el calendario

### Código de colores del calendario
| Estado | Color |
|--------|-------|
| Completado | Verde |
| Planificado | Azul (borde discontinuo) |
| Competición | Rojo |
| No completado | Gris tachado |

### Resumen semanal en cabecera
- Volumen total (km) vs objetivo
- % en Z1-Z2 vs % en Z3-Z5
- Sesiones completadas / planificadas

### Al crear una sesión futura
1. Elegir tipo de sesión de la taxonomía
2. Asociar plantilla de series (existente o nueva)
3. Añadir calentamiento y vuelta a la calma
4. Elegir métrica de intensidad objetivo
5. Añadir notas libres

---

## 9. Macrociclo y vista de temporada

**Principio:** El atleta no configura el macrociclo — la app lo detecta e informa. Sin estructura impuesta. El atleta simplemente entrena y la app le muestra patrones.

### Vista de temporada muestra
- Gráfica de carga semanal (últimas 16 semanas): baja / media / alta / taper / competición
- Distribución de zonas por mes (barras apiladas Z1→Z5)
- Próximas competiciones con contador de días

### Comportamiento con competiciones
**Lo que hace automáticamente:**
- Ancla visual en el calendario desde semanas antes
- Contador regresivo cuando quedan menos de 3 semanas
- Marca la semana previa como "semana de taper" visualmente
- Post-competición: sugiere semana de recuperación

**Lo que NO hace (respeta autonomía):**
- No modifica ni borra sesiones planificadas
- No obliga a ningún protocolo de taper
- No genera alertas invasivas
- El atleta puede ignorar todas las sugerencias

---

## 10. Métricas de progreso

### Bloque 1 — Mejora aeróbica (Free)

| Métrica | Qué mide | Horizonte | Condición de validez |
|---------|----------|-----------|----------------------|
| Pace en Z2 | Velocidad a misma FC | Tendencia 8 semanas | Mínimo 4 sesiones Z2 en el período |
| FC en esfuerzo fijo | Eficiencia cardíaca | Comparativa mes a mes | Condiciones similares de temperatura |
| Ratio pace/FC | Eficiencia aeróbica combinada | Tendencia 8 semanas | Mínimo 4 semanas de histórico |

> Fórmula ratio: `pace (s/km) ÷ FC media × 100`

### Bloque 2 — Rendimiento en alta intensidad (Free)

- **Récords personales** por distancia estándar (400m, 1K, 1 milla, 5K, 10K)
  - Detectados automáticamente en entrenamientos con GPS activo
  - Solo válidos si distancia del entreno ≥ distancia del récord + 10%
  - Vista: histórico total + últimos 90 días
- **Mejor pace por zona** en los últimos 90 días

### Bloque 3 — Fatiga y carga (Premium)

| Métrica | Descripción | Período |
|---------|-------------|---------|
| CTL (Forma crónica) | Carga media acumulada. Representa el fitness | 42 días |
| ATL (Fatiga aguda) | Carga reciente. Sube rápido, baja con descanso | 7 días |
| TSB (Estado de forma) | CTL − ATL. Positivo = fresco. Ideal competir: +5 a +25 | — |

**Cálculo de carga — TRIMP simplificado:**
`Carga = duración (min) × factor de zona`

| Zona | Factor |
|------|--------|
| Z1 | 1 |
| Z2 | 2 |
| Z3 | 3 |
| Z4 | 4 |
| Z5 | 5 |

> No requiere potencia ni lactato. Solo FC y tiempo. Científicamente sólido con los datos disponibles.

**No mostrar ATL/CTL/TSB hasta tener mínimo 6 semanas de datos.**

### Principio de validez
La app nunca muestra un estado vacío ni un número incorrecto. Si faltan datos, usa un fallback razonable o oculta el módulo limpiamente.

| Módulo | Dato mínimo | Sin el dato |
|--------|-------------|-------------|
| Zonas de FC | FCmáx | Usa 220−edad |
| Ratio pace/FC | 4 semanas de datos | Oculta la métrica |
| Contador competición | Competición en calendario | No aparece |
| Dashboard semanal % | Volumen objetivo | Muestra absolutos sin % |
| ATL/CTL/TSB | 6 semanas de datos | Oculta el módulo |

---

## 11. Onboarding progresivo

La app pide los datos cuando los necesita. Sin wizard inicial. Sin formularios largos.

| Momento | Qué se pide | Plan |
|---------|-------------|------|
| Al registrarse | Nombre, fecha nacimiento, sexo biológico | Free |
| Primer entreno con FC | FCmáx real (o confirmar detectada), FC reposo | Free |
| Primera sesión planificada | Distancia principal, competición próxima (opcional) | Free |
| Primera vez en vista temporada | Km semanales objetivo, días de entreno/semana | Free |
| Al activar Premium | Test de umbral guiado (opcional, puede hacerse después) | Premium |
| Siempre en ajustes | Todo lo anterior editable en cualquier momento | Free |

---

## 12. Navegación y estructura de pantallas

### Pestañas principales
```
Inicio · Calendario (nuevo) · Entrenar · Análisis · Perfil
```

### Contenido por pestaña

**Inicio** — Dashboard del día
- Feed de actividad y grupos (existente)
- Próximo entreno planificado (nuevo)
- Resumen de la semana: km, zonas, sesiones (nuevo)
- Contador de competición si hay (nuevo)

**Calendario** — Pestaña nueva, corazón del módulo atleta
- Vista semanal / mensual / temporada
- Crear y editar sesiones planificadas
- Gestión de plantillas
- Competiciones marcadas

**Entrenar** — Iniciar sesión
- Iniciar entreno libre (existente)
- Iniciar entreno planificado — carga plantilla del calendario (nuevo)
- Creador de plantillas de series (existente, mejorado)
- RPE y estado de forma al terminar (nuevo)

**Análisis** — Historial + progreso
- Historial de entrenamientos (existente, mejorar organización)
- Progreso aeróbico: pace Z2, FC, ratio (nuevo)
- Récords personales (nuevo)
- Mejor pace por zona (nuevo)
- Distribución de zonas histórica (nuevo)
- ATL/CTL/TSB (nuevo, Premium)
- Comparador de entrenamientos equivalentes (existente, mejorar)

**Perfil** — Datos y configuración
- Datos personales (existente)
- FCmáx, FC reposo y zonas de entrenamiento (nuevo)
- Volumen objetivo semanal y distancia principal (nuevo)
- Test de umbral (nuevo, Premium)
- Notificaciones — toggles individuales (nuevo)
- Ajustes generales (existente)

---

## 13. Notificaciones

**Actitud:** Moderada. Máximo 2 notificaciones por día. Prioridad: competición > fatiga > logro > recordatorio.

Todas configurables individualmente desde Perfil → Notificaciones.

### Planificación (Free)
- **Recordatorio de entreno:** 1h antes si el atleta puso hora
- **Entreno sin completar:** 22:00 si hay sesión sin marcar
- **Competición próxima:** 7 días antes y 1 día antes

### Progreso y logros (Free)
- **Récord personal:** Inmediatamente al detectarlo
- **Resumen semanal:** Domingo 20:00
- **Mejora aeróbica detectada:** Una vez al mes si mejora ≥5ppm o ≥5 seg/km

### Fatiga (Premium)
- **Carga alta acumulada:** Tras 3 semanas consecutivas de carga alta
- **TSB muy negativo:** Cuando TSB < −20 con competición en los próximos 14 días
- **Semana muy por debajo del objetivo:** Jueves si llevas <40% del objetivo semanal

---

## 14. Grupos

### Grupo recreativo (existente, mantener)
- Retos de grupo y gamificación
- Feed de actividad compartida
- Ranking por distancia semanal / mensual
- Logros y badges
- Sin pace, FC ni zonas visibles

### Grupo atleta (nuevo)
- Ranking por volumen semanal real (km)
- Ranking por progreso aeróbico (quién mejora más su ratio pace/FC)
- Comparativa de entrenos equivalentes (pace en series similares entre miembros)
- Feed con detalle de sesiones (tipo, distancia, zonas)
- RPs del grupo destacados

### Privacidad en grupos atleta
Cada atleta configura qué comparte desde ajustes del grupo:
- Volumen semanal
- Distribución de zonas
- Pace en series
- Progreso aeróbico (ratio pace/FC)
- Récords personales
- FC media de los entrenamientos

> Un atleta puede estar en ambos tipos de grupo simultáneamente.

---

## 15. Integración con relojes

### Principio de diseño
Misma experiencia de usuario en Wear OS y Apple Watch. Solo cambia el stack técnico.

**Colores en el reloj:**
- Morado → identidad de marca, UI general, etiquetas
- Verde → en zona / cumpliendo objetivo
- Ámbar → atención, cerca del límite
- Rojo → fuera de zona / por encima del objetivo

### Pantallas durante el entreno

**Durante serie (con plantilla):**
- Número de serie actual / total
- Distancia de la serie
- Pace objetivo
- Pace actual (color según cumplimiento)
- FC actual
- Distancia recorrida en la serie

**Durante descanso:**
- Cuenta atrás del descanso planificado
- FC recuperando
- Resumen de la serie recién completada vs objetivo

**Rodaje libre (sin series):**
- Tiempo total
- Pace actual
- FC actual
- Distancia
- Indicador de zona actual

**Fin del entreno:**
- Pace medio por serie
- Series completadas vs planificadas
- RPE post-entreno (1-10) directamente desde el reloj

### Flujo del reloj con sesión planificada
1. Al abrir el reloj → propone la sesión planificada de hoy si existe
2. Calentamiento → métricas normales sin objetivo de pace
3. Series → guía en tiempo real serie a serie con vibración al completar
4. Descanso → cuenta atrás con vibración al terminar
5. Vuelta a la calma → métricas normales
6. Fin → resumen + RPE

### Diferencias técnicas
| | Wear OS | Apple Watch |
|--|---------|-------------|
| Estado | Base existente en Kotlin | Por construir en Swift |
| Comunicación | Wearable Data Layer API | WatchConnectivity framework |
| FC y GPS | Sensores del reloj / móvil | HealthKit |
| Pendiente | Recibir plantilla + lógica de guía | Todo desde cero |

---

## 15b. Modo atleta — decisiones de diseño

### Acceso
Perfil → "Modo atleta". Sin acceso desde HomeView.

### AthleteHubView
Pantalla de entrada, no el calendario directamente.
Sin datos: texto explicativo.
Con datos: resumen semanal + próximo entreno + botones de acción.

### Editor de sesión
El atleta diseña la sesión desde cero o parte de una plantilla
guardada que puede modificar libremente.

Calentamiento y vuelta a la calma: texto libre con duración.
Guardables como plantillas independientes.

Bloques de parte principal:
- series: reps × distancia + descanso
- continuousTime: N minutos en zona/pace objetivo
- continuousDistance: N metros en zona/pace objetivo

Pace objetivo: siempre un rango (min-max), no valor exacto.
RPE objetivo: valor único, el sistema muestra proximidad al terminar.
Zona FC objetivo: visible solo si fcMax está configurado.

Reps: explícitas por bloque. Al ejecutar, el atleta puede
registrar resultado real por repetición individual.

### Dos notas separadas
Notas de planificación: intención, contexto, condiciones previstas.
Notas de ejecución: sensaciones, desviaciones, condiciones reales.
Ambas opcionales. Ambas editables en cualquier momento.

### Guardar como plantilla
Opciones granulares al guardar:
calentamiento solo · vuelta a la calma sola · bloque solo ·
bloque+objetivos · parte principal completa · sesión completa.

### Analytics desde Modo atleta
Enlaza a AnalyticsHubScreen existente hasta Fase 5.
Fase 5 rediseñará el hub con métricas útiles reales:
  Sin FC: récords personales, progreso pace en series equivalentes,
          volumen con media móvil, planificado vs ejecutado,
          RPE vs pace (misma serie a RPE menor = mejora)
  Con FC: eficiencia aeróbica pace/FC, cardiac decoupling,
          ATL/CTL/TSB (Fase 10)

---

## 16. Pendientes conscientemente aparcados

- **Analytics hub:** Ver código existente antes de diseñar la mejora
- **Temperatura y FC:** Afecta la validez de métricas de FC. Aparcado para más adelante
- **Entrenador IA Premium:** Fase futura
- **Interfaz web del entrenador (Business):** Fase futura
- **Precio exacto del Premium:** A definir cerca del lanzamiento