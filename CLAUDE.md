# Japan Voice App Repo Guide

## Read first

Before planning or implementing anything, read:

- `docs/vision.md`
- `docs/architecture.md`
- `docs/implementation-plan-prompt.md` when the task is to produce the implementation plan

## Purpose

This repo is a lean v1 scaffold for the Japan Voice App:

- a native `SwiftUI` iPhone app in `ios/`
- a small stateless Cloudflare Worker in `worker/`

The app will eventually request a short-lived realtime bootstrap from the worker, then connect directly to OpenAI Realtime. The worker exists to keep upstream secrets off-device and to mint ephemeral session credentials later.

## Repo layout

- `ios/project.yml`: XcodeGen spec used to regenerate the Xcode project
- `ios/JapanVoiceApp.xcodeproj`: generated iPhone app project
- `ios/JapanVoiceApp/App/`: app entry, root view switching, and session/app state
- `ios/JapanVoiceApp/Features/`: screen-level SwiftUI views
- `ios/JapanVoiceApp/Services/`: worker bootstrap client and realtime service seam
- `ios/JapanVoiceApp/Models/`: small shared app models
- `ios/JapanVoiceApp/Design/`: lightweight visual tokens
- `worker/src/index.ts`: Cloudflare Worker entry point
- `worker/wrangler.jsonc`: Wrangler config
- `worker/.env.example`: example env contract for local setup

## Key files

| File | Purpose |
| --- | --- |
| `ios/JapanVoiceApp/App/JapanVoiceAppApp.swift` | App entry point that injects shared app state |
| `ios/JapanVoiceApp/App/AppState.swift` | Minimal session/app coordinator for screen state and worker bootstrap |
| `ios/JapanVoiceApp/Features/Home/HomeScreen.swift` | Placeholder launch screen for starting a conversation |
| `ios/JapanVoiceApp/Features/Conversation/ConversationScreen.swift` | Split-screen conversation stub with swipe-based speaker handoff controls |
| `ios/JapanVoiceApp/Services/WorkerClient.swift` | Small client for the worker bootstrap endpoints |
| `ios/JapanVoiceApp/Services/RealtimeService.swift` | Protocol seam for future OpenAI Realtime integration |
| `worker/src/index.ts` | Minimal worker with `/health` and `/ws-token` placeholder routes |

## Integration shape

1. The app starts on `HomeScreen`.
2. Starting a conversation creates placeholder session state and calls the worker.
3. The worker returns stub realtime bootstrap data from `/ws-token`.
4. The app stores that bootstrap response and hands it to a no-op realtime service for now.

That keeps the UI and service seams ready for the next agent without prematurely building audio or translation logic.

## Guardrails

- Keep this repo lean.
- Do not add auth, analytics, billing, or database setup unless explicitly requested.
- Do not put provider secrets in the app.
- Prefer extending the existing seams over introducing new abstraction layers.

## Common commands

```bash
open ios/JapanVoiceApp.xcodeproj
```

```bash
cd ios && xcodegen generate
```

```bash
cd worker && npm install && npm run dev
```
