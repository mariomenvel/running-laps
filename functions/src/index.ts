import { onCall, HttpsError } from "firebase-functions/v2/https";
import { initializeApp } from "firebase-admin/app";

initializeApp();

export { callOpenRouter } from "./openrouter";
export { syncEmailVerified } from "./auth";
export { joinWaitlist } from "./waitlist";
export { resetWeeklyChatUsage } from "./resetChatUsage";

export const ping = onCall((request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Debes iniciar sesión.");
  }
  return {
    message: "pong",
    uid: request.auth.uid,
    timestamp: new Date().toISOString(),
  };
});
