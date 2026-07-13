# WORKOUT_EDITOR_UX.md — Editor de Sesiones y Plantillas
> Running Laps · Versión 1.0 · Mayo 2026
> UX spec del editor de bloques. Para diseñadores, desarrolladores y testers.
> Referencia visual: DESIGN.md · Colores: COLOR_SYSTEM.md

---

## 1. Contexto y puntos de entrada

El editor (`WorkoutEditorScreen`) se usa en varios contextos que comparten la misma UI:

| Contexto | Dónde se abre | Qué se guarda |
|---|---|---|
| **Crear/editar sesión planificada** | Calendario → día vacío o sesión existente | `users/{uid}/athleteSessions/{id}` via `AthleteSessionRepository` |
| **Editar sesión del Coach IA** | Calendario → sesión generada → Editar | `users/{uid}/athleteSessions/{id}` (sobreescribe) |
| **Crear plantilla** | Perfil → Mis plantillas → "+" | callback `onSave` — la pantalla llamante gestiona el repositorio |
| **Quick start** | TrainingStartView (`isQuickStart: true`) | callback `onSave` — arranca ejecución directa |

**Lógica de guardado:**
- Si viene del calendario (`shellParams != null` o `scheduledDate != null`) → convierte `WorkoutSession → AthleteSession` via mapper y guarda en `athleteSessions`
- Si no → llama al callback `onSave(WorkoutSession)` y la pantalla llamante decide qué hacer

El editor puede abrirse **precargado** con:
- Una `AthleteSession` existente (mapper convierte a `WorkoutSession` para edición)
- Una `WorkoutSession` directa (plantilla, quick start)
- Vacío (nueva sesión desde cero)

---

## 2. Flujo completo del editor

```
Punto de entrada
      ↓
[1] Selección de tipo de entrenamiento
      ↓
[2] Nombre de la sesión (opcional, tiene default)
      ↓
[3] Construcción de bloques
      │
      ├── [3a] Añadir calentamiento (opcional)
      ├── [3b] Configurar bloque principal
      │         ├── Número de repeticiones
      │         └── Segmentos (esfuerzo + descanso)
      ├── [3c] Añadir bloques adicionales (opcional, tipo custom)
      └── [3d] Añadir vuelta a la calma (opcional)
      ↓
[4] Revisión — vista resumen de la sesión completa
      ↓
[5] Guardar
```

El flujo no es lineal obligatoriamente. El atleta puede saltar entre pasos. El botón "Guardar" está siempre disponible aunque la sesión esté incompleta (mínimo: 1 bloque main con 1 segmento).

---

## 3. Pantalla 1 — Selección de tipo

### Layout
```
┌────────────────────────────────┐
│ ←   Nueva sesión               │
│                                │
│  ¿Qué tipo de sesión?          │
│                                │
│  ┌──────────┐  ┌──────────┐   │
│  │ 🟢       │  │ 🔴       │   │
│  │ Continua │  │  Series  │   │
│  └──────────┘  └──────────┘   │
│                                │
│  ┌──────────┐  ┌──────────┐   │
│  │ 🟠       │  │ 🟡       │   │
│  │ Fartlek  │  │ Cuestas  │   │
│  └──────────┘  └──────────┘   │
│                                │
│  ┌──────────┐  ┌──────────┐   │
│  │ 🟣       │  │ ⚪       │   │
│  │Competición│  │  Libre  │   │
│  └──────────┘  └──────────┘   │
│                                │
└────────────────────────────────┘
```

### Comportamiento
- Grid 2 columnas con cards cuadradas.
- Al seleccionar: la card se marca con borde `AppColors.brand` 1.5px + fondo `brand.withOpacity(0.08)`.
- Solo una selección posible.
- Al seleccionar, aparece la siguiente sección con `AnimatedSwitcher` (no navega a nueva pantalla).
- El tipo `Libre` salta directamente al paso de nombre + guardar (sin bloques).

### Título — auto-generación inteligente

Si el atleta no edita el nombre manualmente, el título se genera desde el contenido al guardar:

| Condición | Título generado |
|---|---|
| intervals/hills + distancia | `"5×1000m"` / `"8×100m"` |
| intervals/hills + tiempo | `"5×3'30\""` |
| continuous + distancia | `"Rodaje 8km"` |
| continuous + tiempo | `"Rodaje 45 min"` |
| fallback | nombre default del tipo (ver abajo) |

| Tipo | Nombre default (fallback) |
|---|---|
| `continuous` | "Rodaje base" |
| `intervals` | "Series" |
| `fartlek` | "Fartlek" |
| `hills` | "Cuestas" |
| `competition` | "Competición" |
| `free` | "Sesión libre" |

---

