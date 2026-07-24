import { onSchedule } from "firebase-functions/v2/scheduler";
import { getFirestore } from "firebase-admin/firestore";

/**
 * Resetea los contadores de cuota del chat del AI Coach
 * cada lunes a las 00:05 (hora de Madrid, Europe/Madrid).
 * Actualiza periodStart, periodEnd, messagesUsed y
 * previewsGenerated en users/{uid}/settings/aiCoachUsage
 * para todos los usuarios con plan activo.
 */
export const resetWeeklyChatUsage = onSchedule(
  {
    schedule: "5 0 * * 1", // lunes a las 00:05
    timeZone: "Europe/Madrid",
    retryCount: 3,
  },
  async () => {
    const db = getFirestore();

    const now = new Date();

    // Calcular lunes actual (inicio del nuevo periodo)
    const monday = new Date(now);
    monday.setHours(0, 0, 0, 0);
    const day = monday.getDay(); // 0=dom, 1=lun...
    const diff = day === 0 ? -6 : 1 - day;
    monday.setDate(monday.getDate() - diff);

    // Calcular domingo 23:59:59 (fin del periodo)
    const sunday = new Date(monday);
    sunday.setDate(monday.getDate() + 6);
    sunday.setHours(23, 59, 59, 999);

    // Buscar todos los docs aiCoachUsage del plan semanal. No filtramos por
    // messagesUsed > 0: un usuario puede tener messagesUsed == 0 pero
    // previewsGenerated acumulado (contador anti-abuso, límite 10), y también
    // necesita reset. La query por igualdad sobre `plan` la cubre el índice
    // compuesto (plan, messagesUsed) existente por prefijo.
    const usageDocs = await db
      .collectionGroup("settings")
      .where("plan", "==", "athlete_chat_weekly")
      .get();

    if (usageDocs.empty) {
      console.log("[resetChatUsage] No hay docs que resetear");
      return;
    }

    // Reset en batches de 500 (límite de Firestore)
    const BATCH_SIZE = 500;
    let batch = db.batch();
    let count = 0;
    let totalReset = 0;

    for (const doc of usageDocs.docs) {
      batch.update(doc.ref, {
        messagesUsed: 0,
        previewsGenerated: 0,
        // Renormaliza el límite: docs antiguos pueden tener un valor obsoleto
        // (p. ej. 40 de una versión anterior). El límite canónico es 3.
        messagesLimit: 3,
        periodStart: monday,
        periodEnd: sunday,
      });
      count++;
      totalReset++;

      if (count === BATCH_SIZE) {
        await batch.commit();
        batch = db.batch();
        count = 0;
      }
    }

    if (count > 0) {
      await batch.commit();
    }

    console.log(
      `[resetChatUsage] Reset completado: ${totalReset} usuarios`
    );
  }
);
