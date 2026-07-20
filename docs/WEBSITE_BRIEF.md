# Brief para rediseño de runninglaps.com

Documento de traspaso para el diseñador que va a rehacer la web desde cero. Reúne qué es el producto, qué tiene que llevar la web sí o sí, y qué activos y reglas de marca ya existen. El diseñador tiene libertad total sobre layout, composición y dirección visual concreta — lo que no es negociable son la identidad de marca (Sección 3), el contenido mínimo por página (Sección 6) y los requisitos funcionales/técnicos (Sección 7).

---

## 1. Qué es Running Laps

App de entrenamiento de running (Android/iOS, + versión reloj Wear OS en pausa) para corredores que entrenan por su cuenta, sin entrenador humano. No es una app de fitness genérica: es un coach de atletismo con estructura — series, RPE (esfuerzo percibido), GPS, zonas de frecuencia cardíaca, plan semanal generado por IA y análisis de carga real (CTL/ATL/TSB, estilo TrainingPeaks).

**Estado actual:** en beta cerrada, gratuita. La web actual es una landing de captación de lista de espera (waitlist), sin enlaces a tiendas todavía — no hay que diseñar botones de App Store / Google Play.

**Posicionamiento:** *"El entrenador para quien corre por su cuenta."*
**Diferenciador clave:** *"Coach, no app de fitness"* — se comporta como un entrenador profesional: preciso, orientado al dato, sin hype vacío. El elogio se gana con números, no con entusiasmo.

**Público objetivo:**
- Corredores con algo de base que quieren entrenar en serio (de su primer 10K/medio maratón al amateur avanzado).
- Gente que ya registra y analiza cada sesión, o quiere empezar a hacerlo.
- Van por su cuenta, sin entrenador humano — la app ocupa ese hueco.

**Quién lo construye:** proyecto de fundador único (Mario, entrenador de fuerza + ingeniero de software), construido en público. La web actual tiene un bloque "quién construye esto" con foto y storytelling personal — es un activo de confianza importante, no un adorno.

---

## 2. Objetivo de la web

1. **Captar leads para la beta** — formulario de waitlist (email + plataforma Android/iOS) es la conversión principal. Todo el diseño debe empujar hacia ese formulario sin fricción.
2. **SEO / adquisición orgánica** — la web es la puerta de entrada a búsquedas tipo "app entrenamiento running series RPE", etc. Necesita metadatos, datos estructurados y rendimiento cuidados (ver Sección 8).
3. **Credibilidad** — transmitir que esto es una herramienta seria hecha por alguien que entiende tanto de entrenar como de construir software, no una app genérica de "conecta tu reloj y ya".

No es objetivo de esta web: vender un plan de pago (no existe todavía), documentar la app en profundidad, o servir de blog/CMS.

---

## 3. Identidad de marca — resumen ejecutivo

**La fuente de verdad completa es el PDF `Manual de identidad Running Laps.pdf`** (56 páginas, v1.0, 2026, en la raíz del repo) — el diseñador debe leerlo entero antes de empezar. Incluye una sección dedicada a grid y breakpoints web (§06). Aquí va el resumen imprescindible:

### Color
| Uso | Hex | Nota |
|---|---|---|
| Púrpura Running (marca) | `#8E24AA` | Acción, selección, marca. **Nunca** codifica intensidad/esfuerzo. Uso exclusivo — no recolorear. |
| Púrpura profundo | `#6A1B9A` | Estado press/hover del púrpura. Solo oscurece, nunca aclara. |
| Tinta (texto/fondo oscuro) | `#1A1A1A` | Texto principal en claro; fondo de secciones de contraste. |
| Blanco | `#FFFFFF` | Fondo principal. |
| Azul recuperación | `#378ADD` | Uso exclusivo para mensajes de descanso/recuperación. Nunca mezclado con colores de esfuerzo en la misma superficie. |
| Escala de esfuerzo (RPE) | Verde `#5A9E5A` · Ámbar `#EF9F27` · Coral suave `#F0997B` · Rojo `#E24B4A` | Vocabulario de intensidad de la app. En la web solo aparece si se muestran datos/capturas reales — no usar como paleta decorativa. |

Reglas duras de color: **sin gradientes** (excepción única en toda la marca: el track del RPE slider, que no aparece en la web), **sin blur/glassmorphism**, **sin sombras de color/neón**, **cards sin sombra** (solo borde hairline 0.5px). Contraste mínimo WCAG AA.

