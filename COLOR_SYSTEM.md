# COLOR_SYSTEM.md — Running Laps

> Referencia de color para Claude Code y el equipo. Cualquier decisión de color debe consultarse aquí antes de tocar código.

---

## Principio fundamental

**El color comunica significado, no decoración.** Si un color aparece en pantalla, el usuario debe entender algo sin leer texto. Si el color no comunica nada, no debería estar.

---

## Sistema de 3 capas

### Capa 1 · Marca — morado

El color de identidad de la app. Ya ancla el logo, el Live Activity y el botón principal.

| Token | Hex | Uso |
|---|---|---|
| `AppColors.brand` | `#8E24AA` | Botón principal, pestaña activa, underline serie activa |
| `AppColors.brandDark` | `#6A1B9A` | Pressed state, sombras |
| `AppColors.brandLight` | `#CE93D8` | Texto sobre fondos oscuros morados |
| `AppColors.brandSurface` | `#1E1530` | Fondo de tarjetas con acento morado (dark mode) |
| `AppColors.brandBorder` | `#3D2A6E` | Borde de tarjetas con acento morado (dark mode) |

### Capa 2 · Acento — coral/naranja

Para todo lo relacionado con intensidad, esfuerzo y energía.

| Token | Hex | Uso |
|---|---|---|
| `AppColors.effort` | `#D85A30` | Retos de distancia, RPE alto, ritmo al acabar serie |
| `AppColors.effortLight` | `#F0997B` | Texto sobre fondos oscuros de esfuerzo |
| `AppColors.effortSurface` | `#2A1208` | Fondo dark de elementos de esfuerzo |
| `AppColors.effortBorder` | `#993C1D` | Borde de elementos de esfuerzo |

### Capa 3 · Funcional — roles fijos

Cada color tiene **un solo significado** en toda la app.

| Color | Token | Hex | Significado | Nunca usar para |
|---|---|---|---|---|
| Azul | `AppColors.rest` | `#378ADD` | Descanso, recuperación, retos de tiempo | Información genérica |
| Verde | `AppColors.rpeLow` | `#5A9E5A` | RPE 1–4, esfuerzo suave | Éxito de acción (usar morado) |
| Ámbar | `AppColors.rpeMid` | `#EF9F27` | RPE 5–7, esfuerzo moderado | Advertencias de sistema |
| Rojo | `AppColors.rpeMax` | `#E24B4A` | RPE 9–10 únicamente | Errores de UI |

---

## Escala de RPE — color automático

Usar siempre `AppColors.effortColor(rpe)` o equivalente. **Nunca hardcodear el color del RPE.**

```dart
// Implementar en app_theme.dart
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
```

---

## Pantallas — qué color corresponde a cada estado

### Configuración previa (antes de correr)

- Tarjetas Distancia / Descanso: fondo `#1E1E1E`, valor en `AppColors.brand`
- Toggles: off = `#333`, on = `AppColors.brandSurface` + thumb `AppColors.brand`
- Botones "Cargar Plantilla" y "Plantilla Rápida": **mismo estilo, mismo color** — `#1E1E1E` + borde `#2A2A2A`
- Botón "Carrera Continua": `AppColors.brand` sólido
- Iconos de stats: **todos grises** `#555` — el icono es forma, no color
- RPE en series guardadas: `effortColor(rpe)` sobre `effortSurface(rpe)`

### Serie activa

- Fondo: negro puro `#111`
- Tiempo principal: blanco, tipografía máxima
- Encabezado "Serie N": blanco + underline `AppColors.brand`
- Métricas secundarias: `#AAAAAA`
- Botón "Finalizar serie": `AppColors.brand` sólido — **sin degradado**

### Descanso ⟵ cambio de estado más importante

Toda la UI vira a azul. El usuario percibe el cambio de estado sin leer.

- Anillo countdown: `AppColors.rest` sobre fondo `#0D1825`
- Texto countdown: `AppColors.rest`
- Resumen serie anterior: fondo `#0D1825`, borde `#1A3A5A`
- Ritmo de la serie: `AppColors.effortLight` (es el dato de rendimiento)
- Selector RPE: escala `effortColor(n)` para cada celda
- Botón "Saltar descanso": outline `AppColors.rest`

---

## Home — qué color corresponde a cada sección

| Sección | Color | Razón |
|---|---|---|
| Banner motivación | Fondo `#1E1530` + borde izquierdo `AppColors.brand` | Pertenece a la marca, no al contenido |
| Stats (km, sesiones, ritmo) | Fondo `#1A1A1A`, valor en blanco | Son datos neutros |
| Reto distancia | `AppColors.effort` / `#2A1208` | Esfuerzo físico, calor |
| Reto tiempo | `AppColors.rest` / `#0A1825` | Constancia, calma |
| Reto RPE/esfuerzo | `AppColors.brand` / `#1E1530` | Pertenece al sistema de marca |
| Tarjetas entrenos | Fondo `#1A1A1A` | Neutras — el RPE pill lleva el color |
| Tarjetas comunidades | Fondo `#1A1A1A` | Neutras — badge morado solo si hay novedades |
| Nav bar inactivo | `#2A2A2A` / `#3A3A3A` | Sin información que transmitir |
| Nav bar activo | `AppColors.brand` | Estás aquí |

---

## Reglas de oro — checklist antes de añadir color

1. **¿El color comunica algo?** Si la respuesta es "se ve bien", eliminar el color.
2. **¿Ya existe un token para este uso?** Si sí, usar ese. Si no, añadir el token aquí antes de escribir código.
3. **¿Es un degradado?** Los degradados están prohibidos salvo en el Live Activity (ya implementado). Usar colores sólidos.
4. **¿Son varios colores en una misma tarjeta?** Máximo 1 color de acento por tarjeta. El resto, neutro.
5. **¿Es el color de un icono?** Los iconos son grises `#555`. Solo tienen color si el icono representa un estado activo/especial.
6. **¿Es un botón secundario?** Todos los botones secundarios tienen el mismo estilo. La jerarquía se marca con el tamaño y la posición, no con colores distintos.

---

## Lo que está prohibido

- ❌ Degradados en tarjetas del home (el verde del banner, el rosa-azul de comunidades)
- ❌ Color generado desde el título/ID del entrenamiento o del grupo
- ❌ Iconos con color propio (azul para distancia, naranja para tiempo, verde para ritmo...)
- ❌ Botones del mismo nivel jerárquico con colores distintos (plantilla normal vs plantilla rápida)
- ❌ Usar teal (`#009688`) — no es parte del sistema
- ❌ Usar pink/rosa (`#E91E63`) — no es parte del sistema
- ❌ `Colors.orange`, `Colors.green`, `Colors.blue` de Material — usar los tokens de `AppColors`

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
  static const surface  = Color(0xFF1A1A1A);
  static const surface2 = Color(0xFF1E1E1E);
  static const border   = Color(0xFF2A2A2A);
  static const border2  = Color(0xFF252525);
  static const iconMuted = Color(0xFF555555);

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
}
```

---

## Historial

| Fecha | Cambio |
|---|---|
| 2026-04-08 | Sistema de color inicial definido tras auditoría completa de la app |