# Banco de Posts Diarios — X / Threads / Stories
> Escribir UNA vez → publicar en X y Threads a la vez. Stories: versión visual del mismo material.
> Coste objetivo por post: 2 minutos. Si te lleva más, simplifica.

---

## Cómo usar este banco

30+ posts listos organizados por tipo. Cada día, elige uno del tipo que toque o improvisa sobre lo que hayas hecho ese día en la app (siempre mejor lo real del día que la plantilla). Los que llevan [corchetes] se rellenan con tu realidad — nunca inventes el contenido del corchete.

**Mix semanal orientativo:** 3 de builder del día · 2 de retrospectiva/opinión · 1 pregunta a la audiencia · 1 libre.

---

## Tipo A — Builder del día (lo que hiciste HOY, capítulo 2)

1. "Hoy he arreglado un bug que llevaba [X] días persiguiéndome. Era [una línea]. Siempre es una línea."
2. "Un beta tester me acaba de decir que [feedback real]. Apuntado. Esto es exactamente para lo que sirve una beta."
3. "Captura de hoy: [screenshot]. Pequeño detalle, pero cada vez se parece más a lo que tenía en la cabeza."
4. "Día raro: 3 horas para algo que pensé que eran 20 minutos. Construir apps en una frase."
5. "Hoy el coach IA ha generado este plan para un usuario: [captura sin datos personales]. Verlo funcionar con gente real no se paga con nada."
6. "Pregunta que me ha hecho un tester hoy y no supe responder: [pregunta]. A veces el usuario ve lo que tú llevas meses sin ver."
7. "Push de hoy: [n] archivos cambiados para mejorar [cosa]. Nadie lo notará. Así se construyen las apps buenas."
8. "Primera vez que [hito real: alguien completa un plan entero / se registra alguien que no conozco / etc.]. Guardando este momento."

## Tipo B — Retrospectiva (capítulo 1, cómo lo construiste)

9. "El primer diseño de Running Laps era horrible. Lo sé porque lo guardé: [captura antigua]. Enseñar el proceso incluye enseñar esto."
10. "Descarté [feature] tras semanas de trabajo. Dolió. Pero la app es mejor sin ella. Saber quitar > saber añadir."
11. "La decisión más difícil hasta ahora: [decisión real de producto]. Elegí [X] porque [razón]. Aún no sé si acerté."
12. "Cosas que no sabía hacer cuando empecé este proyecto: [lista corta real]. Cosas que ahora hago con los ojos cerrados: las mismas."
13. "Por qué un coach con IA y no plantillas: porque ningún runner es una plantilla. Tu semana no se parece a la de nadie."
14. "El nombre 'Running Laps' viene de [historia real]. Las mejores decisiones a veces son las menos pensadas."

## Tipo C — Disciplina / entrenamiento (tu terreno de fuerza)

15. "La motivación es un estado de ánimo. El plan es un compromiso. Solo uno de los dos aparece los lunes a las 6am."
16. "Años entrenando gente me enseñaron una cosa: nadie falla por falta de ganas. Fallan por falta de estructura."
17. "El RPE en una frase: tu cuerpo sabe más que tu reloj. Escúchalo, apúntalo, ajusta."
18. "Entrenar sin plan es como ahorrar sin presupuesto. Puedes tener suerte. O puedes tener sistema."
19. "El error nº1 del que empieza: entrenar duro todos los días. El progreso vive en la alternancia, no en la intensidad constante."
20. "En el gimnasio nadie discute que necesitas un programa. ¿Por qué en running lo normal es improvisar?"
21. "Un plan que no se adapta a tus malos días no es un plan, es una lista de deseos."

## Tipo D — Preguntas a la audiencia (engagement barato)

22. "¿Corres con plan o improvisas cada salida? Sin juicio, curiosidad real."
23. "¿Qué es lo que más te cuesta: empezar a correr o SEGUIR corriendo a las 3 semanas?"
24. "Si pudieras preguntarle algo a un entrenador antes de cada entreno, ¿qué sería? (Lo pregunto por... motivos 👀)"
25. "¿Cuánto pagaríais al mes por un plan de running de verdad, adaptado a vosotros? Respuestas sinceras."
26. "¿Qué app de running usáis y qué le cambiaríais? Estoy tomando notas literalmente."

## Tipo E — Camino al lanzamiento (según se acerque)

27. "Preparando la ficha de la App Store. Nadie te avisa de lo difícil que es resumir meses de trabajo en 3 pantallazos."
28. "Enviada a revisión de Apple. Ahora, el deporte favorito de todo developer: esperar."
29. "[Si ocurre] Apple ha rechazado la app por [motivo]. Bienvenidos al capítulo que todo builder conoce. Arreglando."
30. "Quedan [X] personas en lista de espera para la beta. No pensé que llegaríamos ni a 10."

