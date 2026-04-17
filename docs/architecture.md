---
name: "[[architecture|Japan Voice App - Architecture v1]]"
type: architecture
status: locked
links:
  - "[[_SideProducts/japan-voice-app/vision|vision]]"
---

# Japan Voice App - Architecture

Locked v1 choices for [[vision]].

## Four decisions

1. **Native Swift iPhone app (`SwiftUI`)**
   Reason: this gives the cleanest full-screen experience, the best control over microphone/session state, and the highest chance of making the product feel seamless in-hand.

2. **One personal Cloudflare Worker**
   Reason: the worker keeps the upstream API secret off-device, mints short-lived realtime tokens, and avoids building any real backend. For v1, it is deployed once for personal use and the app points at that worker.

3. **OpenAI Realtime for the first working pipeline**
   Reason: it is the fastest route to a usable realtime translation prototype with the fewest moving parts. We can benchmark other providers later if Japanese accuracy becomes the bottleneck.

4. **One active speaker at a time**
   Reason: this is the cleanest interaction model on one phone. The user taps the side of the current speaker, the translation direction flips (`EN -> JA` or `JA -> EN`), and the opposite side becomes the prominent live output surface.

## How the app will work

- The home screen is minimal and centered around one launch control using the `waveform.circle.fill` visual.
- Tapping that button opens the conversation surface. The button stays in the same physical place and becomes the center waveform/signal control, so the transition feels seamless.
- On the conversation screen, the left and right halves represent the two people. Tapping a side makes that person the active speaker and flips the translation direction.
- The active speaker side becomes lighter and less visually dominant. The opposite side becomes bolder because it is showing the live translated text.
- The center waveform indicates that realtime transcription is running. Tapping it pauses or resumes the live session.
- Holding the center waveform starts an exit action. A ring grows around the button while it is held, and once the ring completes, the conversation ends and the app returns to the home screen. Releasing early cancels the exit.
- No gesture-based enter/exit flow in v1. iPhone reliability and discoverability matter more than cleverness here.

## High-level flow

1. Open app
2. Tap centered waveform button
3. App requests a short-lived realtime token from the Cloudflare Worker
4. App connects to the realtime session
5. User taps the side of the current speaker
6. Audio streams in, translation appears live on the opposite side
7. Center waveform can pause/resume at any time
8. Hold the center waveform until the progress ring completes to end the conversation and return home

## Out of scope for v1

- App Store distribution
- user accounts or auth
- storing raw provider API keys on-device
- simultaneous two-way speech on one phone
- fancy gesture navigation



---


## Reference Architecture

[farzaa/clicky](https://github.com/farzaa/clicky) is the closest public reference implementation for the core infrastructure pattern. It's a macOS AI companion app with:
- A 142-line Cloudflare Worker as a stateless API key proxy
- Short-lived WebSocket token pattern for real-time streaming
- Pluggable transcription provider protocol (AssemblyAI streaming, OpenAI upload, Apple Speech fallback)
- SSE streaming piped directly through the worker with no buffering

The `worker/src/index.ts` and `CLAUDE.md` are the two files worth reading before writing a line of code.

## Architecture Patterns to Apply

- **Cloudflare Worker as the API key proxy.** The iOS app never holds API keys. A ~150-line worker handles auth header injection and routes to upstream APIs. One deploy, free tier covers personal use easily.
- **Short-lived token for the WebSocket.** The translation pipeline is real-time audio → STT → translation → display. The STT leg uses a WebSocket (AssemblyAI, OpenAI Realtime, or similar). The worker issues a short-lived token (~480s); the iOS app opens the WebSocket directly to the STT provider using that token. This keeps latency minimal — no audio proxied through the worker.
- **Pipe streaming responses directly.** For any text responses or TTS, `response.body` is piped directly from upstream to client. No buffering on the worker.
- **Pluggable translation provider.** Abstract the STT and translation layer behind a Swift protocol from the start. Lets you swap Google, OpenAI Realtime, or AssemblyAI + Claude without touching UI code. Aligned with "bet on model improvement without becoming vague."
- **No auth, no accounts, no backend state.** The worker is stateless. No database. No user accounts. The app is a direct client-to-API bridge with a key proxy in the middle.
- **CLAUDE.md first.** Write the architecture doc before writing Swift. Include a key-files table with line counts and purpose for each file. See Clicky's `CLAUDE.md` as the template — it's what makes Claude Code usable in the repo from session one.

## Technical Decisions

- **Native Swift iOS app** — SwiftUI for the split-screen UI, `AVAudioEngine` for mic capture, `AVAudioSession` for speaker routing. Native is the right call for a travel app: hardware access, no browser permissions friction, cleaner on-device latency.
- **Real-time voice API for translation**: Google vs OpenAI? Still open. OpenAI Realtime handles STT + translation in one WebSocket (simpler pipeline). Google has strong Japanese accuracy. Decision: build with pluggable protocol, start with OpenAI Realtime, benchmark against Google.
- **Translation pipeline**: Either STT → Claude for translation in a second call (composable, swappable), or OpenAI Realtime which handles both in one WebSocket (lower latency, less control). Evaluate based on latency in practice.
- **No auth, no accounts** — none of that. Stateless app, stateless worker. User opens it and it works.
- **Cloudflare Worker**: Three routes — `/ws-token` (STT token), `/translate` (optional if using separate LLM for translation), `/tts` (optional if adding voice output later). Start with just `/ws-token`.

## Distribution Tradeoffs

Two realistic end states given the blog post sharing intent:

### Option A: App Store

| Factor | Detail |
|---|---|
| **Keys** | You own one Cloudflare Worker. All users hit your worker. You absorb API costs. |
| **Worker** | One deploy, your secrets, centralized. |
| **Sharing** | Anyone with an iPhone can download it. No setup required. |
| **Monetization** | IAP or one-time purchase possible. Offsets API costs. |
| **Maintenance** | You're responsible for uptime, costs, and key rotation. |
| **App Review** | Apple review process (~1-3 days). Need to handle privacy disclosures for microphone + translation. |
| **Best for** | Widest reach. Best UX for readers who just want to use it. |

### Option B: GitHub — Clone Your Own Keys

| Factor | Detail |
|---|---|
| **Keys** | User deploys their own Cloudflare Worker with their own API keys. |
| **Worker** | Template in the repo. User runs `wrangler deploy` and updates one constant in the app. |
| **Sharing** | Technical audience only. Requires Xcode + Cloudflare account + API keys. |
| **Monetization** | None. |
| **Maintenance** | Near zero for you once shipped. User owns their own infra. |
| **App Review** | None. Sideloaded or built locally. |
| **Best for** | Blog post audience that wants to learn the pattern, not just use the app. |

### What actually changes in the code

The client app code is **identical** in both options. The only difference:
- App Store: `workerURL` is a constant pointing to your deployed worker
- GitHub: `workerURL` is a placeholder the user replaces after running `wrangler deploy`

The worker code is also identical — just who owns the secrets differs. Document a one-command deploy in the README: `npx wrangler deploy`.

### Recommendation

Ship Option B first (GitHub clone), write the blog post. If there's demand from non-technical readers, submit Option A to the App Store. The architecture change is one constant and one deployment.


 also there is a Codex app skill bundle for building iOS apps
