# COLOR_SYSTEM.md — Running Laps

> Referencia de color para Claude Code y el equipo. Cualquier decisión de color debe consultarse aquí antes de tocar código.
> Actualizado Mayo 2026

---

## Principio fundamental

**El color comunica significado, no decoración.** Si un color aparece en pantalla, el usuario debe entender algo sin leer texto. Si el color no comunica nada, no debería estar.

---

## Sistema de 3 capas

### Capa 1 · Marca — morado

El color de identidad de la app. Ancla el logo, el Live Activity, el botón principal y las competiciones en el calendario.

| Token | Hex | Uso |
|---|---|---|
| `AppColors.brand` | `#8E24AA` | Botón principal, pestaña activa, underline serie activa, competición en calendario |
| `AppColors.brandDark` | `#6A1B9A` | Pressed state, sombras |
| `AppColors.brandLight` | `#CE93D8` | Texto sobre fondos oscuros morados |
| `AppColors.brandSurface` | `#1E1530` | Fondo de tarjetas con acento morado (dark mode) |
| `AppColors.brandBorder` | `#3D2A6E` | Borde de tarjetas con acento morado (dark mode) |

### Capa 2 · Acento — coral/naranja

Para todo lo relacionado con intensidad, esfuerzo y energía.

| Token | Hex | Uso |
|---|---|---|
| `AppColors.effort` | `#D85A30` | Retos de distancia, RPE alto, ritmo al acabar serie |
| `AppColors.effortLight` | `#F0997B` | Texto sobre fondos oscuros de esfuerzo, semana de carga en calendario |
| `AppColors.effortSurface` | `#2A1208` | Fondo dark de elementos de esfuerzo |
| `AppColors.effortBorder` | `#993C1D` | Borde de elementos de esfuerzo |

### Capa 3 · Funcional — roles fijos

Cada color tiene **un solo significado** en toda la app.

| Color | Token | Hex | Significado | Nunca usar para |
|---|---|---|---|---|
| Azul | `AppColors.rest` | `#378ADD` | Descanso, recuperación, retos de tiempo, pantalla de descanso entre series | Información genérica |
| Verde | `AppColors.rpeLow` | `#5A9E5A` | RPE 1–4, esfuerzo suave, semana suave en calendario | Éxito de acción (usar morado) |
| Ámbar | `AppColors.rpeMid` | `#EF9F27` | RPE 5–7, esfuerzo moderado, semana moderada en calendario | Advertencias de sistema |
| Rojo | `AppColors.rpeMax` | `#E24B4A` | RPE 9–10, semana pico en calendario | Errores de UI |

---

## Escala de RPE — color automático

Usar siempre `AppColors.effortColor(rpe)` o equivalente. **Nunca hardcodear el color del RPE.**

```dart
static Color effortColor(double rpe) {
  if (rpe <= 4) return const Color(0xFF5A9E5A);   // verde
  if (rpe <= 7) return const Color(0xFFEF9F27);   // ámbar
  if (rpe <= 8) return const Color(0xFFF0997B);   // coral claro
  return const Color(0xFFE24B4A);                 // rojo
}

static Color effortSurface(double rpe) {
  if (rpe <= 4) return const Color(0xFF0F1F0F);
  if (rpe <= 7) return const Color(0xFF1F1A08);
  if (rpe <= 8) return const Color(0xFF2A1208);
  return const Color(0xFF2A0808);
}

static Color effortBorderColor(double rpe) {
  if (rpe <= 4) return const Color(0xFF3B6D11);
  if (rpe <= 7) return const Color(0xFF854F0B);
  if (rpe <= 8) return const Color(0xFF993C1D);
  return const Color(0xFF791F1F);
}
```

---

## Calendario — sistema de colores de carga semanal

El color de una semana representa **carga TRIMP acumulada**, no kilómetros.

