# Running Laps — Sistema de Entrenamiento
> Documento de producto · Mayo 2026
> Para: equipo de producto, clientes, entrenadores, testers

---

## ¿Qué es Running Laps?

Running Laps es una app para runners que se toman el entrenamiento en serio. Permite planificar cualquier tipo de sesión de carrera, ejecutarla con guía en tiempo real, y analizar los resultados para mejorar progresivamente.

**Tres fases del producto:**

| Fase | Quién la usa | Qué hace |
|---|---|---|
| **Free (ahora)** | El atleta se autoplanifica | Planifica, entrena, analiza métricas |
| **Premium (próximo)** | El atleta con Coach IA | La IA planifica la semana automáticamente según los datos reales |
| **Business (futuro)** | Entrenadores profesionales | Planifican para sus atletas desde una web |

El mismo sistema de entrenamiento sirve para las tres fases. Lo que cambia es quién crea el plan.

---

## Tipos de entrenamiento soportados

Running Laps soporta todos los tipos de sesión habituales en el atletismo de fondo:

### 🟢 Carrera continua
Sesión sin pausas estructuradas. El atleta corre durante un tiempo o distancia determinada a una intensidad objetivo.

**Subtipos incluidos:**
- Rodaje regenerativo (Z1 — muy suave, recuperación activa)
- Rodaje base (Z2 — la base de todo el entrenamiento)
- Tempo / umbral (Z3 — esfuerzo sostenido exigente)
- Tirada larga (Z2, más volumen)
- Progresivo (intensidad creciente)

**Parámetros configurables:**
- Duración (minutos) o distancia (km)
- Pace objetivo o rango de pace (ej: 5:00–5:30/km)
- Zona de FC objetivo (Z1–Z5)
- RPE objetivo (1–10)

---

### 🔴 Series / Intervalos
El tipo de entrenamiento más técnico. Repeticiones de un esfuerzo intenso con recuperación entre ellas. Es el núcleo de la mejora de velocidad y VO2max.

**Ejemplos:**
- 5×1000m a pace de 10K con 90s de trote
- 10×400m a pace de 5K con 60s parado
- 3×2000m en umbral con 3 minutos de trote

**Parámetros configurables:**
- Número de repeticiones (1–99)
- Distancia por serie (metros) o duración (minutos y segundos)
- Tipo de recuperación: activa (trotando) o pasiva (parado/caminando)
- Duración de la recuperación
- Pace objetivo o rango por serie
- Zona de FC objetivo
- RPE objetivo
- Calentamiento estructurado previo
- Vuelta a la calma posterior

---

