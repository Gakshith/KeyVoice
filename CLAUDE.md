# KeyVoice — repo guide

Build/test commands, architecture, and conventions for this repo only.

## Status

Scaffold only — no build system, no app code, no stack committed yet. The sections
below are the intended shape; fill in the real commands the day code lands.

## Stack (undecided)

macOS system-wide app. Swift + AppKit is the natural fit for global hotkey capture,
active-app detection, and Accessibility-based text insertion. Not committed — revisit
before the first spike.

## Architecture (intended)

Pipeline: **hotkey → capture → transcribe → format → insert**.

- **Hotkey** — global push-to-talk key, configurable. Hold to record, release to fire.
- **Capture** — record microphone audio for the hold duration.
- **Transcribe** — send audio to a swappable backend. This is a **plugin boundary**:
  Codex, Claude, a cloud speech API, and local models are interchangeable behind one
  interface. Keep the core app free of backend-specific code.
- **Format** — optional cleanup/reformat keyed on the active app (per-app rules).
- **Insert** — place the text at the current cursor position in the frontmost app.

Design goals: minimal end-to-end latency; works in arbitrary text fields system-wide.

## macOS permissions

The app will need **Accessibility** (to read the active app and insert text) and
**Microphone** access. Note these in setup docs once implemented.

## Build / test

```bash
# TODO: add once the stack and toolchain are chosen
```

## Conventions

_Add repo-specific conventions here as they emerge (module layout, the backend
interface contract, naming). Nothing yet._
