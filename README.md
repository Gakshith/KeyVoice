# KeyVoice

System-wide push-to-talk voice typing for macOS.

Focus any text field — WhatsApp, Gmail, Slack, VS Code, Calendar, a browser — hold the
push-to-talk key, and speak. On release KeyVoice transcribes what you said **on your Mac**,
cleans up the grammar and formats it for the app you're in, and pastes it at your cursor.

## How it works

```
hold ⌥R → record mic → transcribe on-device → Claude fixes grammar/format → paste at the locked cursor
release ┘                                       └ any failure/timeout/empty → paste raw or skip (never wrong window, never silent)
```

- **Trigger** — hold **Right-Option (⌥)**. A listen-only key tap, so normal typing and ⌥-accents still work.
- **Transcribe** — Apple **SpeechAnalyzer** (on-device, macOS 26); **WhisperKit** fallback. Audio never leaves the Mac.
- **Cleanup** — **Claude Haiku** fixes grammar and matches the app's tone. The transcript text is sent to Anthropic; audio is not.
- **Insert** — clipboard paste-injection that works across native, Electron, and web apps, with your clipboard saved and restored.

## Module layout

| Module | Responsibility |
|---|---|
| `KeyVoiceCore` | The contract: protocols, the `Target` lock, events, config, and the `Coordinator` pipeline. |
| `KeyVoiceHotkey` | Right-Option push-to-talk via a listen-only CGEvent tap. |
| `KeyVoiceInsert` | Paste-injection + capturing/re-verifying the paste target. |
| `KeyVoiceAudio` | Mic capture + SpeechAnalyzer and WhisperKit transcribers. |
| `KeyVoiceCleanup` | The Claude cleanup call + Keychain key storage. |
| `KeyVoiceApp` | Menu-bar shell that wires it all into the Coordinator. |

## Build & run

```bash
swift build          # compile
swift test           # run the core unit tests
./Scripts/bundle.sh  # produce build/KeyVoice.app
open build/KeyVoice.app
```

Then grant **Input Monitoring**, **Accessibility**, and **Microphone** in System Settings →
Privacy & Security, and add your Anthropic API key in the app's Settings.

## Requirements

- macOS 26 (Tahoe) for the SpeechAnalyzer engine; macOS 14+ runs on the WhisperKit fallback.
- An Anthropic API key for the cleanup step (without it, KeyVoice pastes the raw transcription).

## Status

Early build. Core pipeline, hotkey, paste, transcription, and cleanup are implemented and compile;
end-to-end behavior needs live validation on the target Mac (permissions, first-run speech-model
download, cross-app paste). See `docs/` and the project plan for the phased acceptance tests.