## 4. Pantalla 2 — Nombre de la sesión

### Layout
```
Nombre de la sesión

[  Series 5×1000m          ]   ← TextField editable
   (default según tipo)

(el cursor aparece al tocar, teclado)
```

### Comportamiento
- El nombre es editable en cualquier momento.
- Si el atleta no lo toca, se queda el default.
- Solo aparece teclado aquí y en el campo de notas. Todo lo demás es `NumberPickerField`.
- Longitud máxima: 60 caracteres.

---

## 5. Pantalla 3 — Constructor de bloques (núcleo del editor)

Esta es la pantalla principal. Muestra la sesión como una lista vertical de bloques.

### Layout general
```
┌────────────────────────────────────┐
│ ←   Series 5×1000m           💾   │  ← header con nombre editable + guardar
├────────────────────────────────────┤
│                                    │
│  [+ Añadir calentamiento]          │  ← si no existe, botón fantasma
│                                    │
│  ┌──────────────────────────────┐  │
│  │ 🔴 BLOQUE PRINCIPAL          │  │
│  │ 5 repeticiones               │  │
│  │                              │  │
│  │  ● 1000m · 4:40–4:50/km     │  │  ← segmento interval
│  │  〰 90 seg · Trote (Z1)     │  │  ← segmento recovery
│  │                              │  │
│  │  [+ Añadir segmento]        │  │
│  └──────────────────────────────┘  │
│                                    │
│  [+ Añadir bloque]                 │  ← bloque adicional tipo custom
│                                    │
│  [+ Añadir vuelta a la calma]      │  ← si no existe
│                                    │
│         [GUARDAR SESIÓN]           │
└────────────────────────────────────┘
```

### Cards de bloque

Cada bloque es una card con:
- **Header:** icono de color + rol (`CALENTAMIENTO` / `BLOQUE PRINCIPAL` / `VUELTA A LA CALMA`) en `labels MAYÚSCULAS` (letterSpacing 1.2, w500–w600).
- **Selector de repeticiones** (solo en bloque `main` y `custom`): `NumberPickerField` inline — "5 repeticiones".
- **Lista de segmentos** dentro del bloque.
- **Botón "Añadir segmento"** al final de la lista de segmentos.
- **Botón eliminar bloque** (icono trash, `textSecondary`, esquina superior derecha). Con `AlertDialog` de confirmación.
- **Drag handle** para reordenar bloques (solo entre bloques del mismo nivel — no se puede poner el cooldown antes del main).

### Colores de bloque por rol

| Rol | Color header | Icono |
|---|---|---|
| `warmup` | `AppColors.rest` (azul) | ❄ o 🌊 |
| `main` | `AppColors.effort` (coral) | ⚡ o 🔴 |
| `cooldown` | `AppColors.rest` (azul) | 🌊 |
| `custom` | `AppColors.brand` (morado) | ➕ |

### Chips de segmento

Cada segmento se muestra como una fila compacta:
```
● 1000m · 4:40–4:50/km · Z4 · RPE 8     [✏] [🗑]
〰 90 seg · Trote (Z1)                   [✏] [🗑]
```

- `●` para interval, `〰` para recovery.
- El color del chip de objetivo usa el sistema de colores: pace en `brand`, zona en color de zona, RPE con `effortColor(rpe)`.
- Tap en la fila abre el **editor de segmento** (bottom sheet).
- `[✏]` abre el editor de segmento.
- `[🗑]` elimina con confirmación inline (no AlertDialog, solo undo snackbar).
- Los segmentos se pueden reordenar dentro del bloque con drag.

---

## 6. Editor de segmento — Bottom Sheet

Al tocar un segmento o "Añadir segmento", aparece un bottom sheet.

### Layout — Segmento de esfuerzo (interval)

```
─────────────────────────────────
  Segmento de esfuerzo

  Tipo
  [● Esfuerzo]  [〰 Descanso]

  Medida
  [● Por distancia]  [○ Por tiempo]

  Distancia
  [  1000  ] m       ← NumberPickerField

  ────── OBJETIVO (opcional) ──────

  Pace                 [min/km] [s/100m]   ← toggle de unidad (persistido)
  [ 4 min ] [ 40 seg ] – [ 4 min ] [ 50 seg ]  /km
                                        ← si iguales = pace exacto
  (modo s/100m: [ 28.0 ] – [ 29.0 ]  s/100m — para atletas de pista;
   pasos de 0.5 s/100m = 5 s/km, se convierte a seg/km por detrás)

  Zona de FC
  [Z1] [Z2] [Z3] [Z4★] [Z5]          ← selector horizontal

  RPE
  ━━━━━━━━━━━━●━━━━  8                ← slider effortColor(8)

  [GUARDAR SEGMENTO]
─────────────────────────────────
```

