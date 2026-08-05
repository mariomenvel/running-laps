# Firestore — Patrones de Acceso

> Generado analizando todos los repositorios y servicios de `lib/`.
> Principios aplicados: mínimo privilegio, sin escritura cruzada entre usuarios salvo excepciones documentadas, sin escalada de privilegios.

---

## Resumen por colección

| Colección | Quién lee | Quién escribe | Regla aplicada |
|-----------|-----------|---------------|----------------|
| `users/{uid}` | Cualquier usuario autenticado | Solo el propietario (sin poder cambiar `isAdmin`) | `read: isSignedIn()` · `write: isOwner && !affectsIsAdmin` |
| `users/{uid}/trainings/{id}` | Solo el propietario | Solo el propietario | `read/write: isOwner` |
| `users/{uid}/tags/{id}` | Solo el propietario | Solo el propietario | `read/write: isOwner` |
| `users/{uid}/groups/{groupId}` | Solo el propietario | Solo el propietario | `read/write: isOwner` |
| `users/{uid}/result_notifications/{id}` | Solo el propietario | Solo el propietario | `read/update/delete/create: isOwner` — el `create: isSignedIn()` se cerró el 5 ago 2026 (sin cliente desde que se fue grupos) |
| `users/{uid}/athleteSessions/{id}` | Solo el propietario | Propietario + Cloud Functions | `read/write: isOwner` |
| `users/{uid}/raceGoals/{id}` | Solo el propietario | Solo el propietario | `read/write: isOwner` |
| `users/{uid}/aiCoachEvents/{id}` | Solo el propietario | Solo el propietario | `read/write: isOwner` |
| `users/{uid}/settings/aiCoachProfile` | Solo el propietario | Solo el propietario | `read/write: isOwner` |
| `users/{uid}/settings/aiCoachUsage` | Solo el propietario | Propietario + Cloud Functions (reset semanal) | `read/write: isOwner` |
| `users/{uid}/settings/healthConsent` 🔒 | Solo el propietario | Solo el propietario (vía `HealthConsentService`) | `read/write: isOwner` |
| `users/{uid}/settings/healthScreening` 🔒 | Solo el propietario | Solo el propietario (vía `HealthScreeningService`) | `read/write: isOwner` |
| `appConfig/aiCoachProvider` | Cualquier autenticado | Solo app-admin | `read: isSignedIn()` · `write: isAdmin` |
| `appConfig/global` | Cualquier autenticado | Solo app-admin | `read: isSignedIn()` · `write: isAdmin` · campo `betaFreeAccess: bool` — durante beta: `true`; lanzamiento: `false` |
| `groups/{groupId}` | Cualquier autenticado | Create: cualquier autenticado · Update/delete: admin del grupo | `read/create: isSignedIn()` · `update/delete: isGroupAdmin` |
| `groups/{groupId}/members/{uid}` | Miembros del grupo | El propio usuario · Admin del grupo | `read: isGroupMember` · `write: isOwner \|\| isGroupAdmin` |
| `groups/{groupId}/challenges/{id}` | Miembros del grupo | Solo admin del grupo | `read: isGroupMember` · `write: isGroupAdmin` |
| `groups/{groupId}/challenges/{id}/participants/{uid}` | Miembros del grupo · App admin | Solo el propio usuario | `read: isGroupMember \|\| isAdmin` · `write: isOwner` |
| `groups/{groupId}/invites/{inviteId}` | Cualquier autenticado | Solo admin del grupo | `read: isSignedIn()` · `write: isGroupAdmin` |
| `groups/{groupId}/medals/{uid}` | Miembros del grupo | Admin del grupo (finalización) | `read: isGroupMember` · `write: isGroupAdmin` |
| `groups/{groupId}/medal_history/{id}` | Miembros del grupo | Admin del grupo (finalización) | `read: isGroupMember` · `write: isGroupAdmin` |
| `groups/{groupId}/badges/{uid}` | Miembros del grupo | Admin del grupo (finalización) | `read: isGroupMember` · `write: isGroupAdmin` |
| `groups/{groupId}/badge_history/{id}` | Miembros del grupo | Admin del grupo (finalización) | `read: isGroupMember` · `write: isGroupAdmin` |
| `groups/{groupId}/prefs/{uid}` | Solo el propietario | Solo el propietario | `read/write: isOwner` |
| `challenge_templates/{id}` | Cualquier autenticado | Solo app-admin | `read: isSignedIn()` · `write: isAdmin` |
| `global_challenges/{id}` | Cualquier autenticado | Solo app-admin | `read: isSignedIn()` · `write: isAdmin` |

---

## Detalle de acceso por servicio/repositorio

