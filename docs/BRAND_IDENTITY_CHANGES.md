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
