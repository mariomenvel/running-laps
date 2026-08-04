# PUBLISHING.md — Publicación en Google Play y App Store

> Estado a julio 2026. Requisitos verificados contra las políticas vigentes y el
> código del repo. **Nada de este documento es asesoría legal** — la sección legal
> es orientación técnica; para RGPD con datos de salud conviene una revisión
> profesional antes del lanzamiento.

---

## Resumen ejecutivo

| | Google Play | App Store |
|---|---|---|
| Coste | 25 $ (pago único) | 99 $/año |
| Bloqueante principal | Cuenta + formularios + assets | **Cuenta Apple Developer sin contratar** |
| Estado técnico | ✅ Prácticamente listo | ⚠️ Firma sin configurar + decisión de login |
| Recomendación | **Lanzar primero aquí** | Después, como proyecto aparte |

---

## Lo que YA se cumple (verificado en el repo)

- ✅ **Target API 36 (Android 16)** — requisito obligatorio para apps nuevas desde
  el 31/8/2026. Flutter 3.41.1 lo pone por defecto (`flutter.targetSdkVersion = 36`).
- ✅ **AAB**: `flutter build appbundle --release` en el workflow de Codemagic.
- ✅ **Sin `ACCESS_BACKGROUND_LOCATION`**: el tracking usa foreground service con
  `foregroundServiceType="location"` + notificación persistente — el patrón que
  Play acepta sin la declaración especial de ubicación en segundo plano (la
  revisión más dura de Play, con vídeo demostrativo, **no aplica**). No añadir
  ese permiso jamás sin leer esta nota.
- ✅ Permisos Android 14+ correctos: `FOREGROUND_SERVICE_LOCATION`,
  `ACTIVITY_RECOGNITION`, `BLUETOOTH_SCAN/CONNECT` (con `neverForLocation`),
  `POST_NOTIFICATIONS`.
- ✅ **Purpose strings iOS** completos y en español (ubicación when-in-use y
  always, Bluetooth, movimiento, micrófono, reconocimiento de voz) +
  `UIBackgroundModes: location`.
- ✅ `ITSAppUsesNonExemptEncryption = false` en Info.plist (solo HTTPS estándar —
  exime de la declaración de cifrado en cada subida).
- ✅ **Borrado de cuenta in-app** (obligatorio en ambas tiendas desde 2023-24):
  Perfil → Cuenta → Eliminar, con reautenticación, y borrado server-side completo
  (Cloud Function `deleteUserData` con Admin SDK, desplegada).
- ✅ **Página web de solicitud de borrado** (`/delete-account`) — la exige Play
  además del flujo in-app. Desplegada en `runninglaps.com/delete-account`.
- ✅ Política de privacidad y términos con URL pública en dominio propio con
  SSL: `runninglaps.com/privacy`, `runninglaps.com/terms` — y ahora también
  enlazadas dentro de la app (ver sección Legal).
- ✅ App Check Android (Play Integrity en release, debug provider en debug).
- ✅ **Permisos just-in-time** (jul 2026): ningún diálogo de permisos en el primer
  arranque. Bluetooth se pide al emparejar el pulsómetro, micrófono +
  reconocimiento de voz al pulsar el micro de dictado por primera vez, y
  ubicación + movimiento en la pantalla previa al entrenamiento. Cumple la
  guideline 5.1.1 de Apple (peticiones con contexto) — no reintroducir
  inicializaciones de BLE/speech en el arranque.

---

## Checklist Google Play

