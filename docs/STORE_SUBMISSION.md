# Material para publicar en las tiendas

Respuestas de los formularios y textos de ficha, **derivados del código real**
(manifest, Info.plist, campos escritos en Firestore, servicios usados), no de
suposiciones. Cada apartado dice de dónde sale el dato para que puedas
comprobarlo o corregirlo si cambia el código.

> ⚠️ Esto no es asesoría legal. Los formularios los firmas tú: si algo no te
> encaja, corrígelo antes de enviar. Declarar de menos en Data Safety o en las
> Nutrition Labels es de las causas más frecuentes de rechazo y de retirada
> posterior.

Estado del checklist técnico: `PUBLISHING.md`.

---

## 0. Datos que la app recoge de verdad

Sacado de: campos escritos en `users/{uid}` en todo `lib/`, permisos del
`AndroidManifest.xml`, purpose strings de `Info.plist` y servicios activos.

| Dato | Dónde vive | Para qué | Origen en el código |
|---|---|---|---|
| Email, nombre | `users/{uid}.email`, `.nombre` | Cuenta e identificación | Registro / Google / Apple |
| Foto de perfil (URL de Google) o avatar generativo | `.photoUrl`, `.profilePicType`, `.generativeAvatarConfig` | Avatar en la app | El avatar generativo es configuración, **no** una foto subida |
| Fecha de nacimiento y sexo biológico | `.birthDate`, `.sex` | Calcular zonas de FC | Onboarding del Coach IA (opcionales) |
| FC máxima y zonas | `.fcMax`, `users/{uid}/settings` | Zonas de entrenamiento | `zones_repository` |
| Entrenamientos: distancia, tiempo, ritmo, RPE, etiquetas, notas | `users/{uid}/trainings` | Función principal | `training_repository` |
| **Ruta GPS** (coordenadas de la sesión) | `users/{uid}/trainings/{id}/track/data` — subcolección aparte, **no** dentro del documento del entreno | Mapa y ritmo | `gps_service`, `training_repository._saveTrack` |
| **Frecuencia cardíaca** (pulsómetro BLE) | Por serie: `fcMedia`, `fcReadings`. Por sesión: `fcMediaSesion`, `fcMaxSesion` | Métricas de sesión y reparto por zonas | `heart_rate_service`, `fc_analytics` |
| **Competiciones objetivo** (fecha, distancia, prioridad) | `users/{uid}/raceGoals` | Planificar el bloque y el taper | `race_goal_repository` |
| **Cuestionario semanal**: sensaciones, sueño y **molestias/lesiones** (texto libre) | `users/{uid}/aiCoachFeedback` | Autorregular la carga del plan | `ai_coach_repository` |
| **Mensajes del chat con el Coach** (texto libre del usuario) | No se persisten; se envían al proveedor de IA en la petición | Responder al atleta | `ai_coach_chat_service` |
| Plantillas, bloques guardados y sesiones planificadas | `users/{uid}/{templates,savedBlocks,athleteSessions}` | Configuración de entrenamiento | Sin datos personales |
| Agregados | `.totalKm`, `.totalSessions`, `.totalTimeMinutes`, `.lastTrainingDate` | Estadísticas de inicio | `training_repository.createTraining` |
| Consentimiento de datos de salud | `users/{uid}/settings/healthConsent` (fecha + versión) | Prueba del consentimiento art. 9 RGPD | `health_consent_service` |
| Uso de la app y diagnósticos | Firebase Analytics / Crashlytics | Analítica y errores | `analytics_service`, `main.dart` |

**Permisos declarados** (Android): ubicación fina y aproximada, reconocimiento
de actividad (podómetro), Bluetooth (escaneo/conexión), servicio en primer
plano con tipo `location`, notificaciones, arranque. **iOS**: ubicación en uso
y en segundo plano, Bluetooth, movimiento, micrófono y reconocimiento de voz.

**Terceros:**
- **Firebase / Google** (Auth, Firestore, Storage-no, Functions, Analytics,
  Crashlytics, App Check): encargado del tratamiento.
