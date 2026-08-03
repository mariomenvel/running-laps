# CHANGELOG — Running Laps

## [Fix] — La pantalla de zonas se contradecía a sí misma — 2026-08-03
Encontrado probando en dispositivo, no por los tests: al elegir 197 en la rueda
de FCmáx, la tabla de abajo seguía diciendo "FCmáx 194 bpm" con los límites
viejos hasta pulsar Guardar. Dos números distintos para lo mismo, a la vez, en
la misma pantalla.

La causa: la previsualización salía de `ZonesViewModel.effectiveFcMax`, que
deriva del perfil **guardado**, mientras el campo mostraba el valor en pantalla.
No lo introdujo la migración a rueda —con el `TextField` pasaba igual—, pero se
nota más ahora que elegir un valor es un gesto y no teclear.

Ahora la previsualización usa `ZonesService().fcMaxEffective(_fcMax, birthDate)`
sobre el valor en pantalla. De paso, el botón de limpiar por fin se ve hacer
algo: las zonas saltan de vuelta a las estimadas por edad.

Se eliminan `effectiveFcMax` y `currentZones` del viewmodel: quedaron sin uso, y
dejarlos era dejar la trampa puesta para el siguiente que previsualizara con
ellos.

## [Feat] — La frecuencia cardíaca llega hasta el Coach — 2026-07-29
Con el pulsómetro ya conectando, se recorrió la cadena entera de la FC: en
vivo → resumen → historial → Coach IA. Funcionaba la mitad, y la mitad que
funcionaba mentía un poco.

**Cuatro cosas rotas:**
- **La FC media de sesión era la media de las medias por serie.** Una serie de
  30 s pesaba igual que un rodaje de 20 min, y como las cortas son las
  intensas, la media salía inflada. Ahora se calcula sobre las lecturas reales
  (`FcSessionStats`, 7 tests); sin lecturas punto a punto cae a las medias por
  serie **ponderadas por duración**.
- **El pico no se guardaba.** Solo la media. El detalle del historial lo
  recalculaba de las lecturas, pero el Coach solo recibe el resumen: no tenía
  forma de saber cuánto se apretó. Campo nuevo `fcMaxSesion`.
- **Las sesiones planificadas no calculaban TRIMP.** Solo lo hacía el flujo de
  series; las sesiones que vienen del plan del Coach —justo las que más importa
  medir— se guardaban sin `loadScore` y el propio Coach caía al proxy por RPE,
  ignorando la FC. Ahora se calcula en el resumen, que es el punto común de
  guardado de ambos flujos.
- **La zona durante el descanso estaba siempre vacía**: se le pasaba un
  `ValueNotifier<int?>(null)` creado en la línea, que nunca se actualizaba —
  y se fugaba uno nuevo por serie. Justo el momento en que miras si has bajado.

**Lo que el Coach recibe ahora** (`fc_analytics.dart`, lógica pura, 14 tests):
reparto del tiempo por zona, índice de eficiencia (m/min por pulsación),
desacople cardíaco y deriva de FC, más el pico y la FC en reposo. Con eso puede
ver lo que antes no: que los rodajes se corren en Z3, que el desacople se
repite (base aeróbica corta), o que a igual ritmo la FC está bajando —evidencia
para progresar aunque el RPE no se mueva—. El prompt lleva sección propia
explicando cada campo, con dos límites escritos: no comparar eficiencia entre
tipos de sesión distintos, y **la FC no manda sobre el RPE ni sobre las
molestias**.

Detalle importante del reparto por zonas: se pondera **por tiempo**, no por
número de lecturas. El historial contaba lecturas, así que una serie muestreada
más densa se comía el porcentaje. Ahora resumen, historial y Coach comparten
cálculo (`FcAnalytics`) y widget (`core/widgets/fc_zone_bars.dart`) — no pueden
dar cifras distintas del mismo entreno.

**Mina encontrada de paso en `firestore.rules`:** el `allow create` de
`trainings` exigía `keys().size() < 20` y `Entrenamiento.toMap()` ya escribía
**20** claves en el peor caso — es decir, un entreno con todos los campos
opcionales rellenos se denegaba en silencio *antes* de este cambio (fail-closed,
igual que el bug de `.toString()` de abril 2026). No estaba dando la cara porque
un create real rara vez lleva `analysis`, `isManual` y `source` a la vez.
`fcMaxSesion` lo dejaba en 21. Límite subido a 30 —quien frena el abuso de
verdad son los topes de título y número de series, no el de claves— y añadido
`test/unit/entrenamiento_firestore_test.dart`, que cuenta las claves del peor
caso y se pone en rojo si un campo nuevo vuelve a acercarse al tope.
✅ Reglas **desplegadas** en producción el 31 jul 2026 (`firebase deploy --only
firestore:rules` → `running-laps-mario-2025`). El mismo deploy publicó los otros
dos cambios que llevaban desde el 22-24 jul sin subir: la retirada del bypass de
Wear OS —que permitía `create` en `trainings` sin sesión de Auth— junto con la
colección `wear_sessions` de `create` abierto, y el alta de `raceGoals`.

**Y en pantalla:** bloque de FC en el resumen post-entreno (mín/media/pico,
reparto por zonas y FC por serie, que solo existía en el historial), FC media
acumulada en vivo junto al instantáneo, y etiqueta de zona (Z1-Z5) siempre
visible — antes solo se veía el color, y la etiqueta únicamente si la sesión
traía zona objetivo.

## [Fix] — El buscador de pulsómetros no encontraba nada — 2026-07-29
Primera prueba del pulsómetro en dispositivo real: el escaneo se quedaba
buscando los 10 segundos y terminaba con la lista vacía, sin decir nada.

Causa principal: `scanForDevices(withServices: [0x180D])`. Ese filtro se traduce
a un `ScanFilter` nativo en Android y a un filtro de CoreBluetooth en iOS, y
**ambos miran solo el paquete de advertising**. Muchas bandas (Polar, Garmin,
Coospo) no anuncian el Heart Rate Service ahí — lo exponen al hacer discovery,
ya conectadas —, así que el filtro las descartaba antes de que la app pudiera
verlas. Ahora se escanea abierto y se filtra en Dart: se listan los anuncios con
nombre o con 0x180D, los confirmados como pulsómetro salen primero y etiquetados
(corazón rojo), y dentro de cada grupo manda el RSSI, así que la banda que
llevas puesta queda arriba. Como la lista ya no está filtrada por servicio, el
`onError` de la suscripción sirve además para avisar de "ese dispositivo no
envía frecuencia cardíaca" si alguien conecta con sus auriculares.

Dos causas secundarias que también daban cero resultados:
- **Escaneo antes de que el adaptador esté listo.** `getBleStatus()` hacía
  `statusStream.first`, y el primer valor es siempre `unknown` mientras arranca
  el cliente nativo. Ahora espera al primer estado definitivo (`firstWhere(s !=
  unknown)`) y `startScan` no arranca hasta tener `ready` — era el fallo típico
  del primer intento tras abrir la app.
- **Android ≤ 11 con la ubicación del sistema apagada.** El escaneo BLE devuelve
  cero resultados sin error. `minSdk` es 26, así que hay dispositivos afectados;
  se comprueba y se avisa (en API 31+ no aplica: `BLUETOOTH_SCAN` va con
  `neverForLocation`). De paso, en API ≤ 30 se dejó de pedir
  `Permission.bluetooth` (permiso de instalación, no runtime): quien gatea el
  escaneo ahí es la ubicación.

Y lo que hacía el problema indepurable: **el escaneo vacío no explicaba nada**.
`requestPermissions()` devolvía un `bool`, así que la vista mostraba un
"Bluetooth no disponible" genérico (con el texto de iOS, "Centro de Control",
también en Android). Ahora devuelve `HrPermissionResult` con el motivo concreto
y la pantalla enseña una tarjeta de diagnóstico: Bluetooth apagado, permiso
denegado, ubicación apagada, o —cuando no aparece nada— la lista de qué
comprobar, empezando por la que más veces es: **si el pulsómetro está emparejado
en los ajustes de Bluetooth del móvil, hay que quitarlo de ahí**. Una banda BLE
admite una sola conexión; mientras el sistema la tiene cogida deja de anunciarse
y ninguna app puede verla.

