# BFC Cloud Proxy

A tiny server that holds your Anthropic API key so the BFC app's testers don't need
their own. The app sends `{ system, messages }`; the proxy forwards to Claude and
returns `{ text }`.

## What it does
- `POST /v1/chat` — auth with a shared `APP_TOKEN`, forwards to Claude, returns `{ text }`.
- `GET /health` — returns `{ ok: true }`.
- Per-IP rate limiting (20 req/min) to throttle abuse of the shared token.

## Run locally
```bash
cd Proxy
npm install
ANTHROPIC_API_KEY=sk-ant-... APP_TOKEN=some-long-random-string node server.js
# -> BFC proxy listening on :8787 (model claude-sonnet-4-6)
curl localhost:8787/health
```

## Deploy (pick one host)
Any Node 18+ host works. Set env vars from `.env.example` in the dashboard.

- **Render**: New → Web Service → connect repo (or upload) → Build `npm install`,
  Start `node server.js` → add env vars → deploy. You get an `https://…onrender.com` URL.
- **Railway / Fly.io**: same idea — Node app, `npm start`, set env vars.

After deploy, confirm: `curl https://YOUR-URL/health` → `{"ok":true}`.

## Connect the app
In `BFC/Services/AppConfig.swift` set:
```swift
static let proxyBaseURL = "https://YOUR-URL"   // no trailing slash
static let proxyAppToken = "the same APP_TOKEN you set on the proxy"
```
Rebuild. In the app, Settings → Analysis Brain → **BFC Cloud** should show "connected".

## Model & cost
- Default `MODEL=claude-sonnet-4-6` — good quality, cheaper for a beta.
- For max quality on long contracts, set `MODEL=claude-opus-4-8`.
- You pay Anthropic per token. Watch usage; the rate limit is a basic guard, not billing protection.

## Security notes (read before external beta)
- The `APP_TOKEN` ships inside the app, so a determined user can extract it. It's a
  throttle, not a real secret. Keep rate limiting on, and rotate the token if abused.
- For production, move to per-user auth (e.g. verify a Firebase ID token in the proxy)
  instead of a shared token, and meter usage per account.
- Never commit your real `.env`. Keep `ANTHROPIC_API_KEY` server-side only.