### Tipografía
- **General Sans** (Regular 400 / Medium 500 / Semibold 600) — self-hosted en WOFF2. Es la fuente ya usada en la web actual (`hosting/assets/fonts/`).
- **Bold/700 prohibido en todo el sistema.** Techo: Semibold 600, reservado para h1 y labels. La jerarquía se construye con tamaño y color, no con peso.
- Sentence case siempre. UPPERCASE solo permitido en labels cortas de datos (ej. "DISTANCIA"), nunca en frases.
- Números con `font-variant-numeric: tabular-nums`.

### Grid web (definido en el manual, §06)
| Breakpoint | Móvil (<768px) | Tablet (768–1023px) | Desktop (1024–1439px) | Wide (≥1440px) |
|---|---|---|---|---|
| Columnas | 4 | 8 | 12 | 12 |
| Gutter | 16px | 24px | 24px | 24px |
| Margen lateral | 20px | 32px | 48px | auto |
| Max-width | — | — | — | 1280px |

Bloque de texto corrido: máx. 680px de ancho de línea. Radios: 12px (botones/inputs), 16px (cards), 999px (pills). Motion: easing único `cubic-bezier(.2,0,0,1)`, sin rebote/overshoot, entradas ≤400ms.

### Voz y tono
1. **Coach, no cheerleader** — feedback preciso y medible, el elogio se gana con datos.
2. Los números llevan el mensaje: ritmo, FC, distancia, RPE son el vocabulario.
3. Habla al atleta ("tú"), no al "usuario".
4. Directo, calmo, declarativo — imperativos para guiar, sin exclamaciones vacías.
5. Celebra progreso con datos, no con "¡lo has petado!".
6. **Sin emojis, nunca.** En ningún copy de marca ni de producto.
7. Bilingüe natural aceptado (español primero), pero la web es 100% español.

Ejemplo correcto: *"+4 s/km vs la semana pasada a la misma FC."*
Ejemplo prohibido: *"¡¡Increíble!! ¡Lo has petado! Eres imparable"*

### Fotografía (si se usa fuera de producto — válido en web/marketing)
Permitida solo bajo 3 condiciones: blanco y negro (nunca color), documental y no aspiracional (nunca poses/sonrisas/celebración/amaneceres/puños en alto), y el púrpura se superpone como bloque plano sobre la foto — nunca la tiñe. Excepción ya usada: la foto real del fundador en color (`hosting/assets/yo.png`) es una excepción intencional documentada.

---

## 4. Assets disponibles para entregar al diseñador

Todo en `hosting/assets/` y raíz del repo:

- **Logo:** `logo-wordmark.png` / `logo-wordmark-white.png`, `rl-mark-white.png`. El manual referencia versiones SVG (`rl-lockup-color.svg`, `rl-badge-color.svg`, etc.) como pendientes de publicar en un repo de assets — de momento solo existen los PNG/favicon ya en `hosting/assets/`.
- **Favicons/app icon:** `favicon.ico`, `favicon-32.png`, `apple-touch-icon.png`.
- **Tipografía:** `GeneralSans-Regular/Medium/Semibold.woff2`.
- **Capturas reales de la app** (usar tal cual, no renders ni mockups genéricos): `screens/forma.webp` (estado de forma CTL/ATL/TSB), `plan.webp` (plan semanal del coach), `historial.webp`, `carga.webp` (volumen + distribución 80/20), `zonas.webp` (zonas FC), `records.webp` (récords personales).
- **Foto del fundador:** `assets/yo.png`.
- **Manual de identidad completo:** `Manual de identidad Running Laps.pdf` (raíz del repo) — fuente de verdad de todo lo de la Sección 3.
- **OG image:** `assets/og-image.png` (1200×630) — el diseñador debe regenerarla si cambia el diseño.

---

## 5. Sitemap requerido

La web se sirve estática desde Firebase Hosting (`hosting/` = public dir, `cleanUrls: true`). Rutas que deben existir sí o sí:

| Ruta | Contenido |
|---|---|
| `/` | Landing principal (ver Sección 6) |
| `/privacy` | Política de privacidad (RGPD) |
| `/terms` | Términos y condiciones |
| `/support` | Ayuda / contacto |
| `/delete-account` | Instrucciones de eliminación de cuenta (requisito de Google Play / App Store) |
| `/sitemap.xml`, `/robots.txt` | SEO técnico |

