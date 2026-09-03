# KeyVoice

System-wide push-to-talk voice typing for macOS.

Focus any text field — WhatsApp, Gmail, Slack, VS Code, Calendar, a browser — hold the
push-to-talk key, and speak. On release KeyVoice transcribes what you said **on your Mac** and
pastes it at your cursor. If no field is focused, it saves the text to a scratchpad with a Copy
button instead of losing it.

## How it works

```
hold ⌥ → record mic → transcribe on-device → optional cleanup → paste at the locked cursor
release ┘                                     └ off / slow / empty → paste raw, or scratchpad if no target (never wrong window, never silent)
```

- **Trigger** — hold **Right-Option (⌥)** (rebindable to Left-Option). A listen-only key tap, so normal typing and ⌥-accents still work.
- **Transcribe** — Apple **SpeechAnalyzer** (on-device, macOS 26+), English. **Audio never leaves the Mac.**
- **Cleanup (optional, off by default)** — polish grammar/format with on-device **Ollama** or the **Claude API**. Only when you turn it on does *transcript text* leave the Mac (audio never does). Off = the raw transcription is pasted.
- **Insert** — clipboard paste-injection that works across native, Electron, and web apps, with your clipboard saved and restored (and left alone if you copy something during the paste).
- **No target?** — dictate with nothing focused and the text appears in a floating **scratchpad** with Copy. Secure/password fields are never captured.
- **HUD** — a floating Liquid-Glass **Living HUD** (a SwiftUI Canvas Aurora) shows listening → thinking → done; no Metal, no bundled shader.

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

**Distributing to other Macs.** The self-signed cert above is for **local development only**. A build
you hand to someone else must be signed with a **Developer ID Application** certificate, built with a
**hardened runtime** and the right entitlements (microphone, Input Monitoring/Accessibility), then
**notarized and stapled** — otherwise Gatekeeper blocks it. That step needs an Apple Developer account
and is not automated here.

## Requirements

- macOS 26 (Tahoe) — transcription uses Apple's on-device **SpeechAnalyzer** (Apple-only, no fallback).
- Cleanup is **optional and off by default**. For Claude cleanup, add an Anthropic API key in Settings;
  for on-device cleanup, install Ollama. With cleanup off, KeyVoice pastes the raw transcription.

## Privacy

- **Audio never leaves your Mac** — recognition is fully on-device.
- **Transcript text** leaves only if you enable **Claude** cleanup (sent to Anthropic). On-device
  Ollama and "off" keep everything local.
- History, dictionary, snippets, and stats are stored locally (SwiftData). No account, no telemetry.

## Known limitations

- Recognition is **English (en-US)**. "Translate to" transcribes English, then translates via the cleanup model.
- Cleanup latency is capped (~4s); past that, the raw text is pasted so you're never blocked.
- Distribution requires your own Developer ID + notarization (see Code signing).
