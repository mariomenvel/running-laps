import { onCall, HttpsError } from "firebase-functions/v2/https";
import { defineSecret } from "firebase-functions/params";
import { logger } from "firebase-functions";

const openRouterApiKey = defineSecret("OPENROUTER_API_KEY");

interface ChatMessage {
  role: string;
  content: string;
}

interface CallOpenRouterRequest {
  model: string;
  messages: ChatMessage[];
  jsonSchema: Record<string, unknown>;
  temperature?: number;
  schemaName?: string;
}

interface CallOpenRouterResponse {
  content: string;
  model: string | null;
  raw: Record<string, unknown>;
}

const MAX_PAYLOAD_CHARS = 200_000;

export const callOpenRouter = onCall(
  { secrets: [openRouterApiKey], timeoutSeconds: 60, memory: "256MiB" },
  async (request): Promise<CallOpenRouterResponse> => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Debes iniciar sesión.");
    }

    const data = request.data as Partial<CallOpenRouterRequest>;

    if (typeof data.model !== "string" || !data.model.trim()) {
      throw new HttpsError("invalid-argument", "Falta 'model'.");
    }
    if (!Array.isArray(data.messages) || data.messages.length === 0) {
      throw new HttpsError("invalid-argument", "Falta 'messages'.");
    }
    if (typeof data.jsonSchema !== "object" || data.jsonSchema === null) {
      throw new HttpsError("invalid-argument", "Falta 'jsonSchema'.");
    }

    const messages: ChatMessage[] = data.messages.map((m) => ({
      role: String((m as unknown as Record<string, unknown>).role ?? ""),
      content: String((m as unknown as Record<string, unknown>).content ?? ""),
    }));

    const totalChars =
      messages.reduce((acc, m) => acc + m.content.length, 0) +
      JSON.stringify(data.jsonSchema).length;
    if (totalChars > MAX_PAYLOAD_CHARS) {
      throw new HttpsError("invalid-argument", "El contexto enviado es demasiado grande.");
    }

    const temperature = typeof data.temperature === "number" ? data.temperature : 0.3;
    const schemaName =
      typeof data.schemaName === "string" && data.schemaName.trim()
        ? data.schemaName
        : "ai_coach_weekly_plan";

    const payload = {
      model: data.model,
      temperature,
      messages,
      response_format: {
        type: "json_schema",
        json_schema: {
          name: schemaName,
          strict: true,
          schema: data.jsonSchema,
        },
      },
    };

    let response: Response;
    try {
      response = await fetch("https://openrouter.ai/api/v1/chat/completions", {
        method: "POST",
        headers: {
          Authorization: `Bearer ${openRouterApiKey.value()}`,
          "Content-Type": "application/json",
          "HTTP-Referer": "https://runninglaps.app",
          "X-Title": "Running Laps",
        },
        body: JSON.stringify(payload),
      });
    } catch (e) {
      logger.error("[callOpenRouter] network error", e);
      throw new HttpsError("unavailable", "No se pudo conectar con OpenRouter.");
    }

    const rawText = await response.text();

    if (!response.ok) {
      logger.error("[callOpenRouter] OpenRouter error", {
        status: response.status,
        body: rawText,
      });
      let message = `OpenRouter error ${response.status}`;
      try {
        const decoded = JSON.parse(rawText);
        const errMsg = decoded?.error?.message;
        if (typeof errMsg === "string" && errMsg.trim()) {
          message = `OpenRouter error ${response.status}: ${errMsg}`;
        }
      } catch {
        // ignore
      }
      throw new HttpsError("internal", message);
    }

    let decoded: Record<string, unknown>;
    try {
      decoded = JSON.parse(rawText);
    } catch {
      throw new HttpsError("internal", "Respuesta de OpenRouter no es JSON válido.");
    }

    const choices = Array.isArray(decoded.choices) ? decoded.choices : [];
    if (choices.length === 0) {
      throw new HttpsError("internal", "OpenRouter sin choices.");
    }

    const firstChoice = choices[0] as Record<string, unknown>;
    const messageOut = (firstChoice.message ?? {}) as Record<string, unknown>;
    const contentValue = messageOut.content;

    let content: string;
    if (typeof contentValue === "string") {
      content = contentValue;
    } else if (Array.isArray(contentValue)) {
      content = contentValue
        .map((item) =>
          item && typeof item === "object"
            ? String((item as Record<string, unknown>).text ?? "")
            : ""
        )
        .join("");
    } else {
      content = "";
    }

    if (!content.trim()) {
      throw new HttpsError("internal", "OpenRouter devolvió contenido vacío.");
    }

    logger.info("[callOpenRouter] success", {
      uid: request.auth.uid,
      model: decoded.model ?? data.model,
      schemaName,
      contentLength: content.length,
    });

    return {
      content,
      model: typeof decoded.model === "string" ? decoded.model : null,
      raw: decoded,
    };
  }
);