### Auth (`features/auth/`)
| Operación | Colección | Regla |
|-----------|-----------|-------|
| Registro — crear perfil | `users/{uid}` | `create: isOwner` · campos relevantes: `isAthleteMode` (bool, gratis), `hasPremiumCoach` (bool, escrito solo por Cloud Function webhook Stripe — no editar desde cliente) |
| Google login — crear perfil inicial | `users/{uid}` | `create: isOwner` · el doc se crea **solo si no existe** (`userDocExists` — get previo); nunca se sobrescribe un doc existente porque la escritura es `set()` sin merge |
| Leer `isAdmin` para acceso al panel admin | `users/{uid}` | `read: isSignedIn()` |
| Buscar usuario por email (invite lookup) | `users` (query) | `read: isSignedIn()` |
| Reset de contraseña | — (solo Firebase Auth) | Sin lecturas Firestore: la query previa por email fue eliminada (jul 2026) — corría sin sesión (siempre permission-denied) y era enumeración de cuentas |
| Borrar cuenta | Cloud Function `deleteUserData` (Admin SDK) | Borra recursivamente `users/{uid}` + artefactos en grupos (member/prefs/medals/badges/participants) + participaciones globales + usuario de Auth. Exige token con `auth_time` < 10 min (la UI reautentica justo antes). Fallback cliente (solo `users/{uid}` + Auth) si la función no está desplegada |

### Training (`features/training/`)

> Desde jul 2026 existe `users/{uid}/trainings/{id}/track/data`: la traza GPS
> de la sesión y de cada serie, fuera del documento del entrenamiento. Hereda
> las reglas de `trainings` (subcolección). Solo se lee al pintar un mapa.

| Operación | Colección | Regla |
|-----------|-----------|-------|
| Guardar entrenamiento | `users/{uid}/trainings` | `write: isOwner` |
| Leer historial propio | `users/{uid}/trainings` | `read: isOwner` |
| ~~Leer entrenamientos para ranking de grupo~~ | — | Eliminado con grupos; la regla es `read: isOwner` (ver § Lectura cruzada) |
| CRUD etiquetas | `users/{uid}/tags` | `read/write: isOwner` |
| Admin — collectionGroup `trainings` | todos los `trainings` | ❌ **denegado** desde que `trainings` es `read: isOwner` — ver § Panel de admin |

### Groups — repositorios (`features/groups/`)
| Operación | Colección | Regla |
|-----------|-----------|-------|
| Crear grupo | `groups/{groupId}` | `create: isSignedIn()` |
| Actualizar/borrar grupo | `groups/{groupId}` | `update/delete: isGroupAdmin` |
| Leer grupo | `groups/{groupId}` | `read: isSignedIn()` |
| Leer roster de miembros | `groups/{groupId}/members` | `read: isGroupMember` |
| Unirse al grupo (crear propio member doc) | `groups/{groupId}/members/{uid}` | `write: isOwner` |
| Kick / cambio de rol | `groups/{groupId}/members/{uid}` | `write: isGroupAdmin` |
| CRUD desafíos | `groups/{groupId}/challenges` | `read: isGroupMember` · `write: isGroupAdmin` |
| Registro de participación | `groups/{groupId}/challenges/{id}/participants/{uid}` | `read: isGroupMember` · `write: isOwner` |
| Crear/revocar invitación | `groups/{groupId}/invites` | `write: isGroupAdmin` |
| Validar token de invitación | `groups/{groupId}/invites` | `read: isSignedIn()` |
| Aceptar invitación — escribir en members | `groups/{groupId}/members/{uid}` | `write: isOwner` |
| Aceptar invitación — escribir en user groups | `users/{uid}/groups/{groupId}` | `write: isOwner` |

### Groups — servicios

> ⚠️ **Ninguno de estos servicios existe ya en `lib/`** — se fueron con la
> feature de grupos (ago 2026). La tabla se conserva porque las reglas de
> `groups`/`global_challenges` siguen en `firestore.rules` (inertes, para poder
> recuperar la feature). Lo único que estas filas describían y **sí** tocaba el
> árbol de otro usuario era la escritura en `result_notifications`, ya cerrada.

| Servicio | Operación | Colección | Regla |
|---------|-----------|-----------|-------|
| `TrainingChallengeSyncService` | Sync participación propia | `participants/{uid}` | `write: isOwner` |
| `TrainingChallengeSyncService` | Escribir notificación a ganadores | `users/{uid}/result_notifications` | ✅ cerrado: `create: isOwner` |
| `ChallengeFinalizationService` | Actualizar estado del desafío | `groups/{groupId}/challenges/{id}` | `write: isGroupAdmin` |
| `ChallengeFinalizationService` | Escribir medallas / historial | `medals/{uid}`, `medal_history/{id}` | `write: isGroupAdmin` |
| `ChallengeFinalizationService` | Escribir badges / historial | `badges/{uid}`, `badge_history/{id}` | `write: isGroupAdmin` |
| `ChallengeFinalizationService` | Notificaciones a ganadores | `users/{uid}/result_notifications` | ✅ cerrado: `create: isOwner` |
| `AutoJoinService` | Auto-registro participación | `participants/{uid}` | `write: isOwner` |
| ~~`UserLookupService`~~ | Buscar por email | `users` (query) | Servicio eliminado — ya no justifica el `read: isSignedIn()` de `users` |

