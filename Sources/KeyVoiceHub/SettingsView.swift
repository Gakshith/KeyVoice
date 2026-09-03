import AppKit
import AVFoundation
import ServiceManagement
import SwiftUI
import KeyVoiceDesign
import KeyVoiceStore
import KeyVoiceCleanup

/// Settings, in the warm Studio language: grouped cards instead of a system Form. Native controls
/// (pickers, toggles) sit inside our cards so it reads as one app.
struct SettingsView: View {
    let store: Store
    let settings: SettingsStore
    let onSetAPIKey: () -> Void

    @State private var ollamaModels: [String] = []

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header

                SettingsGroup("General") {
                    SettingsRow("Microphone") {
                        Picker("", selection: microphoneSelection) {
                            Text("System Default").tag(String?.none)
                            ForEach(microphones, id: \.uniqueID) { device in
                                Text(device.localizedName).tag(Optional(device.uniqueID))
                            }
                        }
                        .labelsHidden().frame(maxWidth: 240)
                    }
                    Divider().overlay(KeyVoiceTokens.Colors.line)
                    SettingsRow("Hotkey", caption: "Applies after you restart KeyVoice.") {
                        Picker("", selection: hotKeyBinding) {
                            Text("Right-Option (⌥)").tag(61)
                            Text("Left-Option (⌥)").tag(58)
                        }
                        .labelsHidden().frame(maxWidth: 190)
                    }
                }

                SettingsGroup("Behavior") {
                    SettingsRow("Launch at login") { Toggle("", isOn: launchAtLoginBinding).labelsHidden() }
                    Divider().overlay(KeyVoiceTokens.Colors.line)
                    SettingsRow("Show the on-screen HUD") { Toggle("", isOn: showHUDBinding).labelsHidden() }
                    Divider().overlay(KeyVoiceTokens.Colors.line)
                    SettingsRow("Play a sound when text lands") { Toggle("", isOn: soundEnabledBinding).labelsHidden() }
                }

                SettingsGroup("Transcription cleanup") {
                    SettingsRow("Polish transcripts with") {
                        Picker("", selection: cleanupProviderBinding) {
                            Text("Off — raw").tag("off")
                            Text("On-device · Ollama").tag("ollama")
                            Text("Claude API key").tag("claude")
                        }
                        .labelsHidden().frame(maxWidth: 210)
                    }

                    if settings.cleanupProvider == "ollama" {
                        Divider().overlay(KeyVoiceTokens.Colors.line)
                        if ollamaModels.isEmpty {
                            SettingsNote("Ollama not detected. Install and run it, then Refresh.")
                        } else {
                            SettingsRow("Model") {
                                Picker("", selection: ollamaModelBinding) {
                                    ForEach(ollamaModels, id: \.self) { Text($0).tag(Optional($0)) }
                                }.labelsHidden().frame(maxWidth: 210)
                            }
                        }
                        SettingsRow("") { Button("Refresh detection", action: detect).buttonStyle(.plain).foregroundStyle(KeyVoiceTokens.Colors.accent) }
                    }

                    if settings.cleanupProvider == "claude" {
                        Divider().overlay(KeyVoiceTokens.Colors.line)
                        SettingsRow("Anthropic API key") {
                            Button("Set API Key…", action: onSetAPIKey).buttonStyle(.plain).foregroundStyle(KeyVoiceTokens.Colors.accent)
                        }
                    }

                    if settings.cleanupProvider != "off" {
                        Divider().overlay(KeyVoiceTokens.Colors.line)
                        SettingsRow("Translate to", caption: "Transcribes your English, then translates it into this language.") {
                            Picker("", selection: targetLanguageBinding) {
                                Text("Don't translate").tag("off")
                                ForEach(Self.languages, id: \.self) { Text($0).tag($0) }
                            }.labelsHidden().frame(maxWidth: 210)
                        }
                    }

                    Divider().overlay(KeyVoiceTokens.Colors.line)
                    SettingsNote("🔒 Your audio is always transcribed on-device. Only Claude text-cleanup (if you turn it on) leaves this Mac.")
                }

                SettingsGroup("Data") {
                    SettingsRow("Dictation history") {
                        Button("Clear History…", action: confirmClearHistory)
                            .buttonStyle(.plain).foregroundStyle(.red)
                    }
                }