## Tipo F — Historias reales que YA ocurrieron (con recibos en el repo)

Estas no son plantillas: son historias verídicas del desarrollo, listas para
contar en retrospectiva (capítulo 1/2). Cada una tiene "recibo" (commits,
capturas) por si quieres enseñarlo:

31. **El GPS que no funcionaba en series.** "Mi app medía perfecto en carrera
    continua y marcaba 0 en series. ¿El motivo? El filtro GPS esperaba señal
    'fina' antes de arrancar... y una serie de 400m termina antes de que
    llegue. En continua ni se nota; en series se comía el entreno entero.
    Una línea de código: `return state`." (Historia completa: cada serie
    reiniciaba el GPS desde cero — perfecta para un Reel técnico-accesible.)
32. **El botón principal que no hacía nada.** "El botón de PLAY de mi app —
    EL botón — te llevaba a una pantalla sin salida, y al darle a 'Empezar
    entrenamiento'... no pasaba nada. Un TODO olvidado en el código. Meses
    ahí. Nadie lo vio porque nadie había recorrido ese camino entero."
33. **Las notificaciones que nunca llegaron.** "Programé recordatorios de
    entreno preciosos. Nunca sonaron. Dos motivos: Android los borra al
    reiniciar el móvil si no se lo impides, y Android 14 rechaza el tipo de
    alarma que usaba. Funcionaban perfecto... en mi cabeza."
34. **El día que borré código vivo con un script.** "Escribí un script para
    limpiar código muerto. Se comió código VIVO de la pantalla más crítica.
    Los tests lo cazaron en segundos y git me salvó. Moraleja doble:
    automatiza, pero con red."
35. **952 usos de una función deprecada.** "Flutter deprecó withOpacity.
    Yo lo usaba 952 veces. Historia de cómo se migra eso sin volverse loco
    (spoiler: un script de 40 líneas y una suite de tests)."
36. **El modo oscuro que tuve que apagar.** "Lancé modo oscuro y lo tuve que
    quitar: mi morado de marca sobre negro da 2.5:1 de contraste — ilegible.
    La solución era un morado claro que YA existía en mi paleta. A veces la
    respuesta lleva meses en tu propio código."
37. **El descanso es un vaso que se llena.** "Especifiqué que la pantalla de
    descanso se llenara de azul como un vaso — recuperar el aliento. Lo
    escribí en la guía de diseño... y se me olvidó construirlo durante meses.
    Esta semana existe por fin. [vídeo del efecto]"
38. **Por qué borrar tu cuenta borra TODO.** "Descubrí que si borrabas tu
    cuenta, tus entrenamientos quedaban huérfanos en mi base de datos para
    siempre — sin dueño y sin forma de limpiarlos. RGPD aparte, es feo.
    Ahora una función en la nube lo arrasa todo. Lo invisible también se
    construye."
39. **El test que salvó el pulsómetro.** "Un cambio 'inocente' hacía que las
    series con GPS perdieran los datos de frecuencia cardiaca al guardarse.
    Silenciosamente. Hoy hay un test con nombre y apellidos que grita si
    alguien lo vuelve a romper."
40. **La revisión de 18 commits.** "Paré una semana de features para revisar
    TODO el código: 9 bugs reales, 700 líneas muertas, 70 tests nuevos.
    Nadie ve este trabajo en la app. Por eso lo cuento aquí."

## Stories específicas (además de replicar lo anterior)

- Encuesta: "¿Plan o improvisación?" (sticker de dos opciones)
- Caja de preguntas: "Pregúntame lo que sea sobre la app / sobre entrenar con estructura"
- Time-lapse de 10s de ti trabajando en el código (sin necesidad de que se lea nada)
- Captura del feedback de un tester (con su permiso, sin nombre si prefiere)
- Cuenta atrás para la apertura de beta (sticker countdown) — solo cuando haya fecha real

---

## Reglas del diario

1. **Lo real del día SIEMPRE gana a la plantilla.** El banco es red de seguridad, no menú principal.
2. **Nunca rellenar corchetes con inventos.** Si no pasó, no se publica.
3. **Un post al día es suficiente.** Dos si el día dio para mucho. Cero un día puntual no mata a nadie — la constancia semanal sí importa.
4. **Responde comentarios el mismo día.** En cuentas pequeñas, cada respuesta es un seguidor retenido.
5. **Tono: cercano, honesto, sin humo.** Cero lenguaje de LinkedIn ("encantado de anunciar..."). Escribes como hablas.
