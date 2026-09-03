import AppKit
import AVFoundation
import ServiceManagement
import SwiftUI
import KeyVoiceStore
import KeyVoiceCleanup

struct SettingsView: View {
    let store: Store
    let settings: SettingsStore
    let onSetAPIKey: () -> Void

    @State private var ollamaModels: [String] = []
    @State private var detectedTools: [CLITool] = []

    var body: some View {
        Form {
            Section("General") {
                LabeledContent("Microphone") {
                    Picker("Microphone", selection: microphoneSelection) {
                        Text("System Default").tag(String?.none)
                        ForEach(microphones, id: \.uniqueID) { device in
                            Text(device.localizedName).tag(Optional(device.uniqueID))
                        }
                    }
                    .labelsHidden()
                    .frame(maxWidth: 280)
                }

                LabeledContent("Hotkey") {
                    VStack(alignment: .trailing, spacing: 2) {
                        Picker("Hotkey", selection: hotKeyBinding) {
                            Text("Right-Option (⌥)").tag(61)
                            Text("Left-Option (⌥)").tag(58)
                        }
                        .labelsHidden()
                        .frame(maxWidth: 200)
                        Text("Applies after you restart KeyVoice.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Section("Behavior") {
                Toggle("Launch at login", isOn: launchAtLoginBinding)
                Toggle("Show the on-screen HUD", isOn: showHUDBinding)
                Toggle("Play a sound", isOn: soundEnabledBinding)
            }

            Section("Transcription cleanup") {
                Picker("Polish transcripts with", selection: cleanupProviderBinding) {
                    Text("Off — raw (most private)").tag("off")
                    Text("On-device · Ollama").tag("ollama")
                    Text("Installed CLI").tag("cli")
                    Text("Claude API key").tag("claude")
                }

                if settings.cleanupProvider == "ollama" {
                    if ollamaModels.isEmpty {
                        Text("Ollama not detected. Install and run Ollama, then Refresh.")
                            .font(.caption).foregroundStyle(.secondary)
                    } else {
                        Picker("Model", selection: ollamaModelBinding) {
                            ForEach(ollamaModels, id: \.self) { Text($0).tag(Optional($0)) }
                        }
                    }
                    Button("Refresh detection", action: detect)
                }

                if settings.cleanupProvider == "cli" {
                    if detectedTools.isEmpty {
                        Text("No CLI found (claude, codex, gemini). Install one, then Refresh.")
                            .font(.caption).foregroundStyle(.secondary)
                    } else {
                        Picker("Tool", selection: cliToolBinding) {
                            ForEach(detectedTools, id: \.self) { Text($0.rawValue).tag($0.rawValue) }
                        }
                    }
                    Text("Experimental — reuses a CLI you're already signed into. Slower than Ollama.")
                        .font(.caption).foregroundStyle(.secondary)
                    Button("Refresh detection", action: detect)
                }

                if settings.cleanupProvider == "claude" {
                    LabeledContent("Anthropic API key") {
                        Button("Set API Key…", action: onSetAPIKey)
                    }
                }

                Label("Your audio is always transcribed on-device. Only Claude / CLI text-cleanup leaves this Mac.",
                      systemImage: "lock.shield")
                    .font(.caption).foregroundStyle(.secondary)
            }

            Section("Data") {
                LabeledContent("Dictation history") {
                    Button("Clear History…", role: .destructive, action: confirmClearHistory)
                }
            }

            Section("About") {
                LabeledContent("Application", value: "KeyVoice")
                Text("Fast, system-wide push-to-talk voice typing for your Mac.")
                    .foregroundStyle(.secondary)
                Label("All data stays on this Mac.", systemImage: "lock")
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .padding()
        .navigationTitle("Settings")
        .task { detect() }
    }

    private var microphones: [AVCaptureDevice] {
        AVCaptureDevice.DiscoverySession(
            deviceTypes: [.microphone],
            mediaType: .audio,
            position: .unspecified
        ).devices
    }

    private var microphoneSelection: Binding<String?> {
        Binding(
            get: { settings.micDeviceID },
            set: { settings.micDeviceID = $0 }
        )
    }

    private var launchAtLoginBinding: Binding<Bool> {
        Binding(
            get: { settings.launchAtLogin },
            set: { enabled in
                settings.launchAtLogin = enabled
                if enabled {
                    try? SMAppService.mainApp.register()
                } else {
                    try? SMAppService.mainApp.unregister()
                }
            }
        )
    }

    private var showHUDBinding: Binding<Bool> {
        Binding(
            get: { settings.showHUD },
            set: { settings.showHUD = $0 }
        )
    }

    private var soundEnabledBinding: Binding<Bool> {
        Binding(
            get: { settings.soundEnabled },
            set: { settings.soundEnabled = $0 }
        )
    }

    private var hotKeyBinding: Binding<Int> {
        Binding(
            get: { settings.hotKeyCode },
            set: { settings.hotKeyCode = $0 }
        )
    }

    private var cleanupProviderBinding: Binding<String> {
        Binding(get: { settings.cleanupProvider }, set: { settings.cleanupProvider = $0 })
    }

    private var ollamaModelBinding: Binding<String?> {
        Binding(get: { settings.ollamaModel }, set: { settings.ollamaModel = $0 })
    }

    private var cliToolBinding: Binding<String> {
        Binding(get: { settings.cliTool }, set: { settings.cliTool = $0 })
    }

    /// Probe for installed CLIs (sync) and running Ollama models (async), for the pickers.
    private func detect() {
        detectedTools = CLICleaner.detectTools()
        Task {
            let models = await OllamaCleaner.detectModels()
            await MainActor.run {
                ollamaModels = models
                if settings.ollamaModel == nil { settings.ollamaModel = models.first }
            }
        }
    }

    private func confirmClearHistory() {
        let alert = NSAlert()
        alert.messageText = "Clear Dictation History?"
        alert.informativeText = "This permanently deletes all saved transcripts from this Mac. This action cannot be undone."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Clear History")
        alert.addButton(withTitle: "Cancel")

        if alert.runModal() == .alertFirstButtonReturn {
            store.clearHistory()
        }
    }
}