### Layout — Segmento de descanso (recovery)

```
─────────────────────────────────
  Segmento de descanso

  Tipo
  [○ Esfuerzo]  [● Descanso]

  Duración
  [ 1 min ] [ 30 seg ]                ← NumberPickerField

  Tipo de descanso
  [● Activo — trotando]
  [○ Pasivo — parado / caminando]

  Objetivo (opcional)
  Zona: [Z1★] [Z2] [Z3] [Z4] [Z5]

  [GUARDAR SEGMENTO]
─────────────────────────────────
```

### Reglas del bottom sheet
- Se puede cambiar el tipo (interval ↔ recovery) en el mismo sheet.
- El objetivo es siempre opcional — el atleta puede guardar un segmento sin objetivo.
- Al cambiar "Por distancia" ↔ "Por tiempo", el valor se resetea.
- NumberPickerField: nunca teclado numérico. CupertinoPicker para todos los valores numéricos.
- El pace se introduce como dos NumberPickerField: minutos + segundos (igual que en `TrainingStartView`). Toggle de unidad `min/km` / `s/100m` en la cabecera de la tarjeta PACE: en modo s/100m se muestra una única rueda por límite (12.0–54.5, pasos de 0.5) y el valor se convierte a seg/km al vuelo — el modelo (`TargetConfig.paceMinSecPerKm`) no cambia. La preferencia se persiste en `SettingsService.getPacePer100()`.
- La zona se selecciona con chips horizontales, uno activo a la vez.
- RPE con slider `effortColor(rpe)` dinámico.

---

## 7. Configuración específica por WorkoutType

El editor adapta sus opciones según el tipo de sesión seleccionado en el paso 1.

### intervals — Series
- El bloque `main` muestra el selector de repeticiones (1–99).
- Por defecto: 1 segmento interval + 1 segmento recovery.
- El bottom sheet sugiere "Por distancia" como default.

### continuous — Rodaje continuo
- El bloque `main` tiene `repetitions` fijo a 1 (no se muestra el selector).
- Solo 1 segmento de tipo interval. No se pueden añadir segmentos recovery.
- El bottom sheet sugiere "Por tiempo" como default.

### fartlek — Fartlek
- El bloque `main` tiene `repetitions` fijo a 1.
- Se pueden añadir segmentos alternando interval y recovery libremente.
- El bottom sheet no tiene default — el atleta elige.

### hills — Cuestas
- El bloque `main` muestra el selector de repeticiones.
- Los segmentos recovery se crean siempre con `recoveryType: active` (trotando bajando). No se puede cambiar a pasivo.
- El bottom sheet para recovery muestra "Bajando" como label fijo (no el selector activo/pasivo).

### competition — Competición
- No tiene constructor de bloques estándar.
- Muestra un editor simplificado: distancia total + objetivo de tiempo + pace plan opcional por km.
- Badge especial en el calendario (morado).

---

## 8. Vista resumen antes de guardar

Antes de guardar, el atleta ve un resumen legible de la sesión completa:

```
┌────────────────────────────────┐
│ Series 5×1000m                 │
│ Tipo: Series · ~45 min total   │
│                                │
│ ❄ Calentamiento                │
│   15 min · Z1                  │
│                                │
│ ⚡ 5 × Bloque principal        │
│   1000m @ 4:40–4:50/km (Z4)   │
│   + 90 seg trote (Z1)         │
│                                │
│ 🌊 Vuelta a la calma           │
│   10 min · Z1                  │
│                                │
│ Duración estimada: 43 min      │
│ Distancia estimada: ~8.5 km    │
│                                │
│ [✏ SEGUIR EDITANDO]            │
│ [💾 GUARDAR SESIÓN]            │
└────────────────────────────────┘
```

La duración y distancia estimadas se calculan:
- Calentamiento/cooldown: por tiempo o pace estimado de Z1/Z2.
- Bloque main: `repetitions × (duracionInterval + duracionRecovery)`.
- Si no hay datos suficientes para estimar: mostrar solo "~X min".

---

## 9. Panel de generación por IA

El editor incluye un panel desplegable (`WorkoutAiPanelViewModel`) para generar bloques mediante prompt de texto libre:

```
┌────────────────────────────────────┐
│ ✨ Generar con IA     [▼ expandir] │
│                                    │
│ [  Describe el entrenamiento...  ] │ ← TextField, máx 500 chars
│                      [GENERAR →]   │
└────────────────────────────────────┘
```

### Comportamiento
- Usa `AiCoachPromptSessionGenerator` → Claude Haiku 4.5 via OpenRouter (rápido, parsing simple)
- Al generar, carga los bloques directamente en el editor — el atleta revisa y edita antes de guardar
- Solo disponible si `isAthleteMode == true` y Coach IA habilitado (`weeklyPlanningEnabled`)