### Cuenta y proceso
- [x] **Clave de subida (upload key) creada** ✅ (3 ago 2026). Era un bloqueante
  que no estaba en esta lista: `android/key.properties` apuntaba a un
  `dummy.jks` inexistente, así que `flutter build appbundle --release` **fallaba**
  (`validateSigningRelease: Keystore file 'dummy.jks' not found`) y no había
  forma de subir nada a Play. Estado actual:
  - Keystore PKCS12, RSA 2048, validez 10.000 días, alias `upload`,
    `CN=Mario Mendoza, O=Running Laps, L=Madrid, C=ES`.
  - Vive **fuera del repo**, en `C:/Users/mario/keys/running-laps-upload.jks`,
    para que no pueda colarse en un commit. `android/key.properties` sigue
    gitignoreado.
  - ⚠️ En `key.properties` la ruta va con **barras normales**: es un
    `.properties` de Java y `\` se interpreta como escape — con barras
    invertidas el path se corrompe en silencio (`C:Usersmariokeys...`).
  - AAB verificado: `jarsigner -verify` → `jar verified`, firmado por ese CN.
  - 🔐 **Respaldar el `.jks` y su contraseña.** Con Play App Signing la clave
    de firma real la custodia Google y la de subida es reseteable pidiéndoselo
    a Google, así que perderla no es fatal — pero sí un trámite.
- [ ] Crear cuenta de **Play Console** (25 $, pago único).
  - ✅ **Decidido (3 ago 2026): cuenta personal.** Consecuencia asumida: al ser
    personal creada después de nov 2023, es obligatorio pasar una **prueba
    cerrada con 12 testers durante 14 días seguidos** antes de poder solicitar
    producción. Los 12 tienen que ser cuentas de Google reales, aceptar la
    invitación y **permanecer** en la prueba esos 14 días: el contador se mide
    sobre testers activos, no sobre invitaciones enviadas. Conviene arrancarla
    cuanto antes porque corre en paralelo a la ficha y los formularios.
  - Verificación de identidad (DNI) y datos de contacto de desarrollador
    **públicos** en la ficha (email obligatorio; teléfono/dirección según caso).
- [ ] Crear la app en Console y subir el AAB firmado a prueba interna.
- [ ] **Play App Signing**: Google custodia la clave de firma; tu keystore es la
  "upload key".

### Formularios de política (los que rechazan apps)
- [ ] **Data Safety** — declarar con precisión:
  - *Ubicación precisa*: recogida, vinculada al usuario, para funcionalidad de la app. No compartida con terceros con fines propios.
  - *Salud y fitness* (FC, entrenamientos): recogida, vinculada, funcionalidad.
  - *Info personal* (email, nombre): recogida, vinculada, gestión de cuenta.
  - *Compartición*: métricas de entrenamiento (sin identificadores) se envían a un
    proveedor de IA (OpenRouter, vía Cloud Function) para generar el plan. Firebase/Google
    actúa como encargado (no cuenta como "compartir" si se declara como service provider).
  - *Borrado*: marcar que existe borrado in-app + URL `/delete-account`.
- [ ] **Declaración de apps de salud** (categoría Health & Fitness): declarar el
  uso de datos de salud/fitness y su finalidad.
- [ ] **Cuestionario IARC** (clasificación por edades) — contenido deportivo, sin
  problemas; declarar que no hay anuncios.
- [ ] Público objetivo: 18+ o 16+ (coherente con la edad mínima de la política de
  privacidad — ver sección legal).

### Ficha de la tienda
- [ ] Icono 512×512 (PNG, sin transparencia).
- [ ] Feature graphic 1024×500.
- [ ] Mínimo 2 capturas de teléfono (recomendado 4-8, con marcos y textos).
- [ ] Título (30 chars), descripción corta (80), descripción larga (4000).
- [x] URL de privacidad: `https://runninglaps.com/privacy` ✅

---

## Checklist App Store

### Cuenta y build
- [ ] **Apple Developer Program** (99 $/año) — bloqueante de todo lo demás.
- [ ] Configurar firma en Codemagic (certificado de distribución + provisioning
  profile; Codemagic lo automatiza con la API key de App Store Connect).
- [ ] Compilar con **Xcode 26 / SDK de iOS 26** — obligatorio desde el 28/4/2026.
  `xcode: latest` en codemagic.yaml lo cubre.
- [ ] Subir a TestFlight y probar en dispositivo real (Google Sign-In crash, GPS,
  Live Activity).

### Login: Google + Sign in with Apple ✅ (código listo)
Apple obliga a ofrecer Sign in with Apple si ofreces login de terceros
(guideline 4.8). Estado:
- Google Sign-In iOS **funciona** (el "crash" documentado era un
  `assertionFailure` solo-debug cuando el plist no tenía CLIENT_ID).
