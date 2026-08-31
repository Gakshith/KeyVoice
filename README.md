# KeyVoice

System-wide push-to-talk AI voice typing for macOS.

Focus any text field — WhatsApp, Gmail, Slack, VS Code, Codex, Claude — hold a
configurable hotkey, and speak. On release, KeyVoice transcribes what you said,
optionally cleans or reformats it based on the app you're in, and drops the text
straight at your cursor with minimal latency.

## Why

Existing dictation is either OS-locked, slow, or dumps raw unpunctuated text. KeyVoice
aims for: hold-to-talk anywhere, fast insert-at-cursor, and context-aware cleanup
(a Slack message and a commit message shouldn't be formatted the same way).

## How it's meant to work

1. **Hotkey** — hold a global push-to-talk key; recording starts.
2. **Capture** — audio is recorded while held.
3. **Transcribe** — on release, audio goes to a transcription backend.
4. **Format** — text is optionally cleaned/reformatted for the active app.
5. **Insert** — result is inserted at the current cursor position.

The transcription backend is **modular** — Codex, Claude, a cloud speech API, or a
local model can be swapped in without changing the core app.

## Status

Early scaffold. No app code yet. Stack not yet committed (macOS points toward
Swift/AppKit). See the design and open questions before building.

## Running it

_Not runnable yet._ Build/run instructions land here once the stack is chosen and the
first spike works.