- **OpenRouter** (modelo de IA del coach): la llamada sale **desde una Cloud
  Function**, no desde el móvil (`openrouter_client.dart` usa `httpsCallable`).
  Ni la clave ni la conexión están en el cliente.
  **Verificado en el payload** (`ai_coach_prompt_builder._contextPayload`, ago
  2026): no viaja `uid`, ni email, ni nombre. Sí viajan datos de salud, y
  algunos en **texto libre escrito por el usuario**:
  - objetivo, nivel, disponibilidad semanal y marcas personales;
  - `fcMax`/`fcRest` y, por entreno, FC media/pico, reparto por zonas,
    eficiencia y desacoplamiento;
  - `coachNotes`, `recurringConstraints` y `temporaryStatuses` — aquí es donde
    el atleta describe lesiones y limitaciones;
  - `sensaciones` y `molestias` del cuestionario semanal;
  - el mensaje que el atleta escribe en el chat.

  > Por eso "salud y forma física" se declara como **compartido** en Data
  > Safety. La ausencia de identificadores reduce el riesgo, pero no convierte
  > esto en anónimo: son datos de salud de una persona identificable en tu
  > sistema.
- **Reconocimiento de voz del sistema operativo** para el dictado: lo procesa
  el SO (Google/Apple). La app **no almacena audio** en ningún momento.

**No hay**: anuncios, compras dentro de la app (todo gratis en beta),
seguimiento entre apps ni identificadores publicitarios. Esto último no es solo
una promesa: el manifest **elimina explícitamente** el permiso de ID de
publicidad que arrastran las librerías de Google —
`<uses-permission android:name="com.google.android.gms.permission.AD_ID"
tools:node="remove" />`— así que el AAB sale sin él y la respuesta "no se
recogen identificadores publicitarios" es comprobable en el propio bundle.

---

## 1. Google Play — Data Safety

Para cada tipo: *¿se recoge?* · *¿se comparte?* · *finalidad* · *¿obligatorio?*
Todo va **cifrado en tránsito** (HTTPS/Firestore) y el usuario **puede
solicitar su borrado** (borrado in-app + `runninglaps.com/delete-account`).

| Tipo de dato | Recogido | Compartido | Finalidad | Obligatorio |
|---|---|---|---|---|
| Nombre | Sí, vinculado | No | Gestión de la cuenta | Sí |
| Dirección de email | Sí, vinculado | No | Gestión de la cuenta | Sí |
| **Ubicación precisa** | Sí, vinculado | No | Función de la app | **No** (se puede entrenar sin GPS) |
| **Info de salud y forma física** (FC, entrenamientos, RPE) | Sí, vinculado | **Sí** → proveedor de IA | Función de la app | No |
| Otra info personal (fecha de nacimiento, sexo) | Sí, vinculado | No | Personalización (zonas de FC) | No |
| Interacciones con la app | Sí, vinculado | No | Analítica | No |
| Registros de fallos y diagnósticos | Sí, vinculado | No | Analítica y rendimiento | No |
| **Mensajes en la app** (chat con el Coach) | Sí, vinculado | **Sí** → proveedor de IA | Función de la app | No |
| Fotos | **No** | — | — | — |
| Audio / grabaciones de voz | **No** (lo procesa el SO; la app no lo guarda) | — | — | — |

**Por qué aparecen los mensajes.** El tipo "Mensajes → Otros mensajes en la
app" de Play cubre *chat content*. Lo que el atleta escribe en el chat del
Coach sale hacia OpenRouter, así que se declara aunque no se guarde en
Firestore: Data Safety pregunta por lo que se **recoge y transmite**, no solo
por lo que se persiste. Lo mismo vale para las molestias y sensaciones del
cuestionario semanal, que van dentro de "salud y forma física".

**El punto delicado — "compartido" con la IA.** Play distingue entre
*encargado del tratamiento* (no cuenta como compartir) y *transferencia a un
tercero* (sí cuenta). Firebase es claramente encargado. OpenRouter recibe
métricas sin identificadores para generar el plan: **declara "compartido" en
salud y forma física**. Declarar de más aquí no penaliza; declarar de menos, sí.

