# Identidad de marca vs. código — pendientes

Registro de discrepancias entre el manual de identidad de marca (artefacto
`Manual de Identidad vs. Código — Running Laps`) y el código real, revisadas
punto por punto. Para cada punto se decide si el cambio va en el **PDF**
(el manual estaba mal / hay que matizarlo) o en el **código** (hay que
corregir la app para que cumpla el manual), o ambos.

Este documento es la lista de trabajo pendiente — cuando se aplique un
cambio, mover el punto a "Resuelto" con el commit/fecha.

---

## Pendientes

### 1. "Coach, no cheerleader" — el ejemplo prohibido del manual es el patrón real

**Estado:** No coincide

**Manual (pág. 5):** da como ejemplo de lo incorrecto
«¡Increíble!!🔥¡Lo has petado!»

**Código:** `lib/features/analytics/data/coach_insight_service.dart:70-132`
genera exactamente ese tono en insights mostrados de forma persistente en
Analytics (`CoachInsightWidget` en `overview_tab.dart:51`, "COACH INSIGHT
(Top priority)"), no en una notificación puntual:
- "¡Increíble! Tus X km son tu mayor distancia... ¡Eres una máquina!"
- "¡Vuelas!... ¡Espectacular!"

**Decisión:** permitir el tono "cheerleader" **solo en notificaciones**
puntuales (push/momento de logro), no en superficies persistentes de la UI
como el card de Analytics. Reducir la intensidad en general.

**Acciones:**
- [x] **Código:** bajado el tono en `coach_insight_service.dart` (las 6
  ramas de `generateInsight`) — sin exclamaciones dobles ni metáforas hype
  ("máquina", "vuelas", "espectacular", "imparable"). El único uso activo
  de este servicio es el card persistente de Analytics
  (`overview_tab.dart:51`); `home_view_legacy.dart` es huérfano (deuda #5)
  y no cuenta. No se creó ningún sistema de notificaciones nuevo para el
  tono celebratorio — si se quiere esa función en el futuro, es una feature
  aparte, no algo a construir especulativamente ahora.
- [ ] **PDF:** aclarar en el manual que la excepción de tono celebratorio
  aplica a notificaciones puntuales de logro (PB, récord), no a texto
  persistente en pantalla — y que incluso ahí debe moderarse (evitar
  emojis/exclamaciones múltiples tipo el ejemplo prohibido pág. 5).

---

### 2. Tagline oficial no implementado — convivían 4 taglines distintos

**Estado:** No coincide

**Manual (pág. 7):** tagline oficial «Para los que van en serio.» ·
tagline de store «Entrena con datos. Corre con propósito.»

**Código:** ninguno de los dos aparecía. Tres textos distintos entre sí en
`README.md:2`, `web/index.html:7,21` y `landing/index.html:560-570`.

**Decisión:** manda el PDF. Se corrige `README.md` para usar el tagline
oficial. `web/index.html` y `landing/index.html` **no se tocan** — ambos se
van a rehacer desde cero, así que no tiene sentido parchear textos que se
van a descartar.

**Acciones:**
- [x] **Código:** `README.md:2` actualizado a «Para los que van en serio.»
- [ ] **PDF:** ninguna — el manual ya estaba bien, era el código el que no
  coincidía.
- [ ] **Pendiente (fuera de este repo por ahora):** cuando se rehagan
  `web/` y `landing/` desde cero, usar el tagline oficial (home/principal)
  y el de store (meta description / listing) según corresponda.

---

### 3. "Nunca fotografía en la interfaz" no contempla la foto de perfil real

**Estado:** Omisión del manual

**Manual (pág. 8):** "Dentro de la app nunca aparece una fotografía" — sin
excepción para avatares.

**Código:** `lib/config/app_theme.dart:75-83` — `AvatarHelper.construirAvatar`
tiene dos ramas distintas: `type == 'avatar'` (avatar generado con el
avatar maker integrado, nunca es una foto real) y `type == 'photo'`
(muestra `NetworkImage` con la foto real de Google o subida por el
usuario). El manual solo contemplaba la primera rama.

**Decisión:** manda el código — la foto de perfil real (Google/subida) es
intencional y se mantiene. El avatar maker ya cumplía la regla del manual
sin necesidad de cambios; lo que estaba mal era la regla en sí, que no
preveía esta excepción.

**Acciones:**
- [ ] **Código:** ninguna.
- [ ] **PDF:** quitar/matizar la regla "nunca fotografía en la interfaz"
  en pág. 8 para reflejar que la foto de perfil real (Google/subida) es
  una excepción intencional; el avatar generado (avatar maker) sigue
  siendo la opción "sin foto" por defecto.

---

### 4. Naming y formatos de assets no siguen la convención del manual

**Estado:** No coincide

**Manual (pág. 14):** `rl-lockup-color.svg/.png`, `rl-badge-*.svg`,
`favicon.ico`, GeneralSans en WOFF2.

**Código:** `assets/images/logo.png`, `Icon.png`, `web/favicon.png` (no
`.ico`), sin SVG de marca, sin WOFF2 (solo `.otf`).

Este punto mezclaba 4 sub-decisiones distintas, resueltas por separado:

**4a. Naming (`rl-lockup-color.*`, `rl-badge-*`)**
- **Decisión:** no renombrar ahora. Se aplica cuando haya un rediseño real
  del sistema de logo — renombrar hoy sin SVGs reales solo genera riesgo
  de romper referencias (`pubspec.yaml`, código) sin beneficio.
- **Acciones:** ninguna por ahora (ni código ni PDF).

**4b. SVG de marca — no existe ningún SVG vectorial del logo, solo PNG**
- **Decisión:** no se puede generar un SVG real a partir del PNG rasterizado
  sin rehacer el arte — es un encargo de diseño, no una tarea de código.
- **Acciones:**
  - [ ] **Diseño (fuera de este repo):** encargar/crear el SVG vectorial
    oficial del logo (lockup + badge).
  - [ ] **PDF:** ninguna por ahora — el requisito SVG se mantiene, queda
    como deuda pendiente hasta tener el vectorial.

**4c. `favicon.ico`**
- **Decisión:** generarlo ya, es trivial y no depende del rediseño web.
- **Acciones:**
  - [x] **Código:** generado `web/favicon.ico` (16/32/48 px) a partir de
    `web/icons/Icon-192.png`. No se tocó `web/index.html` (la web se rehace
    desde cero) — el archivo queda listo para cuando se referencie.
  - [ ] **PDF:** ninguna.

**4d. WOFF2 vs OTF en fuentes**
- **Manual pedía WOFF2**, pero eso es un formato de fuente **web**; la app
  Flutter necesita OTF/TTF vía `pubspec.yaml` — WOFF2 no serviría ahí.
- **Decisión:** aclarar en el PDF que WOFF2 aplica solo a la web (cuando
  se rehaga); la app móvil usa OTF/TTF por requisito técnico de Flutter.
- **Acciones:**
  - [ ] **Código:** ninguna — `assets/fonts/*.otf` está correcto para la
    app.
  - [ ] **PDF:** matizar pág. 14 — WOFF2 solo para web, OTF/TTF para la
    app Flutter.

---

### 5. Colores de feedback de toasts no aparecen en ninguna tabla del manual

**Estado:** Omisión del manual

**Manual:** no documenta success/error/warning/info ni los menciona como
excepción a la paleta de marca.

**Código:** `feedbackSuccess #10B981` · `feedbackError #EF4444` ·
`feedbackWarning #F59E0B` · `feedbackInfo #3B82F6`
(`lib/core/theme/app_colors.dart:50-53`), usados por `ModernSnackBar`
(`modern_snackbar.dart`). Ya documentados y justificados como excepción
semántica en `COLOR_SYSTEM.md:160-168` (tabla `showSuccess/showError/
showWarning/showInfo` → color hex).

**Decisión:** manda el código — son colores semánticos estándar (semáforo
verde/rojo/ámbar/azul), no arbitrarios, y ya están documentados en
`COLOR_SYSTEM.md`. Solo falta que el manual de marca los incorpore.

**Acciones:**
- [ ] **Código:** ninguna.
- [ ] **PDF:** añadir tabla de colores de feedback (success/error/
  warning/info con sus hex) como excepción documentada a la paleta de
  marca, replicando la tabla ya existente en `COLOR_SYSTEM.md`.

---
