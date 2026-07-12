# La Saga — 8 episodios diseñados, listos para grabar
> Diseñados sobre el estado REAL de la app (jul 2026) · Formatos N0/N1 (sin
> cara obligatoria, tu voz siempre) · Sustituyen a los guiones genéricos del
> doc 02 para las primeras semanas
> Objetivo: retención → enganche a la saga → whitelist → testers

---

## La mecánica de la saga (léela antes que los guiones)

**Nombre de la serie:** "Construyendo Running Laps" — cada pieza lleva
`ep. N` en el texto de apertura. La numeración ES el gancho de serie: el que
llega al ep. 4 por el algoritmo va a buscar el 1.

**Firma visual** (mismo arranque en todos): 0,5s del móvil con la app en la
mano + sticker `ep. N` — antes incluso del hook. El cerebro del scroller
reconoce la serie en medio segundo.

**La regla del bucle abierto:** ningún episodio termina cerrado. Cada cierre
planta la pregunta del siguiente. Está escrito en cada guion — no lo recortes
al editar.

**Progresión del CTA (no la rompas):**
| Episodios | CTA único | Por qué |
|---|---|---|
| 1-3 | "Sígueme para el siguiente" | Primero audiencia; pedir antes de dar mata cuentas pequeñas |
| 4-6 | "Whitelist en la bio" | Ya has dado 4 piezas de valor; ahora conviertes |
| 7-8 | "Comenta BETA" | Reclutamiento real de los 12 testers de Play |

**Cadencia:** 2/semana (ej. martes y sábado). La saga completa = 4 semanas.
Entre episodios, el diario X/Threads/Stories (doc 03) mantiene el pulso.

**Retención — las 5 mecánicas que usan estos guiones:**
1. Hook en el primer segundo: movimiento + afirmación concreta (números, no adjetivos)
2. Duración 20-35s — nunca más
3. Una sola idea por pieza
4. Especificidad brutal ("191 tests", "12 personas", "una línea de código") — lo concreto retiene, lo genérico desliza
5. Bucle: el final reabre (cliffhanger) o reconecta con el inicio (loop visual)

---

## EP. 1 — "La app que no existía" (presentación + demo)
**Duración:** 30s · **Formato:** N0 (manos/pantalla/POV) + tu voz · **CTA:** seguir

| seg | Plano | Voz (tuya, natural) | Texto en pantalla |
|---|---|---|---|
| 0-1,5 | Móvil en mano, la app abierta, el dedo pulsa "generar plan" y APARECE la semana entera | "Esta app no está en ninguna tienda." | `ep. 1 — no está en ninguna tienda` |
| 1,5-8 | Zoom al plan generado: series, ritmos, descansos, días | "Le dices qué días puedes entrenar, tu objetivo... y te monta la semana. Series, ritmos, descansos. Como un entrenador." | `te planifica la semana` |
| 8-16 | Corte a POV: manos en el teclado, código, terminal con tests pasando | "La estoy construyendo yo. Soy entrenador de fuerza — en el gimnasio nadie entrena sin programa. Empecé a correr, busqué una app que me diera un PLAN de verdad... y no existía." | `entrenador de fuerza` → `no existía` |
| 16-24 | POV pista/calle corriendo (2-3s) + vuelta a la app: pantalla de sesión activa con el crono | "Así que llevo meses construyéndola a escondidas. Y ya funciona: la semana que viene me entrena a mí por primera vez, en pista." | `ya funciona` |
| 24-30 | El móvil se bloquea → se ve la app en la pantalla de bloqueo (Live Activity) → negro | "Voy a enseñar todo lo que pase: lo que funcione y lo que explote. Ep. 2 el sábado: el detalle de la app del que más orgulloso estoy." | `ep. 2 — el sábado` |

**Caption:** "Ep. 1. Llevo meses construyendo la app de running que no encontré. La termino en público — lo bueno y lo que explote. 🏃‍♂️ (Sí, hay lista de espera en la bio, pero de momento solo quiero que veas si esto te interesa.)"
**Por qué retiene:** demo real en el segundo 0 (no promesa: producto), identidad con conflicto ("de fuerza construyendo de running"), cita concreta con fecha para el ep. 2.
**Material a grabar:** screen recording del coach generando plan · manos+teclado+terminal (vale `flutter test` pasando en verde) · 3s POV corriendo · Live Activity en pantalla de bloqueo.

---

## EP. 2 — "La pantalla que es un vaso de agua" (el detalle wow)
**Duración:** 22s · **Formato:** N0 puro · **CTA:** seguir

