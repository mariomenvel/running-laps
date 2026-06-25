# Firestore — Patrones de Acceso

> Generado analizando todos los repositorios y servicios de `lib/`.
> Principios aplicados: mínimo privilegio, sin escritura cruzada entre usuarios salvo excepciones documentadas, sin escalada de privilegios.

---

## Resumen por colección

| Colección | Quién lee | Quién escribe | Regla aplicada |
|-----------|-----------|---------------|----------------|
| `users/{uid}` | Cualquier usuario autenticado | Solo el propietario (sin poder cambiar `isAdmin`) | `read: isSignedIn()` · `write: isOwner && !affectsIsAdmin` |
| `users/{uid}/trainings/{id}` | Cualquier usuario autenticado ⚠️ | Solo el propietario | `read: isSignedIn()` · `write: isOwner` |
| `users/{uid}/tags/{id}` | Solo el propietario | Solo el propietario | `read/write: isOwner` |
| `users/{uid}/groups/{groupId}` | Solo el propietario | Solo el propietario | `read/write: isOwner` |
| `users/{uid}/result_notifications/{id}` | Solo el propietario | Propietario (update/delete) · Cualquier autenticado (create) ⚠️ | `read/delete: isOwner` · `create: isSignedIn()` |
| `users/{uid}/athleteSessions/{id}` | Solo el propietario | Propietario + Cloud Functions | `read/write: isOwner` |
| `users/{uid}/aiCoachEvents/{id}` | Solo el propietario | Solo el propietario | `read/write: isOwner` |
| `users/{uid}/settings/aiCoachProfile` | Solo el propietario | Solo el propietario | `read/write: isOwner` |
| `users/{uid}/settings/aiCoachUsage` | Solo el propietario | Propietario + Cloud Functions (reset semanal) | `read/write: isOwner` |
| `appConfig/aiCoachProvider` | Cualquier autenticado | Solo app-admin | `read: isSignedIn()` · `write: isAdmin` |
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
| Registro — crear perfil | `users/{uid}` | `create: isOwner` |
| Google login — crear/actualizar perfil | `users/{uid}` | `create: isOwner` · `update: isOwner` |
| Leer `isAdmin` para acceso al panel admin | `users/{uid}` | `read: isSignedIn()` |
| Buscar usuario por email (invite lookup) | `users` (query) | `read: isSignedIn()` |

### Training (`features/training/`)
| Operación | Colección | Regla |
|-----------|-----------|-------|
| Guardar entrenamiento | `users/{uid}/trainings` | `write: isOwner` |
| Leer historial propio | `users/{uid}/trainings` | `read: isSignedIn()` (propietario) |
| Leer entrenamientos para ranking de grupo | `users/{uid}/trainings` | `read: isSignedIn()` ⚠️ |
| CRUD etiquetas | `users/{uid}/tags` | `read/write: isOwner` |
| Admin — collectionGroup `trainings` | todos los `trainings` | `read: isSignedIn()` (admin is signed in) |

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
| Servicio | Operación | Colección | Regla |
|---------|-----------|-----------|-------|
| `TrainingChallengeSyncService` | Sync participación propia | `participants/{uid}` | `write: isOwner` |
| `TrainingChallengeSyncService` | Escribir notificación a ganadores | `users/{uid}/result_notifications` | `create: isSignedIn()` ⚠️ |
| `ChallengeFinalizationService` | Actualizar estado del desafío | `groups/{groupId}/challenges/{id}` | `write: isGroupAdmin` |
| `ChallengeFinalizationService` | Escribir medallas / historial | `medals/{uid}`, `medal_history/{id}` | `write: isGroupAdmin` |
| `ChallengeFinalizationService` | Escribir badges / historial | `badges/{uid}`, `badge_history/{id}` | `write: isGroupAdmin` |
| `ChallengeFinalizationService` | Notificaciones a ganadores | `users/{uid}/result_notifications` | `create: isSignedIn()` ⚠️ |
| `AutoJoinService` | Auto-registro participación | `participants/{uid}` | `write: isOwner` |
| `UserLookupService` | Buscar por email | `users` (query) | `read: isSignedIn()` |

### Admin (`features/admin/`)
| Operación | Colección | Regla |
|-----------|-----------|-------|
| Leer todos los usuarios | `users` | `read: isSignedIn()` (admin is signed in) |
| collectionGroup trainings | `users/*/trainings` | `read: isSignedIn()` |
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

### ⚠️ Lectura cruzada de entrenamientos (`users/{uid}/trainings`)
**Problema:** La regla actual permite a cualquier usuario autenticado leer entrenamientos de cualquier otro usuario. El principio correcto sería "solo si comparten un grupo", pero Firestore Rules no puede hacer joins (necesitaría saber el `groupId` en tiempo de evaluación).

**Solución recomendada:** Migrar el cálculo de ranking a una Cloud Function con Admin SDK. La función recibe el `groupId`, obtiene los miembros y compila el ranking server-side. La regla de cliente se puede restringir a `isOwner(uid)`.

### ⚠️ Escritura cruzada en `result_notifications`
**Problema:** `ChallengeFinalizationService` escribe notificaciones en la cuenta de otros usuarios (ganadores del desafío) desde el cliente.

**Solución recomendada:** Mover la lógica de finalización a una Cloud Function con Admin SDK. La regla de cliente se puede restringir a `isOwner(uid)`.

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