No se necesitan más páginas (sin blog, sin pricing todavía, sin páginas de features separadas) salvo que el diseñador proponga algo y se valide antes.

---

## 6. Contenido mínimo por página

### 6.1 Landing (`/`)

El copy exacto puede reescribirse — lo que sigue es el contenido informativo que **tiene que estar**, no el texto literal:

1. **Header** — logo + navegación a anclas de la propia página + CTA "Unirme a la beta" siempre visible (sticky).
2. **Hero** — tagline (*"Para los que van en serio."*), propuesta de valor en una frase, formulario de waitlist (email + selector de plataforma Android/iPhone) visible sin scroll, captura real de la app.
3. **Diferenciador** — "coach, no app de fitness": contraste explícito entre el tono de Running Laps (dato) y el de apps de fitness genéricas (hype). Puede incluir una fila de datos de ejemplo (ritmo, RPE, zonas FC, TSB) para anclar la idea de "esto es serio".
4. **Feature: Coach IA** — plan semanal automático, ajustes en lenguaje natural, análisis post-sesión (planificado vs ejecutado). Con captura real.
5. **Feature: Análisis de carga** — estado de forma (CTL/ATL/TSB), distribución de intensidad 80/20, récords personales detectados automáticamente. Con captura real.
6. **Feature: Entrenamiento fraccionado** — series con GPS, RPE por serie, zonas de FC personalizadas, historial completo. Con captura real.
7. **Galería** — el resto de capturas reales no usadas arriba (zonas FC, récords, historial), para reforzar "así es la app de verdad, sin renders".
8. **Cómo funciona** — 3 pasos: definir objetivo → recibir plan semanal → entrenar y medir.
9. **Fundador** — foto real + historia corta (entrenador de fuerza + programador, lo construye en público). Enlace a Instagram del proyecto (`instagram.com/runninglapsapp`).
10. **CTA final de waitlist** — repetir formulario con motivación de "entra como fundador": acceso anticipado, feedback moldea la app, precio de fundador de por vida.
11. **FAQ** — mínimo estas 5 preguntas (contenido real, no placeholder):
    - ¿Cuánto cuesta Running Laps? (gratis en beta, habrá plan de pago después pero siempre existirá versión gratuita)
    - ¿Cómo funciona el coach IA?
    - ¿Qué es el RPE y por qué lo usa la app?
    - ¿Sirve si soy principiante?
    - ¿Qué pasa con mis datos de GPS y salud?
12. **Footer** — logo, tagline, enlaces a Producto (anclas), Legal (privacidad/términos/eliminar cuenta), Soporte, copyright.

**Nota de tono en el hero/CTA:** nada de exclamaciones ni superlativos vacíos ("¡increíble!", "revoluciona tu entrenamiento"). El texto de confirmación del formulario también sigue la regla: *"Listo. Te avisaremos cuando la beta esté disponible."*, no "¡Genial, ya estás dentro!".

### 6.2 Privacidad (`/privacy`)

Debe cubrir, como mínimo (contenido legal ya redactado y vigente, ver `hosting/privacy.html` como referencia de qué secciones son obligatorias):

- Responsable del tratamiento (Mario Mendoza / Running Laps) + contacto `legal@runninglaps.com`.
- Qué datos se recopilan: cuenta, datos de entrenamiento (incl. GPS), datos de salud (FC — categoría especial RGPD art. 9), datos del coach IA, dictado por voz, email/plataforma de la waitlist.
- Finalidad y base legal de cada tratamiento (ejecución de contrato, consentimiento explícito para datos de salud, interés legítimo para seguridad).
- Consentimiento explícito específico para frecuencia cardíaca, con cómo retirarlo.
- Con quién se comparten datos: Firebase/Google Cloud, proveedor de IA (OpenRouter — nunca recibe nombre/email/GPS, solo métricas anonimizadas), Apple/Google para dictado.
- Transferencias internacionales (EE.UU., EU-U.S. Data Privacy Framework / cláusulas contractuales tipo).
- Retención y borrado (inmediato al eliminar cuenta).
- Derechos RGPD (acceso, rectificación, supresión, portabilidad, limitación, oposición, retirar consentimiento) + derecho a reclamar ante la AEPD.
- Menores (16+).
- Seguridad (TLS, reglas de acceso, App Check).
- Fecha de última actualización visible.

### 6.3 Términos (`/terms`)