### Cuotas (diseño, pendiente activar con paywall)
- Free: 8 generaciones/mes
- Premium: 60 generaciones/mes
- Reset el día 1 de cada mes

### Ejemplo de prompt
```
"Ponme un calentamiento de 2km, luego 4×400m a 4:30 con 90
segundos de descanso, y 1km de vuelta a la calma a RPE 5"
```

Output esperado: `WorkoutSession` con warmup 2000m + main 4× (400m pace 4:30 + 90s rest) + cooldown 1000m RPE 5.

### Errores
- Sin conexión → mensaje claro, no genera
- Cuota agotada → mensaje de límite alcanzado
- API error → reintento automático 1 vez, luego mensaje manual
- Respuesta inválida → mensaje + reintentar

### Pendiente
- Botón micrófono (transcripción STT via `SpeechToTextService`) — diseñado, no implementado en el editor

> **Nota:** La función "Guardar también como plantilla" (checkbox) está diseñada pero no implementada. Las plantillas se crean desde Perfil → Mis plantillas de forma independiente.

---

## 10. Estados vacíos y errores

### Sesión sin bloques
No se permite guardar. El botón "Guardar" está deshabilitado con texto `textSecondary`. El atleta ve el mensaje:
```
Añade al menos un bloque para guardar la sesión.
```

### Segmento sin distancia ni tiempo
No se permite guardar el segmento. El botón "Guardar segmento" deshabilitado con mensaje:
```
Introduce la distancia o duración del segmento.
```

### Nombre vacío
Permitido — se usa el nombre default del tipo de entrenamiento.

### Discard changes
Al cerrar el editor con cambios sin guardar, `AlertDialog` de confirmación:
```
¿Salir sin guardar?
Los cambios se perderán.
[Salir]  [Seguir editando]
```

### ✅ Corregido — botón "Guardar sesión" sin estado sucio/limpio

Antes, `_onSave()` no comprobaba nunca `_hasChanges()`: al editar una sesión existente sin tocar nada, el botón "Guardar sesión" reescribía igualmente el documento en Firestore y no daba ninguna señal visual de que no había cambios reales — se sentía como un tap que "no hacía nada".

Ahora el botón principal escucha en vivo los 5 `ValueNotifier` que ya comparaba `_hasChanges()` (tipo, título, bloques, hora, notas) vía `AnimatedBuilder` + `Listenable.merge`:

- **Editando una sesión existente sin cambios:** botón en gris neutro (`AppColors.surface2Of`), texto **"Sin cambios"**. Al pulsarlo cierra la pantalla al instante (`_navigateBack()`), sin escritura a Firestore.
- **Con algún cambio real:** vuelve a `AppColors.brand`, texto **"Guardar sesión"**, comportamiento normal (persiste y cierra).
- **Sesión nueva sin bloques:** sigue bloqueado como antes (`disabled`), independientemente del estado de cambios.

---

## 11. Accesibilidad y usabilidad

- Todos los valores numéricos con `NumberPickerField` (CupertinoPicker) — nunca teclado.
- Teclado solo para: nombre de sesión y notas.
- Targets de toque mínimo: 44×44pt en todos los botones.
- Drag para reordenar: handle visible (6 puntos verticales, color `iconMuted`).
- El editor funciona en scroll vertical. Los bloques pueden ocupar más de una pantalla.
- En Wear OS: el editor NO está disponible. Solo ejecución de sesiones ya creadas desde el móvil.
- El editor es completamente funcional offline. Guarda localmente y sincroniza cuando hay conexión.

---

## 12. Integración con el resto de la app

### Desde el Calendario
- Día vacío → tap → "Añadir sesión" → abre editor en modo `plannedSession`.
- Sesión existente → tap → `SessionDetailView` → botón "Editar" → abre editor precargado.

### Desde Training Start (isQuickStart)
- Editor abre con `isQuickStart: true` — al guardar, lanza directamente la ejecución sin navegar al calendario.
- "Cargar plantilla" → `TemplatesListView` → seleccionar → precarga el editor.

### Desde el Coach IA (Premium)
- La IA genera la sesión. El atleta la ve en el calendario.
- Tap en la sesión IA → `SessionDetailView` con badge "✨ Generada por IA".
- Botón "Editar" → abre editor precargado con los bloques de la IA, editables.

### Desde Wear OS
- `TemplatePickerScreen` lista las plantillas.
- No hay editor en Wear OS — solo selección y ejecución.

---

*Documento UX Running Laps · Mayo 2026. Actualizar cuando cambien flujos del editor o se añadan nuevos tipos de entrenamiento.*
