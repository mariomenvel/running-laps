import { onCall, HttpsError } from "firebase-functions/v2/https";
import { getAuth } from "firebase-admin/auth";

export const syncEmailVerified = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Debes iniciar sesión.");
  }

  const uid = request.auth.uid;
  const userRecord = await getAuth().getUser(uid);

  if (!userRecord.emailVerified) {
    return { emailVerified: false };
  }

  await getAuth().setCustomUserClaims(uid, {
    ...(userRecord.customClaims ?? {}),
    email_verified: true,
  });

  return { emailVerified: true };
});
