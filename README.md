# Japan Voice

An iPhone-native realtime interpreter for face-to-face conversations in Japan.

Put the phone flat between two people. Each person gets their own half of the screen, rotated toward them, while live English/Japanese translation streams across like a shared teleprompter.

Read the build story: [declankramper.com/writes/japan-voice-app](https://www.declankramper.com/writes/japan-voice-app)

## Purpose

Translation apps are powerful, but they still make real conversations feel like taking turns with a machine. Japan Voice is an experiment in making translation feel more like a shared surface: one phone on the counter, both people reading naturally, no awkward phone-in-face interaction.

## How It Works

- `ios/` is a native SwiftUI iPhone app with the split teleprompter UI, microphone capture, speaker handoff, and Realtime session state.
- `worker/` is a small Cloudflare Worker that keeps the OpenAI API key off-device and mints short-lived Realtime client secrets.
- The iPhone asks the Worker for a bootstrap, then connects directly to OpenAI Realtime for low-latency EN<->JA interpretation.
- A shared secret protects the personal Worker when this repo is public.

## Run It

Requirements: Xcode 16+, XcodeGen, a Cloudflare account, and an OpenAI API key.

```bash
brew install xcodegen
cp ios/Config/Local.xcconfig.example ios/Config/Local.xcconfig
cd ios
xcodegen generate
open JapanVoiceApp.xcodeproj
```

```bash
cd worker
npm install
cp .env.example .dev.vars
npm run dev
```

For a real iPhone, deploy the Worker and point `ios/Config/Local.xcconfig` at the deployed hostname:

```bash
cd worker
npx wrangler secret put OPENAI_API_KEY
npx wrangler secret put APP_SHARED_SECRET
npm run deploy
```

Set `JAPAN_VOICE_WORKER_BASE_HOST` to your `workers.dev` hostname and make `JAPAN_VOICE_APP_SHARED_SECRET` match the Worker secret.

## Vision

The wedge is physical: a phone laid flat between two people, text facing each reader, with live translation that keeps the human moment in the center. v1 proves that interaction. The longer-term goal is a travel companion that feels calm enough for an izakaya counter, a train station question, or a quick conversation with someone you otherwise could not talk to.