| seg | Plano | Voz | Texto |
|---|---|---|---|
| 0-1,5 | La pantalla de descanso YA llenándose de azul, burbujas subiendo | "Mi app hace esto cuando terminas una serie." | `ep. 2 — mira el fondo` |
| 1,5-9 | La misma pantalla, tiempo real: el azul sube, el contador baja | "Se va llenando de azul mientras recuperas. Como un vaso de agua. Cuando está lleno — respiraste lo que tocaba, y vamos con la siguiente serie." | `recuperar el aliento, literal` |
| 9-16 | Split o corte: boceto/nota de la spec (vale el .md de la guía de diseño) → pantalla final | "Lo diseñé hace meses en un documento... y se me olvidó construirlo. Llevaba ahí, escrito, esperando. Esta semana por fin existe." | `diseñado en mayo` → `construido esta semana` |
| 16-22 | Loop: vuelve al plano inicial del vaso llenándose | "Los detalles que nadie pide son los que hacen que algo se sienta bien. Ep. 3: el botón MÁS importante de mi app... no hacía nada. Te lo cuento el martes." | `ep. 3 — el botón que no hacía nada` |

**Caption:** "Ep. 2. Nadie me pidió esto. Por eso lo hice. 🫧 ¿Detalle favorito de una app que uses?"
**Por qué retiene:** el efecto es hipnótico y único (nadie lo ha visto antes), historia mínima con giro ("lo olvidé meses"), loop visual perfecto + cliffhanger fuerte.
**Material:** screen recording largo del descanso real (déjalo correr 60-90s y acelera en edición) · captura del COLOR_SYSTEM.md con la spec (te la preparo yo).

---

## EP. 3 — "El botón que no hacía nada" (builder honesto, historia real)
**Duración:** 30s · **Formato:** N0 + opcional 2s de cara al cierre · **CTA:** seguir

| seg | Plano | Voz | Texto |
|---|---|---|---|
| 0-1,5 | Dedo pulsando el botón central de PLAY de la app, repetido 2-3 veces rápido | "El botón principal de mi app no hacía nada. Y tardé meses en enterarme." | `ep. 3 — no hacía nada` |
| 1,5-10 | Screen recording del flujo: play → editor → "Empezar entrenamiento" → …nada | "Este es EL botón. El de empezar a entrenar. Te llevaba a crear tu sesión, le dabas a empezar... y ahí se quedaba. Ni entrenaba, ni guardaba. Nada." | `¿y ahora qué?` |
| 10-20 | El código: el TODO en pantalla (te preparo la captura), señalado | "¿El motivo? Esto. Un 'TODO: conectar esto luego' que escribí hace meses... y enterré. La app crecía por todos lados menos por su puerta principal." | `// TODO` en rojo |
| 20-30 | El flujo YA funcionando: play → sesión → GPS corriendo → resumen guardado. Cara 2s si quieres | "Ya está conectado — ahora ese botón te lleva del plan a la pista y guarda el entreno. La moraleja me duele: nadie prueba el camino completo hasta que alguien lo camina. Ep. 4 es todavía peor: el GPS me marcaba CERO metros. Solo en series." | `arreglado ✅` → `ep. 4 — 0 metros` |

**Caption:** "Ep. 3. Construir en público también es enseñar esto. ¿Tu peor 'lo conecto luego'?"
**Por qué retiene:** vulnerabilidad con resolución (no es queja: es arco completo), el espectador no-técnico lo entiende TODO, cliffhanger con número imposible ("0 metros").
**Material:** screen recording del flujo completo arreglado · captura del código con el TODO (te la doy) · opcional: 2s cara.

---

## EP. 4 — "0 metros" (la mejor historia técnica, contada para humanos)
**Duración:** 35s · **Formato:** N0+N1 · **CTA:** ⚡ primera mención a whitelist

| seg | Plano | Voz | Texto |
|---|---|---|---|
| 0-1,5 | POV corriendo fuerte en pista + el móvil marcando "0 m" | "Corrí 400 metros. Mi app dijo: cero." | `ep. 4 — 0 metros` |
| 1,5-9 | Pantalla dividida (edición): carrera continua marcando bien / serie marcando 0 | "Y lo raro: en carrera larga medía perfecto. Solo fallaba en series. Semanas volviéndome loco." | `¿por qué solo en series?` |
| 9-22 | Animación simple o texto sobre mapa/GPS: el móvil "esperando señal fina" | "El motivo es casi bonito: mi filtro GPS esperaba señal MUY precisa antes de empezar a contar. En una carrera de una hora, esos 20 segundos de espera no se notan. En una serie de 90 segundos... la espera se come la serie entera. El GPS no estaba roto. Estaba siendo demasiado perfeccionista." | `esperaba la señal perfecta` → `la serie terminaba antes` |
| 22-30 | El fix: POV serie real con los metros subiendo en vivo desde el primer paso | "La solución: que empiece a contar con lo que hay y se corrija sobre la marcha — y mientras el GPS despierta, cuenta tus pasos. Como hace tu cuerpo, vaya." | `arreglado: cuenta desde el paso 1` |
| 30-35 | La app guardando el entreno, resumen con la serie completa | "Esta app se está construyendo a base de fallar en pista. Si quieres probarla antes que nadie cuando abra — la lista de espera está en la bio. Ep. 5: me entrena a mí por primera vez. Entero, en pista, sin trampas." | `whitelist en la bio` → `ep. 5 — mi primer entreno` |

