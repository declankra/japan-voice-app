interface Env {
  OPENAI_API_KEY?: string;
  OPENAI_REALTIME_MODEL?: string;
}

function json(data: unknown, init?: ResponseInit): Response {
  return new Response(JSON.stringify(data, null, 2), {
    ...init,
    headers: {
      "content-type": "application/json; charset=utf-8",
      ...init?.headers,
    },
  });
}

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    const url = new URL(request.url);

    if (request.method === "GET" && url.pathname === "/health") {
      return json({
        ok: true,
        service: "japan-voice-worker",
        hasOpenAIKey: Boolean(env.OPENAI_API_KEY),
        model: env.OPENAI_REALTIME_MODEL ?? "gpt-realtime",
      });
    }

    if (request.method === "POST" && url.pathname === "/ws-token") {
      const issuedAt = new Date();
      const expiresAt = new Date(issuedAt.getTime() + 8 * 60 * 1000);

      return json({
        sessionId: crypto.randomUUID(),
        websocketURL: "wss://api.openai.com/v1/realtime",
        model: env.OPENAI_REALTIME_MODEL ?? "gpt-realtime",
        ephemeralToken: "stub-token-replace-in-worker",
        issuedAt: issuedAt.toISOString(),
        expiresAt: expiresAt.toISOString(),
        note: env.OPENAI_API_KEY
          ? "Replace this stub with real ephemeral token minting when realtime implementation starts."
          : "Set OPENAI_API_KEY before wiring real token minting.",
      });
    }

    return json({ error: "Not found" }, { status: 404 });
  },
};