```dart
Color _colorForWeekLoad(double trimp, bool hasCompetition) {
  if (hasCompetition) return AppColors.brand;      // morado — competición siempre
  if (trimp <= 0)   return AppColors.iconMutedOf;  // gris — sin datos
  if (trimp < 150)  return AppColors.rpeLow;       // verde — semana suave/descarga
  if (trimp < 300)  return AppColors.rpeMid;       // ámbar — semana base/moderada
  if (trimp < 500)  return AppColors.effortLight;  // coral — semana de carga
  return AppColors.rpeMax;                         // rojo — semana pico/sobrecarga
}
```

| Color | Token | TRIMP | Significado |
|---|---|---|---|
| Gris | `iconMutedOf` | 0 | Sin datos / Descanso |
| Verde | `rpeLow` | < 150 | Semana suave / descarga |
| Ámbar | `rpeMid` | 150–300 | Semana base / moderada |
| Coral | `effortLight` | 300–500 | Semana de carga |
| Rojo | `rpeMax` | > 500 | Semana pico / sobrecarga |
| Morado | `brand` | — | **Solo competición** (tag 'competición' o athleteSession.category == 'competición') |

**REGLA CRÍTICA:** `brand` (morado) NUNCA indica volumen alto. Solo competición.
La competición siempre es morado independientemente del TRIMP.

### Leyenda visual en el calendario
```
CARGA SEMANAL
● Sin datos  ● Suave  ● Moderada  ● Carga  ● Pico  ◆ Competición
  (gris)      (verde)  (ámbar)    (coral)  (rojo)   (morado)
```

---

## Etiquetas — sistema de colores

| Tipo | Fondo | Texto | Borde |
|---|---|---|---|
| Predefinida (rodaje, series, etc.) | `brand.withOpacity(0.1)` | `brand` | ninguno |
| Custom (creada por usuario) | `surface2Of(context)` | `textSecondary(context)` | `borderOf(context)` 0.5px |

Predefinidas: rodaje, series, tempo, largo, fartlek, competición, recuperación.

---

## Pantallas — qué color corresponde a cada estado

### Training Start (antes de correr)

- Fondo general: `AppColors.surface2Of(context)`
- Icono GPS activo: `AppColors.brand` (no verde)
- Icono GPS inactivo: `AppColors.iconMutedOf`
- Switch activo: `activeColor: AppColors.brand`
- Iconos de tipo de entreno: `AppColors.brand` (solo el icono, no el label)
- Botón EMPEZAR: círculo 56×56, `AppColors.brand`, sin sombra

### Serie activa

- Fondo: negro puro `#111`
- Tiempo principal: blanco, tipografía máxima
- Encabezado "Serie N": blanco + underline `AppColors.brand`
- Métricas secundarias: `#AAAAAA`
- Botón "Finalizar serie": `AppColors.brand` sólido — **sin degradado**

### Descanso ⟵ cambio de estado más importante

Toda la UI vira a azul. El usuario percibe el cambio de estado sin leer.

- Fondo: blanco que se tiñe de `Color(0xFFE3F2FD)` de abajo hacia arriba según progreso
- Burbujas flotantes: `Color(0xFF90CAF9).withOpacity(0.4-0.7)`
- Temporizador: `AppColors.rest`
- Resumen serie anterior: fondo semitransparente, datos limpios
- Selector RPE: escala `effortColor(n)` para cada valor
- Botón "Saltar descanso": textSecondary, muy discreto

### Historial

- Cards: `surfaceOf(context)`, borde `borderOf(context)` 0.5px, radius 16
- Stats: `textPrimary(context)` w400-w500 — sin negrita
- Título de sesión: w600 — única negrita permitida
- Pace: `AppColors.brand`
- RPE: `effortColor(rpe)`
- Badge GPS: `brand.withOpacity(0.1)` + texto `brand`
- Badge Manual: `surface2Of` + texto `textSecondary`

### Training Detail

