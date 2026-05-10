# WORKOUT_EDITOR_UX.md — Editor de Sesiones y Plantillas
> Running Laps · Versión 1.0 · Mayo 2026
> UX spec del editor de bloques. Para diseñadores, desarrolladores y testers.
> Referencia visual: DESIGN.md · Colores: COLOR_SYSTEM.md

---

## 1. Contexto y puntos de entrada

El editor se usa en dos contextos que comparten la misma UI base:

| Contexto | Dónde se abre | Qué se guarda |
|---|---|---|
| **Crear sesión planificada** | Calendario → día vacío → "Añadir sesión" | `plannedSessions/{id}` |
| **Crear / editar plantilla** | Perfil → Mis plantillas → "+" o editar existente | `templates/{id}` |

En ambos casos el editor es **el mismo widget**. La diferencia está en el título de la pantalla y en qué repositorio se llama al guardar.

Adicionalmente, el editor puede abrirse **precargado** con:
- Una plantilla existente (duplicar o usar como base)
- Una sesión generada por el Coach IA (solo lectura inicialmente, editable si el atleta quiere modificarla)

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

### Nombre default por tipo

| Tipo | Nombre default |
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

  Pace
  [ 4 min ] [ 40 seg ] – [ 4 min ] [ 50 seg ]  /km
                                        ← si iguales = pace exacto

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
- El pace se introduce como dos NumberPickerField: minutos + segundos (igual que en `TrainingStartView`).
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

## 9. Guardar como plantilla

En cualquier punto del editor, el atleta puede marcar "Guardar también como plantilla":

```
□ Guardar como plantilla reutilizable
```

Si está marcado, la sesión se guarda en dos lugares:
- `plannedSessions/{id}` — la sesión del día en el calendario
- `templates/{templateId}` — plantilla con `isTemplate: true`

Las plantillas aparecen en:
- Perfil → Mis plantillas
- Training Start → "Cargar plantilla"
- Wear OS → TemplatePickerScreen

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

### Desde Training Start
- "Cargar plantilla" → `TemplatesListView` → seleccionar → carga en editor o directamente en sesión activa.

### Desde el Coach IA (Premium)
- La IA genera la sesión. El atleta la ve en el calendario.
- Tap en la sesión IA → `SessionDetailView` con badge "✨ Generada por IA".
- Botón "Editar" → abre editor precargado con los bloques de la IA, editables.

### Desde Wear OS
- `TemplatePickerScreen` lista las plantillas.
- No hay editor en Wear OS — solo selección y ejecución.

---

*Documento UX Running Laps · Mayo 2026. Actualizar cuando cambien flujos del editor o se añadan nuevos tipos de entrenamiento.*