Mantener el contenido legal ya vigente en `hosting/terms.html` (leer antes de rediseñar) — el diseñador puede reestilizar libremente, no reescribir el fondo legal sin validarlo.

### 6.4 Soporte (`/support`)

- Contacto directo por email (`soporte@runninglaps.com`).
- Enlace a la FAQ de la landing.

### 6.5 Eliminar cuenta (`/delete-account`)

Requisito de cumplimiento de las tiendas de apps (Google Play / App Store exigen una URL pública de instrucciones de borrado, aunque el usuario no tenga la app instalada). Debe incluir:

- Pasos desde la app (Perfil → Cuenta y ajustes → Eliminar cuenta).
- Alternativa por email (`soporte@runninglaps.com`) con plazo de respuesta (máx. 30 días).
- Qué se elimina exactamente (cuenta, entrenamientos, rutas GPS, FC, plan del coach, participación en grupos).
- Enlace a política de privacidad.

---

## 7. Requisitos funcionales y técnicos

- **Formulario de waitlist:** `POST /api/waitlist` con body JSON `{ email, platform }` (`platform` = `"android"` | `"ios"`). Este endpoint ya existe como Cloud Function (`joinWaitlist`, ver `functions/src/waitlist.ts`) — **no cambiar el contrato** sin coordinarlo, o hay que tocar el backend también. Selector de plataforma obligatorio (radio/segmented, no dropdown).
- **Estático, sin backend propio:** la web se despliega a Firebase Hosting (`hosting/` como public dir). No requiere SSR ni base de datos — puede ser HTML/CSS/JS plano o el output estático de cualquier framework (Next export, Astro, etc.), lo que el diseñador/su equipo prefiera, siempre que compile a estático.
- **Rendimiento:** fuentes self-hosted con preload, imágenes en WebP, `loading="lazy"` salvo la imagen hero, sin librerías de animación pesadas (el motion del manual es CSS transitions simples, no necesita GSAP/Framer).
- **Accesibilidad:** contraste AA, `prefers-reduced-motion` respetado, formularios con labels/aria correctos, focus visible.
- **Responsive:** mobile-first, siguiendo el grid de la Sección 3.
- **Idioma:** español (`lang="es"`), sin selector de idioma.

---

## 8. SEO y metadatos (obligatorio, no opcional)

- Title + meta description orientados a intención de búsqueda ("app entrenamiento running", "coach IA running", "series RPE GPS").
- Canonical a `https://runninglaps.com/`.
- Open Graph completo (title, description, image 1200×630, locale `es_ES`) + Twitter card `summary_large_image`.
- Datos estructurados JSON-LD: `MobileApplication` (con `offers` reflejando que es gratis en beta) y `FAQPage` (con las mismas preguntas visibles en la página — deben coincidir texto a texto con el HTML visible).
- `sitemap.xml` y `robots.txt` actualizados con el dominio final.
- `theme-color` acorde a marca (`#8E24AA`).

---

## 9. Restricciones — qué NO debe llevar la web

- Nada de enlaces a App Store / Google Play (todavía no hay listing público).
- Nada de menciones a Wear OS / reloj — se retiró de la propuesta de valor pública (el producto lo va a discontinuar).
- Nada de precios de pago (el modelo de monetización aún no está definido/implementado).
- Nada de gradientes, blur, glassmorphism, sombras de color, emojis, bold/700, exclamaciones tipo "¡increíble!". Estas son prohibiciones explícitas del manual de marca, no preferencias de estilo.
- Nada de fotografía de stock genérica de corredores sonriendo — si se usa fotografía, debe seguir la regla de la Sección 3 (B/N, documental) o no usarse.

---

## 10. Contactos operativos ya activos

`hola@runninglaps.com`, `soporte@runninglaps.com`, `legal@runninglaps.com` — todos activos vía Cloudflare Email Routing, dominio `runninglaps.com` ya conectado a Firebase Hosting con SSL. No hay que crear nada nuevo aquí, solo usarlos correctamente en cada página (soporte en /support y /delete-account, legal en /privacy).

---

## 11. Entregables esperados del diseñador

A confirmar con el diseñador, pero como mínimo:
- Diseño para los 3 breakpoints principales del manual (móvil / desktop / wide) de las 5 páginas de la Sección 5.
- Assets exportados (o Figma con acceso) para poder maquetar/desarrollar a partir de ahí.
- Si el diseñador también entrega el build final: debe ser compatible con Firebase Hosting estático y respetar el contrato del formulario de waitlist (Sección 7).