- Hero: sin cards, números grandes protagonistas, w400-w500
- Separadores entre secciones: `Divider(color: borderOf, thickness: 0.5)`
- Pace en stats: `AppColors.brand`
- RPE: `effortColor(rpe)`
- Delta positivo (mejora): `AppColors.rpeLow`
- Delta negativo (empeora): `AppColors.rpeMax`
- Gráfica fl_chart: línea pace en `brand`, línea FC en `rpeMax`

### Home

| Sección | Color | Razón |
|---|---|---|
| Banner motivación | Fondo `#1E1530` + borde izquierdo `AppColors.brand` | Pertenece a la marca |
| Stats (km, sesiones, ritmo) | Fondo `#1A1A1A`, valor en blanco | Datos neutros |
| Reto distancia | `AppColors.effort` / `#2A1208` | Esfuerzo físico |
| Reto tiempo | `AppColors.rest` / `#0A1825` | Constancia |
| Reto RPE/esfuerzo | `AppColors.brand` / `#1E1530` | Marca |
| Tarjetas entrenos | Fondo `#1A1A1A` | Neutras — RPE pill lleva color |
| Nav bar inactivo | `#2A2A2A` / `#3A3A3A` | Sin info |
| Nav bar activo | `AppColors.brand` | Estás aquí |

---

## Inputs y controles

| Tipo | Control | Color activo |
|---|---|---|
| Números (distancia, tiempo, series, descanso) | `NumberPickerField` (CupertinoPicker) | — |
| RPE (1-10) | Slider | `effortColor(rpe)` dinámico |
| Toggle on/off | Switch | `activeColor: AppColors.brand` |
| Selección de tipo | Container custom (GestureDetector) | Borde `brand` 1.5px + fondo `brand.withOpacity(0.08)` |
| Tags predefinidas | Container pill | `brand.withOpacity(0.1)` + texto `brand` |
| Tags custom | Container pill | `surface2Of` + borde `borderOf` |

**REGLA:** El teclado solo aparece para texto libre (nombre, notas, búsqueda). Todo lo numérico usa `NumberPickerField` o slider.

---

## Tipografía — reglas de peso

| Elemento | fontWeight | letterSpacing |
|---|---|---|
| Título de sesión/pantalla | w600 | -0.4 |
| Stats y números grandes (h1/h2) | w400–w500 | -0.4 |
| Body texto | w400 | -0.3 |
| Small texto | w400 | -0.3 |
| Labels MAYÚSCULAS (SERIES, SENSORES...) | w500–w600 | 1.2–1.5 (intencional) |

**REGLA:** Sin `FontWeight.bold` ni `w700` en listas, historial ni detalles. Solo títulos de sesión usan w600.

---

## Reglas de oro — checklist antes de añadir color

1. **¿El color comunica algo?** Si la respuesta es "se ve bien", eliminar el color.
2. **¿Ya existe un token para este uso?** Si sí, usar ese. Si no, añadir el token aquí antes de escribir código.
3. **¿Es un degradado?** Los degradados están prohibidos salvo en el Live Activity. Usar colores sólidos.
4. **¿Son varios colores en una misma tarjeta?** Máximo 1 color de acento por tarjeta. El resto, neutro.
5. **¿Es el color de un icono?** Los iconos son grises `iconMutedOf`. Solo tienen color si representan un estado activo/especial.
6. **¿Es un botón secundario?** Todos los botones secundarios tienen el mismo estilo. La jerarquía se marca con tamaño y posición, no con colores distintos.
7. **¿Es un número o stat?** Sin negrita. w400–w500 máximo.

---

## Lo que está prohibido

- ❌ Degradados en tarjetas (usar colores sólidos)
- ❌ `AppColors.brand` para indicar "semana de mucho volumen" — solo competición
- ❌ Color generado desde el título/ID del entrenamiento o del grupo
- ❌ Iconos con color propio (azul para distancia, naranja para tiempo, verde para ritmo...)
- ❌ Botones del mismo nivel jerárquico con colores distintos
- ❌ Usar teal (`#009688`) — no es parte del sistema
- ❌ Usar pink/rosa (`#E91E63`) — no es parte del sistema
- ❌ `Colors.orange`, `Colors.green`, `Colors.blue` de Material — usar tokens de `AppColors`
- ❌ `FontWeight.bold` / `w700` en listas, historial o detalles — solo títulos de sesión usan w600
- ❌ `Colors.transparent` como backgroundColor de Scaffold — usar `AppColors.background(context)`
- ❌ Verde (`rpeLow`) para "GPS activo" — usar `brand`

