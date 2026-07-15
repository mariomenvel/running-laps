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

### 6. Opacidad de fondo del tag/badge — 13% en código vs. 15% del manual

**Estado:** Parcial

**Manual (pág. 40):** "El fondo es el color RPE al 15%."

**Código:** `lib/core/widgets/rpe_badge.dart:47` —
`color.withValues(alpha: 0.13)`, cercano pero no coincide.

**Decisión:** manda el PDF — corregido en código.

**Acciones:**
- [x] **Código:** `rpe_badge.dart:47` → `alpha: 0.15`.
- [ ] **PDF:** ninguna.

---

### 7. Bold 700 — prohibido en el manual, pero empaquetado y usado en producción

**Estado:** No coincide

**Manual (pág. 28, 55):** "Bold (w700) está prohibido en todo el sistema."

**Código:** `GeneralSans-Bold.otf` registrado con weight 700 en
`pubspec.yaml`; decenas de `FontWeight.bold`/`.w700`/`.w900` activos fuera
de `AppTypography` (que ya tenía como máximo w600).

**Decisión:** manda el PDF — corregido en código, con dos exclusiones de
alcance:

- **Vistas huérfanas** (deuda técnica #5 de CLAUDE.md, cero referencias,
  pendientes de borrar): `home_view_legacy.dart`, `session_planner_view.dart`,
  `athlete_session_editor_view.dart`, `session_editor_view.dart`,
  `analytics_hub_screen_legacy.dart`, `analytics_hub_view.dart`,
  `profile_menu_screen.dart` (el huérfano es el que NO lleva `_legacy`),
  `global_challenge_card.dart` (solo referenciado desde
  `home_view_legacy.dart`) — no se tocó bold ahí, no vale la pena arreglar
  código que se va a eliminar.
- **`pdf_generator_service.dart`:** los PDFs exportables usan la fuente
  por defecto del paquete `pdf` (no GeneralSans) — es un contexto de
  render distinto a la UI de la app. Se deja fuera de alcance (decisión
  explícita del usuario) en vez de embeber una fuente custom para esto.

**Acciones:**
- [x] **Código:** `FontWeight.bold`/`.w700`/`.w900` → `FontWeight.w600`
  en los dos archivos activos que los usaban:
  `profile_menu_screen_legacy.dart` (2 usos) y `group_rewards_screen.dart`
  (11 usos, incluida la distinción `isMe` que ya se diferenciaba por color
  y ahora también solo por color, sin peso extra). Eliminado
  `GeneralSans-Bold.otf` de `pubspec.yaml` y borrado el asset del repo —
  nada en código activo puede ya pedir weight 700.
- [ ] **PDF:** ninguna.

---

### 8. Falta el WOFF2 que el manual exige para uso web self-hosted

**Estado:** Parcial

**Manual (pág. 14, 26):** GeneralSans en WOFF2 (web) y OTF (diseño/Figma)
como assets separados.

**Código:** solo existían los 4 pesos en `.otf`; no había WOFF2 en el
repo. (Relacionado con el punto 4d, que aclaraba que WOFF2 es solo para
web — este punto es la ejecución de esa aclaración.)

**Decisión:** manda el PDF — generado el WOFF2 para web.

**Acciones:**
- [x] **Código:** generados `web/assets/fonts/GeneralSans-{Regular,
  Medium,Semibold}.woff2` a partir de los `.otf` (fontTools). **No** se
  generó Bold — ya no existe el `.otf` fuente tras el punto 7 (Bold
  prohibido) y no tendría sentido añadirlo solo para web. No se tocó
  `web/index.html`/`landing/index.html` (se rehacen desde cero) — los
  WOFF2 quedan listos como asset para cuando se referencien con
  `@font-face`.
- [ ] **PDF:** ninguna.

---

### 9. Librería de iconos — Material Icons, no Lucide

**Estado:** No coincide

**Manual (pág. 30):** Lucide · línea única 2px · sin relleno · sin
filled/solid.