**Declaración de apps de salud** (categoría Salud y fitness): la app registra
entrenamientos y frecuencia cardíaca del propio usuario; no es un producto
sanitario, no diagnostica y no sustituye consejo médico (ya está el disclaimer
en `terms.html`).

**Clasificación IARC**: contenido deportivo, sin violencia, sin contenido
sexual, sin lenguaje soez, sin juego, **sin anuncios**, sin compras.
Interacción entre usuarios: **sí** si publicas grupos/retos (hay nombres y
rankings visibles entre miembros); **no** si lanzas sin grupos — respóndelo
según lo que salga en la v1.

**Público objetivo**: 16+ (coherente con la edad mínima de la política de
privacidad y de los términos).

---

## 2. App Store — Privacy Nutrition Labels

Traducción de lo mismo a las categorías de Apple. Todo es **"Datos vinculados
al usuario"** y **nada** se usa para *tracking* (no hay publicidad ni
identificadores compartidos con terceros con fines publicitarios).

| Categoría Apple | Dato concreto | Uso |
|---|---|---|
| Contact Info | Nombre, email | Funcionalidad de la app |
| Health & Fitness | Entrenamientos, frecuencia cardíaca, RPE | Funcionalidad de la app |
| Location | Ubicación precisa (ruta) | Funcionalidad de la app |
| Identifiers | ID de usuario (Firebase UID) | Funcionalidad de la app |
| Usage Data | Interacciones con la app | Analítica |
| Diagnostics | Fallos y rendimiento | Analítica |
| Sensitive Info | Fecha de nacimiento, sexo biológico, **lesiones y molestias** (texto libre del cuestionario y del perfil del Coach) | Personalización |
| User Content | **Mensajes del chat con el Coach**, notas de entrenamiento | Funcionalidad de la app |

**Estatus de trader (DSA)** — obligatorio para distribuir en la UE: hay que
publicar nombre, dirección, email y teléfono de contacto. Sin esto la app **no
se distribuye en la UE**, España incluida.

---

## 3. Ficha de la tienda

Tagline oficial del manual de identidad: «Para los que van en serio.»
Tagline de store: «Entrena con datos. Corre con propósito.»

**Título (máx. 30):**
```
Running Laps: series y ritmo
```
(28 caracteres. Alternativa: `Running Laps — Entrena series` = 29.)

**Descripción corta (máx. 80):**
```
Entrena con datos. Series, ritmo, RPE y GPS con un coach que se adapta a ti.
```
(75 caracteres.)

**Descripción larga (máx. 4000):**
```
Running Laps es la app para quien entrena en serio: series, ritmo, esfuerzo
percibido y GPS, sin ruido y sin gamificación vacía.

ENTRENAMIENTO FRACCIONADO DE VERDAD
Planifica y ejecuta sesiones por series: calentamiento, bloque principal con
repeticiones y vuelta a la calma. Cada serie con su distancia, su tiempo, su
descanso y su RPE. La app te acompaña durante la sesión y registra cada
repetición por separado, no un promedio inútil de toda la carrera.

GPS PRECISO, TAMBIÉN CON LA PANTALLA BLOQUEADA
Seguimiento con filtro de Kalman y fusión con el podómetro para que la
distancia sea fiable incluso cuando la señal falla. Notificación persistente
con distancia, tiempo y ritmo mientras corres.

ESFUERZO PERCIBIDO (RPE)
Lo que ningún reloj mide: cómo te has sentido. Registra el RPE de cada serie y
cruza esa percepción con tus datos para entender tu forma de verdad.

PULSÓMETRO BLUETOOTH
Conecta tu banda de frecuencia cardíaca y añade FC media por serie y zonas de
entrenamiento personalizadas a partir de tu FC máxima.

TU COACH, NO UN ANIMADOR
Un entrenador con IA que analiza tus últimas semanas, tu carga y tus objetivos
y te propone el plan de la semana. Te dice lo que necesitas oír, no lo que te
gusta oír. Puedes ajustar el plan hablando con él.

CALENDARIO Y PROGRESO
Planifica tu semana, marca tu competición objetivo y sigue tu evolución:
récords personales, distribución de intensidad, carga de entrenamiento y
ritmos por distancia.

TUS DATOS SON TUYOS
Puedes borrar tu cuenta y todos tus datos desde la propia app, en cualquier
momento. Política de privacidad clara y consentimiento explícito antes de
registrar datos de frecuencia cardíaca.

Running Laps no es un producto sanitario ni sustituye el consejo de un
profesional. Consulta a tu médico antes de empezar un plan de entrenamiento.
```

