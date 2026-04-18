---
name: "Japan Voice App v1 Shell Design"
type: design
status: active
links:
  - "[[vision]]"
  - "[[architecture]]"
source: /plan-ceo-review (2026-04-17, SELECTIVE EXPANSION)
---

# Japan Voice App — v1 Shell Design

Outcome of a CEO-level review of `vision.md` + `architecture.md` on 2026-04-17. SELECTIVE EXPANSION mode: architecture is locked, scope adjusted per cherry-picked decisions below. This document is the bridge between `vision.md` / `architecture.md` and the implementation plan that will be produced from `docs/implementation-plan-prompt.md`.

## Vision recap

Realtime voice translation for face-to-face conversations with locals in Japan. Split-screen teleprompter, one active speaker at a time, swipe to hand off the translation lane. SwiftUI iPhone app + one personal Cloudflare Worker. OpenAI Realtime (`gpt-realtime`) for v1, with the `RealtimeService` protocol as the swap seam if the provider needs to change.

## Strategic wedge (to be written into `vision.md`)

Google Translate conversation mode is the incumbent baseline: free, Japanese-tuned, partially offline. The missing strategic artifact in `vision.md` is the "why this, not Google Translate" answer. Candidate wedges to articulate:

1. **Realtime continuous vs turn-taking.** No tap-to-speak. Both people can talk without interrupting the tool. Feels like a conversation, not a dictation session.
2. **Teleprompter layout parallel to the ground.** Both parties read comfortably without the phone becoming an interruption in the conversation. The physical orientation is the interaction model.
3. **Travel-context UX.** One-thumb, high-contrast, designed for standing close to a stranger in a noisy space — the izakaya counter, the hostel lobby, the konbini register.

This answer must be written into `vision.md` before the implementation plan is produced, so the plan can be evaluated against a real wedge rather than a vague one.

## Scope decisions

| # | Proposal | Effort (human / CC) | Decision | Reasoning |
|---|----------|---------------------|----------|-----------|
| 1 | Add "Why not Google Translate" section to `vision.md` | 30 min / 5 min | ACCEPTED | Most important strategic artifact. Every v1 decision needs to serve the wedge. Without it written down, the plan cannot be evaluated. |
| 2 | Plan must specify the swipe gesture end-to-end | trivial to require / 10 min to write into the plan | ACCEPTED | Real docs/code drift — `architecture.md` says swipe, `ConversationScreen.swift` uses tap. The plan must pick the swipe answer and hold the implementation accountable. |
| 3 | Lock 5-10 bilingual benchmark phrases in `docs/benchmark-phrases.md` | 20 min / 5 min | ACCEPTED | First time OpenAI Realtime is wired, you need a repeatable yardstick for JA accuracy so "it worked" doesn't become "it worked on what I happened to say." |
| 4 | WebSocket reconnect with exponential backoff + visible "reconnecting…" state | 2-4 hr / 15-30 min | ACCEPTED | Minimum viable travel hardening. Realtime needs a live socket; travel means flaky networks. Skipped in v1: battery budget, sunlight-mode screen brightness. |
| 5 | Split `RealtimeService` into `TranscriptionProvider` + `TranslationProvider` seams | 1 day / 30 min | SKIPPED | Commit to OpenAI Realtime as the primary v1 provider. Current `RealtimeService` protocol is enough for a one-WebSocket model. If Approach B/C becomes necessary post-benchmarks, the protocol split is a v2 refactor we can absorb. |

## Accepted scope (added to v1)

### 1. Write the wedge into `vision.md`

Append a "Why not Google Translate" section with 2-3 of the candidate wedges above. Keep it short — a paragraph per wedge, concrete.

### 2. Plan must specify swipe interaction end-to-end

The implementation plan must answer, explicitly:

- **Gesture:** drag from the active speaker's own side toward the center/opposite side (horizontal drag).
- **Threshold:** distance-based (e.g., 40% of half-screen width) or velocity-based (e.g., flick > 300 pt/s). Pick one; justify.
- **Mid-bootstrap behavior:** what happens if the user swipes while `connectionState == .bootstrapping`? Queue the direction flip? Ignore? Flash an affordance?
- **Cancellation:** release before threshold cancels; opposite-direction swipe cancels; simultaneous swipes on both sides — last one wins, or ignored?
- **Visual affordance:** how does the user know the swipe exists and which direction to swipe? Chevron, handle, edge glow, hint text on first run.

### 3. Benchmark phrases