**Código:** ningún paquete Lucide en `pubspec.yaml` (solo
`cupertino_icons`). 784 usos de `Icons.*` de Material (filled/rounded) +
Cupertino sueltos. `pubspec.yaml` · `lib/core/widgets/rpe_badge.dart:54`.

**Decisión:** manda el código — 784 usos es una migración de icon set
completa, no algo a hacer como corrección puntual. Se actualiza el PDF
para reflejar Material Icons (rounded) como librería oficial en vez de
Lucide.

**Acciones:**
- [ ] **Código:** ninguna.
- [ ] **PDF:** reemplazar la especificación de librería de iconos (pág.
  30) — de Lucide a Material Icons variante *rounded*, documentando el
  estilo real usado (grosor/relleno según el icono, no estrictamente
  línea única 2px sin relleno).

---

### 10. Emoji en UI — prohibición "sin excepciones" incumplida de forma extendida

**Estado:** No coincide

**Manual (págs. 30, 47):** "Los emoji están prohibidos en toda la UI del
producto: mensajes del sistema, toasts, coaching copy y estados."

**Código:** emoji en notificaciones push, snackbars de récord, onboarding,
errores de GPS, medallas del ranking, chips de sueño del coach IA,
invitaciones de grupo, y un caso en Wear OS.

**Decisión:** manda el PDF — 0 emoji por ahora. Corregido en código.

**Acciones:**
- [x] **Código:** eliminados todos los emoji en superficies de UI activas:
  - `notification_service.dart` (4 títulos de notificación push)
  - `challenge_detail_screen.dart` — medallas 🥇🥈🥉 reemplazadas por
    `Icon(Icons.emoji_events_rounded)` en oro/plata/bronce (no se podía
    solo borrar: son el indicador visual del podio)
  - `create_challenge_modal.dart`, `groups_list_screen.dart`,
    `group_screen.dart` (2 snackbars), `training_no_gps_detail_view.dart`,
    `training_start_view.dart`, `training_session_view.dart` (3 mensajes
    de error GPS) — texto plano sin emoji
  - `athlete_tutorial_view.dart` — el campo `emoji: String` de cada slide
    del tutorial de onboarding pasó a `icon: IconData` (Material Icons:
    `track_changes`, `calendar_month`, `chat_bubble`, `bar_chart`)
  - `home_layout_config.dart` — el getter `WidgetType.icon` (emoji) no
    tenía ningún caller real (código muerto, superado por
    `_iconForWidget` en `edit_home_view.dart`); eliminado en vez de
    convertido
  - `ai_coach_weekly_feedback_view.dart` — chips de sueño, solo texto
  - `wear_os/.../SeriesPageScreen.kt` — un emoji en la etiqueta de
    plantilla
  - **No tocados:** comentarios internos de código (`⚠️ HUÉRFANO`,
    `✅ ACTIVO`, ❌/✅ en `app_colors.dart`) y dos `debugPrint()` — no son
    UI visible para el usuario. `web/`/`landing/` tampoco (se rehacen
    desde cero).
- [ ] **PDF:** ninguna — el manual ya estaba bien, era el código el que
  no coincidía.

---

### 11. Tamaños de icono 20/24px tokenizados pero no siempre respetados

**Estado:** Parcial

**Manual (pág. 30):** "20 px y 24 px únicamente. Nunca tamaños
intermedios."

**Código:** `AppDimens.iconSize`/`iconSizeSmall` existen (24/20) pero
conviven con más de 20 tamaños distintos hardcodeados en uso real (13,
14, 16, 18, 22, 28, 32, 34, 40, 48, 56, 64... — cientos de sitios).

**Decisión (a petición explícita):** manda el código. Los dos ejemplos
citados no son descuido: `rpe_badge.dart:54` usa 13px porque es un icono
inline dentro de un badge compacto de texto 12px (20px no cabría sin
romper el layout); `app_footer.dart:142` usa 40px porque es el icono del
FAB central "Entrenar", con jerarquía visual deliberadamente mayor que
los 4 iconos de tab normales. Con cientos de sitios y tamaños ligados a
contexto (badge inline vs. FAB hero vs. nav bar), forzar todo a 20/24
sería un cambio mecánico de alto riesgo visual sin beneficio real, no
algo para hacer como corrección puntual — igual que el punto 9 (Lucide).

