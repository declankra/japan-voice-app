# Japan Voice App

Lean scaffold for a native iPhone app plus a small Cloudflare Worker companion.

## Product docs

- `docs/vision.md`: current product vision and repo state
- `docs/architecture.md`: locked v1 architecture and interaction model
- `docs/implementation-plan-prompt.md`: handoff prompt for generating the implementation plan

## Structure

- `ios/`: SwiftUI iPhone app scaffold
- `worker/`: TypeScript Cloudflare Worker scaffold

## Local setup

### iOS app

1. Install Xcode 16+.
2. Copy the local config template and fill in your values:

```bash
cp ios/Config/Local.xcconfig.example ios/Config/Local.xcconfig
```

3. Regenerate the Xcode project after pulling this repo version or after changing `ios/project.yml`:

```bash
cd ios
xcodegen generate
```

4. Open the project:

```bash
open ios/JapanVoiceApp.xcodeproj
```

5. Select an iPhone simulator or your physical iPhone and run `JapanVoiceApp`.

`ios/Config/Local.xcconfig` is ignored by git. That file is where you set:
- `APP_BUNDLE_IDENTIFIER`
- `APP_DEVELOPMENT_TEAM`
- `JAPAN_VOICE_WORKER_BASE_URL`
- `JAPAN_VOICE_APP_SHARED_SECRET`

### Worker

1. Install dependencies:

```bash
cd worker
npm install
```

2. Create local env vars:

```bash
cp .env.example .dev.vars
```

3. Put your real values in `worker/.dev.vars`:
- `OPENAI_API_KEY`
- `OPENAI_REALTIME_MODEL`
- `APP_SHARED_SECRET`

The `APP_SHARED_SECRET` in `.dev.vars` must exactly match `JAPAN_VOICE_APP_SHARED_SECRET` in `ios/Config/Local.xcconfig`.

4. Start the worker locally:

```bash
npm run dev
```

5. Type-check the worker:

```bash
npm run typecheck
```

## Real iPhone testing

If you want the app to work on a physical iPhone, the app must talk to a deployed HTTPS worker. `http://127.0.0.1:8787` only works from the simulator running on your Mac.

1. Log into Cloudflare for Wrangler:

```bash
cd worker
npx wrangler login
```

2. Generate a shared secret:

```bash
openssl rand -hex 32
```

3. Set worker secrets in Cloudflare:

```bash
cd worker
npx wrangler secret put OPENAI_API_KEY
npx wrangler secret put APP_SHARED_SECRET
```

4. Deploy the worker:

```bash
cd worker
npm run deploy
```

5. Copy the deployed `https://...workers.dev` URL into `ios/Config/Local.xcconfig` as `JAPAN_VOICE_WORKER_BASE_URL`.
6. Put the same `APP_SHARED_SECRET` value into `ios/Config/Local.xcconfig` as `JAPAN_VOICE_APP_SHARED_SECRET`.
7. Set `APP_DEVELOPMENT_TEAM` to your Apple team ID and `APP_BUNDLE_IDENTIFIER` to an identifier you control.
8. Open `ios/JapanVoiceApp.xcodeproj`, choose your connected iPhone as the run destination, and run the app from Xcode.
9. Accept the microphone permission prompt on first launch.

## Notes

- The app does not store a long-lived OpenAI API key on-device. The worker mints a short-lived Realtime client secret and the phone connects to OpenAI Realtime directly.
- `worker/.env.example` and `ios/Config/Local.xcconfig.example` are safe to commit. Your real secrets belong only in `worker/.dev.vars`, Cloudflare secrets, and your ignored `ios/Config/Local.xcconfig`.

## Current state

- The iOS app captures microphone audio, requests a short-lived Realtime bootstrap from the worker, and connects directly to OpenAI Realtime for live interpretation.
- The worker exposes `/health` and `/ws-token` and mints short-lived OpenAI Realtime client secrets.
- The repo defaults to `gpt-realtime-1.5` for the Realtime model and `gpt-4o-mini-transcribe` for input transcription.
