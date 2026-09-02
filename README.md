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
- **Transcribe** — Apple **SpeechAnalyzer** (on-device, macOS 26+). Audio never leaves the Mac.
- **Cleanup** — **Claude Haiku** fixes grammar and matches the app's tone. The transcript text is sent to Anthropic; audio is not.
- **Insert** — clipboard paste-injection that works across native, Electron, and web apps, with your clipboard saved and restored.

## Module layout

| Module | Responsibility |
|---|---|
| `KeyVoiceCore` | The contract: protocols, the `Target` lock, events, config, and the `Coordinator` pipeline. |
| `KeyVoiceHotkey` | Right-Option push-to-talk via a listen-only CGEvent tap. |
| `KeyVoiceInsert` | Paste-injection + capturing/re-verifying the paste target. |
| `KeyVoiceAudio` | Mic capture + on-device SpeechAnalyzer transcription + the live level meter. |
| `KeyVoiceCleanup` | The Claude cleanup call + Keychain key storage. |
| `KeyVoiceApp` | Menu-bar shell that wires it all into the Coordinator. |

## Build & run

```bash
swift build              # compile
swift test               # run the core unit tests
./Scripts/setup-signing.sh   # once: create a stable signing identity (see Code signing below)
export KEYVOICE_CODESIGN_IDENTITY="KeyVoice Dev Signing"
./Scripts/bundle.sh      # produce build/KeyVoice.app
open build/KeyVoice.app
```

Then grant **Input Monitoring**, **Accessibility**, and **Microphone** in System Settings →
Privacy & Security, and add your Anthropic API key in the app's Settings.

## Code signing

macOS ties **Input Monitoring** and **Accessibility** permissions to the app's code-signing
identity. `Scripts/bundle.sh` must sign with a **stable certificate** or those grants are lost on
every rebuild:

- **Ad-hoc signing** (`codesign -s -`) derives the identity from the executable's **CDHash**, which
  changes on every build — so macOS treats each rebuild as a *different app* and drops the
  permissions you granted. (This is why the hotkey stopped arming after a rebuild.)
- **A certificate** anchors the "designated requirement" to the cert, so the identity stays stable
  across rebuilds and grants persist.

Pick one identity (nothing is hardcoded — resolved from `$KEYVOICE_CODESIGN_IDENTITY`, else an
auto-detected `Apple Development` cert, else an ad-hoc fallback that prints a warning):

- **Have an Apple Development certificate** (Xcode → Settings → Accounts → Manage Certificates, or
  an Apple Developer account)? Just `export KEYVOICE_CODESIGN_IDENTITY="Apple Development: you (TEAMID)"`.
- **No Apple account?** Run `./Scripts/setup-signing.sh` once — it creates a self-signed *Code
  Signing* certificate in a dedicated keychain (it never touches your login keychain or any macOS
  privacy records), then export the identity it prints. The bundle id stays `com.keyvoice.app`.

**One-time reset after switching signing.** macOS still holds KeyVoice's *old* identity in its
permission records, so grants won't apply until you clear them once:

- System Settings → Privacy & Security → **Input Monitoring** → select KeyVoice → click **–**; do the
  same under **Accessibility**. Relaunch and grant again.
- Or: `tccutil reset Accessibility com.keyvoice.app ; tccutil reset ListenEvent com.keyvoice.app`

KeyVoice never modifies these records for you.

## Requirements

- macOS 26 (Tahoe) — transcription uses Apple's on-device **SpeechAnalyzer** (Apple-only, no fallback).
- An Anthropic API key for the cleanup step (without it, KeyVoice pastes the raw transcription).

## Status

Early build. Core pipeline, hotkey, paste, transcription, and cleanup are implemented and compile;
end-to-end behavior needs live validation on the target Mac (permissions, first-run speech-model
download, cross-app paste). See `docs/` and the project plan for the phased acceptance tests.