Extra: `stopScan()` ahora invalida el escaneo pendiente (antes solo cancelaba la
suscripción, y el `startScan` en vuelo seguía esperando su timeout), y los dos
`AlertDialog` de Material de la pantalla pasaron a `showAppConfirmDialog`
(deuda #8: quedan 6 ficheros).

## [Test] — Cubierto cuándo se programan las notificaciones — 2026-07-26
Equivocarse aquí no da un error: da un aviso a la hora que no toca o, peor,
programado **en el pasado** — que en Android hace que la notificación salte
inmediatamente. Es de las pocas cosas que el usuario percibe directamente como
"esta app me molesta".

El cálculo estaba escrito tres veces (recordatorio de sesión, resumen del
domingo, feedback del sábado), dos de ellas con el mismo bucle `while` copiado.
Ahora hay dos funciones puras —`nextWeekdayAt` y `sessionReminderTime`— usadas
por los tres sitios, con 8 tests: hoy si aún no ha llegado la hora, semana
siguiente si ya pasó, la hora exacta cuenta como hoy, y el aviso de "entreno en
1 hora" devuelve null si esa hora ya pasó y cruza bien la medianoche en una
sesión de madrugada (avisa el día anterior a las 23:30).

Suite 310 → 318.

## [Test] — Cubiertos los números de Analytics — 2026-07-26
Récords, ritmo medio, reparto de intensidad, racha, ACWR: cifras que el usuario
lee y se cree. Un error ahí no rompe nada — simplemente le cuenta otra historia
sobre su propio entrenamiento, y no tiene con qué contrastarla.

`AnalyticsViewModel.compute()` resultó ser función pura de sus argumentos, así
que se fija sin tocar Firebase. 9 tests, incluidos los criterios que no se
adivinan mirando la pantalla: el corte de intensidad está en RPE 7 (7,0 ya
cuenta como fuerte), la consistencia cuenta **semanas activas** y no
entrenamientos, la carga aguda solo mira los últimos 7 días, y el **ritmo medio
se pondera por distancia** — 1 km a 6:00 y 9 km a 4:00 dan 4:12, no 5:00, que
es el error clásico de promediar ritmos.

Suite 301 → 310.

## [Test] — Cubierto el reparto del plan semanal por días — 2026-07-26
Es la promesa más concreta que le hace el Coach al atleta: *"solo te planifico
los días que me has dicho"*. Y no la puede garantizar el LLM — la garantiza este
código, reubicando lo que venga del modelo. Si falla, el usuario abre el
calendario y ve entrenos en días en los que dijo que no puede.

12 tests sobre las tres funciones que lo deciden:
- **Normalización de días**: los perfiles antiguos guardaban 0..6 con 0 =
  domingo, los nuevos 1..7 como Dart. Si esa traducción se equivoca, el plan
  entero se corre de día.
- **Días factibles**: los del perfil (o un reparto por defecto según el número
  de sesiones si no los ha dicho), descartando los que ya pasaron.
- **Reubicación**: una sesión en día no disponible se mueve al primero libre,
  nunca se ponen dos el mismo día, se respetan los días ya ocupados por sesiones
  existentes, y si no quedan días **se descarta la sesión sobrante** en vez de
  doblarla.

Quinto y sexto servicio con dependencias perezosas (`AiCoachWeeklyPlannerService`
y, antes, `AiCoachContextBuilder`): construirlos ya no exige Firebase.

Suite 289 → 301.

## [Test] — Cubiertos los filtros del historial — 2026-07-26
Son la única forma de encontrar un entreno concreto entre cientos, y fallan en
silencio: si un filtro se come un entrenamiento, para el usuario simplemente no
existe. 9 tests fijan los criterios exactos, incluidos los bordes que no son
obvios leyendo la pantalla — "tiradas largas" es **más** de 10 km (10 km
clavados no entran), "alta intensidad" es RPE medio **por encima** de 7, el
rango de fechas personalizado cubre los días de los extremos enteros (de las
00:00 a las 23:59) y **manda sobre** el filtro predefinido.

Por el camino, un bug de verdad en `HistoryController`: el constructor creaba
**siempre** un `TrainingRepository` y solo después lo sustituía por el
inyectado, así que inyectar no evitaba tocar `FirebaseFirestore.instance` —
justo lo que la inyección existía para evitar. Ahora es perezoso. Lo mismo con
`TagManager`, que instanciaba Auth y Firestore como campos.

Suite 280 → 289.

## [Test] — Cubierto lo que el Coach IA ve de tu semana — 2026-07-26
`buildWeeklyState` es el resumen que se le manda al LLM: adherencia, volumen,
carga aguda (ATL), crónica (CTL) y frescura (TSB = CTL − ATL). Si eso miente, el
plan que genera está mal razonado por muy bueno que sea el prompt — y **no hay
forma de darse cuenta mirando la app**.

Es función pura de sus argumentos, así que 8 tests la fijan entera: el filtrado
por semana con límites inclusivos (lunes y domingo cuentan), la adherencia
—incluido el 1.0 cuando no hay sesiones planificadas, en vez de una división por
cero—, el volumen, el RPE medio ignorando entrenos sin series, y el bloque de
carga: una semana dura deja el TSB negativo, y sin entrenos el "días desde el
último" es el centinela 999 y no 0 (que significaría "hoy").

Tercer servicio al que se le hacen perezosas las dependencias por el mismo
motivo que ayer: `AiCoachContextBuilder` construía cuatro repositorios en su
constructor, así que instanciarlo exigía Firebase real aunque solo fueras a usar
la parte pura.

Suite 272 → 280.

## [Test] — Cubierta la cuota semanal del chat del coach — 2026-07-26
Esta lógica ha roto **dos veces**, y las dos en silencio: una el contador se
quedaba pillado y el chat no dejaba escribir aunque hubiera empezado semana
nueva, y otra el badge enseñaba el límite guardado (40) en vez del canónico (3).
No tenía tests.

5 tests sobre los tres caminos: crear la cuota si no existe, resetear el
contador cuando el periodo guardado ya pasó, y **normalizar un límite antiguo
sin perder `messagesUsed` ni `previewsGenerated`** — que es exactamente el
error que hubo que corregir en julio. Más el caso del reloj mal puesto (periodo
en el futuro), que si no se resetea deja la cuota bloqueada hasta esa fecha.

Para poder testearlo hicieron falta dos cambios de fontanería, ninguno de
comportamiento:
- `AiCoachChatService` construía **toda** su cadena de dependencias en el
  constructor, así que instanciarlo pedía Firebase real. Ahora los
  colaboradores son perezosos: se crean al usarse y un test inyecta solo el que
  necesita.
- `AiCoachRepository` evaluaba `FirebaseAuth.instance` al construirse; ahora es
  un getter perezoso, igual que ya hacía `HomeEstadisticaRepository`.

De paso se eliminaron 4 `debugPrint('[Prep] ...')` que quedaron de cazar aquel
bug y seguían escupiendo el estado de la cuota en cada interacción del chat.

Suite 267 → 272.

## [Test] — Cubierto el mapeo que transporta el contenido del entrenamiento — 2026-07-26
`athlete_session_mapper` traduce entre la sesión planificada que vive en
Firestore (y pinta el calendario) y la sesión del editor. Por ahí viaja **el
contenido**: repeticiones, distancias, descansos, calentamiento y vuelta a la
calma. Si pierde algo, planificas 6×1000 y la app te ofrece ejecutar otra cosa
— sin error, sin aviso. Tenía **un** test, y solo del tipo de sesión.

9 tests nuevos en `athlete_session_blocks_test`, en las dos direcciones e ida y
vuelta completa (editor → Firestore → editor de un 6×1km, que es justo el caso
que se verificó a mano en dispositivo esta tarde). Incluyen los casos de borde
que hoy resuelve el mapper en silencio: sin descanso no se inventa un segmento
de recuperación, un bloque sin distancia ni tiempo no genera segmentos vacíos, y
una sesión sin bloques sigue cumpliendo el invariante de "al menos un bloque
principal" que exige `WorkoutSession`.

Suite 258 → 267.

## [Test] — Cubiertos los récords personales — 2026-07-26
`ProgressRepository.updateRollupAfterSave` no tenía ni un test, y es el sitio
donde un fallo da marcas personales falsas **sin que nada parezca roto**: es una
optimización (compara solo las series del entreno recién guardado contra el
rollup cacheado, en vez de reescanear el historial), así que si se equivoca,
simplemente enseña un récord que no es.

7 tests: mejora el récord solo si el ritmo es mejor; **no** toca el rollup si es
peor (y conserva el `trainingId` anterior); respeta las ventanas de distancia
estándar — 950 m cuenta para el récord de 1000 y 700 m no cuenta para ninguno;
ignora series sin distancia o sin tiempo; no hace nada con un entreno que aún no
tiene id; y crea el rollup escaneando el historial la primera vez.

Suite 251 → 258.

## [Chore] — Más reglas del proyecto convertidas en test — 2026-07-26
`architecture_test` pasa de 5 a 9 comprobaciones: además de que ninguna vista
toque Firebase, ahora vigila que no se use `AppBar` de Material (la cabecera es
`AppHeader` + `BackPill`), ni `showDatePicker` (hay `showAppDatePicker`, rueda
iOS con el rango clampeado), ni colores sueltos de Material
(`Colors.orange/green/blue` — el color sale de `AppColors` y comunica estado),
ni `print()` en `lib/` (va `debugPrint`, que el framework silencia en release).

Solo se han fijado las reglas que **hoy se cumplen al 100%**. Hizo falta migrar
un `showDatePicker` que quedaba en `create_challenge_modal`, con 19 líneas de
Material y tema a mano que ahora son cuatro parámetros.

Las dos que **no** se han fijado, con lista de ficheros en CLAUDE.md (deuda #8):
números con teclado en vez de `NumberPickerField` (6 ficheros) y `AlertDialog`
en vez de `showAppConfirmDialog` (7). Son trabajo de UI que hay que ver en
dispositivo, no un cambio mecánico — y un test en rojo desde el primer día se
acaba ignorando, que es peor que no tenerlo.

Suite 247 → 251.

## [Refactor] — Ninguna vista instancia Firebase, y un test lo vigila — 2026-07-26
Cierra la regla de CLAUDE.md que estaba a medias: las vistas ya no tocaban
Firestore, pero `FirebaseAuth.instance` seguía en **24 ficheros (61 usos)**.

- `UserService.currentUid` sustituye a `FirebaseAuth.instance.currentUser?.uid`.
- `UserService.awaitCurrentUid()` recoge un patrón que estaba **copiado en tres
  vistas** (home, calendario, analytics): `currentUser` síncrono y, si aún no
  hay sesión restaurada, esperar el stream con timeout de 5 s.
- `AuthWrapper` y la pantalla de verificación de email pasan por
  `AuthRepository` (stream de sesión y `signOut`), que ya los tenía.

**El test es la parte que importa**: `test/features/architecture_test.dart`
comprueba las reglas, no el comportamiento. Escanea `lib/features/**/views/` y
falla si alguien reintroduce `FirebaseFirestore.instance`, `FirebaseAuth.instance`,
`dart:html` o un `ScaffoldMessenger.showSnackBar` a pelo — diciendo el fichero y
a qué servicio llevarlo. Es el tipo de test que protege una decisión de
arquitectura de la erosión, que es exactamente cómo se había perdido esta.

De hecho ya encontró dos infracciones vivas al escribirlo: `create_challenge_modal`
y `blocks_list_section` mostraban snackbars crudos en vez de `ModernSnackBar`
(migrados). Y lleva un test de cordura que verifica que la lista de vistas no
está vacía: sin él, mover carpetas dejaría los demás pasando sin comprobar nada.

Suite 242 → 247. `flutter analyze` 58 → 57 avisos.

⚠️ Sin humo en dispositivo: el móvil se bloqueó (batería al 13%) antes de poder
recorrer las pantallas. La app **compila e instala** con los 24 ficheros
cambiados y el analizador está limpio, pero el paseo visual queda pendiente.

## [Fix] — "Completar manualmente": el botón guardaba en silencio o no guardaba — 2026-07-26
Encontrado usando la app: rellenas los tiempos, pulsas GUARDAR SESIÓN y **no
pasa nada**. Parece la app rota. Lo que faltaba era el RPE global, y había tres
cosas conspirando:

1. El campo **mentía**: `NumberPickerField` recibía `_globalRpe ?? 5`, así que
   mostraba un "5" que nadie había elegido. Visualmente estaba relleno.
2. El aviso salía en un **snackbar** que se va solo, fácil de perderse.
3. El campo está **debajo del botón**, fuera de pantalla: aunque leyeras el
   aviso, no veías qué te faltaba.

Ahora: `NumberPickerField` acepta `displayOverride` para no fingir un valor
(muestra "Elegir"), al intentar guardar la vista **se desplaza sola** hasta el
campo (`Scrollable.ensureVisible`) y aparece un texto en rojo explicando *por
qué* es obligatorio ("ninguna serie tiene RPE, así que hace falta el de la
sesión"). El rojo solo aparece **después** de intentar guardar: avisar antes es
regañar por adelantado.

Verificado en dispositivo: guardar sin RPE lleva al campo y lo explica; con el
RPE puesto, guarda y aparece en el historial.

## [Perf] — Las trazas GPS salen del documento del entrenamiento — 2026-07-26
Cada entrenamiento guardaba dentro sus coordenadas: la traza de la sesión
(`trackPoints`) y la de cada serie (`gpsPoints`). Como Firestore devuelve el
documento entero, **listar entrenamientos descargaba todas las trazas** aunque
la pantalla solo pintara distancia y fecha. El calendario y analytics piden 12
meses: para un usuario con un año de entrenos reales eso son megas por visita,
y en móvil se nota. También acercaba el documento al límite de 1 MiB.

Ahora la traza vive en `users/{uid}/trainings/{id}/track/data`
(`trackPoints` + `seriesGps` indexado por posición de serie) y el documento del
entrenamiento queda ligero. Solo se lee cuando alguien va a pintar un mapa:
`TrainingRepository.withTrack(training)`, que llama el detalle del
entrenamiento al abrirse.

Decisiones que no son mecánicas:
- **La traza se escribe DESPUÉS del entrenamiento y tolerando el fallo.** En un
  batch atómico, una traza que no cupiera tiraría la sesión entera; así, en el
  peor caso te quedas sin mapa pero nunca sin el entrenamiento.
- **`overwriteTraining` pasa a `merge: true`.** Los entrenamientos anteriores a
  jul 2026 llevan la traza embebida; al guardar notas o RPE desde el resumen se
  reenvía el entrenamiento ya sin trazas, y un `set` sin merge se las habría
  llevado por delante. Con merge, se conservan.
- **Compatibilidad hacia atrás sin migración ni backfill**: `withTrack()`
  detecta que el entrenamiento ya trae la traza embebida y lo devuelve tal cual.

Cubierto por 5 tests nuevos contra Firestore simulado (suite 237 → 242), uno de
ellos justo sobre el caso de no borrar la traza antigua al guardar.

⚠️ Lo que **no** arregla: los otros dos problemas de escala de grupos — el
ranking de un reto lee los entrenamientos de todos los miembros
(`group_detail_repository`) y guardar un entreno recalcula cada reto desde cero
(`training_challenge_sync_service`). Están fuera del MVP; anotados como deuda.

## [Feature] — Pantalla de ajustes nueva, con solo lo que va a producto — 2026-07-26
`AccountSettingsView` (1.231 líneas, UI antigua) se sustituye por
`profile/views/settings_view.dart` (~450), con las **tres funciones que van a
producto**: cambiar nombre, borrar cuenta y GPS por defecto. Es además el sitio
donde vivirá la gestión de la suscripción, por eso sigue siendo una pantalla y
no se disolvió dentro del menú de Perfil.

Se retiran por decisión de producto: estilo de tarjetas, alarmas por defecto,
distancia de marca destacada y **cambiar contraseña**. ⚠️ Esto último tiene
consecuencia real: una cuenta de email/contraseña ya no puede cambiarla desde
dentro de la app — queda el "olvidé mi contraseña" desde el login.

La pantalla sigue el sistema actual: `AppHeader`, tokens de
`AppColors`, `showAppBottomSheet` para los dos flujos sensibles, colores
sólidos (los degradados están prohibidos salvo Live Activity), iconos en gris
salvo estado activo. **Sin pill de "Volver"**: las pantallas hermanas abiertas
desde el mismo menú de Perfil (Zonas, Pulsómetro) tampoco la llevan — dentro
del shell se vuelve con el atrás del sistema o la barra inferior; `BackPill`
es para vistas pusheadas como ruta propia. El sheet de nombre y el de borrado piden contraseña solo
si la cuenta es de email: con Google/Apple la reautenticación la resuelve el
proveedor. La reautenticación antes de borrar no es adorno — la Cloud Function
`deleteUserData` exige sesión reciente (`auth_time` < 10 min).

También: `GradientBanner` pintaba su texto **siempre en blanco**, así que con
un `accentColor` claro el contenido quedaba invisible (título y subtítulo del
banner de ajustes y del panel de admin). Ahora elige blanco o texto primario
según la luminancia real del fondo. El nombre del widget engaña: no pinta
ningún degradado, es un color plano.

Verificado en dispositivo: la pantalla carga con el nombre real, el sheet de
cambio de nombre muestra el aviso correcto para cuenta de Google, y el toggle
de GPS persiste. `flutter test` 237 OK, `flutter analyze` 58 avisos (0 errores).

## [Fix] — Tres bugs del botón atrás encontrados probando en dispositivo — 2026-07-26
Salieron al verificar el refactor MVVM del editor en un móvil real (Poco X3
Pro, Android 12). Ninguno los ve `flutter analyze` ni la suite: son de
interacción entre `PopScope` y el `IndexedStack` del shell.

**1. Diálogos de pestañas ocultas secuestrando el atrás.** El `IndexedStack`
mantiene montadas *todas* las pestañas, así que el `PopScope` de una pestaña
invisible sigue registrado en la ruta. Con un entreno a medias en la pestaña
15, cualquier "atrás" — en Perfil, en el calendario, donde fuera — sacaba
"¿Abandonar entrenamiento?" encima de la pantalla equivocada; lo mismo con
"¿Salir sin guardar?" del editor (pestaña 13). Nuevo `ShellSlotScope`
(`core/widgets/shell_embedding_scope.dart`): el shell envuelve cada hijo del
`IndexedStack` marcando si es el visible, y ambas pantallas condicionan su
`PopScope` a eso. Fuera del shell (pantalla pusheada) no hay scope y devuelve
`true`, que es el comportamiento correcto ahí.

**2. El callback también hay que condicionarlo, no solo `canPop`.** Cuando
*cualquier* `PopScope` de la ruta bloquea el pop, Flutter llama a
`onPopInvokedWithResult` de **todos** ellos con `didPop == false`. Con solo
arreglar `canPop`, el diálogo de la pestaña oculta seguía saliendo porque lo
disparaba el bloqueo de otra. De ahí el `&& isVisible` en los callbacks.

**3. El atrás del editor no hacía nada.** Consecuencia de lo mismo una capa
más arriba: el `PopScope` del propio `MainShell` llamaba a `navigateBack()`
aunque el pop lo hubiera bloqueado una pestaña self-managed. Como
`navigateBack()` **intercambia** pestaña actual y anterior, las dos llamadas
(la del shell y la del editor) se anulaban y te quedabas en el editor. Ahora
el shell solo actúa si es él quien intercepta (`&& interceptSystemBack`).

**Y un cuarto, del propio refactor:** `hasChanges()` comparaba contra
`initialSession`, pero al abrir una sesión planificada desde el calendario la
sesión llega por `shellParams.session`. Resultado: el editor creía que todo
era nuevo y preguntaba "¿Salir sin guardar?" sin haber tocado nada. Ahora
compara contra la sesión de partida real, venga por donde venga. Con test de
regresión (suite 236 → 237).

Verificado en el dispositivo tras cada arreglo: abrir sesión planificada y
salir sin tocar nada vuelve al calendario limpio; tocar el tipo y salir sí
avisa; guardar crea y editar actualiza sin duplicar.

## [Refactor] — Ninguna vista habla ya directamente con Firestore — 2026-07-26
La regla estaba escrita en CLAUDE.md desde siempre ("nunca instanciar
`FirebaseFirestore.instance` en vistas") y la incumplían **9 pantallas**, que
montaban sus propias queries dentro del widget. Ahora son cero.

Dónde ha ido cada cosa:
- `UserService` gana el acceso a `users/{uid}`: `getUserData`, `watchUserData`
  (el stream que usa `AuthWrapper`; devuelve `null` cuando el documento aún no
  existe, que es distinto de un perfil vacío — esa distinción es la que evita
  mandar a un usuario recién creado al onboarding otra vez),
  `completeOnboarding`, `saveGenerativeAvatar`, `updateProfileFields`, y la
  distancia de marca destacada (`users/{uid}/settings/bestMarkDistance`).
- `TrainingRepository` gana `overwriteTraining` (reescribe el doc completo —
  documentado como tal, porque `set` sin merge borra lo que no venga) y
  `deleteTraining`. La pantalla de resumen ya no construye `DocumentReference`
  ni importa `cloud_firestore`: el sello `updatedAt` lo pone el repositorio,
  como en el resto de escrituras.
- `AiCoachRepository.deleteWeeklyFeedback()` para el reset del panel admin.
- **`TestDataService`** (`core/services/test_data_service.dart`): los ~190
  líneas de generación de datos de prueba que vivían dentro de
  `profile_view.dart` escribiendo batches a Firestore desde el widget. La vista
  quedó en 12 líneas que llaman al servicio y muestran el resumen que devuelve.

Vistas tocadas: `profile_view`, `account_settings_view`, `training_summary_screen`,
`welcome_view`, `auth_wrapper`, `calendar_view`, `home_view`,
`avatar_customizer_view`, `ai_coach_onboarding_view`.

⚠️ Queda la otra mitad de la regla: `FirebaseAuth.instance.currentUser?.uid`
sigue en 23 vistas (61 usos). Es un cambio bastante más ancho y no se ha
tocado aquí.

Verificado: `flutter analyze` 58 avisos y 0 errores, `flutter test` 236 OK,
`flutter build apk --debug` OK. Sin comprobación en dispositivo todavía.

## [Refactor] — WorkoutEditorScreen pasa a MVVM (deuda #3) — 2026-07-26
La lógica de negocio del editor sale de la `State` a
`templates/viewmodels/workout_editor_view_model.dart`: composición de la
`WorkoutSession`, nombre automático, bloques por defecto por tipo, generación
por IA y persistencia como sesión planificada (con el recordatorio de 1 h). La
vista se queda con lo suyo — renderizar, navegar y avisar. El viewmodel **no
conoce `BuildContext`**: devuelve `SaveResult` / `AiGenerationResult` y es la
vista quien decide el snackbar o el `pop`. 842 → 528 líneas de vista + 406 de
viewmodel.

**No se mergeó la rama `refactor/workout-editor-mvvm`** (parada desde el 21 jun).
Main tocó ese fichero en 11 commits desde entonces, y la rama reintroducía
`initSpeech()` en el `initState` — exactamente lo que se quitó al migrar a
permisos just-in-time, que en iOS dispara el diálogo de micrófono al abrir la
pantalla. Se rehízo desde main usando la rama solo como referencia de diseño
(de ahí vienen `SaveResult`/`AiGenerationResult`). La colisión
`WorkoutType.free` ↔ `continuous` que documentaba esa rama ya está arreglada en
main: `free` mapea a `gimnasio_fuerza` y el round-trip funciona.

Detalles del refactor que no son mecánicos:
- El `TextEditingController` del nombre se sincroniza escuchando `vm.title`, con
  comparación previa: sin ella, reescribir el controlador mientras el usuario
  teclea le movería el cursor al final.
- `resolveTitle` y `buildSession` son puras y están marcadas
  `@visibleForTesting` — son lo que sostiene los 19 tests nuevos
  (`test/features/templates/workout_editor_view_model_test.dart`, suite total
  217 → 236).
- Se eliminó `ValueListenableBuilder2`, un helper público definido en la vista
  que no usaba nadie (por público, `flutter analyze` no lo marcaba).
- Se retira el `try/catch` que envolvía el `initState`: solo tragaba el error y
  dejaba los campos `late final` sin inicializar, así que el fallo reaparecía
  después como `LateInitializationError`. Mejor que falle donde falla.

## [Chore] — Cerrada la deuda de cargas masivas: fuera `getAllEntrenamientos()` — 2026-07-26
Última consulta del repo que traía hasta 500 entrenamientos de golpe **con sus
`gpsPoints` dentro**. Sobrevivía solo por `home_view_legacy`, eliminada en la
purga de julio; desde entonces no tenía un solo call site (la única mención que
quedaba era un comentario histórico en `home_view_model.dart`). Home, calendario
y analytics ya consultan acotado con `getTrainingsSince()`.

Para listados nuevos: `getTrainings()` (paginado por cursor) o
`getTrainingsSince()` (acotado por fecha, con el bound en UTC según la
convención de `fecha`). No reintroducir una carga sin límite.

De paso, limpieza de ramas locales: 20 ramas cuyo contenido ya estaba
íntegramente en `main` (verificado por contenido, no por nombre: `--merged` y
`rev-list --count main..origin/<rama>` = 0). Quedan las dos que sí tienen
trabajo propio — `feature/workout-execution` (PreExecutionScreen, mayo 2026,
también en origin) y `refactor/workout-editor-mvvm` (**solo local, no está en
origin**: es la única copia de ese trabajo).

## [Chore] — Cuarta purga de código muerto: 3 ficheros, ~1.400 líneas y 6 dependencias — 2026-07-26
Barrido igual que el de julio (alcanzabilidad transitiva desde `main.dart`, no
greps), pero esta vez también **dentro** de ficheros vivos: miembros privados
que el analizador demuestra no referenciados.

**Trampa encontrada en el método de auditoría** — el script de alcanzabilidad
daba un falso positivo (`premium_date_range_picker.dart`, que sí usa
`admin_dashboard_tab.dart`). Causa: los imports relativos se resuelven en el
espacio de URIs de `package:`, donde `lib/` es la raíz y los `..` que sobran se
**descartan** (RFC 3986 clampea en la autoridad). Por eso
`'../../../../config/app_theme.dart'` desde `lib/features/admin/views/` apunta a
`lib/config/app_theme.dart` y no a `<repo>/config/...`. Hay 16 imports así en el
repo. Cualquier futuro barrido debe resolver con ese clamp, o borrará ficheros
vivos.

**Ficheros eliminados** (clúster del editor de avatar legado, se referenciaban
solo entre sí): `avatar_editor_wraper_view.dart`, `avatar_maker_screen.dart`,
`avatar_maker_controller.dart`. La rama `profilePicType == 'avatar'` de
`AvatarHelper` se conserva para renderizar los docs ya guardados con ese
formato; el editor vivo es `avatar_customizer_view.dart`.

**Código muerto dentro de ficheros vivos** (~1.180 líneas):
- `training_start_view.dart`: −920 líneas. Dos subsistemas enteros sin punto de
  entrada — el selector "¿Qué entrenamos hoy?" (`_buildTypeSelector`,
  `_buildTypeCard`, `_buildTypeConfig` y sus `_cfg*` con `TextField` numéricos,
  que además incumplían la convención de `NumberPickerField`) y las pestañas
  antiguas (`_buildQuickStartTab`, `_buildTemplatesTab`) con sus toggles de
  GPS/pulsómetro, superados por `_buildSensors()`, que es el que se pinta.
  También `_openTemplateSelector`/`_createMomentaryTemplate`: **efecto
  observado, no causado por esta purga — desde "Entrenar" ya no hay forma de
  cargar una plantilla guardada** (las plantillas siguen accesibles desde su
  propia pestaña). Si se quiere recuperar ese acceso, hay que volver a montarlo.
- `training_session_view.dart`: `_handleResume` (reanudar crono/GPS tras pausa,
  sin llamadas: la pantalla activa ya no ofrece esa acción), `_buildMetricsGrid`,
  `_buildMetricCard`, `_buildSmallTimer`, `_getPaceColor`.
- `training_summary_screen.dart`: `_buildStats`, `_statItem`, `_rpeColor`, campo
  `_fcMedia` (se asignaba y nadie lo leía).
- `training_start_view.dart` (jul 2026) tenía además un bug latente en el código
  borrado: `_buildActionCard` declaraba `bool isPressed` *dentro* del builder del
  `StatefulBuilder`, así que la animación de pulsado nunca se veía (el
  analizador lo marcaba como `dead_code`).
- Varios `final isDark = ...` sin usar, la animación inerte del header de
  `group_screen.dart` (un `AnimationController` que hacía `forward()` sobre una
  `Animation` que nadie pintaba), campos `_history`/`_photoUrl`/`_ritmoActual`
  asignados y nunca leídos, y 9 imports huérfanos.

**Dependencias retiradas de `pubspec.yaml`** (cero imports en lib/ y test/):
`get`, `firebase_storage`, `http`, `image_picker`, `gal`, `path_provider` — 19
paquetes menos contando transitivas. GetX desaparece del proyecto por completo:
su último uso estaba en el editor de avatar legado, así que la regla "estado con
`ValueNotifier`, nunca GetX" ya no depende de la disciplina, no está el paquete.

Verificado con `flutter analyze` (122 → 59 avisos, 0 errores), `flutter test`
(217 OK) y `flutter build apk --debug`. Los 59 restantes son de estilo
(`curly_braces`, `use_super_parameters`…) más 9 `unused_element_parameter` que
son parámetros con valor por defecto legítimos (p. ej. `_ManualSerieData`), no
código muerto.

## [Fix] — Enlaces legales otra vez alcanzables dentro de la app — 2026-07-26
Regresión de la unificación del menú de perfil (`0d615b3`, 24 jul): los tiles
"Ayuda y contacto", "Política de privacidad" y "Términos de uso" solo existían
en `profile_menu_screen_legacy.dart` y desaparecieron al borrar el duplicado,
sin reimplantarse en `ProfileView`. Resultado: el único punto de la app que
abría `runninglaps.com/{privacy,terms}` era `auth_page.dart` (login/registro),
al que un usuario ya logueado no vuelve nunca — es decir, se volvía a incumplir
la política de Google Play que exige el enlace *dentro* de la app ("must be
linked directly within the app itself"), lo mismo que se había arreglado el
19 jul.

Fix: sección AYUDA de [profile_view.dart](lib/features/profile/views/profile_view.dart)
amplía sus tiles con soporte, privacidad y términos vía `_openWebPage()`
(`url_launcher` + `LaunchMode.externalApplication`, ya era dependencia del
proyecto y el `<queries>` de ACTION_VIEW/https ya estaba en el manifest). A
diferencia del original, si `launchUrl` devuelve `false` se avisa con
`ModernSnackBar.showError` en vez de fallar en silencio. Las rutas sin `.html`
funcionan por `cleanUrls: true` de `firebase.json`.

Nota de proceso: la doc daba el punto por ✅ mientras citaba un archivo ya
borrado — al eliminar una vista "duplicada" hay que verificar que **todo** su
contenido único está en la que sobrevive, no solo la navegación.

## [Fix] — La app queda bloqueada en vertical (portrait) — 2026-07-26
No estaba contemplado en ninguna capa: girar el móvil rotaba toda la app, que
no tiene ni un layout pensado para landscape. Bloqueado en los tres sitios que
hacen falta para que la garantía sea real:

- **Dart** (`main.dart`): `SystemChrome.setPreferredOrientations([portraitUp])`
  como primera cosa del `main()`, dentro de `if (!kIsWeb)` — en Web no aplica y
  el lock de orientación del navegador puede rechazar la promesa.
- **Android** (`AndroidManifest.xml`): `android:screenOrientation="portrait"` en
  `.MainActivity`. Necesario *además* del lock de Dart porque cubre el splash
  nativo (`LaunchTheme`), que se dibuja antes de que el engine ejecute `main()`.
- **iOS** (`Info.plist`): `UISupportedInterfaceOrientations` y su variante
  `~ipad` reducidas a `UIInterfaceOrientationPortrait` (el plist manda sobre
  `SystemChrome` en iOS, así que sin esto el lock de Dart se quedaba a medias),
  más `UIRequiresFullScreen: true` — la renuncia explícita al multitasking de
  iPad, que es lo que permite declarar solo portrait ahí sin que App Store lo
  marque en revisión. Efecto secundario aceptado: sin Split View / Slide Over
  en iPad. La clave está deprecada en iPadOS 26; si algún día se apunta a iPad
  en serio habrá que rediseñar para landscape en vez de depender de ella.

Regla derivada (documentada en `NAVIGATION_ARCHITECTURE.md`): no reactivar
landscape desde vistas concretas — el candidato obvio es el mapa a pantalla
completa del historial, y en Android el manifest lo ignoraría igualmente.

De paso, `pubspec.lock` se pone al día eliminando `mobile_scanner`, que ya se
había quitado de `pubspec.yaml` con la retirada de Wear OS pero seguía en el
lock.

## [Fix] — Unificado el menú de perfil, eliminado profile_menu_screen_legacy.dart — 2026-07-24
Cierra el pendiente de la auditoría del 2026-06-19 (ver más abajo). El menú
"legacy" solo seguía vivo porque era el único de los dos que funcionaba
correctamente cuando se abría empujado por encima de Admin/Templates/Grupos:
`ProfileView` (el tab real, slot 3 de `MainShell`) navegaba a sus
sub-pantallas con `MainShell.shellKey.currentState?.navigateTo(index)`, que
solo tiene efecto visible si `ProfileView` es el tab activo del
`IndexedStack` — si se pushea encima de otra pantalla, cambiar el tab por
debajo no se ve. `ProfileMenuView` (legacy) en cambio siempre usaba
`Navigator.push()` directo, por eso sobrevivía en esos 6 sitios.

Fix real: `ProfileView` ahora usa `ShellEmbeddingScope.isEmbedded(context)`
(el mismo patrón ya usado en `templates_list_view.dart` y
`avatar_customizer_view.dart`) para decidir — embebida en el shell:
`navigateTo()`; pusheada standalone: `Navigator.push()` a la pantalla
correspondiente directamente. Los 6 call sites (`admin_panel_screen.dart`,
`templates_list_view.dart`, `group_screen.dart`, `groups_list_screen.dart`,
`challenge_detail_screen.dart`, `participant_profile_screen.dart`) ahora
abren `ProfileView` en vez del duplicado. `profile_menu_screen_legacy.dart`
eliminado — un solo menú de perfil en toda la app, sin contenido
desincronizado entre los dos.

## [Feature] — Récords detectados y celebrados en todos los flujos de guardado — 2026-07-16
La detección de récords solo existía en el flujo de entreno libre
(`training_start_view`): el flujo estructurado con GPS, el registro manual y
el completar manualmente no comprobaban nada. Nuevo
`core/services/pb_celebration_service.dart` como punto único:
- **Récords por serie** (400/1000/1500/5000/10000 m): tras guardar se
  recalculan los récords (`ProgressRepository`) — los que apunten al entreno
  recién guardado son nuevos → notificación local con distancia y ritmo.
- **Marcas de sesión** 5K/10K/media/maratón (`PbDetector`, ±3%): actualizan
  el perfil del coach (alimentan el VDOT) → notificación local con el
  tiempo. Ahora también en entrenos manuales (tiempos de pista/cinta), antes
  solo GPS.
- Cableado en: `training_summary_screen._saveTraining` (cubre flujo libre y
  estructurado — se celebran solo entrenos confirmados, no descartados),
  `complete_session_manually_view` y `manual_training_view`. Los dos checks
  privados duplicados de `training_start_view` eliminados.
- `NotificationService.showSessionPb()` nuevo (el body es tiempo total, sin
  el sufijo "/km" de `showPersonalRecord`).

## [Perf] — Queries de trainings acotadas por fecha (deuda #3) — 2026-07-16
`getAllEntrenamientos()` traía hasta 500 docs de golpe — cada uno con sus
gpsPoints dentro — en cada apertura de home, calendario y analytics. Nuevo
`TrainingRepository.getTrainingsSince(since)` (bound UTC inclusivo sobre
`fecha`, orden desc) y cada consumidor pide solo su ventana:
- **Home** (`home_view_model`): 5 recientes (`getTrainings` pageSize 5) +
  semana actual desde el lunes local para las stats semanales.
- **Calendario** (`calendar_view_model`): últimos 12 meses.
- **Analytics** (`analytics_hub_controller`): 12 meses (máximo del selector);
  un rango custom más antiguo que lo cargado amplía la ventana y re-filtra.
- `getAllEntrenamientos()` queda marcado como legacy (solo lo usa la huérfana
  `home_view_legacy`). Pendiente aparte: rollup cacheado para los PBs de
  `ProgressRepository` (necesitan historial completo). +3 tests
  (`getTrainingsSince`: bound inclusivo UTC, orden, ventana vacía).

## [UX] — Ritmo objetivo en s/100m para atletas de pista — 2026-07-13
Toggle `min/km` / `s/100m` en la tarjeta PACE del sheet de segmento: quien
mide "el 100 en 28" introduce el objetivo directamente en segundos por 100 m
(ruedas 12.0–54.5, pasos de 0.5 s/100m = 5 s/km, misma granularidad) y la app
lo convierte a seg/km por detrás — `TargetConfig` y todo lo aguas abajo
(metrónomo, GPS, coach) no cambian. La preferencia se persiste
(`SettingsService.getPacePer100`). Con el modo activo, la fila informativa
del metrónomo muestra "28 s/100m (4:40 /km)".

## [UX] — Auditoría de navegación: header estándar + sin flechas de volver — 2026-07-13
Barrido página a página: toda pantalla con header usa el `AppHeader` global
(logo + avatar; variante con `title:` centrado permitida) y ninguna lleva
flecha/botón de volver en el header. Volver = swipe iOS (`AppRoute` es
`CupertinoPageRoute`; `MaterialPageRoute` hereda transición Cupertino en iOS)
+ botón/gesto Android, con la pill "Volver" como affordance visible.
- Nuevo widget compartido [`BackPill`](lib/core/widgets/back_pill.dart)
  (antes duplicado como `_AnimatedBackButton`/`_BackPill` en 6 archivos —
  todos migrados; `color:` opcional para el acento del editor de plantillas).
- Convertidas de `AppBar`/header custom a `AppHeader` + `BackPill`:
  `coach_philosophy_view`, `ai_coach_settings_view` (consciente de shell),
  `ai_coach_weekly_feedback_view` (el "Cancelar" era un AppBar),
  `workout_pattern_detail/carousel`, `series_pattern_detail/carousel`,
  `pattern_comparison_view`, `manual_training_view` (acción "Guardar" movida
  a la fila de la pill), `edit_home_view` ("Reset" ídem), `zones_config_screen`
  (consciente de shell) y el escáner QR de `wear_auth_service` (pill flotante
  sobre la cámara).
- Sin cambios (correctas): vistas con `AppHeader` título-only (`athlete_hub`,
  `season`, `progress`, `heart_rate_monitor`), pantallas con pill ya existente
  (grupos, detalle de entreno), huérfanas de deuda #5 (no se tocan), y los dos
  `PopScope(canPop: false)` intencionales (editor con cambios sin guardar y
  sesión de entrenamiento activa).

## [UX] — Metrónomo por ritmo hereda el ritmo objetivo del segmento — 2026-07-12
Si el segmento tiene ritmo objetivo configurado, el aviso "Por ritmo" ya no
pide el pace otra vez: lo toma del objetivo (punto medio si es un rango) y
solo pregunta cada cuántos metros debe sonar.
- `_targetPaceSecPerKm` / `_effectiveAlertPace*` en `_SegmentBottomSheetState`:
  el pace del aviso se deriva en vivo del objetivo — si editas el ritmo
  objetivo en la misma sheet, el metrónomo lo sigue. Sin ritmo objetivo, las
  ruedas de pace del aviso se muestran como antes.
- En modo ritmo con objetivo: fila informativa "Al ritmo objetivo del
  segmento · 4:30 /km" en lugar de las dos ruedas.
- Al activar el metrónomo con ritmo objetivo ya configurado (y sin aviso
  previo guardado), arranca directamente en modo "Por ritmo".
- Ver [segment_bottom_sheet.dart](lib/features/templates/views/widgets/segment_bottom_sheet.dart).

## [Fix] — MVP forzado a light mode únicamente — 2026-07-05
Decisión de producto: el MVP lanza solo en modo claro. El toggle
sistema/claro/oscuro ya estaba implementado y en producción (no era código
muerto, ver auditoría debajo), pero `AppTheme.dark()` reutiliza el mismo
morado de marca sobre fondos oscuros y el contraste resulta insuficiente —
queda pendiente de pulir para una fase futura antes de reactivarlo.
- `ThemeService.themeMode` fijo en `ThemeMode.light`; `init()` ya no lee
  preferencia persistida (no-op) — ver
  [theme_service.dart](lib/core/theme/theme_service.dart).
- Quitado el selector de tema de `Perfil` (`_showThemePicker`,
  `_currentThemeLabel`, clase `_ThemeOption`) — ver
  [profile_view.dart](lib/features/profile/views/profile_view.dart).
- Quitado el selector de tema de `Ajustes de cuenta` (`_buildThemeSelector`,
  `_buildThemeOption`) — ver
  [account_settings_view.dart](lib/features/profile/views/account_settings_view.dart).
- `AppTheme.dark()` y la lógica de persistencia de `ThemeService.setTheme()`
  se mantienen intactas en el código, sin exponerse en UI, para cuando se
  retome dark mode.

## [Auditoría] — Estado real de theming (dark/light) — 2026-07-05
Se pidió revertir un supuesto rewrite "dark-only" de `app_theme.dart` del
2026-04-28 (con `AppTheme.light()` eliminado y `main.dart` forzando
`ThemeMode.dark`). Auditoría de `git log --since="2026-04-28" -- lib/` y del
código actual no encontró tal commit ni tal estado:
- `AppTheme.light()` existe y está completo en
  [app_theme.dart](lib/core/theme/app_theme.dart).
- `main.dart` no fija `ThemeMode.dark`: usa
  [`ThemeService.themeMode`](lib/core/theme/theme_service.dart), un
  `ValueNotifier<ThemeMode>` persistido en SharedPreferences que soporta
  `system` (default), `light` y `dark`.
- No se tocó código de theming en esta tarea — solo se corrige la
  documentación de `COLOR_SYSTEM.md` para que no describa `AppTheme.dark()`
  como código muerto de una fase futura, cuando en realidad ya está expuesto
  y activo.

Si la decisión de producto sigue siendo "MVP solo en light mode", falta un
cambio de código real (fijar `ThemeMode.light` en `main.dart` y no exponer
el toggle) que no se ha aplicado todavía.

## [Fix] — Onboarding completo de extremo a extremo (fix/onboarding-bugs)

### Registro y verificación de email
- `EmailVerificationPendingView` se muestra siempre tras el registro (antes a
  veces requería recargar la app manualmente)
- `AuthWrapper` espera a que exista el documento `users/{uid}` en Firestore
  antes de decidir la ruta (evitaba salto directo a `MainShell` con documento
  aún no creado)
- Fix overflow en `EmailVerificationPendingView` que rompía el render en
  pantallas pequeñas o con teclado abierto (`SingleChildScrollView` +
  `ConstrainedBox` + `IntrinsicHeight`)
- Timer periódico (3 s) en `AuthWrapper` detecta verificación de email
  automáticamente sin parpadeo ni rebuild innecesario

### Onboarding AI Coach — flujo y navegación
- Timeout 30 s + botón Cancelar en pantalla de carga del LLM
- Fix overflow en paso de marcas personales con teclado abierto
- `onCompleted` cambiado de `VoidCallback` a `Future<void> Function()` para
  esperar la escritura en Firestore antes de generar el plan
- `isAthleteMode: true` se escribe en Firestore antes de llamar a
  `forceGenerateCurrentWeekPlan` (elimina race condition)
- `popUntil(isFirst)` limpia el stack de navegación completo tras el onboarding
- `_isProcessing` + `_currentStep` se resetean en el happy path y en Cancelar
- Guard `context.mounted` antes de `Navigator.pop` en el launcher

### Onboarding AI Coach — calidad del perfil
- Schema del LLM: constraint `enum` en `goal` (7 valores exactos) + description
  en `goalDescription` para evitar que el modelo confunda ambos campos
- Nuevo paso 5: fecha de nacimiento + sexo biológico (opcionales; se guardan en
  `users/{uid}.birthDate` (ISO8601) y `.sex`)
- Paso de marcas personales reordenado al paso 6 (último); eliminado botón
  "Saltar" redundante — sustituido por botón único "Crear mi plan →"
- Eliminado sheet automático de fecha/sexo en `ZonesConfigScreen` (los datos
  ya se recogen en el onboarding del Coach)

### Generación del plan semanal
- Fallback a semana siguiente si `feasibleWeekdays` queda vacío al generar
  a mitad de semana
- `_subscribeToMonth` en `CalendarViewModel` ahora cubre semanas completas
  (lunes a domingo) que desbordan el mes natural, para que sesiones del mes
  siguiente visibles en la cuadrícula aparezcan sin navegar de mes
- Guards `_disposed` tras cada `await` en `CalendarViewModel.loadAll()` para
  evitar escrituras en `ValueNotifier` ya destruidos

---

## [Fix] — Bugs críticos del onboarding (rama: fix/onboarding-bugs)
- Timeout de 30 s en la llamada al LLM del onboarding del AI Coach; antes podía
  quedarse cargando hasta 60 s (límite de Cloud Function) sin feedback
- Mensaje de error diferenciado para timeout vs. error de red/servidor
- Botón "Cancelar" en la pantalla de loading del onboarding para salir sin
  esperar a que venza el timeout
- Fix overflow en el paso de marcas personales cuando el teclado sube
  (SingleChildScrollView + padding adaptativo)
- Fix sheet de fecha/sexo (ZonesConfigScreen) que podía aparecer encima del
  onboarding del AI Coach; ahora se suprime si hay una ruta modal encima
- Verificación de email tras registro: ya implementada en AuthController
  (sendEmailVerification) + AuthWrapper redirige a EmailVerificationPendingView
- Google Sign-In: implementado pero crashea en iOS (assertionFailure en
  AppDelegate.configureGoogleSignIn) — pendiente Xcode/logs

## [AI Coach] — Reset semanal automático del chat (Cloud Function)
- Scheduled Function resetWeeklyChatUsage: cada lunes 00:05 (Europe/Madrid)
  resetea messagesUsed a 0 y actualiza periodStart/periodEnd para todos los
  usuarios con plan athlete_chat_weekly y messagesUsed > 0
- Más robusto que el reset en cliente (que dependía de que el usuario abriera
  la app esa semana); ahora el reset ocurre aunque el usuario no abra la app
- Batches de 500 documentos para escalar sin límite de usuarios
- firestore.indexes.json: índice collectionGroup "settings" por plan +
  messagesUsed, necesario para la query de la función
- firebase.json: añadida referencia a firestore.indexes.json

## [AI Coach] — Progresión intra-sesión semana a semana
- AiCoachWorkoutTarget: targetReps (int?) y targetSegmentDistanceM (int?) —
  el LLM especifica reps y metros por rep directamente en la decisión semanal
- coachSignals.lastSessionByCategory: datos de la última sesión ejecutada por
  categoría (seriesCount, avgSeriesDistanceM, paceCompliance, rpe) construidos
  cruzando AiCoachTrainingSummary con Entrenamiento para obtener reps reales
- Schema JSON: targetReps y targetSegmentDistanceM añadidos con descripción
- Prompt: sección explícita de progresión con umbrales paceCompliance (75/90%)
  y regla de 3 niveles (progresar/mantener/reducir); rangos por categoría
- Generador: series_cortas/largas/medias/cuestas respetan targetReps y
  targetSegmentDistanceM del LLM con fallback al cálculo anterior

## [AI Coach] — Auto-guardar marcas desde entrenos
- PbDetector (lib/features/ai_coach/data/pb_detector.dart): detecta marcas
  en 5K/10K/HM/M con tolerancia ±3% de distancia e interpolación lineal
  si hay diferencia de metros respecto a la distancia exacta
- Solo activo en entrenos con GPS (training.gps == true) — distancia fiable
- Si mejora el PB actual → actualiza AiCoachProfile en Firestore via saveProfile
- Snackbar de celebración al detectar nuevo récord (etiqueta legible + tiempo)
- Integrado en training_start_view._saveTrainingToFirebase, antes de navegar
  al resumen — fire-and-forget con try/catch para no bloquear el flujo

## [AI Coach] — FC en zonas + TSB al LLM + path lesión
- SessionBlock: nuevo campo targetFcBpm (int?) — punto medio de la zona
  en bpm calculado desde fcMax del perfil (Z1=52%, Z2=65%, Z3=75%, Z4=85%, Z5=95%)
- Todos los helpers del generador propagamos fcBpm: _buildBaseRunBlocks,
  _buildRepeatedSeriesBlocks, _buildFartlekBlocks, _buildTempoBlocks,
  _buildTestBlocks, _buildProgressiveLongRunBlocks, _buildMixedSeriesBlocks
- Prompt: sección TSB con umbrales explícitos (+10 fresco, −5/+10 óptimo,
  −10 fatigado, −20 deload inmediato). TSB ya estaba calculado y persistido
  en AiCoachWeeklyState — ahora el LLM tiene instrucciones para interpretarlo
- Generador: guard de seguridad para lesión/recuperación — cualquier sesión
  intensa (quality category) se redirige automáticamente a _buildBaseRunBlocks
  con rpe≤5.5, km≤6, min≤40 y nota explicativa cuando hay lesión o adjustment
  es recover/reduce. effectiveRpe/effectiveZone aplicados en el resto de casos

## [AI Coach] — Protocolo de evaluación inicial
- coachSignals: nuevos campos isNewAthlete, hasNoPbs, weekOfPlan,
  needsBaselineAssessment (true si sin marcas y weekOfPlan ≤ 3)
- Prompt: protocolo explícito semana 1 (solo base/regenerativo),
  semana 2 (fartlek suave opcional), semana 3 (test 5K/3K de referencia)
- _buildTestBlocks: protocolo real — calentamiento específico (progresivos),
  bloque de test con instrucciones claras, vuelta a la calma extendida 10 min
- Nueva categoría 'evaluacion': rodaje sin pace objetivo con nota explicativa;
  normaliza también 'evaluation' y 'baseline'

## [AI Coach — Pendiente] — Actualización automática de marcas
- Cuando el sistema detecte un nuevo RP en 5K/10K/HM/M durante el resumen
  de un entreno, actualizar automáticamente pb*Seconds en AiCoachProfile
- Punto de integración: TrainingSummaryScreen o el servicio que detecta RPs,
  tras confirmar el récord
- Sin intervención manual del atleta

## [AI Coach — Pendiente] — Test de FCmáx guiado
- Protocolo de 20-30 min: rodaje progresivo hasta esfuerzo máximo con pulsómetro BLE
- Resultado: fcMax real guardado en AiCoachProfile
- Beneficio: zonas de FC calibradas individualmente en lugar de 220-edad
- Dependencia: pulsómetro BLE conectado (HeartRateService)
- Integrar en AiCoachSettingsView como opción avanzada

## [AI Coach] — Paces personalizados por VDOT
- Nuevo VdotCalculator (fórmulas Daniels & Gilbert 1979): estima VDOT desde
  marcas del perfil, calcula paces por zona (Z1-Z5) vía Newton-Raphson
- Series cortas: Z5/R-pace personalizado, reps clamp 4-12 (antes mín 6 sin tope)
- Series largas: Z4/I-pace personalizado, reps clamp 3-8 (antes mín 3 sin tope)
- Series cuestas: adapta reps/distancia/descanso al complexityTier
  (antes hardcoded 10×200m 75s para todos los niveles)
- Fartlek: intercala bloques de recuperación Z1 entre estímulos Z3
  (antes bloques de esfuerzo consecutivos sin recovery explícito)
- Tempo: paces Z3 personalizados en las 3 variantes A/B/C; si no hay
  marcas, fallback a valores hardcodeados previos
- Fallback completo a valores hardcodeados cuando el perfil no tiene marcas

## [AI Coach] — Marcas estructuradas en el perfil
- AiCoachProfile: nuevos campos pb5kSeconds, pb10kSeconds, pbHalfMarathonSeconds,
  pbMarathonSeconds (int?, segundos totales) con toMap/fromMap/copyWith (sentinel)
- AiCoachSettingsView: sección "MARCAS PERSONALES" con campos MM:SS para 4 distancias
  ubicada entre OBJETIVO y DISPONIBILIDAD
- Onboarding: paso 5 opcional "¿Tienes marcas personales?" con botón "Saltar" y
  "Crear mi plan →" en paralelo; si se salta, el perfil queda sin marcas
- Payload LLM: marcas formateadas como "MM:SS" en athleteProfile.pb5k / pb10k /
  pbHalfMarathon / pbMarathon — el LLM puede usarlas para calibrar intensidad y pace
- Próximo: calcular paces VDOT desde estas marcas en el generador Dart

## [AI Coach] — Retroalimentación de ediciones manuales
- AthleteSession: nuevo campo originalDate (String?) — se fija al crear la
  sesión en createSession(), nunca se modifica en updateSession()
- Si date != originalDate: sesión fue movida por el atleta → se incluye en
  athleteEdits del payload con movedFrom/movedTo
- Si suggestion.status == 'edited': sesión fue modificada en bloques/intensidad
  → se incluye en athleteEdits con edited: true
- AiCoachPlannedSessionSummary: nuevo campo originalDate propagado desde
  AthleteSession vía AiCoachContextBuilder
- _buildAthleteEdits() en AiCoachPromptBuilder construye el bloque y lo
  mezcla en el payload solo si hay ediciones

## [AI Coach] — Mejoras de prompt y periodización
- System prompt reescrito con principios 80/20, regla de 48h entre sesiones
  intensas, guía de fase (base/specific/taper/race_week) y respuesta al
  rendimiento real del atleta
- Payload ampliado con planContext (weeksRemaining, targetDate, phase) —
  calculado en Dart a partir de targetDate, no delegado al LLM
- _phaseForWeeksRemaining() helper nuevo en AiCoachPromptBuilder
- Validación de preferredDay contra availableDays ya existía en _pickDay()
  del generador (availableDays.contains) — confirmado, sin cambios necesarios
- Ediciones manuales (wasManuallyEdited): campo no existe en AthleteSession —
  PENDIENTE implementar; athleteEdits ya mencionado en prompt para cuando se añada
- Rama: feat/ai-coach-prompt-improvements

## [UI] — WorkoutEditorScreen: eliminado AppBar
- AppBar con título "Nueva sesión" + X + tick eliminado — redundante con
  swipe atrás (iOS) y botón "Guardar sesión" del footer
- Añadido PopScope(canPop: false) para que el swipe/back nativo pase
  por _onClose y su diálogo de confirmación de descarte

## [UI] — WorkoutTypeSelector: grid → chips horizontales
- Sustituido GridView.count (6 tarjetas cuadradas) por Wrap de chips pill (5 tipos)
- Eliminada "Libre" como tipo seleccionable en el editor (sigue existiendo en el
  enum para datos históricos, pero no aparece en la UI)
- Tipos disponibles: Continuo / Series / Cuestas / Competición / Fartlek
- `WorkoutType.competition` es el valor del enum real (no `race`); ajustado respecto
  al enunciado original

## [UX] — Toggles GPS/pulsómetro junto a "Correr libre"
- _buildSensors() movido a _buildNoSessionOptions(),
  debajo de "Correr libre" — ya no aparece en todas
  las ramas del FAB (solo relevante para correr libre)
- Fix: _startContinuousRun() usaba gpsActivo: true
  hardcodeado ignorando el toggle del usuario —
  ahora usa _vm.gpsOn
- _buildStartButtonNew() (play circular) oculto
  cuando hay sesión planificada para hoy (redundante
  con el botón "Empezar sesión" de la card)

## [Fix] — FAB: navegar a PreExecutionScreen tras planificar sesión de hoy
- AthleteSessionShellParams: nuevo campo onSaved
  (callback con la AthleteSession recién creada)
- WorkoutEditorScreen._onSave: llama onSaved tras
  crear sesión nueva con shellParams
- TrainingStartView: "Planificar sesión de hoy"
  pasa onSaved → _launchPlannedSession, eliminando
  el workaround Future.delayed(1s)
- Resultado: guardar sesión desde el editor →
  navega directo a PreExecutionScreen con la
  estructura completa

## [Fix] — FAB: _launchPlannedSession usa flujo correcto
- _launchPlannedSession ahora usa
  mapAthleteSessionToWorkout + PreExecutionScreen,
  igual que el calendario (antes usaba _startContinuousRun,
  ignorando toda la estructura de la sesión planificada)
- _buildNoSessionOptions simplificado a 2 opciones:
  "Correr libre" y "Planificar sesión de hoy"
  (eliminada "Sesión rápida" redundante)
- Recarga de sesión tras planificar: workaround con
  Future.delayed(1s) — pendiente callback real desde
  WorkoutEditorScreen al guardar
- Rama: feat/fab-flow-redesign

## [UX] — Rediseño flujo FAB de inicio de entrenamiento
- FAB detecta automáticamente sesión planificada para hoy
  (getSessionsForDate, sin necesitar pasar athleteSessionId)
- Sin sesión: 3 opciones claras (Correr libre /
  Planificar sesión / Sesión rápida con grid colapsable)
- Con sesión: card con botón "Empezar sesión" prominente
  + "Ignorar" como opción secundaria
- Simplificadas las categorías de sesión rápida:
  Continuo / Series / Cuestas / Competición / Fartlek
  (eliminadas Rodaje, Libre, Tempo, Largo como categorías
  separadas — todas eran continuas)
- athleteSessionId explícito (desde athlete_hub_view)
  sigue teniendo prioridad sobre búsqueda automática
- Rama: feat/fab-flow-redesign

## [UI] — RPE post-serie: RpeSlider + lógica corregida
- _showRpePicker (training_session_view.dart):
  sustituido IosPicker por RpeSlider — consistente
  con editor de segmento y resumen de entreno
- training_summary_screen.dart: _showRpe ahora oculta
  el slider de RPE global cuando ya hay RPE capturado
  por serie individual (antes solo lo ocultaba si
  series.length > 1, lo cual era incorrecto para
  entrenos de 1 serie donde el RPE ya se capturó)
- Rama: feat/rpe-slider-shared

## [UI] — RpeSlider: componente compartido
- Nuevo lib/core/widgets/rpe_slider.dart: slider
  con track de gradiente verde→ámbar→coral→rojo,
  thumb con color semántico, etiquetas Suave/Máximo
- Aplicado en training_summary_screen.dart
  (sustituye Slider Material estándar) y
  segment_bottom_sheet.dart (_RpeRow)
- Rama: feat/rpe-slider-shared

## [Fix] — Crash al iniciar entrenamiento
- workout_execution_screen.dart: targetRpe se
  casteaba como int pero TrainingSessionView
  espera double? — fix con (params['targetRpe']
  as num?)?.toDouble()
- Bug presente en Android e iOS, ahora resuelto

## [Debug] — Logs de diagnóstico en flujo de inicio de entrenamiento (temporal)
- Añadidos debugPrint en workout_execution_screen,
  training_session_view y gps_service para acotar
  el punto de bloqueo en "Ejecutando entrenamiento..."
- PENDIENTE: eliminar estos logs una vez resuelto
  el bug

## [iOS] — Fix congelación al iniciar entrenamiento
- GPSService.initialize(): timeout de 8s en
  Geolocator.requestPermission() y 5s en
  sensorService.initialize()
- Evita que la app se quede en "Ejecutando
  entrenamiento..." indefinidamente si iOS no
  responde al diálogo de permisos (comportamiento
  detectado en iOS 26 beta)
- Cuando el timeout se dispara, la app muestra
  un mensaje de error en lugar de congelarse

## [Fix — iOS] Live Activity apagada durante el descanso entre series
- Síntoma reportado inicialmente: "pace y tiempo no se actualizan bien"
  durante la sesión. Tras auditoría, esa sospecha se descartó — `pace`
  (gps_service.dart:575) y `elapsed` (gps_service.dart:435-456) se calculan
  en tiempo real en cada fix GPS, independientes del modelo de
  bloques/segmentos, y funcionan correctamente. La causa real era otra.
- Causa raíz confirmada: cada serie de entreno (`TrainingSessionView`) crea
  su propio `GPSService`, y al cerrarla (`GPSService.dispose()`,
  gps_service.dart:277-300, línea 288:
  `unawaited(IOSLiveActivityService.instance.stop())`) la Live Activity de
  iOS termina por completo. En el flujo nuevo de bloques/segmentos
  (`WorkoutExecutionScreen` → `RestScreen`), `RestScreen`
  (session_screens/rest/rest_screen.dart) es un `StatelessWidget` puro sin
  ninguna referencia a `GPSService` ni `IOSLiveActivityService` — durante
  todo el descanso entre series no había ninguna Live Activity activa en
  la pantalla bloqueada, hasta que la siguiente serie volvía a arrancar una
  nueva. El flujo legacy (`training_start_view.dart:279-298`) sí lo hacía
  bien, alimentando `IOSLiveActivityService.instance.update()` con
  `IOSLiveActivityPayload.rest()` cada segundo durante el descanso — ese
  patrón nunca se portó al flujo nuevo durante la remodelación del modelo
  de entrenamiento.
- Fix: en `workout_execution_screen.dart` → `_launchRestScreen()`, se añade
  un segundo `Timer.periodic` (1 Hz, solo si `!kIsWeb &&
  defaultTargetPlatform == TargetPlatform.iOS`) que llama a
  `IOSLiveActivityService.instance.update(IOSLiveActivityPayload.rest(...))`
  con el countdown restante y `serie: nextRepNumber` (el mismo valor ya
  calculado por `WorkoutExecutionController` y pasado a `RestScreen` para
  la UI in-app, así que el número de serie del payload de descanso es
  coherente con el resto de la sesión). El timer de UI existente
  (`elapsedNotifier`, 100ms) no se tocó — se mantiene separado para no
  perder fluidez en el countdown visible en pantalla.
- El timer de Live Activity se cancela en las tres rutas de salida del
  descanso: cierre automático por tiempo, "saltar descanso" (`onSkip` →
  `Navigator.pop()`), y la limpieza final tras el `await push(...)` — sin
  timers huérfanos.
- No hizo falta tocar el arranque de la siguiente serie ni el cierre de la
  Live Activity al terminar toda la sesión: `RunningLapsLiveActivityManager
  .start()` (Swift) ya termina cualquier Activity existente antes de crear
  una nueva, así que la siguiente `TrainingSessionView` reemplaza
  correctamente la Activity de descanso; y la última serie de la sesión ya
  dispara `GPSService.dispose()` → `stop()` al hacer pop, sin dejar Activity
  huérfana en la pantalla bloqueada.
- `flutter analyze`: 0 errores. `flutter test`: 59/59 (única carga fallida:
  `test/widget_test.dart`, archivo vacío preexistente, no relacionado).
- Cambio exclusivo de `workout_execution_screen.dart` (Dart, flujo nuevo de
  iOS). No se tocó `training_start_view.dart` (legacy, ya funciona) ni
  ningún archivo de Android/Wear OS — Android no tiene Live Activity y
  Wear OS no participa de este flujo.
- **Pendiente de verificación:** no se puede compilar ni probar en Xcode
  desde este entorno. Falta verificación visual en iPhone real vía
  Codemagic — confirmar que la Live Activity muestra el countdown de
  descanso correctamente y que no queda ninguna Activity duplicada o
  huérfana al encadenar varias series.

## [CI/Build — iOS] Codemagic compila pero falla al firmar
- Build de la rama `fix/ios-live-activity-rest-serie` en Codemagic:
  Xcode build completó correctamente (sin errores de código), pero el
  proceso falló al firmar con "requires a selected Development Team
  with a Provisioning Profile".
- No es un bug de código — es falta de configuración de cuenta. Pendiente:
  cuenta Apple Developer Program activa + configuración de firma en
  Codemagic (API Key de App Store Connect o certificados manuales). Ver
  CLAUDE.md → "Estado iOS" → fila "Code signing / Development Team".
- Bloquea cualquier build firmado para dispositivo real, incluyendo
  TestFlight — esto incluye la verificación visual pendiente de los dos
  fixes de Live Activity de esa rama.

## [Fix] Colisión WorkoutType.free/continuous en athlete_session_mapper.dart
- Causa raíz: en `_workoutTypeToCategory()` (athlete_session_mapper.dart:367),
  `case WorkoutType.free:` devolvía el mismo string `'rodaje_base'` que
  `case WorkoutType.continuous:` (línea 362). Al releer una sesión desde
  Firestore, `_mapCategory('rodaje_base')` siempre resuelve a
  `WorkoutType.continuous` (línea 48-50) — el tipo `free` se perdía
  silenciosamente cada vez que la sesión se cargaba de nuevo.
- Fix: línea 367 ahora devuelve `'gimnasio_fuerza'`, la categoría que
  `_mapCategory()` ya mapeaba correctamente a `WorkoutType.free`
  (línea 62-63) — el camino de lectura ya estaba bien, solo faltaba que
  la escritura usara el mismo valor.
- Test nuevo: test/features/templates/athlete_session_mapper_test.dart
  — round-trip `WorkoutType -> category -> WorkoutType` para todos los
  valores del enum, vía las funciones públicas `mapWorkoutSessionToAthlete`
  / `mapAthleteSessionToWorkout`. Evita que esta colisión vuelva a pasar
  silenciosamente si se añaden nuevos `WorkoutType` en el futuro.
- `flutter analyze` sin errores; `flutter test` — 59/59 tests pasan
  (la única carga fallida, test/widget_test.dart, es un archivo vacío
  preexistente sin relación con este cambio).
- Cambio puramente en Dart compartido — mismo comportamiento en Android,
  iOS y Wear OS tras el fix (Wear OS no lee el campo `category`).
- **Pendiente — migración de datos:** las sesiones `free` guardadas
  ANTES de este fix quedaron persistidas en Firestore con
  `category: 'rodaje_base'` (indistinguibles de una sesión `continuous`
  real por ese campo). Hay una heurística posible para identificarlas
  retroactivamente — documentos con `category == 'rodaje_base'` cuyo
  array `blocks` tiene un solo elemento con `role == 'main'` (sin
  warmup/cooldown) — pero NO se ha aplicado ninguna migración. Requiere
  revisión manual de una muestra antes de tocar datos de producción,
  por riesgo de falsos positivos (una sesión `continuous` editada a mano
  para tener un solo bloque caería en el mismo patrón).
- **Pendiente — training_load_service.dart:** no distingue
  `'gimnasio_fuerza'` de `'rodaje_base'` en `_intensityForCategory()` —
  ambos caen en el `default: 1.0` porque `'gimnasio_fuerza'` no está
  listado en ese switch. No se tocó este archivo en este fix.

## [Refactor — MVVM] SpeechToText extraído a servicio singleton
- Corrige deuda técnica: SpeechToText() se instanciaba directamente
  en la View (State) en workout_editor_screen.dart:52 y
  calendar_view.dart:39, violando la convención MVVM del proyecto
  (Vistas sin lógica de negocio).
- Nuevo lib/core/services/speech_to_text_service.dart — singleton
  que encapsula el paquete speech_to_text, siguiendo el mismo patrón
  que HeartRateService. Expone isAvailable, isListening,
  recognizedText y lastError como ValueNotifier (sin GetX).
  Solo puede haber una sesión de escucha activa a la vez en toda la
  app (coherente: un solo micrófono, un solo campo dictado a la vez).
- Nuevo lib/features/templates/viewmodels/workout_ai_panel_view_model.dart
  — viewmodel para WorkoutEditorScreen (no existía ninguno para esta
  pantalla). Consume SpeechToTextService; expone su estado a la View.
  Solo cubre el dictado del panel "Crear con IA" — el resto de la
  lógica de la pantalla (tipo, bloques, guardado) se deja igual,
  fuera de alcance de este refactor.
- lib/features/calendar/viewmodels/calendar_view_model.dart — añadidos
  getters/métodos (adjustSpeechAvailable, adjustListening,
  adjustRecognizedText, adjustSpeechError, initAdjustSpeech,
  toggleAdjustListening) que delegan en SpeechToTextService, para el
  panel "Ajustar plan con el coach". Se reutiliza el viewmodel ya
  existente en vez de crear uno nuevo, ya que CalendarViewModel ya
  encapsulaba el estado de esa pantalla.
- workout_editor_screen.dart y calendar_view.dart: eliminada la
  instanciación directa de SpeechToText(); ambos consumen el
  viewmodel vía ValueListenableBuilder. El flujo funcional
  ("pulsar micrófono → dictar → texto al campo editable") no cambia.
- flutter analyze sin errores tras el refactor (mismos warnings
  preexistentes en calendar_view.dart, no relacionados con este
  cambio — verificado con git stash).
- Sin impacto en Android (Dart puro) ni en Wear OS (esta feature no
  existe en el reloj).
- No se tocó App Check, Google Sign-In ni Bluetooth/HeartRateService.

## [Fix — iOS] Crash SIGABRT/TCC al arrancar (micrófono del generador de entrenamientos por IA)
- Causa raíz confirmada por crash log (.ips): el proceso terminaba con
  SIGABRT al invocar el reconocimiento de voz (paquete speech_to_text)
  porque ios/Runner/Info.plist no declaraba la clave
  NSSpeechRecognitionUsageDescription. iOS exige declarar el uso de
  TCC (Transparency, Consent and Control) antes de poder solicitar el
  permiso; sin la clave, el sistema aborta el proceso en vez de mostrar
  el diálogo de permiso.
- Añadidas a ios/Runner/Info.plist:
  - NSSpeechRecognitionUsageDescription
  - NSMicrophoneUsageDescription (también faltaba; speech_to_text
    requiere acceso al micrófono además del reconocimiento de voz)
- Afecta al botón de micrófono del generador de entrenamientos por IA
  (ver WORKOUT_GENERATOR_BY_PROMPT.md), usado en
  lib/features/templates/views/workout_editor_screen.dart y
  lib/features/calendar/views/calendar_view.dart.
- Pendiente: verificar en build iOS real (requiere Mac/Codemagic) que
  el diálogo de permiso aparece y la app ya no crashea al pulsar el
  micrófono.
- Nota aparte (no corregida, solo reportada): en ambos archivos
  SpeechToText() se instancia directamente en la View (State), no en
  un viewmodel — inconsistente con la convención MVVM del proyecto.
  No se modifica sin confirmación explícita.

## [UI] — BlockPreviewTile: componente compartido
- Nuevo lib/core/widgets/block_preview_tile.dart —
  2 estilos (compact para Home/Calendario, card para
  selección), opera sobre SessionBlock
- Unifica 3 implementaciones de formato de texto
  que tenían inconsistencias entre sí (uso de '+'
  vs '•', condición reps>1 aplicada solo en 1 de 3)
- Aplicado en home_view.dart, calendar_view.dart
  (2 usos), save_as_template_sheet.dart
- Eliminadas: _blockSummary, _blocksDescription,
  _BlockPickerTile (duplicadas/redundantes tras
  la unificación)
- home_view.dart: cambiado de BlockPreviewStyle.compact
  a .card — ahora muestra chips de RPE/zona/pace
  por bloque, igual que en el editor
- calendar_view.dart: ambos usos cambiados de
  BlockPreviewStyle.compact a .card. Tras revisar el
  código no existe ninguna celda de grid apretada en
  este archivo — la vista mensual (_buildMonthSection)
  solo pinta puntos de color y no usa BlockPreviewTile.
  Los 2 usos reales son full-width sin restricción de
  altura: _buildWeekDayCard (vista semanal, card por
  día en una Column vertical) y _buildSessionCard
  (panel de detalle del día seleccionado). Se aplicó
  card completo en ambos, sin necesidad de take(1) ni
  de mantener compact en ningún sitio.
- calendar_view.dart: sesiones ahora desplegables
  (colapsado por defecto, toca el título/chevron
  para ver el desglose de bloques) en ambas vistas
  (_buildWeekDayCard y _showDaySessionsSheet),
  estado compartido vía ValueNotifier<Set<String>>

## [Arquitectura — nota documentada, no resuelta]
- Existen dos modelos de sesión paralelos en el repo:
  SessionBlock (AI Coach, lib/features/athlete/data/
  athlete_session_model.dart) y WorkoutBlock/WorkoutSegment
  (editor manual, lib/features/templates/data/).
  No hay conversión entre ambos. Home/Calendario
  muestran sesiones del AI Coach (SessionBlock);
  WorkoutEditorScreen crea sesiones con WorkoutBlock.
  Evaluar en sesión futura si esto debe unificarse.
- Rama: feat/block-preview-tile — PENDIENTE testing
  visual antes de mergear

## [UI] — IosPicker: migración completa (4 archivos restantes)
- IosPicker ampliado con selectedColorBuilder opcional
  (color de texto por ítem, ej. escala RPE)
- alarm_config_sheet.dart: _buildCupertinoWheel migrado,
  5 call sites sin cambios de firma
- block_editor_sheet.dart: distancia y descanso migrados
- manual_training_view.dart: los 4 sheets migrados
  (distancia con extraItemLabel para "Otra distancia →",
  duración, RPE con color dinámico, descanso)
- training_session_view.dart: RPE intra-entreno migrado
  (⚠️ requiere testing manual cuidadoso antes de mergear,
  pantalla usada durante carreras reales)
- Con esto, IosPicker sustituye TODOS los CupertinoPicker/
  ListWheelScrollView ad-hoc identificados en el
  inventario original (7 de 7 sitios)
- Rama: feat/ios-picker-shared — PENDIENTE testing
  visual completo antes de mergear a main

## [UI] — IosPicker componente compartido
- Nuevo lib/core/widgets/ios_picker.dart: extraído
  de segment_bottom_sheet.dart, API basada en
  itemCount+initialItem+textBuilder (cubre rangos
  consecutivos, decimales, zero-pad, lookup tables)
- Soporte opcional para ítem extra final
  (extraItemLabel/onExtraSelected) preparado para
  el caso "Otro..." de manual_training_view.dart
- Migrados: segment_bottom_sheet.dart (interno),
  NumberPickerField, training_start_view.dart
  (_buildCupertinoWheel, 5 call sites sin cambios
  de firma)
- Pendiente: alarm_config_sheet.dart,
  block_editor_sheet.dart, manual_training_view.dart
  (caso "Otro..."), training_session_view.dart
- Rama: feat/ios-picker-shared

## [UI] — RpeBadge: rollout a 4 sitios adicionales
- training_no_gps_detail_view.dart: chip por serie
  + planificado/ejecutado (elimina _rpeColor duplicado,
  que tenía un tier de color faltante respecto a
  AppColors.effortColor)
- training_start_view.dart: objetivo de RPE + stat de
  serie completada (elimina parámetro isRpe muerto de
  _buildSerieStat)
- admin_dashboard_tab.dart: stat card de RPE medio
  con color semántico (antes fijo en rojo)
- FIX adicional: 3 sitios más tenían el bug de color
  fijo en rojo independiente del valor real de RPE

## [RPE — excluidos de la migración, documentado]
- analytics_hub_screen.dart _IntensityBar: no es un
  valor de RPE individual, es % de distribución —
  fuera de alcance
- block_transition_screen.dart _RpeBadge: ya implementado
  correctamente con AppColors.effortColor + variante
  con borde (más rico que el RpeBadge compartido actual)
  — pendiente: considerar ampliar RpeBadge con parámetro
  border para poder migrar este caso sin perder esa
  variante visual
- athlete_hub_view.dart _RpeVsPaceHalfCard: el color
  actual representa "tendencia" (mejoró/empeoró entre
  mitades de temporada), no nivel absoluto de esfuerzo —
  requiere decisión de producto antes de migrar, no es
  un swap directo

## [UI] — RpeBadge: componente compartido de RPE
- Nuevo lib/core/widgets/rpe_badge.dart — 3 tamaños
  (text/chip/stat), color semántico vía
  AppColors.effortColor, label autoformateado
- Aplicado en: training_detail_view.dart (chip por
  serie), blocks_list_section.dart (chip de objetivo),
  premium_training_card.dart (stat chip de historial)
- FIX: premium_training_card.dart tenía el RPE
  siempre en color rojo (AppColors.rpeMax fijo)
  sin importar el valor real — ahora usa el color
  semántico correcto
- home_view.dart: pendiente, _StatItem no tiene
  parámetro de color — fuera de alcance, documentado
  para sesión futura
- Quedan 7 sitios de visualización de RPE sin migrar
  (ver inventario completo en sesión anterior) —
  se migrarán en tareas siguientes
- Rama: feat/rpe-badge-shared

## [Auditoría] — 2026-06-19 — Vistas huérfanas vs activas

Mapa de reachability desde `MainShell` (sin router de paquete, sin rutas con
nombre — toda la navegación es `Navigator.push`/`MainShell.navigateTo` con
`AppRoute`/`AppModalRoute`, por lo que el grep de instanciación directa es fiable):

| Vista | Archivo | Estado | Usada desde |
|---|---|---|---|
| WorkoutEditorScreen | workout_editor_screen.dart | ACTIVA | calendario (slot 13), athlete_hub_view ×4, training_start_view |
| SessionEditorView | session_editor_view.dart | HUÉRFANA | nadie |
| AthleteSessionEditorView | athlete_session_editor_view.dart | HUÉRFANA | nadie (ni siquiera slot 13) |
| CalendarView | calendar_view.dart | ACTIVA | slot 1 |
| HomeView (no-legacy) | home_view.dart | ACTIVA | slot 0 |
| HomeView (legacy) | home_view_legacy.dart | HUÉRFANA | sus 2 "importadores" no usan la clase |
| GlobalChallengeCard | global_challenge_card.dart | HUÉRFANA | solo dentro de home_view_legacy.dart |
| ProfileView | profile_view.dart | ACTIVA | slot 3 |
| ProfileMenuView (no-legacy) | profile_menu_screen.dart | HUÉRFANA | nadie — pese al nombre sin sufijo |
| ProfileMenuView (legacy) | profile_menu_screen_legacy.dart | **ACTIVA** | GroupScreen, GroupsListScreen, TemplatesListView |
| AnalyticsHubScreen | analytics_hub_screen.dart | ACTIVA | slot 2 |
| AnalyticsHubScreenLegacy | analytics_hub_screen_legacy.dart | HUÉRFANA | nadie |
| AnalyticsHubView | analytics_hub_view.dart | HUÉRFANA | nadie |
| GroupRewardsScreen | group_rewards_screen.dart | HUÉRFANA | nadie |
| EditProfilePictureView | edit_profile_picture_view.dart | HUÉRFANA | nadie |
| SessionPlannerView | session_planner_view.dart | HUÉRFANA | nadie |
| TrainingSummaryScreen | training_summary_screen.dart | DUDOSA | no verificado |
| AiCoachOnboardingView | ai_coach_onboarding_view.dart | DUDOSA | no verificado |

10 archivos marcados con comentario ⚠️ HUÉRFANO:
session_editor_view.dart, athlete_session_editor_view.dart, home_view_legacy.dart,
profile_menu_screen.dart, analytics_hub_screen_legacy.dart, analytics_hub_view.dart,
group_rewards_screen.dart, edit_profile_picture_view.dart, session_planner_view.dart,
global_challenge_card.dart

1 archivo marcado con comentario ✅ ACTIVO pese al naming confuso:
profile_menu_screen_legacy.dart (es la versión realmente usada; la versión
sin sufijo "_legacy" es la huérfana — el nombre del archivo no refleja su estado real)

**PENDIENTE:** testing manual exhaustivo de cada flujo antes de eliminar ningún huérfano.

**Resuelto (2026-07-24):** en vez de renombrar, se unificó con `ProfileView`
y se eliminó `profile_menu_screen_legacy.dart` — ver entrada más arriba.

## [Templates] — 2026-06-18 — Switch "Guardar como plantilla" eliminado
- Eliminado del `WorkoutEditorScreen` hasta que exista UI de carga de plantillas
- El backend (`TrainingTemplatesRepository` + Firestore `users/{uid}/templates/`) está completo y listo para cuando se implemente la feature

## [Pendiente — Templates MVP]
- Pantalla "Nueva sesión: Desde cero / Desde plantilla"
- Lista de plantillas guardadas (`getWorkoutSessions`)
- Flujo: seleccionar plantilla → abrir editor precargado con sus bloques
- Guardar como plantilla: volver a exponer el switch una vez haya UI de carga
- `TrainingTemplatesRepository` ya implementado, solo falta la UI

## [UI] — 2026-06-18 — Metrónomo: solo segundos (0.5–60s)
- Eliminado el picker de minutos del modo "Por tiempo" del metrónomo — ahora un único `_MiniWheelPickerDouble` de 0.5 a 60 segundos en pasos de 0.5
- `_alertTimeSecOptions` pasa de 8 valores fijos a 120 valores generados (0.5, 1.0, ..., 60.0)
- Quitado el campo `_alertTimeMin`/`onTimeMinChanged` de `_AlertSection` y `_SegmentBottomSheetState` (el modelo `SegmentAlerts.timeMin` ya tenía default 0)
- Al cargar un segmento existente con `timeMin > 0`, se convierte a segundos totales y se ajusta al valor más cercano dentro de 0.5–60s

## [Fix] — 2026-06-18 — setState durante build en _IosPicker
- `_IosPickerState.didUpdateWidget` llamaba `_ctrl.jumpToItem(...)` de forma síncrona, lo que podía disparar `onSelectedItemChanged` → `setState` en `_SegmentBottomSheetState` mientras el árbol todavía estaba en build
- Ahora el salto se difiere con `WidgetsBinding.instance.addPostFrameCallback`; `_selectedIndex` se actualiza como mutación directa de campo (seguro durante `didUpdateWidget`)

## [UI] — 2026-06-18 — Distancias del segmento: rango completo
- `_distances` ahora cubre 50m–1km en pasos de 50m, 1.1km–5km en pasos de 100m, y 5.5km–42km en pasos de 500m (antes solo 14 valores discretos hasta 10km)

## [UI] — 2026-06-18 — Pickers: fondo uniforme + rango pace
- `_IosPicker`: pill central ahora usa `AppColors.borderOf` al 60% en light (antes `Colors.black` al 7%) — color consistente sobre `surface` y `surface2`
- Pickers: fondo uniforme `surface2` en duración, distancia, pace y metrónomo (antes el metrónomo no tenía contenedor)
- Pace: mínimo de minutos reducido a 2:00 /km (antes 3:00) en `_PaceRow` y en el pace objetivo del metrónomo

## [UI] — 2026-06-18 — Pickers iOS: reducción de tamaño
- `_IosPicker`: 3 ítems visibles (antes 5), altura total 96px (antes 190px con itemExtent 32)
- `_WheelPicker`: itemExtent 32, width 60 (antes 38/72)
- `_MiniWheelPicker`/`_MiniWheelPickerDouble`: itemExtent 28, width 36 (antes 32/44)
- Fuente: 15px seleccionado / 14px no seleccionado (antes 17px ambos)
- Pill de selección: borderRadius 6 (antes 8)

## [UI] — 2026-06-18 — Pickers estilo iOS en editor de segmento
- `_WheelPicker`, `_MiniWheelPicker`, `_MiniWheelPickerDouble` migrados a `_IosPicker`: pill de selección central, ítem activo en bold/blanco, fade superior/inferior
- Funciona en modo claro y oscuro
- Sin paquetes externos — `ListWheelScrollView` nativo
- Duración/Distancia: quitado el `Container` con borde envolvente (el pill interno ya da suficiente contexto visual)
- Pace: `_PacePill` simplificado a borde 0.5px y padding 8×4

## [UI] — 2026-06-18 — Rediseño editor de segmento
- Tipo/Medida (`_TypeToggle`, `_BoolToggle`): seleccionado con fondo morado sólido y texto blanco (antes solo borde + texto morado)
- Duración/Distancia: pickers agrupados en card `surface2` con label "min"/"seg"/"m" encima de cada rueda
- Objetivo: Pace, Zona FC y RPE en cards individuales (`surface2` + borde) con label interno propio
- Zona FC: cada zona usa su color semántico al seleccionarse (Z1 verde, Z2 azul, Z3 ámbar, Z4 coral, Z5 rojo) en lugar de morado genérico
- RPE: fila de 10 puntos de color como leyenda visual sobre el slider, número aumentado a 22px
- Descanso pasivo: añadido guard — antes Objetivo y Metrónomo se mostraban siempre; ahora se ocultan cuando `type == recovery && recoveryType == passive`
- Tipo/Medida: revertido a fondo suave morado (brand × 0.08) — más coherente con el resto de la app
- Pace: pickers min:seg agrupados en pill con borde
- RPE: track con gradiente verde→ámbar→coral→rojo (Stack con Container gradiente + Slider thumb-only), reemplaza la fila de 10 puntos
- Rama: `feat/segment-editor-redesign`

## [UI] — 2026-06-18 — Polish bloques editor: colores semánticos
- Franja izquierda: color por rol del bloque (ámbar calentamiento, coral principal, verde vuelta a la calma, morado custom)
- Chips de zona: color propio de cada zona (Z1-Z5)
- Chips de RPE: escala verde→ámbar→coral→rojo según intensidad
- Chips de FC%: escala por porcentaje (<70/<80/<90/≥90)
- Chips de pace: morado neutro
- Fila "Repeticiones" con fondo surface2 para más presencia visual
- Chips más grandes (padding 8×4, font 12)
- Rama: `feat/workout-block-redesign`

## [UI] — 2026-06-17 — Rediseño WorkoutBlockCard y SegmentCard
- Header del bloque con fondo de color según rol: ámbar (calentamiento), verde (vuelta a la calma), neutro surface2 (principal/custom)
- Iconos de rol: `wb_sunny_outlined` / `bolt` / `self_improvement_outlined` / `add_circle_outline`
- Botones de repetición como círculos compactos 28×28 con borde `AppColors.brand`
- Segmentos como cards compactos (`_SegmentCard`) con franja de color izquierda (3px) según zona/tipo
- Chips de objetivos por segmento: pace, zona Z1-Z5, RPE, %FC — solo cuando existen
- Descanso pasivo sin chips (corrección de UX: no tiene objetivos de esfuerzo)
- `_SegmentChip` renombrado a `_SegmentCard`; añadidos `_RepButton` y `_TargetChip`
- Archivos legacy marcados con comentario LEGACY en cabecera
- Rama: `feat/workout-block-redesign`

## [UI] — 2026-06-17 — Rediseño cards de bloque en editor de sesión
- Franja de color izquierda según zona (Z1 verde, Z2 azul, Z3 ámbar, Z4 coral, Z5 rojo, sin zona gris neutro)
- Título `w500` en lugar de `w700`, subtítulo con tipo de bloque y descanso formateado
- Chips RPE/zona/pace con color coherente a la zona del bloque (un solo acento por card)
- Icono `chevron_right` en lugar de `edit_outlined`
- Notas del bloque visibles en el card (2 líneas, italic, separadas por borde superior)
- `_WarmupCooldownEditor` acepta `borderRadius` opcional para conectarse al header
- Headers con icono y color: sol ámbar para Calentamiento, yoga verde para Vuelta a la calma
- Rama: `feat/session-block-redesign`

## [AI Coach] — 2026-06-15 — Fix: rodaje fragmentado sin progresión real
- `_buildProgressiveLongRunBlocks` en `rodaje_base` y `rodaje_largo` solo se activa si `complexityTier >= 2` (nivel avanzado en semana de carga), donde el bloque final sube a Z3 y hay progresión real de zona
- Con `complexityTier < 2`, se genera un único bloque continuo con la duración total (`_buildBaseRunBlocks`), sin fragmentar artificialmente en 3 segmentos idénticos en Z2
- Antes: rodaje de 70 min → 39/21/10 min, los tres en Z2 (sin sentido pedagógico). Ahora: 1 bloque de 70 min en Z2
- Bajo impacto: lógica de generación de sesiones, compartida Android/iOS/Web, sin cambios de UI

## [Web] — 2026-06-15 — Recolección de emails (waitlist)
- Cloud Function `joinWaitlist` (HTTP, Admin SDK): escribe en Firestore `waitlist/{email}`
- `firebase.json`: rewrite `/api/waitlist` → `joinWaitlist` (mismo origen, sin CORS visible en el cliente)
- Formularios de la landing conectados, con estado de carga/error
- Pendiente: `firebase deploy --only hosting,functions`

## [Web] — 2026-06-15 — Landing page + Firebase Hosting
- `web/`: landing page (index, privacy, terms, support)
- `firebase.json`: sección `hosting` añadida (`public: "web"`, rewrites para /privacy, /terms, /support)
- Pendiente: `firebase deploy --only hosting` (URL final: https://running-laps-mario-2025.web.app)

## [Notificaciones] — 2026-06-14 — Recordatorios coach
- `scheduleWeeklyFeedbackReminder`: sábado 09:00, recurrente (OS-managed via `matchDateTimeComponents`) — "¿Cómo fue tu semana?"
- `syncTrainingReminders(uid)`: notificación 08:00 los días con sesión `planned` esta semana (IDs 101-107, se resincronizan en cada llamada con cancelación previa)
- `cancelTrainingReminders()`: cancela IDs 101-107
- `_friendlyCategoryName()`: helper interno que mapea categorías a etiquetas en español
- Ambas gated por `isAthleteMode` (leído del snapshot de Firestore en `AuthWrapper`)
- `AuthWrapper`: llama feedback reminder + sync 1x por sesión de app (flag `_notificationsSynced`)
- `AiCoachAutomationService`: llama `syncTrainingReminders` tras generación exitosa en `forceGenerateCurrentWeekPlan` y `forceGenerateNextWeekPlan`
- Nota: recordatorios diarios requieren que la app se abra al menos 1x/semana; el recordatorio semanal (recurrente, OS-managed) actúa como gancho para mantener el ciclo activo
- Pendiente: probar en dispositivo real, especialmente Android con optimización de batería agresiva

## [AI Coach] — 2026-06-14 — Migrado a Cloud Function callOpenRouter
- `OpenRouterClient` ahora llama a la Cloud Function `callOpenRouter` (cloud_functions) en vez de HTTP directo
- `apiKey` eliminado de los 6 puntos de uso: `decision_service`, `chat_service`, `prompt_session_generator`, `onboarding_view`, `onboarding_launcher`, `workout_editor_screen`
- `getProviderConfig` devuelve config habilitada por defecto (`fromMap({})`) si no existe ningún doc — el coach funciona sin configuración previa en Firestore (resuelve bloqueo de onboarding para usuarios nuevos)
- `weeklyPlanningEnabled` / `chatAdjustmentsEnabled` siguen funcionando como kill-switches de admin vía `appConfig/aiCoachProvider`
- `AiCoachAutomationService`: eliminados los guards de API key en `forceGenerateCurrentWeekPlan` y `forceGenerateNextWeekPlan`
- Pendiente (deuda técnica menor): campos `apiKey` en `appConfig/aiCoachProvider` y `users/{uid}/settings/aiCoachProvider` quedan sin uso — limpieza de Firestore opcional

## [Cloud Functions] — syncEmailVerified — 2026-06-14
- Función callable que confirma emailVerified vía Admin SDK
  (fuente de verdad real) y añade custom claim email_verified
- EmailVerificationPendingView la llama tras reload() exitoso,
  refresca el ID token; spinner mientras comprueba
- Firestore Rules: helper hasVerifiedEmailClaim() añadido,
  NO aplicado todavía (UI gate ya cubre el caso; aplicar en
  rules es hardening futuro)
- Pendiente: firebase deploy --only functions

## [Cloud Functions] — 2026-06-14
- Setup inicial: `functions/` (TypeScript, Node 20)
- Función de prueba `ping` (callable, requiere auth)
- `firebase.json` actualizado con sección `functions` + predeploy build
- Pendiente: `firebase login` + `firebase deploy --only functions`
  (requiere autenticación interactiva del usuario)

### callOpenRouter
- Función callable `callOpenRouter`: recibe
  `{ model, messages, jsonSchema, temperature?, schemaName? }`
- API key de OpenRouter en Secret Manager
  (`OPENROUTER_API_KEY`), nunca en el cliente
- Auth requerida, validación de inputs, límite 200k chars por payload
- Pendiente: `firebase functions:secrets:set OPENROUTER_API_KEY`
  + `firebase deploy --only functions`

## [iOS Build Fix] — 2026-06-13
- `IPHONEOS_DEPLOYMENT_TARGET` subido de 13.0 a 16.0 en Runner (Profile)
  y configuración base del proyecto (Debug/Release) en `project.pbxproj`
- Causa: Firebase SDK (cloud_firestore, firebase_auth, firebase_core,
  firebase_app_check, firebase_storage) requiere mínimo iOS 15.0 vía SPM
- Live Activity Extension no tocada (ya estaba en 16.1)
- → RESUELTO: build de Xcode completa sin errores
  (antes fallaba por requisito Firebase SDK ≥ iOS 15.0)

### Pendiente — Code signing iOS
- Build de Xcode OK, pero falla la firma final:
  "requires a selected Development Team with a Provisioning Profile"
- Requiere configurar Code Signing en Codemagic
  (certificado .p12 + provisioning profile, o App Store Connect API key)
- No requiere Xcode/Mac — se configura desde el dashboard web de Codemagic
- Bloqueado: usuario sin cuenta Apple Developer activa todavía

### Pendiente — iOS distribución a dispositivos reales
- Build de Xcode funciona correctamente (deployment target 16.0 resuelto)
- Code signing requiere Apple Developer Program ($99/año) — sin esto,
  imposible distribuir a iPhones de testers (TestFlight) ni instalar
  en dispositivos físicos ajenos
- Mientras tanto: build para simulador posible sin coste
  (`flutter build ios --simulator`)
- Testing con amigos: centrado en Android hasta decidir sobre
  la cuenta Apple Developer

## [Seguridad — Pendiente antes de producción] — 2026-06-12

### Requiere Firebase Blaze + Cloud Functions

#### 🔴 CRÍTICO
1. API key OpenRouter → Cloud Function
   - Ahora: appConfig/aiCoachProvider legible por cualquier
     usuario autenticado
   - Fix: Cloud Function proxy que recibe el prompt,
     añade la key server-side, llama a OpenRouter
   - Nunca debe llegar ninguna key al cliente

2. trainings read → Cloud Function para rankings de grupo
   - Ahora: allow read: if isOwner(uid) (correcto pero
     rompe rankings de grupo)
   - Fix: Cloud Function con Admin SDK calcula el ranking
     y devuelve solo los datos necesarios
   - Permite restringir trainings a isOwner(uid) completamente

#### 🟡 MEDIO
3. result_notifications create → Cloud Function
   - Ahora: allow create: if isSignedIn() (cualquier
     usuario autenticado puede crear notificaciones a otro)
   - Fix: solo Admin SDK puede crear notificaciones

4. Email verificado en Firestore Rules
   - Ahora: isSignedIn() no comprueba emailVerified
     (no disponible en Firestore Rules sin custom claims)
   - Fix: Cloud Function setCustomUserClaims({ emailVerified: true })
     tras verificación → Rules comprueban
     request.auth.token.email_verified == true

5. invite_codes write
   - Ahora: cualquier usuario autenticado puede crear
   - Fix: isGroupAdmin(data.groupId) cuando Firestore
     soporte acceder a request.resource.data en top-level

#### 🟢 BAJO
6. App Check iOS
   - Requiere Apple Developer membership + DeviceCheck setup
   - Activar cuando se tenga acceso a Xcode/Mac

7. Wear OS custom token
   - Reemplazar bypass de auth por custom JWT
   - Cloud Function generateSessionToken(userId, deviceCode)

### No requiere Cloud Functions (hacer ahora)
- ✅ Cerrado: trainings/tags/templates/settings
  ya no tienen request.auth == null
- ✅ .gitignore actualizado con secrets
- ✅ Anti-injection en prompts del AI Coach
- ✅ Validación de inputs en campos del coach
- ✅ App Check activo en Android y Web

---

## [Deuda técnica — Seguridad] API key OpenRouter en cliente — 2026-06-06

**Gravedad:** 🔴 Crítico antes de producción pública

**Problema:**
La API key de OpenRouter vive en Firestore (appConfig/aiCoachProvider)
con read permitido a cualquier usuario autenticado. Cualquier usuario
logueado puede leer la key y usarla fuera de la app.

**Solución correcta:**
Mover las llamadas a OpenRouter a una Cloud Function.
La key vive como variable de entorno del servidor (Firebase Functions config).
El cliente llama a la función, nunca a OpenRouter directamente.

**Impacto actual:**
Solo en uso interno/beta con usuarios de confianza.
No desplegar a producción pública sin resolver esto.

**Referencia:**
PREMIUM_AI_COACH.md líneas 176-179 — arquitectura correcta con Cloud Functions.

---

## [feature/workout-types] — Mayo 2026

### Añadido
- Sistema completo de tipos de entrenamiento (WorkoutType: continuous,
  intervals, fartlek, hills, competition, free)
- Modelos: WorkoutSession, WorkoutBlock, WorkoutSegment, TargetConfig,
  SavedBlock con toMap/fromMap/copyWith y 37 tests unitarios
- Repositorios: templates (WorkoutSession), savedBlocks con límite 30
- Reglas Firestore: users/{uid}/savedBlocks
- Editor de sesiones completo con calentamiento, bloques, vuelta a la calma
- Títulos autogenerados desde contenido ("5×1km", "Rodaje 45 min")
- Biblioteca de bloques guardables por usuario (guardar, cargar, eliminar)
- Bloques guardados agrupados por categoría en el sheet
- Reordenación de bloques y segmentos con drag & drop
- Validación rango pace (mín siempre < máx) con feedback visual
- Mapeadores bidireccionales AthleteSession ↔ WorkoutSession
- Conexión completa con calendario (crear, editar, persistir, título visible)
- SessionWarmupCooldown: campo distanceM añadido (retrocompatible)
- AthleteSession: campo title añadido (retrocompatible)

### Pendiente (próximas ramas)
- feature/workout-execution: integrar WorkoutSession con TrainingSessionView
- chore/remove-legacy-views: eliminar vistas huérfanas

---

## [Rediseño UI completo + Arquitectura de navegación] — Mayo 2026
 
### Arquitectura de navegación — cambio fundamental
- **Todas las pantallas secundarias son tabs ocultos del MainShell** — header global (logo + avatar) y footer (BottomNav) visibles en toda la app excepto durante sesión activa
- `MainShell.shellKey` (GlobalKey) expuesto para navegación cross-widget
- `navigateTo(int index, {dynamic params})` — método público para navegar a cualquier tab
- Tabs ocultos implementados: HistoryScreen(4), TrainingStartView(15), TrainingDetailView(5), GroupsListScreen(6), GroupScreen(7), AccountSettingsView(8), ZonesConfigScreen(9), HeartRateMonitorView(10), TemplatesListView(11), TemplateEditorView(12), AthleteSessionEditorView(13), AvatarCustomizerView(14)
- TrainingSessionView y TrainingSessionSummary mantienen Navigator.push (sin header/footer durante sesión)
- Footer oculto en TrainingStartView (`_tabIndex == 15 ? SizedBox.shrink() : _NavBar`)
### Avatar customizable — generador SVG propio
- `lib/features/avatar/models/avatar_config.dart` — modelo con copyWith, toMap/fromMap, AvatarConfig.random()
- `lib/features/avatar/services/avatar_generator.dart` — genera SVG puro sin assets externos
- `lib/features/avatar/views/avatar_customizer_view.dart` — 11 secciones de personalización
- Opciones: 4 formas de cabeza, 6 tonos de piel, 8 expresiones de ojos, 12 expresiones de boca, 26 estilos de pelo, 7 vello facial, 7 prendas de ropa, 5 gorros, 8 fondos, accesorios
- `_LiveAvatarBadge` en MainShell — StreamBuilder sobre users/{uid}, actualización en tiempo real
- Guardado en Firestore `users/{uid}.generativeAvatarConfig`
- Fix proporciones SVG: pelo extendido a y=18 (tope real de cabeza), gorros reposicionados
- RepaintBoundary en avatar preview para rendimiento
### Sistema de etiquetas — predefinidas + custom
- `lib/core/constants/training_tags.dart` — 7 tags predefinidas: rodaje, series, tempo, largo, fartlek, competición, recuperación
- `TrainingTags.isPredefined(tag)` — detecta si es predefinida
- TagChip: predefinidas (brand bg) vs custom (surface2 + borde)
- TagSelectorSheet: sección predefinidas + sección custom + crear nueva
- training_summary_screen: tags predefinidas inline seleccionables sin abrir sheet
### Historial — rediseño completo
- `history_screen.dart` — elimina AppHeader, GradientBanner, HistoryBottomBar
- Header local: título + contador selección + filtro
- SearchBar inline (pill 40px), filter chips horizontal scroll
- Selection mode integrado en header (count + Cancelar)
- `premium_training_card.dart` — border radius 16, borders siempre visibles, `_StatChip` component
- Expanded content: surface2Of background, label "SERIES"
- Footer: surface2Of + top border
### Training Detail — rediseño + unificación
- `training_detail_view.dart` — unifica GPS y no-GPS (parámetro `training.gps`)
- Elimina AppHeader, GradientBanner, animaciones complejas
- Hero: título grande + fecha + badge GPS/Manual + tags
- Stats: números grandes sin cards/bordes
- Series expandibles con fl_chart LineChart interactivo (pace + FC, toggle eje X tiempo/distancia)
- Tooltips en gráfica con pace + fecha
- Notas editables inline (tap → TextField)
- `training_no_gps_detail_view.dart` → renombrada a TrainingNoGpsDetailViewLegacy
### Training Summary — rediseño completo
- Animación celebración (check icon ScaleTransition)
- RPE slider solo si 1 serie o isManual (ya recogido por serie en múltiples)
- Comparativa: vs planificado primero, vs similar si no hay planificado
- Tags predefinidas + custom inline
- Guardar / Descartar con AlertDialog de confirmación
### Training Start — rediseño completo
- Modo atleta: card sesión planificada con bloques
- Grid 2×3 tipos: Rodaje, Series, Tempo, Largo, Fartlek, Libre
- `_buildTypeConfig()` — AnimatedSwitcher con configuración específica por tipo
- Sensores: GPS toggle + BLE toggle (condición: connectionState != disconnected)
- BLE sin dispositivo: "No configurado — toca para configurar" → navigateTo(10)
- Botón EMPEZAR: círculo 56×56, brand, play icon blanco, sin sombra
- Fondo: AppColors.surface2Of(context)
- Config series pre-rellena estado antes del countdown
### Training Session — pantalla de descanso
- Fondo blanco que se tiñe de azul claro de abajo hacia arriba (progreso descanso)
- CustomPainter `_RestFillPainter` con drawRect (sin sine wave — 60fps)
- 8 burbujas flotantes con RepaintBoundary por capa
- RPE slider por serie durante descanso
- Info siguiente serie en parte inferior
- Botón "Saltar descanso" discreto
- Al terminar: HapticFeedback.mediumImpact() + arranca automáticamente
### Analytics — mejoras
- Gráfica "RITMO EN SERIES" (`_buildPaceProgression()`): puntos visibles FlDotCirclePainter, tooltip con pace + fecha, hint "Toca un punto para ver el detalle"
- CTL/ATL/TSB: ventana 180 días (era 90)
### Calendario — fixes y rediseño
- Vista mensual: barras semanales con color basado en carga TRIMP (no km)
- Vista temporada: cuadraditos por semana con mismo sistema de color
- Sistema de colores TRIMP: verde(<150) / ámbar(150-300) / coral(300-500) / rojo(>500) / morado solo competición
- Competición detectada por tag 'competición' o athleteSession.category == 'competición'
- Fix semanas cross-mes: cada semana aparece solo en el mes con más días
- `_monthForWeek(DateTime weekStart)` — helper para asignar semana al mes correcto
- Vista semanal: botones check/play/+ más grandes, centrados, tap en todo el contenedor del día
### Inputs numéricos — CupertinoPicker iOS
- `lib/core/widgets/number_picker_field.dart` — widget reutilizable
- CupertinoPicker en bottom sheet con handle bar, Cancelar/Hecho
- Sin teclado para valores numéricos en: athlete_session_editor_view, session_editor_view, session_block_editor, training_start_view
- Rangos: duración 1-300min, distancia 100-42000m (step 100), genérico 1-100
### Typography — ajustes globales
- letterSpacing reducido -0.4 en h1/h2, -0.3 en body/small
- Labels en MAYÚSCULAS (letterSpacing 1.2/1.5) sin cambios — intencionales
- fontWeight reducido en historial y detalle (w400/w500, solo título w600)
- Números con decimales limitados: distancia 2 dec, RPE 1 dec, FC/carga sin decimales
### COLOR_SYSTEM.md — actualizaciones
- Morado (brand) prohibido para indicar volumen alto — exclusivo de marca + competición en calendario
- Calendario: verde=suave, ámbar=moderada, coral=carga, rojo=pico, morado=competición únicamente
---
 
## Archivos legacy (NO eliminados — decisión deliberada)
- `home_view_legacy.dart`
- `profile_menu_screen_legacy.dart`
- `analytics_hub_screen_legacy.dart`
- `training_no_gps_detail_view.dart` (renombrada clase a TrainingNoGpsDetailViewLegacy)
## [Auditoría de colores — limpieza de colores ilegales] — 2026-04-29

### Resumen
Eliminados todos los colores fuera del sistema de diseño en `lib/`. El principio: "El color comunica significado, no decoración."

### Cambios
- **Material Colors ilegales eliminados**: `Colors.blueAccent` → `AppColors.rest`, `Colors.orangeAccent` → `AppColors.effort`, `Colors.deepPurple` → `AppColors.brandSurface`. Total: 11 reemplazos.
- **Degradados de tarjetas/botones eliminados**: 10 `LinearGradient` en fondos de tarjeta/botón reemplazados por colores sólidos de `AppColors`. Se mantienen los de gráficas (fl_chart), skeleton shimmer y Paint shaders.
- **`GradientBanner.gradientColors`** → renombrado a `accentColor` (Color sólido). Actualizadas 11 llamadas en vistas.
- **`ChallengeColorHelper.gradientForMetric()`** eliminado — sin usos externos.
- **Código malformado del agente anterior** corregido: `${IMPORT_LINE}` en 18 archivos, `const AppColors.brand` → `AppColors.brand`, `AppColors.rpeMax[50]` → `.withOpacity()`, BoxDecoration mal cerrado en `create_tag_dialog.dart`.
- **0 errores** en `flutter analyze`.

## [Design System — AppColors fuente de verdad] — 2026-04-28

### Cambios
- `lib/core/theme/app_colors.dart` reescrito: sistema de 3 capas (marca/esfuerzo/funcional) + helpers RPE + tokens por pantalla (serie, descanso, config, home, retos)
- `lib/core/theme/app_theme.dart` reescrito: dark-only `AppTheme.dark()` + `AppTypography` + `AppSpacing` + `AppDimens`
- `lib/config/app_theme.dart`: elimina `AppColors` duplicada, re-exporta desde `core/theme/app_colors.dart`, mantiene `Tema` (deprecated) y `AvatarHelper`
- `AppColors.brandPurple` → `AppColors.brand` en todo el proyecto (52 archivos)
- `AppTheme.light()` eliminado; `main.dart` usa `ThemeMode.dark` permanente
- Aliases de compatibilidad añadidos para tokens legacy (`surfaceDark`, `borderDark`, `textPrimaryDark`, etc.) — marcados como deprecated para migración gradual
- `AppColors.effortSurface` ahora es un método (RPE-aware); `effortSurfaceConst` para usos sin contexto RPE

## [GPS — EKF2D + fusión IMU] — 2026-04-23

### Mejoras GPS
- EKF2D con estado 4D (lat, lon, velocidad, heading)
- Predicción sub-segundo cada 100ms con giroscopio y acelerómetro
- processNoise adaptativo: bajo en rectas (gravedad restada), alto en curvas
- Umbral accuracy: 25m → 35m con ponderación por accuracy²
- Micro-movement threshold inteligente con podómetro (iOS)
- RDP smoother: epsilon trackPoints 2.5 → 2.0 metros
- sensors_plus: acelerómetro + giroscopio a 50Hz (gameInterval)

### Pendiente de prueba en campo
- Validar trazas en ciudad con edificios
- Comparar con recorrido de referencia
- Ajustar epsilon RDP según resultados reales

## [Fase 5 — Métricas de progreso] — 2026-04-10

### Nueva feature: ProgressView (lib/features/athlete/)
Accesible desde AthleteHubView → "Ver análisis"
(reemplaza enlace a AnalyticsHubScreen para usuarios atleta)

### ProgressRepository
- `getPersonalRecords`: mejor pace por distancia estándar
  (400m/1km/5km/10km) con tolerancias por rango
- `getSeriesProgress`: grupos de series equivalentes (±10%
  distancia, mínimo 3) con historial temporal de pace
- `getWeeklyVolume`: km reales por semana, últimas 12 semanas,
  semanas vacías incluidas
- `getPlannedVsExecuted`: sesiones vinculadas con training
  ejecutado, indexado en memoria sin queries adicionales

### ProgressViewModel
- Carga en paralelo con Future.wait
- Media móvil de 4 semanas sobre volumen semanal
- `trendForGroup`: tendencia pace primera vs segunda mitad
- `paceDeviationSecPerKm`: delta objetivo vs ejecutado,
  usa punto medio del rango pace como referencia

### ProgressView — 4 secciones
- Récords personales: grid 2×2 con pace y fecha
- Progreso en series: mini gráfica CustomPaint por grupo,
  badge tendencia mejorando/a revisar
- Volumen semanal: barras + línea media móvil, CustomPaint
- Planificado vs ejecutado: delta con colores semáforo
  (verde ≤15s/km, ámbar ≤30, rojo >30)

### Enganches abiertos para FC
- TrainingLoadService acepta fcAvgBpm/fcMax/fcRest opcionales
- Sin FC: proxy categoría+RPE. Con FC: TRIMP de Banister
- Eficiencia aeróbica y cardiac decoupling pendientes

## [Fase 4 — Competiciones y macrociclo] — 2026-04-10

### Modelos
- `AthleteSession`: nuevos campos `raceName`, `raceDistanceM`,
  `targetTimeSeconds` para sesiones de tipo competición

### Servicios
- `TrainingLoadService` (singleton, lógica pura):
  cálculo de carga con TRIMP de Banister si hay FC,
  proxy categoría+RPE si no; `nextRace`, `daysUntilRace`,
  `isRaceWeek`, `daysUntil`. Enganches abiertos para FC.

### SessionEditorView
- Sección "Detalles de la competición" dinámica cuando
  category == competicion: nombre, distancia estándar/custom,
  tiempo objetivo h/m/s

### AthleteHubView
- `_RaceCountdownCard`: contador regresivo visible cuando
  hay competición en ≤21 días, con indicador de semana taper

### SeasonView (nueva pantalla)
- Accesible desde AthleteHubView → "Ver temporada"
- Gráfica de barras scrollable: carga semanal 16 semanas
  con colores por contexto (competición/taper/alta/normal)
- Próximas competiciones con badge de días restantes
- Estadísticas del período: km, sesiones, carga total
- Nota informativa: carga estimada, mejora con pulsómetro

## [Fase 3 — Modo atleta y planificación] — 2026-04-10

### Feature athlete (nueva, reemplaza feature calendar)
- `AthleteSession` — modelo completo con warmup/cooldown texto
  libre, bloques tipados (series/continuousTime/continuousDistance),
  objetivos por bloque (pace rango, RPE, zona FC), dos notas
  separadas (planificación y ejecución)
- `AthleteSessionRepository` — stream por rango, CRUD completo,
  markAsCompleted, getSessionsForDate
- `AthleteHubView` — hub de entrada desde Perfil → "Modo atleta":
  estado vacío explicativo, resumen semanal con datos, próximo
  entreno, acceso a calendario y analytics
- `AthleteCalendarView` — StandardTableCalendar con marcadores
  por categoría de sesión
- `SessionEditorView` — editor completo: fecha/hora, categoría,
  calentamiento/cooldown texto libre, bloques, dos notas,
  partir de plantilla existente, guardar como plantilla
- `SessionBlockEditor` — ReorderableListView de bloques,
  _BlockEditorSheet con campos por tipo y sección objetivos
  colapsable (pace rango, RPE slider, zona FC)
- `SaveAsTemplateSheet` — opciones granulares: calentamiento,
  vuelta a la calma, bloque sin/con objetivos, parte principal
  sin/con objetivos, sesión completa

### Limpieza
- Feature calendar eliminada (PlannedSession, CalendarView,
  CalendarViewModel, PlannedSessionEditorView)
- Icono calendario eliminado de HomeView
- Referencias a PlannedSession eliminadas de training_start_view

### Perfil
- Nuevo tile "Modo atleta" en ProfileMenuScreen

### Pendiente
- Vinculación entreno ejecutado con sesión planificada
  (reemplazar _LinkSessionSheet eliminada — ticket para Fase 3.1)
- Notificación recordatorio cuando hay hora en la sesión

---

## [Decisiones de diseño — Modo atleta] — 2026-04-10

### Diseño aprobado
- Modo atleta accesible desde Perfil (no desde HomeView)
- AthleteHubView como pantalla de entrada con resumen semanal
- SessionEditorView: calentamiento/cooldown texto libre,
  bloques tipados, objetivos por bloque, dos notas separadas
- Pace objetivo como rango min-max
- Reps explícitas con registro individual por rep al ejecutar
- Guardar como plantilla con opciones granulares
- Feature calendar anterior (PlannedSession) se reemplaza
  completamente por feature athlete (AthleteSession)

### Analytics — decisión
- Hub existente se enlaza desde Modo atleta hasta Fase 5
- Fase 5 rediseñada: métricas con narrativa, no números aislados
- Métricas prioritarias sin FC: récords, progreso pace series,
  volumen media móvil, planificado vs ejecutado, RPE vs pace
- Métricas con FC (post pulsómetro BLE): eficiencia aeróbica,
  cardiac decoupling, ATL/CTL/TSB

---

## [Fase 1 — Zonas de entrenamiento] — 2026-04-08

### Nuevos archivos
- `lib/features/profile/data/user_profile_model.dart` — modelo completo
  de usuario con fromMap/toMap/copyWith (sentinel para nullable)
- `lib/core/services/zones_service.dart` — singleton, lógica pura:
  fcMaxEffective, zonesFor, zoneFor. ZoneRange con color incluido
- `lib/features/profile/data/zones_repository.dart` — getUserProfile,
  saveFcConfig con update parcial (no sobreescribe campos no enviados)
- `lib/features/profile/viewmodels/zones_viewmodel.dart` — 
  ZonesViewModelState inmutable + ZonesViewModel con ValueNotifier
- `lib/features/profile/views/zones_config_screen.dart` — pantalla
  completa con onboarding contextual (birthDate/sex), tabla de zonas
  en tiempo real, validación FCmáx 100-220 y FC reposo 30-100

### Archivos modificados
- `lib/features/auth/data/auth_repository.dart` — fcMax, fcReposo,
  birthDate, sex inicializados a null en registro email/password
  y Google Sign-In móvil
- `lib/features/auth/data/auth_remote.dart` — ídem para Google
  Sign-In web
- `lib/core/theme/app_colors.dart` — añadidos tokens de zonas:
  rest, rpeLow, rpeMid, effort, rpeMax
- `lib/features/profile/views/profile_menu_screen.dart` — entrada
  "Zonas de entrenamiento" en sección Personal

### Aparcado (requiere integración BLE pulsómetros)
- T5: distribución de tiempo por zona en detalle de entreno
- T7: onboarding momento 2 (detección de FC alta post-entreno)

### Deuda técnica registrada
- AppColors vive en core/theme/app_colors.dart, no en
  config/app_theme.dart — referencias en CLAUDE.md y COLOR_SYSTEM.md
  desactualizadas (baja prioridad)
- _OnboardingSheetState usa setState para estado local de formulario
  — aceptable en widget efímero sin ViewModel asociado

## [GPS Fase 4 - RDP Smoothing + Stride Persistido] — 2026-04-08

### GPS - Post-proceso y calibración personal
- Nuevo archivo lib/core/utils/rdp_smoother.dart — algoritmo Ramer-Douglas-Peucker
  - Simplifica trazas GPS antes de guardar en Firestore
  - Epsilon 2.5m: preserva curvas, elimina puntos redundantes en rectas
  - Distancia perpendicular cross-track esférica (precisa para cualquier distancia)
  - Aplicado a trackPoints (traza completa) y gpsPoints de cada serie
  - Solo si hay más de 10 puntos (evita procesar trazas triviales)
- Stride length persistido en Firestore:
  - Guardado en users/{uid}/settings/gpsCalibration al finalizar sesión
  - Solo si _gpsStableSeconds >= 30 (calibración suficiente)
  - Cargado antes de startTracking() para que el primer tick use el valor calibrado
  - Rango válido: 0.3m - 2.0m (descarta valores incoherentes)
  - Campo sessions: incremento atómico para rastrear número de calibraciones

### Referencia
Ver GPS_Plan_RunningLaps.docx — Fase 4 completada.
Plan GPS completo implementado (Fases 1-4).

## [GPS Fase 3 - UserTrackingState + Dead Reckoning] — 2026-04-08

### GPS - Máquina de estados y dead reckoning
- UserTrackingState activado en el pipeline (era dead code)
- Nuevo campo userState en TrackingState
- Máquina de estados en _processTick():
  - movingGps: GPS usable + movimiento detectado
  - movingNoGps: sin GPS >5s pero hay pasos del podómetro
  - stopped: sin pasos + velocidad <0.3 m/s durante >3s
  - uncertain: transición entre estados
- Dead reckoning en estado movingNoGps: usa podómetro exclusivamente
  cuando el GPS se pierde (túneles, edificios, sombras)
- Contadores _noGpsSeconds y _stoppedSeconds para transiciones suaves
- Reset de contadores en startTracking()

### Referencia  
Ver GPS_Plan_RunningLaps.docx — Fase 3 completada.
Fase 4 (RDP smoothing + stride persistido) es el siguiente paso.

## [GPS Fase 2 - EKF 2D] — 2026-04-08

### GPS - Extended Kalman Filter 2D
- Nuevo archivo lib/core/utils/ekf2d.dart — EKF con vector de estado [lat, lon, vel, heading]
- Reemplaza los dos KalmanFilter 1D independientes (lat y lon separados)
- Ventajas vs Kalman 1D:
  - Modela la correlación entre latitud y longitud via heading
  - Predicción cinemática: propaga posición usando velocidad + heading entre ticks GPS
  - Corrección GPS con ruido adaptativo (accuracy → R matrix)
  - updateHeading() cuando speed > 0.5 m/s para mantener heading actualizado
- Matrices: F (Jacobiano del modelo), P (covarianza 4x4), R (ruido medición), Q (ruido proceso)
- Sin dependencias externas — solo dart:math
- _accuracyToDegrees() eliminado (ya no necesario)
- _ekf.reset() en startTracking(), stopTracking() y dispose()

### Referencia
Ver GPS_Plan_RunningLaps.docx — Fase 2 completada.
Fase 3 (UserTrackingState + dead reckoning) es el siguiente paso.

## [GPS Fase 1 - processNoise adaptativo] — 2026-04-08

### GPS - Mejoras Kalman filter
- processNoise baseline aumentado de 1e-6 a 1e-5 (reducía demasiado las curvas)
- processNoise adaptativo en _processTick():
  - Sube cuando GPS accuracy es pobre (señal débil)
  - Sube x3 cuando hay cambio brusco de velocidad (curvas/aceleraciones)
  - Rango: 5e-6 (señal perfecta) a 1.5e-4 (señal pobre + curva)
- Nuevo método setProcessNoise() en KalmanFilter con clamp [1e-7, 1e-3]

### Referencia
Ver GPS_Plan_RunningLaps.docx — Fase 1 completada.
Fase 2 (EKF 2D) pendiente de validar resultados de Fase 1 en campo.

## [Optimización de consultas y agregados] — 2026-04-05

### Límites de consultas añadidos
- `group_detail_repository.dart`: `.limit(500)` en fetches de trainings para rankings de grupo
- `training_repository.dart`: `.limit(100)` en `getTrainings()`
- `rewards_repository.dart`: `.limit(50)` en streams de medals y badges
- `home_view.dart`: `.limit(20)` en stream de `result_notifications`

### HomeEstadisticaRepository
- Convertido a singleton para persistir caché entre navegaciones
- Caché en memoria de 5 minutos por combinación rango+métrica (clave: `"${range.name}_${metric.name}"`)
- `.limit(500)` en queries de gráficas (`_getRawData`)
- `clearCache()` llamado automáticamente desde `TrainingRepository.createTraining()` al guardar un entrenamiento

### Agregados en `users/{uid}`
- Nuevos campos: `totalKm` (double), `totalSessions` (int), `totalTimeMinutes` (double), `lastTrainingDate` (String ISO8601)
- Se actualizan atómicamente con `FieldValue.increment()` en `createTraining()` — seguro ante escrituras concurrentes
- Inicializados a 0 en el registro de nuevos usuarios (email/password y Google Sign-In, en los tres puntos de creación de documento)
- KPI cards de la home leen estos campos directamente con fallback a cálculo local sobre `_entrenamientos` para usuarios sin los campos (compatibilidad con cuentas existentes)
- Documento `users/{uid}` cargado en paralelo con `getAllEntrenamientos()` usando `Future.wait` — sin coste adicional de latencia

### Correcciones de race condition web
- `AuthWrapper` pasa el objeto `User` directamente a `HomeView(user: snapshot.data!)` para evitar `currentUser == null` en `initState` en web
- `_loadEntrenamientos()` usa `widget.user?.uid ?? FirebaseAuth.instance.currentUser?.uid` como fuente primaria de uid
- Stream `result_notifications` limitado a `.limit(20)`

### iOS — Limitaciones conocidas
- Live Activities no implementado (requiere Xcode + Swift extension target)
- No hay notificación persistente en iOS como en Android — el foreground task muestra la barra azul de ubicación del sistema
- GPS en segundo plano funciona correctamente vía `UIBackgroundModes: location`
- Botones de control (Terminar / Fin de serie) no disponibles en notificación iOS — `NotificationButtons` son Android-only
- Workaround: control desde la app o desde Wear OS

### iOS — Live Activity fixes adicionales
- Fix datos de distancia/ritmo no actualizaban en background:
  eliminado `Timer.periodic` en iOS, updates ahora se disparan desde `_handlePosition()`
  directamente al recibir posición GPS (iOS entrega eventos GPS en background
  via `UIBackgroundModes: location` aunque el isolate Dart esté suspendido)
- Timer de notificación solo activo en Android
- `pause()`/`resume()` solo gestionan el timer en Android

### iOS — Pendiente con logs
- Google Sign In: app se cierra al pulsar el botón.
  Cambios aplicados: `REVERSED_CLIENT_ID` en `Info.plist`, `GoogleService-Info.plist` añadido,
  `GIDSignIn.sharedInstance.handle(url)` en `AppDelegate.swift`.
  Requiere logs para diagnosticar el crash. Pendiente para cuando haya acceso a Xcode/Mac.

### Documentación
- Creados `CHANGELOG.md`, `ARCHITECTURE.md` y `CLAUDE.md` en raíz del proyecto

---

## [Unreleased] — 2026-04-05

### Seguridad — Firebase App Check

#### Flutter (móvil)
- Añadida dependencia `firebase_app_check: ^0.4.1+1` en `pubspec.yaml`
- Añadidas dependencias nativas en `android/app/build.gradle.kts`:
  - `firebase-appcheck-playintegrity`
  - `firebase-appcheck-debug`
- Implementada activación en `lib/main.dart`:
  - Android release: `AndroidProvider.playIntegrity`
  - Android debug: `AndroidProvider.debug`
  - iOS release: `AppleProvider.deviceCheck`
  - iOS debug: `AppleProvider.debug`
  - Web: `ReCaptchaV3Provider('6LcH2acsAAAAAGdH2Wi1X39xnD3EB6o40ZsVjnIo')`
- Eliminado el guard `if (!kIsWeb)` — App Check activo en todas las plataformas

#### Wear OS (Kotlin)
- Añadidas dependencias App Check en `wear_os/app/build.gradle.kts`:
  - `firebase-appcheck-playintegrity`
  - `firebase-appcheck-debug`
- Habilitado `buildConfig = true` en el bloque `buildFeatures`
- Implementada activación en `MainActivity.kt`:
  - Release: `PlayIntegrityAppCheckProviderFactory`
  - Debug: `DebugAppCheckProviderFactory` (via `BuildConfig.DEBUG`)

---

### Seguridad — Reglas de Firestore

Auditoría completa de `firestore.rules`. Cambios aplicados:

#### Helpers añadidos
- `isReasonableDocument()` — limita tamaño de documentos entrantes
- `isSafeWrite()` — valida campos mínimos y tamaño en escrituras de grupos

#### Colecciones endurecidas

| Colección | Cambio |
|---|---|
| `trainings` | `allow read` ampliado a `request.auth == null` para lecturas desde Wear OS sin sesión |
| `templates` | `allow read` ampliado a `request.auth == null` para lecturas desde Wear OS |
| `settings` | `allow read` ampliado a `request.auth == null` para lecturas desde Wear OS |
| `result_notifications` | Añadida validación de tamaño + comprobación `toUid == uid` |
| `groups` (create) | Envuelto en `isSafeWrite()` |
| `groups` (memberCount) | Delta bloqueado a +1 para evitar manipulación del contador |
| `invite_codes` | Validación de campos obligatorios en create; update/delete restringido a admin del grupo |
| `wear_sessions` (create) | Validación de campos requeridos, `status == 'pending'`, tipo timestamp, cota futura ≤ +10 minutos |
| `wear_sessions` (read) | Sustituido `allow read: if true` por ventana temporal: `createdAt > now - 10 minutos` |
| `invites` (uses) | Delta bloqueado a +1 |

#### Correcciones específicas
- Eliminada validación `code.size() == 6` en `wear_sessions` — el código es el ID del documento, no un campo interno
- Corregida comprobación `result_notifications`: cambiado `request.auth.uid` por `uid` (wildcard del path) para permitir escrituras entre usuarios distintos desde `ChallengeFinalizationService`

---

### Autenticación — Google Sign In en Web

**Problema:** `GoogleSignIn().signIn()` devuelve `null` en plataforma web.

**Solución aplicada en `lib/features/auth/data/auth_remote.dart`:**
- Añadido branch `if (kIsWeb)` en `signInWithGoogle()`
- Web usa `_auth.signInWithPopup(GoogleAuthProvider())` directamente
- Tras `signInWithPopup`, se fuerza refresco del token: `await user.getIdToken(true)`
- Creación del documento Firestore del usuario en el propio branch web, antes de retornar el `UserCredential`:
  - Si `doc.exists == false` → `_db.collection("users").doc(uid).set({...})`
  - Esto evita condiciones de carrera con listeners que se abren antes de que `AuthRepository` pueda crear el documento
- Añadidos prints de debug temporales para diagnóstico (`WEB LOGIN: user=...`, `WEB LOGIN: token refreshed`, etc.)

**Por qué en `auth_remote` y no en `auth_repository`:**
En web, los listeners de Firestore se activan antes de que el flujo de `AuthRepository.signInWithGoogle()` llegue a su comprobación `getUserName()`. Crear el documento directamente en `auth_remote`, inmediatamente tras el `signInWithPopup` y con token ya refrescado, garantiza que el documento existe cuando los primeros listeners lo necesitan.

---

### Autenticación — Race condition en HomeView (web)

**Problema:** `FirebaseAuth.instance.currentUser` puede ser `null` en `HomeView.initState()` en web, porque el SDK de Firebase web inicializa el estado de auth de forma asíncrona.

**Solución:**
- `AuthWrapper` pasa el objeto `User` del stream directamente a `HomeView`:
  ```dart
  if (snapshot.hasData) return HomeView(user: snapshot.data!);
  ```
- `HomeView` recibe `User? user` como parámetro opcional
- En `initState`: `_currentUserId = widget.user?.uid ?? FirebaseAuth.instance.currentUser?.uid ?? ''`
- El parámetro es opcional (no required) para no romper otros puntos de navegación que no disponen del objeto `User`

---

### Rendimiento — Límites en consultas Firestore

Se añadió `.limit()` a todas las consultas sin cota de documentos identificadas en la auditoría:

| Archivo | Consulta | Límite añadido |
|---|---|---|
| `training_repository.dart:56` | `getTrainings()` ordenado por `createdAt` | `.limit(100)` |
| `group_detail_repository.dart:59` | `trainings` sin filtro de fecha (para stats de grupo) | `.limit(500)` |
| `group_detail_repository.dart:154` | `fetchUserTrainings()` ordenado por `fecha` | `.limit(500)` |
| `rewards_repository.dart:150` | Stream `medal_history` con `.where('uid')` | `.limit(50)` |
| `rewards_repository.dart:169` | Stream `badge_history` con `.where('uid')` | `.limit(50)` |
| `home_estadistica_repository.dart` | `_getRawData()` con filtro de fecha | `.limit(500)` |

Consultas ya protegidas (sin cambio necesario):
- `auth_remote.dart:122` — `.limit(1)` ya existía
- `user_lookup_service.dart:17` — `.limit(1)` ya existía
- `admin_repository.dart:47,52` — `.limit(1000)` ya existía
- `admin_repository.dart:177` — `.limit(500)` ya existía

---

### Rendimiento — HomeEstadisticaRepository: singleton + caché

**Problema:** `HomeEstadisticaRepository` se instanciaba de nuevo cada vez que el controlador se creaba (por re-mount del widget Home), perdiendo cualquier caché. Cada cambio de métrica o rango temporal disparaba una consulta Firestore nueva sin ningún control.

**Cambios en `lib/features/home/data/home_estadistica_repository.dart`:**

1. **Patrón singleton:**
   ```dart
   static final HomeEstadisticaRepository _instance =
       HomeEstadisticaRepository._internal();
   factory HomeEstadisticaRepository() => _instance;
   HomeEstadisticaRepository._internal();
   ```

2. **Caché en memoria por combinación rango+métrica:**
   - Clave: `"${range.name}_${metric.name}"` (ej. `"oneWeek_ritmoMedio"`)
   - Expiración: 5 minutos desde la última petición
   - Almacenamiento: `Map<String, List<DailyMetric>>` + `Map<String, DateTime>` de timestamps
   - `clearCache()` limpia ambos mapas

3. **Invalidación del caché tras guardar:**
   - `lib/features/training/data/training_repository.dart`: añadido import y llamada `HomeEstadisticaRepository().clearCache()` en `createTraining()`, inmediatamente tras obtener el `trainingId`
   - Al ser singleton, la llamada siempre impacta la misma instancia que usa el widget Home

**Impacto:** De hasta 20 consultas Firestore por sesión en la pantalla Home (5 rangos × 4 métricas), se reduce a máximo 20 consultas en las primeras 5 minutos y 0 adicionales mientras el caché sea válido.

---

### Eliminación de código muerto

- **Eliminado:** `lib/features/training/views/training_start_view_helper.dart`
  - Archivo con métodos sueltos sin clase contenedora
  - Referencias a variables no definidas en el archivo
  - Sin imports, sin ningún caller en el resto del proyecto
  - Confirmado con `flutter analyze` tras la eliminación

---

### Wear OS — Soporte de plantillas (5 partes)

#### PART 1 — TemplateModels.kt (nuevo)
- Modelos Kotlin espejo de `template_models.dart`:
  - `WearTemplateAlerts`, `WearTemplateBlock`, `WearTemplate`
- Función `parseTemplateFromFirestore(id, data)` para deserializar desde Firestore

#### PART 2 — TemplatePickerScreen.kt (nuevo)
- Pantalla Wear OS Compose para seleccionar plantilla
- Carga desde `users/{uid}/templates/` en Firestore
- Estados: spinner → "Sin plantillas" → lista con chips de color
- Callback `onTemplateSelected: (WearTemplate) -> Unit`

#### PART 3 — SeriesTrainingService.kt (modificado)
- Añadidos en companion object: `instance`, `pendingTemplate`, `_templateFinished`, `templateFinished`
- `reset()` limpia `_templateFinished`
- `onCreate()` / `onDestroy()` gestionan `instance`
- `onStartCommand()` aplica `pendingTemplate` si existe
- Nuevos métodos: `loadTemplate()`, `applyBlock()`, `computeAlarmIntervalMs()`
- `confirmRpe()`: descarta serie vacía (`distanciaM <= 0f && tiempoSec <= 2s`), avanza bloque de plantilla, emite `_templateFinished = true` al agotar bloques

#### PART 4 — SeriesActiveScreen.kt (modificado)
- Recoge `templateFinished` como estado Compose
- Overlay "¡Plantilla completada!" con degradado radial brandPurple al completar
- Auto-stop tras 2 segundos con `LaunchedEffect` + `delay`

#### PART 5 — SeriesPageScreen.kt + MainActivity.kt (modificados)
- `SeriesPage` acepta `initialTemplate: WearTemplate?` para pre-selección
- `metersToDistStr()` y `secondsToDescStr()` como helpers internos
- `MainActivity`: estado `activeTemplate` con `remember { mutableStateOf<WearTemplate?>(null) }`
- Ruta `template_picker` → `TemplatePickerScreen` con callback de selección
- Ruta `series_page` pasa `initialTemplate = activeTemplate`

---

### Wear OS — HomeScreen.kt (correcciones)

- Colección corregida: `"entrenamientos"` → `"trainings"` (nombre real en Firestore)
- Añadido `.addOnFailureListener` con logging de errores
- Parsing defensivo: lee `distanciaTotalM` del nivel superior o, si no existe, suma `series[].distanciaM` manualmente
