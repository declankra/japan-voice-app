# Japan Voice App Implementation Plan Prompt

Use this prompt with an agent when the goal is to create the implementation plan, not write code yet.

---

You are working in the repo at `/Users/macbook/Code/japan-voice-app`.

Your task is to create the **implementation plan only** for v1 of the Japan Voice App. Do **not** implement the product in this pass.

## Read first

Read these files before doing anything else:

- `/Users/macbook/Code/japan-voice-app/docs/vision.md`
- `/Users/macbook/Code/japan-voice-app/docs/architecture.md`
- `/Users/macbook/Code/japan-voice-app/CLAUDE.md`
- the current repo scaffold under `ios/` and `worker/`

## Goal

Write a practical implementation plan for the first working v1 build of the app.

The plan should be good enough that another agent could execute it step by step without guessing what matters.

## Locked v1 product choices

- native `SwiftUI` iPhone app
- one personal `Cloudflare Worker`
- `OpenAI Realtime` for v1
- one active speaker at a time
- home screen with one centered launch control using the waveform visual
- conversation screen with:
  - split layout
  - swipe on your own side toward the other person to hand off the translation lane
  - center waveform tap to pause/resume
  - center waveform long-press with progress ring to end conversation and return home

## What the plan should cover

Break the work into clear phases and tasks for:

1. **App shell**
   - home screen
   - conversation screen
   - centered waveform control
   - swipe-based speaker handoff
   - navigation between home and conversation

2. **State model**
   - app/session state
   - active speaker and translation direction state
   - paused/running/ending states
   - long-press exit progress state

3. **Worker integration**
   - worker env contract
   - `/ws-token` response shape
   - app bootstrap request
   - error handling when worker/bootstrap fails

4. **Realtime integration seam**
   - protocol and service boundaries for OpenAI Realtime
   - what should be stubbed first vs implemented later
   - how to keep the UI testable before realtime audio is fully live

5. **UI polish for v1**
   - visual treatment of active vs inactive speaker side
   - clear swipe affordance for handing the translation lane to the other person
   - smooth transition from home button to center waveform control
   - pause vs end interaction clarity

6. **Verification**
   - what to build and run locally
   - what can be tested before simulator audio works
   - what manual checks define “v1 shell works”

## Constraints

- Do not add auth, analytics, billing, App Store work, or a database.
- Do not redesign the architecture.
- Do not introduce unnecessary abstraction.
- Keep the plan biased toward shipping a usable first shell quickly.
- If there is a tradeoff between “clean architecture” and “working soon,” prefer the simpler working path.

## Output

Create a single markdown plan file at:

`/Users/macbook/Code/japan-voice-app/docs/implementation-plan.md`

The plan should include:

- a short summary of the v1 goal
- ordered implementation phases
- concrete tasks under each phase
- notes on file ownership / likely files to touch
- verification steps
- biggest risks / blockers

## Important

This pass is for planning only.

Do not write app code.
Do not write worker code.
Do not modify the scaffold beyond creating the plan file if needed.