**Caption:** "Ep. 4. El bug más bonito que he arreglado: un GPS perfeccionista. Lista de espera en la bio para cuando abra la beta 📝"
**Por qué retiene:** apertura con contradicción imposible, misterio con resolución elegante que un no-programador ENTIENDE, y la metáfora ("perfeccionista") lo hace compartible. Primera conversión tras 3 piezas de valor.
**Material:** POV serie en pista (¡tu prueba de campo ES este rodaje — graba todo!) · pantalla con distancia subiendo en vivo · resumen guardado.

---

## EP. 5 — "Me entrena a mí" (el episodio emocional — TU PRUEBA DE CAMPO)
**Duración:** 30-35s · **Formato:** N1 POV atmosférico + N0 · **CTA:** whitelist

⚠️ **Este episodio ES tu prueba de campo pendiente.** El día que bajes a pista
a validar GPS+flujo, graba TODO: llegar, el móvil, las series, el descanso,
el resumen. Material real, emoción real. No lo hagas dos veces.

| seg | Plano | Voz | Texto |
|---|---|---|---|
| 0-1,5 | POV: el dedo pulsa "EMPEZAR" en la pre-ejecución, cuenta atrás 3-2-1 | "Meses construyéndola. Hoy me entrena a mí." | `ep. 5 — el primer entreno` |
| 1,5-10 | POV serie: pista, respiración, el móvil con serie/ritmo en vivo, 2-3 planos cortos | "Primera serie. El plan lo hizo la app. El ritmo lo marca la app. Yo solo tengo que hacer lo que llevo años diciéndole a mis clientes: seguir el plan." | `serie 1/6` (según pantalla real) |
| 10-18 | El descanso: el vaso llenándose EN PISTA, tú recuperando (manos en rodillas vale, sin cara) | "Y esto en pista de verdad... funciona. Recuperas, se llena, sigues. No miré el reloj ni una vez." | `descanso — se llena el vaso` |
| 18-26 | Última serie + resumen final del entreno: distancias, ritmos, RPE | "Seis series. Todas guardadas, con ritmo, esfuerzo y ruta. Hace meses esto era una idea en una libreta." | `entreno guardado ✅` |
| 26-33 | Pantalla de bloqueo con Live Activity → negro | "Falta pulir mil cosas — y para eso os necesito. Lista de espera en la bio: los primeros de la lista serán los primeros en probarla. Ep. 6: la métrica que ningún reloj mide." | `whitelist → bio` → `ep. 6` |

**Caption:** "Ep. 5. Hoy la app me ha entrenado a mí. No sé describir la sensación. Whitelist en la bio — los primeros entran primero. 🏃‍♂️"
**Por qué retiene:** es el pago de la saga (4 episodios de construcción → el momento de verdad), atmósfera POV pura que a ti te gusta grabar, y el CTA cae en el pico emocional.
**Material:** TODO el rodaje de tu prueba de campo. Mínimo: pulsar EMPEZAR, 3 planos de carrera, el vaso en descanso, el resumen, la Live Activity.

---

## EP. 6 — "La métrica que ningún reloj mide" (autoridad: RPE)
**Duración:** 30s · **Formato:** N0 con el slider real · **CTA:** whitelist suave

| seg | Plano | Voz | Texto |
|---|---|---|---|
| 0-1,5 | El slider de RPE deslizándose: el color fluye verde→ámbar→coral→rojo | "La métrica más importante de tu entreno no la mide ningún reloj." | `ep. 6 — ningún reloj la mide` |
| 1,5-12 | Slider en detalle + texto grande | "Se llama RPE: cómo de duro te pareció, del 1 al 10. En fuerza la usamos desde hace décadas, porque tu cuerpo no rinde igual todos los días. El mismo ritmo un martes es un 6... y un jueves sin dormir es un 9." | `mismo ritmo ≠ mismo esfuerzo` |
| 12-22 | La app: registrar RPE en dos toques al acabar la serie → el historial coloreado | "Si solo miras el ritmo, entrenas a ciegas. Por eso en mi app cada serie se guarda con su esfuerzo — dos toques — y el plan de la semana siguiente se adapta a cómo ESTÁS, no a cómo deberías estar." | `2 toques` → `el plan se adapta` |
| 22-30 | Calendario con la carga semanal por colores | "Esto de la izquierda es una semana suave. Esto, una de carga. Tu cuerpo lo sabía — ahora tu app también. Guárdate esto si entrenas con reloj pero sin escucharte." | `guárdatelo 📌` |

