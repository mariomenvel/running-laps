# Firebase — estado real del proyecto

Manual de referencia rápida: qué hay activo en Firebase, verificado directamente
contra el proyecto (`firebase functions:list`, `firebase apps:list`, lectura de
`firestore.rules` / `functions/src/*.ts`), no solo inferido del código Dart.
Proyecto: **running-laps-mario-2025** (número 461355077893).

Última verificación completa: **18 jul 2026**. Si pasan meses sin tocar esto,
antes de fiarte re-ejecuta `firebase functions:list` / `firebase apps:list` —
esta tabla es una foto fija, no un dashboard en vivo.

---

## 1. Resumen — qué usa la app hoy

| Servicio | Estado | Notas |
|---|---|---|
| Authentication | ✅ Activo | Email/pass + Google. Apple listo en código, pendiente activar en consola (deuda #1 en CLAUDE.md). |
| Firestore | ✅ Activo | 1 base de datos, reglas propias detalladas (§3). |
| Cloud Functions | ✅ Activo — 6 funciones desplegadas | Ver §4, confirmado en vivo. |
| Storage | ⚠️ Configurado pero **sin usar** | Dependencia en `pubspec.yaml`, cero código activo que la llame (§5). |
| App Check | ⚠️ Parcial | Android + Web activos, iOS omitido (sin cuenta Apple Developer). |
| Crashlytics | ✅ Activo (jul 2026) | Verificado en dispositivo real — ver conversación de esta sesión. |
| Analytics | ✅ Activo (jul 2026) | Verificado con logs nativos del SDK (`screen_view` registrado y encolado). |
| Hosting | ✅ Activo | Sirve `hosting/` (jul 2026): landing SEO en `/` (index.html, capturas reales, JSON-LD, sitemap/robots), páginas legales con `cleanUrls` (`/privacy`, `/terms`, `/support`, `/delete-account`), rewrite `/api/waitlist` → `joinWaitlist` y redirect 301 de la antigua `/landing.html`. `web/` queda solo como source de Flutter web (no se despliega). |
| Remote Config / FCM push | ❌ No usado | No hay dependencia ni código — las notificaciones son locales (`flutter_local_notifications`), no push. |

---

## 2. Authentication

- **Email/contraseña**: requiere verificación de email antes de dejar entrar a `MainShell` (gate en `AuthWrapper`). El claim `email_verified` se sincroniza server-side vía la función `syncEmailVerified` (§4) porque el token de Firebase Auth no lo refresca solo.
- **Google Sign-In**: funcionando en dispositivo (el "crash" antiguo era un `assertionFailure` solo-debug, ver CLAUDE.md).
- **Sign in with Apple**: código completo (login, doc inicial, reauth, botón solo-iOS), pendiente de 3 pasos manuales en Apple Developer + Firebase Console + TestFlight (deuda #1).
- **Wear OS**: el reloj NO tiene sesión de Firebase Auth real — usa un bypass temporal (QR + código, `wear_sessions/{code}`) y escribe `trainings` autoidentificándose con `source: "wear_os"` + `wear_uid`. Reemplazo pendiente con Cloud Function + custom token (deuda #2).

## 3. Firestore

El detalle completo de colecciones, quién lee/escribe cada una y por qué ya
está mantenido en **[`firestore_access_patterns.md`](firestore_access_patterns.md)**
— no lo duplico aquí para no tener dos fuentes que se desincronicen. Ese
documento incluye también las limitaciones conocidas (lectura cruzada de
`trainings`, escritura cruzada en `result_notifications`) que ya están en la
deuda técnica de CLAUDE.md.

⚠️ Al releerlo ahora (jul 2026) noté que menciona `hasPremiumCoach` escrito
"por Cloud Function webhook Stripe" — esa función **no existe** en
`functions/src/` (solo las 6 de §4). La monetización sigue en diseño
(`docs/MONETIZATION_ARCHITECTURE.md`, per CLAUDE.md), así que esa línea del
doc de patrones de acceso está adelantada a lo que hay implementado — no la
he tocado porque no es el objeto de esta revisión, pero si lo lees, ese campo
concreto es aspiracional, no real todavía.

**Índices**: solo 1 compuesto (`settings` collectionGroup, `plan` + `messagesUsed`,
usado por `resetWeeklyChatUsage`). Cualquier query nueva con `where` compuesto
necesitará añadir su índice a `firestore.indexes.json` y desplegar.

## 4. Cloud Functions (confirmado en vivo, `firebase functions:list`)

| Función | Trigger | Qué hace |
|---|---|---|
| `callOpenRouter` | callable | Proxy a OpenRouter para el AI Coach (Claude Sonnet). La API key vive en Secret Manager (`OPENROUTER_API_KEY`), nunca en el cliente. Límite de payload 200k chars. |
| `deleteUserData` | callable | Borrado completo de cuenta: artefactos en grupos → `recursiveDelete` de `users/{uid}` → borrado del Auth user. Exige `auth_time` < 10 min (equivalente a "reauth reciente"). |
| `joinWaitlist` | HTTPS (público, CORS) | Formulario de landing (`/api/waitlist`) — guarda email en `waitlist/{email}`. |
| `ping` | callable | Health check simple (requiere auth, devuelve uid + timestamp). Útil para probar conectividad desde la app sin tocar datos reales. |
| `resetWeeklyChatUsage` | scheduled (lunes 00:05 Europe/Madrid) | Resetea el contador semanal de mensajes del chat del AI Coach. |
| `syncEmailVerified` | callable | Sincroniza `emailVerified` de Auth → custom claim `email_verified` (el token no se refresca solo tras verificar). |

Todas: **nodejs20, v2, us-central1, 256MiB**. Sin funciones huérfanas detectadas
(el código fuente en `functions/src/` coincide 1:1 con lo desplegado).

## 5. Storage — hallazgo de esta revisión

`firebase_storage: ^13.0.3` está en `pubspec.yaml` pero **no hay una sola
llamada activa** en todo `lib/` — el único hit es una línea *comentada* en
`edit_profile_picture_view.dart` (que además es una vista huérfana marcada
para borrar, ver deuda #5 en CLAUDE.md). Los avatares se generan localmente
como SVG (`AvatarGenerator`), no se sube ninguna imagen.

No hay `storage.rules` en el repo ni entrada `"storage"` en `firebase.json` —
si en algún momento se sube algo a un bucket por fuera de este flujo, no hay
reglas versionadas controlando el acceso. Si no se va a implementar subida de
fotos a corto plazo, valdría la pena quitar la dependencia; si sí, hay que
crear `storage.rules` antes de escribir el primer `putFile`.

## 6. App Check

- **Android**: activo, `AndroidPlayIntegrityProvider` en release / `AndroidDebugProvider` en debug.
- **Web**: activo, `ReCaptchaV3Provider`.
- **iOS**: omitido — requiere cuenta Apple Developer (no disponible todavía).

## 7. Observability (añadido en esta sesión, jul 2026)

- **Crashlytics** (`firebase_crashlytics: ^5.2.3`): captura errores Flutter/Dart
  vía `FlutterError.onError` + `PlatformDispatcher.instance.onError` en
  `main.dart`, guardado tras `!kIsWeb` (el plugin no soporta Web). Plugin de
  Gradle añadido para symbolicar crashes nativos.
- **Analytics** (`firebase_analytics: ^12.4.2`): wrapper en
  `core/services/analytics_service.dart`. Como la navegación principal es un
  `IndexedStack` (`MainShell`) sin rutas de `Navigator`, las screen views se
  registran a mano en cada cambio de tab — no hay forma de instrumentarlo
  automáticamente con un `NavigatorObserver`.
- Ambos verificados en dispositivo real (no solo compilación): ver la entrada
  "`Firebase.initializeApp()` crasheaba en arranque en Android" en el
  changelog de CLAUDE.md — el bug que se encontró y arregló en el proceso.

## 8. Apps registradas (`firebase apps:list`)

5 apps bajo el proyecto: Android ×2 (una sin nombre, App ID
`...46015cdb77b81d1cbca76c`, que **no** coincide con la del
`google-services.json` actual — probablemente un registro de prueba antiguo
sin usar), iOS, y Web ×2 (`web` y `windows`, comparten implementación Firebase
Web). Limpiar el Android huérfano en Firebase Console es opcional — no rompe
nada, es solo ruido.

---

## Ideas para más adelante (no implementado, solo para no perder el hilo)

Lo que pediste como "panel admin sencillo cuando haya web" — hoy `lib/features/admin/`
ya existe pero cubre solo producto (retos globales, dashboard de stats), no
salud de infraestructura. Un futuro "estado de Firebase" ahí o en una web aparte
podría mostrar: último error de Crashlytics, funciones con error rate alto,
cuota de OpenRouter usada, tamaño de `trainings` por usuario (relevante para la
deuda #3 de PBs). Es trabajo nuevo, no una tarde — cuando quieras lo planificamos
en serio.