- **Sign in with Apple implementado** en Dart (firebase_auth
  `AppleAuthProvider`, sin paquetes nuevos): login + creación del doc inicial +
  reautenticación (borrar cuenta / cambios sensibles) + botón solo-iOS en
  AuthPage.
- **El entitlement ya está en el repo** (`ios/Runner/Runner.entitlements` +
  `CODE_SIGN_ENTITLEMENTS` en las 3 configs del Runner) — **no hace falta Mac
  ni Xcode** para este paso. Verificable hoy re-lanzando el workflow iOS de
  Codemagic (simulador).
- **3 pasos manuales al tener la cuenta de Apple Developer (todo vía web):**
  1. developer.apple.com → Certificates, Identifiers & Profiles → Identifiers
     → App ID `com.runninglaps.runningLaps` → marcar capability
     **"Sign In with Apple"** (la firma automática de Codemagic regenerará el
     provisioning profile con ella).
  2. Firebase Console → Authentication → Sign-in method → habilitar **Apple**.
  3. Probar login/cancelación/reauth en **TestFlight** (no se puede probar sin
     firma con la capability).

### ¿Hace falta un Mac? No.
- **Compilar, firmar y subir a App Store Connect**: Codemagic (Macs en la nube),
  con la integración de App Store Connect API key.
- **Capability/entitlements**: portal web + repo (ya hecho, ver arriba).
- **Probar**: TestFlight se instala directamente en el iPhone.
- **Capturas de la ficha**: desde el iPhone físico (o herramientas de framing).
- Único escenario donde un Mac ayuda: depurar un crash **nativo** raro que solo
  aparezca en TestFlight — los crash logs llegan igualmente a App Store Connect,
  y para un caso puntual existe el alquiler de Mac por horas (MacinCloud y
  similares).

### Formularios y ficha
- [ ] **Privacy Nutrition Labels** en App Store Connect (mismo mapeo que Data
  Safety: ubicación, salud/fitness, info de contacto, identificadores).
- [ ] **Estatus de trader (DSA)** para distribuir en la UE: publicar nombre,
  dirección, email y teléfono en la ficha. Sin esto, la app no se distribuye en
  la UE (España incluida).
