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

### Login: Google + Sign in with Apple ✅ (código listo)
Apple obliga a ofrecer Sign in with Apple si ofreces login de terceros
(guideline 4.8). Estado:
- Google Sign-In iOS **funciona** (el "crash" documentado era un
  `assertionFailure` solo-debug cuando el plist no tenía CLIENT_ID).
- **Sign in with Apple implementado** en Dart (firebase_auth
  `AppleAuthProvider`, sin paquetes nuevos): login + creación del doc inicial +
  reautenticación (borrar cuenta / cambios sensibles) + botón solo-iOS en
  AuthPage. **3 pasos manuales al tener la cuenta de Apple Developer:**
  1. Xcode → target Runner → Signing & Capabilities → añadir capability
     **"Sign In with Apple"** (regenera el provisioning profile).
  2. Firebase Console → Authentication → Sign-in method → habilitar **Apple**.
  3. Probar login/cancelación/reauth en **TestFlight** (no se puede probar sin
     la capability firmada).

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

> Datos publicados en las páginas: responsable "Mario Mendoza", contacto
> `mariomenvel@gmail.com`, edad mínima 16, ley española. Si prefieres un email
> dedicado de soporte o una sociedad como responsable, es un buscar-y-reemplazar
> en las 4 páginas + re-deploy.

### Pendiente legal (futuro)
- **Derecho de desistimiento** en los términos cuando haya pagos (Stripe —
  ver docs/MONETIZATION_ARCHITECTURE.md; no aplica al MVP gratuito).
- Si cambia el texto del consentimiento de salud de forma sustancial, subir
  `HealthConsentService.policyVersion` para forzar re-consentimiento.
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

## Acciones manuales pendientes ahora mismo

- [x] ~~Rellenar placeholders en privacy/terms/support/delete-account~~ ✅
- [x] ~~Consentimiento de datos de salud en la app~~ ✅
- [x] ~~Deploy de hosting con las páginas legales~~ ✅
- [ ] Decidir: ¿cuenta de Play personal u organización? (condiciona la prueba
  cerrada de 12 testers × 14 días)
- [ ] Crear cuenta de Play Console / Apple Developer Program.
- [ ] Assets de ficha (icono 512, feature graphic, capturas).