**Acciones:**
- [ ] **Código:** ninguna.
- [ ] **PDF:** relajar pág. 30 — documentar 20/24px como los tamaños
  estándar de icono de UI (nav, botones, list items), pero permitir
  tamaños contextuales fuera de esos dos casos (badges compactos, iconos
  hero/FAB, tablas densas) en vez de una prohibición absoluta.

---

### 12. Escala de espaciado — faltan 3 de 9 pasos, incluido el gutter móvil "regla principal"

**Estado:** Parcial

**Manual (pág. 32):** 4/8/12/16/20/24/32/48/64px — 20px es "gutter móvil,
regla principal".

**Código:** `AppSpacing` solo definía xs/s/m/l/xl/xxl = 4/8/12/16/24/32.
Sin token para 20, 48 ni 64. `lib/core/theme/app_theme.dart:108-113`.

**Decisión:** manda el PDF — corregido en código. A diferencia de los
puntos 9 y 11, esto no es migrar cientos de sitios: es solo añadir los
tokens que faltaban en la definición de la escala. CLAUDE.md ya deja
explícito que `AppSpacing` es "usar en código nuevo, no migrar el
existente", así que no se tocó ningún spacing hardcodeado ya en uso.

**Acciones:**
- [x] **Código:** añadidos `AppSpacing.gutter = 20` (nombre semántico,
  siguiendo la designación del manual como "regla principal"),
  `AppSpacing.xxxl = 48` y `AppSpacing.xxxxl = 64`.
- [ ] **PDF:** ninguna.

---

### 13. Radios de esquina — el radio pill (999) no existe en ningún sitio del código

**Estado:** No coincide

**Manual (pág. 33):** escala 8(sm)/12(md)/16(card)/20(lg)/999(pill). Tags
y segmented control siempre pill.

**Código:** `AppDimens` solo tokenizaba 12 y 16. Cero `StadiumBorder` o
`BorderRadius.circular(999)` en todo `lib/`. Radios sueltos (2,6,8,10,20,
24,28) repetidos a mano sin token. `lib/core/theme/app_theme.dart:120-121,129`
· `rpe_badge.dart:48` (6px, no pill).

**Decisión:** manda el código, con dos alcances distintos:
- **Tags:** a diferencia de los tamaños de icono (punto 11), los tags
  están centralizados en dos widgets reutilizables (`TagChip` y el
  `_TagToggleChip` privado de `tag_selector_sheet.dart`) — cambiarlos a
  pill es un cambio contenido, no una migración de cientos de sitios.
  Corregido.
- **Segmented control:** solo 2 usos, ambos `CupertinoSlidingSegmentedControl`
  (widget nativo de Flutter). Su radio de esquina no es parametrizable vía
  API pública — forzar pill requeriría reconstruir el widget desde cero.
  Fuera de alcance; se deja el radio nativo de Cupertino y se anota para
  el PDF.

**Acciones:**
- [x] **Código:** añadidos `AppDimens.radiusSm = 8`, `AppDimens.radiusLg
  = 20` y `AppDimens.radiusPill = 999`. `TagChip.build()` y
  `_TagToggleChip.build()` ahora usan `AppDimens.radiusPill` en vez de
  8/12 hardcodeado — todos los tags (vista, selector, historial) son pill
  ahora. No se tocó `rpe_badge.dart:48` (6px) — es el radio del badge
  completo (RPE), no un tag, fuera del alcance de esta regla.
- [ ] **PDF:** anotar que el segmented control usa el radio nativo de
  `CupertinoSlidingSegmentedControl` (no pill custom) — no parametrizable
  sin reconstruir el widget.

---