                SettingsGroup("About") {
                    SettingsRow("Application") { Text("KeyVoice").foregroundStyle(KeyVoiceTokens.Colors.text2) }
                    Divider().overlay(KeyVoiceTokens.Colors.line)
                    SettingsNote("Fast, system-wide push-to-talk voice typing. Your audio always stays on this Mac.")
                }
            }
            .padding(.horizontal, 32).padding(.top, 30).padding(.bottom, 34)
            .frame(maxWidth: 720, alignment: .leading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .task { detect() }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("Settings").font(.studioSerif(30)).foregroundStyle(KeyVoiceTokens.Colors.text)
            Text("No account. Your audio always stays on this Mac.")
                .font(.system(size: 14.5)).foregroundStyle(KeyVoiceTokens.Colors.text2)
        }
    }

    // MARK: - Data & bindings

    private var microphones: [AVCaptureDevice] {
        AVCaptureDevice.DiscoverySession(deviceTypes: [.microphone], mediaType: .audio, position: .unspecified).devices
    }
    private var microphoneSelection: Binding<String?> {
        Binding(get: { settings.micDeviceID }, set: { settings.micDeviceID = $0 })
    }
    private var launchAtLoginBinding: Binding<Bool> {
        Binding(get: { settings.launchAtLogin }, set: { enabled in
            settings.launchAtLogin = enabled
            if enabled { try? SMAppService.mainApp.register() } else { try? SMAppService.mainApp.unregister() }
        })
    }
    private var showHUDBinding: Binding<Bool> { Binding(get: { settings.showHUD }, set: { settings.showHUD = $0 }) }
    private var soundEnabledBinding: Binding<Bool> { Binding(get: { settings.soundEnabled }, set: { settings.soundEnabled = $0 }) }
    private var hotKeyBinding: Binding<Int> { Binding(get: { settings.hotKeyCode }, set: { settings.hotKeyCode = $0 }) }
    private var cleanupProviderBinding: Binding<String> { Binding(get: { settings.cleanupProvider }, set: { settings.cleanupProvider = $0 }) }
    private var ollamaModelBinding: Binding<String?> { Binding(get: { settings.ollamaModel }, set: { settings.ollamaModel = $0 }) }
    private var targetLanguageBinding: Binding<String> { Binding(get: { settings.targetLanguage }, set: { settings.targetLanguage = $0 }) }

    private static let languages = ["Spanish", "French", "German", "Portuguese", "Italian",
                                    "Hindi", "Telugu", "Mandarin Chinese", "Japanese", "Korean", "Arabic"]

    private func detect() {
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
        alert.informativeText = "This permanently deletes all saved transcripts from this Mac. This cannot be undone."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Clear History")
        alert.addButton(withTitle: "Cancel")
        if alert.runModal() == .alertFirstButtonReturn { store.clearHistory() }
    }
}

// MARK: - Studio settings primitives

/// A titled group: an uppercase label above a warm card holding the rows.
private struct SettingsGroup<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content
    init(_ title: String, @ViewBuilder content: () -> Content) { self.title = title; self.content = content() }
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            StudioSectionLabel(title)
            StudioCard(padding: 4) {
                VStack(spacing: 0) { content }
            }
        }
    }
}

/// A label + trailing control row.
private struct SettingsRow<Control: View>: View {
    let title: String
    let caption: String?
    @ViewBuilder let control: Control
    init(_ title: String, caption: String? = nil, @ViewBuilder control: () -> Control) {
        self.title = title; self.caption = caption; self.control = control()
    }
    var body: some View {
        HStack(alignment: caption == nil ? .center : .top, spacing: 12) {
            if !title.isEmpty {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.system(size: 14.5, weight: .medium)).foregroundStyle(KeyVoiceTokens.Colors.text)
                    if let caption {
                        Text(caption).font(.system(size: 12)).foregroundStyle(KeyVoiceTokens.Colors.fog)
                    }
                }
            }
            Spacer(minLength: 8)
            control
        }
        .padding(.horizontal, 14).padding(.vertical, 12)
    }
}

/// A full-width muted note row.
private struct SettingsNote: View {
    let text: String
    init(_ text: String) { self.text = text }
    var body: some View {
        Text(text)
            .font(.system(size: 12.5)).foregroundStyle(KeyVoiceTokens.Colors.text2)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 14).padding(.vertical, 10)
    }
}