- [ ] Capturas para 6.9" y 6.5" (iPhone), icono 1024.
- [ ] **Notas para el revisor**: cuenta demo con datos de entrenamiento ya
  cargados + explicación del uso de ubicación en segundo plano ("registra la ruta
  del entrenamiento mientras la pantalla está bloqueada, con Live Activity visible").
- [ ] Edad (rating) coherente con Play y con la política de privacidad.

---

## Legal: privacidad, términos y RGPD

### Estado (jul 2026): COMPLETADO ✅
- ✅ `web/privacy.html` **reescrita completa para RGPD**: responsable del
  tratamiento (Mario Mendoza + email), bases legales por tratamiento (art. 6),
  sección específica de **datos de salud con consentimiento explícito (art. 9)**
  y cómo retirarlo, encargados (Firebase, OpenRouter — solo métricas sin
  identificadores, dictado por voz vía SO), transferencias internacionales
  (EU-U.S. DPF/SCC), conservación, derechos completos + AEPD, menores (16+),
  seguridad.
- ✅ `web/terms.html`: placeholders rellenados, edad mínima 16 en "Tu cuenta",
  ley aplicable española + protección del consumidor UE. Conserva sus puntos
  fuertes: disclaimer médico, disclaimer del coach IA, limitación de
  responsabilidad, plan gratuito/futuros pagos.
- ✅ `support.html` y `delete-account.html`: email de contacto rellenado.
- ✅ **Consentimiento explícito de datos de salud EN LA APP** (art. 9):
  `HealthConsentService` (persistido en `users/{uid}/settings/healthConsent`
  con fecha y versión de política, auditable) + diálogo de consentimiento antes
  del primer escaneo de pulsómetro en `heart_rate_monitor_view` + opción
  "Retirar consentimiento" en la misma pantalla (revoca + olvida el dispositivo
  para cortar la reconexión automática). Con tests (`health_consent_service_test`).
- ✅ **El consentimiento cubre también al Coach IA** (4 ago 2026) — ver
  § Coach IA: cribado y consentimiento.
- ✅ **Enlace a Privacidad/Términos dentro de la app** (jul 2026) — Google Play
  exige explícitamente que el enlace esté accesible *dentro* de la app, no solo
  en la ficha de la tienda ("must be linked directly within the app itself").
  Antes no existía ningún punto de la app (registro, perfil, ajustes) que
  enlazara a `/privacy` o `/terms` — solo la landing web. Añadido:
  - `url_launcher` como dependencia nueva (`pubspec.yaml`), con el `<queries>`
    de `android/app/src/main/AndroidManifest.xml` para `ACTION_VIEW` + `https`
    (Android 11+ package visibility).
  - Aviso "Al continuar, aceptas los Términos de uso y la Política de
    privacidad" con enlaces tocables, visible en login **y** registro de
    `auth_page.dart` — cubre también el alta implícita vía Google/Apple Sign-In
    (que puede crear cuenta nueva desde la pantalla de login).
  - Sección "Ayuda" del menú de perfil: tiles "Ayuda y contacto", "Política de
    privacidad" y "Términos de uso" que abren
    `runninglaps.com/{support,privacy,terms}` en el navegador (`cleanUrls: true`
    en `firebase.json` sirve esas rutas sin `.html`).
  > ⚠️ Regresión corregida (26 jul 2026): esos 3 tiles vivían en
  > `profile_menu_screen_legacy.dart` y **se perdieron** al eliminar el
  > duplicado el 24 jul (commit `0d615b3`) — durante dos días el único punto de
  > la app que enlazaba a Privacidad/Términos fue `auth_page.dart`, inalcanzable
  > para un usuario ya logueado, justo el incumplimiento que el fix del 19 jul
  > venía a resolver. Reimplantados en `ProfileView` (`_openWebPage`). Al tocar
  > el menú de perfil, comprobar que esta sección sigue ahí.

> Datos publicados en las páginas: responsable "Mario Mendoza", contacto
> `legal@runninglaps.com` (privacidad/términos) y `soporte@runninglaps.com`
> (soporte/borrado de cuenta) vía Cloudflare Email Routing sobre el dominio
> propio, edad mínima 16, ley española.

### Coach IA: cribado y consentimiento (4 ago 2026)

Hasta esta fecha el consentimiento del art. 9 solo tapaba el pulsómetro: su
única puerta era `heart_rate_monitor_view`. Mientras tanto el Coach recogía y
**enviaba a OpenRouter** molestias y lesiones en texto libre
(`weeklyFeedback.molestias`, `motivoParon: 'lesion'`, `recurringConstraints`),
`fcMax`/`fcRest`, fecha de nacimiento y sexo biológico. Un atleta que nunca
conectó una banda usaba el Coach entero sin haber consentido nada.

Qué se ha hecho:

- **Consentimiento por ámbito** (`HealthConsentScope.heartRate` / `.aiCoach`).
  El art. 9 exige consentimiento para fines determinados, no un "sí" genérico:
  cada ámbito se concede y se retira por separado, en el mismo documento
  `users/{uid}/settings/healthConsent` bajo `scopes.<ámbito>`. Quien ya aceptó
  el pulsómetro **no vuelve a ver el diálogo**: el booleano suelto de la raíz
  se sigue leyendo como el ámbito `heartRate` (y se mantiene sincronizado, para
  que revertir esta versión no pierda el consentimiento).
- **Cribado PAR-Q abreviado** (`HealthScreeningService`, 4 preguntas) en
  `users/{uid}/settings/healthScreening`. **No bloquea nada**: un "sí" solo
  muestra el consejo correspondiente — visto bueno médico si la bandera es
  cardíaca, arranque suave si es una molestia — y queda registrado. Su valor es
  doble: ajustar el arranque y poder demostrar que se preguntó y se avisó.
- **Un solo candado, en `planNextWeek()`**: las cuatro rutas de generación
  (automática del domingo, forzada, onboarding y chat) pasan por ahí, así que
  sin consentimiento se lanza `HealthConsentRequiredException` y no sale ni un
  dato. Es un tipo propio para que la UI ofrezca el consentimiento en vez de un
  "error al generar el plan".
- **Dónde se pide**: atletas nuevos → último paso del onboarding del Coach
  (`HealthSafetyForm`, con el botón "Crear mi plan" deshabilitado hasta marcar
  la casilla). Atletas con perfil previo → sheet de `ensureAiCoachHealthConsent`
  una sola vez, desde `launchAiCoachOnboarding` y desde el cuestionario semanal.
  El formulario es **el mismo widget** en los dos sitios: si los textos
  divergieran, el consentimiento dejaría de ser demostrable.
- **Disclaimer médico dentro de la app**, no solo en `terms.html` §4: la línea
  "no es un servicio médico / no sustituye el criterio de un profesional" va en
  `HealthSafetyForm`, que es la pantalla que el atleta sí lee.
- **`provider: { data_collection: "deny" }`** en `functions/src/openrouter.ts`:
  descarta los proveedores que se reservan almacenar el prompt o entrenar con
  él. Va por petición a propósito — el ajuste equivalente de la cuenta de
  OpenRouter es invisible desde el código. ⚠️ Requiere desplegar functions.

> ⚠️ **Consecuencia asumida**: un atleta con perfil previo que no abra el Coach
> deja de recibir plan hasta que pase por el sheet. Es deliberado — la
> alternativa era seguir mandando datos de salud sin base legal.

### Pendiente legal (futuro)
- **Derecho de desistimiento** en los términos cuando haya pagos (Stripe —
  ver docs/MONETIZATION_ARCHITECTURE.md; no aplica al MVP gratuito).
- Si cambia el texto del consentimiento de salud de forma sustancial, subir
  `HealthConsentService.policyVersion` para forzar re-consentimiento.
- **Verificar que OpenRouter está en la lista del EU-U.S. Data Privacy
  Framework**: `privacy.html` §6 ampara la transferencia en el DPF. Si no
  figura en la lista oficial, la base son las SCC y el texto está mal. Pendiente
  también el DPA del art. 28 y conocer sus subencargados (OpenRouter enruta a
  proveedores de modelo).
- **`privacy.html` no menciona el cribado de salud** (`healthScreening`) ni el
  ámbito `aiCoach` del consentimiento. Actualizar la tabla de tratamientos.
- **Edad mínima 16 sin comprobar**: los términos la exigen y la app no la
  valida en ningún punto; `birthDate` es opcional y se pide en el onboarding
  del Coach.
- Revisión por un profesional antes del lanzamiento (recomendado: datos de
  salud + RGPD).

---

## Orden recomendado

1. ~~Placeholders + política de privacidad RGPD + deploy hosting~~ ✅
2. ~~Consentimiento explícito de datos de salud en la app~~ ✅
3. Cuenta de Play Console → prueba interna → prueba cerrada (12 testers si aplica)
   — encaja con la fase de validación en campo actual.
4. Data Safety + declaración de salud + IARC + ficha → producción en Play.
5. Apple Developer Program → firma en Codemagic → decisión del login → TestFlight.
6. Nutrition labels + DSA trader + ficha → revisión de App Store.

> 📄 **Las respuestas concretas de los formularios y los textos de la ficha
> están en [docs/STORE_SUBMISSION.md](docs/STORE_SUBMISSION.md)**, derivadas del
> código (permisos del manifest, campos escritos en Firestore, terceros reales).
> Ahí está el mapeo completo de Data Safety y de las Nutrition Labels, el
> título/descripciones y las notas para el revisor.

## Acciones manuales pendientes ahora mismo

- [x] ~~Rellenar placeholders en privacy/terms/support/delete-account~~ ✅
- [x] ~~Consentimiento de datos de salud en la app~~ ✅
- [x] ~~Deploy de hosting con las páginas legales~~ ✅
- [ ] Decidir: ¿cuenta de Play personal u organización? (condiciona la prueba
  cerrada de 12 testers × 14 días)
- [ ] Crear cuenta de Play Console / Apple Developer Program.
- [ ] Assets de ficha (icono 512, feature graphic, capturas).
