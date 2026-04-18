---
name: "[[japan-voice-app/vision|Japan Voice App]]"
type: side-product
status: scaffolded
repo: ~/Code/japan-voice-app
description: Realtime voice translation app for face-to-face conversations with locals in Japan
---

# Japan Voice App

## Context

Traveling to Japan and don't speak any Japanese. Want to build an app to have conversations with locals in realtime.

## Current State

- Repo scaffold exists at `/Users/macbook/Code/japan-voice-app`
- Git is initialized on `main`
- iOS app and Cloudflare Worker skeleton are in place
- Current blocker is local Xcode simulator/platform setup, not product architecture

## Vision

The way I see it working:
- Used when standing close to locals
- Position the phone parallel with the ground — one vertical end in front of me, the other in front of the local
- Screen split down the middle (top-half vs bottom-half, with the far side's text rotated 180° so each person reads right-side-up from their own end)
- When I talk in English, the words get translated from English into Japanese and display like a scrolling teleprompter, readable to the person on the other end

## Why this, not Google Translate

Google Translate conversation mode is the incumbent: free, offline-capable, Japanese-tuned, ~10 years of product iteration. This app only earns its place by being materially better on at least one axis that matters for a traveler. Three candidate wedges:

1. **Realtime continuous vs turn-taking.** Google makes you press a button each turn and waits for a pause. This app runs a live session — both people can speak without interrupting the tool. Conversations feel like conversations, not dictation.
2. **Teleprompter layout parallel to the ground.** The phone lies flat between two people on a counter or table, text oriented correctly for each end. The interaction becomes a shared surface, not a phone one person holds up to the other's face.
3. **Travel-context UX.** One-thumb operation, high-contrast, designed for standing close to a stranger in a noisy space — the izakaya counter, the hostel lobby, the konbini register. Optimized for the places where Google Translate feels awkward to hold up.

Every v1 decision should serve at least one of these wedges. If it doesn't, it's a distraction.
