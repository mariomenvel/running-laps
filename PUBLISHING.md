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
  además del flujo in-app. ⚠️ Pendiente `firebase deploy --only hosting`.
- ✅ Política de privacidad y términos con URL pública (`/privacy`, `/terms`).
- ✅ App Check Android (Play Integrity en release, debug provider en debug).

---

## Checklist Google Play

### Cuenta y proceso
- [ ] Crear cuenta de **Play Console** (25 $, pago único).
  - ⚠️ Si es cuenta **personal** (no organización) creada después de nov 2023:
    obligatorio pasar una **prueba cerrada con 12 testers durante 14 días** antes
    de poder solicitar producción. Planificar el calendario con esto.
  - Verificación de identidad (DNI) y datos de contacto de desarrollador
    **públicos** en la ficha (email obligatorio; teléfono/dirección según caso).
- [ ] Crear la app en Console y subir el AAB firmado a prueba interna.
- [ ] **Play App Signing**: Google custodia la clave de firma; tu keystore es la
  "upload key". ⚠️ Respaldar el keystore y sus contraseñas — perderlo complica
  cualquier futuro fuera de Play.

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
- [ ] URL de privacidad: `https://<dominio>/privacy`.

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

### Decisión de producto: el login ⚠️
Apple **obliga a ofrecer Sign in with Apple si ofreces login de terceros**
(Google Sign-In). Además el Google Sign-In de iOS crashea hoy (deuda #1). Opciones:
- **A (recomendada para MVP)**: en iOS, ocultar el botón de Google y lanzar solo
  con email/contraseña → no aplica la obligación de Sign in with Apple.
- **B**: arreglar Google Sign-In iOS **y** añadir Sign in with Apple.

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

### Estado actual de las páginas
- `web/terms.html` — **estructura sólida**: disclaimer médico ("no sustituye el
  consejo de un médico"), disclaimer del coach IA, limitación de responsabilidad,
  cláusula de plan gratuito/futuros pagos, propiedad de los datos del usuario.
- `web/privacy.html` — buen esqueleto (recoge GPS, FC, datos del coach IA, no
  venta de datos, proveedor de IA sin identificadores) pero **incompleta para RGPD**.
- ⚠️ **Ambas tienen placeholders sin rellenar**: `[fecha]`, `[email-soporte]`,
  `[edad mínima]` (y el mailto de `support.html` y `delete-account.html`).
  **Cualquier revisor lo ve. Bloqueante.**

### Huecos RGPD a cubrir en la política de privacidad
1. **Responsable del tratamiento**: nombre completo (persona física o sociedad),
   y email de contacto. Sin esto la política no es válida.
2. **Bases legales** por tratamiento (Art. 6): ejecución del contrato (la app),
   consentimiento (datos de salud, notificaciones), interés legítimo (seguridad).
3. **Datos de salud = categoría especial (Art. 9 RGPD)**. La frecuencia cardíaca
   y los datos de fitness requieren **consentimiento explícito**:
   - En la política: base legal "consentimiento explícito" y cómo retirarlo.
   - ⚠️ **En la app**: hace falta una casilla/pantalla de consentimiento en el
     onboarding o al conectar el pulsómetro ("Acepto el tratamiento de mis datos
     de salud para..."). Hoy no existe — **tarea de producto pendiente**.
4. **Transferencias internacionales**: Google/Firebase y OpenRouter procesan en
   EE. UU. — citar el EU-U.S. Data Privacy Framework / cláusulas contractuales tipo.
5. **Plazos de conservación**: mientras la cuenta esté activa + borrado al eliminar.
6. **Derechos completos**: acceso, rectificación, supresión, **portabilidad,
   limitación y oposición**, retirada del consentimiento, y **derecho a reclamar
   ante la AEPD** (www.aepd.es). La página actual solo menciona tres.
7. **Edad mínima**: en España un menor puede consentir el tratamiento de sus datos
   desde los **14 años** (LOPDGDD art. 7). Recomendación práctica: fijar 16+
   (simplifica) o 14+ y decláralo coherentemente en IARC/App Store.
8. **Encargados del tratamiento**: listar Google/Firebase (infraestructura, auth,
   analytics si aplica) y OpenRouter/proveedor LLM (generación de planes, solo
   métricas sin identificadores — como ya dice la política ✅).

### Términos: retoques menores
- Rellenar placeholders (fecha, email, y verificar la cláusula de ley aplicable →
  España, jurisdicción del consumidor).
- Añadir mención al **derecho de desistimiento** solo cuando haya pagos (futuro
  Stripe — ver docs/MONETIZATION_ARCHITECTURE.md; no aplica al MVP gratuito).

---

## Orden recomendado

1. Rellenar placeholders + completar la política de privacidad (RGPD) → deploy hosting.
2. Añadir el consentimiento explícito de datos de salud en el onboarding de la app.
3. Cuenta de Play Console → prueba interna → prueba cerrada (12 testers si aplica)
   — encaja con la fase de validación en campo actual.
4. Data Safety + declaración de salud + IARC + ficha → producción en Play.
5. Apple Developer Program → firma en Codemagic → decisión del login → TestFlight.
6. Nutrition labels + DSA trader + ficha → revisión de App Store.

## Acciones manuales pendientes ahora mismo

- [ ] `firebase deploy --only hosting` (publica `/delete-account` y cualquier
  cambio de privacy/terms).
- [ ] Rellenar `[email-soporte]`, `[fecha]`, `[edad mínima]` en
  privacy/terms/support/delete-account.
- [ ] Decidir: ¿cuenta de Play personal u organización?