### Admin (`features/admin/`)
| Operación | Colección | Regla |
|-----------|-----------|-------|
| Leer todos los usuarios | `users` | `read: isSignedIn()` (admin is signed in) — es lo único que sostiene esa regla, ver § Panel de admin |
| collectionGroup trainings | `users/*/trainings` | ❌ **denegado** desde ago 2026 (`read: isOwner`) |
| collectionGroup participants | `groups/*/challenges/*/participants` | `read: isGroupMember \|\| isAdmin` |
| CRUD global_challenges | `global_challenges` | `write: isAdmin` |

### Home / Profile
| Operación | Colección | Regla |
|-----------|-----------|-------|
| Leer estadísticas propias | `users/{uid}/trainings` | `read: isSignedIn()` (propietario) |
| Leer / escribir preferencias de grupo | `groups/{groupId}/prefs/{uid}` | `read/write: isOwner` |
| Leer medallas / badges propios | `groups/{groupId}/medals/{uid}` | `read: isGroupMember` |

---

## Limitaciones conocidas y recomendaciones

### ✅ Lectura cruzada de entrenamientos — cerrada (ago 2026)
Esta sección describía que cualquier usuario autenticado podía leer los
entrenamientos de cualquier otro, para que el ranking de grupo funcionase. La
regla se cerró a `isOwner(uid)` al eliminarse la feature de grupos, pero **ni
esta doc ni el comentario de `firestore.rules` se actualizaron** y ambos
siguieron describiendo un agujero que ya no existía (corregido el 4 ago 2026).

⚠️ No volver a abrirla sin pensarlo: el documento de entrenamiento lleva FC
(`fcMediaSesion`, `fcMaxSesion` y, por serie, `fcMedia`/`fcReadings`), que es
dato de salud del art. 9. Si vuelven los rankings, calcularlos en una Cloud
Function con Admin SDK y dejar la regla en `isOwner`.

### ✅ Escritura cruzada en `result_notifications` — cerrada (5 ago 2026)
`allow create: if isSignedIn()` permitía a cualquier usuario autenticado crear
documentos dentro de `users/{otroUid}/result_notifications`. Se puso para
`ChallengeFinalizationService`, que **se eliminó con la feature de grupos**: no
queda una sola referencia en `lib/`, `test/` ni `functions/src/`.

A diferencia de las reglas de `groups`/`global_challenges` —que se conservaron
a propósito y son inertes porque nadie escribe ahí—, esta **sí era una puerta
abierta**: escribía dentro del árbol de la cuenta de otro usuario y cualquiera
con una cuenta podía usarla para spam. `create` pasa a `isOwner(uid)`; el resto
de topes (nº de claves, tamaño de `type`, `toUid == uid`) se conservan.

⚠️ **No surte efecto hasta desplegar las reglas** (`firebase deploy --only
firestore:rules`).

### ⚠️ `users/{uid}` — lectura cruzada de perfiles, sostenida solo por el panel de admin
`allow read: if isSignedIn()` deja a cualquier usuario autenticado leer (y
consultar) el documento de perfil de cualquier otro, que lleva `birthDate`,
`sex` y `fcMax`. Las dos razones que documentaba la regla ya no existen —
ranking de grupo y `UserLookupService`—; lo único que la usa hoy es
`AdminRepository` (`count()` de `users` y query por `generativeAvatarConfig`),
que corre como un usuario firmado normal porque no hay regla de lectura por
`isAdmin`.

El arreglo natural es `isOwner(uid) || isAdmin()`, pero **no se ha hecho aquí**:
cambia lo que el panel puede leer, no lo ve el analizador ni la suite de tests
y solo se comprueba con el emulador de reglas o en vivo. Encaja con sacar el
panel a web (CLAUDE.md, deuda #5), que dejaría la regla sin ningún cliente.

### ⚠️ Panel de admin — sus métricas globales ya están rotas
`AdminRepository.getGlobalStats()` hace `collectionGroup('trainings')` sobre
todos los usuarios. Desde que `trainings` es `read: isOwner` (ago 2026, al
quitar los rankings de grupo) esa query **la deniega Firestore**: el `try`
interno se traga el error y el panel enseña las métricas de entrenamiento a
cero o vacías.

No se arregla aflojando la regla — el documento de entrenamiento lleva FC, dato
del art. 9. La salida es calcular los agregados en una Cloud Function con Admin
SDK, que es justo lo que haría el panel web al que está previsto migrar.

### ⚠️ isAdmin protegido solo contra auto-modificación
El campo `isAdmin` en `users/{uid}` está protegido contra auto-modificación (`!affectedKeys().hasAny(['isAdmin'])`), pero solo el Firebase console o una Cloud Function con Admin SDK debería establecerlo. Nunca expongas un endpoint no autenticado que pueda cambiar este campo.

---

## Helpers definidos en `firestore.rules`

| Función | Descripción | Coste |
|---------|-------------|-------|
| `isSignedIn()` | `request.auth != null` | 0 reads |
| `isOwner(uid)` | `request.auth.uid == uid` | 0 reads |
| `isAdmin()` | Lee `users/{uid}.isAdmin` | 1 `get()` |
| `isGroupMember(groupId)` | Comprueba existencia en `groups/{groupId}/members/{uid}` | 1 `exists()` |
| `isGroupAdmin(groupId)` | Lee `groups/{groupId}/members/{uid}.role` | 1 `get()` |
