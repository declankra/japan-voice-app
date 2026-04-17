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
2. Open the project:

```bash
open ios/JapanVoiceApp.xcodeproj
```

3. Select an iPhone simulator and run `JapanVoiceApp`.

If you change `ios/project.yml`, regenerate the project:

```bash
cd ios
xcodegen generate
```

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

3. Start the worker locally:

```bash
npm run dev
```

4. Type-check the worker:

```bash
npm run typecheck
```

## Current state

- The iOS app has placeholder screens, app state, a worker client, and a no-op realtime service.
- The worker exposes `/health` and `/ws-token`.
- Realtime translation, audio capture, and OpenAI token minting are intentionally not implemented yet.