---

## Implementación en app_theme.dart

```dart
class AppColors {
  // Marca
  static const brand        = Color(0xFF8E24AA);
  static const brandDark    = Color(0xFF6A1B9A);
  static const brandLight   = Color(0xFFCE93D8);
  static const brandSurface = Color(0xFF1E1530);
  static const brandBorder  = Color(0xFF3D2A6E);

  // Esfuerzo / acento
  static const effort        = Color(0xFFD85A30);
  static const effortLight   = Color(0xFFF0997B);
  static const effortSurface = Color(0xFF2A1208);
  static const effortBorder  = Color(0xFF993C1D);

  // Descanso
  static const rest        = Color(0xFF378ADD);
  static const restLight   = Color(0xFF85B7EB);
  static const restSurface = Color(0xFF0D1825);
  static const restBorder  = Color(0xFF1A3A5A);

  // RPE — usar effortColor(), no hardcodear
  static const rpeLow  = Color(0xFF5A9E5A);
  static const rpeMid  = Color(0xFFEF9F27);
  static const rpeHigh = Color(0xFFD85A30);
  static const rpeMax  = Color(0xFFE24B4A);

  // Neutros dark mode
  static const surface   = Color(0xFF1A1A1A);
  static const surface2  = Color(0xFF1E1E1E);
  static const border    = Color(0xFF2A2A2A);
  static const border2   = Color(0xFF252525);
  static const iconMuted = Color(0xFF555555);

  // Contextuales (light/dark)
  static Color background(BuildContext context) => ...
  static Color surfaceOf(BuildContext context) => ...
  static Color surface2Of(BuildContext context) => ...
  static Color borderOf(BuildContext context) => ...
  static Color textPrimary(BuildContext context) => ...
  static Color textSecondary(BuildContext context) => ...
  static Color iconMutedOf(BuildContext context) => ...

  // Escala RPE
  static Color effortColor(double rpe) {
    if (rpe <= 4) return rpeLow;
    if (rpe <= 7) return rpeMid;
    if (rpe <= 8) return effortLight;
    return rpeMax;
  }

  static Color effortSurface(double rpe) {
    if (rpe <= 4) return const Color(0xFF0F1F0F);
    if (rpe <= 7) return const Color(0xFF1F1A08);
    if (rpe <= 8) return const Color(0xFF2A1208);
    return const Color(0xFF2A0808);
  }

  static Color effortBorderColor(double rpe) {
    if (rpe <= 4) return const Color(0xFF3B6D11);
    if (rpe <= 7) return const Color(0xFF854F0B);
    if (rpe <= 8) return const Color(0xFF993C1D);
    return const Color(0xFF791F1F);
  }

  // Calendario
  static Color weekLoadColor(double trimp, bool hasCompetition, BuildContext context) {
    if (hasCompetition) return brand;
    if (trimp <= 0)   return iconMutedOf(context);
    if (trimp < 150)  return rpeLow;
    if (trimp < 300)  return rpeMid;
    if (trimp < 500)  return effortLight;
    return rpeMax;
  }
}
```

---

## Historial de cambios

| Fecha | Cambio |
|---|---|
| 2026-04-08 | Sistema de color inicial definido tras auditoría completa |
| 2026-05-09 | Añadido sistema de colores para calendario (TRIMP, no km). Brand reservado para competición. Añadidas reglas de tipografía (sin bold en listas). Añadidas reglas de inputs (NumberPickerField). Añadido sistema de etiquetas predefinidas/custom. Fix: GPS activo en brand no en rpeLow. Fix: backgroundColor nunca Colors.transparent. |