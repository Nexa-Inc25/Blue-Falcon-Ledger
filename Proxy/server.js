// BFC Cloud proxy — holds the Anthropic API key server-side so the app never ships it.
// The iOS app POSTs { system, messages } here; we forward to Claude and return { text }.
//
// Run locally:   ANTHROPIC_API_KEY=sk-... APP_TOKEN=choose-a-token node server.js
// Deploy:        any Node 18+ host (Render, Railway, Fly.io). Set the env vars below.
//
// Env vars:
//   ANTHROPIC_API_KEY  (required)  your Anthropic key
//   APP_TOKEN          (required)  shared token the app sends as Bearer; must match AppConfig
//   MODEL              (optional)  default claude-sonnet-4-6 (use claude-opus-4-8 for max quality)
//   MAX_TOKENS         (optional)  default 2048
//   PORT               (optional)  default 8787

import express from "express";

const {
  ANTHROPIC_API_KEY,
  APP_TOKEN,
  MODEL = "claude-sonnet-4-6",
  MAX_TOKENS = "4096",
  PORT = "8787",
} = process.env;

if (!ANTHROPIC_API_KEY || !APP_TOKEN) {
  console.error("Missing ANTHROPIC_API_KEY or APP_TOKEN env vars. Refusing to start.");
  process.exit(1);
}

const app = express();
app.use(express.json({ limit: "1mb" }));

// --- Simple in-memory per-IP rate limit (throttle abuse of the shared token) ---
const WINDOW_MS = 60_000;
const MAX_PER_WINDOW = 20;
const hits = new Map(); // ip -> { count, resetAt }

function rateLimited(ip) {
  const now = Date.now();
  const rec = hits.get(ip);
  if (!rec || now > rec.resetAt) {
    hits.set(ip, { count: 1, resetAt: now + WINDOW_MS });
    return false;
  }
  rec.count += 1;
  return rec.count > MAX_PER_WINDOW;
}

app.get("/health", (_req, res) => res.json({ ok: true }));

app.post("/v1/chat", async (req, res) => {
  // Auth: shared app token.
  const auth = req.get("authorization") || "";
  if (auth !== `Bearer ${APP_TOKEN}`) {
    return res.status(401).json({ error: "Unauthorized." });
  }

  const ip = req.headers["x-forwarded-for"]?.split(",")[0]?.trim() || req.ip;
  if (rateLimited(ip)) {
    return res.status(429).json({ error: "Slow down — too many requests. Try again in a minute." });
  }

  const { system, messages } = req.body || {};
  if (typeof system !== "string" || !Array.isArray(messages)) {
    return res.status(400).json({ error: "Body must be { system: string, messages: [...] }." });
  }

  // Anthropic takes a top-level system string + user/assistant turns.
  const turns = messages
    .filter((m) => m && typeof m.content === "string")
    .map((m) => ({
      role: m.role === "assistant" ? "assistant" : "user",
      content: m.content,
    }));

  try {
    const upstream = await fetch("https://api.anthropic.com/v1/messages", {
      method: "POST",
      headers: {
        "content-type": "application/json",
        "x-api-key": ANTHROPIC_API_KEY,
        "anthropic-version": "2023-06-01",
      },
      body: JSON.stringify({
        model: MODEL,
        max_tokens: Number(MAX_TOKENS),
        system,
        messages: turns,
      }),
    });

    const data = await upstream.json();
    if (!upstream.ok) {
      const detail = data?.error?.message || "Upstream model error.";
      return res.status(upstream.status).json({ error: detail });
    }

    const text = (data.content || []).map((c) => c.text || "").join("").trim();
    if (!text) return res.status(502).json({ error: "Empty response from model." });

    return res.json({ text });
  } catch (err) {
    console.error("proxy error:", err);
    return res.status(502).json({ error: "Could not reach the model." });
  }
});

app.listen(Number(PORT), () => {
  console.log(`BFC proxy listening on :${PORT} (model ${MODEL})`);
});