**Caption:** "Ep. 6. Años poniendo RPE a levantadores. Ahora se lo pongo a corredores. Whitelist en bio si quieres entrenar así 📝"
**Por qué retiene:** valor educativo real guardable (el guardado dispara distribución), el slider es visualmente perfecto para esto, y refuerza tu única autoridad legítima.
**Material:** slider RPE en movimiento · registro post-serie · calendario TRIMP por colores.

---

## EP. 7 — "Google me exige 12 personas" (el reclutamiento — la joya honesta)
**Duración:** 28s · **Formato:** N0 + cara recomendada 3-4s (es el episodio donde más suma) · **CTA:** comenta BETA
**⚠️ Publicar SOLO con la Fase 0 validada y la cuenta de Play lista.**

| seg | Plano | Voz | Texto |
|---|---|---|---|
| 0-1,5 | Captura real de Play Console con el requisito de prueba cerrada | "Google no me deja publicar mi app. Y tiene razón." | `ep. 7 — Google dice no` |
| 1,5-10 | La pantalla del requisito + zoom al "12 testers / 14 días" | "Para publicar en Google Play siendo un desarrollador individual, te exigen que 12 personas usen la app 14 días seguidos. No es burocracia: es que la prueben humanos de verdad antes de soltarla al mundo." | `12 personas` → `14 días` |
| 10-20 | Montaje rápido de la saga: el plan generándose, el vaso, la pista (recap 1s por episodio) | "Así que esto es una oferta seria: busco 12 corredores — o gente que quiera EMPEZAR a correr con un plan de verdad. Gratis, obviamente. Solo pido que entrenes con ella y me digas todo lo que esté mal." | `busco 12 corredores` |
| 20-28 | Cara 3-4s (o POV pista si no) | "Los saco de la lista de espera y de los comentarios. Comenta BETA y te escribo yo — soy una persona con un móvil, no una empresa. Android primero; iPhone, segunda ola." | `comenta BETA` |

**Caption:** "Ep. 7. Necesito 12 personas que rompan mi app. Comenta BETA 👇 (Android primero — cosas de Google. iPhone en la segunda ola.)"
**Por qué retiene:** el hook es contraintuitivo y VERDADERO (nadie sabe que Google exige esto — es noticia), la escasez es real y no inventada, y pedir ayuda desde la honestidad convierte mejor que vender.
**Material:** captura de Play Console (cuando exista la cuenta) · recap de clips ya grabados · 4s de cara si te ves.

---

## EP. 8 — "Los 12" (prueba social + cierre de temporada)
**Duración:** 25-30s · **Formato:** N0 · **CTA:** whitelist ("la segunda ola sale de aquí")
**Se escribe SOLO con material real de la beta.** Estructura prevista:

- Hook: "12 desconocidos llevan una semana entrenando con mi app." (`ep. 8`)
- Desarrollo: 2-3 capturas de feedback real (con permiso, sin nombres) — el
  primer bug encontrado por un tester, la primera sugerencia implementada,
  el primer "esto me ha venido genial".
- Verdad incómoda incluida: lo que peor ha ido. La saga es creíble porque
  enseña las dos caras.
- Cierre: "La segunda ola de testers sale de la whitelist. Y la temporada 2
  de esta saga empieza donde acaba esta: camino de la App Store." →
  **cliffhanger de temporada** (Apple review = arco narrativo entero).

---

## Reglas de producción de la saga

1. **Graba en horizontal NADA.** Todo vertical 9:16 nativo.
2. **Subtítulos quemados siempre** (CapCut/Kapwing auto + repaso a mano).
3. **Tu voz en todos** — graba la voz DESPUÉS de montar los planos, leyendo
   el guion 3 veces y quedándote con la más natural (la tercera, casi siempre).
4. **El sticker `ep. N` va en el mismo sitio en todos** (arriba-izquierda).
5. Los guiones de los eps. 7-8 son plantillas de la parte REAL — si la
   realidad da mejor material (que lo dará), la realidad manda.
6. Cada episodio se trocea después para el diario: 1 captura → Story,
   1 frase del guion → post de X/Threads. Un rodaje, tres canales.

## Qué necesito de ti para dejarte el material técnico listo

Avísame antes de grabar cada episodio y te preparo: capturas del código
real para el ep. 3 (el TODO) y el ep. 4 (el `return state`), la spec del
vaso para el ep. 2 (COLOR_SYSTEM.md § Descanso), y screen recordings guiados
de la app si quieres exactamente los flujos que salen en cada guion.