Create `docs/benchmark-phrases.md` with 5-10 bilingual pairs. Suggested coverage:

- Station directions ("excuse me, where's the bathroom," "how many minutes to walk to the station")
- Restaurant ordering ("what do you recommend," "I'm allergic to shellfish")
- Counter / money ("can I pay by card," "keep the change")
- Small talk ("where are you from," "this is my first time in Japan")
- Emergency / apology ("I'm sorry, I didn't understand," "I need a doctor")

Both directions (EN→JA and JA→EN). This is the v1 acceptance check for whether OpenAI Realtime JA quality is good enough or whether you need to pivot to Approach B.

### 4. WebSocket reconnect hardening

Plan and scaffold must handle WebSocket disconnect:

- Detect socket close (clean or error).
- Reconnect with exponential backoff — 0.5s, 1s, 2s, 4s, cap at 10s. Cap max retries (e.g., 5) before surfacing "lost connection" to the user.
- Introduce a `reconnecting` connection state distinct from `idle` / `bootstrapping` / `ready` / `paused` / `failed`.
- UI surfaces the reconnecting state — non-alarmist, brief text like "reconnecting…" near the center control.
- On successful reconnect, resume the session transparently. On max-retry failure, transition to `failed(...)` and let the user retry from the home screen.

## NOT in scope for v1

- On-device English STT via Apple Speech (Approach C — the "true travel wedge" path). Deferred to v2 if post-benchmark results show OpenAI JA accuracy is marginal or users hit network walls.
- Separate STT + translation pipeline (Approach B). Same deferral rationale.
- Battery budget / background-CPU throttling.
- Sunlight-mode screen brightness boost.
- Voice output (TTS). v1 is text teleprompter only.
- App Store distribution.
- Auth, accounts, database, analytics, billing.
- Simultaneous two-way speech on one phone.

## 12-month ideal (delta)

A monolingual traveler uses this app for 2 weeks in Japan and never opens Google Translate. Gestures feel inevitable. JA accuracy holds for casual chat, not just keywords. Battery survives a full day of sporadic use. Screen is readable in bright sunlight. Works when LTE drops for 3 seconds walking past a building.

**v1 delta:** covers shell + one realtime pipeline + swipe handoff + benchmarks + basic WS reconnect. Does NOT cover battery/thermal budget, sunlight readability, or on-device fallback. These are explicit 12-month debts, not v1 gaps.

## Strategic risks flagged but not mitigated in v1

1. **OpenAI Realtime JA accuracy is unproven for travel phrases.** Mitigation: the benchmark phrases file exists specifically to catch this early. If accuracy is marginal, pivot to Approach B (separate STT + translate) in v2.
2. **Provider lock-in / pricing drift.** OpenAI Realtime is per-minute. Extended use during a two-week trip could cost real money. Not a v1 blocker, but worth tracking once you have real usage.
3. **No offline path.** Any dead-zone moment is a dead app. The WS reconnect logic softens this but does not solve it. Approach C remains the real answer in v2.

## Additional decisions (from review sections 1-11)

### 6. Screen split orientation — top-bottom with 180° flip on far side

**Accepted.** Matches the vision's physical layout ("phone parallel with the ground, one vertical end in front of me, other in front of the local"). The scaffold's current left-right `HStack` split does not match. The plan must specify:

- Vertical split (top-half vs bottom-half of the screen when phone is held in portrait but laid flat between two people, long axis pointing from one person to the other).
- Top half rotated 180° relative to bottom half so each person reads right-side-up from their own end.
- Gesture directions are mirrored on the flipped side (a "swipe toward the other person" is visually up on the bottom half and visually down on the top half — both map to the same logical "hand off" action).
- Layout mirroring (padding, text alignment, affordance placement) on the flipped half.
- Active/inactive styling applies per half, independent of rotation.

### 7. Worker `/ws-token` — shared-secret header auth

**Accepted.** Prevents OpenAI budget burn if the Worker URL ever becomes public (blog post, GitHub README, decompiled app binary). The plan must specify:

- App sends `X-App-Secret: <constant>` header on every Worker request.
- Worker rejects requests missing or mismatching the header with HTTP 401.
- Secret stored in app as a compile-time constant (raises the bar above "open endpoint"; not cryptographically strong but proportional to v1 personal use).
- Secret stored in Worker as a Cloudflare Secret (not plaintext in `wrangler.jsonc`).
- Include in the "v1 vs v2" debt list: this is a weak auth for personal use. If v2 goes App Store, upgrade to Cloudflare Access or per-device issuance.

