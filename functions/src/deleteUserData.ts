import { onCall, HttpsError } from "firebase-functions/v2/https";
import { getFirestore, FieldValue } from "firebase-admin/firestore";
import { getAuth } from "firebase-admin/auth";

/**
 * Borra TODOS los datos del usuario autenticado y su cuenta de Auth.
 *
 * Orden de borrado (importante):
 *  1. Artefactos en grupos (member doc, participaciones en retos, prefs,
 *     medallas y badges) — se localizan vía users/{uid}/groups ANTES de
 *     borrar el árbol del usuario, porque esa lista desaparece con él.
 *  2. users/{uid} completo con recursiveDelete (incluye trainings, tags,
 *     settings, athleteSessions, templates, savedBlocks, aiCoachEvents,
 *     aiCoachFeedback, result_notifications, groups...).
 *  3. El usuario de Firebase Auth. Si esto fallara, el usuario puede
 *     reintentar: los pasos 1-2 son idempotentes.
 *
 * El cliente exige reautenticación reciente antes de llamar (flujo de UI),
 * pero la función no depende de ello: solo borra los datos del caller.
 */
export const deleteUserData = onCall(
  { timeoutSeconds: 300 },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Debes iniciar sesión.");
    }

    // Misma semántica que requires-recent-login de Firebase Auth:
    // el flujo de UI reautentica justo antes de llamar, así que un token
    // con auth_time viejo indica una llamada fuera del flujo previsto.
    const authTimeSec = Number(request.auth.token.auth_time ?? 0);
    const ageSec = Date.now() / 1000 - authTimeSec;
    if (!authTimeSec || ageSec > 10 * 60) {
      throw new HttpsError(
        "failed-precondition",
        "requires-recent-login",
      );
    }

    const uid = request.auth.uid;
    const db = getFirestore();

    // ── 1. Limpieza de grupos ────────────────────────────────────────────
    const userGroups = await db
      .collection("users").doc(uid)
      .collection("groups")
      .get();

    for (const groupRef of userGroups.docs) {
      const groupId = groupRef.id;
      const group = db.collection("groups").doc(groupId);

      // Participaciones en retos del grupo
      const challenges = await group.collection("challenges").get();
      const batch = db.batch();
      for (const challenge of challenges.docs) {
        batch.delete(challenge.ref.collection("participants").doc(uid));
      }

      // Membresía, prefs, medallas y badges
      batch.delete(group.collection("members").doc(uid));
      batch.delete(group.collection("prefs").doc(uid));
      batch.delete(group.collection("medals").doc(uid));
      batch.delete(group.collection("badges").doc(uid));
      await batch.commit();

      // Contador de miembros (best-effort; el grupo puede haber desaparecido)
      try {
        await group.update({ memberCount: FieldValue.increment(-1) });
      } catch {
        // grupo inexistente o campo ausente — no bloquear el borrado
      }
    }

    // Participaciones en retos globales
    const globalChallenges = await db.collection("global_challenges").get();
    if (!globalChallenges.empty) {
      const batch = db.batch();
      for (const challenge of globalChallenges.docs) {
        batch.delete(challenge.ref.collection("participations").doc(uid));
      }
      await batch.commit();
    }

    // ── 2. Árbol completo del usuario ────────────────────────────────────
    await db.recursiveDelete(db.collection("users").doc(uid));

    // ── 3. Cuenta de Auth ────────────────────────────────────────────────
    await getAuth().deleteUser(uid);

    return { ok: true };
  },
);
