interface Env {
  OPENAI_API_KEY?: string;
  OPENAI_REALTIME_MODEL?: string;
  APP_SHARED_SECRET?: string;
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

const INTERPRETER_INSTRUCTIONS = [
  "You are the live interpreter for a shared phone screen between an English speaker and a Japanese speaker.",
  "Detect the spoken language for each utterance and translate it into the opposite language only.",
  "Output text only. Do not explain what you are doing. Do not add notes, labels, romaji, or extra commentary.",
  "Keep the translation concise, natural, and polite for in-person travel conversation.",
].join(" ");

function isAuthorized(request: Request, env: Env): boolean {
  const expected = env.APP_SHARED_SECRET?.trim();
  if (!expected) {
    return false;
  }

  const provided = request.headers.get("X-App-Secret")?.trim();
  return provided === expected;
}

async function mintClientSecret(env: Env): Promise<Response> {
  if (!env.OPENAI_API_KEY?.trim()) {
    return json({ error: "OPENAI_API_KEY is not configured." }, { status: 503 });
  }

  const model = env.OPENAI_REALTIME_MODEL?.trim() || "gpt-realtime-1.5";

  const upstream = await fetch("https://api.openai.com/v1/realtime/client_secrets", {
    method: "POST",
    headers: {
      Authorization: `Bearer ${env.OPENAI_API_KEY}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      session: {
        type: "realtime",
        model,
        instructions: INTERPRETER_INSTRUCTIONS,
        output_modalities: ["text"],
        tracing: null,
        audio: {
          input: {
            transcription: {
              model: "gpt-4o-mini-transcribe",
            },
            turn_detection: {
              type: "server_vad",
              create_response: true,
              interrupt_response: true,
              prefix_padding_ms: 300,
              silence_duration_ms: 500,
            },
          },
        },
      },
    }),
  });

  const payload = await upstream.text();

  return new Response(payload, {
    status: upstream.status,
    headers: {
      "content-type": upstream.headers.get("content-type") ?? "application/json; charset=utf-8",
    },
  });
}

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    const url = new URL(request.url);
    const authorized = isAuthorized(request, env);

    console.log(JSON.stringify({
      path: url.pathname,
      method: request.method,
      authorized,
    }));

    if (request.method === "GET" && url.pathname === "/health") {
      return json({
        ok: true,
        service: "japan-voice-worker",
        hasOpenAIKey: Boolean(env.OPENAI_API_KEY),
        hasAppSecret: Boolean(env.APP_SHARED_SECRET),
        model: env.OPENAI_REALTIME_MODEL ?? "gpt-realtime-1.5",
      });
    }

    if (request.method === "POST" && url.pathname === "/ws-token") {
      if (!authorized) {
        return json({ error: "Unauthorized" }, { status: 401 });
      }

      const upstream = await mintClientSecret(env);
      const cloned = upstream.clone();

      try {
        const parsed = await cloned.json<{ session?: { id?: string } }>();
        console.log(JSON.stringify({
          path: url.pathname,
          method: request.method,
          authorized,
          issuedSessionId: parsed.session?.id ?? null,
          status: upstream.status,
        }));
      } catch {
        console.log(JSON.stringify({
          path: url.pathname,
          method: request.method,
          authorized,
          issuedSessionId: null,
          status: upstream.status,
        }));
      }

      return upstream;
    }

    return json({ error: "Not found" }, { status: 404 });
  },
};