## Implementation plan must also address (from sections 1-11)

These are not new scope expansions — they are specifications the implementation plan must include for v1 to be correct.

### Architecture / error handling

- **OpenAI Realtime ephemeral token contract.** The scaffold's `/ws-token` response shape is fabricated. The plan must specify the real OpenAI Realtime client-secret / session-creation contract and update the `RealtimeBootstrap` Swift struct + Worker response to match. This is an Hour-1 blocker for the implementer.
- **Explicit `DecodingError` rescue** in `WorkerClient.fetchRealtimeBootstrap`. Distinguish "worker is down" from "worker returned unexpected shape."
- **Request timeout** on `URLRequest.timeoutInterval` — ~5s for bootstrap, not the 60s default.
- **Error-to-UI mapping** — each named error class maps to a specific user-visible state, not just `localizedDescription` pass-through.
- **Empty/zero-length field validation** on `RealtimeBootstrap` after decode — empty `ephemeralToken` or `websocketURL` must fail bootstrap, not silently connect with bad values.

### State machine

- Add `reconnecting` connection state (from scope decision 4).
- Cancel the in-flight bootstrap `Task` inside `endConversation()` — today it would mutate stale state if bootstrap returns after end.
- Debounce `startConversation()` — ignore while already `.bootstrapping` or `.ready`.

### Interaction edge cases

- **App backgrounded mid-conversation:** iOS will suspend URLSession and close the WebSocket. Plan must decide — auto-pause on background and reconnect on foreground, or force end-session? Pick one.
- **Incoming phone call:** handle `AVAudioSession.interruptionNotification` (`.began` → pause, `.ended` → offer resume).
- **Swipe during `bootstrapping`:** ignore, or queue the direction flip? Pick one.
- **Both sides swipe simultaneously:** last-write-wins is fine; specify it.

### Realtime session config

- Set OpenAI Realtime session `modalities: ["text"]` (text-only output; no TTS in v1).
- Prompt the session as a bidirectional simultaneous interpreter (EN→JA and JA→EN, auto-detect input language).
- Specify zero retention in session init if OpenAI supports it.

### Observability (minimum)

- Structured `Logger` (OSLog) at: `startConversation`, `bootstrapRealtime` entry+exit, `togglePause`, `endConversation`, WS connect/close/error, swipe handoff, reconnect attempts.
- Every log line tagged with `sessionId` from the worker response so `wrangler tail` cross-references the iOS logs.
- Worker logs: `sessionId`, path, outcome.
- Nice-to-have for the blog post: tokens-burned-per-session log line on session end.

### Design

- **Active vs inactive side styling** — vision says "active speaker side becomes lighter and less visually dominant, opposite side becomes bolder." Scaffold has this inverted today. Plan must reconcile.
- **Waveform center control** — plan must specify tap-to-pause + hold-to-end behaviors explicitly, including hold duration (suggest 1.5s), progress ring animation, what cancels (release, drag off).
- **First-run affordance** for the swipe gesture. Options: edge chevron, corner hint label on first launch, rubberband feedback when finger touches the edge.
- **Accessibility floor:** VoiceOver labels on the waveform control + both speaker halves, Dynamic Type support, a tap fallback for the swipe gesture. Not optional — a voice app that excludes screen-reader users fails its own premise.
- **Visual reference.** The plan should cite a concrete visual reference (screenshot, Figma frame, or ASCII sketch) so the implementer isn't guessing aesthetic direction.

## Next steps

1. Spec review loop runs on this doc inside `/plan-ceo-review`.
2. Apply accepted scope before the implementation plan is produced:
   - Add "Why not Google Translate" section to `docs/vision.md`.
   - Reconcile the swipe-vs-tap drift in `docs/architecture.md` and `ios/JapanVoiceApp/Features/Conversation/ConversationScreen.swift`.
   - Reconcile the screen orientation (top-bottom with 180° flip) across `docs/architecture.md` and `ConversationScreen.swift`.
   - Create `docs/benchmark-phrases.md` with 5-10 bilingual travel phrases.
3. Run `docs/implementation-plan-prompt.md` with a downstream agent to produce `docs/implementation-plan.md`. The plan must inherit every decision in this document.
4. `/plan-eng-review` before implementation (required gate).
5. `/plan-design-review` recommended — swipe UX + teleprompter layout + screen rotation are the product.
