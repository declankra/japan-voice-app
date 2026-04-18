# Japan Voice App v1 Implementation Plan

## v1 goal

v1 should prove the wedge from [docs/vision.md](./vision.md): a traveler can place the phone flat between two people, keep one thumb near the center waveform, and hold a live EN⇄JA conversation that feels more continuous and less awkward than Google Translate conversation mode. The implementation sequence below is biased toward that physical interaction model first, then a real worker/bootstrap contract, then the live Realtime path, and only then benchmark proof and observability.

## Sequencing rationale

Phase 1 comes first because the top/bottom teleprompter shell, rotated far side, swipe handoff, and center waveform control are the product wedge; the current scaffold is visibly wrong there, so realtime work would only hide UI drift behind transport bugs. Phase 2 hardens the worker/bootstrap contract before any audio work so contract drift, auth mistakes, timeout behavior, and stale-task bugs are solved in isolation. Phase 3 then extends the existing `RealtimeService` seam directly, without adding new provider layers, and lands the OpenAI Realtime WebSocket plus interruption/reconnect behavior. Phase 4 only starts once the live pipeline exists, because the benchmark phrases and structured logs are meaningful only against a real session. For handoff, this plan follows the locked top/bottom layout in [docs/designs/v1-shell.md](./designs/v1-shell.md): a valid handoff swipe moves toward the opposite end of the phone, which means downward on the flipped top pane and upward on the bottom pane.

## Biggest risks / unknowns

- **OpenAI Realtime JA accuracy vs the benchmark set.** The app only earns its place if it clears the fixed travel phrases in [docs/benchmark-phrases.md](./benchmark-phrases.md); if it misses intent or politeness too often, v1 is blocked even if the transport works.
- **Ephemeral-token contract drift.** The current scaffold invents `/ws-token`; the current official Realtime flow is `POST /v1/realtime/client_secrets`, which returns a client secret plus session object. The app/worker contract must mirror that instead of normalizing it into another made-up shape.
- **WebSocket robustness on mobile travel networks.** OpenAI’s current docs recommend WebRTC for client-like environments, but the locked v1 plan is WebSocket. That makes on-device reconnect behavior, socket close handling, and network drop recovery a real execution risk.
- **`AVAudioSession` interruption and background edges.** Phone calls, Control Center, screen lock, and app backgrounding can suspend capture and tear down the socket in different orders. The state machine needs one deterministic answer instead of ad hoc fixes.
- **Zero-retention semantics in the current Realtime API.** The current docs expose `tracing: null` and truncation controls, but they do not advertise a simple `store: false` field on Realtime sessions. Phase 3 must confirm the exact no-retention knobs available at implementation time and document any unavoidable limitation before sign-off.

## Visual reference

Use [docs/designs/v1-shell.md](./designs/v1-shell.md) as the source of truth, with the shell below as the concrete layout reference for Phase 1:

```text
┌──────────────────────────────────────┐
│  Partner half (rendered rotated 180°)│
│  Bold translated text surface        │
│  Swipe down to hand off              │
├───────────────◉──────────────────────┤
│  Center waveform: tap pause/resume   │
│  Hold 1.5s to end, release cancels   │
├──────────────────────────────────────┤
│  Local half                          │
│  Lighter listening / capture surface │
│  Swipe up to hand off                │
└──────────────────────────────────────┘
```

## File ownership