### 🟠 Fartlek
Entrenamiento mixto con cambios de ritmo. Puede ser uniforme (ej: 10×1 minuto rápido) o variable (ej: 5'-4'-3'-2'-1' con recuperaciones distintas). Más flexible que las series clásicas.

**Ejemplos:**
- Fartlek sueco: 1' rápido / 1' suave durante 30 minutos
- Fartlek piramidal: 5'-4'-3'-2'-1' con recuperación progresiva
- Fartlek libre: cambios de ritmo según sensaciones

**Parámetros configurables:**
- Estructura libre: el usuario añade bloques de esfuerzo y descanso individualmente
- Cada bloque puede tener duración y objetivo diferente
- RPE o zona por bloque

---

### 🟡 Cuestas
Repeticiones en subida para desarrollar fuerza específica y potencia. La recuperación es siempre trotando bajando.

**Ejemplos:**
- 8×100m de cuesta al 8% de pendiente
- 6×200m de cuesta a máxima intensidad

**Parámetros configurables:**
- Número de repeticiones
- Longitud de la cuesta (metros)
- Pendiente estimada (%)
- Intensidad objetivo (RPE o zona)
- La recuperación es siempre activa bajando

---

### 🟣 Competición / Test
Para registrar carreras oficiales o tests cronometrados. Tiene visualización especial en el calendario (morado) y permite configurar un plan de pace por parciales.

**Ejemplos:**
- Carrera de 10K con pacing plan
- Test de 1000m para medir forma
- Media maratón con estrategia por tramos

**Parámetros configurables:**
- Distancia total
- Pace objetivo por km o por tramos
- Objetivo de tiempo total
- Notas de estrategia

---

### ⚪ Libre
Sin estructura. El atleta sale a correr y la app registra todo (GPS, FC, tiempo). Al terminar añade RPE y notas.

---

## Estructura de una sesión

Todas las sesiones (excepto Libre) se componen de hasta 3 partes:

```
┌─────────────────────────────────┐
│  🔵 CALENTAMIENTO               │
│  Rodaje suave · 15 minutos · Z1 │
├─────────────────────────────────┤
│  🔴 BLOQUE PRINCIPAL            │
│  5 repeticiones de:             │
│    → 1000m @ 4:40–4:50/km (Z4) │
│    → 90 seg trote (Z1)         │
├─────────────────────────────────┤
│  🔵 VUELTA A LA CALMA           │
│  Rodaje suave · 10 minutos · Z1 │
└─────────────────────────────────┘
```

**Calentamiento y vuelta a la calma son opcionales** — el atleta los añade si los necesita. Un rodaje base no necesita calentamiento estructurado.

**El bloque principal puede ser complejo.** En un fartlek piramidal, el bloque principal contiene múltiples segmentos de distinta duración. En unas series, se repite N veces el mismo esfuerzo + recuperación.

---

## Objetivos de intensidad — cómo se configura

Cada parte de la sesión puede tener un objetivo de intensidad. El atleta elige cuál prefiere:

| Método | Ejemplo | Cuándo usarlo |
|---|---|---|
| **Pace (ritmo)** | 4:30–4:45/km | Cuando conoces tu ritmo objetivo |
| **Zona de FC** | Z4 (80–90% FCmáx) | Cuando entrenas por pulsaciones |
| **RPE** | 8/10 | Cuando el ritmo varía (cuestas, calor, cansancio) |
| **% FCmáx** | 85% | Alternativa a zonas si no están calibradas |

Se pueden combinar — por ejemplo, pace 4:30/km + Z4 + RPE 8 para una serie de VO2max.

---

## Métricas que devuelve la app

### Durante la sesión
- Ritmo actual (pace en tiempo real, suavizado)
- Distancia acumulada de la serie
- FC en tiempo real (si hay pulsómetro BLE o Wear OS)
- Comparativa vs objetivo (¿estás en rango?)
- Tiempo de descanso en cuenta atrás
- Serie actual / total de series

### Al terminar cada serie
- Pace medio de la serie
- Distancia recorrida
- FC media (si disponible)
- RPE (el atleta lo introduce)
- Comparativa con el objetivo planificado

### Al terminar la sesión
- Resumen completo: tiempo total, distancia, pace medio, FC media
- Serie a serie con datos individuales
- Comparativa planificado vs ejecutado (si venía de una sesión planificada)
- Distribución de tiempo por zonas de FC

### En el historial y analytics
- Récords personales por distancia (400m, 1K, 5K, 10K)
- Progreso de pace en series equivalentes (¿mejoras en el mismo tipo de sesión?)
- Evolución de la FC en esfuerzo fijo (indicador de mejora aeróbica)
- Volumen semanal con tendencia
- Distribución de zonas (¿cuánto tiempo en Z1, Z2, Z3, Z4, Z5?)
- Carga semanal con TRIMP (Premium: ATL/CTL/TSB)

---

## Free vs Premium

> **Estado actual (beta):** todo está disponible de forma gratuita. La separación Free/Premium está diseñada pero el paywall (RevenueCat) no está activo aún.

| Funcionalidad | Free | Premium (diseño) |
|---|---|---|
| Todos los tipos de entrenamiento | ✅ | ✅ |
| Editor de sesiones con bloques | ✅ | ✅ |
| Plantillas reutilizables | ✅ | ✅ |
| GPS + pulsómetro | ✅ | ✅ |
| Historial completo | ✅ | ✅ |
| Récords personales | ✅ | ✅ |
| Analytics básicos | ✅ | ✅ |
| Zonas genéricas (% FCmáx) | ✅ | ✅ |
| **Coach IA semanal** | ❌ | ✅ (ahora free en beta) |
| **ATL/CTL/TSB (fatiga y forma)** | ❌ | ✅ (ahora free en beta) |
| **Generador por prompt (8/mes)** | ✅ | ✅ (60/mes) |
| **Test de umbral individualizado** | ❌ | ✅ (pendiente implementar) |
| **Zonas calibradas por FCumbral** | ❌ | ✅ (pendiente implementar) |

---

## Cómo funciona el Coach IA (Premium)

El Coach IA no es un chatbot. Es un entrenador que trabaja en segundo plano:

1. **El lunes**, analiza la semana anterior: qué hiciste, qué tenías planificado, cómo respondiste, cuál es tu fatiga acumulada.
2. **Genera el plan de la semana** adaptado a tu realidad: si estás cansado, baja el volumen. Si respondiste bien, sube la carga.
3. **El atleta simplemente entrena** — el plan ya está en el calendario.
4. **Se repite cada semana**, adaptándose continuamente.

El atleta define su objetivo una sola vez (mejorar el 10K, preparar una maratón, etc.). La IA hace el resto.

---

## Integración con Wear OS

La app se sincroniza con el reloj Wear OS. Desde el reloj el atleta puede:
- Ver la sesión planificada del día
- Ejecutar entrenamientos con plantilla (bloques, series, descansos)
- Registrar FC en tiempo real
- GPS independiente

Apple Watch está planificado para una fase futura.

---

*Documento de producto Running Laps · Mayo 2026*
