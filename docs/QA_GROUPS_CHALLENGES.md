# QA Checklist: Groups & Challenges (Phase 9)

Este documento define los pasos para la validación manual / QA de la funcionalidad de Grupos, Retos, Sincronización y Recompensas.

## 1. Gestión de Grupos
- [ ] **Crear Grupo**:
  - Verificar que se puede crear un grupo nuevo.
  - Verificar que el creador es `owner` y tiene `status: active` en `members`.
  - Verificar que `activeChallengeId` inicia vacío o nulo.
- [ ] **Invitar Miembros**:
  - Generar un enlace de invitación.
  - Verificar que el enlace contiene un token válido.
- [ ] **Unirse a Grupo (Usuario B)**:
  - Usar la invitación con otro usuario.
  - Verificar que aparece el diálogo de confirmación.
  - Al aceptar, verificar que:
    - Se incrementa `memberCount` del grupo.
    - Se crea documento en `groups/{id}/members/{uid}` con `status: active`.
    - Se actualiza índice `users/{uid}/groups/{groupId}`.

## 2. Retos Automáticos y Manuales
- [ ] **Auto Challenges**:
  - Al entrar al grupo, verificar que el sistema asegura 4 retos activos (2 weekly + 2 monthly).
  - Comprobar que los IDs generados son deterministas (ej. `tmpl__dist_w__2025-W01`).
- [ ] **Reto Manual**:
  - Crear un reto manual (solo owner).
  - Verificar fechas de inicio y fin correctas.

## 3. Participación y Sincronización
- [ ] **Auto-Join Prompt**:
  - Entrar como miembro nuevo a un grupo con retos activos.
  - Verificar que aparece el diálogo preguntando si quiere unirse a los retos.
  - **Acción SI**: Verificar que se crean documentos en `participants` para todos los retos activos.
  - **Acción NO**: Verificar que NO se une automáticamente.
- [ ] **Opt-in Manual**:
  - Si dijo NO, ir a la lista, tocar "Unirse" en un reto.
  - Verificar estado cambia a "Participando".
- [ ] **Sincronización Entrenamiento**:
  - Guardar un entrenamiento que cumpla fecha y filtros de un reto activo.
  - Verificar logs en consola: `[Sync] onTrainingSaved ...`.
  - Verificar que el `score` del participante aumenta.
  - Verificar que `lastUpdatedAt` se actualiza.
  - Si cumple el objetivo, verificar que aparece el chip "Objetivo Logrado" ✅ en la lista y detalle.

## 4. Ranking y Desempate
- [ ] **Leaderboard**:
  - Con Usuario A y Usuario B participando.
  - Simular scores diferentes. Verificar orden correcto (Descendente para distancia, Ascendente para pace).
  - Simular empate en score:
    - Verificar que desempata por `earliestCompletion` (quien logró el objetivo antes). (Requiere simular fechas de entreno).
    - O desempata por `earliestJoin`.

## 5. Cierre y Recompensas (Simulación)
*Nota: Para testear esto, puede requerir modificar temporalmente la fecha del sistema o editar la fecha `endAt` del reto en Firestore.*

- [ ] **Finalización**:
  - Hacer que un reto expire (`now > endAt`).
  - Abrir la pantalla de Grupo.
  - Verificar warning/log de finalización.
  - El reto debe pasar a estado `finished`.
- [ ] **Distribución de Premios**:
  - **Medallas**: Verificar que el TOP 3 (con score > 0) recibe documentos en `medals` y `medal_history`.
  - **Badges**: Verificar que quienes cumplieron el objetivo reciben `badge` "goalCompleted" y entrada en `badge_history`.
- [ ] **Flags**:
  - Verificar que el reto queda marcado con `medalsAwarded: true` y `badgesAwarded: true`.

## 6. UI de Recompensas
- [ ] **Pantalla Recompensas**:
  - Verificar Tab "Medallero": Suma correcta de Oro/Plata/Bronce.
  - Verificar Tab "Logros": Conteo correcto de badges.
  - Verificar Tab "Historial": Lista cronológica de eventos.
- [ ] **Navegación**:
  - Botón copa 🏆 en AppBar funciona.
  - Clic en reto finalizado lleva a detalle congelado (ranking final).

## 7. Seguridad (Firestore Rules)
- [ ] **Prueba negativa de escritura**:
  - Intentar editar el score de otro usuario (vía código temporal o simulador). Debe fallar.
  - Intentar cerrar un reto sin ser miembro. Debe fallar.