| File | Responsibility in v1 | Phase 1 | Phase 2 | Phase 3 | Phase 4 |
| --- | --- | --- | --- | --- | --- |
| `ios/JapanVoiceApp/App/AppState.swift` | App/session coordinator, bootstrap gating, UI state mapping, reconnect lifecycle | Update | Primary | Primary | Update |
| `ios/JapanVoiceApp/App/JapanVoiceAppApp.swift` | Root scene and foreground/background hooks | Reference | Reference | Update | Reference |
| `ios/JapanVoiceApp/Features/Home/HomeScreen.swift` | Launch shell and centered waveform entry affordance | Primary | Reference | Reference | Polish |
| `ios/JapanVoiceApp/Features/Conversation/ConversationScreen.swift` | Top/bottom teleprompter UI, swipe/tap handoff, center waveform behavior, failure copy | Primary | Update | Primary | Polish |
| `ios/JapanVoiceApp/Models/ConversationSession.swift` | Active speaker, direction labels, transcript/status state, reconnect/error display state | Update | Update | Primary | Update |
| `ios/JapanVoiceApp/Design/AppTheme.swift` | Active/inactive color tokens and contrast rules | Primary | Reference | Reference | Polish |
| `ios/JapanVoiceApp/Services/WorkerClient.swift` | Worker request auth, timeout, decode/validation, bootstrap error taxonomy | Reference | Primary | Update | Update |
| `ios/JapanVoiceApp/Services/RealtimeService.swift` | The one allowed realtime seam; extend it rather than splitting providers | Reference | Reference | Primary | Reference |
| `ios/JapanVoiceApp/Services/OpenAIRealtimeService.swift` | Concrete Realtime WebSocket + audio capture implementation | New | - | Primary | Update |
| `ios/project.yml` | Info.plist settings and any project-level settings needed for microphone access | Reference | Reference | Update | Reference |
| `worker/src/index.ts` | `/health`, `/ws-token`, shared-secret auth, OpenAI client-secret minting, worker logging | Reference | Primary | Update | Update |
| `worker/wrangler.jsonc` | Worker model default and secret/env contract notes | Reference | Update | Reference | Reference |
| `worker/.env.example` | Local worker env contract, including app secret | Reference | Update | Reference | Reference |
| `docs/benchmark-phrases.md` | Fixed acceptance dataset for realtime JA quality | Reference | Reference | Reference | Primary input |
| `docs/benchmark-results/<date>-v1.md` | Logged benchmark results and pass/fail notes | - | - | - | New |

## Verification loop

| Phase | Build / run locally | What can be tested before simulator audio works | Manual pass gate |
| --- | --- | --- | --- |
| Phase 1 | `cd ios && xcodegen generate && xcodebuild -project JapanVoiceApp.xcodeproj -scheme JapanVoiceApp -destination 'platform=iOS Simulator,name=iPhone 16' build` | Everything in this phase; the worker can stay stubbed and `NoopRealtimeService` stays in place. | The shell matches the top/bottom design, swipe and tap fallback work, the center waveform pauses and ends correctly, and accessibility labels read clearly. |
| Phase 2 | `cd worker && npm run typecheck`; `cd worker && npm run dev`; `curl` `/health` and `/ws-token`; rebuild iOS app with the same `xcodebuild` command | All worker/auth/timeout/error mapping work can be verified without live mic audio. | The worker rejects bad secrets, returns a real client-secret response for good ones, and the app surfaces each failure mode as the intended UI state. |
| Phase 3 | Run the Phase 2 worker, then build/run the app on a microphone-capable target; if the simulator mic path is still blocked, use a physical iPhone instead of inventing a second mock pipeline. | Only shell/state portions are testable without live audio. Full phase sign-off requires real speech input. | Live EN⇄JA text appears on the opposite pane, reconnect behaves as specified, and background/interruption handling follows the chosen policy without stale-state bugs. |
| Phase 4 | Repeat Phase 3 run conditions, plus `wrangler tail` during sessions and a dated benchmark-results write-up in `docs/benchmark-results/` | None of the benchmark and observability checks are meaningful without the live pipeline. | All ten phrase pairs are exercised both directions, logs correlate by `sessionId`, and the v1 pass bar is met or the blocker is explicitly recorded. |

## Phase 1 — Shell correctness

**Goal:** Make the iOS shell match the v1 physical interaction model while keeping the realtime layer stubbed behind `NoopRealtimeService`.

### Tasks

1. Rebuild the conversation surface into a top/bottom split aligned to the phone’s long axis, with the far half rendered 180° rotated, mirrored alignment/padding, and active/inactive styling corrected so the listening side is lighter and the translated-output side is bolder.
   Files: `ios/JapanVoiceApp/Features/Conversation/ConversationScreen.swift`, `ios/JapanVoiceApp/Design/AppTheme.swift`, `ios/JapanVoiceApp/Models/ConversationSession.swift`.

2. Replace tap-to-select lane switching with an explicit handoff contract: the active speaker swipes toward the opposite end of the phone; the gesture succeeds only after crossing a distance threshold of **40% of that pane’s height**; releasing below threshold cancels; reversing direction cancels; swipes during `.bootstrapping` are ignored and show a short “Connecting…” hint; if both sides complete a qualifying swipe, the **last completed swipe wins**.
   Files: `ios/JapanVoiceApp/Features/Conversation/ConversationScreen.swift`, `ios/JapanVoiceApp/App/AppState.swift`, `ios/JapanVoiceApp/Models/ConversationSession.swift`.

3. Add the accessibility fallback for handoff: tapping either pane flips direction without dragging, and VoiceOver exposes each half as a labeled button-like target with clear speaker/direction copy.
   Files: `ios/JapanVoiceApp/Features/Conversation/ConversationScreen.swift`, `ios/JapanVoiceApp/App/AppState.swift`.

