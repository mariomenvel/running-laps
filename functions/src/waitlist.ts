import { onRequest } from "firebase-functions/v2/https";
import { getFirestore, FieldValue } from "firebase-admin/firestore";

const EMAIL_RE = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

export const joinWaitlist = onRequest(
  { cors: true },
  async (req, res) => {
    if (req.method !== "POST") {
      res.status(405).json({ error: "Method not allowed" });
      return;
    }

    const email = String(req.body?.email ?? "").trim().toLowerCase();

    if (!EMAIL_RE.test(email) || email.length > 200) {
      res.status(400).json({ error: "Email inválido" });
      return;
    }

    // Plataforma declarada en la landing (para priorizar testers Android en la
    // prueba cerrada de Google Play). Solo se aceptan valores conocidos.
    const rawPlatform = String(req.body?.platform ?? "").trim().toLowerCase();
    const platform =
      rawPlatform === "android" || rawPlatform === "ios" ? rawPlatform : null;

    const db = getFirestore();
    await db.collection("waitlist").doc(email).set(
      {
        email,
        platform,
        createdAt: FieldValue.serverTimestamp(),
        source: "landing",
      },
      { merge: true }
    );

    res.json({ ok: true });
  }
);
