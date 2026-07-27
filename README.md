# Japan Voice

An iPhone-native realtime interpreter for face-to-face conversations in Japan.

Put the phone flat between two people. Each person gets their own half of the screen, rotated toward them, while live English/Japanese translation streams across like a shared teleprompter.

Read the build story: [declankramper.com/writes/vision](https://www.declankramper.com/writes/vision)

## Purpose

Translation apps are powerful, but they still make real conversations feel like taking turns with a machine. Japan Voice is an experiment in making translation feel more like a shared surface: one phone on the counter, both people reading naturally, no awkward phone-in-face interaction.

## How It Works

- `ios/` is a native SwiftUI iPhone app with the split teleprompter UI, microphone capture, speaker handoff, and Realtime session state.
- `worker/` is a small Cloudflare Worker that keeps the OpenAI API key off-device and mints short-lived Realtime client secrets.
- The iPhone asks the Worker for a bootstrap, then connects directly to OpenAI Realtime for low-latency EN<->JA interpretation.
- A shared secret protects the personal Worker when this repo is public.

## Run It

Requirements: Xcode 16+, XcodeGen, a Cloudflare account, and an OpenAI API key.

Create the local iOS config:

```bash
brew install xcodegen
cp ios/Config/Local.xcconfig.example ios/Config/Local.xcconfig
```

Fill in `ios/Config/Local.xcconfig`:

```xcconfig
APP_BUNDLE_IDENTIFIER = com.yourname.JapanVoiceApp
APP_DEVELOPMENT_TEAM = YOUR_APPLE_TEAM_ID
JAPAN_VOICE_WORKER_BASE_HOST = 127.0.0.1:8787
JAPAN_VOICE_WORKER_BASE_SCHEME = http
JAPAN_VOICE_APP_SHARED_SECRET = replace-with-a-random-shared-secret
```

Use `127.0.0.1:8787` + `http` for simulator testing against local Wrangler. For a physical iPhone, use your deployed `workers.dev` hostname and keep the scheme as `https`.

Generate and open the Xcode project:

```bash
cd ios
xcodegen generate
open JapanVoiceApp.xcodeproj
```

Create the local Worker env:

```bash
cd worker
npm install
cp .env.example .dev.vars
npm run dev
```

Fill in `worker/.dev.vars`:

```dotenv
OPENAI_API_KEY=replace-with-your-openai-api-key
OPENAI_REALTIME_MODEL=gpt-realtime-1.5
APP_SHARED_SECRET=replace-with-the-same-shared-secret
```

`APP_SHARED_SECRET` must match `JAPAN_VOICE_APP_SHARED_SECRET`.

For a real iPhone, deploy the Worker:

```bash
cd worker
npx wrangler login
npx wrangler secret put OPENAI_API_KEY
npx wrangler secret put APP_SHARED_SECRET
npm run deploy
```

`ios/Config/Local.xcconfig` and `worker/.dev.vars` are ignored by git. Keep real secrets there or in Cloudflare secrets, not in the app bundle or committed files.