4. Replace the current pause button plus separate “End Conversation” button with one center waveform control: tap toggles pause/resume; press-and-hold for **1.5 seconds** grows a visible ring and ends the conversation; releasing early or dragging off the control cancels the exit; the same control stays in the same physical center position when entering from `HomeScreen`.
   Files: `ios/JapanVoiceApp/Features/Home/HomeScreen.swift`, `ios/JapanVoiceApp/Features/Conversation/ConversationScreen.swift`, `ios/JapanVoiceApp/App/AppState.swift`.

5. Raise the accessibility floor for the shell: Dynamic Type must keep the title/status copy readable without clipping, hit targets must remain reachable, and the swipe affordance must be visible on first use through a small chevron plus hint text that disappears after the first successful handoff.
   Files: `ios/JapanVoiceApp/Features/Home/HomeScreen.swift`, `ios/JapanVoiceApp/Features/Conversation/ConversationScreen.swift`.

6. Keep the shell honest about its current stage: `NoopRealtimeService` stays in place, and shell status copy must say the session is UI-only until the live transport arrives so manual QA cannot mistake the stub for real translation.
   Files: `ios/JapanVoiceApp/App/AppState.swift`, `ios/JapanVoiceApp/Models/ConversationSession.swift`, `ios/JapanVoiceApp/Services/RealtimeService.swift`.

### Acceptance criteria

| Check | How to verify |
| --- | --- |
| Top/bottom layout is correct | Launch the app in the simulator; the conversation surface is vertically split, the top half is visibly rotated 180°, and the visual hierarchy matches the design sketch. |
| Handoff behavior is fully specified in the shell | On the simulator, drag upward on the bottom pane and downward on the top pane; only drags that cross roughly 40% of the pane height flip direction, while short or reversed drags cancel. |
| Tap fallback exists | With VoiceOver on, double-tap either pane and confirm the active speaker flips without a drag gesture. |
| Center control behavior is unambiguous | Tap the waveform to toggle paused/ready visuals; hold for 1.5 seconds to return home; release early and confirm the session stays open. |
| Accessibility floor is met | Increase Dynamic Type to a large accessibility size and enable VoiceOver; labels still read clearly, hint text remains understandable, and the shell stays usable. |

### Out of scope for this phase

- Real worker auth or OpenAI client-secret minting.
- Real WebSocket/audio capture or transcript streaming.
- Reconnect/backoff, interruption handling, or benchmark execution.

## Phase 2 — Worker + bootstrap contract

**Goal:** Replace the fabricated worker bootstrap with the real authenticated OpenAI Realtime client-secret flow and map every bootstrap failure into a deterministic app state.

### Tasks

1. Replace the stub `/ws-token` payload with the current official Realtime client-secret contract by having the worker call `POST /v1/realtime/client_secrets` and return the fields the app needs from that response instead of today’s invented `ephemeralToken` payload.
   Files: `worker/src/index.ts`, `ios/JapanVoiceApp/Services/WorkerClient.swift`, `ios/JapanVoiceApp/Models/ConversationSession.swift`.

2. Add the v1 shared-secret gate on every worker request: the app sends `X-App-Secret`, the worker compares it against a Cloudflare secret, and unauthenticated calls fail with HTTP 401.
   Files: `ios/JapanVoiceApp/App/AppState.swift`, `ios/JapanVoiceApp/Services/WorkerClient.swift`, `worker/src/index.ts`, `worker/wrangler.jsonc`, `worker/.env.example`.

3. Harden `WorkerClient.fetchRealtimeBootstrap()` for real failures: set the request timeout to about **5 seconds**, rescue `DecodingError` by name, reject empty client-secret/session/model values after decode, and classify worker failures into named cases instead of generic `localizedDescription`.
   Files: `ios/JapanVoiceApp/Services/WorkerClient.swift`.

4. Wire explicit error-to-UI mapping in `AppState`: at minimum, map `401` to “app/worker secret mismatch,” timeout or offline to “worker unreachable,” decode/shape mismatch to “bootstrap contract drift,” and 5xx to “worker failed.” Keep these as user-facing states rather than raw transport strings.
   Files: `ios/JapanVoiceApp/App/AppState.swift`, `ios/JapanVoiceApp/Models/ConversationSession.swift`, `ios/JapanVoiceApp/Features/Conversation/ConversationScreen.swift`, `ios/JapanVoiceApp/Features/Home/HomeScreen.swift`.

