import AppKit
import AVFoundation
import ServiceManagement
import SwiftUI
import KeyVoiceStore

struct SettingsView: View {
    let store: Store
    let settings: SettingsStore
    let onSetAPIKey: () -> Void

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

            Section("Cleanup") {
                LabeledContent("Transcription cleanup") {
                    Button("Set API Key…", action: onSetAPIKey)
                }
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
        .padding()
        .navigationTitle("Settings")
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