**Capturas sugeridas** (mínimo 2, recomendado 4-8; hay material real en
`design/app-screenshots-2026-07-20/`):
1. Sesión activa con distancia y ritmo · 2. Editor de sesión por bloques ·
3. Calendario semanal · 4. Resumen con RPE y mapa · 5. Analytics ·
6. Coach IA.

---

## 4. Notas para el revisor

```
La app registra entrenamientos de carrera. Para revisarla:

CUENTA DE PRUEBA
Usuario: <crear una cuenta de prueba con datos ya cargados>
Contraseña: <...>
La cuenta tiene entrenamientos e historial para que se vean las pantallas de
analytics y calendario sin tener que salir a correr.

UBICACION (redactar distinto en cada tienda - ver nota debajo del bloque)
La app registra la ruta unicamente durante un entrenamiento iniciado por el
usuario, con una notificacion persistente visible mientras dura. No se recoge
ubicacion fuera de una sesion activa.

PERMISOS BAJO DEMANDA
Ningún permiso se solicita al abrir la app: ubicación y movimiento se piden en
la pantalla previa al entrenamiento, Bluetooth al emparejar un pulsómetro, y
micrófono al usar el dictado por voz del generador con IA.

DATOS DE SALUD
La frecuencia cardíaca solo se registra si el usuario conecta una banda
Bluetooth, y requiere aceptar antes un consentimiento explícito.

BORRADO DE CUENTA
Perfil → Ajustes → Borrar cuenta. También en runninglaps.com/delete-account.
```

> ⚠️ **No escribas "ubicación en segundo plano" en las notas de Google Play.**
> Verificado en `AndroidManifest.xml` (ago 2026): la app **no declara**
> `ACCESS_BACKGROUND_LOCATION`. Usa `FOREGROUND_SERVICE_LOCATION` con
> `foregroundServiceType="location"`, que es el patrón que Play acepta **sin**
> la declaración especial de ubicación en segundo plano — la revisión más dura,
> con vídeo demostrativo obligatorio. Decir que usas background location invita
> a esa revisión por un permiso que ni siquiera pides. Para Play, redáctalo así:
>
> ```
> UBICACIÓN
> El seguimiento se hace con un servicio en primer plano
> (foregroundServiceType="location") con notificación persistente, solo
> mientras dura un entrenamiento que el usuario ha iniciado. La app no
> declara ACCESS_BACKGROUND_LOCATION.
> ```
>
> En **App Store sí aplica** lo contrario: el `Info.plist` declara
> `NSLocationAlwaysAndWhenInUseUsageDescription` y `UIBackgroundModes:
> location`, así que ahí la redacción de "segundo plano" es correcta y hay que
> justificarla — es exactamente lo que Apple espera leer.

---

## 5. Lo que sigue bloqueado y no depende de este documento

- Decidir cuenta de Play **personal u organización** (la personal creada tras
  nov-2023 obliga a prueba cerrada de 12 testers × 14 días).
- Alta en Play Console (25 $) y Apple Developer Program (99 $/año).
- Firma iOS en Codemagic (bloquea TestFlight) y los 3 pasos web de Sign in
  with Apple.
- Assets gráficos: icono 512×512, feature graphic 1024×500, capturas.
- Revisión legal profesional (datos de salud + RGPD).