5. Fix the current stale-task hazards in bootstrap orchestration: ignore repeated `startConversation()` calls while `.bootstrapping` or `.ready`, and cancel the in-flight bootstrap task inside `endConversation()` so a late worker response cannot mutate a finished session.
   Files: `ios/JapanVoiceApp/App/AppState.swift`.

6. Add minimal worker-side logging for contract verification: log request path, auth outcome, and issued `session.id` so Phase 2 smoke tests and later `wrangler tail` sessions have correlated identifiers from the start.
   Files: `worker/src/index.ts`.

### Acceptance criteria

| Check | How to verify |
| --- | --- |
| Shared-secret auth works | Run `curl -i -X POST http://127.0.0.1:8787/ws-token` with no header or a bad header and confirm `401`; repeat with the correct `X-App-Secret` and confirm `200`. |
| Worker returns a real client-secret response | With a valid header and valid worker secrets, `/ws-token` returns non-empty client-secret data plus a non-empty Realtime session id/model rather than the current stub fields. |
| Error states are specific | Stop the worker, break the secret, and intentionally return malformed JSON once; the app shows three different, named states instead of a generic failure string. |
| Bootstrap is race-safe | Start a conversation and end it immediately while the worker is delayed; the app remains on the home screen and ignores the late worker response. |
| Start is debounced | Tap “Start Conversation” rapidly several times and confirm only one bootstrap request is issued. |

### Out of scope for this phase

- Opening the Realtime WebSocket or sending microphone audio.
- Reconnect/backoff after socket failures.
- Stronger auth than the v1 shared-secret header.

## Phase 3 — Realtime pipeline

**Goal:** Land one working OpenAI Realtime text-only conversation path over WebSocket using the existing `RealtimeService` seam, with deterministic reconnect and interruption handling.

### Tasks

1. Extend the existing `RealtimeService` protocol directly with the minimum additional surface the app needs for transcript delivery and lifecycle events; do **not** split it into separate transcription/translation provider abstractions.
   Files: `ios/JapanVoiceApp/Services/RealtimeService.swift`, `ios/JapanVoiceApp/App/AppState.swift`, `ios/JapanVoiceApp/Models/ConversationSession.swift`.

2. Add a concrete `OpenAIRealtimeService` that owns `AVAudioSession`, `AVAudioEngine`, and the Realtime WebSocket connection, authenticated with the client secret returned in Phase 2.
   Files: `ios/JapanVoiceApp/Services/OpenAIRealtimeService.swift`, `ios/JapanVoiceApp/Services/RealtimeService.swift`, `ios/project.yml`.

3. On connection, send the v1 session configuration: `output_modalities: ["text"]`, interpreter instructions that auto-detect English vs Japanese and translate into the opposite language, and the current no-retention/no-tracing settings supported by the Realtime API at implementation time.
   Files: `ios/JapanVoiceApp/Services/OpenAIRealtimeService.swift`, `worker/src/index.ts`.

4. Pipe transcript deltas into the existing UI: the active speaker half remains the lighter listening surface, the opposite half shows the live translated text, and final transcript updates replace intermediate text without jitter or duplicated lines.
   Files: `ios/JapanVoiceApp/App/AppState.swift`, `ios/JapanVoiceApp/Models/ConversationSession.swift`, `ios/JapanVoiceApp/Features/Conversation/ConversationScreen.swift`.

5. Add the missing connection state and backoff flow: `.reconnecting` appears after recoverable socket loss, retries happen with delays of **0.5s, 1s, 2s, 4s, then 10s**, and the app transitions to `.failed` after **5 unsuccessful retries**. While reconnecting, the UI shows brief, non-alarmist copy near the center control.
   Files: `ios/JapanVoiceApp/Models/ConversationSession.swift`, `ios/JapanVoiceApp/App/AppState.swift`, `ios/JapanVoiceApp/Services/OpenAIRealtimeService.swift`, `ios/JapanVoiceApp/Features/Conversation/ConversationScreen.swift`.

6. Choose and implement the background/interruption policy: **auto-pause on background, tear down the socket cleanly, then reconnect on foreground**. This is the best v1 compromise because it preserves the conversation wedge across short interruptions without pretending background audio is reliable. For `AVAudioSession.interruptionNotification`, `.began` pauses immediately; `.ended` attempts resume/reconnect when the system says resume is allowed; otherwise the session remains paused until the user taps the waveform.
   Files: `ios/JapanVoiceApp/App/JapanVoiceAppApp.swift`, `ios/JapanVoiceApp/App/AppState.swift`, `ios/JapanVoiceApp/Services/OpenAIRealtimeService.swift`, `ios/JapanVoiceApp/Features/Conversation/ConversationScreen.swift`.

