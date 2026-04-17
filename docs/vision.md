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
- Screen split down the middle
- When I talk in English, the words get translated from English into Japanese and display like a scrolling teleprompter, readable to the person on the other end