7. Keep the gesture edge cases deterministic while audio is live: swipes during `.bootstrapping` stay ignored, swipes during `.reconnecting` are ignored with “Reconnecting…” copy, and simultaneous qualifying swipes still resolve as last completed wins.
   Files: `ios/JapanVoiceApp/App/AppState.swift`, `ios/JapanVoiceApp/Features/Conversation/ConversationScreen.swift`.

### Acceptance criteria

| Check | How to verify |
| --- | --- |
| Live text-only Realtime session works | On a microphone-capable device, start a conversation and speak English, then Japanese; text streams onto the opposite pane in the correct direction and no audio reply is played. |
| Existing seam was extended, not replaced | The implementation still centers on `RealtimeService` plus one concrete `OpenAIRealtimeService`; there is no new `TranscriptionProvider` / `TranslationProvider` split in v1. |
| Reconnect behavior is deterministic | While a session is active, disable network or kill the socket; the UI enters `.reconnecting`, retries on the required schedule, then recovers or transitions to `.failed` after the fifth miss. |
| Background/interruption policy is stable | Background the app or trigger an audio interruption; capture pauses, the app does not crash, and returning to the foreground resumes by reconnecting rather than forcing a full restart. |
| Gesture rules still hold during live sessions | While the session is ready, swipe handoff still works; while bootstrapping or reconnecting, swipes are ignored with explicit status copy. |

### Out of scope for this phase

- Benchmark pass/fail scoring.
- Provider swaps or on-device fallback STT.
- TTS or simultaneous two-way speech.

## Phase 4 — Benchmark & polish

**Goal:** Prove that the live build clears the fixed travel benchmark and add enough structured logging to diagnose failures across iOS and the worker.

### Tasks

1. Add structured OSLog at the required lifecycle points: `startConversation`, bootstrap request start/end, pause/resume, end, swipe handoff, WebSocket open/close/error, reconnect attempt, reconnect success/failure, and interruption/background transitions. Every log line must include the Realtime `session.id` from Phase 2 so device logs and `wrangler tail` can be correlated.
   Files: `ios/JapanVoiceApp/App/AppState.swift`, `ios/JapanVoiceApp/Services/WorkerClient.swift`, `ios/JapanVoiceApp/Services/OpenAIRealtimeService.swift`, `worker/src/index.ts`.

2. Create a dated benchmark result file under `docs/benchmark-results/` and run all ten phrases from [docs/benchmark-phrases.md](./benchmark-phrases.md) in both directions, recording translation quality, first-delta latency, and any STT or interruption failures.
   Files: `docs/benchmark-phrases.md`, `docs/benchmark-results/<date>-v1.md`.

3. Use an explicit ship bar for v1: **at least 8/10 phrases must translate cleanly in both directions**, first text delta must arrive in **under 1.5 seconds** for passing runs, and the session must survive at least one forced reconnect plus one interruption scenario without crashing or leaving stale UI state.
   Files: `docs/benchmark-results/<date>-v1.md`.

4. Run one final polish pass on state copy and gesture affordances so the app communicates the right thing in all non-happy paths: offline, bad app secret, worker drift, reconnecting, paused after interruption, and hard failure after retry exhaustion.
   Files: `ios/JapanVoiceApp/Features/Home/HomeScreen.swift`, `ios/JapanVoiceApp/Features/Conversation/ConversationScreen.swift`, `ios/JapanVoiceApp/App/AppState.swift`.

5. If the benchmark bar is missed, record the blocker honestly and stop. Do not “polish around” poor JA accuracy; Phase 4 only passes if the benchmark says the Realtime path is good enough for travel phrases.
   Files: `docs/benchmark-results/<date>-v1.md`.

### Acceptance criteria

| Check | How to verify |
| --- | --- |
| Logs correlate across client and worker | Run a live session with `wrangler tail` active and inspect device logs; both sides emit the same `session.id` at lifecycle checkpoints. |
| Benchmark results are written down | `docs/benchmark-results/` contains a dated result file with all 10 phrase pairs, both directions, latency notes, and any misses called out. |
| v1 pass bar is explicit and enforced | The results file says whether the build met the `>=8/10 both directions` and `<1.5s first delta` bar; if not, the file names the failure and next step instead of claiming success. |
| Final state copy is polished | Manually trigger each non-happy path and confirm the UI speaks in specific, calm language rather than generic transport errors. |

### Out of scope for this phase

- Switching away from OpenAI Realtime if the benchmark fails; that becomes the next plan.
- Battery budgeting, sunlight readability work, or on-device fallback.
- App Store prep, analytics, auth, or persistence.
